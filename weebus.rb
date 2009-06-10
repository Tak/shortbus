#!/usr/bin/env ruby

# This program is free software; you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

require 'dbus'
require 'thread'

WEECHAT_COMMAND_HANDLER = 'weechat_command_handler'
WEECHAT_MESSAGE_HANDLER = 'weechat_message_handler'

class WeeBus < DBus::Object
	# Create an interface.
	dbus_interface('tak.weebus.connection') {
		dbus_method(:Connect, 'in filename:s, in name:s, in description:s, in version:s, out path:s') { |filename, name, description, version|
			Kernel.puts('Weebus: Connect')
			# if(@path)
			# 	Kernel.puts("WeeBus: Trying to connect to existing object: #{@path}")
			# 	['']
			# else
				path = "/tak/weebus/WeeBus#{@index}"
				Kernel.puts("Connecting #{path}")
				@connections[name] = [filename, description, version, path]
				@index += 1
				@plugins[name] = WeeBus.new(path, filename, description, version, path)
				@service.export(@plugins[name])
				[path]
			# end
		}# Connect

		dbus_method(:Disconnect, '') {
			if(@path)
				Kernel.puts("Disconnecting #{@path}")
			else
				Kernel.puts('Disconnect called.')
			end
			[]
		}# Disconnect
	}# tak.weebus.connection

	dbus_interface('tak.weebus.plugin') {
		dbus_method(:Command, 'in command:s') { |command|
			Kernel.puts("WeeBus: #{command}")
			Weechat.command(command)
			[]
		}# Command

		dbus_method(:Print, 'in text:s') { |text|
			Kernel.puts("WeeBus: Print #{text}")
			Weechat.print(text)
			[]
		}# Print

		dbus_method(:GetInfo, 'in key:s, out value:s') { |key|
			Kernel.puts("WeeBus: GetInfo #{key}")
			[Weechat.get_info(key)]
		}# GetInfo

		dbus_method(:GetPrefs, 'in key:s, out status:i, out str:s, out int:i') { |key|
			Kernel.puts("WeeBus: GetPrefs #{key}")
			pref = Weechat.get_config(key)
			[('' == pref) ? 0 : 1, pref, 0]
		}# GetPrefs

		dbus_method(:HookCommand, 'in command:s, in priority:i, in help:s, in commandreturn:i, out id:u') { |command, priority, help, commandreturn|
			Kernel.puts("WeeBus: HookCommand #{command}")
			
			mod = Module.nesting.detect{ |ancestor|
				puts("Scanning #{ancestor.name}")
				ancestor.name.match(/^WeechatRubyModule\d+$/)
			}
			mod.create_command_handler(command)
			success = Weechat.add_command_handler(command, "#{command}_command_handler", help)
			if(1 == success) then @handlers << [command.upcase, WEECHAT_COMMAND_HANDLER]; end
			[id = @handlers.size * success]
		}# HookCommand

		dbus_method(:HookServer, 'in event:s, in priority:i, in eventreturn:i, out id:u') { |event, priority, eventreturn|
			Kernel.puts("WeeBus: HookServer #{event}")
			success = Weechat.add_message_handler(event, WEECHAT_MESSAGE_HANDLER)
			if(1 == success) then @handlers << [event.upcase, WEECHAT_MESSAGE_HANDLER]; end
			[id = @handlers.size * success]
		}# HookServer

		dbus_method(:HookPrint, 'in event:s, in priority:i, in eventreturn:i, out id:u') { |event, priority, eventreturn|
			Kernel.puts("WeeBus: HookPrint #{event}")
			success = Weechat.add_message_handler(event, WEECHAT_MESSAGE_HANDLER)
			if(1 == success) then @handlers << [event.upcase, WEECHAT_MESSAGE_HANDLER]; end
			[id = @handlers.size * success]
		}# HookPrint

		dbus_method(:Unhook, 'in id:u') { |id|
			Kernel.puts("WeeBus: Unhook #{id}")
			if(@handlers && id < @handlers.size && [] != @handlers[id])
				success = Weechat.remove_handler(@handlers[id][0], @handlers[id][1])
				if(1 == success) then @handlers[id] = []; end
			end
			[]
		}# Unhook

		dbus_signal(:CommandSignal, 'words:as, words_eol:as, id:u, context:s')
		dbus_signal(:ServerSignal, 'words:as, words_eol:as, id:u, context:s')
		dbus_signal(:PrintSignal, 'words:as, id:u, context:s')
		dbus_signal(:UnloadSignal, '')
	}# tak.weebus.plugin

	def initialize(path, name, filename, description, version)
		super(path)

		@path = path
		@name = name
		@filename = filename
		@description = description
		@version = version
		@connections = {}
		@handlers = []
		@index = 0
		@plugins = {}

	end # initialize

	attr_accessor :plugins

	def handle_command(server, words, words_eol)
		Kernel.puts("WeeBus: handling #{words[0]}")
		select_indices(@handlers, words[0]).each{ |handler|
			self.CommandSignal(words, words_eol, handler, server)
		}
	end # handle_command

	def handle_message(server, words, words_eol)
		Kernel.puts("WeeBus: handling #{words[0]}")
		select_indices(@handlers, words[0]).each{ |handler|
			self.ServerSignal(words, words_eol, handler, server)
			self.PrintSignal(words, handler, server)
		}
	end # handle_message

	def select_indices(collection, key)
		handlers = []
		@handlers.each_with_index{ |handler, i|
			handlers << [i, handler]
		}
		handlers.select{ |handler|
			[] != handler[1] && handler[1][0] == key.upcase
		}.collect{ |handler| handler[0] }
	end # select_indices
end # WeeBus

def weechat_init()
	Weechat.register('WeeBus', '0.1', 'weechat_finalize', 'Weechat needs help to ride the ShortBus!')
	Kernel.puts('weechat_init')
	@bus = DBus::SessionBus.instance
	@service = @bus.request_service('tak.weebus')
	@weebus = WeeBus.new('/tak/weebus/WeeBus', '', '', '', '')
	@service.export(@weebus)
	Weechat.add_timer_handler(1, 'process_events')
	puts 'WeeBus: listening'
	return Weechat::PLUGIN_RC_OK
end # weechat_init

def weechat_finalize()
	Kernel.puts('weechat_finalize')
	@weebus.plugins.each_value{ |plugin|
		plugin.UnloadSignal()
	}
	return Weechat::PLUGIN_RC_OK
end # weechat_finalize

def weechat_command_handler(server, command, args)
	Kernel.puts("weechat_command_handler: #{command} #{args}")
	wordarrays = transform_args(args)
	@weebus.plugins.each_value{ |plugin|
		plugin.handle_command(server, wordarrays[0], wordarrays[1])
	}
	return Weechat::PLUGIN_RC_OK
end # weechat_command_handler

def weechat_message_handler(server, args)
	Kernel.puts("weechat_message_handler: #{args}")
	wordarrays = transform_args(args)
	@weebus.plugins.each_value{ |plugin|
		plugin.handle_message(server, wordarrays[0], wordarrays[1])	
	}
	return Weechat::PLUGIN_RC_OK
end # weechat_message_handler

def transform_args(args)
	message = "#{args[1]} #{args[2]}"
	words = message.split(/\s/)
	words_eol = (0..message.size-1).collect{ |i|
		words.slice(i..-1).join(' ')
	}
	return [words, words_eol]
end # transform_args

def process_events()
	begin
		ready = IO.select([@bus.socket],nil,nil,0.1)
		if(ready)
			# puts('process_events')
			@bus.update_buffer()
			while(msg = @bus.pop_message())
				puts("#{msg.member} #{msg.signature}")
				@bus.process(msg)
			end
		end
	rescue DBus::Type::SignatureException => e
		puts(e.inspect())
		puts(e.backtrace)
	end
	return Weechat::PLUGIN_RC_OK
end # process_events

def create_command_handler(command)
	define_method("#{command}_command_handler"){ |server, args|
		weechat_command_handler(server, command, args)
	}
end # create_command_handler

