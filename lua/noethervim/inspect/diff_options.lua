--- :NoetherVim diff options: options your files changed from NoetherVim's.
---@diagnostic disable: undefined-doc-name

local Snacks = require("snacks")
local ui = require("noethervim.inspect.ui")
local effective_root = ui.effective_root
local user_dir = ui.user_dir
local snapshots = ui.snapshots
local hint_footer = ui.hint_footer

local M = {}

-- ── Comparison: Options ─────────────────────────────

function M.diff_options()
  local snap = snapshots()
  if not snap.options_before or not snap.options_after then
    return vim.notify("NoetherVim: no option snapshots (user overrides may be disabled)", vim.log.levels.WARN)
  end

  local before = snap.options_before
  local after  = snap.options_after
  local items  = {}

  local yours = require("noethervim.user_layer").is_yours
  for name, default_val in pairs(before) do
    local current_val = after[name]
    local sid = vim.api.nvim_get_option_info2(name, { scope = "global" }).last_set_sid
    local tag = (current_val ~= default_val and yours(sid)) and "[OVERRIDE]" or "[CORE]"
    table.insert(items, {
      text        = tag .. " " .. name .. " " .. tostring(current_val) .. " " .. tostring(default_val),
      tag         = tag,
      name        = name,
      current     = tostring(current_val),
      default_val = tostring(default_val),
    })
  end

  local tag_order = { ["[OVERRIDE]"] = 1, ["[CORE]"] = 2 }
  local tag_hl = {
    ["[OVERRIDE]"] = "DiagnosticWarn",
    ["[CORE]"]     = "Comment",
  }
  table.sort(items, function(a, b)
    local oa = tag_order[a.tag] or 3
    local ob = tag_order[b.tag] or 3
    if oa ~= ob then return oa < ob end
    return a.name < b.name
  end)

  Snacks.picker({
    title  = "NoetherVim Option Comparison",
    items  = items,
    layout = { preset = "select", preview = "main" },
    win = { input = {
      footer     = hint_footer({ { "<cr>", "source" } }),
      footer_pos = "center",
    } },
    format = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-11s", item.tag), tag_hl[item.tag] or "Comment" }
      ret[#ret + 1] = { string.format(" %-20s", item.name), "SnacksPickerFile" }
      ret[#ret + 1] = { " = " }
      ret[#ret + 1] = { string.format("%-12s", item.current), item.tag == "[OVERRIDE]" and "DiagnosticWarn" or "SnacksPickerFile" }
      ret[#ret + 1] = { " (default: ", "Comment" }
      ret[#ret + 1] = { item.default_val, "Comment" }
      ret[#ret + 1] = { ")", "Comment" }
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      local file, readonly
      if item.tag == "[OVERRIDE]" then
        file = user_dir() .. "options.lua"
        readonly = false
      else
        local root = effective_root()
        if root then file = root .. "/lua/noethervim/options.lua" end
        readonly = not vim.g.noethervim_dev
      end
      if file and vim.uv.fs_stat(file) then
        vim.cmd((readonly and "view " or "edit ") .. vim.fn.fnameescape(file))
        if readonly then vim.bo.readonly = true; vim.bo.modifiable = false end
        vim.fn.search(vim.fn.escape(item.name, "/\\[]{}().*+^$~"), "w")
      end
    end,
  })
end

return M
