-- Diagnostics statusline component.

local ctx = require("noethervim.plugins.statusline.context")
local icons = require("noethervim.util.icons")
local conditions = require("heirline.conditions")

local M = {}

local diagWithIcons = {
  {
    provider = icons.diagnostics .. "(",
  },
  { -- ERRORS
    provider = function(self)
      -- 0 is just another output, we can decide to print it or not!
      return self.errors > 0 and (self.error_icon .. " " .. self.errors)
    end,
    hl = function() return { fg = ctx.colors.diag_error } end,
  },
  {
    condition = function(self)
      -- something to the right of errors
      return self.errors > 0 and (self.warnings > 0 or self.info > 0 or self.hints > 0)
    end,
    provider = " ",
  },
  { -- WARNINGS
    provider = function(self)
      return self.warnings > 0 and (self.warn_icon .. " " .. self.warnings)
    end,
    hl = function() return { fg = ctx.colors.diag_warn } end,
  },
  {
    condition = function(self)
      return (self.errors > 0 or self.warnings > 0) and (self.info > 0 or self.hints > 0)
    end,
    provider = " ",
  },
  { -- INFO
    provider = function(self)
      return self.info > 0 and (self.info_icon .. " " .. self.info)
    end,
    hl = function() return { fg = ctx.colors.diag_info } end,
  },
  {
    condition = function(self)
      return (self.errors > 0 or self.warnings > 0 or self.info > 0) and self.hints > 0
    end,
    provider = " ",
  },
  { -- HINT
    provider = function(self)
      return self.hints > 0 and (self.hint_icon .. " " .. self.hints)
    end,
    hl = function() return { fg = ctx.colors.diag_hint } end,
  },
  {
    provider = ")",
  },
}

local diagWithoutIcons = {
  {
    provider = "(",
  },
  {
    provider = function(self)
      return self.errors > 0 and self.errors
    end,
    hl = function() return { fg = ctx.colors.diag_error } end,
  },
  {
    provider = function(self)
      return self.warnings > 0 and self.warnings
    end,
    hl = function() return { fg = ctx.colors.diag_warn } end,
  },
  {
    provider = function(self)
      return self.info > 0 and self.info
    end,
    hl = function() return { fg = ctx.colors.diag_info } end,
  },
  {
    provider = function(self)
      return self.hints > 0 and self.hints
    end,
    hl = function() return { fg = ctx.colors.diag_hint } end,
  },
  {
    provider = ")",
  },
}

M.Diagnostics = {

  condition = conditions.has_diagnostics,

  on_click = {
    callback = function()
      require("snacks").picker.diagnostics_buffer({ title = "Diagnostics (Buffer)" })
    end,
    name = "heirline_diagnostics",
  },

  static = {
    error_icon = icons.error,
    warn_icon = icons.warning,
    info_icon = icons.info,
    hint_icon = icons.bulb,
  },

  init = function(self)
    local diags = vim.diagnostic.get(0)
    self.errors, self.warnings, self.hints, self.info = 0, 0, 0, 0
    for _, d in ipairs(diags) do
      if d.severity == vim.diagnostic.severity.ERROR then self.errors = self.errors + 1
      elseif d.severity == vim.diagnostic.severity.WARN then self.warnings = self.warnings + 1
      elseif d.severity == vim.diagnostic.severity.HINT then self.hints = self.hints + 1
      elseif d.severity == vim.diagnostic.severity.INFO then self.info = self.info + 1
      end
    end
  end,

  update = { "DiagnosticChanged", "BufEnter", "WinResized", "InsertEnter", "InsertLeave" },

  hl = function() return { fg = ctx.colors.light_red } end,
  flexible = ctx.priority.mid,
  diagWithIcons,
  diagWithoutIcons,
}

return M
