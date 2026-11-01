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
		-- Loaded by the first key below, through require("dial.map").
		lazy = true,
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("dial.nvim", {
			{ "<C-a>",  function() require("dial.map").manipulate("increment", "normal")  end, desc = "increment", set = "remaps" },
			{ "<C-x>",  function() require("dial.map").manipulate("decrement", "normal")  end, desc = "decrement", set = "remaps" },
			{ "g<C-a>", function() require("dial.map").manipulate("increment", "gnormal") end, desc = "increment (sequential)", set = "remaps" },
			{ "g<C-x>", function() require("dial.map").manipulate("decrement", "gnormal") end, desc = "decrement (sequential)", set = "remaps" },
			{ "<C-a>",  function() require("dial.map").manipulate("increment", "visual")  end, mode = "x", desc = "increment", set = "remaps" },
			{ "<C-x>",  function() require("dial.map").manipulate("decrement", "visual")  end, mode = "x", desc = "decrement", set = "remaps" },
			{ "g<C-a>", function() require("dial.map").manipulate("increment", "gvisual") end, mode = "x", desc = "increment (sequential)", set = "remaps" },
			{ "g<C-x>", function() require("dial.map").manipulate("decrement", "gvisual") end, mode = "x", desc = "decrement (sequential)", set = "remaps" },
		}) } },
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
