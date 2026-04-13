-- NoetherVim bundle: Database
-- Enable with: { import = "noethervim.bundles.database" }
--
-- Provides:
--   vim-dadbod:        database client (supports PostgreSQL, MySQL, SQLite, …)
--   vim-dadbod-ui:     interactive database UI
--     :DBUI            open database explorer
--     :DBUIToggle      toggle explorer panel
--     :DBUIAddConnection  add a new database connection
--   vim-dadbod-completion: SQL completion via blink.cmp
--
-- Connections can be set via:
--   let g:dbs = [{ name = 'dev', url = 'postgres://...' }]
-- Or interactively with :DBUIAddConnection.

return {
	{
		"kristijanhusak/vim-dadbod-ui",
		cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
		dependencies = {
			{ "tpope/vim-dadbod", lazy = true },
			{
				"kristijanhusak/vim-dadbod-completion",
				ft = { "sql", "mysql", "plsql" },
				lazy = true,
			},
		},
		init = function()
			vim.g.db_ui_use_nerd_fonts = 1
		end,
	},

	-- blink.cmp source for SQL completion
	{
		"saghen/blink.cmp",
		opts = {
			sources = {
				per_filetype = {
					sql   = { "dadbod", "snippets", "buffer" },
					mysql = { "dadbod", "snippets", "buffer" },
					plsql = { "dadbod", "snippets", "buffer" },
				},
				providers = {
					dadbod = {
						name = "Dadbod",
						module = "vim_dadbod_completion.blink",
					},
				},
			},
		},
	},
}
