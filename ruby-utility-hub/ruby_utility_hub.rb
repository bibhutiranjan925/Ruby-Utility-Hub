#!/usr/bin/env ruby
# frozen_string_literal: true

# ===========================================================================
#  RUBY UTILITY HUB
#  A personal, menu-driven console application written in plain Ruby.
#
#  It brings eight small exercises together into one program:
#
#    1. String Repeater             5. Greatest of Three Numbers
#    2. Circle Calculator           6. Odd Number Generator
#    3. Name Reverser               7. Number-20 Checker
#    4. File Extension Extractor    8. Temperature Condition Checker
#
#  Everything lives in this single file and uses only Ruby's built-in
#  features (Kernel methods, Math and File). No gems, no network access,
#  no database and no configuration files are needed.
# ===========================================================================

# Raised internally when the input stream ends, for example when the user
# presses Ctrl+Z (Windows) or Ctrl+D (macOS / Linux), or when a redirected
# input file runs out of lines. The entry point at the bottom of this file
# turns it into a friendly goodbye message instead of a crash.
class EndOfInputError < StandardError; end

# ===========================================================================
#  Input helpers
#  These small methods are reused by every utility module, so the program
#  asks for input and reports mistakes in exactly one consistent way.
# ===========================================================================

# Prints a prompt and reads one whole line from standard input.
# chomp removes the trailing newline (and the \r left by Windows terminals).
# Raises EndOfInputError when there is nothing left to read.
def prompt_line(message)
  print message
  line = $stdin.gets
  raise EndOfInputError, 'no more input available' if line.nil?

  line.chomp
end

# Keeps asking until the user types one of the allowed answers.
# Used for small "pick an option" questions inside a module.
def read_choice(message, allowed)
  loop do
    answer = prompt_line(message).strip
    return answer if allowed.include?(answer)

    puts "  [!] Please enter one of: #{allowed.join(', ')}."
  end
end

# Keeps asking until the user types a whole number.
# The optional `minimum` argument rejects values that are too small while
# still allowing a legitimate value, for example minimum: 0 rejects -4
# but happily accepts 0. Invalid text is reported and the user retries.
def read_integer(message, minimum: nil)
  loop do
    text = prompt_line(message).strip

    begin
      value = Integer(text, 10)
    rescue ArgumentError
      puts "  [!] \"#{text}\" is not a whole number. Please try again (example: 5, 0 or -3)."
      next
    end

    if !minimum.nil? && value < minimum
      puts "  [!] The value must be #{minimum} or more. Please try again."
      next
    end

    return value
  end
end

# Keeps asking until the user types a real number, either whole (5) or
# decimal (2.5). Negative values are allowed unless `minimum` says otherwise.
# Float() raises ArgumentError for text such as "abc", "12x" or "2,5".
def read_float(message, minimum: nil)
  loop do
    text = prompt_line(message).strip

    begin
      value = Float(text)
    rescue ArgumentError
      puts "  [!] \"#{text}\" is not a valid number. Please try again (example: 5, 2.5 or -3.14)."
      next
    end

    if !minimum.nil? && value < minimum
      puts "  [!] The value must be #{minimum} or more. Please try again."
      next
    end

    return value
  end
end

# Asks for a name until a real name is given. Whitespace-only input such as
# "   " is rejected, while the characters the user typed are preserved.
def read_name(message)
  loop do
    name = prompt_line(message).strip
    return name unless name.empty?

    puts '  [!] A name cannot be empty or only spaces. Please try again.'
  end
end

# Stops after every result so the user can read it before the menu returns.
def pause_for_user
  prompt_line("\nPress Enter to return to the main menu...")
end

# Tidies a number for display: 5.0 becomes "5" while 2.5 stays "2.5".
def format_number(value)
  whole_number = value.to_i
  value == whole_number ? whole_number.to_s : value.to_s
end

# ===========================================================================
#  Screen helpers
# ===========================================================================

def print_line
  puts '=' * 62
end

# Shown once when the program starts.
def display_welcome
  puts
  print_line
  puts '                 RUBY UTILITY HUB'
  puts '              Personal Ruby Mini Project'
  print_line
  puts '  Welcome! This program collects eight small Ruby exercises'
  puts '  into one menu-driven console application:'
  puts
  puts '    - strings and text        - maths with Math::PI'
  puts '    - files and extensions    - loops and conditions'
  puts
  puts '  Choose an option, follow the prompts, read the result and'
  puts '  you will come straight back to this menu. Nothing is stored'
  puts '  anywhere; everything happens in this terminal window.'
  print_line
end

# Shown before every choice. Nine numbered options, no hidden shortcuts.
def display_menu
  puts
  print_line
  puts '                       MAIN MENU'
  print_line
  puts '   1. String Repeater'
  puts '   2. Circle Calculator'
  puts '   3. Name Reverser'
  puts '   4. File Extension Extractor'
  puts '   5. Greatest of Three Numbers'
  puts '   6. Odd Number Generator'
  puts '   7. Number-20 Checker'
  puts '   8. Temperature Condition Checker'
  puts '   9. Exit'
  print_line
end

# ===========================================================================
#  Module 1 - String Repeater
#  Repeats a string with Ruby's * operator: text * count.
# ===========================================================================
def repeat_string
  puts
  puts '--- Module 1: String Repeater ---'
  text  = prompt_line('Enter the text to repeat (press Enter for an empty string): ')
  count = read_integer('How many times should it repeat? (0 or more): ', minimum: 0)

  result = text * count

  puts
  puts "  Original text : #{text.empty? ? '(empty string)' : text}"
  puts "  Repeat count   : #{count}"
  puts "  Result         : #{result.empty? ? '(empty string)' : result}"
end

# ===========================================================================
#  Module 2 - Circle Calculator
#  perimeter = 2 * PI * radius      area = PI * radius ** 2
#  Both results are printed with exactly two decimal places.
# ===========================================================================
def calculate_circle
  puts
  puts '--- Module 2: Circle Calculator ---'
  radius = read_float('Enter the radius (0 or more): ', minimum: 0)

  perimeter = 2 * Math::PI * radius
  area      = Math::PI * radius**2

  puts
  puts "  Radius    : #{format_number(radius)}"
  puts "  Perimeter : #{format('%.2f', perimeter)}"
  puts "  Area      : #{format('%.2f', area)}"
end

# ===========================================================================
#  Module 3 - Name Reverser
#  Prints the last name first using string interpolation: "#{last} #{first}"
# ===========================================================================
def reverse_name
  puts
  puts '--- Module 3: Name Reverser ---'
  first_name = read_name('Enter the first name: ')
  last_name  = read_name('Enter the last name : ')

  puts
  puts "  Original name : #{first_name} #{last_name}"
  puts "  Reversed name : #{last_name} #{first_name}"
end

# ===========================================================================
#  Module 4 - File Extension Extractor
#  Uses File.extname, which returns the extension including its dot
#  ("archive.tar.gz" => ".gz"). The dot is removed before printing.
# ===========================================================================
def extract_extension
  puts
  puts '--- Module 4: File Extension Extractor ---'
  filename = prompt_line('Enter a filename (example: archive.tar.gz): ').strip

  puts
  if filename.empty?
    puts '  Filename : (nothing entered)'
    puts '  Result   : No extension found.'
    puts '  Why      : a filename was not entered.'
    return
  end

  # delete_prefix removes the leading dot. It also turns a bare "." into "",
  # so any "no conventional extension" case ends up in the same branch.
  extension = File.extname(filename).delete_prefix('.')

  puts "  Filename : #{filename}"
  if extension.empty?
    puts '  Result   : No extension found.'
    puts "  Why      : #{explain_missing_extension(filename)}"
  else
    puts "  Extension: #{extension}"
  end
end

# Explains, in plain language, why a name has no conventional extension.
def explain_missing_extension(filename)
  if filename.start_with?('.') && filename.count('.') == 1
    'a name that starts with a dot is a hidden file, not an extension.'
  elsif filename.end_with?('.')
    'a dot at the very end does not create an extension.'
  else
    'this name contains no dot followed by an extension.'
  end
end

# ===========================================================================
#  Module 5 - Greatest of Three Numbers
#  Stores the three values in an array and asks it for its maximum.
#  Works for negative numbers, decimals and equal values.
# ===========================================================================
def find_greatest
  puts
  puts '--- Module 5: Greatest of Three Numbers ---'
  first  = read_float('Enter the first number : ')
  second = read_float('Enter the second number: ')
  third  = read_float('Enter the third number : ')

  greatest = [first, second, third].max

  puts
  puts "  Values   : #{format_number(first)}, #{format_number(second)}, #{format_number(third)}"
  puts "  Greatest : #{format_number(greatest)}"
end

# ===========================================================================
#  Module 6 - Odd Number Generator
#  The original exercise prints 9, 7, 5, 3, 1 (10 down to 1).
#  A custom positive upper limit is offered as an optional extra, while
#  option 1 always reproduces the original exercise exactly.
# ===========================================================================
def print_odd_numbers
  puts
  puts '--- Module 6: Odd Number Generator ---'
  puts '   1. Original exercise (odd numbers from 10 down to 1)'
  puts '   2. Custom positive upper limit'
  mode = read_choice('Choose an option [1-2]: ', %w[1 2])

  upper_limit = if mode == '1'
                  10
                else
                  read_integer('Enter a positive upper limit: ', minimum: 1)
                end

  puts
  puts "  Odd numbers from #{upper_limit} down to 1:"
  upper_limit.downto(1) do |number|
    puts number if number.odd?
  end
end

# ===========================================================================
#  Module 7 - Number-20 Checker
#  Uses logical OR (||): if either value equals 20 the answer is true,
#  otherwise the two values are added and the sum is printed.
# ===========================================================================
def check_twenty
  puts
  puts '--- Module 7: Number-20 Checker ---'
  first  = read_integer('Enter the first integer : ')
  second = read_integer('Enter the second integer: ')

  puts
  puts "  Numbers : #{first}, #{second}"
  if first == 20 || second == 20
    puts '  Result   : true'
  else
    puts "  Sum      : #{first + second}"
  end
end

# ===========================================================================
#  Module 8 - Temperature Condition Checker
#  True only when one temperature is below 0 and the other is above 100.
#  Both arrangements are checked with && and ||.
# ===========================================================================
def check_temperatures
  puts
  puts '--- Module 8: Temperature Condition Checker ---'
  temp1 = read_float('Enter the first temperature : ')
  temp2 = read_float('Enter the second temperature: ')

  condition = (temp1 < 0 && temp2 > 100) || (temp2 < 0 && temp1 > 100)

  puts
  puts "  Temperatures : #{format_number(temp1)}, #{format_number(temp2)}"
  puts "  Condition    : #{condition}"
end

# ===========================================================================
#  Main program loop
#  Shows the menu, reads one choice, runs the matching module (or exits),
#  then always comes back to the menu.
# ===========================================================================
def main_loop
  loop do
    display_menu
    choice = prompt_line('Select an option (1-9): ').strip

    case choice
    when '1' then repeat_string
    when '2' then calculate_circle
    when '3' then reverse_name
    when '4' then extract_extension
    when '5' then find_greatest
    when '6' then print_odd_numbers
    when '7' then check_twenty
    when '8' then check_temperatures
    when '9'
      puts
      puts 'Thank you for using Ruby Utility Hub. Goodbye!'
      puts
      return
    else
      # Unknown or non-numeric input: explain, do not crash, show the menu again.
      puts
      puts "  [!] \"#{choice}\" is not a valid option."
      puts '      Please enter a number from 1 to 9.'
      next
    end

    pause_for_user
  end
end

# ===========================================================================
#  Entry point
#  Start with the welcome screen, then run the menu loop. EndOfInputError and
#  Ctrl+C are both turned into a polite goodbye message.
# ===========================================================================
begin
  display_welcome
  main_loop
rescue EndOfInputError
  puts
  puts 'No more input. Thank you for using Ruby Utility Hub. Goodbye!'
  puts
rescue Interrupt
  puts
  puts 'Program interrupted. Thank you for using Ruby Utility Hub. Goodbye!'
  puts
end
