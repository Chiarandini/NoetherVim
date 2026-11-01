--- Heirline's side of the statusline segments (noethervim.statusline).
---
--- A segment is renderer-neutral data: a provider returning text, or chunks
--- of text with a highlight group or a `{ fg = ... }` table. This turns each
--- into a heirline component and lays the main bar out by id: the core
--- blocks in order, and each segment after the block or segment its
--- `place.after` names, or else at the start of its side.

local sl = require("noethervim.statusline")

local M = {}

--- A chunk's highlight as heirline takes it: the foreground of a group, so
--- the bar's own background shows through, or the table as given.
---@param hl string|table|nil
local function highlight(hl)
  if type(hl) == "string" then
    local ok, def = pcall(vim.api.nvim_get_hl, 0, { name = hl, link = false })
    return ok and def.fg and { fg = def.fg } or nil
  end
  return hl
end

--- The heirline component that draws segment `id`.
---@param id string
local function component(id)
  local seg = sl.segment(id)
  return {
    -- heirline evaluates `condition` before `init`, so the chunks are
    -- computed once here and handed on.
    condition = function(self)
      self.chunks = sl.chunks(id)
      return self.chunks ~= nil
    end,
    init = function(self)
      for i, chunk in ipairs(self.chunks) do
        self[i] = self:new({
          provider = (chunk[1]:gsub("%%", "%%%%")),
          hl = highlight(chunk[2]),
        }, i)
      end
      self[#self.chunks + 1] = self:new({ provider = " " }, #self.chunks + 1)
      for i = #self.chunks + 2, #self do self[i] = nil end
    end,
    on_click = seg and seg.click and {
      name = "noethervim_segment_" .. id:gsub("[^%w]", "_"),
      callback = function(_, _, _, button) sl.click(id, button) end,
    } or nil,
  }
end

--- The segment ids placed on `side`, each after the id it names.
---@param side "left"|"right"
---@return table<string, string[]> after  anchor id ("" for the side's start) -> ids
local function placed(side)
  local after = {}
  for _, id in ipairs(sl.ids()) do
    local seg = sl.segment(id)
    local place = seg and seg.place or {}
    if seg and (place.side or "right") == side then
      local anchor = place.after or ""
      after[anchor] = after[anchor] or {}
      table.insert(after[anchor], id)
    end
  end
  return after
end

--- `core` (pairs of id and heirline components, in order) with the side's
--- segments placed among them. A segment after an id nothing declares
--- lands at the start of the side.
---@param side "left"|"right"
---@param core { [1]: string, [2]: table[] }[]
---@return table[]
function M.side(side, core)
  local after = placed(side)
  local known = { [""] = true }
  for _, block in ipairs(core) do known[block[1]] = true end
  for _, id in ipairs(sl.ids()) do known[id] = true end
  local dangling = vim.tbl_filter(function(anchor) return not known[anchor] end, vim.tbl_keys(after))
  table.sort(dangling)
  for _, anchor in ipairs(dangling) do
    after[""] = vim.list_extend(after[""] or {}, after[anchor])
    after[anchor] = nil
  end

  local out = {}
  local function emit(anchor)
    for _, id in ipairs(after[anchor] or {}) do
      table.insert(out, component(id))
      emit(id)
    end
  end
  emit("")
  for _, block in ipairs(core) do
    vim.list_extend(out, block[2])
    emit(block[1])
  end
  return out
end

return M
