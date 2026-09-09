--- Remembers which snippets are switched off, and puts that back into effect.
---
--- TWO LISTS, TWO DIFFERENT ANSWERS
--- `snippets_disabled` in `user/config.lua` answers "I never want this". It is
--- written by hand, travels with the config, and is never rewritten from here:
--- files under `lua/user/` belong to the reader.
---
--- The toggle file under `stdpath('state')` answers "not right now". It is
--- machine-owned, so this module writes it freely, and a config copied to
--- another machine arrives without it. That is the intended direction: a
--- missing toggle file means nothing is switched off, which fails silent
--- rather than wrong.
---
--- When the two disagree the toggle wins, being the later and more specific
--- act, and `:checkhealth` reports the disagreement rather than hiding it.
---
--- WHY THE FILE HOLDS A LIST AND NOT A MAP
--- The only thing separating two snippets that share a trigger in one file is
--- the line they start on, and a line moves whenever anything is inserted
--- above it. A map keyed on the line would therefore lose entries on edits
--- that changed nothing about the snippet. Records are matched by
--- `snippet_id.resolve`, which treats the line as a tie-break, and the line is
--- written back whenever a record resolves so it stays current.

local M = {}

local id_mod = require('noethervim.util.snippet_id')
local engine = require('noethervim.util.snippets')

local function toggle_path()
  return vim.fs.joinpath(
    vim.fn.stdpath('state'),
    'noethervim',
    'snippet-toggles.json'
  )
end

--- @return table[] records each an identity plus a `state` field
local function read_toggles()
  local path = toggle_path()
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local ok, decoded = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
  end)
  if not ok or type(decoded) ~= 'table' then
    vim.notify(
      'noethervim: could not read ' .. path .. ', ignoring it',
      vim.log.levels.WARN
    )
    return {}
  end
  return decoded
end

--- @param records table[]
local function write_toggles(records)
  local path = toggle_path()
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  vim.fn.writefile(vim.split(vim.json.encode(records), '\n'), path)
end

--- The reader's durable list, straight from their config.
--- @return table[]
local function read_blocklist()
  local ok, user_cfg = pcall(require, 'user.config')
  if not ok or type(user_cfg) ~= 'table' then
    return {}
  end
  local list = user_cfg.snippets_disabled
  return type(list) == 'table' and list or {}
end

local function same_snippet(a, b)
  return a.ft == b.ft
    and a.trigger == b.trigger
    and a.owner == b.owner
    and a.file == b.file
end

--- Every record that should be acted on, with the toggle file taking
--- precedence over the blocklist for any snippet named by both.
--- @return table[] records every identity to act on, with `state` set
--- @return table[] disagreements where the toggle file contradicts the config
function M.records()
  local toggles = read_toggles()
  local records, disagreements = {}, {}

  for _, rec in ipairs(toggles) do
    table.insert(
      records,
      vim.tbl_extend('force', rec, { state = rec.state or 'off', source = 'toggle' })
    )
  end

  for _, blocked in ipairs(read_blocklist()) do
    local overridden
    for _, rec in ipairs(records) do
      if same_snippet(rec, blocked) then
        overridden = rec
        break
      end
    end
    if overridden then
      if overridden.state ~= 'off' then
        table.insert(disagreements, { blocked = blocked, toggle = overridden })
      end
    else
      table.insert(
        records,
        vim.tbl_extend('force', blocked, { state = 'off', source = 'config' })
      )
    end
  end

  return records, disagreements
end

--- Snippets of a filetype, both kinds, since a record does not say which it is.
local function pool(ft)
  local ls = require('luasnip')
  local snips = vim.list_extend({}, ls.get_snippets(ft) or {})
  vim.list_extend(snips, ls.get_snippets(ft, { type = 'autosnippets' }) or {})
  return snips
end

--- Put the remembered state back into effect.
---
--- Safe to call repeatedly: it compares against what each snippet is already
--- doing and only acts on a difference, so re-running after a snippet file
--- reloads costs nothing when nothing changed.
--- @return table[] unresolved records naming no live snippet; each has a reason
function M.apply()
  local records = M.records()
  local unresolved, touched, moved = {}, {}, false

  for _, rec in ipairs(records) do
    local snip, why = id_mod.resolve(rec, pool(rec.ft))
    if not snip then
      table.insert(unresolved, { record = rec, reason = why })
    else
      local current = engine.state(snip)
      if rec.state == 'off' and current == 'on' then
        engine.disable(snip, rec.ft, { refresh = false })
        touched[rec.ft] = true
      elseif rec.state == 'on' and current == 'off' then
        engine.enable(snip, rec.ft, { refresh = false })
        touched[rec.ft] = true
      end
      local fresh = id_mod.identity(snip, rec.ft)
      if fresh and fresh.line ~= rec.line then
        rec.line = fresh.line
        moved = true
      end
    end
  end

  -- One notification per filetype rather than one per snippet: the event is
  -- broadcast, and blink throws away its whole cache on each.
  local ls = require('luasnip')
  for ft in pairs(touched) do
    ls.refresh_notify(ft)
  end

  if moved then
    M.rewrite_lines(records)
  end
  return unresolved
end

--- Persist refreshed line hints for records that came from the toggle file.
--- Blocklist records live in the reader's config and are left alone.
--- @param records table[]
function M.rewrite_lines(records)
  local toggles = read_toggles()
  local changed = false
  for _, saved in ipairs(toggles) do
    for _, rec in ipairs(records) do
      if same_snippet(saved, rec) and saved.line ~= rec.line then
        saved.line = rec.line
        changed = true
      end
    end
  end
  if changed then
    write_toggles(toggles)
  end
end

--- Switch a snippet off or on for this machine, and remember it.
--- @param snip table
--- @param ft string
--- @param want 'on'|'off'
--- @return boolean ok, string|nil reason
function M.set(snip, ft, want)
  local idty, why = id_mod.identity(snip, ft)
  if want == 'off' then
    engine.disable(snip, ft)
  else
    engine.enable(snip, ft)
  end
  if not idty then
    -- Took effect, but there is no durable name to write down; charter point
    -- 10 refuses to invent one.
    return false, why
  end

  local blocked = false
  for _, entry in ipairs(read_blocklist()) do
    if same_snippet(entry, idty) then
      blocked = true
      break
    end
  end

  local toggles = read_toggles()
  for i = #toggles, 1, -1 do
    if same_snippet(toggles[i], idty) then
      table.remove(toggles, i)
    end
  end

  -- The file holds only what departs from the blocklist, so switching a
  -- snippet back to what the config already said removes the record instead
  -- of writing a redundant one. Switching one *off* that the config blocks
  -- writes nothing; switching one *on* that it blocks is the override the
  -- charter says wins, and that does need a record.
  if (want == 'off') ~= blocked then
    table.insert(toggles, vim.tbl_extend('force', idty, { state = want }))
  end
  write_toggles(toggles)
  return true
end

--- @return string path of the machine-owned toggle file
function M.path()
  return toggle_path()
end

--- What the two lists currently amount to, changing nothing.
---
--- Separate from `apply` on purpose: `:checkhealth` must be able to say what
--- is switched off without switching anything off as a side effect of being
--- asked.
--- @return table report counts, disagreements and records naming no snippet
function M.audit()
  local records, disagreements = M.records()
  local report = {
    off_config = 0,
    off_toggle = 0,
    on_override = 0,
    unresolved = {},
    disagreements = disagreements,
    path = toggle_path(),
  }
  local pools = {}
  for _, rec in ipairs(records) do
    pools[rec.ft] = pools[rec.ft] or pool(rec.ft)
    local snip, why = id_mod.resolve(rec, pools[rec.ft])
    if not snip then
      table.insert(report.unresolved, { record = rec, reason = why })
    elseif rec.state == 'off' then
      if rec.source == 'config' then
        report.off_config = report.off_config + 1
      else
        report.off_toggle = report.off_toggle + 1
      end
    else
      report.on_override = report.on_override + 1
    end
  end
  return report
end

--- Re-apply after every load, so a disable outlives the file being saved.
---
--- LuaSnip re-runs a snippet file when it is written and builds fresh snippet
--- objects, which carry none of the fields this module sets. Without this the
--- disable would appear to work until the first edit and then quietly stop.
---
--- TWO FLAGS, NOT ONE
--- `applying` drops the events `apply` itself causes: it calls
--- `refresh_notify`, which fires the very event being handled. `scheduled`
--- collapses a burst into one pass, because startup fires the event once per
--- filetype and each pass would otherwise walk every record again.
---
--- The known gap: a genuine load landing in the same tick as our own refresh
--- is dropped with it. The next load re-applies, and `apply` acts only on
--- differences, so the cost of that is one pass, not a wrong state.
function M.install()
  local applying, scheduled = false, false
  vim.api.nvim_create_autocmd('User', {
    pattern = 'LuasnipSnippetsAdded',
    group = vim.api.nvim_create_augroup('NoetherVimSnippetState', { clear = true }),
    desc = 'noethervim: re-apply switched-off snippets after a snippet load',
    callback = function()
      if applying or scheduled then
        return
      end
      scheduled = true
      vim.schedule(function()
        scheduled = false
        applying = true
        local ok, err = pcall(M.apply)
        applying = false
        if not ok then
          vim.notify(
            'noethervim: could not re-apply snippet state: ' .. tostring(err),
            vim.log.levels.WARN
          )
        end
      end)
    end,
  })
end

return M
