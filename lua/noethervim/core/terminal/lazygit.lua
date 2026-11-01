-- NoetherVim plugin: lazygit and git browse (snacks)

return {
	{
		"folke/snacks.nvim",
		opts = { gitbrowse = { enabled = true } },
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("snacks.nvim", {
			{ "<c-w><c-g>", "<cmd>lua Snacks.terminal('lazygit')<cr>", desc = "lazygit" },
		}) } },
	},
}
