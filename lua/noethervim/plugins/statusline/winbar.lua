-- Winbar components (diff-side labels).

local ctx = require("noethervim.plugins.statusline.context")
local conditions = require("heirline.conditions")
local utils = require("heirline.utils")

local M = {}

-- Label each side of a diff so it's obvious which window is which.
-- Active only when the window's `diff` flag is set, so the winbar row
-- collapses away in non-diff windows. The buftype/modified heuristics
-- cover the three common shapes:
--   * :DiffOrig scratch side  -> buftype=nofile         -> ON DISK
--   * :DiffOrig original side -> modified=true          -> MODIFIED
--   * two-file :diffthis      -> neither                -> DIFF
M.DiffLabel = {
  condition = function() return vim.wo.diff end,
  init = function(self)
    local name = vim.api.nvim_buf_get_name(0)
    local tail = vim.fn.fnamemodify(name, ":t")
    if tail == "" then tail = "[No Name]" end
    self.filename = tail

    if vim.bo.buftype == "nofile" then
      self.tag    = "ON DISK"
      self.tag_hl = { fg = ctx.colors.green, bold = true }
    elseif vim.bo.modified then
      self.tag    = "MODIFIED (in memory)"
      self.tag_hl = { fg = ctx.colors.light_orange, bold = true }
    else
      self.tag    = "DIFF"
      self.tag_hl = { fg = ctx.colors.text_gray, bold = true }
    end
  end,
  {
    provider = function(self) return "  " .. self.tag .. "   " end,
    hl       = function(self) return self.tag_hl end,
  },
  {
    provider = function(self) return self.filename .. "  " end,
    hl       = function() return { fg = ctx.colors.text_gray } end,
  },
}

return M
