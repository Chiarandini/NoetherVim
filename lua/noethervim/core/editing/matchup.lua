-- NoetherVim plugin: vim-matchup (smarter % matching)

return {
	{ -- vim-matchup: smarter % matching
		"andymass/vim-matchup",
		event = "BufReadPost",
		-- matchup replaces matchit and matchparen; off with it, they return.
		specs = { { "NoetherVim", optional = true, opts = { g = {
			loaded_matchit = 1,
			loaded_matchparen = 1,
			matchup_matchparen_offscreen = { method = "popup" },
		} } } },
	},
}
