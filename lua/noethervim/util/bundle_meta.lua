--- Bundle metadata parsed from annotation headers.
---
--- Each bundle file opens with a LuaCATS-style block that declares what the
--- bundle is and what it needs from outside Neovim:
--- >lua
---     ---@bundle octo
---     ---@desc GitHub PRs, issues and reviews
---     ---@about Brings GitHub review workflow into the editor: PR lists,
---     ---       inline review comments, issues and gists.
---     ---@requires exe=gh label="GitHub CLI" why="every octo command"
---                  install="https://cli.github.com, then `gh auth login`"
--- <
--- The annotation is the single source of truth. `:checkhealth noethervim`
--- probes it, `:NoetherVim bundles` shows the description, and the docs site
--- renders both. Nothing restates it.
---
--- WHY IN THE FILE, NOT A CENTRAL TABLE
--- `:NoetherVim bundles` previews the bundle source in the picker and opens
--- it on <CR>, so the file header is what a user actually reads when deciding
--- whether to enable something. A requirement recorded anywhere else is a
--- requirement they will not see at the moment they need it.
---
--- WHY PARSED, NOT GENERATED
--- Parsing keeps one authored copy and no build step in the runtime path.
--- `:checkhealth` is manual and infrequent, and only reads the handful of
--- active bundles, so the cost is a few file reads. A malformed annotation
--- surfaces as a health error naming the file and line, rather than rotting
--- silently the way the old prose lists did.

local M = {}

--- Number of header lines scanned for the annotation block. The block sits
--- at the very top of every bundle; reading further just wastes IO.
local MAX_HEADER_LINES = 60

---@class noethervim.BundleRequirement
---@field kind "exe"|"env"|"app"|"note"  how to verify it
---@field value string            executable, env var, application name, or prose
---@field label string            human name, shown in health output and docs
---@field why? string             what stops working without it
---@field install? string         how to get it
---@field optional? boolean       degrades gracefully rather than breaking
---
--- `note` covers requirements that cannot be probed from Neovim: a shared
--- library a plugin links against, "the REPL binary for your language", a
--- vault path. Health reports them as info rather than pass/fail. They are
--- declared here anyway because the alternative is what the old prose lists
--- did, which is lose them.

---@class noethervim.BundleMeta
---@field name string
---@field category string
---@field path string
---@field desc? string   one line for the bundles picker
---@field about? string  prose for the docs site; falls back to `desc`
---@field declared_name? string  the `@bundle` value, checked against the filename
---@field requires noethervim.BundleRequirement[]
---@field errors string[]  malformed annotation lines, reported by health

--- Split `key=value key="quoted value"` into a table.
--- Values may be bare (no spaces) or double-quoted; quoted values may
--- contain spaces, commas, backticks and URLs, which install hints need.
---@param s string
---@return table<string, string>
local function parse_fields(s)
  local out = {}
  -- Quoted first, so a quoted value containing '=' or spaces is taken whole
  -- before the bare-word pattern can bite off part of it.
  for k, v in s:gmatch('([%w_]+)="([^"]*)"') do out[k] = v end
  local stripped = s:gsub('[%w_]+="[^"]*"', '')
  for k, v in stripped:gmatch('([%w_]+)=([^%s]+)') do out[k] = v end
  return out
end

---@param line string
---@param lnum integer
---@param acc noethervim.BundleMeta
local function parse_requires(line, lnum, acc)
  if line:match('^%s*none%s*$') then return end

  local f = parse_fields(line)
  local kind, value
  for _, k in ipairs({ 'exe', 'env', 'app', 'note' }) do
    if f[k] then
      kind, value = k, f[k]
      break
    end
  end

  if not kind then
    acc.errors[#acc.errors + 1] =
      ('%s:%d: @requires needs one of exe=, env=, app=, note=, or the literal `none`'):format(acc.path, lnum)
    return
  end

  acc.requires[#acc.requires + 1] = {
    kind = kind,
    value = value,
    label = f.label or value,
    why = f.why,
    install = f.install,
    optional = f.optional == 'true',
  }
end

--- Read and parse one bundle file's annotation header.
---@param path string
---@param name string
---@param category string
---@return noethervim.BundleMeta
function M.parse(path, name, category)
  ---@type noethervim.BundleMeta
  local acc = { name = name, category = category, path = path, requires = {}, errors = {} }

  local ok, lines = pcall(vim.fn.readfile, path, '', MAX_HEADER_LINES)
  if not ok or type(lines) ~= 'table' then
    acc.errors[#acc.errors + 1] = ('%s: unreadable'):format(path)
    return acc
  end

  local declared = false
  -- `@about` and `@requires` values are long enough to wrap; a continuation
  -- is any following `---` line that does not open a new tag.
  local pending = nil ---@type {tag: string, text: string, lnum: integer}?

  local function flush()
    if not pending then return end
    if pending.tag == 'requires' then
      parse_requires(pending.text, pending.lnum, acc)
    elseif pending.tag == 'desc' then
      acc.desc = vim.trim(pending.text)
    elseif pending.tag == 'about' then
      acc.about = vim.trim(pending.text)
    end
    pending = nil
  end

  for lnum, line in ipairs(lines) do
    local body = line:match('^%-%-%-(.*)$')
    if not body then
      if declared then break end -- header block ended
    else
      local tag, rest = body:match('^%s*@(%w[%w_-]*)%s*(.*)$')
      if tag == 'bundle' then
        flush()
        declared = true
        acc.declared_name = vim.trim(rest)
      elseif tag == 'desc' or tag == 'about' or tag == 'requires' then
        flush()
        pending = { tag = tag, text = rest, lnum = lnum }
      elseif tag then
        flush()
      elseif pending then
        pending.text = pending.text .. ' ' .. vim.trim(body)
      end
    end
  end
  flush()

  if not declared then
    acc.errors[#acc.errors + 1] = ('%s: no @bundle annotation'):format(path)
  elseif acc.declared_name ~= name then
    acc.errors[#acc.errors + 1] =
      ('%s: @bundle is "%s" but the file is %s.lua'):format(path, acc.declared_name or '', name)
  end

  return acc
end

--- Parse every bundle under `bundles_dir`, sorted by category then name.
---@param bundles_dir string
---@return noethervim.BundleMeta[]
function M.scan(bundles_dir)
  local out = {}
  for _, entry in ipairs(require('noethervim.util').scan_bundles(bundles_dir)) do
    out[#out + 1] = M.parse(entry.path, entry.name, entry.category)
  end
  return out
end

--- Parse a single bundle by its `<category>.<name>` key, as used by
--- lazy.nvim import paths and `:checkhealth`.
---@param bundles_dir string
---@param key string
---@return noethervim.BundleMeta?
function M.get(bundles_dir, key)
  local category, name = key:match('^([^.]+)%.(.+)$')
  if not category then return nil end
  local path = vim.fs.joinpath(bundles_dir, category, name .. '.lua')
  if vim.uv.fs_stat(path) == nil then return nil end
  return M.parse(path, name, category)
end

return M
