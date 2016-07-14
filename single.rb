require_relative 'lib/parser'

parser = Parser.new

parser.single ARGV[0]
