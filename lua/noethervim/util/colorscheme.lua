-- NoetherVim colorscheme utilities.
-- Persistence: saves/restores the active colorscheme across sessions.
-- Tweaks: re-applies user highlight overrides when the colorscheme changes.

-- vim.api.keyset.highlight is shipped in Neovim's runtime _meta directory,
-- but standalone lua-language-server --check cannot reach a user-specific
-- $VIMRUNTIME path through .luarc.json. IDE users with lazydev or
-- runtime-injected library paths see the real type; CI uses this disable.
---@diagnostic disable: undefined-doc-name

local M = {}
local _file = vim.fn.stdpath("data") .. "/noethervim_colorscheme"
local _tweaks = {} ---@type table<string, vim.api.keyset.highlight>

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
  local group = vim.api.nvim_create_augroup("noethervim_colorscheme", { clear = true })

  -- Save on every colorscheme change.
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function(args) save(args.match) end,
  })

  -- Restore immediately (setup() runs after VimEnter, so a deferred
  -- VimEnter autocmd would never fire).
  local saved = load()
  if saved then
    pcall(vim.cmd.colorscheme, saved)
  end
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

-- ── Compat: old setup() call used by persistence bundle ─────────────────────

function M.setup()
  M.setup_persistence()
end

return M
