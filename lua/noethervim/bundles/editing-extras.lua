-- NoetherVim bundle: Editing Extras
-- Enable with: { import = "noethervim.bundles.editing-extras" }
--
-- Provides:
--   argmark:          mark and navigate function argument positions
--     SearchLeader+ae edit argument marks
--     <leader>aa      add argument mark
--     <leader>ax      remove argument mark
--     <leader>aX      clear all argument marks
--     [a / ]a         cycle through arguments
--
--   comment-box.nvim: decorative ASCII comment boxes
--     <leader>bb      left-aligned fixed-size box
--     <leader>bl      centered line separator
local SearchLeader = require("noethervim.util").search_leader

return {

	-- ── Argmark ───────────────────────────────────────────────────────────────
	{
		"BirdeeHub/argmark",
		event = "BufReadPost",
		opts = {
			keys = {
				edit = SearchLeader .. "ae",
				rm = "<leader>ax",
				go = "<leader>a<leader>",
				add = "<leader>aa",
				copy = "<leader>ay",
				clear = "<leader>aX",
				add_windows = "<leader>aA",
			},
			edit_opts = {
				keys = {
					cycle_right = "]a",
					cycle_left = "[a",
					go = "<CR>",
					quit = "Q",
					exit = "q",
				}
			}
		},
	},

	-- ── Comment Box ───────────────────────────────────────────────────────────
	{
		"LudoPinelli/comment-box.nvim",
		event  = "VeryLazy",
		opts = {},
		config = function(_, opts)
			require("comment-box").setup(opts)
			vim.keymap.set({ "n", "v" }, "<Leader>bb", "<cmd>CBalbox7<cr>", { desc = "comment box" })
			vim.keymap.set("n",          "<Leader>bl", "<cmd>CBcline<cr>",  { desc = "comment line" })
		end,
	},
}
