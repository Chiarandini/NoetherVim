--- :NoetherVim debug-keymaps: where each keymap was registered, and why.

local ui = require("noethervim.inspect.ui")
local snapshots = ui.snapshots
local keymap_source = require("noethervim.inspect.source")
local same_mapping = keymap_source.same_mapping
local callback_file = keymap_source.callback_file

local M = {}

-- ── Debug: keymap source diagnostic ─────────────────────────────

--- Show the source attribution for every tracked keymap. For each key
--- in the diff set, report the data source that would drive a jump:
---   REG   — a row, a write through noethervim.default, or a mapping made by a sourced file
---   LAZY  — attributed via lazy.nvim handler metadata (spec file)
---   CB    — inferred from the callback function's defining file
---   ----  — no source available; jump would notify and do nothing
--- Run with :NoetherVim debug-keymaps
function M.debug_keymaps()
  local snap = snapshots()
  if not snap.keymaps_before or not snap.keymaps_after then
    return vim.notify("NoetherVim: no keymap snapshots", vim.log.levels.WARN)
  end

  local key_sources, lazy_managed = require("noethervim.inspect.source").keymap_sources()
  local registry = require("noethervim.inspect.source")

  local baseline = snap.keymaps_baseline or {}
  local before   = snap.keymaps_before
  local after    = snap.keymaps_after

  local all_keys = {}
  for k in pairs(before) do all_keys[k] = true end
  for k in pairs(after)  do all_keys[k] = true end

  local results = {}
  local skipped = 0
  for key in pairs(all_keys) do
    local a, b, bl = after[key], before[key], baseline[key]
    -- Same Neovim-default filter as diff_keymaps.
    if a and b and bl and not key_sources[key] and not lazy_managed[key]
       and same_mapping(bl, b) and same_mapping(b, a) then
      skipped = skipped + 1
    else
      local km = a or b
      local entry = registry.lookup(km.mode, km.lhs)
      local kind, file, line
      if entry then
        kind, file, line = "REG ", entry.file, entry.line
      elseif key_sources[key] then
        kind, file = "LAZY", key_sources[key]
      else
        local cb_file = callback_file(km.callback)
        if cb_file then kind, file = "CB  ", cb_file
        else kind = "----" end
      end
      results[#results + 1] = {
        kind = kind, mode = km.mode, lhs = km.lhs, desc = km.desc,
        file = file and vim.fn.fnamemodify(file, ":t") or "???",
        line = line,
      }
    end
  end

  table.sort(results, function(a, b)
    if a.kind ~= b.kind then return a.kind > b.kind end  -- ---- first, then CB, LAZY, REG
    if a.mode ~= b.mode then return a.mode < b.mode end
    return a.lhs < b.lhs
  end)

  local counts = { REG = 0, LAZY = 0, CB = 0, MISS = 0 }
  for _, r in ipairs(results) do
    local k = r.kind:gsub("%s", "")
    if k == "" then counts.MISS = counts.MISS + 1
    else counts[k] = (counts[k] or 0) + 1 end
  end

  local out = {
    "NoetherVim Keymap Source Diagnostic",
    string.format("Total: %d keymaps  (REG:%d  LAZY:%d  CB:%d  none:%d  Neovim defaults filtered: %d)",
      #results, counts.REG, counts.LAZY, counts.CB, counts.MISS, skipped),
    string.rep("─", 80),
  }
  for _, r in ipairs(results) do
    out[#out + 1] = string.format("[%s] [%s] %-20s  %-24s %-6s %s",
      r.kind, r.mode, r.lhs, r.file,
      r.line and ("L" .. r.line) or "",
      r.desc)
  end

  vim.cmd("tabnew")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_name(0, "noethervim://keymap-diagnostic")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, out)
end

return M
