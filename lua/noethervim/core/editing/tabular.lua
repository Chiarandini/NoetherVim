-- NoetherVim plugin: Tabular Alignment
-- Visual-mode alignment: select text, press T, then type the character to align on.
return {
	'godlygeek/tabular',
	cmd = { "Tabularize" },
	-- Visual mode only: in select mode (a snippet placeholder) T is text.
	specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("tabular", {
		{ "T", ":Tabularize /", mode = "x", desc = "align text on character" },
	}) } },
}
