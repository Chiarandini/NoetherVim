-- NoetherVim plugin: Undotree
--  ╔══════════════════════════════════════════════════════════╗
--  ║                         Undotree                         ║
--  ╚══════════════════════════════════════════════════════════╝
-- mbbill/undotree -- non-destructive preview pane. Selecting a node
-- shows a diff against current state without applying it; press <CR>
-- (or `<` / `>` for sibling branches) to actually move the buffer.
--
-- This intentionally replaces Neovim's builtin nvim.undotree, which
-- applies state on every CursorMoved (no preview). The <c-w><c-u>
-- toggle in keymaps.lua dispatches to whichever is loaded.
return {
	{
		"mbbill/undotree",
		cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeHide", "UndotreeFocus" },
		-- Layout: tree on the left, diff pane below it, both 30 cols wide.
		-- Plugin globals as `g` data: set at startup unless you set them.
		specs = { { "NoetherVim", optional = true, opts = { g = {
			undotree_WindowLayout       = 2,
			undotree_SplitWidth         = 30,
			undotree_DiffpanelHeight    = 12,
			undotree_SetFocusWhenToggle = 1,
			undotree_ShortIndicators    = 1,
			undotree_HelpLine           = 0,
		} } } },
	},
}
