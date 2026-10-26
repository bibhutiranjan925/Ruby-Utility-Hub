# End-to-end HTTP tests for the local dev server.
# Start the server first (ruby dev_server.rb), then:  ruby test/http_test.rb
require 'net/http'
require 'json'
require 'uri'

BASE = 'http://localhost:3000'
$pass = 0
$fail = 0

def fetch(path, method = :get)
  uri = URI(BASE + path)
  request = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
  response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
  [response.code.to_i, response.body.to_s, response['content-type'].to_s]
end

def ok(label, condition, detail = nil)
  if condition
    $pass += 1
    puts "  PASS  #{label}"
  else
    $fail += 1
    puts "  FAIL  #{label}#{detail ? " -> #{detail}" : ''}"
  end
end

def json_get(path)
  code, body, = fetch(path)
  [code, JSON.parse(body)]
end

puts '--- static site ---'
code, body, ctype = fetch('/')
ok('GET / returns 200', code == 200, "got #{code}")
ok('index has the title', body.include?('Ruby Utility Hub'))
ok('index has the hero subtitle', body.include?('Eight useful tools, powered by Ruby'))
ok('index has the SDC Lab footer', body.include?('developed for the SDC Lab'))
ok('index has all 8 tool cards', body.scan('class="tool-card"').length == 8,
   "found #{body.scan('class=\"tool-card\"').length}")
ok('index links style.css + script.js',
   body.include?('style.css') && body.include?('script.js'))
ok('index is valid UTF-8', body.dup.force_encoding('UTF-8').valid_encoding?)

code, = fetch('/style.css')
ok('GET /style.css returns 200', code == 200, "got #{code}")
code, = fetch('/script.js')
ok('GET /script.js returns 200', code == 200, "got #{code}")

puts '--- valid requests (all 8 tools) ---'
code, data = json_get('/api/string_repeater?text=Ruby&count=3')
ok('repeater 200 + ok', code == 200 && data['ok'] == true)
ok('repeater result RubyRubyRuby', data.dig('rows', 2, 'value') == 'RubyRubyRuby', data.inspect)
ok('repeater summary uses a real multiplication sign', data['summary'].include?("\u00d7"))

code, data = json_get('/api/string_repeater?text=&count=0')
ok('repeater n=0 allowed', code == 200 && data.dig('rows', 2, 'value') == '(empty string)')

code, data = json_get('/api/circle_calculator?radius=5')
ok('circle 31.42 / 78.54',
   data.dig('rows', 1, 'value') == '31.42' && data.dig('rows', 2, 'value') == '78.54', data.inspect)

code, data = json_get('/api/circle_calculator?radius=0')
ok('circle radius 0 -> 0.00 / 0.00',
   data.dig('rows', 1, 'value') == '0.00' && data.dig('rows', 2, 'value') == '0.00')

code, data = json_get('/api/name_reverser?first=Arun&last=Kumar')
ok('name reversed', data['summary'] == 'Kumar Arun')

code, data = json_get('/api/file_extension?filename=archive.tar.gz')
ok('extension gz', data.dig('rows', 1, 'value') == 'gz')

code, data = json_get('/api/greatest_of_three?a=3.5&b=-1.25&c=2')
ok('greatest 3.5', data.dig('rows', 1, 'value') == '3.5')

code, data = json_get('/api/odd_numbers?limit=')
ok('odds default chips', data['chips'] == %w[9 7 5 3 1], data.inspect)

code, data = json_get('/api/number_checker?a=-8&b=0')
ok('number checker sum -8', data.dig('rows', 1, 'value') == '-8')

code, data = json_get('/api/temperature_checker?a=-10&b=150')
ok('temperature true', data.dig('rows', 1, 'value') == 'true')

code, data = json_get('/api/temperature_checker?a=20&b=50')
ok('temperature false', data.dig('rows', 1, 'value') == 'false')

puts '--- invalid input -> HTTP 400 with a readable message ---'
[
  ['/api/string_repeater?text=Hi&count=-2', '0 or more'],
  ['/api/string_repeater?text=Hi&count=abc', 'whole number'],
  ['/api/circle_calculator?radius=-3', '0 or more'],
  ['/api/circle_calculator?radius=x', 'must be a number'],
  ['/api/name_reverser?first=%20%20%20&last=Kumar', 'only spaces'],
  ['/api/greatest_of_three?a=1&b=2&c=', 'required'],
  ['/api/odd_numbers?limit=0', '1 or more'],
  ['/api/number_checker?a=2.5&b=1', 'whole number'],
  ['/api/temperature_checker?a=abc&b=1', 'must be a number']
].each do |path, needle|
  code, data = json_get(path)
  ok("400 + '#{needle}' for #{path.split('?').last}",
     code == 400 && data['ok'] == false && data['error'].to_s.include?(needle),
     "code=#{code} body=#{data.inspect}")
end

puts '--- protocol edge cases ---'
code, data = json_get('/api/does_not_exist')
ok('unknown tool -> 404', code == 404 && data['ok'] == false, "code=#{code}")

code, = fetch('/api/circle_calculator?radius=5', :post)
ok('POST -> 405', code == 405, "got #{code}")

code, data = json_get('/api/string_repeater?text=%3Cscript%3Ealert(1)%3C%2Fscript%3E&count=1')
value = data.dig('rows', 2, 'value').to_s
ok('HTML-looking input survives the round trip verbatim',
   code == 200 && value == '<script>alert(1)</script>', value.inspect)
ok('...and the page renders it with textContent only (no .innerHTML assignment)',
   File.read(File.expand_path('../script.js', __dir__)).scan('.innerHTML').empty?)

puts '--- every endpoint responds ---'
%w[string_repeater circle_calculator name_reverser file_extension
   greatest_of_three odd_numbers number_checker temperature_checker].each do |tool|
  code, = fetch("/api/#{tool}")
  ok("GET /api/#{tool} answers", [200, 400].include?(code), "code=#{code}")
end

puts "\n#{$pass} passed, #{$fail} failed"
exit($fail.zero? ? 0 : 1)
