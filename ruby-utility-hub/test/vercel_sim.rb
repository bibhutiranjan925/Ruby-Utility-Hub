# Simulates what Vercel's vc_init.rb does for each api/*.rb entry point:
#   require the file from an arbitrary working directory,
#   read the top-level `Handler` constant, and call it with WEBrick-style
#   request/response objects.
# Run with:  ruby test/vercel_sim.rb   (no server needed)
require 'tmpdir'

$hub = File.expand_path('..', __dir__) # the project root, wherever it lives
$pass = 0
$fail = 0

def ok(label, cond, detail = nil)
  cond ? ($pass += 1; puts "  PASS  #{label}") : ($fail += 1; puts "  FAIL  #{label} -> #{detail}")
end

# Minimal stand-ins for WEBrick::HTTPRequest / HTTPResponse
FakeRequest = Struct.new(:request_method, :query)
class FakeResponse
  attr_accessor :status, :body
  def initialize
    @headers = {}
  end
  def []=(k, v)
    @headers[k] = v
  end
  def header(k) = @headers[k]
end

# Each endpoint gets its own valid query, as the real frontend sends.
PARAMS = {
  'string_repeater'     => { 'text' => 'Ruby', 'count' => '3' },
  'circle_calculator'   => { 'radius' => '5' },
  'name_reverser'       => { 'first' => 'Arun', 'last' => 'Kumar' },
  'file_extension'      => { 'filename' => 'archive.tar.gz' },
  'greatest_of_three'   => { 'a' => '7', 'b' => '2', 'c' => '9' },
  'odd_numbers'         => { 'limit' => '10' },
  'number_checker'      => { 'a' => '20', 'b' => '5' },
  'temperature_checker' => { 'a' => '-10', 'b' => '150' }
}.freeze

Dir["#{$hub}/api/*.rb"].sort.each do |file|
  name = File.basename(file, '.rb')

  # cwd deliberately somewhere else, like Vercel's bootstrap would be
  Dir.chdir(Dir.tmpdir) do
    load file
  end

  ok("#{name}: top-level Handler is defined", Object.const_defined?(:Handler))
  ok("#{name}: Handler is a Proc (vc_init requires respond_to?(:call))",
     Object.const_get(:Handler).is_a?(Proc), Object.const_get(:Handler).class)

  request  = FakeRequest.new('GET', PARAMS.fetch(name))
  response = FakeResponse.new
  begin
    Object.const_get(:Handler).call(request, response)
    ok("#{name}: Handler.call writes status + JSON body",
       response.status == 200 && response.body.to_s.start_with?('{'),
       "status=#{response.status} body=#{response.body.inspect[0, 80]}")
    ok("#{name}: Content-Type is application/json",
       response.header('Content-Type').to_s.include?('application/json'),
       response.header('Content-Type').inspect)
    data = JSON.parse(response.body) rescue nil
    ok("#{name}: body parses as JSON with ok=true", data && data['ok'] == true, response.body.to_s[0, 120])
  rescue StandardError => e
    ok("#{name}: Handler.call raised no error", false, "#{e.class}: #{e.message}")
  end

  Object.send(:remove_const, :Handler) if Object.const_defined?(:Handler)
end

# Method-not-allowed path, exactly as a real deployment would hit it
load "#{$hub}/api/number_checker.rb"
request  = FakeRequest.new('POST', { 'a' => '1', 'b' => '2' })
response = FakeResponse.new
Handler.call(request, response)
ok('POST request -> HTTP 405', response.status == 405, response.status)

# Unexpected server error -> HTTP 500 with no backtrace leaked
request  = FakeRequest.new('GET', nil) # query nil blows up on purpose
response = FakeResponse.new
Handler.call(request, response)
ok('unexpected error -> HTTP 500, generic message only',
   response.status == 500 && !response.body.to_s.include?('hub.rb'),
   "status=#{response.status} body=#{response.body}")

puts "\n#{$pass} passed, #{$fail} failed"
exit($fail.zero? ? 0 : 1)
