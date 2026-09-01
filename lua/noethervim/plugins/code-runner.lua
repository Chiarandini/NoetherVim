-- NoetherVim plugin: Code Runner
--  ╔══════════════════════════════════════════════════════════╗
--  ║                       code runner                        ║
--  ╚══════════════════════════════════════════════════════════╝
-- Run the current file in a float, or send it to a betterTerm terminal.
--
-- What each language runs is not decided here: it comes from
-- `noethervim.util.run`, which the task-runner bundle reads too, so `cargo`
-- and `go.mod` are understood once rather than once per runner.
--
-- Both keys live under `<leader>r` (Run/REPL), alongside the REPL bundle's
-- `rs`/`rr`/`rF`/`rh` and the task-runner bundle's `rf`/`rp`. Both are
-- declared in `keys` rather than one of them in `config`: `keys` is the only
-- load trigger, so a map created inside `config` would not exist until the
-- other one fired.

local run = require("noethervim.util.run")

--- Hand code_runner a fully-built command for `ft`.
---
--- code_runner appends the buffer path to any command it did not substitute a
--- `$var` into, which would duplicate the filename our command already
--- carries. `$end` expands to the empty string and counts as a substitution,
--- so it suppresses that append without adding anything.
---@param ft string
---@return fun():string|nil
local function command_for(ft)
	return function()
		local cmd, cwd = run.command("file", 0)
		if not cmd then
			vim.notify("No runner for filetype: " .. ft, vim.log.levels.WARN)
			return nil
		end
		return ("cd %s && %s $end"):format(vim.fn.shellescape(cwd), cmd)
	end
end

-- code_runner keys off the filetype table it is given, so every language
-- util/run knows about has to appear here for `:RunCode` to reach it.
local filetype = {}
for ft in pairs(run.languages) do
	filetype[ft] = command_for(ft)
end

return { 'CRAG666/code_runner.nvim',
	keys = {
		{ '<leader>rc', '<cmd>RunCode<cr>', desc = 'run [c]ode' },
		{
			'<leader>rT',
			function()
				local ok, bt = pcall(require, "betterTerm")
				if not ok then
					vim.notify("betterTerm not available (enable noethervim.bundles.terminal.better-term)",
						vim.log.levels.WARN)
					return
				end
				local cmd = require("code_runner.commands").get_filetype_command()
				if not cmd or cmd == "" then return end
				bt.send(cmd, 1, { clean = false, interrupt = true })
			end,
			desc = 'run in [T]erminal (betterTerm)',
		},
	},
	opts = {
		mode = 'float',
		float = { border = "double" },
		filetype = filetype,
	},
}
