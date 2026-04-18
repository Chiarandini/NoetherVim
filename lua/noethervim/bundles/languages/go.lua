-- NoetherVim bundle: Go
-- Enable with: { import = "noethervim.bundles.languages.go" }
--
-- Provides go.nvim — Go development beyond plain gopls.
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
}
