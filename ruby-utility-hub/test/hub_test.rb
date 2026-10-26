# Tests for lib/hub.rb - run with:  ruby test/hub_test.rb
# Resolves all paths relative to this file, so it works from any machine.
# Works from any machine: resolve ../lib relative to this file's folder.
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'hub'

$pass = 0
$fail = 0

def check(label, actual, expected)
  if actual == expected
    $pass += 1
    puts "  PASS  #{label}"
  else
    $fail += 1
    puts "  FAIL  #{label}\n        expected: #{expected.inspect}\n        actual  : #{actual.inspect}"
  end
end

def check_error(label, needle)
  yield
  $fail += 1
  puts "  FAIL  #{label} -> no InputError raised"
rescue Hub::InputError => error
  if error.message.include?(needle)
    $pass += 1
    puts "  PASS  #{label} -> #{error.message}"
  else
    $fail += 1
    puts "  FAIL  #{label} -> message #{error.message.inspect} does not contain #{needle.inspect}"
  end
end

def row(result, label)
  result[:rows].find { |r| r[:label] == label }[:value]
end

puts '== 1. String Repeater =='
r = Hub.string_repeater('text' => 'Ruby', 'count' => '3')
check('Ruby x 3 result', row(r, 'Result'), 'RubyRubyRuby')
check('Ruby x 3 summary', r[:summary], "Ruby \u00d7 3")

r = Hub.string_repeater('text' => '', 'count' => '0')
check('empty text, n = 0', row(r, 'Result'), '(empty string)')
check('n = 0 count shown', row(r, 'Repeat count'), '0')

r = Hub.string_repeater('text' => 'Hi', 'count' => '0')
check('non-empty text, n = 0', row(r, 'Result'), '(empty string)')

check_error('negative count', '0 or more') { Hub.string_repeater('text' => 'Hi', 'count' => '-2') }
check_error('non-integer count', 'whole number') { Hub.string_repeater('text' => 'Hi', 'count' => 'abc') }
check_error('decimal count', 'whole number') { Hub.string_repeater('text' => 'Hi', 'count' => '2.5') }
check_error('missing count', 'required') { Hub.string_repeater('text' => 'Hi', 'count' => '') }
check_error('count above web limit', '1000 or less') { Hub.string_repeater('text' => 'Hi', 'count' => '1001') }
check_error('text above web limit', 'too long') { Hub.string_repeater('text' => 'a' * 101, 'count' => '1') }

puts '== 2. Circle Calculator =='
r = Hub.circle_calculator('radius' => '5')
check('radius 5 perimeter', row(r, 'Perimeter (circumference)'), '31.42')
check('radius 5 area', row(r, 'Area'), '78.54')

r = Hub.circle_calculator('radius' => '0')
check('radius 0 perimeter', row(r, 'Perimeter (circumference)'), '0.00')
check('radius 0 area', row(r, 'Area'), '0.00')

r = Hub.circle_calculator('radius' => '2.5')
check('radius 2.5 perimeter', row(r, 'Perimeter (circumference)'), '15.71')
check('radius 2.5 area', row(r, 'Area'), '19.63')

check_error('negative radius', '0 or more') { Hub.circle_calculator('radius' => '-3') }
check_error('invalid radius', 'must be a number') { Hub.circle_calculator('radius' => 'x') }
check_error('missing radius', 'required') { Hub.circle_calculator('radius' => '') }

puts '== 3. Name Reverser =='
r = Hub.name_reverser('first' => 'Arun', 'last' => 'Kumar')
check('reversed name', row(r, 'Reversed name'), 'Kumar Arun')
check('original name', row(r, 'Original name'), 'Arun Kumar')

check_error('whitespace-only first name', 'cannot be empty or only spaces') { Hub.name_reverser('first' => '   ', 'last' => 'Kumar') }
check_error('missing last name', 'is required') { Hub.name_reverser('first' => 'Arun', 'last' => '') }

puts '== 4. File Extension Extractor =='
r = Hub.file_extension('filename' => 'archive.tar.gz')
check('archive.tar.gz', row(r, 'Extension'), 'gz')

r = Hub.file_extension('filename' => 'notes')
check('notes -> no extension', row(r, 'Result'), 'No extension found.')
check('notes -> reason', row(r, 'Why'), 'this name contains no dot followed by an extension.')

r = Hub.file_extension('filename' => '.bashrc')
check('.bashrc -> no extension', row(r, 'Result'), 'No extension found.')
check('.bashrc -> reason', row(r, 'Why'), 'a name that starts with a dot is a hidden file, not an extension.')

r = Hub.file_extension('filename' => 'report.')
check('report. -> no extension', row(r, 'Result'), 'No extension found.')
check('report. -> reason', row(r, 'Why'), 'a dot at the very end does not create an extension.')

r = Hub.file_extension('filename' => '')
check('empty filename -> no extension', row(r, 'Result'), 'No extension found.')
check('empty filename -> reason', row(r, 'Why'), 'a filename was not entered.')

r = Hub.file_extension('filename' => '.config.json')
check('.config.json', row(r, 'Extension'), 'json')

puts '== 5. Greatest of Three Numbers =='
r = Hub.greatest_of_three('a' => '-5', 'b' => '-12', 'c' => '-3')
check('negatives -> -3', row(r, 'Greatest'), '-3')

r = Hub.greatest_of_three('a' => '7', 'b' => '7', 'c' => '7')
check('equal values -> 7', row(r, 'Greatest'), '7')

r = Hub.greatest_of_three('a' => '3.5', 'b' => '-1.25', 'c' => '2')
check('decimals -> 3.5', row(r, 'Greatest'), '3.5')

check_error('non-numeric value', 'must be a number') { Hub.greatest_of_three('a' => 'abc', 'b' => '1', 'c' => '2') }
check_error('missing value', 'required') { Hub.greatest_of_three('a' => '', 'b' => '1', 'c' => '2') }

puts '== 6. Odd Numbers =='
check('default (empty limit)', Hub.odd_numbers('limit' => '')[:chips], %w[9 7 5 3 1])
check('limit 10 explicit', Hub.odd_numbers('limit' => '10')[:chips], %w[9 7 5 3 1])
check('custom limit 5', Hub.odd_numbers('limit' => '5')[:chips], %w[5 3 1])
check('limit 1', Hub.odd_numbers('limit' => '1')[:chips], ['1'])
check('count row', row(Hub.odd_numbers('limit' => '10'), 'Count'), '5')

check_error('limit 0', '1 or more') { Hub.odd_numbers('limit' => '0') }
check_error('non-numeric limit', 'whole number') { Hub.odd_numbers('limit' => 'abc') }
check_error('limit above web limit', '10000 or less') { Hub.odd_numbers('limit' => '10001') }

puts '== 7. Number Checker =='
r = Hub.number_checker('a' => '20', 'b' => '5')
check('20 and 5 -> true', row(r, 'Result'), 'true')

r = Hub.number_checker('a' => '5', 'b' => '20')
check('5 and 20 -> true', row(r, 'Result'), 'true')

r = Hub.number_checker('a' => '12', 'b' => '4')
check('12 and 4 -> sum 16', row(r, 'Sum'), '16')

r = Hub.number_checker('a' => '-8', 'b' => '0')
check('-8 and 0 -> sum -8', row(r, 'Sum'), '-8')

check_error('decimal input', 'whole number') { Hub.number_checker('a' => '2.5', 'b' => '1') }
check_error('text input', 'whole number') { Hub.number_checker('a' => 'x', 'b' => '1') }

puts '== 8. Temperature Checker =='
r = Hub.temperature_checker('a' => '-10', 'b' => '150')
check('-10 and 150 -> true', row(r, 'Condition'), 'true')

r = Hub.temperature_checker('a' => '150', 'b' => '-10')
check('150 and -10 -> true (second arrangement)', row(r, 'Condition'), 'true')

r = Hub.temperature_checker('a' => '20', 'b' => '50')
check('20 and 50 -> false', row(r, 'Condition'), 'false')

r = Hub.temperature_checker('a' => '0', 'b' => '100')
check('0 and 100 -> false (strict boundaries)', row(r, 'Condition'), 'false')

check_error('text temperature', 'must be a number') { Hub.temperature_checker('a' => 'abc', 'b' => '1') }
check_error('missing temperature', 'required') { Hub.temperature_checker('a' => '', 'b' => '1') }

puts "\n#{$pass} passed, #{$fail} failed"
exit($fail.zero? ? 0 : 1)
