-- NoetherVim plugin: mini.ai (text objects)

return {
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
}
