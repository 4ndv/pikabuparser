require_relative 'lib/parser'

parser = Parser.new

puts parser.single ARGV[0]
