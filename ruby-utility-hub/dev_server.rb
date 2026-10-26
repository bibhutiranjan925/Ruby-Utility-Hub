#!/usr/bin/env ruby
# frozen_string_literal: true

# ===========================================================================
#  RUBY UTILITY HUB - local development server
#
#  Vercel turns every api/*.rb file into a serverless function backed by
#  WEBrick: it requires the file, takes its `Handler` proc and mounts it on
#  a WEBrick server. This script does exactly the same thing on your own
#  machine, so what you test here is what Vercel will run in the cloud.
#
#  Run it with:   ruby dev_server.rb
#  Then open:     http://localhost:3000
#
#  Only WEBrick is required (gem install webrick). Nothing else is needed,
#  and this file is NOT deployed as a function because it lives outside /api.
# ===========================================================================

require 'webrick'
require 'json'

ROOT      = __dir__
PORT      = (ENV['PORT'] || 3000).to_i
API_ROUTE = '/api'

# ---------------------------------------------------------------------------
#  Load every api/*.rb file and remember the Handler it defines.
#  Vercel loads one file per function; here we load them all into one
#  process, so the constant is captured and cleared after each file.
# ---------------------------------------------------------------------------
handlers = {}
Dir[File.join(ROOT, 'api', '*.rb')].sort.each do |file|
  load file
  handlers[File.basename(file, '.rb')] = Object.const_get(:Handler)
  Object.send(:remove_const, :Handler) if Object.const_defined?(:Handler)
end

# ---------------------------------------------------------------------------
#  Static files (index.html, style.css, script.js) come straight from the
#  project folder; /api/* is handed to the matching Ruby Handler.
# ---------------------------------------------------------------------------
server = WEBrick::HTTPServer.new(
  Port: PORT,
  DocumentRoot: ROOT,
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::WARN),
  AccessLog: []
)

server.mount_proc(API_ROUTE) do |request, response|
  tool = File.basename(request.path) # /api/string_repeater -> string_repeater
  handler = handlers[tool]

  if handler.nil?
    response.status = 404
    response['Content-Type'] = 'application/json; charset=utf-8'
    response.body = JSON.generate(
      ok: false,
      error: "Unknown tool \"#{tool}\". Available: #{handlers.keys.sort.join(', ')}."
    )
  else
    handler.call(request, response)
  end
end

# Leave cleanly with Ctrl+C.
%w[INT TERM].each { |signal| trap(signal) { server.shutdown } }

puts '----------------------------------------------------------------'
puts ' Ruby Utility Hub - local development server'
puts " Open http://localhost:#{PORT}"
puts " Ruby tools loaded: #{handlers.keys.sort.join(', ')}"
puts ' Press Ctrl+C to stop.'
puts '----------------------------------------------------------------'

server.start
