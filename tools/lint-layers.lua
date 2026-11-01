-- tools/lint-layers.lua: lexical checks on how distro code touches the user's
-- configuration and plugin setup. Pure text, no plugins loaded.
--
--   nvim --headless -l tools/lint-layers.lua
--
-- R5   No distro module requires `user.*` except the config ingress
--      (lua/noethervim/config/init.lua) and the user-file loader in init.lua, and
--      none builds a path from stdpath("config") outside the ingress, the
--      loader and read-only tooling. Under NOETHERVIM_NO_USER nothing of the
--      user's may be read, and the ingress is what knows that.
-- SRC  The files setup() runs with :source are never required: a require
--      would run them a second time, unsigned.
-- R7   A `config` function that calls setup() passes it the spec's opts, so
--      `opts` from a user's spec reach the plugin.
-- R6   No `init` in a distro spec. It runs before NoetherVim's setup(), so
--      nothing it writes can step aside for the user; plugin globals go in
--      the NoetherVim fragment's `g`, code in its `startup`.
-- KEYS No lazy.nvim `keys` list in a distro spec. lazy maps those again each
--      time the plugin loads, over the user's own keys; distro keys are rows
--      (lua/noethervim/keymaps/rows.lua).
-- R1   The runtime (everything outside core/, bundles/ and lib/) requires
--      Neovim, other runtime modules, util/ and lazy.core.*, and no unit.
--      A plugin only where R1_PLUGINS says why; anything else reaches a
--      plugin through the unit that owns it (a row, a fragment, a seam).
-- R2   A unit (core/, bundles/ and its lib/) requires no other unit's file:
--      units cooperate through host fragments and runtime seams.
-- R3   Core names no bundle module: core works the same with none enabled.
-- R4   lib/<unit>/ is required only from that unit (core/*/<unit>.lua or
--      bundles/*/<unit>.lua, underscores for hyphens) and lib/<unit>/ itself.
-- R10  Unit names (file names under core/ and bundles/) are unique across
--      both trees: a user's lua/user/plugins/<name>.lua names one unit.
-- TEX  No code outside the latex bundle (bundles/languages/latex.lua and
--      lib/latex/) names VimTeX: the flagship reaches core only through the
--      contracts every bundle has (rows, segments, `g`, fragments), so it
--      proves them. Comments may describe the interplay.
--
-- Prints file:line: rule: message for each hit and exits non-zero on any.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local lua_dir = root .. "/lua/noethervim"

local SOURCED = {
  "options", "keymaps", "autocmds", "theme.highlights", "commands",
  "toggles.options", "default.broker", "keymaps.apply", "profiles.apply",
}

-- Modules allowed to read the user's tree: the ingress, the loader, and
-- tooling that only reads it on an explicit command.
local USER_TREE_OK = {
  ["config/init.lua"] = true,
  ["init.lua"] = true,
  ["guide.lua"] = true,
  ["catalog/toggle.lua"] = true,
  -- the SearchLeader+c pickers, which open the config directory on request
  ["core/foundation/snacks.lua"] = true,
}

-- Plugins the runtime may require, by file or directory (`*`: any), and why.
local R1_PLUGINS = {
  -- Read-only tooling: the :NoetherVim pickers are snacks pickers, and health
  -- probes what is installed.
  ["inspect/"] = "*",
  ["health/"] = "*",
  -- The picker seam's snacks engine.
  ["pick/snacks_engine.lua"] = { snacks = true },
  -- Foundation snacks: the notifier <Esc> hides, the dashboard :CloseAll opens.
  ["keymaps.lua"] = { snacks = true },
  ["commands.lua"] = { snacks = true },
  -- The snippet store and engine helpers drive LuaSnip, the snippet engine.
  ["snippets/"] = { luasnip = true },
  -- The shipped colorscheme's palette, which the statusline is tuned against.
  ["theme/palette.lua"] = { gruvbox = true },
  -- The contributor helper that installs a bundle's tools through Mason.
  ["util/mason_install.lua"] = { ["mason-registry"] = true },
}

---@param rel string
---@param mod string
local function plugin_ok(rel, mod)
  for key, allowed in pairs(R1_PLUGINS) do
    if rel == key or (key:sub(-1) == "/" and vim.startswith(rel, key)) then
      if allowed == "*" or allowed[mod] or allowed[mod:match("^[^.]+")] then return true end
    end
  end
  return false
end

---@param rel string
---@return "core"|"bundle"|"lib"|"runtime"
local function layer(rel)
  if vim.startswith(rel, "core/") then return "core" end
  if vim.startswith(rel, "bundles/") then return "bundle" end
  if vim.startswith(rel, "lib/") then return "lib" end
  return "runtime"
end

--- The modules a line requires: require("x") and pcall(require, "x").
---@param code string
---@return string[]
local function required(code)
  local mods = {}
  for m in code:gmatch("require%s*%(?%s*[\"']([^\"']+)[\"']") do table.insert(mods, m) end
  for m in code:gmatch("pcall%s*%(%s*require%s*,%s*[\"']([^\"']+)[\"']") do table.insert(mods, m) end
  return mods
end

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
  local tree_ok = USER_TREE_OK[rel] or vim.startswith(rel, "inspect/") or vim.startswith(rel, "health/")
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

    local spec_file = vim.startswith(rel, "core/") or vim.startswith(rel, "bundles/")

    -- R6: a spec init. Heirline components take `self`; a spec's init
    -- takes the plugin, which distro specs never use.
    if spec_file and code:find("^%s*init%s*=%s*function%s*%(%s*%)") then
      hit(rel, i, "R6", "spec init runs before setup(); use the NoetherVim fragment's `g` or `startup`")
    end

    -- KEYS: `keys = {` opening a list of key specs, `{ "lhs", ... }`
    if spec_file and code:find("keys%s*=%s*{") then
      local nxt = (lines[i + 1] or ""):gsub("%-%-.*$", "")
      if code:find("keys%s*=%s*{%s*{%s*[\"']") or (code:find("keys%s*=%s*{%s*$") and nxt:find("^%s*{%s*[\"']")) then
        hit(rel, i, "KEYS", "lazy keys are mapped again on every load; declare rows (keymaps/rows.lua)")
      end
    end

    -- R1-R4
    local where = layer(rel)
    local unit = rel:match("([^/]+)%.lua$"):gsub("-", "_")
    for _, mod in ipairs(required(code)) do
      local sub = mod:match("^noethervim%.(.+)$")
      local is_unit = sub and (vim.startswith(sub, "core.") or vim.startswith(sub, "bundles."))
      local lib_owner = sub and sub:match("^lib%.([^.]+)")
      if where == "runtime" then
        if is_unit or lib_owner then
          hit(rel, i, "R1", mod .. ": the runtime requires no unit")
        elseif not sub and mod ~= "noethervim" and not vim.startswith(mod, "lazy.core.")
          and not vim.startswith(mod, "vim.") and not vim.startswith(mod, "user.")
          and not plugin_ok(rel, mod) then
          hit(rel, i, "R1", mod .. ": the runtime reaches plugins through their units (or R1_PLUGINS, with a reason)")
        end
      elseif is_unit then
        hit(rel, i, "R2", mod .. ": units cooperate through host fragments and seams, not each other's files")
      end
      if where == "core" and sub and vim.startswith(sub, "bundles.") then
        hit(rel, i, "R3", mod .. ": core works the same with no bundle enabled")
      end
      if lib_owner and not vim.startswith(rel, "lib/" .. lib_owner .. "/")
        and not ((where == "core" or where == "bundle") and unit == lib_owner) then
        hit(rel, i, "R4", mod .. ": lib/" .. lib_owner .. "/ belongs to the " .. lib_owner .. " unit")
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

-- R10
local units = {}
for _, rel in ipairs(files()) do
  local where = layer(rel)
  if where == "core" or where == "bundle" then
    local name = rel:match("([^/]+)%.lua$")
    if units[name] then
      table.insert(hits, ("lua/noethervim/%s: R10: unit name %s is taken by %s"):format(rel, name, units[name]))
    end
    units[name] = rel
  end
end

-- TEX, over the rest of the runtime files the repo ships too.
local function latex_owned(rel)
  return rel == "lua/noethervim/bundles/languages/latex.lua" or vim.startswith(rel, "lua/noethervim/lib/latex/")
end
for _, top in ipairs({ "lua/noethervim", "ftplugin", "after", "plugin" }) do
  for name, kind in vim.fs.dir(root .. "/" .. top, { depth = 10 }) do
    local rel = top .. "/" .. name
    if kind == "file" and name:sub(-4) == ".lua" and not latex_owned(rel) then
      for i, line in ipairs(vim.fn.readfile(root .. "/" .. rel)) do
        if line:gsub("%-%-.*$", ""):lower():find("vimtex", 1, true) then
          table.insert(hits, ("%s:%d: TEX: names VimTeX outside the latex bundle; reach it through a contract"):format(rel, i))
        end
      end
    end
  end
end

for _, h in ipairs(hits) do print(h) end
if #hits > 0 then
  print(("lint-layers: %d problem(s)"):format(#hits))
  os.exit(1)
end
print("lint-layers: ok")
