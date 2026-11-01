--- The test bundle's check for :checkhealth noethervim: which project
--- neotest's adapters resolve from.
-- neotest resolves its adapters once, from Neovim's working directory, the
-- first time its client runs. When that directory is not the project, every
-- buffer in the session answers "No tests found" -- a message that names the
-- file and never the reason, and which no amount of editing the file fixes.
--
-- Printed as two directories side by side rather than as a verdict. The
-- working directory is not always required to be the project root (a
-- single-package project resolves from a subdirectory quite happily), so
-- claiming a mismatch is the fault would be wrong as often as it was right.
-- Showing both is enough to recognise the case, which is what the message
-- from neotest denies you.
---@param h table vim.health
return function(h)
  if not require("lazy.core.config").plugins["neotest"] then return end
  h.start("Test discovery (neotest)")
  local cwd = vim.uv.cwd() or ""
  h.info("Working directory: " .. cwd)

  local ok_ntcfg, ntcfg = pcall(require, "neotest.config")
  local adapters = (ok_ntcfg and ntcfg.adapters) or {}
  if #adapters == 0 then
    h.warn("No neotest adapters registered.\n"
      .. "An adapter comes from a language bundle; tools/test on its own ships\n"
      .. "the runner and nothing to drive.")
  else
    local rooted = 0
    for _, a in ipairs(adapters) do
      local name = a.name or "adapter"
      local ok_root, root = pcall(a.root, cwd)
      if ok_root and root then
        rooted = rooted + 1
        if root == cwd then
          h.ok(("%s: project root is the working directory"):format(name))
        else
          h.info(("%s: project root %s"):format(name, root))
        end
      end
    end
    if rooted == 0 then
      h.warn(("No adapter finds a project at %s.\n"):format(cwd)
        .. "Adapters are resolved from the working directory, so every buffer in\n"
        .. "this session reports \"No tests found\" whatever it holds.\n"
        .. "Start Neovim inside the project.")
    end
  end

  if vim.o.autochdir then
    h.info("'autochdir' is on, so the working directory is the current file's\n"
      .. "directory rather than wherever Neovim started. Discovery is resolved\n"
      .. "from it, which is normally still inside the project. It reports\n"
      .. "nothing only when the current file belongs to no project at all.")
  end
end
