-- NoetherVim plugin: zen-mode.nvim

local rows = require("noethervim.keymaps.rows")

return {
	{ -- for less distractions
		"folke/zen-mode.nvim",
		version = "*",
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
}
