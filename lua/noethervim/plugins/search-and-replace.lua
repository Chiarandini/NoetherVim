-- NoetherVim plugin: Search and Replace
-- Project-wide search and replace. Open with <C-w><C-s>.
return {
	{
		"MagicDuck/grug-far.nvim",
		cmd = {"GrugFar", "GrugFarWithin"},
		keys = {{"<c-w><c-s>", function() require('grug-far').open({ transient = true }) end, desc='grep replace'}},
		opts = {}
	}
}
