--- `:NoetherVim`: the dispatcher, its completion, and an entry point per
--- subcommand. Each subcommand lives in its own module under inspect/ and
--- loads on first use. See :help noethervim-inspect.

local M = {}

function M.files() return require("noethervim.inspect.files").files() end
function M.grep() return require("noethervim.inspect.files").grep() end
function M.user() return require("noethervim.inspect.files").user() end
function M.plugins() return require("noethervim.inspect.files").plugins() end
function M.bundles() return require("noethervim.inspect.bundles").bundles() end
---@param opts? { only_off: boolean }
function M.snippets(opts) return require("noethervim.inspect.snippets").snippets(opts) end
function M.templates() return require("noethervim.inspect.templates").open() end
function M.status() return require("noethervim.inspect.status").status() end
---@param opts? noethervim.inspect.DiffKeymapOpts
function M.diff_keymaps(opts) return require("noethervim.inspect.diff_keymaps").diff_keymaps(opts) end
function M.diff_options() return require("noethervim.inspect.diff_options").diff_options() end
function M.diff_autocmds() return require("noethervim.inspect.diff_autocmds").diff_autocmds() end
---@param module_name? string
function M.diff_file(module_name) return require("noethervim.inspect.diff").diff_file(module_name) end
---@param what? string
function M.diff(what) return require("noethervim.inspect.diff").diff(what) end
function M.override() return require("noethervim.inspect.override").override() end
function M.debug_keymaps() return require("noethervim.inspect.debug_keymaps").debug_keymaps() end

--- Jump to where a keymap is defined; the guide's <CR> and the keymap
--- comparison use it.
---@param mode string   Keymap mode ("n", "i", "v", etc.)
---@param lhs  string   Resolved keymap lhs (from nvim_get_keymap)
---@param opts? noethervim.KeymapJumpOpts
function M.jump_to_keymap(mode, lhs, opts) return require("noethervim.inspect.source").jump(mode, lhs, opts) end

-- ── Command dispatcher ───────────────────────────────────────────

-- One-liner per subcommand. Surfaced in the no-arg help printout.
local subcommand_descriptions = {
  files             = "Browse NoetherVim source files",
  grep              = "Live grep over NoetherVim source",
  user              = "Browse files in lua/user/",
  plugins           = "Browse installed plugins",
  bundles           = "Bundle picker (<C-y> enable, <C-x> disable)",
  snippets          = "Snippet picker (<C-y> on, <C-x> off, <A-o> only off); `snippets off` opens filtered",
  templates         = "Write user-config templates into lua/user/ (<C-y>)",
  ["keymap-guide"]  = "Keymap namespace reference buffer",
  status            = "Show which user override files are loaded",
  diff              = "Compare overrides vs distro defaults (keymaps / options / autocmds / module)",
  override          = "Open the file of yours that changes the current distro file",
  ["debug-keymaps"] = "Trace where each keymap was registered",
  where             = "Who set a key, option, command, plugin, segment or picker verb, and the line that changes it",
}

--- Each entry receives (arg, bang), so the dispatcher needs no special case
--- for a subcommand that reads the bang.
---@type table<string, fun(arg: string?, bang: boolean?)>
local subcommands = {
  files             = M.files,
  grep              = M.grep,
  user              = M.user,
  plugins           = M.plugins,
  bundles           = M.bundles,
  snippets          = function(arg) M.snippets({ only_off = arg == "off" }) end,
  templates         = M.templates,
  ["keymap-guide"]  = function() require("noethervim.guide").open() end,
  status            = M.status,
  diff              = function(args) M.diff(args) end,
  override          = M.override,
  ["debug-keymaps"] = function() M.debug_keymaps() end,
  where             = function(arg) require("noethervim.inspect.where").run(arg) end,
}

local subcommand_names = vim.tbl_keys(subcommands)
table.sort(subcommand_names)

local function print_help()
  local lines = { "NoetherVim subcommands:", "" }
  for _, name in ipairs(subcommand_names) do
    lines[#lines + 1] = string.format("  %-15s  %s", name, subcommand_descriptions[name] or "")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Tab-complete after `:NoetherVim ` to pick one."
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "NoetherVim" })
end

--- Run a `:NoetherVim` subcommand.
---
--- Exported rather than kept inside `setup()` so the command can be created
--- before this module is loaded. Registering it late left `:NoetherVim` as a
--- bare prefix of `:NoetherVimHighlightUnderCursor`, which takes no
--- arguments, so an early `:NoetherVim bundles` failed with a trailing
--- characters error instead of running.
--- @param opts table the table Neovim hands a user-command callback
function M.dispatch(opts)
  local args = vim.split(opts.args, "%s+", { trimempty = true })
  local cmd  = args[1]
  if not cmd then
    print_help()
    return
  end
  local fn = subcommands[cmd]
  if fn then
    fn(args[2], opts.bang)
  else
    vim.notify("NoetherVim: unknown subcommand '" .. cmd .. "'", vim.log.levels.ERROR)
  end
end

--- @param cmdline string
--- @return string[]
function M.complete(_, cmdline)
  -- No `trimempty`: a trailing space has to survive as an empty final
  -- element, otherwise `:NoetherVim diff <Tab>` is indistinguishable
  -- from `:NoetherVim diff<Tab>` and completes subcommands instead of
  -- diff targets.
  local args = vim.split((cmdline:gsub("^%s+", "")), "%s+")
  -- Complete subcommand name
  if #args <= 2 then
    return vim.tbl_filter(function(s)
      return s:find(args[2] or "", 1, true) == 1
    end, subcommand_names)
  end
  -- Complete diff targets
  if args[2] == "diff" and #args == 3 then
    return vim.tbl_filter(function(s)
      return s:find(args[3], 1, true) == 1
    end, require("noethervim.inspect.diff").targets())
  end
  -- `where` takes keys too, which do not complete; offer the rest.
  if args[2] == "where" and #args == 3 then
    local names = vim.tbl_keys(vim.api.nvim_get_commands({}))
    vim.list_extend(names, vim.tbl_keys(require("lazy.core.config").plugins))
    vim.list_extend(names, vim.fn.getcompletion(args[3], "option"))
    vim.list_extend(names, require("noethervim.pick").VERBS)
    table.sort(names)
    return vim.tbl_filter(function(s)
      return s:find(args[3], 1, true) == 1
    end, names)
  end
  return {}
end

return M
