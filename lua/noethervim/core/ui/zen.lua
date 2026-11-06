-- NoetherVim plugin: zen mode (snacks)
--
-- Snacks.zen centres the buffer in a 120-column window and dims all but
-- the scope under the cursor (Snacks.dim). That scope comes from treesitter
-- where the filetype has a parser and from indentation where it has none.
-- Options: `opts = { zen = { ... } }` on snacks in lua/user/plugins/.

local rows = require("noethervim.keymaps.rows")

return {
	{
		"folke/snacks.nvim",
		specs = {
			{ "NoetherVim", optional = true, opts = rows.contribute("snacks.nvim", {
				{ "<leader>z", function() Snacks.zen() end, desc = "ZenMode" },
			}, {
				startup = { ["zen.command"] = function()
					require("noethervim.default").command("ZenMode", function() Snacks.zen() end,
						{ desc = "toggle zen mode" })
				end },
			}) },
			{ "which-key.nvim", optional = true, opts = require("noethervim.util").labels({
				{ "<leader>z", icon = { icon = require("noethervim.util").icons.zenMode, color = "yellow" }, group = "ZenMode" },
			}) },
		},
	},
}
