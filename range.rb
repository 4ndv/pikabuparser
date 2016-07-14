require_relative 'lib/parser'
require 'json'

parser = Parser.new

File.write("#{ARGV[0]}-#{ARGV[1]}.json", parser.range(ARGV[0], ARGV[1]).to_json)
