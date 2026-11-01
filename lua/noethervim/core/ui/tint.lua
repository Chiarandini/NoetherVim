-- NoetherVim plugin: tint.nvim (dim inactive windows)

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
}
