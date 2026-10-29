-- tools/lint-layers.lua: lexical checks on how distro code touches the user's
-- configuration and plugin setup. Pure text, no plugins loaded.
--
--   nvim --headless -l tools/lint-layers.lua
--
-- R5   No distro module requires `user.*` except the config ingress
--      (lua/noethervim/config.lua) and the user-file loader in init.lua, and
--      none builds a path from stdpath("config") outside the ingress, the
--      loader and read-only tooling. Under NOETHERVIM_NO_USER nothing of the
--      user's may be read, and the ingress is what knows that.
-- SRC  The files setup() runs with :source are never required: a require
--      would run them a second time, unsigned.
-- R7   A `config` function that calls setup() passes it the spec's opts, so
--      `opts` from a user's spec reach the plugin.
-- KEYS No lazy.nvim `keys` list in a distro spec. lazy maps those again each
--      time the plugin loads, over the user's own keys; distro keys are rows
--      (lua/noethervim/keymaps/rows.lua).
--
-- Prints file:line: rule: message for each hit and exits non-zero on any.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local lua_dir = root .. "/lua/noethervim"

local SOURCED = {
  "options", "keymaps", "autocmds", "highlights", "commands",
  "toggles.options", "default.broker", "keymaps.apply",
}

-- Modules allowed to read the user's tree: the ingress, the loader, and
-- tooling that only reads it on an explicit command.
local USER_TREE_OK = {
  ["config.lua"] = true,
  ["init.lua"] = true,
  ["health.lua"] = true,
  ["inspect.lua"] = true,
  ["guide.lua"] = true,
  ["util/templates.lua"] = true,
  ["util/bundle_toggle.lua"] = true,
  ["util/keymap_source.lua"] = true,
  ["util/init.lua"] = true,
  -- the SearchLeader+c pickers, which open the config directory on request
  ["plugins/snacks.lua"] = true,
}

local hits = {}
local function hit(rel, lnum, rule, msg)
  table.insert(hits, ("lua/noethervim/%s:%d: %s: %s"):format(rel, lnum, rule, msg))
end

local function files()
  local out = {}
  for name, kind in vim.fs.dir(lua_dir, { depth = 10 }) do
    if kind == "file" and name:sub(-4) == ".lua" then table.insert(out, name) end
  end
  table.sort(out)
  return out
end

for _, rel in ipairs(files()) do
  local lines = vim.fn.readfile(lua_dir .. "/" .. rel)
  local tree_ok = USER_TREE_OK[rel] or vim.startswith(rel, "inspect/")
  for i, line in ipairs(lines) do
    local code = line:gsub("%-%-.*$", "")
    if code:find("^%s*$") then goto continue end

    -- R5
    if not tree_ok then
      if code:find("require%s*%(?%s*[\"']user%.") or code:find("[\"']user%.[\"']%s*%.%.") then
        hit(rel, i, "R5", "reads a user module; go through require(\"noethervim.config\")")
      end
      if code:find("stdpath%(%s*[\"']config[\"']%s*%)") then
        hit(rel, i, "R5", "builds a path into the user's config; use require(\"noethervim.config\").user_dir()")
      end
    end

    -- SRC
    for _, mod in ipairs(SOURCED) do
      if code:find("require%s*%(?%s*[\"']noethervim%." .. vim.pesc(mod) .. "[\"']") then
        hit(rel, i, "SRC", "noethervim." .. mod .. " is sourced by setup(), never required")
      end
    end

    local spec_file = vim.startswith(rel, "plugins/") or vim.startswith(rel, "bundles/")

    -- KEYS: `keys = {` opening a list of key specs, `{ "lhs", ... }`
    if spec_file and code:find("keys%s*=%s*{") then
      local nxt = (lines[i + 1] or ""):gsub("%-%-.*$", "")
      if code:find("keys%s*=%s*{%s*{%s*[\"']") or (code:find("keys%s*=%s*{%s*$") and nxt:find("^%s*{%s*[\"']")) then
        hit(rel, i, "KEYS", "lazy keys are mapped again on every load; declare rows (keymaps/rows.lua)")
      end
    end

    -- R7: a parameterless config whose next lines call setup()
    if code:find("config%s*=%s*function%s*%(%s*%)") then
      for j = i + 1, math.min(i + 3, #lines) do
        if lines[j]:find("[%.:]setup%s*%(") then
          hit(rel, i, "R7", "config calls setup() without the spec's opts: use function(_, opts)")
          break
        end
      end
    end

    ::continue::
  end
end

for _, h in ipairs(hits) do print(h) end
if #hits > 0 then
  print(("lint-layers: %d problem(s)"):format(#hits))
  os.exit(1)
end
print("lint-layers: ok")
