-- NoetherVim plugin: vim-matchup (smarter % matching)

return {
	{ -- vim-matchup: smarter % matching
		"andymass/vim-matchup",
		event = "BufReadPost",
		specs = { { "NoetherVim", optional = true, opts = { g = {
			matchup_matchparen_offscreen = { method = "popup" },
		} } } },
	},
}
