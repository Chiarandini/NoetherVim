-- NoetherVim plugin: Trouble Diagnostics
-- Multi-file diagnostic panel.  Toggle: <C-w>Q
-- Navigate: ]q / [q (context-aware — Trouble when open, quickfix otherwise)

return {
	"folke/trouble.nvim",
	dependencies = "nvim-tree/nvim-web-devicons",
	cmd = "Trouble",
	keys = {
		{ "<C-w>Q", "<cmd>Trouble diagnostics toggle<cr>", desc = "Trouble diagnostics panel" },
	},
	opts = {},
}
