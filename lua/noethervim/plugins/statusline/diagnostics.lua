-- Diagnostics statusline component.

local ctx = require("noethervim.plugins.statusline.context")
local icons = require("noethervim.util.icons")
local conditions = require("heirline.conditions")

local M = {}

--- The four severity counters, in severity order. `with_icons` picks
--- between `E 3` and a bare `3`; the flexible parent below renders the
--- icon form and falls back to the bare one when the bar runs short.
---
--- Separators come from `ctx.joined_counters`, which is also what the git
--- counters use -- see the note there for the spacing this gets right.
local function severities(with_icons)
  local function counter(key, icon_key, colour)
    return {
      value = function(self) return self[key] or 0 end,
      text  = function(self, n)
        return with_icons and (self[icon_key] .. " " .. n) or tostring(n)
      end,
      hl    = function() return { fg = ctx.colors[colour] } end,
    }
  end

  local counters = ctx.joined_counters({
    counter("errors",   "error_icon", "diag_error"),
    counter("warnings", "warn_icon",  "diag_warn"),
    counter("info",     "info_icon",  "diag_info"),
    counter("hints",    "hint_icon",  "diag_hint"),
  })

  local block = { { provider = with_icons and (icons.diagnostics .. "(") or "(" } }
  for _, c in ipairs(counters) do block[#block + 1] = c end
  block[#block + 1] = { provider = ")" }
  return block
end

local diagWithIcons = severities(true)
local diagWithoutIcons = severities(false)

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
