-- NoetherVim plugin: neogen (documentation comments)

return {
	{
		-- context-smart comment adder
		"danymat/neogen",
		cmd = "Neogen",
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("neogen", {
			{ "<leader>Rd", function() require("neogen").generate({}) end,
				desc = "[R]efactor: generate [d]oc comment", silent = true },
		}) } },
		dependencies = "nvim-treesitter/nvim-treesitter",
		opts = {
			snippet_engine = "luasnip",
		},
		-- Uncomment next line if you want to follow only stable versions
		-- version = "*"
	},
}
