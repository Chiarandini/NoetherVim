-- NoetherVim plugin: outline.nvim (symbol outline)

return {
	{
		"hedyhli/outline.nvim",
		cmd = { "Outline", "OutlineOpen" },
		opts = {
			outline_window = { auto_close = true },
			preview_window = { auto_preview = true },
			symbol_folding = { autofold_depth = 1 },
		},
	},
}
