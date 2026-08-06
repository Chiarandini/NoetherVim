-- NoetherVim plugin: Gruvbox Colorscheme
-- Ships with core NoetherVim as the default theme, and stays the only
-- scheme in core: util/palette.lua hand-tunes the statusline against it and
-- highlights.lua special-cases it, so it is the look the distribution is
-- actually maintained against. The ui.colorscheme bundle adds the rest.
return {
	{
		"ellisonleao/gruvbox.nvim",
		lazy = true,
		priority = 1000,
		opts = {},
		config = function(_, opts)
			require("gruvbox").setup(opts)
		end,
	},
}
