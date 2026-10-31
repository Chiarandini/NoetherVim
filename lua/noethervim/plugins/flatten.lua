-- NoetherVim plugin: flatten.nvim

return {
	{ -- when oppening nvim in a terminal in nvim, opens it in new buffer
		"willothy/flatten.nvim",
		config = true,
		event = "TermOpen",
		-- or pass configuration with
		-- opts = {  }
		-- Ensure that it runs first to minimize delay when opening file from terminal
		priority = 1001,
	},
}
