--- Records what each user override was written against, and reports the ones
--- whose upstream file has since changed.
---
--- An override in `lua/user/` shadows a distribution file. When that file
--- later changes, the override keeps winning and there is nothing to notice:
--- a fix lands upstream, the user never sees it, and the bug they report does
--- not reproduce anywhere else.
---
--- WHERE THE RECORD LIVES
--- In `stdpath('state')/noethervim/override-base.json`, not in the override
--- itself. Files under `lua/user/` belong to the user; writing a marker
--- comment into one would make a machine-readable format part of a file they
--- are free to rewrite, reformat or strip comments from, and would quietly
--- stop working when they did. State that NoetherVim owns belongs in the
--- state directory, alongside the VimTeX baseline that already lives there.
---
--- The trade is that the record is per-machine: a config synced to a second
--- machine arrives with no baselines, so nothing is reported there until an
--- override is created or re-baselined on it. That fails silent rather than
--- wrong, which is the right direction for a check nobody asked for.
---
--- WHY A CONTENT HASH, NOT A GIT REVISION
--- The distribution is installed by lazy.nvim as a git clone, but it also
--- runs straight from a working tree in dev mode, and it can be edited in
--- place. A hash of the bytes is true in all three cases and needs no git.
---
--- WHAT IT DOES NOT CLAIM
--- The hash covers the whole file, so a reflowed comment marks an override
--- stale. That is the intended trade: a false "look at this" costs one
--- `:NoetherVim diff`, a missed one costs a debugging session.

local M = {}

--- Length of the retained hash prefix. 12 hex characters is the same order
--- as a short git SHA and keeps the file readable.
local HASH_LEN = 12

local function store_path()
  return vim.fs.joinpath(vim.fn.stdpath('state'), 'noethervim', 'override-base.json')
end

---@param path string
---@return string? content
local function read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= 'table' then return nil end
  return table.concat(lines, '\n')
end

--- Hash a distribution file's current contents.
---@param path string  absolute path
---@return string? truncated sha256, or nil if unreadable
function M.hash(path)
  local content = read(path)
  if not content then return nil end
  return vim.fn.sha256(content):sub(1, HASH_LEN)
end

--- Every recorded baseline, keyed by absolute override path.
---@return table<string, { rel: string, hash: string }>
function M.load()
  local content = read(store_path())
  if not content or content == '' then return {} end
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= 'table' then return {} end
  return decoded
end

---@param records table<string, { rel: string, hash: string }>
local function save(records)
  local path = store_path()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
  -- An empty Lua table encodes as `[]`, which reads back as a list. Writing
  -- an explicit empty object keeps the file's shape stable once the last
  -- record is pruned.
  local payload = next(records) and records or vim.empty_dict()
  vim.fn.writefile(vim.split(vim.json.encode(payload), '\n'), path)
end

--- Record that `user_path` was written against the current contents of the
--- distribution file at `rel`.
---@param user_path string  absolute path to the override
---@param rel string        upstream path, relative to the distribution root
---@param upstream string   absolute path to the upstream file
---@return string? the hash recorded, or nil if upstream was unreadable
function M.record(user_path, rel, upstream)
  local hash = M.hash(upstream)
  if not hash then return nil end
  local records = M.load()
  records[vim.fs.normalize(user_path)] = { rel = rel, hash = hash }
  save(records)
  return hash
end

---@class noethervim.OverrideDrift
---@field user_path string  absolute path to the override
---@field rel string        upstream path, relative to the distribution root
---@field recorded string   hash recorded when the override was created
---@field current string? hash of the upstream file now, nil if it is gone

--- Every recorded override whose upstream file has changed or disappeared.
---
--- Records whose override no longer exists are pruned as a side effect, so
--- deleting a user file is enough to stop hearing about it.
---@param root string  distribution root
---@return noethervim.OverrideDrift[]
function M.scan(root)
  local records = M.load()
  local out, pruned = {}, false

  for user_path, rec in pairs(records) do
    if vim.uv.fs_stat(user_path) == nil then
      records[user_path] = nil
      pruned = true
    else
      local current = M.hash(vim.fs.joinpath(root, rec.rel))
      if current ~= rec.hash then
        out[#out + 1] = {
          user_path = user_path,
          rel = rec.rel,
          recorded = rec.hash,
          current = current,
        }
      end
    end
  end

  if pruned then save(records) end
  table.sort(out, function(a, b) return a.rel < b.rel end)
  return out
end

return M
