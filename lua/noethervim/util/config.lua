--- Validators for `lua/user/config.lua`, the single user-facing surface.
---
--- `validate_types(cfg)` runs at `noethervim.setup()` entry and emits a
--- `vim.notify` warning for type mismatches. Bad types produce a warning,
--- not a crash -- the rest of setup continues with whatever was salvageable.
---
--- `validate_user_config(cfg)` is called from `:checkhealth noethervim`.
--- Per `:h lua-plugin-config`, validation of "unknown fields" (typo
--- detection) is overhead-sensitive enough that the upstream guide
--- explicitly recommends the health-check path for it.

local M = {}

--- Run a vim.validate call inside a pcall, prefixing any error with `path`
--- so messages name the offending key (e.g. `user.config.colorscheme:
--- expected string`).
---@param path string
---@param name string
---@param value any
---@param expected string|string[]
---@param optional? boolean
---@return string? err
local function check(path, name, value, expected, optional)
  local ok, err = pcall(vim.validate, name, value, expected, optional)
  if ok then return nil end
  return path .. "." .. (err or "validation failed")
end

--- Known top-level keys for `lua/user/config.lua`. Values are the
--- `vim.validate` type strings. Add new keys here when adding a user-
--- facing option per `dev-docs/bundle-development.md` §5.
local SCHEMA = {
  colorscheme                  = "string",
  colorscheme_persistence      = "boolean",
  statusline                   = "table",
  obsidian_vault               = "string",
  completion_style             = "string",
  blink_conservative_filetypes = "table",
  blink_conservative_size_kb   = "number",
  drop                         = "boolean",
  writing_filetypes            = "table",
  non_code_filetypes           = "table",
}

--- Inner schema for `cfg.statusline`. Same shape as the outer schema.
local STATUSLINE_SCHEMA = {
  colors      = "table",
  extra_right = "table",
  edge_style  = "string",
}

--- Type-check `cfg`. Returns a list of error strings; empty when valid.
--- Called at `noethervim.setup()` entry. Cheap enough to run every launch.
---@param cfg any
---@return string[] errors
function M.validate_types(cfg)
  local errors = {}
  local function add(err) if err then errors[#errors + 1] = err end end

  if cfg == nil then return errors end
  if type(cfg) ~= "table" then
    return { "user.config: expected table, got " .. type(cfg) }
  end

  for key, expected in pairs(SCHEMA) do
    if cfg[key] ~= nil then
      add(check("user.config", key, cfg[key], expected, true))
    end
  end

  if type(cfg.statusline) == "table" then
    for key, expected in pairs(STATUSLINE_SCHEMA) do
      if cfg.statusline[key] ~= nil then
        add(check("user.config.statusline", key, cfg.statusline[key], expected, true))
      end
    end
    if type(cfg.statusline.edge_style) == "string" then
      local valid = require("noethervim.statusline").list_edge_styles()
      if not vim.tbl_contains(valid, cfg.statusline.edge_style) then
        add("user.config.statusline.edge_style: expected one of "
          .. table.concat(valid, ", ") .. ", got " .. cfg.statusline.edge_style)
      end
    end
  end

  return errors
end

--- Full validation including unknown-field detection (typo catching).
--- Called from `:checkhealth noethervim`. Returns `errors` (type
--- mismatches) and `unknowns` (unrecognized keys). Both lists are empty
--- when valid.
---@param cfg any
---@return string[] errors
---@return string[] unknowns
function M.validate_user_config(cfg)
  local errors = M.validate_types(cfg)
  local unknowns = {}
  if type(cfg) ~= "table" then return errors, unknowns end

  for key, _ in pairs(cfg) do
    if SCHEMA[key] == nil then
      unknowns[#unknowns + 1] = key
    end
  end

  if type(cfg.statusline) == "table" then
    for key, _ in pairs(cfg.statusline) do
      if STATUSLINE_SCHEMA[key] == nil then
        unknowns[#unknowns + 1] = "statusline." .. key
      end
    end
  end

  return errors, unknowns
end

return M
