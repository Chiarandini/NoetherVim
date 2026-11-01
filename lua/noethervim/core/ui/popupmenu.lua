-- NoetherVim plugin: Popup Menu
-- Right-click popup menu with sensible defaults (via nvzone/menu + volt).
-- Without it, <RightMouse> is Neovim's own popup menu.
return {
	{ "nvzone/volt", lazy = true },
	{
		"nvzone/menu",
		lazy = true,
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("menu", {
			{ "<RightMouse>", function()
				-- A menu still open from the last click goes first, or each
				-- click stacks another.
				require("menu.utils").delete_old_menus()
				vim.cmd.exec('"normal! \\<RightMouse>"')
				require("menu").open("default", { mouse = true })
			end, mode = { "n", "v" }, set = "remaps", desc = "context menu" },
		}) } },
	},
}
