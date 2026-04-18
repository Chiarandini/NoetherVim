-- NoetherVim bundle: Projects
-- Enable with: { import = "noethervim.bundles.navigation.projects" }
--
-- Provides:
--   Snacks.picker.projects():  browse recent projects
--   SearchLeader+p             browse recent projects
--
-- After selecting a project, cd's into it and opens a file picker
-- scoped to that directory.
local SearchLeader = require("noethervim.util").search_leader
local Snacks = require("snacks")

return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          projects = {
            confirm = function(picker, item)
              picker:close()
              if not item then return end
              vim.fn.chdir(item.file)
              Snacks.picker.files({ cwd = item.file, title = vim.fn.fnamemodify(item.file, ":t") })
            end,
          },
        },
      },
    },
    keys = {
      {
        SearchLeader .. "p",
        function() Snacks.picker.projects({ title = "Projects" }) end,
        desc = "[p]rojects",
      },
    },
  },
}
