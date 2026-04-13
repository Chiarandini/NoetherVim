-- NoetherVim plugin: Mini Sessions
-- Session management via mini.sessions. Save with :SaveSession [name].
return {
	'nvim-mini/mini.sessions',
	version = '*',
	event = 'VeryLazy',
	opts = {},
	config = function(_, opts)
		local mini_sessions = require('mini.sessions')
		mini_sessions.setup(opts)
		-- Create the User Command
		vim.api.nvim_create_user_command('SaveSession', function(opts)
		  local session_name = opts.args

		  if session_name == "" then
			-- If no name provided, ask for one via input
			vim.ui.input({ prompt = 'Enter session name: ' }, function(input)
			  if input and input ~= "" then
				mini_sessions.write(input)
			  end
			end)
		  else
			-- Save with the provided name
			mini_sessions.write(session_name)
		  end
		end, {
		  nargs = '?', -- '?' means the argument is optional (allows interactive mode)
		  desc = "Save a mini.session with a specific name",
		  -- Optional: Autocomplete with existing session names (useful for overwriting)
		  complete = function(arg_lead, cmd_line, cursor_pos)
			local detected = mini_sessions.detected
			local matches = {}
			for name, _ in pairs(detected) do
			  if name:find(arg_lead, 1, true) then
				table.insert(matches, name)
			  end
			end
			return matches
		  end
		})

	end
}
