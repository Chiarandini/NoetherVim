-- NoetherVim plugin: nvim-surround

return {
	{ -- https://github.com/kylechui/nvim-surround/blob/main/lua/nvim-surround/config.lua
		"kylechui/nvim-surround",
		event = "VeryLazy",
		opts = {},
		specs = {
			{ "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("nvim-surround", {
				{ "<C-g>s", "<Plug>(nvim-surround-insert)",          mode = "i", desc = "surround the cursor" },
				{ "<C-g>S", "<Plug>(nvim-surround-insert-line)",     mode = "i", desc = "surround the cursor, on new lines" },
				{ "ys",     "<Plug>(nvim-surround-normal)",          desc = "surround a motion" },
				{ "yS",     "<Plug>(nvim-surround-normal-line)",     desc = "surround a motion, on new lines" },
				{ "yc",     "<Plug>(nvim-surround-normal-cur)",      desc = "surround the current line" },
				{ "yC",     "<Plug>(nvim-surround-normal-cur-line)", desc = "surround the current line, on new lines" },
				{ "ds",     "<Plug>(nvim-surround-delete)",          desc = "delete a surrounding pair" },
				{ "cs",     "<Plug>(nvim-surround-change)",          desc = "change a surrounding pair" },
				{ "cS",     "<Plug>(nvim-surround-change-line)",     desc = "change a surrounding pair, on new lines" },
				{ "S",      "<Plug>(nvim-surround-visual)",          mode = "x", desc = "surround the selection", set = "remaps" },
				{ "gS",     "<Plug>(nvim-surround-visual-line)",     mode = "x", desc = "surround the selection, on new lines" },
			}, { g = { nvim_surround_no_mappings = true } }) },
		},
	},
}
