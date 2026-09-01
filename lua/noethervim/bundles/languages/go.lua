---@bundle go
---@desc test generation, struct tags, interface implementation
---@about Go development beyond what gopls alone gives you: generate tests,
---       edit struct tags, implement interfaces, fill structs, and run tests
---       by file or by function from the editor. With the test bundle also
---       enabled, registers the neotest-golang adapter.
---@requires exe=go label="Go toolchain"
---          why="building, testing and every go.nvim command"
---          install="https://go.dev/dl/"
---@requires exe=dlv label="Delve"
---          why="stepping through Go, when the debug bundle is also enabled"
---          install="go install github.com/go-delve/delve/cmd/dlv@latest"
---          optional=true
-- NoetherVim bundle: Go
-- Enable with: { import = "noethervim.bundles.languages.go" }
--
-- Provides go.nvim -- Go development beyond plain gopls.
--   Test generation, struct tags, interface implementation,
--   code lens, fill struct, and more.
--
-- Commands:
--   :GoTest          run tests
--   :GoTestFunc      run test under cursor
--   :GoAddTag        add struct tags
--   :GoRmTag         remove struct tags
--   :GoImpl          implement interface
--   :GoFillStruct    fill struct fields
--   :GoCmt           generate doc comment
--
-- Requires: go toolchain installed.
--
-- Also registers the DAP and neotest adapters, but only when tools/debug.lua
-- and tools/test.lua are enabled too -- see the `optional = true` fragments
-- below.

return {
	-- gopls is not installed by go.nvim (its `lsp_cfg` defaults to off), and
	-- core's list does not carry it, so without this the Go bundle gives you
	-- tooling with no language server behind it. The matching
	-- `vim.lsp.enable` lives in lua/noethervim/lsp/gopls.lua.
	{ "neovim/nvim-lspconfig",
		opts = function(_, opts)
			opts.ensure_installed = opts.ensure_installed or {}
			vim.list_extend(opts.ensure_installed, { "gopls" })
		end,
	},

	{ "nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = { "go", "gomod", "gowork" } },
	},

	-- goimports over gofmt: it does gofmt's job and fixes the import block,
	-- which is the edit a Go buffer needs most often.
	{ "stevearc/conform.nvim",
		opts = function(_, opts)
			opts.formatters_by_ft = opts.formatters_by_ft or {}
			opts.formatters_by_ft.go = { "goimports" }
			opts.mason_install = opts.mason_install or {}
			table.insert(opts.mason_install, "goimports")
		end,
	},

	{
		"ray-x/go.nvim",
		dependencies = {
			"ray-x/guihua.lua",
			"neovim/nvim-lspconfig",
			"nvim-treesitter/nvim-treesitter",
		},
		ft = { "go", "gomod", "gowork", "gotmpl" },
		build = ':lua require("go.install").update_all_sync()',
		opts = {},
	},

	-- ── Go debug adapter ──────────────────────────────────────────────────
	-- `optional = true` means lazy.nvim drops this whole fragment unless
	-- nvim-dap is required by something else, i.e. unless tools/debug.lua is
	-- enabled. Enabling this bundle alone installs no debugger.
	--
	-- nvim-dap-go finds `dlv` on PATH and registers both `dap.adapters.go`
	-- and the launch, attach and test configurations. Both halves matter:
	-- configurations naming an adapter that was never defined fail at the
	-- moment you pick one.
	{
		"mfussenegger/nvim-dap",
		optional = true,
		dependencies = {
			{
				"leoluz/nvim-dap-go",
				ft = { "go", "gomod" },
				opts = {},
			},
		},
		-- nvim-dap-go looks for `dlv` on PATH; Mason's `delve` package puts it
		-- there, so the adapter it registers has something to launch.
		opts = function(_, opts)
			opts.mason_install = opts.mason_install or {}
			table.insert(opts.mason_install, "delve")
		end,
	},

	-- ── Go test adapter ───────────────────────────────────────────────────
	-- Same `optional = true` gating, against tools/test.lua.
	--
	-- Built in an `opts` function so the `require` runs after the adapter
	-- plugin loads; see tools/test.lua for why `adapters` merges as it does.
	--
	-- neotest-golang 2.x tracks the Go parser from nvim-treesitter's `main`
	-- branch and does not support the frozen `master` branch. Core is on
	-- `main`, so the current release line is the right one to track.
	{
		"nvim-neotest/neotest",
		optional = true,
		dependencies = {
			{ "fredrikaverpil/neotest-golang", version = "*" },
		},
		opts = function(_, opts)
			opts.adapters = opts.adapters or {}
			table.insert(opts.adapters, require("neotest-golang")({}))
		end,
	},
}
