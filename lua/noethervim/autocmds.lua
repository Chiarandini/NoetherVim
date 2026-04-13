-- NoetherVim core autocommands

-- ──────────────────────────────────────────────────────────────
--  q-to-quit for non-editing windows
--  Philosophy: any window you can't usefully edit should close
--  with a single `q` keypress (no macro-recording concern there).
-- ──────────────────────────────────────────────────────────────

local q_close_ft = {
  "help", "man", "lspinfo", "checkhealth",  -- qf handled by ftplugin/qf.lua
  "notify", "oil", "fugitiveblame",
  "startuptime", "lazy", "mason",
  "spectre_panel", "crunner", "dap-float",
  "DressingInput", "sagarename",
  "bib", "cmp_menu", "query",
  "typr", "snacks_notif", "snacks_terminal",
}

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("noethervim_q_close", { clear = true }),
  pattern = q_close_ft,
  callback = function(ev)
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buf = ev.buf, silent = true, nowait = true })
  end,
})

-- Oil floating-window navigation:
--   <c-h>/<c-l>  → jump to the other Oil float (dual-pane mode)
--   q            → close BOTH Oil floats (overrides the generic q_close above)
-- Only activates when Oil opens inside a floating window.
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
    vim.keymap.set("n", "q", function()
      local other = other_oil_float()
      if other then pcall(vim.api.nvim_win_close, other, true) end
      pcall(vim.api.nvim_win_close, win, true)
    end, vim.tbl_extend("force", opts, { desc = "close all Oil floats" }))
  end,
})

-- sagarename also needs <Esc> to close
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("noethervim_esc_close", { clear = true }),
  pattern = "sagarename",
  callback = function(ev)
    vim.keymap.set("i", "<esc>", "<esc>ZQ", { buf = ev.buf, silent = true })
  end,
})

-- ──────────────────────────────────────────────────────────────
--  Auto-reload buffers when focus returns
-- ──────────────────────────────────────────────────────────────

vim.api.nvim_create_autocmd(
  { "FocusGained", "BufEnter", "FileChangedShell" },
  {
    group   = vim.api.nvim_create_augroup("noethervim_autoread", { clear = true }),
    pattern = "*",
    callback = function() vim.cmd("checktime") end,
  }
)

-- ──────────────────────────────────────────────────────────────
--  Terminal window tweaks
-- ──────────────────────────────────────────────────────────────

vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("noethervim_term", { clear = true }),
  callback = function()
    local o = vim.opt_local
    o.number         = false
    o.relativenumber = false
    o.scrolloff      = 0
  end,
})

-- <Esc><Esc> exits terminal mode (one Esc is sent to the program)
vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>")

-- Open a small terminal at the bottom of the screen
vim.keymap.set("n", "<c-w>t", function()
  vim.cmd.new()
  vim.cmd.wincmd("J")
  vim.api.nvim_win_set_height(0, 12)
  vim.wo.winfixheight = true
  vim.cmd.term()
end, { desc = "open terminal" })

-- ──────────────────────────────────────────────────────────────
--  Heirline component update events
-- ──────────────────────────────────────────────────────────────

local hl_group = vim.api.nvim_create_augroup("noethervim_heirline", { clear = true })

local function hl_event(pattern, callback)
  vim.api.nvim_create_autocmd("User", { group = hl_group, pattern = pattern, callback = callback })
end

hl_event("HeirlineGitToggle",    function() vim.g.heirline_git_show     = not vim.g.heirline_git_show;     vim.cmd.redrawstatus() end)
hl_event("HeirlinePdfSizeToggle",function() vim.g.heirline_pdfsize_show = not vim.g.heirline_pdfsize_show; vim.cmd.redrawstatus() end)
hl_event("HeirlineLspToggle",    function() vim.g.heirline_lsp_show     = not vim.g.heirline_lsp_show;     vim.cmd.redrawstatus() end)
hl_event("HeirlineDirectoryOn",  function() vim.g.heirline_directory_show           = true;  vim.cmd.redrawstatus() end)
hl_event("HeirlineDirectoryOff", function() vim.g.heirline_directory_show           = false; vim.cmd.redrawstatus() end)
hl_event("HeirlineRelativeDirOn",function() vim.g.heirline_proj_relative_dir_show   = true;  vim.cmd.redrawstatus() end)
hl_event("HeirlineRelativeDirOff",function() vim.g.heirline_proj_relative_dir_show  = false; vim.cmd.redrawstatus() end)
hl_event("HeirlinePDFModeOn",    function()
  vim.g.heirline_git_show       = false
  vim.g.heirline_lsp_show       = false
  vim.g.heirline_directory_show = false
  vim.g.heirline_pdfsize_show   = true
  vim.cmd.redrawstatus()
end)

-- ──────────────────────────────────────────────────────────────
--  Spelling for prose filetypes (enable spell + <C-l> quick-fix)
-- ──────────────────────────────────────────────────────────────

vim.api.nvim_create_autocmd("FileType", {
  group    = vim.api.nvim_create_augroup("noethervim_prose", { clear = true }),
  pattern  = { "tex", "markdown", "norg", "text", "gitcommit" },
  callback = function(ev)
    vim.opt_local.spell = true
    vim.keymap.set("i", "<c-l>", "<c-g>u<Esc>[s1z=`]a<c-g>u",
      { buffer = ev.buf, silent = true, desc = "fix spelling" })
  end,
})

