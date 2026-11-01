--- The statusline settings and which segments show.

local h = vim.health

-- ── Statusline ───────────────────────────────────────────────────────
local function statusline()
  h.start("Statusline")
  local sl = require("noethervim.statusline")
  local heirline = require("lazy.core.config").plugins["heirline.nvim"]
  if not heirline then
    h.info("heirline is off: segments still answer noethervim.statusline.text(id) for "
      .. "another statusline; `style` settings do nothing")
  end
  local known = {}
  for _, side in pairs(sl.CORE) do for _, id in ipairs(side) do known[id] = true end end
  for _, id in ipairs(sl.ids()) do known[id] = true end
  local shown, hidden = {}, {}
  for _, id in ipairs(sl.ids()) do
    table.insert(sl.shown(id) and shown or hidden, id)
    local after = (sl.segment(id) or {}).place and sl.segment(id).place.after
    if after and not known[after] then
      h.info(("segment %q is placed after %q, which nothing declares; it shows at the start of its side")
        :format(id, after))
    end
  end
  if #shown + #hidden > 0 then
    h.ok("segments: " .. (#shown > 0 and table.concat(shown, ", ") or "none shown")
      .. (#hidden > 0 and ("; hidden until toggled: " .. table.concat(hidden, ", ")) or ""))
  end
  for id in pairs((require("noethervim.config").get().statusline or {}).layout or {}) do
    if not known[id] and id ~= "directory" and id ~= "proj_relative_dir" then
      h.warn(("statusline.layout names %q, which is neither a core block nor a segment"):format(id),
        { "Core blocks: " .. table.concat(vim.list_extend(vim.list_extend({}, sl.CORE.left), sl.CORE.right), ", ") })
    end
  end
  for id, err in pairs(sl.errors) do
    h.warn(("segment %q raised an error and is off until restart: %s"):format(id, err))
  end
end

local M = {}

function M.check()
  statusline()
end

return M
