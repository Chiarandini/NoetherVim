-- NoetherVim plugin: Auto Pairs
-- Auto-close brackets, quotes, and other pairs on insert.
--
-- autopairs maps <CR> and, per buffer, <BS> itself; a buffer mapping hides
-- a global one of yours. Both are rows instead, so a <CR> or <BS> of yours
-- keeps the key. The functions return keys already escaped, hence
-- replace_keycodes = false, as autopairs' own mappings have it.
return { "windwp/nvim-autopairs",
    event = "InsertEnter",
	opts = {
		disable_filetype = { "TelescopePrompt", "snacks_picker_input", "tex" },
		map_cr = false,
		map_bs = false,
	},
	config = function (_, opts)
		require('nvim-autopairs').setup(opts)
	end,
	specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("nvim-autopairs", {
		{ "<CR>", function() return require("nvim-autopairs").completion_confirm() end,
		  mode = "i", expr = true, replace_keycodes = false, desc = "autopairs completion confirm" },
		{ "<BS>", function() return require("nvim-autopairs").autopairs_bs() end,
		  mode = "i", expr = true, replace_keycodes = false, desc = "autopairs delete" },
	}) } },
}
