--- Switches an individual snippet off and back on.
---
--- WHY TWO FIELDS AND NOT ONE
--- Two independent paths can put a snippet into the buffer, and neither
--- consults the other's condition. blink's LuaSnip source builds a
--- per-filetype cache and drops anything with `hidden` set, so `hidden`
--- governs the completion menu. LuaSnip's own `match_snippet` runs when a
--- trigger is typed and Tab is pressed, and it calls `matches` without ever
--- looking at `hidden`, so `matches` governs that route. Setting one alone
--- leaves the snippet reachable by the other.
---
--- WHY NOT Snippet:invalidate()
--- It looks like the built-in answer and is the wrong one. Alongside setting
--- those two fields it raises `snippet_collection.invalidated_count`, and once
--- that passes 100 `clean_invalidated` strips every invalidated snippet out of
--- the collection. A snippet switched off that way is eventually destroyed, so
--- it can be neither switched back on nor listed. `invalidate` means "this is
--- dead, collect it"; this module means "the reader does not want it right
--- now". See dev-docs/design-decisions.md, charter point 9.
---
--- WHY THE REFRESH IS NOT OPTIONAL
--- blink clears its cache only on `User LuasnipSnippetsAdded`, and its
--- `execute` expands by snippet id without re-checking `matches`. Without the
--- refresh the entry stays in the menu and still expands, so the change would
--- appear to have done nothing.

local M = {}

--- Written onto the LuaSnip snippet itself, so they are namespaced: the engine
--- owns every other field on that table.
local DISABLED = 'noethervim_disabled'
local WAS_HIDDEN = 'noethervim_was_hidden'

local function no_match()
  return nil
end

--- Why a snippet is or is not offered.
--- `shipped_off` is a snippet its own author hid; the reader did not do it,
--- and switching it back on is a different act from undoing one's own change.
--- @param snip table a LuaSnip snippet, as returned by `ls.get_snippets(ft)`
--- @return 'on'|'off'|'shipped_off'
function M.state(snip)
  if snip[DISABLED] then
    return 'off'
  end
  return snip.hidden and 'shipped_off' or 'on'
end

--- `opts.refresh = false` leaves the notification to the caller. Two reasons
--- to want that: a bulk pass would otherwise fire the event once per snippet,
--- and code running inside a `LuasnipSnippetsAdded` handler would re-enter the
--- event it is already handling.
--- @param snip table
--- @param ft string the filetype it was listed under
--- @param opts { refresh: boolean }|nil
--- @return boolean changed false when it was already off
function M.disable(snip, ft, opts)
  if snip[DISABLED] then
    return false
  end
  snip[WAS_HIDDEN] = snip.hidden
  snip.hidden = true
  snip.matches = no_match
  snip[DISABLED] = true
  if not opts or opts.refresh ~= false then
    require('luasnip').refresh_notify(ft)
  end
  return true
end

--- @param snip table
--- @param ft string
--- @param opts { refresh: boolean }|nil
--- @return boolean changed false when it was not off to begin with
function M.enable(snip, ft, opts)
  if not snip[DISABLED] then
    return false
  end
  -- nil, not the value read back: `matches` is reached through the metatable,
  -- so writing any copy of it onto the snippet shadows the original for good.
  snip.matches = nil
  -- Restore rather than clear, or switching off a snippet its author hid and
  -- then switching it on again would reveal something never meant to show.
  snip.hidden = snip[WAS_HIDDEN]
  snip[WAS_HIDDEN] = nil
  snip[DISABLED] = nil
  if not opts or opts.refresh ~= false then
    require('luasnip').refresh_notify(ft)
  end
  return true
end

--- Whether the trigger is a pattern rather than literal text.
---
--- Two tests, because neither covers the field alone. `regTrig` reports only
--- the older spelling and stays false for `trigEngine = "pattern"|"ecma"|
--- "vim"`, so on its own it lets those through. Asking the snippet's own
--- matcher whether the trigger text matches itself catches every engine, but
--- reads a pattern that can match itself (anything ending in `.*`) as literal.
--- A trigger counts as literal only when both agree.
---
--- Callers need this for two different reasons: a pattern must not be offered
--- in the completion menu, where accepting it pastes the pattern itself, and a
--- pattern is useless as a label, since `([%s%a%(%)%[%]%{%}%$])00` names
--- nothing a reader recognises.
--- @param snip table
--- @return boolean
function M.is_pattern_trigger(snip)
  if not snip then
    return false
  end
  if snip.regTrig then
    return true
  end
  if not snip.trig_matcher then
    return false
  end
  local matched, match = pcall(snip.trig_matcher, snip.trigger, snip.trigger)
  return not (matched and match == snip.trigger)
end

--- @param snip table
--- @param ft string
--- @return boolean now_disabled
function M.toggle(snip, ft)
  if snip[DISABLED] then
    M.enable(snip, ft)
    return false
  end
  M.disable(snip, ft)
  return true
end

return M
