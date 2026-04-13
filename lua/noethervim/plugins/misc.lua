-- NoetherVim plugin: Miscellaneous
--  ╔══════════════════════════════════════════════════════════╗
--  ║                      miscellaneous                       ║
--  ╚══════════════════════════════════════════════════════════╝

return {
	{ -- to dim inactive window
		"levouh/tint.nvim",
		event = "VeryLazy",
		keys = {
			-- tint toggle is [o<c-t> / ]o<c-t> — defined in noethervim/toggles.lua
		},
		opts = {
			tint = -5,                                      -- Darken colors, use a positive value to brighten
			saturation = 0.6,                               -- Saturation to preserve
			tint_background_colors = true,                  -- Tint background portions of highlight groups
			highlight_ignore_patterns = { "WinSeparator", "Status.*" }, -- Highlight group patterns to ignore, see `string.find`
		},
		config = function(_, opts)
			opts.transforms = require("tint").transforms.SATURATE_TINT
			opts.window_ignore_function = function(winid)
				local bufid = vim.api.nvim_win_get_buf(winid)
				local buftype = vim.bo[bufid].buftype
				local floating = vim.api.nvim_win_get_config(winid).relative ~= ""
				return buftype == "terminal" or floating
			end
			require("tint").setup(opts)
		end,
	},

	{ -- for less distractions
		"folke/zen-mode.nvim",
		cmd          = "ZenMode",
		dependencies = { "folke/twilight.nvim" },
		keys         = { { "<leader>z", "<cmd>ZenMode<cr>", desc = "ZenMode" } },
	},

	{                   -- to look pretty
		"anuvyklack/windows.nvim",
		event = "BufReadPost",
		dependencies = {
			"anuvyklack/middleclass",
			"anuvyklack/animation.nvim",
		},
		opts = {
			autowidth = {
				enable   = false,
				winwidth = 15,
				filetype = { help = 2 },
			},
			ignore = {
				buftype  = { "quickfix" },
				filetype = { "NvimTree", "neo-tree", "undotree", "gundo", "mundo" },
			},
			animation = {
				enable   = true,
				duration = 100,
				fps      = 30,
				easing   = "in_out_sine",
			},
		},
		config = function(_, opts)
			vim.o.winwidth    = 10
			vim.o.winminwidth = 10
			vim.o.equalalways = false
			require("windows").setup(opts)
			local function cmd(command)
				return table.concat({ "<Cmd>", command, "<CR>" })
			end
			vim.keymap.set("n", "<C-w>z",  cmd("WindowsMaximize"))
			vim.keymap.set("n", "<C-w>_",  cmd("WindowsMaximizeVertically"))
			vim.keymap.set("n", "<C-w>|",  cmd("WindowsMaximizeHorizontally"))
			vim.keymap.set("n", "<C-w>=",  cmd("WindowsEqualize"))
		end,
	},

	{ "nvzone/volt", lazy = true }, -- UI primitive used by popupmenu and nvim-utils/wrapped.nvim
}
