-- Winbar components (Dropbar breadcrumbs, diff-side labels).

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

M.Dropbar = {
  condition = function(self)
    -- check if there is any value here
    return vim.tbl_get(require("dropbar.utils").bar.get_current() or {}, "buf")
  end,
  static = { dropbar_on_click_string = "v:lua.dropbar.callbacks.buf%s.win%s.fn%s" },
  init = function(self)
    self.data = require("dropbar.utils").bar.get_current()
    local components = self.data.components
    local children = {}
    for i, c in ipairs(components) do
      local child = {
        {
          hl = c.icon_hl,
          provider = c.icon:gsub("%%", "%%%%"),
        },
        {
          hl = c.name_hl,
          provider = c.name:gsub("%%", "%%%%"),
        },
        on_click = {
          callback = self.dropbar_on_click_string:format(self.data.buf, self.data.win, i),
          name = "heirline_dropbar",
        },
      }
      if i < #components then
        local sep = self.data.separator
        table.insert(child, {
          provider = sep.icon,
          hl = sep.icon_hl,
          on_click = {
            callback = self.dropbar_on_click_string:format(self.data.buf, self.data.win, i + 1),
          },
        })
      end
      table.insert(children, child)
    end
    self.child = self:new(children, 1)
  end,
  provider = function(self)
    return self.child:eval()
  end,
}

return M
