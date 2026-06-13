-- NoetherVim plugin: Treesitter Context
-- Sticky context: pins the enclosing scope at the top of the window.
-- Toggle: [oX / ]oX  or  <C-w>[T / <C-w>]T
return {
	"nvim-treesitter/nvim-treesitter-context",
	event = "BufReadPost",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
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
		-- upstream replaced :TSContextEnable/:TSContextDisable with a
		-- single :TSContext {enable|disable|toggle} command
		vim.keymap.set("n", "[oX", "<cmd>TSContext enable<cr>" , {desc = "TSContext enable"})
		vim.keymap.set("n", "]oX", "<cmd>TSContext disable<cr>", {desc = "TSContext disable"})
		vim.keymap.set("n", "<c-w>[T", "<cmd>TSContext enable<cr>", {desc = "TSContext enable"})
		vim.keymap.set("n", "<c-w>]T", "<cmd>TSContext disable<cr>", {desc = "TSContext disable"})
	end,
}
