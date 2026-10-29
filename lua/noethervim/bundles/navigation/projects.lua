---@bundle projects
---@desc jump between recent projects
---@about Browses recently used project directories, changes into the one you
---       pick, and immediately opens a file picker scoped to it.
---@requires none
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
              require("snacks").picker.files({ cwd = item.file, title = vim.fn.fnamemodify(item.file, ":t") })
            end,
          },
        },
      },
    },
    specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("snacks.nvim", {
      {
        SearchLeader .. "p",
        function() require("snacks").picker.projects({ title = "Projects" }) end,
        desc = "[p]rojects",
      },
    }) } },
  },
}
