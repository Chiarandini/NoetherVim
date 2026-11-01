-- NoetherVim plugin: diagnostics (tiny-inline-diagnostic)

return {
	{
		"rachartier/tiny-inline-diagnostic.nvim",
		event = "VeryLazy",
		priority = 1000,
		-- A message too long for the rest of the line is clipped, not wrapped.
		-- The plugin's wrapping modes draw the overflow on top of the buffer
		-- lines below with `virt_text_pos = "overlay"`, so a verbose message
		-- replaces two or three lines of real code, cut mid-identifier, with
		-- nothing marking where the code ends and the message begins.
		-- `gl` and `]d` / `[d` open the full text in a float.
		opts = {
			options = {
				overflow = { mode = "oneline" },

				-- `DiagnosticChanged` alongside the plugin's own `LspAttach`:
				-- this renderer replaces Neovim's inline message (turned off
				-- below), so a buffer it never watches shows a sign and an
				-- underline with the text nowhere but `gl`. That is every
				-- buffer whose diagnostics come from a linter rather than a
				-- language server.
				overwrite_events = { "LspAttach", "DiagnosticChanged" },
			},
		},
		config = function(_, opts)
			require("tiny-inline-diagnostic").setup(opts)
			vim.diagnostic.config({ virtual_text = false })
		end,
	},
}
