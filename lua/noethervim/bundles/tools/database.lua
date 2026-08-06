---@bundle database
---@desc query databases from a buffer
---@about vim-dadbod with its interactive UI and SQL completion. Connections
---       are driven by whichever client binary the database needs, so
---       PostgreSQL, MySQL and SQLite each depend on their own command-line
---       tool being installed.
---@requires exe=psql label="psql"
---          why="PostgreSQL connections; dadbod shells out to the client"
---          install="part of postgresql" optional=true
---@requires exe=mysql label="mysql" why="MySQL and MariaDB connections"
---          install="part of mysql-client" optional=true
---@requires exe=sqlite3 label="sqlite3" why="SQLite connections"
---          install="preinstalled on macOS and most Linux distributions"
---          optional=true
-- NoetherVim bundle: Database
-- Enable with: { import = "noethervim.bundles.tools.database" }
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
