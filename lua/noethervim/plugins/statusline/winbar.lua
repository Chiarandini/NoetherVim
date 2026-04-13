-- Winbar components (Dropbar breadcrumbs).

local ctx = require("noethervim.plugins.statusline.context")
local conditions = require("heirline.conditions")
local utils = require("heirline.utils")

local M = {}

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
