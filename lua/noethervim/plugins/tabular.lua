-- NoetherVim plugin: Tabular Alignment
-- Visual-mode alignment: select text, press T, then type the character to align on.
return {
	'godlygeek/tabular',
	keys = {
		{ "T", ":Tabularize /", mode = { "v" }, desc = 'align text on character' },
	},
}
