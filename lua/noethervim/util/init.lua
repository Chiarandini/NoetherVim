--- NoetherVim utility module
--- Usage:  local nv = require("noethervim.util")
---         nv.icons.search  →  "󰍉"

local M = {}

M.icons         = require("noethervim.util.icons")
M.copy_pdf      = require("noethervim.util.copy_pdf")
M.search_leader = vim.g.mapsearchleader or "<space>"

--- Plain (non-magic) string replacement.
---@param s string
---@param substring string
---@param replacement string
---@param n? integer  max replacements
---@return string
function M.str_replace(s, substring, replacement, n)
  return (s:gsub(substring:gsub("%p", "%%%0"), replacement:gsub("%%", "%%%%"), n))
end

--- Map resolved keymap lhs values to the spec file that defines them.
--- Combines lazy.nvim's key handler data (key_id -> plugin_name) with a
--- scan of NoetherVim spec files (plugin_name -> file path).
--- Returns two tables:
---   sources:  { ["mode|resolved_lhs"] = "/path/to/plugins/snacks.lua", ... }
---   managed:  { ["mode|resolved_lhs"] = true, ... } (ALL lazy handler keys,
---             even from dev/user-only plugins without a mapped spec file)
--- Keymaps set directly via vim.keymap.set (not in a lazy spec) are absent.
function M.keymap_sources()
  local sources = {}

  -- Build plugin_name -> spec file by scanning for repo strings
  local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
  local root = init and vim.fn.fnamemodify(init, ":h:h:h")
  if not root then return sources end

  local plugin_files = {}
  local user_plugins = vim.fn.stdpath("config") .. "/lua/user/plugins"
  for _, dir in ipairs({
    root .. "/lua/noethervim/plugins",
    root .. "/lua/noethervim/bundles",
    user_plugins,
  }) do
    local handle = vim.uv.fs_scandir(dir)
    if handle then
      while true do
        local name, ftype = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if (ftype == "file" or ftype == "link") and name:match("%.lua$") then
          local filepath = dir .. "/" .. name
          -- Track brace depth to skip `dependencies = { ... }` blocks.
          -- A repo like trouble.nvim appears as a dependency in
          -- telescope.lua; without skipping, telescope.lua would claim
          -- trouble.nvim's handler keys.
          local deps_depth = nil
          local depth = 0
          for _, line in ipairs(vim.fn.readfile(filepath)) do
            if line:find("dependencies") and line:find("{") then
              deps_depth = depth
            end
            for c in line:gmatch("[{}]") do
              depth = depth + (c == "{" and 1 or -1)
            end
            if deps_depth and depth <= deps_depth then
              deps_depth = nil
            end
            if not deps_depth then
              for repo in line:gmatch('"[%w_%-]+/([%w_%-%.]+)"') do
                if not plugin_files[repo] then
                  plugin_files[repo] = filepath
                end
              end
            end
          end
        end
      end
    end
  end

  -- Iterate over each plugin's own key handlers to get the defining
  -- plugin (not the handler plugin, which managed would give us).
  local managed = {}
  local ok_cfg, lazy_cfg = pcall(require, "lazy.core.config")
  if ok_cfg and lazy_cfg.plugins then
    for name, plugin in pairs(lazy_cfg.plugins) do
      local file = plugin_files[name]
      local keys = plugin._ and plugin._.handlers and plugin._.handlers.keys
      if keys then
        for id in pairs(keys) do
          -- Handler ids are resolved terminal codes.  Convert back to
          -- the notation nvim_get_keymap uses (keytrans, but with
          -- literal space instead of <Space>).
          local base, mode_suffix = id:match("^(.+) %(([^,)]+)%)$")
          if not base or not mode_suffix or #mode_suffix > 2 then
            base = id
            mode_suffix = "n"
          end
          local lhs = vim.fn.keytrans(base):gsub("<Space>", " ")
          local key = mode_suffix .. "|" .. lhs
          managed[key] = true
          if file then
            sources[key] = file
          end
        end
      end
    end
  end

  return sources, managed
end

return M
