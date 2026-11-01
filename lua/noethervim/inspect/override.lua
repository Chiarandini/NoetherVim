--- :NoetherVim override: open, or create, the file of yours that changes
--- the distro file in the current buffer.

local ui = require("noethervim.inspect.ui")
local map_to_user_path = ui.map_to_user_path

local M = {}

-- ── Override: open user file for current source ─────────────

--- Every distinct `owner/repo` string in a spec file, in source order.
---
--- Used to seed a plugin or bundle override with the keys that actually
--- merge. The quotes are part of the pattern, so a path like
--- `"lua/user/plugins"` cannot match -- only a string whose entire contents
--- are two slash-separated segments.
---@param path string
---@return string[]
local function spec_repos(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= "table" then return {} end
  local out, seen = {}, {}
  for _, line in ipairs(lines) do
    for repo in line:gmatch('"([%w%-%._]+/[%w%-%._]+)"') do
      if not seen[repo] then
        seen[repo] = true
        out[#out + 1] = repo
      end
    end
  end
  return out
end

--- The distro's option defaults in `path` (options.lua writes them as
--- `opt.name = value` and `append("name", value)`), as commented lines for
--- your options file.
---@param path string
---@return string[]
local function option_lines(path)
  local out = {}
  for _, line in ipairs(vim.fn.readfile(path)) do
    local code = line:gsub("%s*%-%-.*$", "")
    local name, value = code:match("^%s*opt%.([%w_]+)%s*=%s*(.-)%s*$")
    if name then
      out[#out + 1] = ("-- vim.o.%s = %s"):format(name, value)
    else
      local aname, avalue = code:match('^%s*append%(%s*"([%w_]+)"%s*,%s*(.-)%)%s*$')
      if aname then out[#out + 1] = ("-- vim.opt.%s:append(%s)"):format(aname, avalue) end
    end
  end
  return out
end

--- `vim.keymap.del` lines for every key NoetherVim mapped from `path`.
---@param path string
---@return string[]
local function key_del_lines(path)
  local tail = vim.fn.fnamemodify(path, ":~")
  local out, seen = {}, {}
  for _, rec in pairs(require("noethervim.default").owned.map) do
    if type(rec.source) == "string" and vim.startswith(rec.source, tail .. ":") then
      local line = ('-- vim.keymap.del(%q, %q)'):format(rec.mode, rec.name)
      if not seen[line] then
        seen[line] = true
        out[#out + 1] = line
      end
    end
  end
  table.sort(out)
  return out
end

--- What the writing profile sets, as `vim.opt_local` lines for one filetype.
local PROFILE_LINES = {
  writing = {
    "-- vim.opt_local.wrap = true",
    "-- vim.opt_local.linebreak = true",
    "-- vim.opt_local.spell = true",
    "-- vim.opt_local.conceallevel = 2",
    "-- vim.opt_local.list = false",
    "-- vim.opt_local.formatoptions:append(\"t\")",
  },
  code = {
    "-- vim.opt_local.list = true",
  },
}

--- Lines to add to the file of yours for `rel`, given what it already holds.
---@param rel string            upstream path, relative to the distribution root
---@param category string
---@param upstream string       absolute path to the upstream file
---@param existing string[]     the file's current lines, empty when new
---@param ft? string            the filetype, for a profile
---@return string[]
local function seed_lines(rel, category, upstream, existing, ft)
  local marker = "-- NoetherVim's " .. (ft and (ft .. " profile") or rel) .. ":"
  for _, line in ipairs(existing) do
    if line == marker then return {} end
  end
  local lines = {}
  if category == "plugin" or category == "bundle" then
    if #existing > 0 then return {} end
    lines = { "-- Override: " .. rel,
      "-- Specs merge with the upstream file by repo string.",
      "-- See :help noethervim-user-plugins", "return {" }
    local repos = spec_repos(upstream)
    if #repos == 0 then
      lines[#lines + 1] = "  -- { \"owner/repo\", opts = {} },"
    else
      for _, repo in ipairs(repos) do
        lines[#lines + 1] = ('  -- { "%s", opts = {} },'):format(repo)
      end
    end
    lines[#lines + 1] = "}"
    return lines
  end
  if category == "lsp" then
    if #existing > 0 then return {} end
    lines = { "-- Merged over NoetherVim's " .. rel .. "; a key you set here wins.",
      "-- To start from lspconfig's settings alone instead, set",
      "-- `lsp = { " .. vim.fn.fnamemodify(rel, ":t:r") .. " = false }` in lua/user/config.lua." }
    for _, line in ipairs(vim.fn.readfile(upstream)) do
      if not line:find("lsp_off(", 1, true) then lines[#lines + 1] = line end
    end
    return lines
  end
  lines = { marker }
  if category == "core" and rel:match("options%.lua$") then
    vim.list_extend(lines, option_lines(upstream))
  elseif category == "keys" then
    lines[#lines + 1] = "-- Remove any of them here; to drop every key that changes a Vim key,"
    lines[#lines + 1] = "-- set `keymaps = { remaps = false }` in lua/user/config.lua."
    vim.list_extend(lines, key_del_lines(upstream))
  elseif category == "profile" then
    local class = require("noethervim.profiles").class(ft or "")
    lines[#lines + 1] = "-- A value set here is kept; see :help noethervim-filetype-profiles"
    vim.list_extend(lines, PROFILE_LINES[class or "writing"])
  elseif category == "ftplugin" then
    lines[#lines + 1] = "-- Runs after NoetherVim's " .. rel .. "."
  else
    lines[#lines + 1] = "-- See " .. rel .. " for what NoetherVim sets."
  end
  return lines
end

--- Open the file of yours that changes the current distro file, creating
--- or extending it with a commented starting point.
---
--- Everything written here is a starting point, not a format: the baseline
--- used by the drift check lives in NoetherVim's state directory, so the file
--- can be rewritten from scratch without breaking anything.
function M.override()
  local bufpath = vim.api.nvim_buf_get_name(0)
  if bufpath == "" then
    return vim.notify("NoetherVim: current buffer has no file", vim.log.levels.WARN)
  end

  local user_path, category = map_to_user_path(bufpath)
  if not user_path then
    return vim.notify("NoetherVim: nothing of yours stands in for this file; "
      .. "lua/user/config.lua or after/plugin/ change what it does", vim.log.levels.WARN)
  end

  local rel = ui.relative(bufpath) --[[@as string]]

  ---@cast category string
  local function finish(path, ft)
    local is_new = not vim.uv.fs_stat(path)
    local existing = is_new and {} or vim.fn.readfile(path)
    local add = seed_lines(rel, category, bufpath, existing, ft)
    local shown = vim.fn.fnamemodify(path, ":~")

    local function open()
      -- Record what this override is being written against. Re-running the
      -- command re-baselines it, which is how you clear a drift warning once
      -- you have read the upstream change.
      require("noethervim.inspect.override_base").record(path, rel, bufpath)
      vim.cmd("vsplit " .. vim.fn.fnameescape(path))
    end
    if #add == 0 then return open() end

    -- Nothing is written into your config without your go-ahead: the
    -- addition is shown as a diff first.
    local new = vim.deepcopy(existing)
    if #existing > 0 and existing[#existing] ~= "" then table.insert(new, "") end
    vim.list_extend(new, add)
    local before = #existing > 0 and (table.concat(existing, "\n") .. "\n") or ""
    local body = vim.diff(before, table.concat(new, "\n") .. "\n", { result_type = "unified", ctxlen = 3 })
    require("noethervim.inspect.diff_modal").confirm({
      title   = (is_new and "Create " or "Add to ") .. shown,
      diff    = ("--- %s\n+++ %s\n%s"):format(shown, shown, body or ""),
      on_done = function(accepted)
        if not accepted then
          vim.notify("NoetherVim: " .. shown .. " left as it was", vim.log.levels.INFO)
          if not is_new then vim.schedule(open) end
          return
        end
        vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
        vim.fn.writefile(new, path)
        vim.notify(("NoetherVim: %s %s"):format(is_new and "created" or "added to", shown), vim.log.levels.INFO)
        vim.schedule(open)
      end,
    })
  end

  if category == "profile" then
    vim.ui.input({ prompt = "Filetype: " }, function(ft)
      if ft and ft ~= "" then finish(user_path .. ft .. ".lua", ft) end
    end)
  else
    finish(user_path)
  end
end

return M
