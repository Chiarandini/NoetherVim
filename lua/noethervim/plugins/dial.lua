-- NoetherVim plugin: Enhanced Increment
--  ╔══════════════════════════════════════════════════════════╗
--  ║                    Enhanced increment                    ║
--  ╚══════════════════════════════════════════════════════════╝
-- Extends <C-a>/<C-x> beyond plain numbers: booleans, dates, operators, etc.
--
-- Override the augend groups via a user plugin spec:
--   { "monaqa/dial.nvim", opts = { groups = { default = { ... } } } }

return {
	{
		"monaqa/dial.nvim",
		keys = {
			{ "<C-a>",  function() require("dial.map").manipulate("increment", "normal")  end, desc = "increment" },
			{ "<C-x>",  function() require("dial.map").manipulate("decrement", "normal")  end, desc = "decrement" },
			{ "g<C-a>", function() require("dial.map").manipulate("increment", "gnormal") end, desc = "increment (sequential)" },
			{ "g<C-x>", function() require("dial.map").manipulate("decrement", "gnormal") end, desc = "decrement (sequential)" },
			{ "<C-a>",  function() require("dial.map").manipulate("increment", "visual")  end, mode = "v", desc = "increment" },
			{ "<C-x>",  function() require("dial.map").manipulate("decrement", "visual")  end, mode = "v", desc = "decrement" },
			{ "g<C-a>", function() require("dial.map").manipulate("increment", "gvisual") end, mode = "v", desc = "increment (sequential)" },
			{ "g<C-x>", function() require("dial.map").manipulate("decrement", "gvisual") end, mode = "v", desc = "decrement (sequential)" },
		},
		opts = {},
		config = function(_, opts)
			local augend = require("dial.augend")

			local groups = vim.tbl_deep_extend("force", {
				default = {
					augend.integer.alias.decimal_int,
					augend.integer.alias.hex,
					augend.integer.alias.binary,
					augend.date.alias["%Y-%m-%d"],
					augend.date.alias["%Y/%m/%d"],
					augend.date.alias["%m/%d"],
					augend.constant.alias.bool,
					augend.constant.new({ elements = { "and", "or" },  word = true, cyclic = true }),
					augend.constant.new({ elements = { "&&",  "||" },  word = false, cyclic = true }),
					augend.constant.new({ elements = { "==",  "!=" },  word = false, cyclic = true }),
					augend.constant.new({ elements = { "yes", "no" },  word = true, cyclic = true }),
					augend.constant.new({ elements = { "True", "False" }, word = true, cyclic = true }),
					augend.semver.alias.semver,
				},
				markdown = {
					augend.integer.alias.decimal_int,
					augend.misc.alias.markdown_header,
					augend.constant.alias.bool,
				},
			}, opts.groups or {})

			require("dial.config").augends:register_group(groups)

			-- Filetype-specific groups
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "markdown",
				callback = function()
					vim.b.dial_augends = "markdown"
				end,
			})
		end,
	},
}
