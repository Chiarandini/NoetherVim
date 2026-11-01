--- LuaSnip: what is loaded, from where, and what is switched off.

local h = vim.health

--- The key that opens the snippet files, read from the live keymap table
--- rather than written out, so a rebind is reflected. Returned in press-it
--- form (`<Space>es`); nil when nothing is bound to it.
local function edit_snippets_key()
  local best
  for _, km in ipairs(vim.api.nvim_get_keymap("n")) do
    if (km.rhs or ""):find("LuaSnipEdit", 1, true) then
      if not best or #km.lhs < #best then best = km.lhs end
    end
  end
  return best and vim.fn.keytrans(
    vim.api.nvim_replace_termcodes(best, true, true, true))
end

-- ── Snippets ──────────────────────────────────────────────────────────
local function snippets()
  -- What is loaded, from where, and whether any trigger arrived twice. The
  -- last one is here because a duplicate is invisible from the outside: the
  -- completion menu simply lists an entry twice, which reads as clutter
  -- rather than as a fault, and there was no way to ask.
  h.start("Snippets (LuaSnip)")

  local ls_ok, ls = pcall(require, "luasnip")
  if not ls_ok then
    h.info("LuaSnip is not loaded yet. It loads on InsertEnter, and each\n"
      .. "filetype's snippets load the first time you type in such a buffer,\n"
      .. "so nothing is reported until then.")
  else
    local manual = ls.get_snippets(nil, { type = "snippets" }) or {}
    local auto   = ls.get_snippets(nil, { type = "autosnippets" }) or {}

    local fts = {}
    for ft in pairs(manual) do fts[ft] = true end
    for ft in pairs(auto) do fts[ft] = true end
    local names = vim.tbl_keys(fts)
    table.sort(names)

    -- Said every time, not only when nothing is loaded. A filetype missing
    -- from the list below looks like a fault otherwise, and the usual reason
    -- is simply that no buffer of that filetype has been typed in yet.
    h.info("Snippets load per filetype, the first time you type in a buffer\n"
      .. "of that filetype, so a filetype you have only opened is not listed.")

    for _, ft in ipairs(names) do
      local m, a = manual[ft] or {}, auto[ft] or {}
      -- Where each snippet came from, when LuaSnip is recording it. A
      -- repeated trigger is only worth reporting alongside its origins: two
      -- snippets from two files is a shadowing, two from one file is usually
      -- deliberate, and the same file twice is a loader fault.
      local function origin(snip)
        local src_ok, src = pcall(function()
          return ls.snippet_source and ls.snippet_source.get(snip)
        end)
        if src_ok and src and src.file then
          return vim.fn.fnamemodify(src.file, ":t")
        end
        return nil
      end

      local seen, repeats, sources = {}, {}, {}
      for _, list in ipairs({ m, a }) do
        for _, snip in ipairs(list) do
          local trig = snip.trigger
          seen[trig] = (seen[trig] or 0) + 1
          sources[trig] = sources[trig] or {}
          local from = origin(snip)
          if from then table.insert(sources[trig], from) end
          if seen[trig] == 2 then repeats[#repeats + 1] = trig end
        end
      end

      local distinct = vim.tbl_count(seen)
      h.ok(("%s: %d snippet%s (%d manual, %d auto), %d distinct trigger%s")
        :format(ft, #m + #a, (#m + #a) == 1 and "" or "s", #m, #a,
          distinct, distinct == 1 and "" or "s"))

      if #repeats > 0 then
        -- Shortest first, and regex triggers elided: a list led by
        -- `([%s%a%(%)%[%]%{%}%$])00` tells the reader nothing, while `cc` and
        -- `ff` tell them exactly which snippet to go looking at.
        table.sort(repeats, function(x, y)
          if #x ~= #y then return #x < #y end
          return x < y
        end)
        local advice = {}
        for _, trig in ipairs(vim.list_slice(repeats, 1, 6)) do
          local label = #trig > 12 and (trig:sub(1, 11) .. "…") or trig
          local from = sources[trig] or {}
          advice[#advice + 1] = from[1]
            and ("%s  <- %s"):format(label, table.concat(from, ", "))
            or label
        end
        advice[#advice + 1] = ""
        advice[#advice + 1] =
          "Two files means one shadows the other, and the later one wins."
        advice[#advice + 1] =
          "One file twice is usually deliberate: a trigger may have several"
        advice[#advice + 1] =
          "snippets separated by context, as `iff` has for text and maths."
        advice[#advice + 1] =
          "The same file listed twice is a loader fault, not your doing."
        h.warn(("%s: %d triggers resolve to more than one snippet")
          :format(ft, #repeats), advice)
      end
    end

    -- What is switched off, and by which of the two mechanisms. Reported
    -- every run: a snippet that is missing because you switched it off months
    -- ago is indistinguishable from one that never loaded, and this is the
    -- only place that tells the two apart.
    local store_ok, store = pcall(require, "noethervim.snippets.store")
    if store_ok then
      local audit_ok, report = pcall(store.audit)
      if audit_ok and report then
        local total = report.off_config + report.off_toggle
        if total == 0 and report.on_override == 0 then
          h.ok("no snippets are switched off")
        else
          h.ok(("%d snippet%s switched off (%d from user/config.lua, %d on "
            .. "this machine only)")
            :format(total, total == 1 and "" or "s",
              report.off_config, report.off_toggle))
        end

        if report.on_override > 0 then
          h.info(("%d snippet%s switched back on here despite user/config.lua")
            :format(report.on_override, report.on_override == 1 and " is" or "s are"))
        end

        for _, clash in ipairs(report.disagreements) do
          h.warn(("`%s` is blocked in user/config.lua but switched on here")
            :format(clash.blocked.trigger), {
            "The machine-local choice wins, because it was made later.",
            "Remove it from user/config.lua to agree, or switch it off again",
            "to drop the local exception: " .. report.path,
          })
        end

        if #report.unresolved > 0 then
          local advice = {}
          for _, item in ipairs(vim.list_slice(report.unresolved, 1, 5)) do
            advice[#advice + 1] = ("%s in %s: %s")
              :format(item.record.trigger, item.record.file, item.reason)
          end
          advice[#advice + 1] = ""
          advice[#advice + 1] =
            "Usually the snippet was renamed or removed, in which case the"
          advice[#advice + 1] =
            "record is harmless and can be deleted. Nothing is switched off"
          advice[#advice + 1] = "on its behalf."
          local n = #report.unresolved
          h.warn(("%d remembered snippet%s no longer name%s anything")
            :format(n, n == 1 and "" or "s", n == 1 and "s" or ""), advice)
        end
      end
    end

    -- A snippet LuaSnip did not record a source for cannot be written down,
    -- only switched off until the next restart. Worth saying plainly, since
    -- the switch appears to work and then does not survive.
    local id_ok, snippet_id = pcall(require, "noethervim.snippets.id")
    if id_ok then
      local nameless = 0
      for _, ft in ipairs(names) do
        for _, list in ipairs({ manual[ft] or {}, auto[ft] or {} }) do
          for _, snip in ipairs(list) do
            if not snip.invalidated and not snippet_id.identity(snip, ft) then
              nameless = nameless + 1
            end
          end
        end
      end
      if nameless > 0 then
        h.warn(("%d snippet%s cannot be remembered between sessions")
          :format(nameless, nameless == 1 and "" or "s"), {
          "LuaSnip did not record which file they came from, so there is no",
          "stable way to name them. You can still switch them off, but the",
          "choice lasts only until you restart.",
          "Upstream fix: https://github.com/L3MON4D3/LuaSnip/pull/1451",
        })
      end
    end

    -- jsregexp backs ECMAScript triggers and the transformations inside
    -- LSP-format snippets. It is compiled by LuaSnip's build step, and when
    -- that step did not run both degrade quietly: the trigger falls back to
    -- matching literally, so the snippet never fires and nothing says why.
    local js_ok, js = pcall(require, "luasnip.util.jsregexp")
    if js_ok and js then
      h.ok("jsregexp: available, so ECMAScript triggers and snippet "
        .. "transformations work")
    else
      h.warn("jsregexp: not available", {
        "A snippet written with trigEngine = \"ecma\" matches its trigger\n"
          .. "literally instead, and transformations in LSP-format snippets\n"
          .. "are skipped. Lua patterns and vim regexes are unaffected.",
        ":Lazy build LuaSnip rebuilds it, given make and a C compiler.",
      })
    end

    -- Where the reader's own snippets live, which is the answer to "where do
    -- I put one" and is not guessable from the outside.
    local mine = vim.fn.stdpath("config") .. "/LuaSnip"
    if vim.fn.isdirectory(mine) == 1 then
      local n = #vim.fn.glob(mine .. "/**/*.lua", false, true)
      h.ok(("your snippets: %s (%d file%s)")
        :format(vim.fn.fnamemodify(mine, ":~"), n, n == 1 and "" or "s"))
    else
      h.info(("your snippets would live in %s, which does not exist yet")
        :format(vim.fn.fnamemodify(mine, ":~")))
    end
    local key = edit_snippets_key()
    h.info(("%s opens them, and a file a plugin ships opens read-only.")
      :format(key and (key .. " (:LuaSnipEdit)") or ":LuaSnipEdit"))
  end
end

local M = {}

function M.check()
  snippets()
end

return M
