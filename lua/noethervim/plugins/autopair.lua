-- NoetherVim plugin: Auto Pairs
-- Auto-close brackets, quotes, and other pairs on insert.
return { "windwp/nvim-autopairs",
    event = "InsertEnter",
	opts = {
		disable_filetype = { "TelescopePrompt", "snacks_picker_input", "tex" },
	},
	config = function (_, opts)
		require('nvim-autopairs').setup(opts)
	end
}
