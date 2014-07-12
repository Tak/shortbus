#!/usr/bin/env ruby

# This program is free software; you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

require 'dbus'

# Constants from xchat-plugin.h
XCHAT_EAT_NONE = 0
XCHAT_EAT_XCHAT = 1
XCHAT_EAT_PLUGIN = 2
XCHAT_EAT_ALL = 3

XCHAT_PRI_HIGHEST = 127
XCHAT_PRI_HIGH = 	64
XCHAT_PRI_NORM = 	0
XCHAT_PRI_LOW = 	-64
XCHAT_PRI_LOWEST = -128

BACKENDS = {
	:xchat => {
		:service => 'org.xchat.service',
		:object => '/org/xchat/Remote',
		:connection_interface => 'org.xchat.connection',
		:plugin_interface => 'org.xchat.plugin'
	},
	:hexchat => {
		:service => 'org.hexchat.service',
		:object => '/org/hexchat/Remote',
		:connection_interface => 'org.hexchat.connection',
		:plugin_interface => 'org.hexchat.plugin'
	},
	:weechat => {
		:service => 'tak.weebus',
		:object => '/tak/weebus/WeeBus',
		:connection_interface => 'tak.weebus.connection',
		:plugin_interface => 'tak.weebus.plugin'
	}
}

# ShortBus is a dbus plugin client for xchat and ruby.
class ShortBus
	def initialize(backend=:xchat)
		backend = (BACKENDS[backend] ? BACKENDS[backend] : BACKENDS[:xchat])

		@bus = DBus::SessionBus.instance
		@service = @bus.service(backend[:service])
		@service.introspect()
		# puts('== end service ==')
		connection_object = @service.object(backend[:object])
		connection_object.introspect()
		# puts('== end object ==')

		while(!(@connection_interface = connection_object[backend[:connection_interface]]))
			puts('ShortBus: Sleeping')
			sleep(0.1)
		end

		plugin_path = @connection_interface.Connect(__FILE__, 'ShortBus', 'Ruby XChat-DBus Plugin', '0.1')[0]
		ObjectSpace.define_finalizer(self, proc{ |id| finalize() })

		@plugin_object = @service.object(plugin_path)
		@plugin_object.introspect()
		# puts('== end object ==')
		while(!(@plugin_interface = @plugin_object[backend[:plugin_interface]]))
			puts('ShortBus: Sleeping')
			sleep(0.1)
		end
		while(!(@connection_interface = @plugin_object[backend[:connection_interface]]))
			puts('ShortBus: Sleeping')
			sleep(0.1)
		end

		@commands = {}
		@servers = {}
		@prints = {}
		@channels = {}
		@nicks = {}
		@plugin_interface.on_signal(@bus, 'CommandSignal'){ |words, words_eol, id, context| handle_command(words, words_eol, id, context) }
		@plugin_interface.on_signal(@bus, 'ServerSignal'){ |words, words_eol, id, context| handle_server(words, words_eol, id, context) }
		@plugin_interface.on_signal(@bus, 'PrintSignal'){ |words, id, context| handle_print(words, id, context) }
		@plugin_interface.on_signal(@bus, 'UnloadSignal'){ puts('ShortBus: Unloading.'); exit(0); }

		# Command handler for shortbus administrative stuff
		hook_command('SHORTBUS', XCHAT_PRI_NORM, method(:shortbus_handler), 'Shortbus administrative stuff: QUIT')

		puts('ShortBus loaded.')
	end # initialize

	def finalize()
		puts('ShortBus: Finalizing')
		
		#Disconnect dbus interface
		if(@connection_interface) then @connection_interface.Disconnect(); end

		# Unhook handlers
		[@commands, @servers, @prints].each{ |id, handler|
			if(handler) then @plugin_interface.Unhook(id); end
		}
	end

	# Hook up a command handler
	# * command is the command to match
	# * priority is the priority of the handler (XCHAT_PRI_*)
	# * handler is a Method that will be invoked when the command is called
	# * help is the help text to be displayed
	# * Returns the handler id
	def hook_command(command, priority, handler, help)
		id = @plugin_interface.HookCommand(command, priority, help, XCHAT_EAT_ALL)[0]
		@commands[id] = handler
		# puts("Using id #{id} for handler #{handler}")
		return id
	end

	# Hook up a server event handler
	# * server_event is the event to match
	# * priority is the priority of the handler (XCHAT_PRI_*)
	# * handler is a Method that will be invoked when the command is called
	# * Returns the handler id
	def hook_server(server_event, priority, handler)
		id = @plugin_interface.HookServer(server_event, priority, XCHAT_EAT_NONE)[0]
		@servers[id] = handler
		# puts("Using id #{id} for handler #{handler}")
		return id
	end

	# Hook up a print event handler
	# * server_event is the event to match
	# * priority is the priority of the handler (XCHAT_PRI_*)
	# * handler is a Method that will be invoked when the command is called
	# * Returns the handler id
	def hook_print(print_event, priority, handler)
		id = @plugin_interface.HookPrint(print_event, priority, XCHAT_EAT_NONE)[0]
		@prints[id] = handler
		# puts("Using id #{id} for handler #{handler}")
		return id
	end

	# Unhook an event handler
	# * id is the id of the handler to unhook
	def unhook(id)
		if((handlers = [@commands, @servers, @prints].detect{ |handlers| handlers[id] }))
			@plugin_interface.Unhook(id)
			handlers[id] = nil
		end
	end

	# Proxies a command event to a handler
	def handle_command(words, words_eol, id, context)
		begin
			if((handler = @commands[id]))
				# if(!@channels[context]) then @channels[context] = get_info('channel'); end
				# if(!@nicks[context]) then @nicks[context] = get_info('nick'); end

				# @plugin_interface.SetContext(context)
				return handler.call(words, words_eol, nil)
			# else
			# 	puts("No handler for id #{id}")
			# 	puts(@commands.inspect)
			end
		rescue
			# puts($!)
		end

		return XCHAT_EAT_NONE
	end

	# Proxies a server event to a handler
	def handle_server(words, words_eol, id, context)
		begin
			if((handler = @servers[id]))
				# if(!@channels[context]) then @channels[context] = get_info('channel'); end
				# if(!@nicks[context]) then @nicks[context] = get_info('nick'); end

				# Kernel.puts([words, id, context].inspect)
				# @plugin_interface.SetContext(context)
				return handler.call(words, words_eol, nil)
			# else
			# 	puts("No handler for id #{id}")
			# 	puts(@commands.inspect)
			end
		rescue
			# puts($!)
		end

		return XCHAT_EAT_NONE
	end

	# Proxies a print event to a handler
	def handle_print(words, id, context)
		begin
			if((handler = @prints[id]))
				# if(!@channels[context]) then @channels[context] = get_info('channel'); end
				# if(!@nicks[context]) then @nicks[context] = get_info('nick'); end

				# @plugin_interface.SetContext(context)
				return handler.call(words, nil)
			# else
			# 	puts("No handler for id #{id}")
			# 	puts(@commands.inspect)
			end
		rescue
			# puts($!)
		end

		return XCHAT_EAT_NONE
	end

	# Put a message to the xchat window if connected
	def puts(message, window=nil)
		begin
			if(@plugin_interface)
				@plugin_interface.Print(message)
			else
				Kernel.puts("#{message} (#{window})")
			end
		rescue
			# puts($!)
		end
	end

	# Invoke an irc command
	# * message is the command to be invoked, e.g. 'nick Tak'
	def command(message)
		begin
			rv = @plugin_interface.Command(message)
			return (rv && 0 < rv.size) ? rv[0] : XCHAT_EAT_ALL
		rescue
			# puts($!)
		end

		return XCHAT_EAT_ALL
	end

	# Get info from xchat
	# * request is the info requested, e.g. 'nick'
	def get_info(request)
		begin
			info = @plugin_interface.GetInfo(request)
			if(info && 0 < info.size)
				return info[0]
			else
				Kernel.puts("Bad response for #{request}")
			end
		rescue
			# puts($!)
		end
		
		return ''
	end

	def list_get(listname)
		begin
			return @plugin_interface.ListGet(listname)
		rescue
		end
	
		return nil
	end

	def list_next(list)
		if(!list) then return false; end

		begin
			return @plugin_interface.ListNext(list)
		rescue
		end

		return false
	end

	def list_str(list, request)
		if(!list) then return nil; end

		begin
			return @plugin_interface.ListStr(list, request)
		rescue
		end

		return nil
	end
	

	# Handles /SHORTBUS commands
	def shortbus_handler(words, words_eol, data)
		if(1 < words.size && words[1].strip().downcase() == 'quit') 
			puts('ShortBus: quitting.')
			exit(0)
		end
		return XCHAT_EAT_ALL
	end

	# Run the main event loop
	def run()
		@loop = DBus::Main.new()
		@loop << @bus
		@loop.run()
	end
end # ShortBus


# Testing stuff

def printstuff(words, words_eol, data)
	 Kernel.puts("Got #{words}")
end

def printprintstuff(words, data)
	 Kernel.puts("Got #{words}")
end

if(__FILE__ == $0)
	blah = ShortBus.new(:hexchat)
	blah.hook_command('BLAH', XCHAT_PRI_NORM, method(:printstuff), 'BLAH')
	blah.hook_server('PRIVMSG', XCHAT_PRI_NORM, method(:printstuff))
	blah.hook_print('Your Message', XCHAT_PRI_NORM, method(:printprintstuff))
	puts(blah.get_info('nick').inspect)
	blah.run()
end
