--- Validators for the two user-facing opts surfaces.
---
--- `validate_setup_opts(opts)` runs at `noethervim.setup()` entry and emits
--- a `vim.notify` warning for type mismatches. Bad opts produce a warning,
--- not a crash -- the rest of setup continues with whatever was salvageable.
---
--- `validate_user_config(cfg)` is called from `:checkhealth noethervim`.
--- Per `:h lua-plugin-config`, validation of "unknown fields" (typo
--- detection) is overhead-sensitive enough that the upstream guide
--- explicitly recommends the health-check path for it.

local M = {}

--- Run a vim.validate call inside a pcall, prefixing any error with `path`
--- so messages name the offending key (e.g. `opts.colorscheme: expected string`).
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

--- Validate the opts table accepted by `noethervim.setup(opts)`.
--- Returns a list of error strings; empty when valid.
---@param opts any
---@return string[] errors
function M.validate_setup_opts(opts)
  local errors = {}
  local function add(err) if err then errors[#errors + 1] = err end end

  if opts == nil then return errors end
  if type(opts) ~= "table" then
    return { "opts: expected table, got " .. type(opts) }
  end

  add(check("opts", "colorscheme",             opts.colorscheme,             "string",  true))
  add(check("opts", "colorscheme_persistence", opts.colorscheme_persistence, "boolean", true))
  add(check("opts", "statusline",              opts.statusline,              "table",   true))

  if type(opts.statusline) == "table" then
    add(check("opts.statusline", "colors",      opts.statusline.colors,      "table", true))
    add(check("opts.statusline", "extra_right", opts.statusline.extra_right, "table", true))
  end

  return errors
end

--- Known keys for `lua/user/config.lua`. Update when adding a key per
--- `dev-docs/bundle-development.md` §5.
local USER_CONFIG_SCHEMA = {
  obsidian_vault                = "string",
  blink_conservative_filetypes  = "table",
  blink_conservative_size_kb    = "number",
  drop                          = "boolean",
  writing_filetypes             = "table",
  non_code_filetypes            = "table",
}

--- Validate the table returned from `lua/user/config.lua`.
--- Returns `errors` (type mismatches) and `unknowns` (unrecognized keys --
--- usually typos). Both lists are empty when valid.
---@param cfg any
---@return string[] errors
---@return string[] unknowns
function M.validate_user_config(cfg)
  local errors, unknowns = {}, {}
  if cfg == nil then return errors, unknowns end
  if type(cfg) ~= "table" then
    return { "user.config: expected table, got " .. type(cfg) }, unknowns
  end

  for key, expected in pairs(USER_CONFIG_SCHEMA) do
    if cfg[key] ~= nil then
      local err = check("user.config", key, cfg[key], expected, true)
      if err then errors[#errors + 1] = err end
    end
  end

  for key, _ in pairs(cfg) do
    if USER_CONFIG_SCHEMA[key] == nil then
      unknowns[#unknowns + 1] = key
    end
  end

  return errors, unknowns
end

return M
