--- :NoetherVim files, grep, user and plugins: pickers over NoetherVim's
--- source, your lua/user/ and the installed plugins.

local Snacks = require("snacks")
local ui = require("noethervim.inspect.ui")
local effective_root = ui.effective_root
local user_dir = ui.user_dir
local counterpart = ui.counterpart
local confirm_readonly = ui.confirm_readonly
local hint_footer = ui.hint_footer

local M = {}

-- ── File & Grep Pickers ───────────────────────────────

function M.files()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  local config = vim.fn.stdpath("config") .. "/"
  Snacks.picker.files({
    cwd     = root,
    title   = "NoetherVim Source",
    confirm = confirm_readonly,
    -- A file `:NoetherVim override` can stand in for names the file of
    -- yours that does, highlighted once it exists.
    transform = function(item)
      item.user_file = counterpart(item.file)
      item.has_override = item.user_file ~= nil and vim.uv.fs_stat(config .. item.user_file) ~= nil
    end,
    format = function(item, picker)
      local ret = Snacks.picker.format.file(item, picker)
      if item.user_file then
        ret[#ret + 1] = { "  → " .. item.user_file, item.has_override and "DiagnosticWarn" or "Comment" }
      end
      return ret
    end,
    win = {
      input = {
        footer     = hint_footer({ { "<cr>", "open" }, { "→", "your file that changes it" } }),
        footer_pos = "center",
      },
    },
  })
end

function M.grep()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  Snacks.picker.grep({ cwd = root, title = "NoetherVim Grep", confirm = confirm_readonly })
end

function M.user()
  local dir = user_dir()
  if vim.fn.isdirectory(dir) == 0 then
    return vim.notify("NoetherVim: no user config directory at " .. dir, vim.log.levels.INFO)
  end
  Snacks.picker.files({ cwd = dir, title = "User Config" })
end

function M.plugins()
  local plugin_dir = vim.fn.stdpath("data") .. "/lazy"
  if vim.fn.isdirectory(plugin_dir) == 0 then
    return vim.notify("NoetherVim: no lazy plugin directory found", vim.log.levels.ERROR)
  end
  Snacks.picker.files({ cwd = plugin_dir, title = "Installed Plugins", confirm = confirm_readonly })
end

return M
