-- NoetherVim plugin: vim-repeat

return {
	-- better "." feature
	--
	-- vim-repeat maps . u U <C-R> the first time a plugin calls repeat#set,
	-- unless a mapping already leads to its <Plug> targets. The four
	-- <Plug>(noethervim-repeat-*) rows are such mappings, so it never does;
	-- the keys themselves are rows that call it.
	{
		"tpope/vim-repeat",
		lazy = false,
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("vim-repeat", {
			{ "<Plug>(noethervim-repeat-dot)",      "<Plug>(RepeatDot)" },
			{ "<Plug>(noethervim-repeat-undo)",     "<Plug>(RepeatUndo)" },
			{ "<Plug>(noethervim-repeat-undoline)", "<Plug>(RepeatUndoLine)" },
			{ "<Plug>(noethervim-repeat-redo)",     "<Plug>(RepeatRedo)" },
			{ ".", function()
				if vim.fn["repeat#run"](vim.v.count) == 0 then
					vim.notify(vim.fn["repeat#errmsg"](), vim.log.levels.ERROR)
				end
			end, desc = "repeat, plugin actions included", set = "remaps" },
			{ "u",     function() return vim.fn["repeat#wrap"]("u", vim.v.count) end,
			  expr = true, desc = "undo", set = "remaps" },
			{ "U",     function() return vim.fn["repeat#wrap"]("U", vim.v.count) end,
			  expr = true, desc = "undo line", set = "remaps" },
			{ "<C-R>", function() return vim.fn["repeat#wrap"]("\18", vim.v.count) end,
			  expr = true, desc = "redo", set = "remaps" },
		}) } },
	},
}
