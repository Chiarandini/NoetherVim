-- Git statusline components.

local ctx = require("noethervim.plugins.statusline.context")
local conditions = require("heirline.conditions")

local M = {}

--- Factory for git change counters.
---
--- Renders `(+3 ~1 -2)`, dropping any count that is zero and the separator
--- that would have preceded it. Each count needs its own component because
--- each carries its own colour, so the separator cannot simply be baked into
--- the string -- it is a component too, shown only when a count precedes it
--- AND this one is non-zero.
---
--- Both halves of that test matter, and each was missing before: the
--- separator before `~` fired on `status_dict.changed` being present, but
--- gitsigns reports an unchanged file as `0`, and **0 is truthy in Lua** --
--- so a file with only additions rendered `(+1 )`. The separator before `-`
--- tested `removed ~= 0`, which is true when `removed` is `nil`, so a file
--- with only modifications rendered `( ~1)`.
---
--- @param show_prefix boolean  true -> "+3 ~1 -2", false -> "3 1 2"
local function make_git_changes(show_prefix)
  --- Counts are nil on a file gitsigns has not measured yet, and 0 on one
  --- with nothing to report; both mean "show nothing".
  local function count_of(status, key)
    local n = status and status[key]
    return (type(n) == "number" and n > 0) and n or 0
  end

  local function counter(key, sigil, colour)
    return {
      value = function(self) return count_of(self.status_dict, key) end,
      text  = function(_, n) return show_prefix and (sigil .. n) or tostring(n) end,
      hl    = function() return { fg = ctx.colors[colour] } end,
    }
  end

  local block = {
    init = function(self)
      self.has_changes = count_of(self.status_dict, "added") > 0
          or count_of(self.status_dict, "changed") > 0
          or count_of(self.status_dict, "removed") > 0
    end,
    condition = function()
      return conditions.is_git_repo() and vim.g.heirline_git_show
    end,
    {
      condition = function(self) return self.has_changes end,
      provider = "(",
    },
  }
  for _, c in ipairs(ctx.joined_counters({
    counter("added",   "+", "git_add"),
    counter("changed", "~", "yellow"),
    counter("removed", "-", "git_del"),
  })) do
    block[#block + 1] = c
  end
  block[#block + 1] = {
    condition = function(self) return self.has_changes end,
    provider = ")",
  }
  return block
end

local GitBranchName = {
  init = function(self)
    self.status_dict = vim.b.gitsigns_status_dict
  end,
  condition = function()
    return conditions.is_git_repo() and vim.g.heirline_git_show
  end,
  provider = function(self)
    return "  " .. self.status_dict.head
  end,
  hl = { bold = true },
}

M.GitBlock = {
  init = function(self)
    self.status_dict = vim.b.gitsigns_status_dict
  end,
  condition = function()
    return conditions.is_git_repo() and vim.g.heirline_git_show
  end,

  on_click = {
    -- Resolved per click rather than captured once, so a user handler set
    -- in lua/user/config.lua applies without a restart.
    callback = function()
      require("noethervim.statusline").get_git_click()()
    end,
    name = "heirline_git",
  },

  hl = function() return { fg = ctx.colors.orange } end,

  flexible = ctx.priority.low,

  -- render everything for Git
  {
    GitBranchName,
    make_git_changes(true),
  },

  -- render only the numbers
  make_git_changes(false),

  -- render nothing
  { provider = "" },
}

return M
