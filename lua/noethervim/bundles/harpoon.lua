-- NoetherVim bundle: Harpoon
-- Enable with: { import = "noethervim.bundles.harpoon" }
--
-- Fast per-project file marks (harpoon2).
--
-- Key bindings:
--   <c-w><c-h>  — toggle harpoon quick-menu
--   <leader>ha  — add current file
--   <c-s-n>     — next mark
--   <c-s-p>     — previous mark
--
-- Direct mark jumps (1-4) are intentionally unbound in the distro because
-- <C-number> is not reliably delivered by all terminal emulators. Add in
-- lua/user/plugins/:
--   local h = require("harpoon"):list()
--   vim.keymap.set("n", "<M-1>", function() h:select(1) end)

return {
	{
		"ThePrimeagen/harpoon",
		branch       = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		keys         = {
			{
				"<c-w><c-h>",
				function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end,
				desc = "Harpoon menu",
			},
			{
				"<leader>ha",
				function()
					require("harpoon"):list():append()
					vim.notify("file added to harpoon", vim.log.levels.INFO, { title = "Harpoon" })
				end,
				desc = "Harpoon add file",
			},
			{ "<c-s-n>", function() require("harpoon"):list():next() end, desc = "Harpoon next" },
			{ "<c-s-p>", function() require("harpoon"):list():prev() end, desc = "Harpoon prev" },
		},
		config = function(_, opts)
			require("harpoon"):setup(opts)
		end,
	},
}
