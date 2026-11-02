--- Capabilities detected at runtime and the switches NoetherVim reads.

local h = vim.health

--- Parsers that core, the enabled bundles or an open buffer would have had
--- installed, and that are not there.
---@return string[]
local function missing_parsers()
  local ts = require("lazy.core.config").plugins["nvim-treesitter"]
  if not ts then return {} end
  local want = {}
  for _, lang in ipairs(require("lazy.core.plugin").values(ts, "opts", false).ensure_installed or {}) do
    want[lang] = true
  end
  local registry = ts._.loaded and package.loaded["nvim-treesitter.parsers"]
  for _, buf in ipairs(registry and vim.api.nvim_list_bufs() or {}) do
    local lang = vim.api.nvim_buf_is_loaded(buf) and vim.treesitter.language.get_lang(vim.bo[buf].filetype)
    if lang and registry[lang] then want[lang] = true end
  end
  local missing = {}
  for lang in pairs(want) do
    local ok, added = pcall(vim.treesitter.language.add, lang)
    if not (ok and added) then table.insert(missing, lang) end
  end
  table.sort(missing)
  return missing
end

-- ── Feature flags ────────────────────────────────────────────────────
local function features()
  -- Runtime-detected capabilities and distribution opt-out flags, so users
  -- can confirm what's active in their session. Add new entries here as
  -- flags are introduced; remove entries when the flag is gone.
  h.start("Feature flags")
  if vim.api.nvim__redraw then
    h.ok("nvim__redraw API present (statusline busy-spinner updates smoothly)")
  else
    h.warn("nvim__redraw missing: the busy-spinner falls back to redrawstatus")
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
    h.info("Auto-install: OFF (vim.g.noethervim_auto_install = false)\n"
      .. "The Mason tools and treesitter parsers that core and enabled bundles name\n"
      .. "are not fetched; install them yourself, or with :Mason and :TSInstall.")
    local missing = missing_parsers()
    if #missing > 0 then
      h.warn("Treesitter parsers not installed: " .. table.concat(missing, ", "),
        { ":TSInstall " .. table.concat(missing, " ") })
    end
  else
    h.ok("Auto-install: ON (enabled bundles fetch their Mason tools; parsers install as files need them)")
  end
end

local M = {}

function M.check()
  features()
end

return M
