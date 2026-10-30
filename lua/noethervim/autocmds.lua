-- NoetherVim core autocommands

-- ──────────────────────────────────────────────────────────────
--  q-to-quit for non-editing windows
--  Philosophy: any window you can't usefully edit should close
--  with a single `q` keypress (no macro-recording concern there).
-- ──────────────────────────────────────────────────────────────
-- The list lives in noethervim.util.filetypes, with `q_close` from
-- lua/user/config.lua already applied to it.

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("noethervim_q_close", { clear = true }),
  pattern = require("noethervim.util.filetypes").q_close,
  callback = function(ev)
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buf = ev.buf, silent = true, nowait = true })
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
--  Statusline redraw on window close
-- ──────────────────────────────────────────────────────────────
-- The filetype profiles live in profiles/apply.lua.

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
