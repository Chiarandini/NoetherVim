---@bundle fff
---@desc fff as the file and grep picker inside a project
---@about fff, a fuzzy finder with frecency and a persistent index, searches
---       the project's files and contents: SearchLeader ff, fp, gg, gp and gw
---       open it. snacks keeps every other picker and any directory outside
---       the project. [oF and ]oF switch between the two for the session.
---@requires note="the fff binary (downloaded on install, else built with cargo)"
-- NoetherVim bundle: fff
-- Enable with: { import = "noethervim.bundles.navigation.fff" }
--
-- Provides:
--   fff   an engine for the files, grep and grep_word picker verbs, routed
--         to by default (:h noethervim-pick), and resume for its pickers.
--
-- Default keymaps:
--   [oF / ]oF   fff / snacks for files and grep, for the session
--
-- fff keeps one index per session and indexes again whenever it is pointed
-- at another directory, so it serves the project (the git root, else the
-- cwd) and declines anywhere else, $HOME and / included; snacks searches
-- those.

local enabled = true

--- The project fff searches for a call with `opts`, or nil to decline it.
---@param opts table
local function project(opts)
  local root = require("noethervim.pick").root()
  local asked = vim.fs.normalize(opts.cwd)
  if not enabled or root == vim.uv.os_homedir() or root == "/" then return nil end
  if asked ~= root and asked ~= vim.fs.normalize(vim.uv.cwd() --[[@as string]]) then return nil end
  return root
end

---@param fn string the fff function serving the verb
local function serve(fn)
  return function(opts)
    local root = project(opts)
    if not root then return false end
    require("fff")[fn]({ cwd = root })
  end
end

return {
  {
    "dmtrKovalenko/fff",
    build = function() require("fff.download").download_or_build_binary() end,
    cmd = { "FFFFind", "FFFResume", "FFFScan", "FFFRefreshGit", "FFFClearCache", "FFFHealth", "FFFDebug", "FFFOpenLog" },
    specs = { { "NoetherVim", optional = true, opts = require("noethervim.keymaps.rows").contribute("fff",
      require("noethervim.toggles").rows("oF",
        function() enabled = true end,
        function() enabled = false end,
        "fff for files and grep"), {
      -- fff has no setup() of its own and reads vim.g.fff when it loads.
      -- lazy_sync indexes on first use instead of the startup cwd (often ~);
      -- enable_home_dir_scanning = false keeps a `:cd ~` from indexing $HOME.
      g = { fff = { lazy_sync = true, enable_home_dir_scanning = false } },
      engines = { fff = {
        files = serve("find_files"),
        grep = serve("live_grep"),
        grep_word = serve("live_grep_under_cursor"),
        resume = function() return require("fff").resume() end,
      } },
      route = { files = "fff", grep = "fff", grep_word = "fff" },
      -- A picker from fff's own commands counts for resume too.
      startup = { ["fff.resume"] = function()
        vim.api.nvim_create_autocmd("User", {
          group = vim.api.nvim_create_augroup("noethervim.fff", { clear = true }),
          pattern = "FFFOpen",
          callback = function() require("noethervim.pick").served("fff") end,
        })
      end },
    }) } },
  },
}
