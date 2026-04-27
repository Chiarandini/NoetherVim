-- NoetherVim statusline override registry.
-- Called from noethervim.setup() before plugins load, so the heirline
-- config function can read user preferences at runtime.

local M = {}
local _opts = {}
local _busy_overrides = {}

--- Configure statusline overrides. Called once during `noethervim.setup()`
--- when `opts.statusline` is non-nil; the recorded values are read at
--- statusline-render time by the heirline component functions.
---
---@param opts noethervim.StatuslineOpts
function M.configure(opts)
  _opts = opts or {}
end

--- Returns user color overrides.
function M.get_colors()
  return _opts.colors or {}
end

--- Returns extra right-side components.
function M.get_extra_right()
  return _opts.extra_right or {}
end

--- Register a function that can greedily take over the Busy statusline
--- component. Evaluated on every statusline render; the most recently
--- registered override that returns a non-nil spec wins (last-write-wins,
--- so user config naturally trumps bundles that load earlier).
---
--- fn() -> nil | { icon?, label?, hl?, on_click? }
---   icon     -- string shown before the label; defaults to the animated
---              braille spinner frame
---   label    -- short string shown after the icon (e.g. "ai")
---   hl       -- heirline highlight spec (e.g. { fg = "#c678dd", bold = true })
---   on_click -- function invoked on mouse click
---
--- The animated spinner ticks while something is driving vim.bo.busy > 0;
--- overrides wanting animation should increment busy on the relevant buf.
function M.register_busy_override(fn)
  table.insert(_busy_overrides, fn)
end

function M.get_busy_overrides()
  return _busy_overrides
end

return M
