-- NoetherVim plugin: Programming Utilities
--  ╔══════════════════════════════════════════════════════════╗
--  ║                       programming                        ║
--  ╚══════════════════════════════════════════════════════════╝

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
	{
		-- context-smart comment adder
		"danymat/neogen",
		cmd = "Neogen",
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("neogen", {
			{ "<leader>Rd", function() require("neogen").generate({}) end,
				desc = "[R]efactor: generate [d]oc comment", silent = true },
		}) } },
		dependencies = "nvim-treesitter/nvim-treesitter",
		opts = {
			snippet_engine = "luasnip",
		},
		-- Uncomment next line if you want to follow only stable versions
		-- version = "*"
	},
	-- better around/in operators
	{
		"echasnovski/mini.ai",
		version = false,
		event = "VeryLazy",
		-- mini.ai's search modifiers default to `an`/`in` for the next
		-- textobject and `al`/`il` for the last one, and `il` is the
		-- inner-line object from keymaps.lua -- documented, older, and
		-- reached far more often than "inside the previous quote".
		--
		-- Last moves to the capitalised form of next, which is the
		-- relationship `n` and `N` already have in search. That also
		-- leaves `al`/`il` free for treesitter's loop objects to stay
		-- off, which they now are (they sit on `aL`/`iL`).
		--
		-- mini.ai maps its keys itself, to functions a row cannot call, so
		-- they are not rows. A key a row would yield (one of yours is on
		-- it, or it is off) is emptied instead, which mini.ai skips.
		opts = function(_, opts)
			local rows = require("noethervim.keymaps.rows")
			local keys = {
				around      = { "a",  { "x", "o" } },
				inside      = { "i",  { "x", "o" } },
				around_next = { "an", { "x", "o" } },
				inside_next = { "in", { "x", "o" } },
				around_last = { "aN", { "x", "o" } },
				inside_last = { "iN", { "x", "o" } },
				goto_left   = { "g[", { "n", "x", "o" } },
				goto_right  = { "g]", { "n", "x", "o" }, "remaps" },
			}
			opts.mappings = opts.mappings or {}
			for name, k in pairs(keys) do
				local lhs = opts.mappings[name] or k[1]
				opts.mappings[name] = lhs
				for _, mode in ipairs(k[2]) do
					if lhs ~= "" and not rows.free({ lhs, owner = "mini.ai", set = k[3], desc = "mini.ai " .. name }, mode) then
						opts.mappings[name] = ""
						break
					end
				end
			end
			return opts
		end,
	},

	-- For pop-up
	{
		"kevinhwang91/nvim-bqf",
		ft = "qf",
	},

	{ -- when oppening nvim in a terminal in nvim, opens it in new buffer
		"willothy/flatten.nvim",
		config = true,
		event = "TermOpen",
		-- or pass configuration with
		-- opts = {  }
		-- Ensure that it runs first to minimize delay when opening file from terminal
		priority = 1001,
	},

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
