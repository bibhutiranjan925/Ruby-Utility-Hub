# frozen_string_literal: true

# ===========================================================================
#  RUBY UTILITY HUB - shared Ruby backend logic
#
#  Every file in api/ is a small Vercel serverless function, and each one
#  calls into this module. Writing the rules here means the formulas exist
#  exactly once, and they are the same ones used by the original console
#  program (ruby_utility_hub.rb):
#
#    * text * count                - String Repeater
#    * 2 * Math::PI * radius       - Circle Calculator
#    * "#{last} #{first}"          - Name Reverser
#    * File.extname                - File Extension Extractor
#    * [a, b, c].max               - Greatest of Three Numbers
#    * limit.downto(1) + odd?      - Odd Numbers
#    * first == 20 || second == 20 - Number Checker
#    * (a < 0 && b > 100) || ...   - Temperature Checker
#
#  Input  : a Hash of query parameters (every value arrives as a String)
#  Output : a Hash that gets serialised to JSON, or an InputError, which the
#           API turns into an HTTP 400 response with a friendly message.
# ===========================================================================

require 'json'

module Hub
  # Raised whenever the visitor's input cannot be used.
  class InputError < StandardError; end

  # Safety limits for the public web version. The console program has no
  # limits because only its own user can type into it, but a public endpoint
  # must never accept unlimited work from a stranger.
  MAX_TEXT_LENGTH     = 100   # characters in the string to repeat
  MAX_NAME_LENGTH     = 60    # characters in a first/last name
  MAX_FILENAME_LENGTH = 255   # characters in a filename
  MAX_REPEAT_COUNT    = 1_000 # largest allowed repeat count
  MAX_NUMBER_LENGTH   = 20    # characters in any typed number
  MAX_ODD_LIMIT       = 10_000 # largest upper limit for the odd generator

  # A whole number such as 5, -3 or 0 (but never 2.5 or "abc").
  INTEGER_PATTERN = /\A[+-]?\d+\z/
  # A number such as 5, -2.5 or .5 - digits only, so no Infinity or NaN.
  NUMBER_PATTERN  = /\A[+-]?(?:\d+\.?\d*|\.\d+)\z/

  module_function

  # =========================================================================
  #  Request handling - used by every api/*.rb entry point
  # =========================================================================

  # Runs one tool, then writes the JSON answer and the HTTP status code.
  # The block receives the parsed query parameters and returns the payload.
  def serve(request, response, title:)
    unless request.request_method == 'GET'
      return send_json(response, 405, { ok: false, error: 'Only GET requests are supported.' })
    end

    payload = yield(request.query)
    send_json(response, 200, { ok: true, tool: title }.merge(payload))
  rescue InputError => error
    send_json(response, 400, { ok: false, error: error.message })
  rescue StandardError => error
    # Never leak a backtrace to the browser; write it to the function log.
    warn "[Ruby Utility Hub] #{title}: #{error.class}: #{error.message}"
    send_json(response, 500, { ok: false, error: 'Something went wrong on the server. Please try again.' })
  end

  # Writes a JSON body with the given status code.
  def send_json(response, status, payload)
    response.status = status
    response['Content-Type'] = 'application/json; charset=utf-8'
    response['Cache-Control'] = 'no-store'
    response.body = JSON.generate(payload)
  end

  # =========================================================================
  #  Input helpers - the same acceptance rules as the console program
  # =========================================================================

  # Raw parameter value as a String; "" when the parameter is missing.
  def value_of(params, key)
    params[key].to_s
  end

  # A required free-text field: not blank after trimming, not too long.
  # Whitespace-only input is reported separately so the message is precise,
  # exactly like the console program does for names.
  def required_text(params, key, label, max_length:)
    raw = value_of(params, key)
    value = raw.strip
    if value.empty?
      raise InputError, raw.empty? ? "#{label} is required." : "#{label} cannot be empty or only spaces."
    end
    raise InputError, "#{label} is too long (maximum #{max_length} characters)." if value.length > max_length

    value
  end

  # A whole number, optionally bounded. Zero is a legitimate value: it is
  # only rejected when it falls below an explicit `minimum`.
  def integer_of(params, key, label, minimum: nil, maximum: nil)
    raw = value_of(params, key).strip
    raise InputError, "#{label} is required." if raw.empty?
    raise InputError, "#{label} is too long (maximum #{MAX_NUMBER_LENGTH} characters)." if raw.length > MAX_NUMBER_LENGTH
    raise InputError, "#{label} must be a whole number, for example 5, 0 or -3." unless INTEGER_PATTERN.match?(raw)

    number = raw.to_i
    raise InputError, "#{label} must be #{minimum} or more." if !minimum.nil? && number < minimum
    raise InputError, "#{label} must be #{maximum} or less." if !maximum.nil? && number > maximum

    number
  end

  # A whole or decimal number, optionally bounded.
  def float_of(params, key, label, minimum: nil, maximum: nil)
    raw = value_of(params, key).strip
    raise InputError, "#{label} is required." if raw.empty?
    raise InputError, "#{label} is too long (maximum #{MAX_NUMBER_LENGTH} characters)." if raw.length > MAX_NUMBER_LENGTH
    raise InputError, "#{label} must be a number, for example 5, 0 or -2.5." unless NUMBER_PATTERN.match?(raw)

    number = raw.to_f
    raise InputError, "#{label} must be #{minimum} or more." if !minimum.nil? && number < minimum
    raise InputError, "#{label} must be #{maximum} or less." if !maximum.nil? && number > maximum

    number
  end

  # =========================================================================
  #  Display helpers - identical wording to the console program
  # =========================================================================

  # 5.0 becomes "5" while 2.5 stays "2.5" (same as format_number).
  def tidy(number)
    whole_number = number.to_i
    number == whole_number ? whole_number.to_s : number.to_s
  end

  # Always two decimal places, exactly like format('%.2f', ...) in Ruby.
  def two_decimals(number)
    format('%.2f', number)
  end

  # =========================================================================
  #  The eight tools
  # =========================================================================

  # --- Module 1: String Repeater ------------------------------------------
  def string_repeater(params)
    text = value_of(params, 'text')
    if text.length > MAX_TEXT_LENGTH
      raise InputError, "The text is too long (maximum #{MAX_TEXT_LENGTH} characters)."
    end

    count = integer_of(params, 'count', 'Repeat count', minimum: 0, maximum: MAX_REPEAT_COUNT)

    result = text * count # Ruby's string multiplication, straight from Ruby

    {
      summary: "#{text.empty? ? '(empty string)' : text} \u00d7 #{count}",
      rows: [
        { label: 'Original text', value: text.empty? ? '(empty string)' : text },
        { label: 'Repeat count', value: count.to_s },
        { label: 'Result', value: result.empty? ? '(empty string)' : result, mono: true }
      ]
    }
  end

  # --- Module 2: Circle Calculator ----------------------------------------
  def circle_calculator(params)
    radius = float_of(params, 'radius', 'Radius', minimum: 0, maximum: 1_000_000)

    perimeter = 2 * Math::PI * radius
    area      = Math::PI * radius**2

    {
      summary: "Perimeter #{two_decimals(perimeter)} \u00b7 Area #{two_decimals(area)}",
      rows: [
        { label: 'Radius', value: tidy(radius) },
        { label: 'Perimeter (circumference)', value: two_decimals(perimeter) },
        { label: 'Area', value: two_decimals(area) }
      ]
    }
  end

  # --- Module 3: Name Reverser --------------------------------------------
  def name_reverser(params)
    first_name = required_text(params, 'first', 'First name', max_length: MAX_NAME_LENGTH)
    last_name  = required_text(params, 'last', 'Last name', max_length: MAX_NAME_LENGTH)

    {
      summary: "#{last_name} #{first_name}",
      rows: [
        { label: 'Original name', value: "#{first_name} #{last_name}" },
        { label: 'Reversed name', value: "#{last_name} #{first_name}", mono: true }
      ]
    }
  end

  # --- Module 4: File Extension Extractor ---------------------------------
  def file_extension(params)
    filename = value_of(params, 'filename').strip
    if filename.length > MAX_FILENAME_LENGTH
      raise InputError, "The filename is too long (maximum #{MAX_FILENAME_LENGTH} characters)."
    end

    if filename.empty?
      return {
        summary: 'No extension found.',
        rows: [
          { label: 'Filename', value: '(nothing entered)' },
          { label: 'Result', value: 'No extension found.' },
          { label: 'Why', value: 'a filename was not entered.' }
        ]
      }
    end

    # delete_prefix removes the leading dot, so File.extname('a.tar.gz')
    # becomes 'gz', and a bare '.' collapses to '' (no extension).
    extension = File.extname(filename).delete_prefix('.')

    if extension.empty?
      {
        summary: 'No extension found.',
        rows: [
          { label: 'Filename', value: filename },
          { label: 'Result', value: 'No extension found.' },
          { label: 'Why', value: explain_missing_extension(filename) }
        ]
      }
    else
      {
        summary: ".#{extension}",
        rows: [
          { label: 'Filename', value: filename },
          { label: 'Extension', value: extension, mono: true }
        ]
      }
    end
  end

  # Same three explanations as the console program.
  def explain_missing_extension(filename)
    if filename.start_with?('.') && filename.count('.') == 1
      'a name that starts with a dot is a hidden file, not an extension.'
    elsif filename.end_with?('.')
      'a dot at the very end does not create an extension.'
    else
      'this name contains no dot followed by an extension.'
    end
  end

  # --- Module 5: Greatest of Three Numbers --------------------------------
  def greatest_of_three(params)
    first  = float_of(params, 'a', 'First number')
    second = float_of(params, 'b', 'Second number')
    third  = float_of(params, 'c', 'Third number')

    values   = [first, second, third]
    greatest = values.max

    {
      summary: "Greatest: #{tidy(greatest)}",
      rows: [
        { label: 'Values', value: values.map { |number| tidy(number) }.join(', ') },
        { label: 'Greatest', value: tidy(greatest), mono: true }
      ]
    }
  end

  # --- Module 6: Odd Numbers (10 down to 1 by default) --------------------
  def odd_numbers(params)
    raw_limit = value_of(params, 'limit').strip
    upper_limit = if raw_limit.empty?
                    10 # the original exercise, untouched
                  else
                    integer_of(params, 'limit', 'Upper limit', minimum: 1, maximum: MAX_ODD_LIMIT)
                  end

    numbers = []
    upper_limit.downto(1) do |number|
      numbers << number if number.odd?
    end

    {
      summary: "Odd numbers from #{upper_limit} down to 1",
      rows: [
        { label: 'Upper limit', value: upper_limit.to_s },
        { label: 'Count', value: numbers.length.to_s }
      ],
      chips: numbers.map(&:to_s)
    }
  end

  # --- Module 7: Number Checker (20 or the sum) ---------------------------
  def number_checker(params)
    first  = integer_of(params, 'a', 'First integer')
    second = integer_of(params, 'b', 'Second integer')

    matched = first == 20 || second == 20

    {
      summary: matched ? 'Result: true' : "Sum: #{first + second}",
      rows: [
        { label: 'Numbers', value: "#{first}, #{second}" },
        matched ? { label: 'Result', value: 'true', mono: true }
                : { label: 'Sum', value: (first + second).to_s, mono: true }
      ]
    }
  end

  # --- Module 8: Temperature Checker --------------------------------------
  def temperature_checker(params)
    first  = float_of(params, 'a', 'First temperature')
    second = float_of(params, 'b', 'Second temperature')

    condition = (first < 0 && second > 100) || (second < 0 && first > 100)

    {
      summary: "Condition: #{condition}",
      rows: [
        { label: 'Temperatures', value: "#{tidy(first)}, #{tidy(second)}" },
        { label: 'Condition', value: condition.to_s, mono: true }
      ]
    }
  end
end
