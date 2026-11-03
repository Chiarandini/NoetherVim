--- lua/user/config.lua and the leaders.

local h = vim.health

-- ── Configuration ────────────────────────────────────────────────────
local function configuration()
  h.start("Configuration")

  local config_dir = vim.fn.stdpath("config")
  if vim.uv.fs_stat(config_dir) then
    h.ok("User config dir: " .. config_dir)
  else
    h.error("User config dir missing: " .. config_dir)
  end

  local user_plugins = config_dir .. "/lua/user/plugins"
  if vim.uv.fs_stat(user_plugins) then
    h.ok("User plugins dir present")
  else
    h.info("No user plugins dir (optional) -- add plugins to " .. user_plugins)
  end

  local config = require("noethervim.config")
  if config.user_off() then
    h.info("Clean room: the user layer is off (NOETHERVIM_NO_USER), so lua/user/config.lua is not read")
  else
    local errors, unknowns = config.validate()
    for _, err in ipairs(errors) do h.warn(err) end
    if #unknowns > 0 then
      h.warn("Unknown user.config keys: " .. table.concat(unknowns, ", "),
        { "Check the spelling; a key NoetherVim renamed or removed is listed in NEWS.md" })
    end
    if #errors == 0 and #unknowns == 0 then
      h.ok("user.config: schema valid")
    end
  end

  -- Colorscheme provenance. An interactive pick outlives the session that
  -- made it and takes priority over `colorscheme` in lua/user/config.lua, so
  -- "my colorscheme setting does nothing" has to be answerable from here.
  local cs = require("noethervim.theme")
  h.info("Colorscheme: " .. cs.status())
  if cs.missing then
    h.warn(("colorscheme %q is not installed"):format(cs.missing), { cs.missing_remedy() })
  end
  if cs.dropped then
    h.warn(("saved colorscheme pick %q is no longer installed"):format(cs.dropped),
      { "Re-enable the bundle that provided it, or pick again with SearchLeader+C" })
  end
  if cs.source == "persisted" then
    h.info("The saved pick wins over `colorscheme` in lua/user/config.lua. "
      .. "Set colorscheme_persistence = false to make the config file authoritative.")
  end
end

-- ── Search leader ────────────────────────────────────────────────────
local function search_leader()
  h.start("Search leader")
  local search_leader = require("noethervim.util").search_leader
  h.ok("mapsearchleader: " .. search_leader)
  if search_leader == "" then
    h.warn("mapsearchleader is empty -- search keymaps will collide with normal-mode keys")
  end
end

local M = {}

function M.check()
  configuration()
  search_leader()
end

return M
