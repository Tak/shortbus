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
		}# Command

		dbus_method(:Print, 'in text:s') { |text|
		}# Print

		dbus_method(:GetInfo, 'in key:s, out value:s') { |key|
			['']
		}# GetInfo

		dbus_method(:GetPrefs, 'in key:s, out status:i, out str:s, out int:i') { |key|
			[0, '', 0]
		}# GetPrefs

		dbus_method(:HookCommand, 'in command:s, in priority:i, in help:s, in commandreturn:i, out id:u') { |command, priority, help, commandreturn|
			[0]
		}# HookCommand

		dbus_method(:HookServer, 'in event:s, in priority:i, in eventreturn:i, out id:u') { |event, priority, eventreturn|
			[0]
		}# HookServer

		dbus_method(:HookPrint, 'in event:s, in priority:i, in eventreturn:i, out id:u') { |event, priority, eventreturn|
			[0]
		}# HookPrint

		dbus_method(:Unhook, 'in id:u') { |id|
		}# Unhook

	}# tak.weebus.plugin

	def initialize(path, name, filename, description, version)
		super(path)

		@path = path
		@name = name
		@filename = filename
		@description = description
		@version = version
	end

end
