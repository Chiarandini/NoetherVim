---@bundle rust
---@desc macro expansion, runnables and crate graph
---@about rustaceanvim goes past plain rust-analyzer with macro expansion,
---       runnables and debuggables, the crate graph, hover actions and
---       structural search-replace. It manages its own LSP client, so no
---       lspconfig entry is needed. With the test bundle also enabled, cargo
---       tests run through neotest; with the debug bundle, it loads debug
---       targets from rust-analyzer once an adapter is installed.
---@requires exe=rust-analyzer label="rust-analyzer"
---          why="every rustaceanvim feature"
---          install="rustup component add rust-analyzer"
---@requires exe=cargo label="Cargo"
---          why="building and running from the editor"
---          install="https://rustup.rs/"
---@requires exe=cargo-nextest label="cargo-nextest"
---          why="running tests, when the test bundle is also enabled;
---               neotest-rust drives nextest rather than cargo test"
---          install="cargo install cargo-nextest" optional=true
---@requires exe=codelldb label="codelldb"
---          why="stepping through Rust, when the debug bundle is also enabled"
---          install=":MasonInstall codelldb, or put lldb-dap on PATH" optional=true
-- NoetherVim bundle: Rust
-- Enable with: { import = "noethervim.bundles.languages.rust" }
--
-- Provides rustaceanvim: enhanced Rust development beyond plain rust-analyzer.
--   Macro expansion, runnables/debuggables, crate graph, hover actions,
--   structural search-replace, join lines, and more.
--
-- Commands:
--   :RustLsp runnables       run a target (binary, test, doctest)
--   :RustLsp testables       run tests; reports into neotest when that
--                            bundle is enabled, a terminal otherwise
--   :RustLsp debuggables     debug a target (needs the debug bundle)
--   :RustLsp expandMacro     expand the macro under the cursor
--   :RustLsp explainError    rustc --explain for the error under the cursor
--   :RustLsp openCargo       open the current package's Cargo.toml
--   :RustLsp openDocs        docs.rs for the symbol under the cursor
--   :RustLsp parentModule    jump to the parent module
--   :RustLsp ssr             structural search and replace
--   :RustLsp crateGraph      render the crate graph (needs graphviz)
--   :RustAnalyzer restart    restart the language server
--   `:help rustaceanvim` lists the rest.
--
-- :RustLsp is created when rust-analyzer finishes initializing and removed
-- when it exits, so on a cold crate it does not exist for the first seconds
-- after opening a buffer; until then it reports E492. :RustAnalyzer is
-- available as soon as a Rust buffer opens.
--
-- rustaceanvim manages its own LSP client, so there is no lspconfig setup for
-- rust-analyzer here. Just make sure rust-analyzer is installed.
--
-- Override settings in user/plugins/. rustaceanvim has no setup() function; it
-- reads `vim.g.rustaceanvim` once, when its config module is first required:
--   vim.g.rustaceanvim = { server = { settings = { ... } } }
--
-- Debugging needs no fragment here: rustaceanvim reads its debug targets from
-- rust-analyzer once the client attaches, so enabling tools/debug.lua is
-- enough on the Neovim side. It resolves the adapter binary itself, from
-- `codelldb` or `lldb-dap` on PATH; with neither installed it registers no
-- configurations and <F5> reports none. Testing does need a fragment; below.

return {
	{
		"mrcjkb/rustaceanvim",
		version = "^6",

		init = function()
			-- rustaceanvim reads this global once and has no setup() to merge
			-- with, so a user config that sets it owns the whole table. Only
			-- fill it in when nobody else has.
			if vim.g.rustaceanvim ~= nil then return end

			vim.g.rustaceanvim = {
				server = {
					---@param project_root string|nil
					---@param default_settings table|nil
					settings = function(project_root, default_settings)
						local settings = require("rustaceanvim.config.server")
							.load_rust_analyzer_settings(project_root, { default_settings = default_settings })

						-- A .rs file with no crate around it starts rust-analyzer
						-- detached, and `cargo check` cannot work there: cargo
						-- treats the lone file as a single-file package and drives
						-- rustc with nightly-only flags, so on a stable toolchain
						-- every save answers with a compiler backtrace. Opening a
						-- scratch file should be quiet.
						if not project_root then
							settings["rust-analyzer"] = settings["rust-analyzer"] or {}
							settings["rust-analyzer"].checkOnSave = false
						end
						return settings
					end,
				},
			}
		end,

		-- Upstream's own guidance ("this plugin is already lazy"): rustaceanvim
		-- does all its work from ftplugin files, so loading it is little more
		-- than a runtimepath entry. `ft = "rust"` looks tighter but costs the
		-- Cargo.toml half, since rustaceanvim also ships an ftplugin/toml.lua
		-- that reloads the workspace when you save a manifest; under `ft` that
		-- file never runs unless a Rust buffer opened first.
		lazy = false,
	},

	-- Treesitter is the exception to the list-replacement rule: core declares
	-- `opts_extend = { "ensure_installed" }`, so this appends. `toml` comes
	-- along for Cargo.toml, which is as much a Rust file as anything here.
	{ "nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = { "rust", "toml" } },
	},

	-- rustfmt arrives with the toolchain rather than from Mason, so this
	-- claims the filetype without adding an install.
	{ "stevearc/conform.nvim",
		opts = function(_, opts)
			opts.formatters_by_ft = opts.formatters_by_ft or {}
			opts.formatters_by_ft.rust = { "rustfmt" }
		end,
	},

	-- ── Rust debug adapter ────────────────────────────────────────────────
	-- `optional = true` gates this on tools/debug.lua, like every other
	-- language bundle. rustaceanvim registers the configurations itself, from
	-- rust-analyzer, so there is no adapter to define here; what it cannot do
	-- is produce the binary those configurations launch. It looks for
	-- `codelldb` or `lldb-dap` on PATH and silently registers nothing when
	-- neither is there, which is the whole of the "debugging does nothing"
	-- failure. Asking Mason for codelldb closes it.
	{
		"mfussenegger/nvim-dap",
		optional = true,
		opts = function(_, opts)
			opts.mason_install = opts.mason_install or {}
			table.insert(opts.mason_install, "codelldb")
		end,
	},

	-- ── Rust test adapter ─────────────────────────────────────────────────
	-- `optional = true` means lazy.nvim drops this fragment unless neotest is
	-- required by something else, i.e. unless tools/test.lua is enabled.
	--
	-- neotest-rust owns the adapter rather than the one bundled with
	-- rustaceanvim, because rustaceanvim's result parsing is wrong in both of
	-- its modes: scraping `cargo test` stdout attributes the process exit code
	-- to every discovered test, so one failure marks the whole run red, and the
	-- nextest path looks for `</failure>` while nextest emits a self-closing
	-- `<failure ... />`. Measured on a crate with one passing and one failing
	-- test: rustaceanvim reports 0 passed / 2 failed, neotest-rust reports
	-- 1 and 1, which is what `cargo test` says.
	--
	-- Requiring `rustaceanvim.neotest` anyway is deliberate and is not dead
	-- code. `:RustLsp testables` picks its executor by asking whether that
	-- module is in `package.loaded`; when it is, the command resolves a neotest
	-- position id and calls `neotest.run.run(id)` rather than opening a
	-- terminal. Both build the same `<file>::<module>::<test>` id, so the
	-- command keeps reporting into neotest while neotest-rust produces the
	-- results.
	--
	-- Built in an `opts` function so the requires run after the plugins load;
	-- see tools/test.lua for why `adapters` merges as it does.
	{
		"nvim-neotest/neotest",
		optional = true,
		dependencies = { "mrcjkb/rustaceanvim", "rouge8/neotest-rust" },
		opts = function(_, opts)
			pcall(require, "rustaceanvim.neotest")
			opts.adapters = opts.adapters or {}
			table.insert(opts.adapters, require("neotest-rust"))
		end,
	},
}
