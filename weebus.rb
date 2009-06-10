#!/usr/bin/env ruby

# This program is free software; you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

require 'dbus'

class WeeBus < DBus::Object
	@bus = DBus::SessionBus.instance
	@service = @bus.request_service('tak.weebus')
	@connections = {}
	@plugins = {}
	@index = 0
	@handlers = []

	# Create an interface.
	dbus_interface('tak.weebus.connection') {
		dbus_method(:Connect, 'in filename:s, in name:s, in description:s, in version:s, out path') { |filename, name, description, version|
			if(@path)
				['']
			else
				path = "/tak/weebus/WeeBus#{index}"
				@connections[name] = [filename, description, version, path]
				index += 1
				@plugins[name] = WeeBus.new(path)
				@service.export(@plugins[name])
				[path]
			end
		}# Connect

		dbus_method(:Disconnect, '') {
			if(@path)
				Kernel.puts("Disconnecting #{@path}")
			else
				Kernel.puts('Disconnect called.')
			end
		}# Disconnect
	}# tak.weebus.connection

	dbus_interface('tak.weebus.plugin') {
		dbus_method(:Command, 'in command:s') { |command|
			Weechat.command(command)
		}# Command

		dbus_method(:Print, 'in text:s') { |text|
			Weechat.print(text)
		}# Print

		dbus_method(:GetInfo, 'in key:s, out value:s') { |key|
			[Weechat.get_info(key)]
		}# GetInfo

		dbus_method(:GetPrefs, 'in key:s, out status:i, out str:s, out int:i') { |key|
			pref = Weechat.get_config(key)
			[('' == pref) ? 0 : 1, pref, 0]
		}# GetPrefs

		dbus_method(:HookCommand, 'in command:s, in priority:i, in help:s, in commandreturn:i, out id:u') { |command, priority, help, commandreturn|
			success = Weechat.add_command_handler(command, 'weechat_command_handler', help)
			if(1 == success) then @handlers << [command, 'weechat_command_handler']; end
			id = @handlers.size * success
			[id]
		}# HookCommand

		dbus_method(:HookServer, 'in event:s, in priority:i, in eventreturn:i, out id:u') { |event, priority, eventreturn|
			success = Weechat.add_message_handler(event, 'weechat_message_handler')
			if(1 == success) then @handlers << [event, 'weechat_message_handler']; end
			id = @handlers.size * success
			[id]
		}# HookServer

		dbus_method(:HookPrint, 'in event:s, in priority:i, in eventreturn:i, out id:u') { |event, priority, eventreturn|
			success = Weechat.add_message_handler(event, 'weechat_message_handler')
			if(1 == success) then @handlers << [event, 'weechat_message_handler']; end
			id = @handlers.size * success
			[id]
		}# HookPrint

		dbus_method(:Unhook, 'in id:u') { |id|
			if(@handlers && id < @handlers.size)
				Weechat.remove_handler(@handlers[id][0], @handlers[id][1])
				@handlers.slice!(id)
			end
		}# Unhook

	}# tak.weebus.plugin

	def initialize(path, name, filename, description, version)
		super(path)

		@path = path
		@name = name
		@filename = filename
		@description = description
		@version = version
	end # initialize

end

def weechat_init()
	Weechat.register('WeeBus', '0.1', 'weechat_finalize', 'Weechat needs help to ride the ShortBus!')
end # weechat_init

