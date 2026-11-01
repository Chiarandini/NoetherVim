--- The picker engines and the verbs routed to them.

local h = vim.health

-- ── Pickers ──────────────────────────────────────────────────────────
local function pickers()
  h.start("Pickers")
  local pick = require("noethervim.pick")
  local engines = pick.engines()
  local engine_names = vim.tbl_keys(engines)
  table.sort(engine_names)
  h.ok("engines: " .. table.concat(engine_names, ", "))
  for _, verb in ipairs(pick.VERBS) do
    if verb ~= "resume" then
      local engine, from = pick.serving(verb)
      if engines[engine] and engines[engine][verb] then
        if engine ~= "snacks" then h.ok(("%s: %s (route: %s)"):format(verb, engine, from)) end
      elseif from == "lua/user/config.lua" then
        h.warn(("pick.route sends %s to %q, which %s; %s"):format(verb, engine,
          engines[engine] and "does not serve it" or "nothing defines",
          (engines.snacks or {})[verb] and "snacks serves it instead" or "nothing serves it"))
      end
    end
  end
end

local M = {}

function M.check()
  pickers()
end

return M
