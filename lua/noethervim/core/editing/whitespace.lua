-- NoetherVim plugin: whitespace (tidy.nvim, visual-whitespace.nvim)

return {
	--  delete extra white space
	{
		"mcauley-penney/tidy.nvim",
		event = 'VeryLazy',
		-- tidy.nvim exposes only .toggle(), so each side checks the state first.
		specs = {
			{ "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("tidy.nvim",
				require("noethervim.toggles").rows("oD",
					function()
						local tidy = require("tidy")
						if not tidy.opts.enabled_on_save then tidy.toggle() end
					end,
					function()
						local tidy = require("tidy")
						if tidy.opts.enabled_on_save then tidy.toggle() end
					end,
					"tidy whitespace (Dirty)")) },
			{ "which-key.nvim", optional = true, opts = require("noethervim.util").labels({
				{ "[oD", icon = { icon = require("noethervim.util").icons.options_on, color = "yellow" }, desc = "tidy ON (remove dirty whitespace)" },
				{ "]oD", icon = { icon = require("noethervim.util").icons.options_off, color = "yellow" }, desc = "tidy OFF" },
			}) },
		},
		opts = {
			filetype_exclude = { "snippets", "diff" },
		},
		config = function(_, opts)
			require("tidy").setup(opts)
		end,
	},
	{
		'mcauley-penney/visual-whitespace.nvim',
		config = true,
		-- Loaded on entering visual mode. A load trigger on v/V/<C-v>
		-- themselves would put mappings on Vim's own keys.
		event = "ModeChanged",
	},
}
