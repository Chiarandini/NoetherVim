--- Capabilities detected at runtime and the switches NoetherVim reads.

local h = vim.health

-- ── Feature flags ────────────────────────────────────────────────────
local function features()
  -- Runtime-detected capabilities and distribution opt-out flags, so users
  -- can confirm what's active in their session. Add new entries here as
  -- flags are introduced; remove entries when the flag is gone.
  h.start("Feature flags")
  if vim.api.nvim__redraw then
    h.ok("nvim__redraw API present (statusline busy-spinner updates smoothly)")
  else
    h.warn("nvim__redraw missing -- busy-spinner falls back to redrawstatus")
  end
  local snacks = require("lazy.core.config").plugins["snacks.nvim"]
  local snacks_opts = snacks and require("lazy.core.plugin").values(snacks, "opts", false) or {}
  if (snacks_opts.dashboard or {}).enabled == false then
    h.info("Dashboard: off (dashboard.enabled = false in snacks.nvim's opts)")
  else
    h.ok("Dashboard: on")
  end
  if vim.g.noethervim_dev then
    h.info("Dev mode: ON (vim.g.noethervim_dev set)")
  end
  if vim.env.NOETHERVIM_NO_USER or vim.g.noethervim_no_user then
    h.info("User overrides: SUPPRESSED (NOETHERVIM_NO_USER or vim.g.noethervim_no_user set)")
  end
  if vim.g.noethervim_auto_install == false then
    h.info("Toolchain auto-install: OFF (vim.g.noethervim_auto_install = false)\n"
      .. "Formatters, linters and debug adapters named by enabled bundles are\n"
      .. "not fetched; install them yourself or with :Mason.")
  else
    h.ok("Toolchain auto-install: ON -- enabled bundles fetch their Mason tools")
  end
end

local M = {}

function M.check()
  features()
end

return M
