-- NoetherVim plugin: Trouble Diagnostics
-- Quickfix / diagnostics list. Toggle: SearchLeader+q, navigate: [q / ]q
local SearchLeader = require("noethervim.util").search_leader

return {
	"folke/trouble.nvim",
	dependencies = "nvim-tree/nvim-web-devicons",
	cmd = "Trouble",
	keys = {
		{ SearchLeader .. "q", "<cmd>Trouble diagnostics toggle<cr>", desc = "[q]uickfix (Trouble)" },
		{ "]q", "<cmd>Trouble diagnostics next jump=true<cr>", desc = "next Trouble item" },
		{ "[q", "<cmd>Trouble diagnostics prev jump=true<cr>", desc = "prev Trouble item" },
	},
	opts = {},
}
