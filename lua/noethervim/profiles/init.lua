--- The writing system's classification: which profile a filetype gets.
---
---   class(ft)  "writing", "code", or nil for a filetype both leave alone
---   of(buf)    the same for a buffer
---   classes()  every filetype with a class of its own, `false` for one
---              left alone on purpose
---
--- `profiles = false` in lua/user/config.lua turns both profiles off;
--- `profiles = { classes = { [ft] = "writing" | "code" | false } }` moves or
--- removes one filetype.

local M = {}

--- The options the profiles write. A value of yours in one of them is kept
--- (profiles/apply.lua records claims on these), and `:NoetherVim where`
--- names the profile behind them.
M.MANAGED = { "wrap", "linebreak", "conceallevel", "spell", "list", "statuscolumn", "formatoptions" }

local function settings()
  return require("noethervim.config").get().profiles
end

--- The class `profiles.classes` in config.lua gives `ft`, if any.
---@param ft string
---@return "writing"|"code"|false|nil
local function override(ft)
  local p = settings()
  if p == false then return false end
  local classes = type(p) == "table" and p.classes
  if type(classes) == "table" then return classes[ft] end
end

---@param ft string
---@return "writing"|"code"|nil
function M.class(ft)
  local over = override(ft)
  if over == false then return nil end
  if over == "writing" or over == "code" then return over end
  if ft == "" then return nil end
  local fts = require("noethervim.util.filetypes")
  if fts.non_code[ft] then return nil end
  return fts.writing[ft] and "writing" or "code"
end

---@param buf integer
---@return "writing"|"code"|nil
function M.of(buf)
  return M.class(vim.bo[buf].filetype)
end

--- Filetypes with a class of their own. Every other filetype with a
--- filetype at all is code.
---@return table<string, "writing"|"code"|false>
function M.classes()
  local fts = require("noethervim.util.filetypes")
  local out = {}
  for ft in pairs(fts.writing) do out[ft] = "writing" end
  for ft in pairs(fts.non_code) do out[ft] = false end
  local p = settings()
  if type(p) == "table" and type(p.classes) == "table" then
    for ft, class in pairs(p.classes) do out[ft] = class end
  end
  return out
end

--- Whether completion should wait to be asked in `buf`: a filetype in
--- `profiles.conservative.filetypes` (default tex and latex), or a file
--- larger than `profiles.conservative.size_kb` (default 500). Holds with
--- `profiles = false` too, from the defaults.
---@param buf integer
---@return boolean
function M.conservative(buf)
  local p = settings()
  local c = type(p) == "table" and type(p.conservative) == "table" and p.conservative or {}
  local ft = vim.bo[buf].filetype
  for _, f in ipairs(c.filetypes or { "tex", "latex" }) do
    if f == ft then return true end
  end
  local size = vim.fn.getfsize(vim.api.nvim_buf_get_name(buf))
  return size > (c.size_kb or 500) * 1024
end

return M
