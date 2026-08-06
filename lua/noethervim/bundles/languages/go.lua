---@bundle go
---@desc test generation, struct tags, interface implementation
---@about Go development beyond what gopls alone gives you: generate tests,
---       edit struct tags, implement interfaces, fill structs, and run tests
---       by file or by function from the editor.
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
-- Also registers the DAP adapter, but only when tools/debug.lua is enabled
-- too -- see the `optional = true` fragment below.

return {
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
	-- nvim-dap-go finds `dlv` on PATH and registers both the adapter and the
	-- launch/attach/test configurations. The previous hand-written
	-- `dap.configurations.go` in the debug bundle declared four entries with
	-- `type = "go"` but never defined `dap.adapters.go`, so none of them ran.
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
	},
}
