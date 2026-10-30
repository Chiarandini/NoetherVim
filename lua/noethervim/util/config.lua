--- Validators for `lua/user/config.lua`, the single user-facing surface.
---
--- `validate_user_config(cfg)` returns the type errors and the keys nothing
--- reads. setup() warns about both, and `:checkhealth noethervim` lists them.
--- `:h lua-plugin-config` suggests leaving unknown-field detection to
--- health for its cost; here it is one walk over a table of a dozen keys,
--- and a setting ignored without a word costs more. `validate_types(cfg)`
--- returns the type errors alone.

local M = {}

--- The shape of `lua/user/config.lua`. A string is the `vim.validate`
--- type of a value; a table is the schema of a nested table. Add a key here
--- when adding a user-facing option per `dev-docs/bundle-development.md` §5.
local SCHEMA = {
  colorscheme             = "string",
  colorscheme_persistence = "boolean",
  statusline = {
    style = {
      colors                 = "table",
      edge_style             = "string",
      tab_modified_indicator = "string",
      mode_background        = "boolean",
      git_click              = "function",
    },
    segments = "table",
    layout   = "table",
    bars = {
      statusline = "boolean",
      tabline    = "boolean",
      winbar     = "boolean",
    },
  },
  completion = {
    style = "string",
  },
  profiles = {
    classes       = "table",
    spell_in_code = "boolean",
    conservative  = "table",
  },
  q_close           = "table",
  toggle_feedback   = "string",
  snippets_disabled = "table",
  keymaps           = "table",
  lsp               = "table",
  pick = {
    route   = "table",
    engines = "table",
  },
}

--- Nested tables that also accept `false`, meaning "off".
local MAY_BE_FALSE = { profiles = true }

--- Permitted values for the small enum fields, by dotted path. Unknown
--- strings would otherwise silently fall back to the default behavior,
--- which masks typos.
---
--- Every string-valued key with a closed set of values belongs here.
--- `statusline.style.edge_style` is the one exception: its values live in
--- `noethervim.statusline` and are checked below through
--- `list_edge_styles()` so the two cannot drift apart.
local ENUMS = {
  toggle_feedback    = { "notify", "echo", "off" },
  ["completion.style"] = { "snippet", "supertab", "navigate" },
}

local function sorted_keys(t)
  local keys = vim.tbl_keys(t)
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

--- Check `cfg` against `schema`, adding to `errors` and, when given,
--- naming keys the schema does not know in `unknowns`.
---@param prefix string dotted path of `cfg`, "" at the top
local function walk(prefix, cfg, schema, errors, unknowns)
  for _, key in ipairs(sorted_keys(cfg)) do
    local value, expected = cfg[key], schema[key]
    local name = prefix .. tostring(key)
    if expected == nil then
      if unknowns then unknowns[#unknowns + 1] = name end
    elseif type(expected) == "table" then
      if not (value == false and MAY_BE_FALSE[name]) then
        if type(value) ~= "table" then
          errors[#errors + 1] = ("user.config.%s: expected table, got %s"):format(name, type(value))
        else
          walk(name .. ".", value, expected, errors, unknowns)
        end
      end
    else
      local ok, err = pcall(vim.validate, name, value, expected)
      if not ok then errors[#errors + 1] = "user.config." .. (err or (name .. ": invalid")) end
    end
  end
end

---@param cfg any
---@param want_unknowns boolean
---@return string[] errors, string[] unknowns
local function check(cfg, want_unknowns)
  local errors, unknowns = {}, {}
  if cfg == nil then return errors, unknowns end
  if type(cfg) ~= "table" then
    return { "user.config: expected table, got " .. type(cfg) }, unknowns
  end
  walk("", cfg, SCHEMA, errors, want_unknowns and unknowns or nil)

  for path, valid in pairs(ENUMS) do
    local value = cfg
    for part in path:gmatch("[^.]+") do
      value = type(value) == "table" and value[part] or nil
    end
    if type(value) == "string" and not vim.tbl_contains(valid, value) then
      errors[#errors + 1] = ("user.config.%s: expected one of %s, got %s"):format(
        path, table.concat(valid, ", "), value)
    end
  end

  -- `profiles.conservative`: filetypes mapped to true or false, and size_kb.
  local conservative = vim.tbl_get(cfg, "profiles", "conservative")
  if type(conservative) == "table" then
    for _, key in ipairs(sorted_keys(conservative)) do
      local v = conservative[key]
      if key == "size_kb" then
        if type(v) ~= "number" then
          errors[#errors + 1] = "user.config.profiles.conservative.size_kb: expected number, got " .. type(v)
        end
      elseif type(v) ~= "boolean" then
        errors[#errors + 1] = ("user.config.profiles.conservative.%s: expected true or false (a filetype), got %s")
          :format(tostring(key), type(v))
      end
    end
  end

  -- `pick`: routes and engines name verbs, and a typo would route nothing.
  local verbs = {}
  for _, v in ipairs(require("noethervim.pick").VERBS) do verbs[v] = true end
  local function verb_key(path, key)
    if not verbs[key] then
      errors[#errors + 1] = ("user.config.%s.%s: not a picker verb (%s)"):format(path, tostring(key),
        table.concat(require("noethervim.pick").VERBS, ", "))
      return false
    end
    return true
  end
  local route = vim.tbl_get(cfg, "pick", "route")
  if type(route) == "table" then
    for _, key in ipairs(sorted_keys(route)) do
      if verb_key("pick.route", key) and type(route[key]) ~= "string" then
        errors[#errors + 1] = ("user.config.pick.route.%s: expected an engine name, got %s"):format(key, type(route[key]))
      end
    end
  end
  local engines = vim.tbl_get(cfg, "pick", "engines")
  if type(engines) == "table" then
    for _, name in ipairs(sorted_keys(engines)) do
      local engine = engines[name]
      if type(engine) ~= "table" then
        errors[#errors + 1] = ("user.config.pick.engines.%s: expected a table of functions by verb, got %s")
          :format(tostring(name), type(engine))
      else
        for _, key in ipairs(sorted_keys(engine)) do
          if verb_key("pick.engines." .. tostring(name), key) and type(engine[key]) ~= "function" then
            errors[#errors + 1] = ("user.config.pick.engines.%s.%s: expected function, got %s")
              :format(tostring(name), key, type(engine[key]))
          end
        end
      end
    end
  end

  local edge = vim.tbl_get(cfg, "statusline", "style", "edge_style")
  if type(edge) == "string" then
    local valid = require("noethervim.statusline").list_edge_styles()
    if not vim.tbl_contains(valid, edge) then
      errors[#errors + 1] = "user.config.statusline.style.edge_style: expected one of "
        .. table.concat(valid, ", ") .. ", got " .. edge
    end
  end

  return errors, unknowns
end

--- Type-check `cfg`. Returns a list of error strings; empty when valid.
--- Called at `noethervim.setup()` entry. Cheap enough to run every launch.
---@param cfg any
---@return string[] errors
function M.validate_types(cfg)
  return (check(cfg, false))
end

--- Full validation including unknown-field detection (typo catching).
--- Called from `:checkhealth noethervim`. Returns `errors` (type
--- mismatches) and `unknowns` (unrecognized keys, dotted when nested). Both
--- lists are empty when valid.
---@param cfg any
---@return string[] errors
---@return string[] unknowns
function M.validate_user_config(cfg)
  return check(cfg, true)
end

return M
