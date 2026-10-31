-- NoetherVim plugin: conform.nvim (formatting)

return {
	-- ── conform.nvim: formatter stack ────────────────────────────────────
	-- Replaces none-ls.nvim + mason-null-ls.nvim + prettier.nvim.
	-- <Leader>ff (set in LspAttach below) calls conform with LSP fallback.
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd   = { "ConformInfo" },
		opts  = {
			formatters_by_ft = {
				lua             = { "stylua" },
				bib             = { "bibclean" },
				javascript      = { "prettierd" },
				javascriptreact = { "prettierd" },
				typescript      = { "prettierd" },
				typescriptreact = { "prettierd" },
				css             = { "prettierd" },
				html            = { "prettierd" },
				json            = { "prettierd" },
				yaml            = { "prettierd" },
				markdown        = { "prettierd" },
				sh              = { "shfmt" },
			},
			-- No format_on_save -- use <Leader>ff for explicit formatting.

			-- Mason packages backing the claims above. The rule is that
			-- whoever claims a filetype installs its formatter: core claims
			-- the ones every install meets regardless of language (Lua for the
			-- config itself, shell scripts, and the JSON / YAML / Markdown
			-- that prettierd covers), and a language bundle claims its own.
			-- `bib` is the one claim core makes without installing, because a
			-- .bib file is not something a user without LaTeX opens; the latex
			-- bundle adds `bibclean` to this list.
			--
			-- A list, not a second `config`: lazy keeps only the last config
			-- function it sees, so a bundle defining one would silently drop
			-- this whole block. Bundles append with
			-- `opts = function(_, opts) ... end`, the same way they extend
			-- `ensure_installed`.
			mason_install = { "stylua", "prettierd", "shfmt" },
		},
		config = function(_, opts)
			local tools = opts.mason_install or {}
			opts.mason_install = nil   -- conform would reject the unknown key
			require("conform").setup(opts)
			require("noethervim.util.mason_install").ensure(tools)
		end,
	},
}
