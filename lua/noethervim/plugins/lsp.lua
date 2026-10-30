-- NoetherVim plugin: LSP Setup
--  ╔══════════════════════════════════════════════════════════╗
--  ║                        LSP Setup                         ║
--  ╚══════════════════════════════════════════════════════════╝
-- Uses Neovim built-in LSP (vim.lsp.config / vim.lsp.enable) for all servers.
-- nvim-lspconfig supplies each server's base config (its lsp/<name>.lua).
-- NoetherVim's settings for a server are in after/lsp/<name>.lua, which a
-- user's own after/lsp/<name>.lua and vim.lsp.config() calls override.
-- Formatting is handled by conform.nvim; linting by nvim-lint; none-ls is gone.
--
-- Override data values via a user plugin spec:
--   { "neovim/nvim-lspconfig", opts = { diagnostic = { virtual_lines = true } } }
--   { "stevearc/conform.nvim", opts = { formatters_by_ft = { rust = { "rustfmt" } } } }
--   { "mfussenegger/nvim-lint", opts = { linters_by_ft = { sh = { "shellcheck" } } } }
local SearchLeader = require("noethervim.util").search_leader

local function count_lsp_res_changes(lsp_res)
	local count = { instances = 0, files = 0 }
	if lsp_res.documentChanges then
		for _, changed_file in pairs(lsp_res.documentChanges) do
			count.files = count.files + 1
			count.instances = count.instances + #changed_file.edits
		end
	elseif lsp_res.changes then
		for _, changed_file in pairs(lsp_res.changes) do
			count.instances = count.instances + #changed_file
			count.files = count.files + 1
		end
	end
	return count
end

local function LspRename()
	local curr_name = vim.fn.expand('<cword>')
	vim.ui.input({ prompt = 'LSP Rename', default = curr_name }, function(new_name)
		if not new_name or #new_name == 0 or curr_name == new_name then return end
		local clients = vim.lsp.get_clients({ bufnr = 0 })
		if #clients == 0 then return end
		local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
		params.newName = new_name
		vim.lsp.buf_request(0, 'textDocument/rename', params, function(_, res, ctx)
			if not res then return end
			local client = vim.lsp.get_client_by_id(ctx.client_id)
			if not client then return end
			vim.lsp.util.apply_workspace_edit(res, client.offset_encoding)
			local changes = count_lsp_res_changes(res)
			vim.notify(string.format(
				'renamed %s instance%s in %s file%s. %s',
				changes.instances, changes.instances == 1 and '' or 's',
				changes.files,     changes.files     == 1 and '' or 's',
				changes.files > 1 and "To save them run ':wa'" or ''
			))
		end)
	end)
end

--- gy: yank the inferred type of the symbol under the cursor into the
--- unnamed and system-clipboard registers.
---
--- Uses the standard nvim API: pick a hover-capable client, send
--- textDocument/hover with that client's offset_encoding, then run the
--- response through vim.lsp.util.convert_input_to_markdown_lines (the
--- helper Neovim itself uses to render hover floats) so we handle
--- MarkupContent | MarkedString | string | string[] uniformly. We then
--- strip code fences and the leading "(variable) name:" / "(parameter)
--- name:" preamble that pyright/lua_ls/etc. prepend, and yank whatever's
--- after the first ":" on the signature line.
local function yank_type()
	local hover_clients = vim.lsp.get_clients({
		bufnr = 0,
		method = 'textDocument/hover',
	})
	if #hover_clients == 0 then
		vim.notify("no LSP client supports hover here", vim.log.levels.WARN)
		return
	end
	local hclient = hover_clients[1]
	local params = vim.lsp.util.make_position_params(0, hclient.offset_encoding)
	hclient:request('textDocument/hover', params, function(err, result)
		if err then
			vim.notify("hover request failed: " .. tostring(err.message or err), vim.log.levels.WARN)
			return
		end
		if not result or not result.contents then
			vim.notify("no hover information at cursor", vim.log.levels.WARN)
			return
		end
		local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
		lines = vim.lsp.util.trim_empty_lines(lines)
		if not lines or #lines == 0 then
			vim.notify("hover returned empty content", vim.log.levels.WARN)
			return
		end
		-- Drop the language-tag fence lines if present
		-- ("```python", "```lua", "```typescript", ...).
		local body = {}
		for _, line in ipairs(lines) do
			if not line:match("^```") then
				body[#body + 1] = line
			end
		end
		if #body == 0 then
			vim.notify("hover had only fences", vim.log.levels.WARN)
			return
		end
		-- The signature is the first non-empty body line.
		local signature
		for _, line in ipairs(body) do
			if line:match("%S") then signature = line; break end
		end
		signature = signature or body[1]
		-- Strip "(variable)", "(parameter)", "(method)", etc.
		local stripped = signature:gsub("^%s*%b()%s*", "")
		-- "name: Type" → "Type". If no colon, yank the whole
		-- signature so e.g. function signatures still copy.
		local typ = stripped:match(":%s*(.+)$") or stripped
		typ = typ:gsub("^%s+", ""):gsub("%s+$", "")
		if typ == "" then
			vim.notify("could not extract type from hover", vim.log.levels.WARN)
			return
		end
		vim.fn.setreg('"', typ)
		vim.fn.setreg('+', typ)
		local preview = #typ > 80 and (typ:sub(1, 77) .. "...") or typ
		vim.notify("yanked: " .. preview, vim.log.levels.INFO)
	end, 0)
end


return {
	{
		"j-hui/fidget.nvim",
		event = "LspAttach",
		opts = {},
	},

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

	-- ── nvim-lspconfig + Mason + LSP keymaps ─────────────────────────────
	{
		"neovim/nvim-lspconfig",
		-- Eager: a server's config is resolved from the lsp/ files on
		-- 'runtimepath' the first time a buffer asks for it, and a scratch
		-- buffer can ask before any file is read. Enabling at startup also
		-- puts `vim.lsp.enable(name, false)` in lua/user/options.lua last.
		lazy = false,
		-- :LspStart / :LspStop are gone in 0.12 (superseded by :lsp). For [oL, a
		-- bare `:lsp enable` enables every config matching the buffer's
		-- filetype; a bare `:lsp disable`, every config attached to the buffer.
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("nvim-lspconfig", vim.list_extend(
			require("noethervim.toggles").rows("oL", "<cmd>lsp enable<cr>", "<cmd>lsp disable<cr>", "lsp"), {
			{
				"<c-w><c-l>",
				function()
					local clients = vim.lsp.get_clients({ bufnr = 0 })
					if #clients == 0 then
						vim.notify("No LSP clients attached to this buffer", vim.log.levels.INFO)
					else
						local names = vim.tbl_map(function(c) return c.name end, clients)
						vim.notify("LSP: " .. table.concat(names, ", "), vim.log.levels.INFO)
					end
				end,
				desc = require("noethervim.util.icons").nvim_lsp .. " LSP status",
			},

			-- Buffer-local keys, mapped on LspAttach when the server supports
			-- the method. `keymaps = { lsp = false }` in lua/user/config.lua
			-- switches them all off; a buffer key of yours wins.
			{ "gd",    function() vim.lsp.buf.definition() end,      lsp = "textDocument/definition",     set = "lsp", silent = true, desc = "[g]o to [d]efinition" },
			{ "gD",    function() vim.lsp.buf.declaration() end,     lsp = "textDocument/declaration",    set = "lsp", silent = true, desc = "[g]o to [D]eclaration" },
			{ "gt",    function() vim.lsp.buf.type_definition() end, lsp = "textDocument/typeDefinition", set = "lsp", silent = true, desc = "[g]o to [t]ype definition" },
			{ "gi",    function() vim.lsp.buf.implementation() end,  lsp = "textDocument/implementation", set = "lsp", silent = true, desc = "[g]o to [i]mplementation" },
			-- gr/grr/grn/gra: Neovim 0.12 defaults (references, rename, code action)
			{ "gR",    "<cmd>Glance references<cr>", lsp = "textDocument/references",    set = "lsp", silent = true, desc = "[G]lance [R]eferences (float)" },
			{ "gw",    function() vim.lsp.buf.workspace_symbol("") end, lsp = "workspace/symbol", set = "lsp", silent = true, desc = "[g]et [w]orkspace symbols" },
			{ "gs",    function() vim.lsp.buf.signature_help({ border = "rounded" }) end, lsp = "textDocument/signatureHelp", set = "lsp", silent = true, desc = "[g]et [s]ignature" },
			{ "<C-h>", function() vim.lsp.buf.signature_help({ border = "rounded" }) end, mode = "i", lsp = "textDocument/signatureHelp", set = "lsp", silent = true, desc = "signature help" },
			{ "gl",    function() vim.diagnostic.open_float() end, lsp = true, set = "lsp", silent = true, desc = "diagnostics float" },
			{ "]d",    function() vim.diagnostic.jump({ count = 1, on_jump = function() vim.diagnostic.open_float({ border = "rounded" }) end }) end,
				lsp = true, set = "lsp", silent = true, desc = "next [d]iagnostic" },
			{ "[d",    function() vim.diagnostic.jump({ count = -1, on_jump = function() vim.diagnostic.open_float({ border = "rounded" }) end }) end,
				lsp = true, set = "lsp", silent = true, desc = "prev [d]iagnostic" },
			{ "<F1>",  function() vim.lsp.buf.code_action() end, lsp = "textDocument/codeAction", set = "lsp", silent = true, desc = "code action" },
			{ "<F4>",  function() vim.lsp.buf.code_action() end, lsp = "textDocument/codeAction", set = "lsp", silent = true, desc = "code action" },
			{ "<F1>",  function() vim.lsp.buf.code_action() end, mode = "x", lsp = "textDocument/codeAction", set = "lsp", silent = true, desc = "range code action" },
			{ "<F2>",  LspRename, lsp = "textDocument/rename", set = "lsp", silent = true, desc = "rename (with count)" },
			-- <Leader>ff: format via conform (falls back to LSP if no formatter configured)
			{ "<Leader>ff", function() require("conform").format({ lsp_format = "fallback", bufnr = 0 }) end,
				mode = { "n", "x" }, lsp = true, set = "lsp", silent = true, desc = "format buffer" },
			{ "go",    "<cmd>Outline<cr>", lsp = "textDocument/documentSymbol", set = "lsp", silent = true, desc = "symbols [o]utline" },
			{ SearchLeader .. "li", function() vim.lsp.buf.incoming_calls() end, lsp = "callHierarchy/incomingCalls", set = "lsp", silent = true, desc = "[l]sp [i]ncoming calls" },
			{ SearchLeader .. "lO", function() vim.lsp.buf.outgoing_calls() end, lsp = "callHierarchy/outgoingCalls", set = "lsp", silent = true, desc = "[l]sp [O]utgoing calls" },
			{ "gy",    yank_type, lsp = "textDocument/hover", set = "lsp", silent = true, desc = "[y]ank type at cursor" },
		})) },
			{ "which-key.nvim", optional = true, opts = require("noethervim.util").labels({
				{ "<leader>f", icon = { icon = require("noethervim.util").icons.format, color = "red" }, group = "format" },
			}) },
		},
		-- ── Overridable data ─────────────────────────────────────────
		-- Note: ensure_installed is an array -- overriding it REPLACES
		-- the entire list (lazy.nvim does not merge arrays).
		-- `servers` is the enable list. A server whose binary is not
		-- installed stays idle. Turn one off with vim.lsp.enable(name, false)
		-- in lua/user/options.lua.
		opts_extend = { "servers" },
		opts = {
			servers = {
				"basedpyright", "clangd", "cssls", "eslint", "gopls", "lua_ls",
				"marksman", "ruff", "texlab", "ts_ls", "vimls",
			},
			ensure_installed = {
				'lua_ls', 'basedpyright', 'ruff',
			},
			diagnostic = {
				virtual_text  = false,
				severity_sort = true,
				float = { border = 'rounded', source = true },
			},
		},

		config = function(_, opts)
			local icons = require('noethervim.util.icons')

			-- Start with Neovim's built-in capabilities (cheap, no plugin
			-- load) plus the folding-range bits texlab / lua_ls care about.
			-- The blink.cmp enrichment is merged in LATER via the
			-- LspAttach autocmd below -- requiring blink here would pull
			-- ~37ms of submodule loads onto every file open, even when
			-- the user doesn't press `i` to actually trigger completion.
			-- See `:help vim.lsp.protocol.make_client_capabilities`.
			vim.lsp.config('*', {
				capabilities = vim.tbl_deep_extend("force",
					vim.lsp.protocol.make_client_capabilities(),
					{
						textDocument = {
							foldingRange = {
								dynamicRegistration = false,
								lineFoldingOnly = true,
							},
						},
					}
				),
			})

			-- Once blink.cmp finally loads (on InsertEnter / CmdlineEnter),
			-- re-issue `vim.lsp.config('*', ...)` with the enriched
			-- capabilities. Newly-attached clients pick up the fuller set
			-- the next time they initialize; existing clients keep their
			-- current capabilities for the rest of the session (which is
			-- fine -- the default caps cover everything except a few
			-- snippet/resolve niceties).
			vim.api.nvim_create_autocmd("User", {
				pattern = "BlinkCmpSetupComplete",
				once    = true,
				callback = function()
					local ok, blink = pcall(require, "blink.cmp")
					if not ok then return end
					vim.lsp.config('*', {
						capabilities = blink.get_lsp_capabilities({
							textDocument = {
								foldingRange = {
									dynamicRegistration = false,
									lineFoldingOnly     = true,
								},
							},
						}),
					})
				end,
			})


			require('noethervim.default').command('LspRename', LspRename, {})

			vim.api.nvim_create_autocmd('LspAttach', {
				callback = function(args)
					local bufnr  = args.buf
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if not client then return end

					if client.name == 'ts_ls' then
						require('workspace-diagnostics').populate_workspace_diagnostics(client, bufnr)
					end
					if client.name == 'cssls' then
						client.server_capabilities.definitionProvider = false
					end

				end,
			})

			vim.lsp.enable(opts.servers)

			-- Installing the servers in `ensure_installed` waits for the editor
			-- to be up; it is not startup work. `vim.g.noethervim_auto_install
			-- = false` declines it, as it does every other install.
			vim.api.nvim_create_autocmd("User", {
				pattern  = "VeryLazy",
				once     = true,
				callback = function()
					if vim.g.noethervim_auto_install == false then return end
					local plugins = require("lazy.core.config").plugins
					for _, name in ipairs({ "mason.nvim", "mason-lspconfig.nvim" }) do
						if not plugins[name] or plugins[name]._.cond == false then return end
					end
					require("mason-lspconfig").setup({
						ensure_installed = opts.ensure_installed,
						automatic_enable = false,
					})
				end,
			})

			vim.diagnostic.config(opts.diagnostic)

			vim.diagnostic.config({
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = icons.error,
						[vim.diagnostic.severity.WARN]  = icons.warning,
						[vim.diagnostic.severity.HINT]  = icons.loup,
						[vim.diagnostic.severity.INFO]  = icons.info,
					},
				},
			})

			vim.api.nvim_set_hl(0, 'DiagnosticUnderlineHint', { link = 'NONE' })
			vim.api.nvim_set_hl(0, 'DiagnosticUnderlineInfo', { link = 'NONE' })
		end,
	},

	-- Siblings of nvim-lspconfig rather than its dependencies: lspconfig loads
	-- at startup, and none of these needs to.
	--
	-- lazydev: Neovim-API completions for lua_ls. luvit-meta covers vim.uv types.
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = {
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				-- Surface noethervim.UserConfig (and any other public
				-- LuaCATS class under the noethervim.* namespace) in
				-- lua/user/*.lua so the popup menu shows field docs
				-- and typos are flagged. Gated by `words` so the
				-- distribution source only loads into lua_ls when
				-- the buffer actually references it.
				{ path = "NoetherVim",         words = { "noethervim%." } },
			},
		},
	},
	{ "Bilal2453/luvit-meta", lazy = true },
	{
		"williamboman/mason.nvim",
		build = function()
			pcall(vim.cmd, "MasonUpdate")
		end,
		-- mason.setup() is what appends the package registries, and
		-- the keymap below can load mason.nvim on its own without
		-- loading nvim-lspconfig. Setting it up from lspconfig's
		-- config would leave the registry empty on that path, so
		-- every installed package reads as "removed from the
		-- registry" and nothing is available to install.
		opts = {
			ui = {
				border = 'rounded',
				icons = {
					package_installed   = '✓',
					package_pending     = '➜',
					package_uninstalled = '✗',
				},
			},
		},
		cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUpdate", "MasonLog" },
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("mason.nvim", {
			{ "<c-w><c-m>", function() require("mason.ui").open() end,
				desc = require("noethervim.util.icons").mason .. " Mason" },
		}) } },
	},
	-- Loaded by the first ts_ls attach (lspconfig's LspAttach handler).
	{ "artemave/workspace-diagnostics.nvim", lazy = true, opts = {} },
	-- Loaded at VeryLazy by lspconfig's config to install `ensure_installed`.
	{ "williamboman/mason-lspconfig.nvim", lazy = true, dependencies = { "williamboman/mason.nvim" } },
	{
		"hedyhli/outline.nvim",
		cmd = { "Outline", "OutlineOpen" },
		opts = {
			outline_window = { auto_close = true },
			preview_window = { auto_preview = true },
			symbol_folding = { autofold_depth = 1 },
		},
	},

	{
		"dnlhc/glance.nvim",
		event = "VeryLazy",
		opts = {},
	},
}
