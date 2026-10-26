# Vercel turns every .rb file in /api into its own serverless function.
# This file only wires the HTTP request to the shared logic in lib/hub.rb.

require_relative '../lib/hub'

Handler = Proc.new do |request, response|
  Hub.serve(request, response, title: 'Temperature Checker') do |params|
    Hub.temperature_checker(params)
  end
end
