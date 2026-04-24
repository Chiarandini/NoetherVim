-- NoetherVim plugin: Dead Column Guide
-- Fading colorcolumn guide at textwidth. Disabled by default; opt in with [oG.
-- State persisted to stdpath("state")/noethervim_deadcolumn.
local state_file = vim.fn.stdpath("state") .. "/noethervim_deadcolumn"

local function is_disabled()
	if vim.fn.filereadable(state_file) == 0 then return true end
	return vim.fn.readfile(state_file, "", 1)[1] ~= "1"
end

return {
	"Bekaboo/deadcolumn.nvim",
	event = "VeryLazy",
	opts = {
		scope = 'line',
		modes = function(mode)
			return mode:find('^[ictRss\x13]') ~= nil
		end,
		blending = {
			threshold = 0.75,
			colorcode = '#000000',
			hlgroup = { 'Normal', 'bg' },
		},
		warning = {
			alpha = 0.4,
			offset = 0,
			colorcode = '#FF0000',
			hlgroup = { 'Error', 'bg' },
		},
		extra = { follow_tw = "+1" },
	},
	config = function(_, opts)
		-- Always populate configs.opts so [oG can re-enable with user opts.
		-- When disabled, skip setup() so no augroup/autocmds are created.
		if is_disabled() then
			require("deadcolumn").configs.set_options(opts)
		else
			require("deadcolumn").setup(opts)
		end
	end,
}
