-- tools/check-surface.lua: what a config calls in NoetherVim outside the
-- names `:help noethervim-api` declares. Pure text, no plugins loaded.
--
--   nvim -l tools/check-surface.lua [config dir]   (default ~/.config/nvim)
--
-- The allowed names are read from that help section itself, so the table a
-- reader sees and the one checked here are one list. A name is allowed when
-- the table lists its module bare (`require("noethervim.run")`), or lists
-- the field used (`require("noethervim.theme").tweak(groups)`). Fields are
-- found where the require is indexed directly, and through a local the
-- module is assigned to (`local theme = require(...)`, then `theme.tweak`).
-- Any field starting with `_` is private whatever the table says.
--
-- Prints file:line: name for each use outside the table and exits non-zero
-- on any. Run it on the maintainer's config before each tag.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local dir = vim.fs.normalize(arg[1] or (vim.env.HOME .. "/.config/nvim"))

--- module -> { whole = true } or { fields = { [name] = true } }
local allowed = {}
do
  local doc = vim.fn.readfile(root .. "/doc/noethervim.txt")
  local inside = false
  for _, line in ipairs(doc) do
    if line:find("*noethervim-api*", 1, true) then
      inside = true
    elseif inside and line:find("^=====") or (inside and line:find("^%-%-%-%-%-")) then
      break
    elseif inside then
      for mod, rest in line:gmatch('require%("(noethervim[%w_.]*)"%)([%.:]?[%w_]*)') do
        allowed[mod] = allowed[mod] or { fields = {} }
        local field = rest:match("^[%.:]([%w_]+)")
        if field then allowed[mod].fields[field] = true else allowed[mod].whole = true end
      end
    end
  end
  assert(next(allowed), "no require() lines found under *noethervim-api* in doc/noethervim.txt")
end

local function ok(mod, field)
  if field and field:sub(1, 1) == "_" then return false end
  local a = allowed[mod]
  if not a then return false end
  return a.whole or field == nil or a.fields[field] == true
end

local MOD = "[\"'](noethervim[%w_.]*)[\"']"
local hits, seen = {}, {}

local function check_file(path)
  local lines = vim.fn.readfile(path)
  local aliases = {} ---@type table<string, string> local name -> module
  local function report(lnum, mod, field)
    local hit = ("%s:%d: %s%s"):format(vim.fn.fnamemodify(path, ":~"), lnum, mod, field and ("." .. field) or "")
    if not ok(mod, field) and not seen[hit] then
      seen[hit] = true
      table.insert(hits, hit)
    end
  end
  for lnum, line in ipairs(lines) do
    local code = line:gsub("%-%-.*$", "")
    -- `noethervim-tex` and the like are other plugins: the module must be
    -- `noethervim` itself or a `noethervim.` path.
    for mod, after in code:gmatch("require%s*%(?%s*" .. MOD .. "%s*%)?()") do
      local field = code:sub(after):match("^[%.:]([%w_]+)")
      local alias = code:match("local%s+([%w_]+)%s*=%s*require%s*%(?%s*[\"']" .. vim.pesc(mod) .. "[\"']%s*%)?%s*$")
      if alias then aliases[alias] = mod elseif not field then report(lnum, mod, nil) end
      if field then report(lnum, mod, field) end
    end
    for alias, mod in code:gmatch("local%s+[%w_]+%s*,%s*([%w_]+)%s*=%s*pcall%(%s*require%s*,%s*" .. MOD .. "%s*%)") do
      aliases[alias] = mod
    end
    for alias, mod in pairs(aliases) do
      for field in code:gmatch("%f[%w_]" .. alias .. "[%.:]([%w_]+)") do
        report(lnum, mod, field)
      end
    end
  end
end

local files = vim.fs.find(function(name) return name:match("%.lua$") end,
  { path = dir, type = "file", limit = math.huge })
table.sort(files)
for _, path in ipairs(files) do check_file(path) end

for _, h in ipairs(hits) do print(h) end
if #hits > 0 then
  print(("check-surface: %d use(s) outside :help noethervim-api"):format(#hits))
  os.exit(1)
end
print(("check-surface: ok (%d files)"):format(#files))
