--- :NoetherVim diff autocmds: autocommand groups NoetherVim and you made,
--- and the ones you cleared.
---@diagnostic disable: undefined-doc-name

local Snacks = require("snacks")
local ui = require("noethervim.inspect.ui")
local effective_root = ui.effective_root
local user_dir = ui.user_dir
local hint_footer = ui.hint_footer

local M = {}

-- ── Comparison: Autocommands ────────────────────────────────────
--
-- Autocommands are additive, so the interesting question is not "which
-- line changed" but "is the core augroup still the one doing the work".
-- The documented way to override a core autocmd is to clear its augroup
-- and re-register (see |noethervim-user-autocmds|), and that is exactly
-- what this picker reports:
--
--   [CORE]     distro augroup, still populated from distro source
--   [OVERRIDE] distro augroup, but its handlers now come from lua/user/
--   [CLEARED]  distro augroup that exists but holds no handlers
--   [INACTIVE] never created this session (disabled bundle, plugin not
--              triggered, config flag off) -- absence here is expected
--   [USER]     augroup the distro never registers

--- Augroup names the distribution registers, scraped from its own source.
--- Scraping beats a hardcoded list: it cannot drift when an augroup is
--- added or renamed.
---@param root string
---@return table<string, string>  augroup name -> defining file
local function distro_augroups(root)
  local found = {}
  local files = vim.fn.globpath(root .. "/lua/noethervim", "**/*.lua", false, true)
  for _, file in ipairs(files) do
    local fd = io.open(file, "r")
    if fd then
      for line in fd:lines() do
        local name = line:match('nvim_create_augroup%(%s*"([^"]+)"')
        if name and not found[name] then found[name] = file end
      end
      fd:close()
    end
  end
  return found
end

--- Was this augroup ever created in this session?
---
--- Scraping the source tells us an augroup *can* exist, not that it does:
--- the `nvim_create_augroup` call may sit behind a disabled bundle or a
--- config flag that is off. `nvim_get_autocmds` draws the line for us --
--- it errors on a group that was never created and returns an empty list
--- for one that exists but holds nothing.
---@param group string
---@return boolean
local function augroup_exists(group)
  return (pcall(vim.api.nvim_get_autocmds, { group = group }))
end

--- Where a live autocmd's callback was defined, as file + line.
---@param cmd table  entry from nvim_get_autocmds
---@return string? file
---@return integer? line
local function autocmd_source(cmd)
  if type(cmd.callback) ~= "function" then return nil, nil end
  local ok, info = pcall(debug.getinfo, cmd.callback, "S")
  if not ok or not info or not info.source or info.source:sub(1, 1) ~= "@" then
    return nil, nil
  end
  return info.source:sub(2), info.linedefined
end

function M.diff_autocmds()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  local distro = distro_augroups(root)
  local udir = vim.fs.normalize(user_dir())
  local normroot = vim.fs.normalize(root)

  -- Collect live autocmds grouped by augroup.
  local live = {}
  for _, cmd in ipairs(vim.api.nvim_get_autocmds({})) do
    local group = cmd.group_name
    if group then
      local entry = live[group] or { count = 0, events = {}, from_user = false, file = nil, line = nil }
      entry.count = entry.count + 1
      if not vim.tbl_contains(entry.events, cmd.event) then
        entry.events[#entry.events + 1] = cmd.event
      end
      local file, line = autocmd_source(cmd)
      if file then
        file = vim.fs.normalize(file)
        if vim.startswith(file, udir) then entry.from_user = true end
        -- Prefer a user file as the jump target; it is the one being edited.
        if not entry.file or (entry.from_user and vim.startswith(file, udir)) then
          entry.file, entry.line = file, line
        end
      end
      live[group] = entry
    end
  end

  local items = {}
  local function add(group, tag, entry, fallback_file)
    table.sort(entry and entry.events or {})
    table.insert(items, {
      text   = tag .. " " .. group .. " " .. table.concat(entry and entry.events or {}, " "),
      tag    = tag,
      group  = group,
      count  = entry and entry.count or 0,
      events = table.concat(entry and entry.events or {}, ", "),
      file   = (entry and entry.file) or fallback_file,
      line   = entry and entry.line or nil,
    })
  end

  for group, src in pairs(distro) do
    local entry = live[group]
    if not entry then
      add(group, augroup_exists(group) and "[CLEARED]" or "[INACTIVE]", nil, src)
    elseif entry.from_user then
      add(group, "[OVERRIDE]", entry, src)
    else
      add(group, "[CORE]", entry, src)
    end
  end
  for group, entry in pairs(live) do
    if not distro[group] then
      -- Neovim's own augroups are noise here; only surface groups whose
      -- handlers were defined under the user's config directory.
      local file = entry.file
      if file and (vim.startswith(file, udir) or not vim.startswith(file, normroot)) then
        if vim.startswith(file, vim.fs.normalize(vim.fn.stdpath("config"))) then
          add(group, "[USER]", entry, nil)
        end
      end
    end
  end

  local tag_order = {
    ["[OVERRIDE]"] = 1, ["[CLEARED]"] = 2, ["[USER]"] = 3,
    ["[CORE]"] = 4, ["[INACTIVE]"] = 5,
  }
  local tag_hl = {
    ["[OVERRIDE]"] = "DiagnosticWarn",
    ["[CLEARED]"]  = "DiagnosticError",
    ["[USER]"]     = "DiagnosticOk",
    ["[CORE]"]     = "Comment",
    ["[INACTIVE]"] = "NonText",
  }
  table.sort(items, function(a, b)
    local oa, ob = tag_order[a.tag] or 9, tag_order[b.tag] or 9
    if oa ~= ob then return oa < ob end
    return a.group < b.group
  end)

  Snacks.picker({
    title  = "NoetherVim Autocommand Comparison",
    items  = items,
    layout = { preset = "select", preview = "main" },
    win = { input = {
      footer     = hint_footer({ { "<cr>", "source" } }),
      footer_pos = "center",
    } },
    format = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-11s", item.tag), tag_hl[item.tag] or "Comment" }
      ret[#ret + 1] = { string.format(" %-28s", item.group), "SnacksPickerFile" }
      ret[#ret + 1] = { string.format("%-3d ", item.count), "Number" }
      ret[#ret + 1] = { item.events, "Comment" }
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      if not item.file or not vim.uv.fs_stat(item.file) then
        return vim.notify("NoetherVim: no source recorded for " .. item.group, vim.log.levels.WARN)
      end
      local readonly = vim.startswith(item.file, normroot) and not vim.g.noethervim_dev
      vim.cmd((readonly and "view " or "edit ") .. vim.fn.fnameescape(item.file))
      if readonly then vim.bo.readonly = true; vim.bo.modifiable = false end
      if item.line then
        pcall(vim.api.nvim_win_set_cursor, 0, { item.line, 0 })
      else
        vim.fn.search(vim.fn.escape(item.group, "/\\[]{}().*+^$~"), "w")
      end
      vim.cmd("norm! zz")
    end,
  })
end

return M
