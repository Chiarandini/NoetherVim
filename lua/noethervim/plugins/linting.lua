-- NoetherVim plugin: nvim-lint (linting)

return {
	-- ── nvim-lint: linter stack ──────────────────────────────────────────
	-- Companion to conform.nvim: conform handles formatting, nvim-lint
	-- handles diagnostics from non-LSP linters. Most filetypes are already
	-- covered by their LSP server; add entries here for tools that run
	-- outside the LSP (shellcheck, markdownlint, vale, etc.).
	--
	-- Override via user plugin spec:
	--   { "mfussenegger/nvim-lint", opts = { linters_by_ft = { sh = { "shellcheck" } } } }
	{
		"mfussenegger/nvim-lint",
		event = { "BufReadPost", "BufWritePost", "InsertLeave" },
		opts = {
			linters_by_ft = {
				-- Most linting is provided by LSP servers (basedpyright, ruff,
				-- eslint, lua_ls, …). Add non-LSP linters here or via opts override.
			},
			-- Same contract as conform's list above: a bundle that adds a
			-- linter to `linters_by_ft` names its Mason package here, and the
			-- binary arrives with the bundle instead of being a manual step
			-- the reader only learns about from :checkhealth.
			mason_install = {},
		},
		config = function(_, opts)
			local lint = require("lint")
			lint.linters_by_ft = opts.linters_by_ft
			require("noethervim.util.mason_install").ensure(opts.mason_install)

			vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
				group = vim.api.nvim_create_augroup("noethervim_lint", { clear = true }),
				callback = function()
					-- Only lint buffers backed by a real file
					if vim.bo.buftype == "" then
						lint.try_lint()
					end
				end,
			})
		end,
	},
}
