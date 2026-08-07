-- Git statusline components.

local ctx = require("noethervim.plugins.statusline.context")
local conditions = require("heirline.conditions")

local M = {}

--- Factory for git change counters.
--- @param show_prefix boolean  true -> "+3 ~1 -2", false -> "3 1 2"
local function make_git_changes(show_prefix)
  return {
    init = function(self)
      self.has_changes = self.status_dict.added ~= 0
          or self.status_dict.removed ~= 0
          or self.status_dict.changed ~= 0
    end,
    condition = function()
      return conditions.is_git_repo() and vim.g.heirline_git_show
    end,
    {
      condition = function(self)
        return self.has_changes
      end,
      provider = "(",
    },
    {
      provider = function(self)
        local count = self.status_dict.added or 0
        return count > 0 and (show_prefix and ("+" .. count) or count)
      end,
      hl = function() return { fg = ctx.colors.git_add } end,
    },
    {
      condition = function(self)
        return self.status_dict.changed
      end,
      provider = " ",
    },
    {
      provider = function(self)
        local count = self.status_dict.changed or 0
        return count > 0 and (show_prefix and ("~" .. count) or count)
      end,
      hl = function() return { fg = ctx.colors.yellow } end,
    },
    {
      condition = function(self)
        return self.status_dict.removed ~= 0
      end,
      provider = " ",
    },
    {
      provider = function(self)
        local count = self.status_dict.removed or 0
        return count > 0 and (show_prefix and ("-" .. count) or count)
      end,
      hl = function() return { fg = ctx.colors.git_del } end,
    },
    {
      condition = function(self)
        return self.has_changes
      end,
      provider = ")",
    },
  }
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
