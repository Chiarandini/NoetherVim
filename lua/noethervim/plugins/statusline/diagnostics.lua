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
      require("trouble").toggle({ mode = "diagnostics", filter = { buf = 0 } })
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
    self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
    self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
    self.hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
    self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
  end,

  update = { "DiagnosticChanged", "BufEnter", "WinResized", "InsertEnter", "InsertLeave" },

  hl = function() return { fg = ctx.colors.light_red } end,
  flexible = ctx.priority.mid,
  diagWithIcons,
  diagWithoutIcons,
}

return M
