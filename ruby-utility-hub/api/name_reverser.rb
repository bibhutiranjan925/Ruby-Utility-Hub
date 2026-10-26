# Vercel turns every .rb file in /api into its own serverless function.
# This file only wires the HTTP request to the shared logic in lib/hub.rb.

require_relative '../lib/hub'

Handler = Proc.new do |request, response|
  Hub.serve(request, response, title: 'Name Reverser') do |params|
    Hub.name_reverser(params)
  end
end
