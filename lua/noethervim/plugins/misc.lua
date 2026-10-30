-- NoetherVim plugin: Miscellaneous
--  ╔══════════════════════════════════════════════════════════╗
--  ║                      miscellaneous                       ║
--  ╚══════════════════════════════════════════════════════════╝

local rows = require("noethervim.keymaps.rows")
local toggles = require("noethervim.toggles")

return {
	{ -- to dim inactive window
		"levouh/tint.nvim",
		event = "VeryLazy",
		specs = { { "NoetherVim", optional = true, opts = rows.contribute("tint.nvim", toggles.rows("o<c-t>",
			function() require("tint").enable() end,
			function() require("tint").disable() end,
			"tint")) } },
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
		specs = {
			{ "NoetherVim", optional = true, opts = rows.contribute("zen-mode.nvim", {
				{ "<leader>z", "<cmd>ZenMode<cr>", desc = "ZenMode" },
			}) },
			{ "which-key.nvim", optional = true, opts = require("noethervim.util").labels({
				{ "<leader>z", icon = { icon = require("noethervim.util").icons.zenMode, color = "yellow" }, group = "ZenMode" },
			}) },
		},
	},

	{                   -- to look pretty
		"anuvyklack/windows.nvim",
		event = "BufReadPost",
		cmd = { "WindowsMaximize", "WindowsMaximizeVertically", "WindowsMaximizeHorizontally",
			"WindowsEqualize", "WindowsEnableAutowidth", "WindowsDisableAutowidth", "WindowsToggleAutowidth" },
		specs = { { "NoetherVim", optional = true, opts = rows.contribute("windows.nvim", vim.list_extend({
			{ "<C-w>z", "<Cmd>WindowsMaximize<CR>", desc = "maximize window" },
			{ "<C-w>_", "<Cmd>WindowsMaximizeVertically<CR>", desc = "maximize window vertically" },
			{ "<C-w>|", "<Cmd>WindowsMaximizeHorizontally<CR>", desc = "maximize window horizontally" },
			{ "<C-w>=", "<Cmd>WindowsEqualize<CR>", desc = "equalize windows" },
		}, toggles.rows("oW", "<Cmd>WindowsEnableAutowidth<CR>", "<Cmd>WindowsDisableAutowidth<CR>", "animated windows"))) } },
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
				filetype = { "NvimTree", "neo-tree", "nvim-undotree", "gundo", "mundo" },
			},
			animation = {
				enable   = true,
				duration = 100,
				fps      = 30,
				easing   = "in_out_sine",
			},
		},
		config = function(_, opts)
			local default = require("noethervim.default")
			default.o("winwidth", 10)
			default.o("winminwidth", 10)
			default.o("equalalways", false)
			require("windows").setup(opts)
		end,
	},
}
