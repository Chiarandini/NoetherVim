-- NoetherVim bundle: REPL
-- Enable with: { import = "noethervim.bundles.repl" }
--
-- Provides iron.nvim — interactive REPL for any language.
--   <leader>rs   start REPL
--   <leader>rr   restart REPL
--   <leader>rF   focus REPL           (capital F; <leader>rf is reserved for run-file)
--   <leader>rh   hide REPL
--
-- Send-to-REPL keymaps use <localleader>s* (motion, visual, file, line).

return {
	{
		"Vigemus/iron.nvim",
		keys = {
			{ "<leader>rs", "<cmd>IronRepl<cr>",    desc = "REPL [s]tart" },
			{ "<leader>rr", "<cmd>IronRestart<cr>", desc = "REPL [r]estart" },
			{ "<leader>rF", "<cmd>IronFocus<cr>",   desc = "REPL [F]ocus" },
			{ "<leader>rh", "<cmd>IronHide<cr>",    desc = "REPL [h]ide" },
		},
		cmd = { "IronRepl", "IronHide", "IronFocus", "IronRestart" },
		opts = {
			config = {
				scratch_repl = true,
				repl_definition = {
					sh     = { command = { vim.o.shell } },
				},
				highlight        = { italic = true },
				ignore_blank_lines = true,
			},
			keymaps = {
				send_motion       = "<localleader>sc",
				visual_send       = "<localleader>sc",
				send_file         = "<localleader>sf",
				send_line         = "<localleader>sl",
				send_until_cursor = "<localleader>su",
				send_mark         = "<localleader>sm",
				mark_motion       = "<localleader>mc",
				mark_visual       = "<localleader>mc",
				remove_mark       = "<localleader>md",
				cr                = "<localleader>s<cr>",
				interrupt         = "<localleader>s<space>",
				exit              = "<localleader>sq",
				clear             = "<localleader>cl",
			},
		},
		config = function(_, opts)
			opts.config.repl_definition.python = {
				command = { "python3" },
				format  = require("iron.fts.common").bracketed_paste_python,
			}
			opts.config.repl_open_cmd = require("iron.view").bottom(15)
			require("iron.core").setup(opts)
		end,
	},
}
