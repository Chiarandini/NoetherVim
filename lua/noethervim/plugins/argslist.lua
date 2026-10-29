local SearchLeader = require("noethervim.util").search_leader

-- argmark maps its keys itself in setup(); they are off there and rows here.
local edit_opts

---@param fn string argmark function
---@param arg? fun(): any its argument, read when the key is pressed
---@param level? integer
local function argmark(fn, arg, level)
	return function()
		local mod = require("argmark")
		local ok, err = pcall(mod[fn], arg and arg())
		if not ok then vim.notify(err or ("argmark: " .. fn .. " failed"), level or vim.log.levels.WARN) end
	end
end

local function count() return vim.v.count end

return {
	'BirdeeHub/argmark',
	lazy = true,
	opts = {
		keys = { edit = false, rm = false, go = false, add = false, copy = false, clear = false, add_windows = false },
		edit_opts = {
			keys = {
				cycle_right = "]a",
				cycle_left = "[a",
				go = "<CR>",
				quit = "Q", -- save and quit
				exit = "q", -- exit
				-- :write or :w also saves, but doesn't quit
			}
		}
	},
	config = function(_, opts)
		edit_opts = opts.edit_opts
		require("argmark").setup(opts)
	end,
	specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("argmark", {
		{ SearchLeader .. "ae", argmark("edit", function() return edit_opts end, vim.log.levels.ERROR),
		  silent = true, desc = "edit arglist in floating window" },
		{ "<leader>ax", argmark("rm", count),
		  silent = true, desc = "Remove buffer at count (or current) from arglist" },
		{ "<leader>a<leader>", argmark("go", count),
		  silent = true, desc = "Go to buffer at count in arglist" },
		{ "<leader>aa", argmark("add", count, vim.log.levels.ERROR),
		  silent = true, desc = "Add buffer (count or current) to arglist" },
		{ "<leader>ac", argmark("copy", count, vim.log.levels.ERROR),
		  silent = true, desc = "Copy (count or global) arglist to current (or new) local arglist" },
		{ "<leader>aX", argmark("rm", function() return "*" end), desc = "Clear arglist" },
		{ "<leader>aA", argmark("add_windows"), desc = "Add current buffers for all windows to arglist" },
	}) } },
}
