-- NoetherVim plugin: Dead Column Guide
-- Fading colorcolumn guide at textwidth. Disabled by default; opt in with [oG.
-- State persisted to stdpath("state")/noethervim/deadcolumn.
local state_file = vim.fn.stdpath("state") .. "/noethervim/deadcolumn"

local function is_disabled()
	if vim.fn.filereadable(state_file) == 0 then return true end
	return vim.fn.readfile(state_file, "", 1)[1] ~= "1"
end

local function enable()
	local dc = require("deadcolumn")
	dc.setup(dc.configs.opts)
	local ftw = dc.configs.opts.extra.follow_tw
	if ftw then
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.bo[vim.api.nvim_win_get_buf(win)].textwidth ~= 0 then
				vim.wo[win].colorcolumn = ftw
			end
		end
	end
	vim.fn.mkdir(vim.fs.dirname(state_file), "p")
	vim.fn.writefile({ "1" }, state_file)
end

local function disable()
	vim.api.nvim_create_augroup("deadcolumn", { clear = true })
	-- follow_tw autocmds are created by deadcolumn without a group;
	-- remove them by desc so they don't re-set colorcolumn on BufEnter.
	for _, ev in ipairs({ "BufEnter", "OptionSet" }) do
		for _, au in ipairs(vim.api.nvim_get_autocmds({ event = ev })) do
			if au.desc == "Set colorcolumn according to textwidth." then
				vim.api.nvim_del_autocmd(au.id)
			end
		end
	end
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		vim.wo[win].colorcolumn = ""
		vim.wo[win].winhl = vim.wo[win].winhl:gsub("ColorColumn:[^,]*", "")
			:gsub(",+", ","):gsub("^,", ""):gsub(",$", "")
	end
	vim.fn.mkdir(vim.fs.dirname(state_file), "p")
	vim.fn.writefile({ "0" }, state_file)
end

local icons = require("noethervim.util").icons

return {
	"Bekaboo/deadcolumn.nvim",
	event = "VeryLazy",
	specs = {
		{ "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("deadcolumn.nvim",
			require("noethervim.toggles").rows("oG", enable, disable, "deadcolumn (Guide)")) },
		{ "which-key.nvim", optional = true, opts = require("noethervim.util").labels({
			{ "[oG", icon = { icon = icons.options_on, color = "yellow" }, desc = "deadcolumn ON (Guide)" },
			{ "]oG", icon = { icon = icons.options_off, color = "yellow" }, desc = "deadcolumn OFF (Guide)" },
		}) },
	},
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
