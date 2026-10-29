-- NoetherVim plugin: Treesitter Context
-- Sticky context: pins the enclosing scope at the top of the window.
-- Toggle: [oX / ]oX  or  <C-w>[T / <C-w>]T
return {
	"nvim-treesitter/nvim-treesitter-context",
	event = "BufReadPost",
	cmd = "TSContext",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	-- upstream replaced :TSContextEnable/:TSContextDisable with a single
	-- :TSContext {enable|disable|toggle} command
	specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("nvim-treesitter-context", {
		{ "[oX", "<cmd>TSContext enable<cr>", desc = "TSContext enable" },
		{ "]oX", "<cmd>TSContext disable<cr>", desc = "TSContext disable" },
		{ "<c-w>[T", "<cmd>TSContext enable<cr>", desc = "TSContext enable" },
		{ "<c-w>]T", "<cmd>TSContext disable<cr>", desc = "TSContext disable" },
	}) } },
	opts = {
		enable = true,
		max_lines = 4,
		min_window_height = 10,
		line_numbers = true,
		multiline_threshold = 20,
		trim_scope = "inner",
		mode = "topline",
		separator = nil,
		zindex = 20,
	},
	config = function(_, opts)
		require("treesitter-context").setup(opts)
	end,
}
