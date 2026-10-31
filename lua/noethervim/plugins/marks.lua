-- NoetherVim plugin: marks.nvim

-- marks.nvim's own default keys, as rows.
local function marks_rows()
	local function call(fn) return function() require("marks")[fn]() end end
	local rows = {
		{ "m",         call("set"),             desc = "marks: set",                         set = "remaps" },
		{ "m,",        call("set_next"),        desc = "marks: set the next free letter" },
		{ "m;",        call("toggle"),          desc = "marks: toggle at the line" },
		{ "m]",        call("next"),            desc = "marks: next",                        set = "remaps" },
		{ "m[",        call("prev"),            desc = "marks: previous",                    set = "remaps" },
		{ "m:",        call("preview"),         desc = "marks: preview" },
		{ "m}",        call("next_bookmark"),   desc = "marks: next bookmark" },
		{ "m{",        call("prev_bookmark"),   desc = "marks: previous bookmark" },
		{ "dm",        call("delete"),          desc = "marks: delete" },
		{ "dm-",       call("delete_line"),     desc = "marks: delete on the line" },
		{ "dm=",       call("delete_bookmark"), desc = "marks: delete the bookmark" },
		{ "dm<space>", call("delete_buf"),      desc = "marks: delete in the buffer" },
	}
	for i = 0, 9 do
		table.insert(rows, { "m" .. i,  call("set_bookmark" .. i),    desc = "marks: set bookmark " .. i })
		table.insert(rows, { "dm" .. i, call("delete_bookmark" .. i), desc = "marks: delete bookmark " .. i })
	end
	return rows
end

return {
	{ -- better marks visualization
		"chentoast/marks.nvim",
		event = "BufReadPost",
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("marks.nvim", marks_rows()) } },
		opts = {
			default_mappings = false,
			builtin_marks = {},
			cyclic = true,
			force_write_shada = false,
			refresh_interval = 250,
			sign_priority = { lower=10, upper=15, builtin=8, bookmark=20 },
			excluded_filetypes = {},
			excluded_buftypes = {},
			bookmark_0 = {
				sign = "⚑",
				virt_text = "hello world",
				annotate = false,
			},
			mappings = {},
		},
	},
}
