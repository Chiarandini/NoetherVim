-- NoetherVim plugin: Undotree
--  ╔══════════════════════════════════════════════════════════╗
--  ║                         Undotree                         ║
--  ╚══════════════════════════════════════════════════════════╝
-- mbbill/undotree -- non-destructive preview pane.  Selecting a node
-- shows a diff against current state without applying it; press <CR>
-- (or `<` / `>` for sibling branches) to actually move the buffer.
--
-- This intentionally replaces Neovim's builtin nvim.undotree, which
-- applies state on every CursorMoved (no preview).  The <c-w><c-u>
-- toggle in keymaps.lua dispatches to whichever is loaded.
return {
	{
		"mbbill/undotree",
		cmd = { "UndotreeToggle", "UndotreeShow", "UndotreeHide", "UndotreeFocus" },
		init = function()
			-- Layout: tree on the left, diff pane below it, both 30 cols wide.
			vim.g.undotree_WindowLayout       = 2
			vim.g.undotree_SplitWidth         = 30
			vim.g.undotree_DiffpanelHeight    = 12
			vim.g.undotree_SetFocusWhenToggle = 1
			vim.g.undotree_ShortIndicators    = 1
			vim.g.undotree_HelpLine           = 0
		end,
	},
}
