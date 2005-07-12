require 'msf/core'
require 'msf/base'
require 'msf/ui'
require 'msf/ui/console/shell'
require 'msf/ui/console/command_dispatcher'
require 'msf/ui/console/table'
require 'find'

module Msf
module Ui
module Console


###
#
# Driver
# ------
#
# This class implements a user interface driver on a console interface.
#
###
class Driver < Msf::Ui::Driver

	include Msf::Ui::Console::Shell

	def initialize(prompt = "%umsf", prompt_char = ">%c")
		# Initialize attributes
		self.framework        = Msf::Framework.new
		self.dispatcher_stack = []

		# Add the core command dispatcher as the root of the dispatcher
		# stack
		enstack_dispatcher(CommandDispatcher::Core)

		# Initialize the super
		super
	end

	#
	# Performs tab completion on shell input if supported
	#
	def tab_complete(str)
		items = []

		# Next, try to match internal command or value completion
		# Enumerate each entry in the dispatcher stack
		dispatcher_stack.each { |dispatcher|
			# If it supports commands, query them all
			if (dispatcher.respond_to?('commands'))
				items.concat(dispatcher.commands.to_a.map { |x| x[0] })
			end

			# If the dispatcher has custom tab completion items, use them
			items.concat(dispatcher.tab_complete_items || [])
		}

		items.find_all { |e| 
			e =~ /^#{str}/
		}
	end

	# Run a single command line
	def run_single(line)
		arguments = parse_line(line)
		method    = arguments.shift
		found     = false

		reset_color if (supports_color?)

		if (method)
			entries = dispatcher_stack.length

			dispatcher_stack.each { |dispatcher|
				begin
					if (dispatcher.respond_to?('cmd_' + method))
						eval("
							dispatcher.#{'cmd_' + method}(arguments)
							found = true")
					end
				rescue
					output.print_error("Error while running command #{method}: #{$!}\n#{$@.join("\n")}\n.")
				end

				# If the dispatcher stack changed as a result of this command,
				# break out
				break if (dispatcher_stack.length != entries)
			}

			if (!found)
				output.print_error("Unknown command: #{method}.")
			end
		end

		return found
	end

	# Push a dispatcher to the front of the stack
	def enstack_dispatcher(dispatcher)
		self.dispatcher_stack.unshift(dispatcher.new(self))
	end

	# Pop a dispatcher from the front of the stacker
	def destack_dispatcher
		self.dispatcher_stack.shift
	end

	attr_reader   :dispatcher_stack, :framework

protected

	attr_writer   :dispatcher_stack, :framework

end

end
end
end
