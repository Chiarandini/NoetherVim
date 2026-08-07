---@bundle rust
---@desc macro expansion, runnables and crate graph
---@about rustaceanvim goes past plain rust-analyzer with macro expansion,
---       runnables and debuggables, the crate graph, hover actions and
---       structural search-replace. It manages its own LSP client, so no
---       lspconfig entry is needed. With the test bundle also enabled, it
---       supplies its own neotest adapter.
---@requires exe=rust-analyzer label="rust-analyzer"
---          why="every rustaceanvim feature"
---          install="rustup component add rust-analyzer"
---@requires exe=cargo label="Cargo"
---          why="building and running from the editor"
---          install="https://rustup.rs/"
---@requires note="codelldb or lldb"
---          why="stepping through Rust, when the debug bundle is also enabled"
---          install=":MasonInstall codelldb" optional=true
-- NoetherVim bundle: Rust
-- Enable with: { import = "noethervim.bundles.languages.rust" }
--
-- Provides rustaceanvim -- enhanced Rust development beyond plain rust-analyzer.
--   Macro expansion, runnables/debuggables, crate graph, hover actions,
--   structural search-replace, join lines, and more.
--
-- rustaceanvim manages its own LSP client -- no lspconfig setup needed
-- for rust-analyzer. Just ensure rust-analyzer is installed.
--
-- Override settings in user/plugins/:
--   { "mrcjkb/rustaceanvim", opts = { server = { settings = { ... } } } }
--
-- Debugging needs no fragment here: rustaceanvim autoloads dap configurations
-- itself once rust-analyzer attaches, so enabling tools/debug.lua is enough
-- on the Neovim side. It still needs a debug adapter binary -- codelldb or
-- lldb -- which nothing here installs. Testing does need a fragment; see below.

return {
	{
		"mrcjkb/rustaceanvim",
		version = "^6",
		ft = "rust",
	},

	-- ── Rust test adapter ─────────────────────────────────────────────────
	-- `optional = true` means lazy.nvim drops this fragment unless neotest is
	-- required by something else, i.e. unless tools/test.lua is enabled.
	--
	-- The adapter ships inside rustaceanvim rather than as its own plugin, so
	-- there is no extra repo to install -- but it does have to be registered
	-- by hand, and registering it is also what makes `:RustLsp testables`
	-- report into neotest instead of running in a terminal.
	--
	-- Built in an `opts` function so the `require` runs after rustaceanvim
	-- loads; see tools/test.lua for why `adapters` merges as it does.
	--
	-- rustaceanvim is listed as a dependency so the require resolves without
	-- relying on a rust buffer having been opened first. The cost is that the
	-- first :Neotest in any project loads it; neotest wants every adapter at
	-- setup time, so there is no per-filetype way around that.
	{
		"nvim-neotest/neotest",
		optional = true,
		dependencies = { "mrcjkb/rustaceanvim" },
		opts = function(_, opts)
			opts.adapters = opts.adapters or {}
			table.insert(opts.adapters, require("rustaceanvim.neotest"))
		end,
	},
}
