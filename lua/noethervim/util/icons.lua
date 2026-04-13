local kind_icons = {
	Method = "m",
	nvim_lsp = "λ",
	Constructor = "",
	Field = "",
	Interface = "",
	Module = "",
	Property = "",
	Unit = "",
	Constant = "",
	Value = "",
	Enum = "",
	Keyword = "",
	Snippet = "",
	Color = "",
	-- Snippet = "󰌢",
	Reference = "",
	EnumMember = "",
	Struct = "", -- 
	Event = "",
	Operator = "",
	Text = "",
	TypeParameter = "",
	Function = "", -- 󰡱
	Variable = "󰀫",
	File = "",
	Folder = "",
	Class = "󰋜",
}
local M = {
	kind_icons = kind_icons,
	-- NOTE: These are duplicated here so that I don't double name variable in the future
	method        = "m",
	nvim_lsp      = "λ",
	constructor   = "",
	field         = "",
	interface     = "",
	module        = "",
	property      = "",
	unit          = "",
	constant      = "",
	value         = "",
	enum          = "",
	keyword       = "",
	snippet       = "",
	-- Snippet    = "󰌢",
	reference     = "",
	enumMember    = "",
	struct        = "", -- 
	event         = "",
	operator      = "",
	text          = "",
	typeParameter = "",
	Function      = "", -- 󰡱
	variable      = "󰀫",
	file          = "",
	folder        = "",
	class         = "󰋜",

	-- whichkey
	toggle_on   = "",
	toggle_off  = "",
	setting     = "",
	options_on  = "",
	options_off = "",
	search      = "󰍉",
	search_file = "󰷊",
	grep        = "󱎸",
	git         = "",
	find        = "󰠮",
	config      = "",
	documents   = "󰈙",
	diagnostics = "",
	vim         = "",
	lazy        = "󰒲",
	wiki        = "󰖬",
	session     = "󱅰",
	debug       = "",
	color       = "",
	wrench      = "",
	toc         = "󰉸",

	-- special symbols
	plus   = "",
	window = "",
	tab = "󰓩",
	fish = '󰈺', -- using for harpoon

	-- <leader> + action
	action    = "",
	box       = "󰘷",
	format    = "󰉼",
	undo      = "",
	replace   = "",
	translate = "󱅰",
	spotify   = "",
	zenMode   = "",

	-- telescope
	table_of_content = '󰉸',
	latex            = '',
	mason            = '󰣪',

	-- diagnostic icons
	error    = "",
    warning  = "",
    info     = "",
    loup     = "",
    question = "",
    timeout  = "󱡥",
	flag     = '⚑',
	bulb     = '',
	x        = '✘',
	triangle = '▲',
	landplot = '󱪳',


    question_shard = "", -- from Noice
	clock = '󰥔',
	refactor = '',
	run = '',
	table = '󰓫',
	power_plug = '󰚥',
	bars = '',

	-- for UFO (folding)
	downleftarrow = '󰁂',

	-- for showing a file is unsaved
	pencil = '',

	-- for showing a file is readonly
	lock = '',

	-- checkmark
	checkmark = '',

	map = "󰇧"
}

return M
