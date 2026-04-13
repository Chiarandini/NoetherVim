-- NoetherVim bundle: Neoclip (clipboard history)
-- Enable with: { import = "noethervim.bundles.neoclip" }
--
-- Persistent clipboard history via Telescope.
--   <c-s-v>  (insert mode) — open clipboard history picker

return {
	{
		"AckslD/nvim-neoclip.lua",
		dependencies = {
			{ "kkharji/sqlite.lua",         module = "sqlite" },
			{ "nvim-telescope/telescope.nvim" },
		},
		keys = {
			{ "<c-s-v>", "<cmd>Telescope neoclip theme=cursor<cr>", mode = "i", desc = "clipboard history" },
		},
		lazy   = true,
		opts = {
			history                 = 1000,
			enable_persistent_history = false,
			length_limit            = 1048576,
			continuous_sync         = false,
			db_path                 = vim.fn.stdpath("data") .. "/databases/neoclip.sqlite3",
			filter                  = nil,
			preview                 = true,
			prompt                  = nil,
			default_register        = '"',
			default_register_macros = "q",
			enable_macro_history    = true,
			content_spec_column     = false,
			on_select  = { move_to_front = false, close_telescope = true },
			on_paste   = { set_reg = false, move_to_front = false, close_telescope = true },
			on_replay  = { set_reg = false, move_to_front = false, close_telescope = true },
			on_custom_action = { close_telescope = true },
			keys = {
				telescope = {
					i = {
						select  = "<c-y>",
						paste   = "<cr>",
						replay  = "<c-q>",
						delete  = "<c-d>",
						edit    = "<c-e>",
						custom  = {},
					},
					n = {
						select       = "<cr>",
						paste        = "p",
						paste_behind = "P",
						replay       = "q",
						delete       = "d",
						edit         = "e",
						custom       = {},
					},
				},
			},
		},
	},
}
