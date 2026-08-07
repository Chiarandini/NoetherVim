-- NoetherVim core autocommands

-- ──────────────────────────────────────────────────────────────
--  q-to-quit for non-editing windows
--  Philosophy: any window you can't usefully edit should close
--  with a single `q` keypress (no macro-recording concern there).
-- ──────────────────────────────────────────────────────────────
-- The list lives in noethervim.util.filetypes and already includes
-- whatever `q_close_filetypes` in lua/user/config.lua adds to it. To drop
-- one of the distro's entries instead, clear this augroup and recreate the
-- autocmd -- see templates/user/autocmds.example.lua.

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("noethervim_q_close", { clear = true }),
  pattern = require("noethervim.util.filetypes").q_close,
  callback = function(ev)
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buf = ev.buf, silent = true, nowait = true })
  end,
})

-- Oil floating-window navigation:
--   <c-h>/<c-l>  → jump to the other Oil float (dual-pane mode)
-- Only activates when Oil opens inside a floating window. Oil buffers are
-- editable, so there is no q-to-close (oil's own close keymaps apply).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("noethervim_oil_float", { clear = true }),
  pattern = "oil",
  callback = function(ev)
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_config(win).relative == "" then return end

    local function other_oil_float()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if w ~= win and vim.api.nvim_win_get_config(w).relative ~= "" then
          local buf = vim.api.nvim_win_get_buf(w)
          if vim.bo[buf].filetype == "oil" then return w end
        end
      end
    end

    local opts = { buffer = ev.buf, nowait = true, silent = true }
    vim.keymap.set("n", "<c-h>", function()
      local other = other_oil_float()
      if other then vim.api.nvim_set_current_win(other) end
    end, vim.tbl_extend("force", opts, { desc = "go to other Oil pane" }))
    vim.keymap.set("n", "<c-l>", function()
      local other = other_oil_float()
      if other then vim.api.nvim_set_current_win(other) end
    end, vim.tbl_extend("force", opts, { desc = "go to other Oil pane" }))
  end,
})

-- ──────────────────────────────────────────────────────────────
--  Auto-disable diff mode when a diff buffer is no longer visible.
--  Closing one half of a `:diffthis` pair (or `:Gdiff`, gitsigns'
--  diffthis, `:DiffOrig`, etc.) leaves the surviving window with
--  &diff still set, which silently changes wrap/foldmethod/cursor-bind
--  for the rest of the session. We listen on BufHidden / BufWipeout
--  (NOT BufWinLeave) so simply switching tabs or windows while the
--  diff buffer is still on screen doesn't tear the diff down.
--  BufHidden fires only when the buffer has no remaining windows
--  showing it, which is exactly when the leftover &diff is unwanted.
-- ──────────────────────────────────────────────────────────────

-- Track which buffers are participating in a diff so we can detect when
-- a hidden one was the trigger. `diff` is a window-local option (per
-- `:h 'diff'`), so we can't read it off the buffer at BufHidden time -
-- the window has already gone. We mark `b:noethervim_was_diff = true`
-- whenever any window shows that buffer in diff mode (OptionSet on
-- `diff` fires for the affected window) and consume the flag below.
vim.api.nvim_create_autocmd("OptionSet", {
  group   = vim.api.nvim_create_augroup("noethervim_diff_track", { clear = true }),
  pattern = "diff",
  callback = function()
    if vim.v.option_new == "1" or vim.v.option_new == true then
      vim.b.noethervim_was_diff = true
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufHidden", "BufWipeout" }, {
  group = vim.api.nvim_create_augroup("noethervim_diff_cleanup", { clear = true }),
  callback = function(ev)
    -- Only act for buffers we've seen participating in a diff. Cheaper
    -- and avoids running diffoff on every random hide event.
    if not vim.b[ev.buf].noethervim_was_diff then return end
    vim.b[ev.buf].noethervim_was_diff = nil
    vim.schedule(function()
      for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
          if vim.api.nvim_win_is_valid(win) and vim.wo[win].diff then
            pcall(function()
              vim.api.nvim_win_call(win, function() vim.cmd("diffoff") end)
            end)
          end
        end
      end
    end)
  end,
})

-- ──────────────────────────────────────────────────────────────
--  Auto-reload buffers when focus returns
-- ──────────────────────────────────────────────────────────────
-- The trigger set fires rapidly during workflows that thrash focus or
-- buffer enters -- e.g. a VimTeX continuous compile that bounces between
-- the tex source, log/aux scratch buffers, and the PDF viewer. Each
-- bare `:checktime` walks every loaded buffer, and the resulting UI churn
-- (tab modified flags, statusline redraws) shows up as flicker. Coalesce
-- bursts into a single trailing-edge call so checktime runs at most once
-- per ~100ms. Legitimate reloads still feel instant; the cost is a tiny
-- delay before an externally-edited file pops back in.

do
  local pending = false
  vim.api.nvim_create_autocmd(
    { "FocusGained", "BufEnter", "InsertEnter", "InsertLeave", "FileChangedShell" },
    {
      group   = vim.api.nvim_create_augroup("noethervim_autoread", { clear = true }),
      pattern = "*",
      callback = function()
        if pending then return end
        pending = true
        vim.defer_fn(function()
          pending = false
          pcall(vim.cmd, "checktime")
        end, 100)
      end,
    }
  )
end

-- ──────────────────────────────────────────────────────────────
--  Out-of-sync detection
--  When a file changes on disk AND the buffer has unsaved edits,
--  autoread can't silently reload (would clash with user changes).
--  Flag the buffer so UI (statusline) can surface the conflict.
--  Cleared on next successful write or read.
-- ──────────────────────────────────────────────────────────────

-- Deleting the file behind a buffer leaves the buffer intact, still holding
-- the path and the only remaining copy of the contents, with nothing on
-- screen to say so. `checktime` above reports it as `v:fcs_reason ==
-- "deleted"`, so the detection is already paid for; latch it onto the buffer
-- for the statusline to read. Cleared by the next write, which recreates
-- the file, or by a re-read.

vim.api.nvim_create_autocmd("FileChangedShell", {
  group = vim.api.nvim_create_augroup("noethervim_out_of_sync_set", { clear = true }),
  callback = function(ev)
    if vim.v.fcs_reason == "deleted" then
      vim.b[ev.buf].noethervim_file_missing = true
      vim.cmd.redrawstatus()
    elseif vim.bo[ev.buf].modified then
      vim.b[ev.buf].noethervim_out_of_sync = true
      vim.cmd.redrawstatus()
    end
  end,
})

-- The other direction: a buffer with a name and nothing at that path yet,
-- from `:e newfile.txt`. Neovim says `[New]` once, on the cmdline, and then
-- the buffer is indistinguishable from one backed by a file. Latch it so the
-- statusline can keep saying so for as long as it is true. BufNewFile fires
-- exactly when a file is opened for editing and does not exist.
vim.api.nvim_create_autocmd("BufNewFile", {
  group = vim.api.nvim_create_augroup("noethervim_new_file_set", { clear = true }),
  callback = function(ev)
    vim.b[ev.buf].noethervim_new_file = true
  end,
})

vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
  group = vim.api.nvim_create_augroup("noethervim_out_of_sync_clear", { clear = true }),
  callback = function(ev)
    vim.b[ev.buf].noethervim_out_of_sync = nil
    vim.b[ev.buf].noethervim_file_missing = nil
    -- A write creates the file, so the buffer is backed from here on.
    vim.b[ev.buf].noethervim_new_file = nil
    vim.cmd.redrawstatus()
  end,
})

-- ──────────────────────────────────────────────────────────────
--  Terminal window tweaks
-- ──────────────────────────────────────────────────────────────

local term_group = vim.api.nvim_create_augroup("noethervim_term", { clear = true })

vim.api.nvim_create_autocmd("TermOpen", {
  group = term_group,
  callback = function(ev)
    -- Terminals can be created in a buffer that is not on screen yet
    -- (betterTerm, Snacks.terminal), so set them on the windows actually showing
    -- this buffer instead of whichever window happens to be current.
    for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
      vim.wo[win].number         = false
      vim.wo[win].relativenumber = false
      vim.wo[win].scrolloff      = 0
    end
    if vim.api.nvim_get_current_buf() == ev.buf then
      vim.cmd.startinsert()
    end
  end,
})

-- 'timeoutlen' is global and defaults to a full second, so the <Esc><Esc>
-- exit mapping would hold a single <Esc> back that long before passing it
-- to whatever is running in the terminal. Shorten it for the duration of
-- terminal mode; <Esc><Esc> is the only multi-key mapping there.
local saved_timeoutlen

vim.api.nvim_create_autocmd("TermEnter", {
  group = term_group,
  callback = function()
    saved_timeoutlen = saved_timeoutlen or vim.o.timeoutlen
    vim.o.timeoutlen = 150
  end,
})

vim.api.nvim_create_autocmd("TermLeave", {
  group = term_group,
  callback = function()
    if saved_timeoutlen then
      vim.o.timeoutlen = saved_timeoutlen
      saved_timeoutlen = nil
    end
  end,
})

-- ──────────────────────────────────────────────────────────────
--  Heirline component update events
-- ──────────────────────────────────────────────────────────────

local heirline_group = vim.api.nvim_create_augroup("noethervim_heirline", { clear = true })

local function heirline_event(pattern, callback)
  vim.api.nvim_create_autocmd("User", { group = heirline_group, pattern = pattern, callback = callback })
end

heirline_event("HeirlineGitToggle",    function() vim.g.heirline_git_show     = not vim.g.heirline_git_show;     vim.cmd.redrawstatus() end)
heirline_event("HeirlinePdfSizeToggle",function() vim.g.heirline_pdfsize_show = not vim.g.heirline_pdfsize_show; vim.cmd.redrawstatus() end)
heirline_event("HeirlineLspToggle",    function() vim.g.heirline_lsp_show     = not vim.g.heirline_lsp_show;     vim.cmd.redrawstatus() end)
heirline_event("HeirlineProfileToggle", function() vim.g.heirline_filetype_profile_show = not vim.g.heirline_filetype_profile_show; vim.cmd.redrawstatus() end)
heirline_event("HeirlineDirectoryOn",  function() vim.g.heirline_directory_show           = true;  vim.cmd.redrawstatus() end)
heirline_event("HeirlineDirectoryOff", function() vim.g.heirline_directory_show           = false; vim.cmd.redrawstatus() end)
heirline_event("HeirlineRelativeDirOn",function() vim.g.heirline_proj_relative_dir_show   = true;  vim.cmd.redrawstatus() end)
heirline_event("HeirlineRelativeDirOff",function() vim.g.heirline_proj_relative_dir_show  = false; vim.cmd.redrawstatus() end)
heirline_event("HeirlinePDFModeOn",    function()
  vim.g.heirline_git_show       = false
  vim.g.heirline_lsp_show       = false
  vim.g.heirline_directory_show = false
  vim.g.heirline_pdfsize_show   = true
  vim.cmd.redrawstatus()
end)

-- The directory components read the window's working directory, so they go
-- stale on any change to it. DirChanged covers all four sources: `:cd`,
-- `:tcd`, `:lcd`, and 'autochdir' (which reports scope "window").
vim.api.nvim_create_autocmd("DirChanged", {
  group    = heirline_group,
  pattern  = "*",
  callback = function() vim.cmd.redrawstatus() end,
})

-- ──────────────────────────────────────────────────────────────
--  Filetype profiles: writing and code
-- ──────────────────────────────────────────────────────────────
-- Writing buffers (tex, markdown, gitcommit, ...) get wrap + linebreak +
-- spell + conceallevel=2; list chars are hidden. Code buffers get
-- whitespace visibility (list chars), and -- when spell_in_code is
-- enabled in lua/user/config.lua -- spell turned on, scoped to comments
-- and strings via treesitter @spell captures. Structured-text (json,
-- yaml, toml) and special buffers (help, qf, oil, terminal, dashboard,
-- ...) are left alone -- their own ftplugins / buffer settings take over.
--
-- FileType autocmds fire AFTER ftplugin files, so these profiles win
-- over any same-named setting in ftplugin/*.lua. To extend the lists
-- (e.g. treat vimwiki as writing), set writing_filetypes /
-- non_code_filetypes in lua/user/config.lua -- see
-- :help noethervim-user-config-data.

local fts = require("noethervim.util.filetypes")
local writing_filetypes = fts.writing
local non_code_filetypes = fts.non_code

local ok_cfg, user_cfg = pcall(require, "user.config")
local spell_in_code = ok_cfg and type(user_cfg) == "table" and user_cfg.spell_in_code == true

-- ── Code vs. writing profiles ─────────────────────────────────────
-- Two FileType groups apply window-local "profile" options (wrap,
-- list, spell, etc.) to the windows showing the buffer.
--
-- WHY win_findbuf INSTEAD OF `vim.opt_local` / `setlocal`:
-- FileType fires for the buffer whose filetype just changed, but the
-- callback runs in the context of the *currently active* window --
-- which may be unrelated. Plugins that create hidden scratch buffers
-- and set their filetype (mason-registry, lazydev's lib-doc loader,
-- treesitter's auto_install probes, etc.) would otherwise apply our
-- profile options onto the dashboard / oil / whatever window happens
-- to be current at startup. Iterating `win_findbuf(ev.buf)` ensures
-- we only touch windows actually displaying the buffer; hidden
-- buffers harmlessly fall through.
--
-- We also re-apply on BufWinEnter so a buffer that gets shown later
-- (`:badd` then later `:b`, or a split into an existing buffer)
-- still inherits the profile.

-- Wrapped-line marker. It lives in the number column rather than in
-- 'showbreak' because 'showbreak' occupies a text cell, which pushes every
-- continuation line one column right of the text it continues. v:virtnum
-- is >0 on wrapped rows and <0 on virtual-text lines, which get a blank.
-- %C keeps the fold column working for anyone who turns 'foldcolumn' on.
--
-- A 'statuscolumn' is drawn whether or not 'number' is set, so the number
-- half has to check both options itself -- otherwise `]on` would appear to
-- do nothing in a writing buffer. With both off the column keeps only the
-- wrap marker, which is the point of it.
local wrap_statuscolumn =
  [[%C%s%=%{v:virtnum > 0 ? "↳" : (v:virtnum < 0 ? "" : ]]
  .. [[(!&number && !&relativenumber ? "" : ]]
  .. [[(&relativenumber && v:relnum > 0 ? v:relnum : (&number ? v:lnum : v:relnum))))} ]]

--- Keep the marker column in step with 'wrap'. It belongs to the option, not
--- to the filetype: a code buffer someone ran `[ow` in has exactly the same
--- ambiguity a wrapped prose buffer does, and writing buffers are only the
--- common case because they wrap by default.
---
--- Wrap off means no continuation rows to mark, so the column comes off
--- again and the native number column takes over. Only ever sets or clears
--- our own expression -- a 'statuscolumn' from `lua/user/options.lua` is
--- left alone, which matters because the profiles run on every
--- FileType/BufWinEnter, long after user config has loaded.
local function set_wrap_marker(win)
  local current = vim.wo[win].statuscolumn
  if vim.wo[win].wrap then
    if current == "" then vim.wo[win].statuscolumn = wrap_statuscolumn end
  elseif current == wrap_statuscolumn then
    vim.wo[win].statuscolumn = ""
  end
end

local function apply_writing_profile(buf)
  -- Buffer-local: formatoptions, the keymap.
  -- Guarded: this runs on BufWinEnter as well as FileType, so an
  -- unconditional append would add `t` again on every window switch.
  if not vim.bo[buf].formatoptions:find("t", 1, true) then
    vim.bo[buf].formatoptions = vim.bo[buf].formatoptions .. "t"
  end
  if not vim.b[buf].noethervim_writing_keymap then
    vim.keymap.set("i", "<c-l>", "<c-g>u<Esc>[s1z=`]a<c-g>u",
      { buffer = buf, silent = true, desc = "fix spelling" })
    vim.b[buf].noethervim_writing_keymap = true
  end
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win].wrap         = true
    vim.wo[win].linebreak    = true
    vim.wo[win].list         = false
    vim.wo[win].conceallevel = 2
    vim.wo[win].spell        = true
    set_wrap_marker(win)
  end
end

local function apply_code_profile(buf)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win].list = true
    -- The mirror of the writing profile's `wrap = true`. Without it a code
    -- buffer opened in a window a writing buffer left wrapped stays wrapped,
    -- and 'listchars' `extends` -- the marker saying a line runs off the
    -- right edge -- has nothing to mark, because nothing runs off any more.
    -- Vim remembers window-local options per (window, buffer), so this only
    -- shows up on a buffer that window has not displayed before, which is
    -- what makes it look intermittent.
    vim.wo[win].wrap = false
    -- Clears the marker column with it, since nothing wraps any more.
    set_wrap_marker(win)
    if spell_in_code then
      -- Treesitter @spell captures (shipped with most parsers)
      -- restrict spellcheck to comments and string nodes; identifiers
      -- stay clean. `spelloptions` is left untouched -- users who
      -- want CamelCase splitting can add
      --   vim.opt.spelloptions:append("camel")
      -- in lua/user/options.lua.
      vim.wo[win].spell = true
    end
  end
end

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group    = vim.api.nvim_create_augroup("noethervim_profiles", { clear = true }),
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if ft == "" or non_code_filetypes[ft] then return end
    if writing_filetypes[ft] then
      apply_writing_profile(ev.buf)
    else
      apply_code_profile(ev.buf)
    end
  end,
})

-- `[ow` / `]ow` flip 'wrap' between profile applications, so the marker has
-- to follow the option rather than only the filetype.
vim.api.nvim_create_autocmd("OptionSet", {
  group    = vim.api.nvim_create_augroup("noethervim_wrap_marker", { clear = true }),
  pattern  = "wrap",
  callback = function() set_wrap_marker(vim.api.nvim_get_current_win()) end,
})

-- Whether a window is the current one decides which statusline it gets, and
-- closing a float changes the answer for the window underneath without
-- necessarily marking its statusline dirty. The result is a window that
-- still wears the dimmed inactive bar until something unrelated forces a
-- redraw. Cheap to rule out: WinClosed fires rarely.
vim.api.nvim_create_autocmd("WinClosed", {
  group    = vim.api.nvim_create_augroup("noethervim_statusline_redraw", { clear = true }),
  callback = function() vim.schedule(function() pcall(vim.cmd, "redrawstatus!") end) end,
})

-- ──────────────────────────────────────────────────────────────
--  Restore last cursor position
-- ──────────────────────────────────────────────────────────────
-- In-house replacement for ethanholz/nvim-lastplace: that plugin's
-- BufRead handler registered a fresh buffer-local BufWinEnter autocmd
-- on every read with no dedup, so handlers piled up over a session
-- (and exploded quadratically whenever the quickfix buffer churned).
-- All we actually need is the classic '"-mark jump, scheduled so it
-- runs after filetype detection has settled.

local lastplace_ignore_buftype  = { quickfix = true, nofile = true, help = true }
local lastplace_ignore_filetype = { gitcommit = true, gitrebase = true, svn = true, hgcommit = true }

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("noethervim_lastplace", { clear = true }),
  callback = function(ev)
    local buf = ev.buf
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf)
          or lastplace_ignore_buftype[vim.bo[buf].buftype]
          or lastplace_ignore_filetype[vim.bo[buf].filetype] then
        return
      end
      local mark = vim.api.nvim_buf_get_mark(buf, '"')
      if mark[1] <= 0 or mark[1] > vim.api.nvim_buf_line_count(buf) then return end
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        -- Respect an explicit position (`nvim +42 file`, a quickfix
        -- jump, ...): only restore when the cursor still sits on line 1.
        if vim.api.nvim_win_get_cursor(win)[1] == 1 then
          pcall(vim.api.nvim_win_set_cursor, win, mark)
          -- open folds at the restored position and center the view
          vim.api.nvim_win_call(win, function() vim.cmd("normal! zvzz") end)
        end
      end
    end)
  end,
})
