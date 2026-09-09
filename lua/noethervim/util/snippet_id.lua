--- Names one snippet, durably enough to write the name down and use it again
--- after a restart or on another machine.
---
--- WHY A TRIGGER IS NOT A NAME
--- Triggers repeat on purpose. `iff` is two snippets in one file, one for
--- prose and one for maths, and `cc` is two more in different files. Anything
--- that acts on a single snippet therefore needs its origin as well, which is
--- what `loaders_store_source` records.
---
--- WHY PATHS ARE STORED RELATIVE TO AN OWNER
--- An absolute path names a machine, not a snippet. The same config on a
--- second machine puts every plugin somewhere else, and the dev config
--- symlinks `LuaSnip/` in from another tree entirely, so even the reader's own
--- files resolve outside `stdpath('config')`. Ownership therefore comes from
--- lazy's registry, exactly as `:LuaSnipEdit` resolves it, and the stored form
--- is an owner plus a path inside it.
---
--- WHAT CANNOT BE NAMED
--- A snippet whose source LuaSnip did not record. There is no fallback: load
--- order is not stable, so an ordinal would rebind the name to a different
--- snippet on some later start, which is worse than admitting the gap. Such a
--- snippet can still be switched off for the session, just not written down.

local M = {}

--- fs_realpath, not resolve(): it collapses symlinks *and* normalises case,
--- and lazy names a dev directory after the last segment of the repo string,
--- which may be spelled differently from the checkout on disk.
local function canonical(path)
  return path and (vim.uv.fs_realpath(path) or vim.fs.normalize(path)) or nil
end

--- Plugin roots, longest first so a checkout nested inside another root is
--- attributed to the inner one.
local function plugin_roots()
  local ok, lazy_config = pcall(require, 'lazy.core.config')
  if not ok then
    return {}
  end
  local roots = {}
  for name, plugin in pairs(lazy_config.plugins) do
    if plugin.dir then
      local dir = canonical(plugin.dir)
      if dir then
        table.insert(roots, { name = name, dir = dir })
      end
    end
  end
  table.sort(roots, function(a, b)
    return #a.dir > #b.dir
  end)
  return roots
end

--- Owner of a snippet file, and the path within it.
---
--- The reader's own files are keyed from `LuaSnip/` down rather than from
--- `stdpath('config')`, because that segment is the part that is the same on
--- every machine even when the directory above it is a symlink from elsewhere.
--- @param path string
--- @return string owner  a lazy plugin name, or 'config', or 'absolute'
--- @return string rel
function M.owner(path)
  local target = canonical(path) or path
  for _, root in ipairs(plugin_roots()) do
    if target == root.dir or vim.startswith(target, root.dir .. '/') then
      return root.name, target:sub(#root.dir + 2)
    end
  end
  local within = target:match('/(LuaSnip/.*)$')
  if within then
    return 'config', within
  end
  -- Nothing to anchor to. Still usable on this machine, and reported as
  -- unportable rather than silently written down as if it travelled.
  return 'absolute', target
end

--- @class noethervim.SnippetIdentity
--- @field ft string
--- @field trigger string
--- @field owner string
--- @field file string  path within the owner
--- @field line integer|nil

--- @param snip table
--- @param ft string
--- @return noethervim.SnippetIdentity|nil identity, string|nil reason
function M.identity(snip, ft)
  local ok, ls = pcall(require, 'luasnip')
  if not ok then
    return nil, 'luasnip is not loaded'
  end
  local src = ls.snippet_source.get(snip)
  if not src or not src.file then
    return nil, 'LuaSnip recorded no source for this snippet'
  end
  local owner, rel = M.owner(src.file)
  return {
    ft = ft,
    trigger = snip.trigger,
    owner = owner,
    file = rel,
    line = src.line,
  }
end

--- Text form, for comparing two identities in memory.
---
--- The line is included, because without it two snippets sharing a trigger in
--- one file are the same identity, and `iff` in NoetherVim-tex's acronyms.lua
--- is exactly that. It is the only part that distinguishes them.
---
--- This is deliberately not what the stored file is indexed by. A line moves
--- whenever anything is inserted above the snippet, so a key built from one
--- goes stale on an edit that changed nothing about the snippet. Records are
--- stored as a list and matched with `resolve`, which treats the line as a
--- tie-break rather than part of the match.
--- @param id noethervim.SnippetIdentity
--- @return string
function M.key(id)
  return table.concat(
    { id.ft, id.owner, id.file, id.trigger, tostring(id.line) },
    '\0'
  )
end

--- The live snippet an identity refers to.
---
--- The line is a hint, not part of the match. It moves whenever anything is
--- inserted above the snippet, and a disable that evaporated because the
--- reader added a comment would be a bug, not a feature. So the line only
--- breaks a tie between snippets that are otherwise identical, and callers are
--- expected to write back the line they resolved to.
--- @param id noethervim.SnippetIdentity
--- @param candidates table[] snippets to search, all of `id.ft`
--- @return table|nil snip, string|nil reason
function M.resolve(id, candidates)
  local same = {}
  for _, snip in ipairs(candidates) do
    if snip.trigger == id.trigger then
      local other = M.identity(snip, id.ft)
      if other and other.owner == id.owner and other.file == id.file then
        table.insert(same, { snip = snip, line = other.line })
      end
    end
  end

  if #same == 0 then
    return nil, 'no snippet with that trigger in that file'
  end
  if #same == 1 then
    return same[1].snip
  end
  for _, entry in ipairs(same) do
    if entry.line == id.line then
      return entry.snip
    end
  end
  -- Several share the trigger and none sits on the recorded line, so the file
  -- was edited enough that saying which one was meant is guesswork.
  return nil,
    ('%d snippets share this trigger in %s and none is on line %s')
      :format(#same, id.file, tostring(id.line))
end

return M
