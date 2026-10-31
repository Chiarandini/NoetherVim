-- NoetherVim plugin: windows.nvim (window sizing and animation)

local rows = require("noethervim.keymaps.rows")
local toggles = require("noethervim.toggles")

return {
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
