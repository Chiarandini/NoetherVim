-- NoetherVim plugin: Oil file explorer
-- Open with: <C-w><C-o> (float) or :Oil (replace buffer)
--
-- Custom keymaps (in addition to Oil defaults -- press g? inside Oil):
--   <S-CR>      Apply pending edits. Leaves Oil only from normal mode and
--               only when nothing needed confirming; otherwise stays put
--   <C-p>       Preview the entry under the cursor, following the cursor
--   gd          Toggle detail view (adds permissions to default size + mtime)
--   gf          Fuzzy find in current directory
--   gG          Live grep in current directory
--   gV / g|     Second Oil pane beside this one; <C-h>/<C-l> switch, gV/q leave
--   gX          Open directory in system file browser
--   gS          Create symlink in current directory
--   gz          Zip entry under cursor (normal) or selected entries (visual)
--   gZ          Unzip .zip entry (normal) or selected .zip entries (visual)
--   g. Toggle hidden files
--   g\          Toggle trash
--   gm          Select mode: mark scattered entries, then act on them
--               together (<Space> toggle, y copy, d cut, D trash,
--               c rename by s/pat/rep/, <Esc> leave). Y, gz and gZ also act
--               on the selection. See
--               noethervim.util.oil_select
--   Y           Copy file(s) to the system clipboard. Normal yanks the
--               entry under the cursor; visual yanks every selected entry,
--               skipping "../" and unsaved lines.
--   yp / yd / yn   Yank full path / dir / filename to unnamed register
--   Yp / Yd / Yn   Same, but straight to the system clipboard (+)

-- Columns: only `icon` by default. Size/mtime metadata is rendered as
-- virt_text by the decorator below, NOT as real oil
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
-- Render size + mtime as eol virt_text on each oil row, async-statting
-- each visible entry after the buffer is on screen; extmarks paint in as
-- the stat callbacks resolve, so no render is blocked. `User OilEnter`
-- fires only on a buffer's first render, while every later render (the
-- watcher, a save, `g.`, `gs`) replaces all lines and invalidates the
-- marks, so `config` below also repaints on line changes.
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

-- Per-buffer pass counter: a pass whose stats resolve after a newer
-- render has started must not paint onto the new lines. No stat cache:
-- one would serve stale size/mtime after a file changes, and a full
-- uncached pass over 2000 entries measured 5ms.
local decorate_gen = {}

local function decorate_oil_buffer(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end
	local ok, oil = pcall(require, "oil")
	if not ok then return end
	local dir = oil.get_current_dir(bufnr)
	if not dir then return end

	vim.api.nvim_buf_clear_namespace(bufnr, meta_ns, 0, -1)
	local gen = (decorate_gen[bufnr] or 0) + 1
	decorate_gen[bufnr] = gen

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
				if decorate_gen[bufnr] ~= gen then return end
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

			uv.fs_stat(path, vim.schedule_wrap(function(err, stat)
				if not err then paint(stat) end
			end))
		end
	end
end

-- Title for the directory-scoped pickers `gf` and `gG` launch.
--
-- `action` names which one is running: both used to render a bare path, so
-- a files picker and a grep picker were indistinguishable once open. The
-- scope is the path relative to the enclosing git repo, the repo's own name
-- at its root (a bare "." said nothing), and a `~`-shortened absolute path
-- outside a repo. Long paths keep their tail, which is the part that
-- locates you.
--
-- Title rather than a footer: snacks re-renders titles on every cwd change
-- and every layout provides one, whereas a footer needs the input window to
-- carry a bottom border. `ivy` puts the title on the enclosing box and
-- leaves the input bare, so a footer would silently vanish for anyone who
-- switches layout -- and the `browse` picker already runs `ivy`.
local function picker_title(dir, action)
	local scope
	local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --show-toplevel")[1]
	if git_root and not git_root:match("^fatal") then
		scope = dir:sub(#git_root + 2) -- strip root + trailing /
		if scope == "" then scope = vim.fn.fnamemodify(git_root, ":t") end
	else
		scope = vim.fn.fnamemodify(dir, ":~")
	end
	scope = scope:gsub("(.)/$", "%1") -- oil dirs always end in "/"; "/" itself keeps it
	if #scope > 40 then scope = "…" .. scope:sub(-39) end
	return ("Oil %s (%s)"):format(action, scope)
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

-- Copy several entries (a visual range or a select-mode selection) to the
-- macOS system clipboard as proper
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

---@param targets noethervim.oil_select.Target[]
local function mac_copy_paths(targets)
	local paths = {}
	for _, t in ipairs(targets) do table.insert(paths, t.path) end

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

-- Collect entry basenames from the current oil buffer: the select-mode
-- selection, else every entry in the visual range, else the entry under the
-- cursor, skipping "../" and unsaved lines (see oil_select.targets).
-- Returns (dir, names).
local function collect_entries()
	local dir, targets = require("noethervim.util.oil_select").targets()
	return dir, vim.tbl_map(function(t) return t.name end, targets)
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
		--      file is sourced). Stays scoped to oil's spec: disable oil and
		--      netrw is back.
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

						-- oil.setup() hijacks the *current* buffer into an
						-- oil:// buffer, but the buffer that tripped us here
						-- (args.buf) is often NOT current yet: `:e .` from a
						-- non-reusable buffer (the dashboard, or any open file)
						-- creates a NEW directory buffer while the old one is
						-- still current, so setup's hijack checks the wrong
						-- buffer -- and oil's own BufAdd handler can't retro-fire
						-- for a buffer whose BufAdd is already in flight. That
						-- directory buffer would then reach its BufReadCmd still
						-- named `/path` (not `oil://`), match oil's BufReadCmd
						-- pattern nowhere, and sit blank *forever* -- the
						-- intermittent "`:e .` opens an empty buffer" bug. So we
						-- hijack args.buf ourselves (the same rename oil's own
						-- maybe_hijack_directory_buffer does) unless setup
						-- already renamed it. Its upcoming BufReadCmd then
						-- matches `oil://*` and renders as normal.
						if vim.api.nvim_buf_is_valid(args.buf)
							and not vim.api.nvim_buf_get_name(args.buf):find("://", 1, true)
						then
							pcall(function()
								local ocfg  = require("oil.config")
								local ofs   = require("oil.fs")
								local outil = require("oil.util")
								outil.rename_buffer(
									args.buf,
									outil.addslash(
										ocfg.adapter_to_scheme.files
											.. ofs.os_to_posix_path(vim.fn.fnamemodify(name, ":p"))
									)
								)
							end)
						end

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
				local oil = require("oil")
				pcall(vim.api.nvim_del_augroup_by_id, group)

				-- ── Paint Oil FIRST, before the post-VimEnter load wave ──────
				-- Oil's directory listing is rendered from an async libuv
				-- scandir callback. Just `require("oil")` here loads the *code*
				-- but the *render* is still an async callback -- and the moment
				-- VimEnter fires, lazy pulls in the whole VeryLazy/BufRead wave
				-- (treesitter, LSP, blink.cmp, gitsigns, which-key, ...). That
				-- ~50-plugin wave hogs the main thread for a few hundred ms, so
				-- Oil's scandir callback is serviced LAST and the listing only
				-- paints ~250-400ms after launch -- the long-standing "Oil
				-- isn't instant on `nvim .`" gripe.
				--
				-- So we open oil on the dir right here and pump the event loop
				-- (vim.wait) until its first render fires. The scan is serviced
				-- immediately, during startup, and the wave streams in behind
				-- an already-visible listing. Net: same total startup work,
				-- just reordered so the thing you're staring at comes first.
				-- Drops time-to-paint from ~300ms to ~80ms here.
				--
				-- pcall-guarded so a failure can never break startup; the
				-- BufReadCmd path still renders oil even if open() is skipped.
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
			watch_for_changes = true,
			keymaps = {
				["g?"] = { "actions.show_help", mode = "n" },
				["<CR>"] = "actions.select",
				-- The finishing variant of the plain key, the shape <S-CR>
				-- already has in the quickfix window and the browse picker.
				-- Here it finishes whichever level you are on: from insert
				-- it ends the edit, committing the name you just typed and
				-- dropping you into normal mode with the listing still up;
				-- from normal it ends the session, committing and leaving.
				--
				-- Splitting it that way is what makes the insert binding
				-- safe. Typing is when a stray <S-CR> is likeliest, and it
				-- is also when the confirmation is likeliest to be waived
				-- (`skip_confirm_for_simple_edits`, a lone rename), so an
				-- insert-mode press that closed outright would be an
				-- unaskable question answered by a twitch. Ending the
				-- session stays a deliberate second press.
				--
				-- Buffer-local, so it shadows smart-enter's *global* insert
				-- <S-CR> only inside oil, where that key has nothing to
				-- offer anyway: there is no oil rule, so it falls back to a
				-- plain newline, which is what <CR> already does here.
				--
				-- Leaving insert is not optional even on its own. `oil.save`
				-- locks every oil buffer (`modifiable = false`) before
				-- parsing, and the confirmation float wants normal-mode
				-- `y`/`n`. `stopinsert` inside an insert mapping only takes
				-- hold once the mapping returns, so the commit waits a tick.
				--
				-- Closing is `oil.close`, not `ZZ`. Oil does understand `ZZ`
				-- (it sniffs the key buffer and quits from inside the save
				-- callback, correctly sequenced), but what it runs is
				-- `:quit`, which disposes of the window. For `:Oil` and
				-- `nvim .` oil replaced a buffer in a window that was
				-- already there, so the window is not oil's to take.
				-- `oil.close` is what <C-c> here already means: put the
				-- window back to whatever it held before. Ending the session
				-- is left to `exit_if_last_buf`, which only bites when oil
				-- really is the sole buffer and there is nothing to go back
				-- to; a blank buffer is not what "leave" meant.
				["<S-CR>"] = {
					desc = "apply changes; from normal, also leave Oil",
					mode = { "n", "i" },
					callback = function()
						local oil = require("oil")
						-- Decided before `stopinsert`, which would otherwise
						-- make every press look like it came from normal.
						local leave = vim.fn.mode():sub(1, 1) ~= "i"

						local function commit()
							-- Oil stamps its confirmation buffer with this
							-- filetype and nothing else does (the <C-p>
							-- preview marks windows and buffers with vars
							-- instead), so this fires exactly when you were
							-- asked a question.
							local asked = false
							local probe = vim.api.nvim_create_autocmd("FileType", {
								pattern  = "oil_preview",
								once     = true,
								callback = function() asked = true end,
							})

							oil.save({}, function(err)
								pcall(vim.api.nvim_del_autocmd, probe)
								if err then
									-- Canceling the confirmation is an
									-- ordinary outcome; the oil buffer
									-- stays up, unsaved.
									if err ~= "Canceled" then
										vim.notify(err, vim.log.levels.ERROR)
									end
									return
								end
								-- A dialog changes what the press meant. You
								-- reached for "commit and go", were stopped
								-- and asked something, and answered it; going
								-- as well would be a second consequence
								-- arriving from a keystroke made before the
								-- question existed. Deletes always ask (oil
								-- never counts them as simple), and a deletion
								-- is precisely when you want the listing back
								-- to see the row gone. So leave only on a
								-- commit that passed unquestioned; otherwise
								-- the second press does it.
								if not leave or asked then return end
								-- One tick after the post-apply rerender, so
								-- the buffer is not deleted mid-render.
								vim.schedule(function()
									oil.close({ exit_if_last_buf = true })
								end)
							end)
						end

						if leave then
							commit()
						else
							vim.cmd("stopinsert")
							vim.schedule(commit)
						end
					end,
				},
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
						require("snacks").picker.files({
							cwd = dir,
							title = picker_title(dir, "Files"),
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
						require("snacks").picker.grep({
							cwd = dir,
							title = picker_title(dir, "Grep"),
							hidden = require("oil.config").view_options.show_hidden,
							ignored = true,
						})
					end,
				},
				-- Two keys for one action, deliberately. `gV` sits with the
				-- other `g`-prefixed Oil additions; `g|` echoes the `|` this
				-- distribution already uses for a vertical split, and says
				-- "second pane" where `V` only says "vertical". Both need
				-- shift, so neither is the cheaper one to reach for.
				["gV"] = {
					desc = "second pane beside this one (dual-pane)",
					callback = function() require("noethervim.util.oil_dual").open() end,
				},
				["g|"] = {
					desc = "second pane beside this one (dual-pane)",
					callback = function() require("noethervim.util.oil_dual").open() end,
				},
				-- `m` for mark. Off SearchLeader on purpose: the mode changes
				-- what `y` and `d` mean, and SearchLeader is side-effect free.
				["gm"] = {
					desc = "select mode: toggle entry (or visual range)",
					mode = { "n", "x" },
					callback = function() require("noethervim.util.oil_select").enter() end,
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
						local select = require("noethervim.util.oil_select")
						local several = select.is_active() or vim.fn.mode():match("^[vV\22]") ~= nil
						if several and vim.fn.has("macunix") == 1 then
							local _, targets = select.targets()
							mac_copy_paths(targets)
						elseif select.is_active() then
							-- Oil's Linux copy reads a visual range or the
							-- cursor; it has no way to take scattered entries.
							vim.notify("Oil: copying a selection to the clipboard is macOS-only",
								vim.log.levels.WARN)
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
			local group = vim.api.nvim_create_augroup("noethervim_oil_meta", { clear = true })

			-- Repaint size/mtime after every render. OilEnter covers the first
			-- one (oil.nvim:view.lua:572); a line watch covers the rest. One
			-- scheduled pass per tick, skipped while the user has pending edits
			-- or oil is mid-render, since both are followed by another change.
			local queued, attached = {}, {}
			local function queue_decorate(bufnr)
				if queued[bufnr] then return end
				queued[bufnr] = true
				vim.schedule(function()
					queued[bufnr] = nil
					if vim.api.nvim_buf_is_valid(bufnr)
						and not vim.bo[bufnr].modified
						and not vim.b[bufnr].oil_rendering
					then
						decorate_oil_buffer(bufnr)
					end
				end)
			end
			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "OilEnter",
				callback = function(args)
					local bufnr = args.data.buf
					queue_decorate(bufnr)
					if attached[bufnr] then return end
					attached[bufnr] = vim.api.nvim_buf_attach(bufnr, false, {
						on_lines = function(_, b) queue_decorate(b) end,
						on_detach = function(_, b) attached[b] = nil end,
					})
				end,
			})

			-- The watcher marks a hidden directory dirty and oil re-renders it
			-- on return. Pin the cursor to the entry it is on now, or an entry
			-- created above it while you were away shifts it onto a neighbor.
			vim.api.nvim_create_autocmd("BufEnter", {
				group = group,
				callback = function(args)
					if vim.bo[args.buf].filetype ~= "oil" or not vim.b[args.buf].oil_dirty then return end
					local entry = require("oil").get_cursor_entry()
					if entry then
						require("oil.view").set_last_cursor(vim.api.nvim_buf_get_name(args.buf), entry.name)
					end
				end,
			})
		end,
	},
}
