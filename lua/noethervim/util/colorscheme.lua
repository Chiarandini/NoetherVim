-- NoetherVim colorscheme utilities.
-- Persistence: saves/restores the active colorscheme across sessions.
-- Tweaks: re-applies user highlight overrides when the colorscheme changes.
-- Provenance: records what put the active scheme on screen, so
-- `:checkhealth noethervim` can answer "why isn't my colorscheme applying".

-- vim.api.keyset.highlight is shipped in Neovim's runtime _meta directory,
-- but standalone lua-language-server --check cannot reach a user-specific
-- $VIMRUNTIME path through .luarc.json. IDE users with lazydev or
-- runtime-injected library paths see the real type; CI uses this disable.
---@diagnostic disable: undefined-doc-name

local M = {}
local _file = vim.fn.stdpath("data") .. "/noethervim_colorscheme"
local _tweaks = {} ---@type table<string, vim.api.keyset.highlight>

--- The scheme the distribution ships and pins. `util.palette` hand-tunes the
--- statusline against it and `highlights.lua` special-cases it twice, so it is
--- also the safe landing spot when a requested scheme cannot be loaded.
M.DEFAULT = "gruvbox"

--- What put the active colorscheme on screen.
---@type "config"|"persisted"|"default"|"fallback"|nil
M.source = nil

--- Scheme named in `lua/user/config.lua` that could not be loaded.
---@type string|nil
M.missing = nil

--- Previously persisted pick whose plugin is no longer installed. Kept on
--- disk rather than deleted: disabling the colorscheme bundle for one session
--- should not destroy the choice made in the last one.
---@type string|nil
M.dropped = nil

-- ── Persistence ─────────────────────────────────────────────────────────────

local function save(name)
  local f = io.open(_file, "w")
  if f then f:write(name); f:close() end
end

local function load()
  local f = io.open(_file, "r")
  if not f then return nil end
  local name = f:read("*l")
  f:close()
  return name ~= "" and name or nil
end

function M.setup_persistence()
  -- Restore immediately (setup() runs after VimEnter, so a deferred
  -- VimEnter autocmd would never fire).
  local saved = load()
  if saved then
    if pcall(vim.cmd.colorscheme, saved) then
      M.source = "persisted"
    else
      M.dropped = saved
    end
  end

  -- Arm saving only once setup has finished. Every ColorScheme event fired
  -- during startup is distro-driven (the configured scheme, or the fallback
  -- after a failed load); recording those would overwrite the user's pick
  -- with a scheme they never chose.
  vim.schedule(function()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("noethervim_colorscheme", { clear = true }),
      callback = function(args) save(args.match) end,
    })
  end)
end

-- ── Applying ────────────────────────────────────────────────────────────────

--- Apply `scheme`, reporting failure instead of swallowing it. A colorscheme
--- that is named but not installed otherwise leaves Neovim on its built-in
--- default with no signal at all, which reads as "my config file is ignored".
---@param scheme string
---@param source "config"|"default"
function M.apply(scheme, source)
  if pcall(vim.cmd.colorscheme, scheme) then
    M.source = source
    return
  end

  M.missing = scheme
  vim.notify(
    ("colorscheme %q is not installed. Enable the ui.colorscheme bundle, or "
      .. "add the plugin to lua/user/plugins/."):format(scheme),
    vim.log.levels.WARN)

  if scheme ~= M.DEFAULT and pcall(vim.cmd.colorscheme, M.DEFAULT) then
    M.source = "fallback"
  end
end

--- Human-readable account of the active scheme and what set it.
--- Reported by `:checkhealth noethervim`.
---@return string
function M.status()
  local from = ({
    config    = "colorscheme in lua/user/config.lua",
    persisted = "picked interactively; overrides lua/user/config.lua",
    default   = "distribution default",
    fallback  = "distribution default, after the requested scheme failed to load",
  })[M.source] or "not set by NoetherVim"
  return (vim.g.colors_name or "(Neovim built-in default)") .. " -- " .. from
end

--- Title for the colorscheme picker (SearchLeader+C). Without the
--- ui.colorscheme bundle the picker holds gruvbox plus Neovim's built-ins,
--- and this keymap is exactly where the intent to change themes is expressed,
--- so it is the right place to say where the rest live.
---@return string
function M.picker_title()
  local ok, lazy_cfg = pcall(require, "lazy.core.config")
  if ok and lazy_cfg.spec and lazy_cfg.spec.modules then
    for _, mod in ipairs(lazy_cfg.spec.modules) do
      if mod == "noethervim.bundles.ui.colorscheme" then return "Colorschemes" end
    end
  end
  return "Colorschemes (9 more in the ui.colorscheme bundle)"
end

--- Every colorscheme that could be applied right now, installed or not yet
--- loaded.
---
--- `getcompletion("", "color")` is not enough: lazy.nvim keeps a plugin off
--- the runtimepath until something loads it, so a theme from the
--- ui.colorscheme bundle is invisible until you open the picker once. That
--- makes the answer depend on what you happen to have done this session,
--- which is the worst property a list of choices can have.
---
--- lazy exposes the unloaded paths, and globbing `colors/` across both is
--- what its own pickers do, so this agrees with `SearchLeader+C` by
--- construction.
--- Sorted and de-duplicated.
---@return string[] names
function M.list()
  local rtp = vim.o.runtimepath
  local ok, lazy_util = pcall(require, "lazy.core.util")
  if ok then
    rtp = rtp .. "," .. table.concat(lazy_util.get_unloaded_rtp(""), ",")
  end

  local seen, names = {}, {}
  for _, file in ipairs(vim.fn.globpath(rtp, "colors/*", false, true)) do
    local ext = file:match("%.(%w+)$")
    if ext == "vim" or ext == "lua" then
      local name = vim.fn.fnamemodify(file, ":t:r")
      if not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  table.sort(names)
  return names
end

-- ── Highlight tweaks ────────────────────────────────────────────────────────

local function apply_tweaks()
  for group, hl in pairs(_tweaks) do
    vim.api.nvim_set_hl(0, group, hl)
  end
end

--- Register highlight overrides that persist across colorscheme changes.
--- Call from user/highlights.lua or anywhere after setup.
---@param tweaks table<string, vim.api.keyset.highlight>
function M.tweak(tweaks)
  _tweaks = vim.tbl_deep_extend("force", _tweaks, tweaks)
  apply_tweaks()
end

function M.setup_tweaks()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("noethervim_hl_tweaks", { clear = true }),
    callback = apply_tweaks,
  })
end

return M
