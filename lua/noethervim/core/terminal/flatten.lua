-- NoetherVim plugin: flatten.nvim
-- `nvim file` typed in NoetherVim's :terminal opens the file in the Neovim
-- around it, rather than in a second one inside the terminal.

return {
	{
		"willothy/flatten.nvim",
		config = true,
		-- The inner Neovim ($NVIM set) hands its files over from flatten's
		-- setup(), so there flatten has to load at startup. Only with a UI: a
		-- headless child of Neovim (a script, a test run) inherits $NVIM too
		-- and must keep its files. Everywhere else it waits for TermOpen, the
		-- outer Neovim's side.
		lazy = not (vim.env.NVIM and #vim.api.nvim_list_uis() > 0),
		event = "TermOpen",
		priority = 1001,
	},
}
