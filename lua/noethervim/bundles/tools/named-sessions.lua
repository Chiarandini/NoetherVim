---@bundle named-sessions
---@desc named sessions (mini.sessions) and :SaveSession
---@about mini.sessions keeps sessions under names you choose: :SaveSession [name]
---       writes one and the dashboard's Sessions key picks one to load. Without
---       it, core still restores the last session of a directory (the
---       dashboard's Restore Session).
---@requires none
-- NoetherVim bundle: named sessions
-- Enable with: { import = "noethervim.bundles.tools.named-sessions" }

--- The dashboard's Sessions key, after Restore Session.
local function dashboard_key(_, opts)
	local keys = vim.tbl_get(opts, "dashboard", "preset", "keys")
	if not keys then return end
	local at = #keys + 1
	for i, k in ipairs(keys) do
		if k.key == "r" then at = i + 1 break end
	end
	table.insert(keys, at, { icon = "󰆓 ", key = "s", desc = "Sessions",
		action = function() require("mini.sessions").select() end })
end

return {
	'nvim-mini/mini.sessions',
	version = '*',
	event = 'VeryLazy',
	opts = {},
	specs = { { "snacks.nvim", optional = true, opts = dashboard_key } },
	config = function(_, opts)
		local mini_sessions = require('mini.sessions')
		mini_sessions.setup(opts)
		-- Create the User Command, unless you already have one by this name
		require('noethervim.default').command('SaveSession', function(opts)
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
