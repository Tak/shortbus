#!/usr/bin/env ruby

# This program is free software; you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

require 'shortbus'

class WeeBusTest < ShortBus
	def initialize()
		super('weechat')

		hook_command('WEEBUSTEST', 0, method(:handle_command), 'Weebus test command')
		hook_server('PRIVMSG', 0, method(:handle_server))
		hook_print('PRIVMSG', 0, method(:handle_print))
	end # initialize

	def handle_command(words, words_eol, data)
		Kernel.puts("handle_command: #{words.join(' ')}")
		words_eol.each{ |str|
			Kernel.puts(str)
		}
	end # handle_command

	def handle_server(words, words_eol, data)
		Kernel.puts("handle_server: #{words.join(' ')}")
		words_eol.each{ |str|
			Kernel.puts(str)
		}
	end # handle_server

	def handle_print(words, data)
		Kernel.puts("handle_print: #{words.join(' ')}")
	end # handle_print
end # WeeBusTest

if(__FILE__ == $0)
	blah = WeeBusTest.new()
	blah.run()
end
