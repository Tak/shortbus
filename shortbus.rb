#!/usr/bin/env ruby

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

# ShortBus is a dbus plugin client for xchat and ruby.
class ShortBus
	def initialize()
		@bus = DBus::SessionBus.instance
		@service = @bus.service('org.xchat.service')
		@service.introspect()
		# puts('== end service ==')
		connection_object = @service.object('/org/xchat/Remote')
		connection_object.introspect()
		# puts('== end object ==')

		while(!(@connection_interface = connection_object['org.xchat.connection']))
			puts('ShortBus: Sleeping')
			sleep(0.1)
		end

		plugin_path = @connection_interface.Connect(__FILE__, 'ShortBus', 'Ruby XChat-DBus Plugin', '0.1')[0]
		ObjectSpace.define_finalizer(self, proc{ |id| finalize() })

		@plugin_object = @service.object(plugin_path)
		@plugin_object.introspect()
		# puts('== end object ==')
		while(!(@plugin_interface = @plugin_object['org.xchat.plugin']))
			puts('ShortBus: Sleeping')
			sleep(0.1)
		end
		while(!(@connection_interface = @plugin_object['org.xchat.connection']))
			puts('ShortBus: Sleeping')
			sleep(0.1)
		end

		@commands = {}
		@servers = {}
		@prints = {}
		@plugin_interface.on_signal(@bus, 'CommandSignal'){ |words, words_eol, id, context| puts("Got command signal"); handle_command(words, words_eol, id, context) }
		@plugin_interface.on_signal(@bus, 'ServerSignal'){ |words, words_eol, id, context| puts("Got server signal"); handle_server(words, words_eol, id, context) }
		@plugin_interface.on_signal(@bus, 'PrintSignal'){ |words, id, context| puts("Got print signal"); handle_print(words, id, context) }
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
	def hook_command(command, priority, handler, help)
		id = @plugin_interface.HookCommand(command, priority, help, XCHAT_EAT_ALL)[0]
		@commands[id] = handler
		# puts("Using id #{id} for handler #{handler}")
		return id
	end

	def hook_server(command, priority, handler)
		id = @plugin_interface.HookServer(command, priority, XCHAT_EAT_NONE)[0]
		@servers[id] = handler
		# puts("Using id #{id} for handler #{handler}")
		return id
	end

	def hook_print(command, priority, handler)
		id = @plugin_interface.HookPrint(command, priority, XCHAT_EAT_NONE)[0]
		@prints[id] = handler
		# puts("Using id #{id} for handler #{handler}")
		return id
	end

	def unhook(id)
		if((handlers = [@commands, @servers, @prints].detect{ |handlers| handlers[id] }))
			@plugin_interface.Unhook(id)
			handlers[id] = nil
		end
	end

	def handle_command(words, words_eol, id, context)
		@plugin_interface.SetContext(context)
		
		if((handler = @commands[id]))
			return handler.call(words, words_eol, nil)
		# else
		# 	puts("No handler for id #{id}")
		# 	puts(@commands.inspect)
		end
	end

	def handle_server(words, words_eol, id, context)
		@plugin_interface.SetContext(context)
		
		if((handler = @servers[id]))
			return handler.call(words, words_eol, nil)
		# else
		# 	puts("No handler for id #{id}")
		# 	puts(@commands.inspect)
		end
	end

	def handle_print(words, id, context)
		@plugin_interface.SetContext(context)
		
		if((handler = @prints[id]))
			return handler.call(words, nil)
		# else
		# 	puts("No handler for id #{id}")
		# 	puts(@commands.inspect)
		end
	end

	def puts(message)
		if(@plugin_interface)
			@plugin_interface.Print(message)
		else
			Kernel.puts(message)
		end
	end

	def command(message)
		return @plugin_interface.Command(message)[0]
	end

	def get_info(request)
		return @plugin_interface.GetInfo(request)[0]
	end

	def shortbus_handler(words, words_eol, data)
		if(1 < words.size && words[1].strip().downcase() == 'quit') 
			puts('ShortBus: quitting.')
			exit(0)
		end
		return XCHAT_EAT_ALL
	end

	def run()
		@loop = DBus::Main.new()
		@loop << @bus
		@loop.run()
	end
end # ShortBus

def printstuff(words, words_eol, data)
	 Kernel.puts("Got #{words}")
end

def printprintstuff(words, data)
	 Kernel.puts("Got #{words}")
end

if(__FILE__ == $0)
	blah = ShortBus.new()
	blah.hook_command('BLAH', XCHAT_PRI_NORM, method(:printstuff), 'BLAH')
	blah.hook_server('PRIVMSG', XCHAT_PRI_NORM, method(:printstuff))
	blah.hook_print('Your Message', XCHAT_PRI_NORM, method(:printprintstuff))
	puts(blah.get_info('nick').inspect)
	blah.run()
end
