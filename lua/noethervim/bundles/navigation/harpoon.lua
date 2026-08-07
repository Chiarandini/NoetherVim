---@bundle harpoon
---@desc fast per-project file marks
---@about harpoon2 keeps a short ordered list of files per project, so the
---       handful you are actually working on stay one keystroke apart instead
---       of buried in a fuzzy finder.
---@requires none
-- NoetherVim bundle: Harpoon
-- Enable with: { import = "noethervim.bundles.navigation.harpoon" }
--
-- Fast per-project file marks (harpoon2).
--
-- Key bindings:
--   <c-w><c-h>  -- toggle harpoon quick-menu
--   <leader>H   -- add current file (<leader>h is the gitsigns hunk
--                 namespace, so harpoon does not sit inside it)
--   <c-s-n>     -- next mark
--   <c-s-p>     -- previous mark
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
				"<leader>H",
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
