-- NoetherVim plugin: Blink.cmp Completion
--  ╔══════════════════════════════════════════════════════════╗
--  ║                   Blink.cmp Completion                   ║
--  ╚══════════════════════════════════════════════════════════╝
--
-- Part 1: core built-in sources (LSP, snippets, lazydev, path, buffer).
-- Part 2: custom sources (todos, user_config) as native blink modules.
-- LuaSnip's spec wires it in as the snippet engine, and the latex bundle
-- adds VimTeX's completion for tex.
--
-- Replaces nvim-cmp and all hrsh7th satellite plugins.
--

return {
	{
		"saghen/blink.cmp",
		version = "1.*", -- pre-built binaries, no Rust toolchain needed
		event = { "InsertEnter", "CmdlineEnter" },
		-- Native <C-Space> fallback: blink overrides this with buffer-local
		-- keymaps on InsertEnter; when blink is disabled (]oC toggle), blink
		-- skips the buffer-local keymap and this global mapping fires instead.
		specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("blink.cmp", vim.list_extend({
			{ "<C-Space>", function() vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", false) end,
				mode = "i", desc = "native keyword completion" },
		-- `enabled` below reads vim.g.blink_toggle.
		}, require("noethervim.toggles").rows("oC",
			function() vim.g.blink_toggle = true end,
			function() vim.g.blink_toggle = false end,
			"completion"))) } },
		opts = {
			-- [oC / ]oC (above) flip vim.g.blink_toggle.
			enabled = function()
				return vim.g.blink_toggle ~= false
			end,

			-- ── Keymaps ────────────────────────────────────────────────────────
			-- Tab philosophy: set `completion = { style = ... }` in
			-- lua/user/config.lua to "snippet" (default), "supertab", or
			-- "navigate". See :help noethervim-completion-style for behaviour
			-- and AI-completion notes.
			keymap = (function()
				local completion = require("noethervim.config").get().completion
				local style = type(completion) == "table" and completion.style or "snippet"
				local base = {
					preset    = "none",
					["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
					["<C-e>"]     = { "hide", "fallback" },
					["<C-y>"]     = { "accept", "fallback" },
					["<C-n>"]     = { "select_next", "fallback" },
					["<C-p>"]     = { "select_prev", "fallback" },
					["<C-b>"]     = { "scroll_documentation_up", "fallback" },
					["<C-f>"]     = { "scroll_documentation_down", "fallback" },
					["<S-Tab>"]   = { "snippet_backward", "fallback" },
				}
				if style == "supertab" then
					base["<Tab>"] = {
						-- snippet_forward runs FIRST so an expandable LuaSnip
						-- trigger at the cursor (e.g. `:defn` in tex) wins over
						-- whatever the menu is currently showing (vimtex, lsp,
						-- buffer words). Without this, Tab accepts the menu's
						-- first match and the snippet never gets a chance.
						"snippet_forward",
						function(cmp)
							if not cmp.is_visible() then return end
							-- blink's select_and_accept / accept schedule the
							-- text-edit asynchronously and expose a `callback`
							-- option that fires AFTER the edit lands. Using
							-- vim.schedule for the trailing space races with
							-- that internal schedule -- the space gets fed
							-- first, the accept then replaces the typed keyword
							-- *plus* the inserted space at the wrong cursor
							-- position, producing "pro progress" instead of
							-- "progress ". Hand the space to the post-accept
							-- callback so order is guaranteed.
							local function append_space()
								vim.api.nvim_feedkeys(" ", "n", false)
							end
							if cmp.select_and_accept then
								return cmp.select_and_accept({ callback = append_space })
							end
							return cmp.accept({ callback = append_space })
						end,
						"fallback",
					}
				elseif style == "navigate" then
					-- Tab cycles forward through the menu without accepting; an
					-- explicit C-y or <CR> commits. S-Tab cycles backward (already
					-- shadowed below to drop snippet_backward in this style).
					base["<Tab>"]   = { "select_next", "snippet_forward",  "fallback" }
					base["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" }
				else
					base["<Tab>"] = { "snippet_forward", "fallback" }
				end
				return base
			end)(),


			-- ── Sources ─────────────────────────────────────────────────────────
			sources = {
				default = { "lsp", "snippets", "path", "buffer", "todos" },

				per_filetype = {
					lua = { "lsp", "snippets", "lazydev", "path", "buffer", "todos", "user_config" },
				},

				min_keyword_length = 2,

				providers = {
					lazydev = {
						name         = "LazyDev",
						module       = "lazydev.integrations.blink",
						score_offset = 100,
					},

					buffer = {
						min_keyword_length = 4, -- buffer words only after 4+ chars
						max_items          = 5,
						opts = {
							-- Default scans all visible windows; restrict to current buffer.
							get_bufnrs = function()
								return { vim.api.nvim_get_current_buf() }
							end,
						},
					},

					-- ── Step 3: custom native blink sources ───────────────────────────
					todos = {
						name   = "todos",
						module = "noethervim.sources.todos",
					},
					-- Values for the fixed-vocabulary fields in
					-- lua/user/config.lua. Gates itself on the filename, so it
					-- costs nothing in every other Lua buffer.
					user_config = {
						name   = "NoetherVim config",
						module = "noethervim.sources.user_config",
					},
				},
			},

			-- ── Completion trigger ──────────────────────────────────────────────
			-- show_on_keyword starts false (conservative default).
			-- A config= function below dynamically swaps this boolean per buffer
			-- via autocmds, since blink v1 validates it must be a boolean.
			completion = {
				trigger = {
					show_on_keyword = false,
				},
				-- Blink owns bracket insertion after accept.
				-- Removes the need for the nvim-autopairs cmp confirm hook;
				-- nvim-autopairs itself stays active for its other features.
				accept = { auto_brackets = { enabled = true } },

				documentation = {
					auto_show          = true,
					auto_show_delay_ms = 100,
					window = { border = "rounded" },
				},

				menu = {
					border = "rounded",
					draw = {
						columns = {
							{ "label", "label_description", gap = 1 },
							{ "kind_icon", "kind", gap = 1 },
						},
					},
				},

				-- noselect: don't pre-highlight or auto-insert the first item.
				-- Matches the previous `completeopt = noselect` behaviour.
				list = {
					max_items  = 20, -- default is 200; rank+render 200 items/keystroke is heavy
					selection  = { preselect = false, auto_insert = false },
				},
			},

			-- ── Cmdline ──────────────────────────────────────────────────────────
			-- blink v1: cmdline is a top-level mode config, NOT a sources entry.
			-- Tab/S-Tab: insert_next/prev cycles through items AND inserts the
			-- selected text into the cmdline via setcmdline().
			-- preselect=false: blink's cmdline default (preselect=true) pre-selects
			-- item 1 when the menu auto-shows, so the first Tab would skip to item 2.
			-- With preselect=false, first Tab correctly selects+inserts item 1.
			cmdline = {
				keymap = {
					preset = "cmdline",
					["<Tab>"]   = { "insert_next" },
					["<S-Tab>"] = { "insert_prev" },
				},
				completion = {
					menu = { auto_show = true },
					list = { selection = { preselect = false, auto_insert = true } },
				},
			},

			-- ── Fuzzy ────────────────────────────────────────────────────────────
			fuzzy = {
				-- max_typos > 0 runs a more expensive algorithm.
				-- 0 = exact prefix matching: faster and more predictable.
				max_typos = 0,
			},

			-- ── Signature help ───────────────────────────────────────────────────
			-- Replaces cmp-nvim-lsp-signature-help.
			signature = {
				enabled = true,
				window  = { border = "rounded" },
			},
		},
		-- blink v1 validates show_on_keyword as boolean, so we can't pass a function
		-- in opts. Instead, after setup we swap the boolean per buffer via autocmds.
		config = function(_, opts)
			-- Disable Neovim's built-in wildchar (Tab) so blink fully owns
			-- cmdline completion. Without this, both wildmenu and blink
			-- fight over Tab in cmdline mode.
			-- Through noethervim.default, so a wildchar of yours stays.
			local default = require("noethervim.default")
			default.o("wildchar", 0)
			default.o("wildcharm", vim.fn.char2nr(vim.api.nvim_replace_termcodes("<C-z>", true, false, true)))

			require("blink.cmp").setup(opts)

			-- Signal to deferred consumers (e.g. lsp.lua's capabilities
			-- enrichment) that blink is fully initialized and safe to
			-- require. Fired once per session.
			vim.api.nvim_exec_autocmds("User", {
				pattern  = "BlinkCmpSetupComplete",
				modeline = false,
			})

			-- Monkey-patch undo_preview: when the cursor has moved since the
			-- preview was applied (user typed/deleted), commit the preview
			-- instead of reverting it. Without this, the cursor-compensation
			-- in the undo text-edit sweeps up the user's keystrokes and
			-- corrupts the cmdline text.
			local cmp_list    = require("blink.cmp.completion.list")
			local cmp_context = require("blink.cmp.completion.trigger.context")
			local orig_undo   = cmp_list.undo_preview
			cmp_list.undo_preview = function()
				if cmp_list.preview_undo then
					local expected = cmp_list.preview_undo.cursor_after
					local actual   = cmp_context.get_cursor()
					if expected and actual and actual[2] ~= expected[2] then
						cmp_list.preview_undo = nil
						return
					end
				end
				return orig_undo()
			end

			local function set_keyword_trigger()
				local ok_blink, blink_cfg = pcall(require, "blink.cmp.config")
				if not ok_blink then return end

				-- Skip cmdline mode: completions there are handled by sources.cmdline,
				-- not by the show_on_keyword toggle.
				if vim.fn.mode():match("^c") then return end

				-- Skip floating windows and non-normal buffers (e.g. blink's own popup).
				-- Without this, BufEnter on the completion popup would flip show_on_keyword
				-- to true while editing a conservative filetype.
				local win = vim.api.nvim_get_current_win()
				if vim.api.nvim_win_get_config(win).relative ~= "" then return end
				if vim.bo.buftype ~= "" then return end

				-- The writing system decides which buffers are conservative
				-- (profiles/apply.lua sets the flag on FileType).
				blink_cfg.completion.trigger.show_on_keyword = vim.b.noethervim_conservative ~= true
			end

			local grp = vim.api.nvim_create_augroup("noethervim_blink_keyword", { clear = true })
			vim.api.nvim_create_autocmd({ "BufEnter", "FileType" },
				{ group = grp, callback = set_keyword_trigger })
			-- In cmdline mode, always enable show_on_keyword so typing command names
			-- triggers completions. (Our conservative show_on_keyword=false for tex
			-- buffers is a buffer-level setting; we don't want it to bleed into ':'.)
			-- On leave, set_keyword_trigger restores the per-buffer value.
			vim.api.nvim_create_autocmd("CmdlineEnter", {
				group = grp,
				callback = function()
					local ok_b, bcfg = pcall(require, "blink.cmp.config")
					if ok_b then bcfg.completion.trigger.show_on_keyword = true end
				end,
			})
			vim.api.nvim_create_autocmd("CmdlineLeave", {
				group = grp,
				callback = set_keyword_trigger,
			})
			vim.schedule(set_keyword_trigger)
		end,
	},
}
