-- NoetherVim plugin: Oil file explorer
-- Open with: <C-w><C-o> (float) or :Oil (replace buffer)
--
-- Most keys below bind oil-extras actions (:h oil-extras-actions); press g?
-- inside Oil for the full list, defaults included.
--   <S-CR>      Apply pending edits. Leaves Oil only from normal mode and
--               only when nothing needed confirming; otherwise stays put
--   <C-p>       Preview the entry under the cursor, following the cursor
--   gd          Toggle detail columns (permissions, size, mtime)
--   gf / gG     Find files / live grep in the current directory
--   gV / g|     Second Oil pane beside this one; <C-h>/<C-l> switch, gV/q leave
--   gX          Open directory in system file browser
--   gS          Create symlink in current directory
--   gz / gZ     Zip / unzip the entry, the visual range or the selection
--   g. / g\     Toggle hidden files / trash
--   gm          Select mode: mark scattered entries, then act on them together
--   Y           Copy file(s) to the system clipboard
--   yp / yd / yn   Yank full path / parent dir / name
--   Yp / Yd / Yn   Same, but straight to the system clipboard (+)
--
-- Columns: only `icon`. Size and mtime come from oil-extras' details, painted
-- as virtual text after the listing renders, so a large directory never sits
-- empty waiting on a stat per entry.

return {
	{
		"stevearc/oil.nvim",
		-- Loaded on demand rather than at startup, which costs ~3.5 ms on
		-- every launch. Nothing is lost in exchange: netrw is off from the
		-- start (`g` data below), and the startup entry loads oil the moment
		-- a directory buffer exists, `nvim .` included.
		lazy = true,
		config = function(_, opts)
			-- Read before setup(), which renames a directory buffer to oil://.
			local cur = vim.api.nvim_buf_get_name(0)
			local oil = require("oil")
			oil.setup(opts)

			-- `nvim .`: paint the listing now. Oil renders from an async
			-- scandir callback, and once VimEnter fires lazy loads the
			-- VeryLazy wave (treesitter, blink.cmp, gitsigns, which-key, ...),
			-- which holds the main thread for a few hundred ms; the listing
			-- would paint after it. Opening it here and waiting for the first
			-- render shows it first and the wave streams in behind.
			if vim.v.vim_did_enter == 0 and cur ~= "" and vim.fn.isdirectory(cur) == 1 then
				local painted = false
				local au = vim.api.nvim_create_autocmd("User", {
					pattern  = "OilEnter",
					once     = true,
					callback = function() painted = true end,
				})
				pcall(oil.open, cur)
				vim.wait(1000, function() return painted end, 5)
				pcall(vim.api.nvim_del_autocmd, au)
			end
		end,
		specs = {
			{ "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("oil.nvim", {
				{ "<c-w><c-o>", function() require("oil").open_float() end, desc = "Oil Mode" },
			}, {
				g = { loaded_netrw = 1, loaded_netrwPlugin = 1 },
				startup = { ["oil.directories"] = function()
					local group = vim.api.nvim_create_augroup("noethervim.oil", { clear = true })
					-- A directory buffer made later (`:e somedir/`, a session)
					-- loads oil, and oil's own BufAdd takes over from then on.
					vim.api.nvim_create_autocmd("BufAdd", {
						group    = group,
						nested   = true,
						callback = function(args)
							local name = vim.api.nvim_buf_get_name(args.buf)
							if name == "" or vim.fn.isdirectory(name) == 0 then return end
							require("oil")
							-- oil.setup() hijacks the *current* buffer into an
							-- oil:// buffer, but the buffer that tripped this
							-- (args.buf) is often not current yet: `:e .` from
							-- the dashboard or an open file makes a new directory
							-- buffer while the old one is still current. It would
							-- reach its BufReadCmd still named `/path`, match no
							-- oil pattern, and stay blank. So rename it the way
							-- oil's own maybe_hijack_directory_buffer does.
							if vim.api.nvim_buf_is_valid(args.buf)
								and not vim.api.nvim_buf_get_name(args.buf):find("://", 1, true)
							then
								pcall(function()
									local ocfg  = require("oil.config")
									local ofs   = require("oil.fs")
									local outil = require("oil.util")
									outil.rename_buffer(args.buf, outil.addslash(
										ocfg.adapter_to_scheme.files .. ofs.os_to_posix_path(vim.fn.fnamemodify(name, ":p"))))
								end)
							end
							pcall(vim.api.nvim_del_augroup_by_id, group)
						end,
					})
					-- `nvim .`: the argv buffer was made before any of this.
					local cur = vim.api.nvim_buf_get_name(0)
					if cur ~= "" and vim.fn.isdirectory(cur) == 1 then
						pcall(vim.api.nvim_del_augroup_by_id, group)
						require("oil")
					end
				end },
			}) },
		},
		cmd  = { "Oil" },
		dependencies = { "nvim-tree/nvim-web-devicons", "Chiarandini/oil-extras.nvim" },
		-- A function, so the oil-extras actions are read once the dependency
		-- has loaded rather than while lazy is still reading specs.
		opts = function()
			local x = require("oil_extras.actions")
			return {
				default_file_explorer = true,
				columns = { "icon" },
				buf_options = {
					buflisted = false,
					bufhidden = "hide",
				},
				win_options = {
					wrap = false,
					signcolumn = "no",
					cursorcolumn = true,
					cursorline = true,
					foldcolumn = "0",
					spell = false,
					list = false,
					conceallevel = 3,
					concealcursor = "nvic",
				},
				delete_to_trash = true,
				skip_confirm_for_simple_edits = false,
				prompt_save_on_select_new_entry = true,
				cleanup_delay_ms = 2000,
				lsp_file_methods = {
					enabled = true,
					timeout_ms = 1000,
					autosave_changes = false,
				},
				constrain_cursor = "editable",
				watch_for_changes = true,
				keymaps = {
					["g?"] = { "actions.show_help", mode = "n" },
					["<CR>"] = "actions.select",
					-- The finishing variant of the plain key, the shape <S-CR> already has
					-- in the quickfix window and the browse picker. Buffer-local, so it
					-- shadows smart-enter's global insert <S-CR> only inside Oil, where
					-- that key has nothing to offer.
					["<S-CR>"] = x.save_and_leave,
					["<C-s>"] = { "actions.select", opts = { vertical = true } },
					["<C-h>"] = {},
					["<C-l>"] = {},
					["<C-s-r>"] = "actions.refresh",
					["<C-t>"] = { "actions.select", opts = { tab = true } },
					["<C-p>"] = "actions.preview",
					["<C-c>"] = { "actions.close", mode = "n" },
					["-"] = { "actions.parent", mode = "n" },
					["_"] = { "actions.open_cwd", mode = "n" },
					["`"] = { "actions.cd", mode = "n" },
					["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
					["gs"] = { "actions.change_sort", mode = "n" },
					["gd"] = x.toggle_details,
					["gx"] = "actions.open_external",
					["gX"] = x.open_dir_external,
					["gf"] = x.find_files,
					["gG"] = x.grep,
					-- Two keys for one action, deliberately. `gV` sits with the other
					-- `g`-prefixed Oil additions; `g|` echoes the `|` this distribution
					-- uses for a vertical split, and says "second pane" where `V` only
					-- says "vertical".
					["gV"] = x.dual_pane,
					["g|"] = x.dual_pane,
					-- `m` for mark. Off SearchLeader on purpose: the mode changes what
					-- `y` and `d` mean, and SearchLeader is side-effect free.
					["gm"] = x.select,
					["g."] = { "actions.toggle_hidden", mode = "n" },
					["g\\"] = { "actions.toggle_trash", mode = "n" },
					["yp"] = { x.yank_path, mode = "n", desc = "yank full path" },
					["yd"] = { x.yank_path, mode = "n", desc = "yank parent dir", opts = { modify = ":h" } },
					["yn"] = { x.yank_path, mode = "n", desc = "yank name", opts = { modify = ":t" } },
					["Yp"] = { x.yank_path, mode = "n", desc = "yank full path (+clip)", opts = { register = "+" } },
					["Yd"] = { x.yank_path, mode = "n", desc = "yank parent dir (+clip)", opts = { modify = ":h", register = "+" } },
					["Yn"] = { x.yank_path, mode = "n", desc = "yank name (+clip)", opts = { modify = ":t", register = "+" } },
					["Y"] = x.copy_to_clipboard,
					["gz"] = x.zip,
					["gZ"] = x.unzip,
					["gS"] = x.symlink,
				},
				use_default_keymaps = true,
				view_options = {
					show_hidden = true,
					is_hidden_file = function(name)
						return name:match("^%.") ~= nil
					end,
					natural_order = "fast",
					case_insensitive = false,
					sort = {
						{ "type", "asc" },
						{ "name", "asc" },
					},
				},
				extra_scp_args = {},
				git = {
					add = function() return false end,
					mv = function() return false end,
					rm = function() return false end,
				},
				float = {
					padding = 2,
					max_width = 0,
					max_height = 0,
					border = "rounded",
					-- IMPORTANT: oil's float opens a NEW window and applies only
					-- `float.win_options` to it (see oil.nvim/init.lua:269) -- the
					-- outer `win_options` table is NOT carried over. So anything
					-- the float must inherit goes here too. Without conceallevel
					-- the float renders oil's `^/\d+ ` entry-id prefixes (which
					-- are concealed by oil's syntax file) as raw text.
					win_options = {
						winblend       = 10,
						conceallevel   = 3,
						concealcursor  = "nvic",
					},
					preview_split = "auto",
					override = function(conf) return conf end,
				},
				preview_win = {
					update_on_cursor_moved = true,
					preview_method = "fast_scratch",
				},
				confirmation = {
					max_width = 0.9,
					min_width = { 40, 0.4 },
					max_height = 0.9,
					min_height = { 5, 0.1 },
					border = "rounded",
				},
				progress = {
					max_width = 0.9,
					min_width = { 40, 0.4 },
					max_height = { 10, 0.9 },
					min_height = { 5, 0.1 },
					border = "rounded",
					minimized_border = "none",
				},
				ssh = { border = "rounded" },
				keymaps_help = { border = "rounded" },
			}
		end,
	},
	-- Its file and grep pickers (gf, gG) open through the picker seam, so a
	-- routed engine serves them too.
	{ "Chiarandini/oil-extras.nvim", lazy = true, opts = {
		picker = function(source, opts) require("noethervim.pick").open(source, opts) end,
	} },
}
