-- NoetherVim plugin: Oil file explorer
-- Open with: <C-w><C-o> (float) or :Oil (replace buffer)
--
-- Custom keymaps (in addition to Oil defaults -- press g? inside Oil):
--   gd          Toggle detail view (adds permissions to default size + mtime)
--   gf          Fuzzy find in current directory
--   gG          Live grep in current directory
--   gV          Pick destination and open dual-pane float (q closes both)
--   gX          Open directory in system file browser
--   gS          Create symlink in current directory
--   gz          Zip entry under cursor (normal) or selected entries (visual)
--   gZ          Unzip .zip entry (normal) or selected .zip entries (visual)
--   g.          Toggle hidden files
--   g\          Toggle trash
--   Y           Copy file(s) to the system clipboard. Normal yanks the
--               entry under the cursor; visual yanks every selected entry,
--               skipping "../" and unsaved lines.
--   yp / yd / yn   Yank full path / dir / filename to unnamed register
--   Yp / Yd / Yn   Same, but straight to the system clipboard (+)

-- Columns: only `icon` by default. Size/mtime metadata is rendered as
-- virt_text via the `User OilEnter` handler below, NOT as real oil
-- columns. Why: real columns with `require_stat = true` make oil block
-- on `cb_collect(#entries, ...)` for every fs_stat before rendering
-- (see oil.nvim:adapters/files.lua:484). That visible "buffer empty for
-- a beat, then populates" delay is exactly what virt_text avoids --
-- extmarks paint in as stats arrive, one row at a time, with no gate on
-- the directory listing itself.
--
-- `gd` switches to the real-column verbose view (icon + permissions +
-- size + mtime) for the rare moments you want sortable / editable
-- permissions; that view accepts the stat-wait.
local default_columns = { "icon" }
local detail_columns  = { "icon", "permissions", "size", "mtime" }
local detail = false

-- ── Async virt_text metadata ──────────────────────────────────────────
-- Render size + mtime as eol virt_text on each oil row. We listen to
-- `User OilEnter` (fired by oil after every render -- entry, refresh,
-- toggle hidden, change sort) and async-stat each visible entry. The
-- buffer is already on screen by then; extmarks paint in as the stat
-- callbacks resolve. No render is blocked.
local meta_ns = vim.api.nvim_create_namespace("noethervim.oil.meta")

local function format_size(bytes)
	if bytes >= 1e9 then return string.format("%6.1fG", bytes / 1e9) end
	if bytes >= 1e6 then return string.format("%6.1fM", bytes / 1e6) end
	if bytes >= 1e3 then return string.format("%6.1fk", bytes / 1e3) end
	return string.format("%5dB ", bytes)
end

-- Mirror oil's built-in mtime column format: "Mon DD HH:MM" for this
-- year, "Mon DD  YYYY" for other years, so the visual feel matches the
-- detail view.
local _current_year
local function format_mtime(sec)
	if not sec then return "" end
	_current_year = _current_year or os.date("%Y")
	if os.date("%Y", sec) ~= _current_year then
		return os.date("%b %d  %Y", sec)
	end
	return os.date("%b %d %H:%M", sec)
end

-- Per-session stat cache. fs_stat is fast, but oil refires OilEnter on
-- every change-sort / toggle-hidden / cd, so caching saves a pile of
-- redundant calls. Keyed by absolute path; invalidated on directory
-- mutation by oil's own refresh, which renames buffers and changes
-- listings -- stale entries can't surface that way.
local stat_cache = {}

local function decorate_oil_buffer(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end
	local ok, oil = pcall(require, "oil")
	if not ok then return end
	local dir = oil.get_current_dir(bufnr)
	if not dir then return end

	vim.api.nvim_buf_clear_namespace(bufnr, meta_ns, 0, -1)

	local uv    = vim.uv or vim.loop
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- First pass: find the widest entry line so the metadata column can
	-- start at the same screen column on every row. Skip `../` (no
	-- metadata) and unsaved rows (entry.id == 0). `strdisplaywidth`
	-- handles wide glyphs (the file icon) and multibyte filenames.
	local widths = {}
	local max_w  = 0
	for lnum = 1, #lines do
		local entry = oil.get_entry_on_line(bufnr, lnum)
		if entry and entry.name and entry.name ~= ".." and entry.id and entry.id ~= 0 then
			local w = vim.fn.strdisplaywidth(lines[lnum])
			widths[lnum] = w
			if w > max_w then max_w = w end
		end
	end

	-- Second pass: async-stat each entry, paint when the stat resolves.
	-- The leading-space pad = (max_w - this row's width) + a 2-space
	-- gutter, so every metadata block starts at column `max_w + 2`.
	for lnum, w in pairs(widths) do
		local entry = oil.get_entry_on_line(bufnr, lnum)
		if entry then
			local path     = dir .. entry.name
			local lead_pad = string.rep(" ", (max_w - w) + 2)
			local function paint(stat)
				if not stat then return end
				if not vim.api.nvim_buf_is_valid(bufnr) then return end
				local size_txt  = (stat.type == "directory") and "      " or format_size(stat.size)
				local mtime_txt = format_mtime(stat.mtime and stat.mtime.sec)
				local text      = lead_pad .. size_txt .. "  " .. mtime_txt
				pcall(vim.api.nvim_buf_set_extmark, bufnr, meta_ns, lnum - 1, 0, {
					virt_text     = { { text, "Comment" } },
					virt_text_pos = "eol",
					hl_mode       = "combine",
					invalidate    = true,
				})
			end

			local cached = stat_cache[path]
			if cached then
				paint(cached)
			else
				uv.fs_stat(path, vim.schedule_wrap(function(err, stat)
					if not err and stat then
						stat_cache[path] = stat
						paint(stat)
					end
				end))
			end
		end
	end
end

-- Yank the entry under the cursor. `mods` is a |fnamemodify()| mods string
-- (e.g. ":h", ":t"), or nil for the full path. `reg` is the target register
-- ("+" for system clipboard, "" for unnamed).
-- We apply fnamemodify to the raw path first, then append a trailing "/" for
-- directories only when showing the full path -- otherwise `:h` returns the
-- directory itself instead of its parent, and `:t` returns an empty string.
local function yank_entry(reg, mods)
	return function()
		local oil = require("oil")
		local entry, dir = oil.get_cursor_entry(), oil.get_current_dir()
		if not entry or not dir then return end
		local path = dir .. entry.name
		if mods then
			path = vim.fn.fnamemodify(path, mods)
		elseif entry.type == "directory" then
			path = path .. "/"
		end
		vim.fn.setreg(reg, path)
		if reg == "+" then vim.notify("Copied: " .. path) end
	end
end

-- Copy the visual-selection entries to the macOS system clipboard as proper
-- Finder file references. Oil's upstream copy_to_system_clipboard refuses
-- multi-file visual mode on macOS because its AppleScript hardcodes
-- `first item of args`; even if we bypass that with writeObjects: over
-- NSURLs, Finder's Cmd+V only pastes the first item because it reads
-- public.file-url from pasteboardItem 0 and stops. Declaring
-- NSFilenamesPboardType as the primary flavor and setting it to a path-list
-- property list routes Finder down the multi-file paste branch. Linux uses
-- Oil's upstream (xclip/wl-copy with text/uri-list) instead.
local mac_clipboard_jxa = [[
function run(argv) {
  ObjC.import("AppKit");
  var pb = $.NSPasteboard.generalPasteboard;
  pb.clearContents;
  pb.declareTypesOwner($.NSArray.arrayWithObject("NSFilenamesPboardType"), $.nil);
  var paths = $.NSMutableArray.alloc.init;
  for (var i = 0; i < argv.length; i++) {
    paths.addObject(argv[i]);
  }
  pb.setPropertyListForType(paths, "NSFilenamesPboardType");
}
]]

local function mac_copy_visual_selection()
	local oil = require("oil")
	local dir = oil.get_current_dir()
	if not dir then return end

	local paths = {}
	local s, e = vim.fn.line("v"), vim.fn.line(".")
	if s > e then s, e = e, s end
	for lnum = s, e do
		local entry = oil.get_entry_on_line(0, lnum)
		if entry and entry.id and entry.id ~= 0 then
			table.insert(paths, dir .. entry.name)
		end
	end
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

	if #paths == 0 then
		vim.notify("Oil: no files to copy", vim.log.levels.WARN)
		return
	end

	local cmd = { "osascript", "-l", "JavaScript", "-e", mac_clipboard_jxa }
	for _, p in ipairs(paths) do table.insert(cmd, p) end

	vim.system(cmd, { text = true }, function(out)
		vim.schedule(function()
			if out.code ~= 0 then
				vim.notify("Clipboard copy failed: " .. (out.stderr or ""), vim.log.levels.ERROR)
			else
				vim.notify(string.format("Copied %d file%s to clipboard",
					#paths, #paths == 1 and "" or "s"))
			end
		end)
	end)
end

-- Collect entry basenames from the current oil buffer. In visual mode, returns
-- every selected entry (skipping "../" and unsaved lines); in normal mode,
-- returns just the entry under the cursor. Returns (dir, names).
local function collect_entries()
	local oil = require("oil")
	local dir = oil.get_current_dir()
	if not dir then return nil, {} end
	local names = {}
	if vim.fn.mode():match("^[vV\22]") then
		local s, e = vim.fn.line("v"), vim.fn.line(".")
		if s > e then s, e = e, s end
		for line = s, e do
			local entry = oil.get_entry_on_line(0, line)
			if entry and entry.id and entry.id ~= 0 then
				table.insert(names, entry.name)
			end
		end
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	else
		local entry = oil.get_cursor_entry()
		if entry and entry.id and entry.id ~= 0 then
			table.insert(names, entry.name)
		end
	end
	return dir, names
end

-- Zip entries under cursor / in visual selection to a .zip in the current oil
-- directory. Uses `zip -r` on macOS/Linux and PowerShell's Compress-Archive on
-- Windows; both are stock on their respective platforms.
local function zip_entries()
	local dir, names = collect_entries()
	if not dir then return end
	if #names == 0 then
		vim.notify("Oil: nothing to zip", vim.log.levels.WARN)
		return
	end

	local is_windows = vim.fn.has("win32") == 1
	local tool = is_windows and "powershell" or "zip"
	if vim.fn.executable(tool) == 0 then
		vim.notify(
			string.format("Oil: '%s' not found in PATH -- cannot create zip", tool),
			vim.log.levels.ERROR
		)
		return
	end

	-- Defer prompt so the queued <Esc> (visual-mode exit) processes first.
	vim.schedule(function()
		local base = #names == 1 and names[1]:gsub("/$", "") or "archive"
		local archive = vim.fn.input({ prompt = "Archive name: ", default = base .. ".zip", cancelreturn = "" })
		if archive == "" then return end
		if not archive:lower():match("%.zip$") then archive = archive .. ".zip" end

		local cmd
		if is_windows then
			local quoted = {}
			for _, n in ipairs(names) do
				table.insert(quoted, "'" .. n:gsub("'", "''") .. "'")
			end
			local ps = string.format(
				"Compress-Archive -Path %s -DestinationPath '%s' -Force",
				table.concat(quoted, ","),
				archive:gsub("'", "''")
			)
			cmd = { "powershell", "-NoProfile", "-NonInteractive", "-Command", ps }
		else
			cmd = { "zip", "-rq", archive }
			for _, n in ipairs(names) do table.insert(cmd, n) end
		end

		vim.fn.jobstart(cmd, {
			cwd = dir,
			on_exit = function(_, code)
				vim.schedule(function()
					if code == 0 then
						vim.notify(string.format(
							"Zipped %d entr%s → %s",
							#names, #names == 1 and "y" or "ies", archive
						))
						require("oil.actions").refresh.callback()
					else
						vim.notify("Oil: zip failed (exit " .. code .. ")", vim.log.levels.ERROR)
					end
				end)
			end,
		})
	end)
end

-- Unzip selected .zip entries into a destination directory. Uses `unzip -oq`
-- on macOS/Linux and PowerShell's Expand-Archive on Windows; both overwrite
-- existing files silently. Non-zip entries in the selection are skipped.
local function unzip_entries()
	local dir, all_names = collect_entries()
	if not dir then return end

	local zips, skipped = {}, 0
	for _, n in ipairs(all_names) do
		if n:lower():match("%.zip$") then
			table.insert(zips, n)
		else
			skipped = skipped + 1
		end
	end

	if #zips == 0 then
		vim.notify("Oil: no .zip entries to extract", vim.log.levels.WARN)
		return
	end

	local is_windows = vim.fn.has("win32") == 1
	local tool = is_windows and "powershell" or "unzip"
	if vim.fn.executable(tool) == 0 then
		vim.notify(
			string.format("Oil: '%s' not found in PATH -- cannot extract zip", tool),
			vim.log.levels.ERROR
		)
		return
	end

	-- Defer prompt so the queued <Esc> (visual-mode exit) processes first.
	vim.schedule(function()
		local dest = vim.fn.input({ prompt = "Extract to: ", default = ".", completion = "dir", cancelreturn = "" })
		if dest == "" then return end

		local pending, failed = #zips, 0
		local function finish()
			pending = pending - 1
			if pending > 0 then return end
			vim.schedule(function()
				if failed == 0 then
					local msg = string.format(
						"Extracted %d archive%s → %s",
						#zips, #zips == 1 and "" or "s", dest
					)
					if skipped > 0 then msg = msg .. string.format(" (skipped %d non-zip)", skipped) end
					vim.notify(msg)
				else
					vim.notify(
						string.format("Oil: %d of %d extractions failed", failed, #zips),
						vim.log.levels.ERROR
					)
				end
				require("oil.actions").refresh.callback()
			end)
		end

		for _, zip in ipairs(zips) do
			local cmd
			if is_windows then
				cmd = {
					"powershell", "-NoProfile", "-NonInteractive", "-Command",
					string.format(
						"Expand-Archive -Path '%s' -DestinationPath '%s' -Force",
						zip:gsub("'", "''"), dest:gsub("'", "''")
					),
				}
			else
				cmd = { "unzip", "-oq", zip, "-d", dest }
			end
			vim.fn.jobstart(cmd, {
				cwd = dir,
				on_exit = function(_, code)
					if code ~= 0 then failed = failed + 1 end
					finish()
				end,
			})
		end
	end)
end

return {
	{
		"stevearc/oil.nvim",
		-- ── Lazy-load oil on demand instead of `lazy = false`. ─────────────
		-- `init` runs at spec-resolution time (during lazy.setup), BEFORE
		-- runtime plugins like netrw load. We:
		--   1. Disable netrw early (same effect as oil's setup would have
		--      had, just hoisted up so it's in place before netrw's plugin
		--      file is sourced). Stays scoped to oil's spec -- remove the
		--      oil bundle and netrw is back.
		--   2. Register a one-shot BufAdd that pulls oil in the moment a
		--      directory buffer is created. This covers `nvim .`, `:e dir/`,
		--      session-restored directory buffers, anything. After the first
		--      hit we delete the augroup -- oil's own BufAdd takes over from
		--      then on.
		--
		-- Load triggers (besides the directory shim above):
		--   * `cmd = "Oil"`           -- `:Oil` from anywhere
		--   * `keys = <c-w><c-o>`     -- float open from anywhere
		init = function()
			vim.g.loaded_netrw       = 1
			vim.g.loaded_netrwPlugin = 1

			-- Future directory buffers (`:e somedir/`, session restore, etc.)
			-- get caught by this BufAdd autocmd, which loads oil on demand.
			local group = vim.api.nvim_create_augroup("noethervim_oil_lazy", { clear = true })
			vim.api.nvim_create_autocmd("BufAdd", {
				group   = group,
				nested  = true,
				callback = function(args)
					local name = vim.api.nvim_buf_get_name(args.buf)
					if name ~= "" and vim.fn.isdirectory(name) == 1 then
						require("oil")  -- triggers lazy load + oil.setup
						pcall(vim.api.nvim_del_augroup_by_id, group)
					end
				end,
			})

			-- `nvim .` case: argv buffer is created during argv processing,
			-- BEFORE init.lua sources, so the BufAdd autocmd above never sees
			-- it. Check the current buffer ourselves -- if it's a directory,
			-- load oil now (during lazy.setup, before BufRead fires) so oil
			-- can rename the buffer to `oil:///path/` in time for its
			-- BufReadCmd to take over.
			local cur = vim.api.nvim_buf_get_name(0)
			if cur ~= "" and vim.fn.isdirectory(cur) == 1 then
				require("oil")
				pcall(vim.api.nvim_del_augroup_by_id, group)
			end
		end,
		keys = { {'<c-w><c-o>', function() require('oil').open_float() end, desc = "Oil Mode"}, },
		cmd  = { "Oil" },
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			default_file_explorer = true,
			columns = default_columns,
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
			watch_for_changes = false,
			keymaps = {
				["g?"] = { "actions.show_help", mode = "n" },
				["<CR>"] = "actions.select",
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
				["gd"] = {
					desc = "Toggle file detail view (adds permissions)",
					callback = function()
						detail = not detail
						require("oil").set_columns(detail and detail_columns or default_columns)
					end,
				},
				["gx"] = "actions.open_external",
				["gX"] = {
					desc = "open dir in system file browser",
					callback = function()
						local dir = require("oil").get_current_dir()
						if not dir then return end
						if vim.fn.has("macunix") == 1 then
							vim.fn.jobstart({ "open", dir }, { detach = true })
						elseif vim.fn.has("win32") == 1 then
							vim.fn.jobstart({ "explorer", dir }, { detach = true })
						else
							vim.fn.jobstart({ "xdg-open", dir }, { detach = true })
						end
					end,
				},
				["gf"] = {
					desc = "fuzzy find in current dir",
					callback = function()
						local dir = require("oil").get_current_dir()
						if not dir then return end
						local title
						local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel")[1]
						if git_root and not git_root:match("^fatal") then
							title = dir:sub(#git_root + 2) -- strip root + trailing /
							if title == "" then title = "." end
						else
							title = vim.fn.fnamemodify(dir, ":~")
						end
						require("snacks").picker.files({
							cwd = dir,
							title = title,
							hidden = require("oil.config").view_options.show_hidden,
							ignored = true,
						})
					end,
				},
				["gG"] = {
					desc = "live grep in current dir",
					callback = function()
						local dir = require("oil").get_current_dir()
						if not dir then return end
						local title
						local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel")[1]
						if git_root and not git_root:match("^fatal") then
							title = dir:sub(#git_root + 2) -- strip root + trailing /
							if title == "" then title = "." end
						else
							title = vim.fn.fnamemodify(dir, ":~")
						end
						require("snacks").picker.grep({
							cwd = dir,
							title = title,
							hidden = require("oil.config").view_options.show_hidden,
							ignored = true,
						})
					end,
				},
				["gV"] = {
					desc = "pick destination and split",
					callback = function()
						local oil = require("oil")
						local dir = oil.get_current_dir()
						if not dir then return end
						local is_float = vim.api.nvim_win_get_config(0).relative ~= ""
						if is_float then oil.close() end
						vim.schedule(function()
							require("snacks").picker({
								title = "Split Oil: Pick Destination",
								cwd = dir,
								finder = "proc",
								cmd = "fd",
								args = { "--type", "d", "--hidden", "--exclude", ".git" },
								format = "file",
								show_empty = true,
								transform = function(item)
									item.cwd = dir
									item.file = item.text
									item.dir = true
								end,
								confirm = function(picker)
									local item = picker:current()
									if not item then return end
									picker:close()
									local dest = item.file
									local is_abs = dest:sub(1, 1) == "/" or dest:match("^%a:[/\\]") ~= nil
									if not is_abs then dest = vim.fs.joinpath(dir, dest) end
									vim.schedule(function()
										local total_w = math.floor(vim.o.columns * 0.8)
										local total_h = math.floor(vim.o.lines * 0.7)
										local row     = math.floor((vim.o.lines   - total_h) / 2)
										local col0    = math.floor((vim.o.columns - total_w) / 2)
										local half_w  = math.floor((total_w - 1) / 2)
										-- Left pane: source dir
										local lbuf = vim.api.nvim_create_buf(false, true)
										local lwin = vim.api.nvim_open_win(lbuf, true, {
											relative = "editor", style = "minimal", border = "rounded",
											row = row, col = col0, width = half_w, height = total_h,
										})
										oil.open(dir)
										-- Right pane: destination dir
										local rbuf = vim.api.nvim_create_buf(false, true)
										local rwin = vim.api.nvim_open_win(rbuf, true, {
											relative = "editor", style = "minimal", border = "rounded",
											row = row, col = col0 + half_w + 1, width = half_w, height = total_h,
										})
										oil.open(dest)
										-- q closes both floats
										local function close_both()
											for _, w in ipairs({ lwin, rwin }) do
												if vim.api.nvim_win_is_valid(w) then
													vim.api.nvim_win_close(w, true)
												end
											end
										end
										for _, w in ipairs({ lwin, rwin }) do
											local buf = vim.api.nvim_win_get_buf(w)
											vim.keymap.set("n", "q", close_both, { buf = buf })
										end
									end)
								end,
							})
						end)
					end,
				},
				["g."] = { "actions.toggle_hidden", mode = "n" },
				["g\\"] = { "actions.toggle_trash", mode = "n" },
				["yp"] = { desc = "yank full path",           mode = "n", callback = yank_entry("",  nil)  },
				["yd"] = { desc = "yank parent dir",          mode = "n", callback = yank_entry("",  ":h") },
				["yn"] = { desc = "yank name",                mode = "n", callback = yank_entry("",  ":t") },
				["Yp"] = { desc = "yank full path (+clip)",   mode = "n", callback = yank_entry("+", nil)  },
				["Yd"] = { desc = "yank parent dir (+clip)",  mode = "n", callback = yank_entry("+", ":h") },
				["Yn"] = { desc = "yank name (+clip)",        mode = "n", callback = yank_entry("+", ":t") },
				["Y"]  = {
					desc = "copy file(s) to system clipboard",
					mode = { "n", "x" },
					callback = function()
						local is_visual = vim.fn.mode():match("^[vV\22]")
						if is_visual and vim.fn.has("macunix") == 1 then
							mac_copy_visual_selection()
						else
							require("oil.clipboard").copy_to_system_clipboard()
						end
					end,
				},
				["gz"] = {
					desc = "zip entry (normal) or selection (visual)",
					mode = { "n", "x" },
					callback = zip_entries,
				},
				["gZ"] = {
					desc = "unzip .zip entry (normal) or selection (visual)",
					mode = { "n", "x" },
					callback = unzip_entries,
				},
				["gS"] = {
					desc = "Create symlink in current directory",
					callback = function()
						local dir = require("oil").get_current_dir()
						if not dir then return end
						local target = vim.fn.input("Symlink target: ")
						if target == "" then return end
						local link_name = vim.fn.input("Symlink name: ")
						if link_name == "" then return end
						vim.fn.system({ "ln", "-s", target, dir .. link_name })
						require("oil.actions").refresh.callback()
					end,
				},
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
		},
		config = function(_, opts)
			require("oil").setup(opts)
			-- Async metadata decoration: paint size/mtime as virt_text after
			-- every oil render. `User OilEnter` fires once the buffer is ready
			-- (see oil.nvim:view.lua:572). Wrapped in vim.schedule so the
			-- decoration walk runs one tick later -- the buffer is already
			-- visible by then, so stats trickle in without blocking.
			vim.api.nvim_create_autocmd("User", {
				pattern = "OilEnter",
				callback = function(args)
					vim.schedule(function()
						decorate_oil_buffer(args.data.buf or 0)
					end)
				end,
			})
		end,
	},
}
