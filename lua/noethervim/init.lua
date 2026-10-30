--- NoetherVim distribution entry point.
--- Called as the `config` function of the NoetherVim lazy plugin spec,
--- first among the start plugins.
---
--- Your hook files in lua/user/ run later, from after/plugin/noethervim.lua
--- (noethervim.user_layer). Set NOETHERVIM_NO_USER=1 or
--- vim.g.noethervim_no_user to skip them (useful for debugging).
---
--- See init.lua.example for the recommended user setup pattern.
--- See :help noethervim-user-config for the override system.

local M = {}

-- ── Snapshot infrastructure ──────────────────────────────────────
-- Before/after snapshots of options and keymaps, used by the
-- comparison pickers in noethervim.inspect.

---@private
M._snapshots = {}

--- Options set by noethervim/options.lua that we track for diffing.
local TRACKED_OPTIONS = {
  "number", "relativenumber",
  "mouse", "mousemoveevent",
  "autowrite", "autowriteall", "autoread", "swapfile",
  "textwidth", "wrap", "breakindent", "linebreak", "formatoptions",
  "diffopt",
  "ignorecase", "infercase", "incsearch", "smartcase", "hlsearch",
  "tabstop", "shiftwidth",
  "splitbelow", "splitright",
  "scrolloff", "sidescrolloff", "smoothscroll",
  "shortmess", "visualbell", "termguicolors",
  "foldcolumn", "foldlevel", "foldlevelstart", "foldenable",
  "autochdir",
  "sessionoptions",
  "undofile", "undolevels", "undoreload",
  "shada",
}

--- Capture current values of all tracked options.
---@return table<string, any>
local function snapshot_options()
  local snap = {}
  for _, name in ipairs(TRACKED_OPTIONS) do
    snap[name] = vim.o[name]
  end
  return snap
end

--- Apply the configured window-local options to windows already open.
---
--- `vim.o.number = true` sets two things: the current window's value, and
--- the value new windows will inherit. Windows already open are left alone.
---
--- That is harmless most of the time, because the startup window is the
--- current one while options load. Not on a first launch: lazy.nvim is busy
--- installing plugins, so its progress window is current instead, and the
--- startup window is the one window that misses out -- the very window the
--- dashboard and then your first file appear in. The symptom is a session
--- with no line numbers, 'wrap' on and folds closed, that comes back
--- correct on the next launch.
---
--- So bring those windows up to date: give each one the value a window
--- opened right now would inherit. Windows a plugin owns (any 'buftype':
--- the lazy view, oil, the dashboard) are left out, since they set their
--- own. Runs once, over ten-odd options and usually one window.
local function apply_win_local_defaults()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
      for name, info in pairs(vim.api.nvim_get_all_options_info()) do
        if info.scope == "win" and not info.global_local then
          local inherited = vim.api.nvim_get_option_value(name, { scope = "global" })
          if vim.api.nvim_get_option_value(name, { win = win }) ~= inherited then
            vim.api.nvim_set_option_value(name, inherited, { win = win })
          end
        end
      end
    end
  end
end

---@class noethervim.KeymapSnapshot
---@field mode string
---@field lhs string
---@field rhs string
---@field desc string
---@field sid integer
---@field callback? function

--- Capture all keymaps across all modes, keyed by "mode|lhs".
---@param lists? table<string, table[]> nvim_get_keymap() per mode, if read already
---@return table<string, noethervim.KeymapSnapshot>
local function snapshot_keymaps(lists)
  local snap = {}
  for _, mode in ipairs({ "n", "i", "v", "x", "s", "o", "c", "t" }) do
    for _, km in ipairs(lists and lists[mode] or vim.api.nvim_get_keymap(mode)) do
      snap[mode .. "|" .. km.lhs] = {
        mode     = mode,
        lhs      = km.lhs,
        rhs      = km.rhs or "",
        desc     = km.desc or "",
        sid      = km.sid,
        callback = km.callback,
      }
    end
  end
  return snap
end

-- ── Setup ────────────────────────────────────────────────────────

--- Directory of this module: lua/noethervim.
local here = (debug.getinfo(1, "S").source:sub(2):gsub("/init%.lua$", ""))

--- Run one of NoetherVim's writing files with `:source` rather than
--- `require`. A sourced file gets a script id of its own, so every option,
--- mapping and autocmd it creates is signed with it: `:verbose set` and
--- `:verbose map` name NoetherVim's file, and a value NoetherVim set can be
--- told apart from one you set. These files are never required.
---@param rel string path below lua/noethervim
local function source(rel)
  vim.cmd.source(vim.fn.fnameescape(here .. "/" .. rel))
end

--- Which user modules were actually found and loaded.
--- Read by `:checkhealth noethervim`; not part of the public API.
---@private
M._user_loaded = false
---@private
M._user_modules = {}

--- The snapshots :NoetherVim diff compares: NoetherVim's state at the end
--- of setup, and the state now. Only what your files changed counts as
--- yours there, so reading "now" late includes nothing it should not.
---@private
function M._snapshots_now()
  return vim.tbl_extend("force", M._snapshots, {
    options_after = snapshot_options(),
    keymaps_after = snapshot_keymaps(),
  })
end

--- What units contributed through NoetherVim's spec: rows, g, startup,
--- gutter, segments, busy.
---@private
---@type noethervim.HostOpts
M._host = {}

--- Initialize NoetherVim. Called from the lazy.nvim `config` callback
--- of the NoetherVim plugin spec, first among the start plugins.
---
--- All user-facing configuration lives in `lua/user/config.lua`, read
--- through `noethervim.config`. See |noethervim-user-config|.
---@param opts? noethervim.HostOpts  the NoetherVim spec's merged opts
function M.setup(opts)
  M._host = opts or {}
  local config = require("noethervim.config")
  local load_user = not config.user_off()
  M._user_loaded = load_user
  local user_cfg = config.get()

  -- Check at the boundary. A bad value becomes a warning rather than a
  -- crash, and setup goes on with what can be read. A key nothing reads (a
  -- typo, or one renamed in an update) is named too: otherwise the setting
  -- is ignored without a word.
  local errors, unknowns = config.validate()
  for _, err in ipairs(errors) do
    vim.notify("noethervim.setup: " .. err, vim.log.levels.WARN)
  end
  if #unknowns > 0 then
    vim.notify("lua/user/config.lua: nothing reads " .. table.concat(unknowns, ", ")
      .. " (a typo, or a key renamed in an update: NEWS.md lists those)", vim.log.levels.WARN)
  end

  -- Every mapping here with no script behind it is one of Neovim's own
  -- defaults; record them before NoetherVim adds any. Then the broker,
  -- which signs the writes plugin configs make later (noethervim.default).
  require("noethervim.default").snapshot_defaults()
  source("default/broker.lua")

  -- Plugin globals units declare, set only while still unset, so one you
  -- set before NoetherVim loads stays.
  for name, value in pairs(M._host.g or {}) do
    if vim.g[name] == nil then vim.g[name] = value end
  end

  -- The statusline's data: your `statusline` settings, and the segments
  -- and busy entries units declared. Whatever draws the bar reads them.
  local statusline = require("noethervim.statusline")
  statusline.configure(user_cfg.statusline)
  statusline.register(M._host.segments, M._host.busy)

  -- Disable unused external providers
  vim.g.loaded_ruby_provider = 0
  vim.g.loaded_perl_provider = 0
  vim.g.loaded_node_provider = 0

  -- ── Core options ───────────────────────────────────────────────
  source("options.lua")
  apply_win_local_defaults()

  -- Lazy management keymaps (under <C-w>l prefix, Window namespace)
  vim.keymap.set("n", "<c-w>ll", "<cmd>Lazy<cr>",             { desc = "Lazy" })
  vim.keymap.set("n", "<c-w>li", "<cmd>Lazy install<cr>",     { desc = "Lazy install" })
  vim.keymap.set("n", "<c-w>ls", "<cmd>Lazy sync<cr>",        { desc = "Lazy sync" })
  vim.keymap.set("n", "<c-w>lp", "<cmd>Lazy profile<cr>",     { desc = "Lazy profile" })
  vim.keymap.set("n", "<c-w>ld", "<cmd>Lazy debug<cr>",       { desc = "Lazy debug" })
  vim.keymap.set("n", "<c-w><c-g>",
    "<cmd>lua Snacks.terminal('lazygit')<cr>", { desc = "lazygit" })

  -- ── Core keymaps + toggles ─────────────────────────────────────
  -- Baseline: keymaps that exist before NoetherVim core loads
  -- (Neovim defaults + lazy plugin handler keymaps).
  -- Used to filter Neovim defaults from the diff picker.
  -- One read of every mode's mappings answers both.
  local held = require("noethervim.default").hold(true)
  if load_user then M._snapshots.keymaps_baseline = snapshot_keymaps(held) end
  source("keymaps.lua")
  source("toggles/options.lua")
  source("keymaps/apply.lua")
  require("noethervim.default").hold(false)

  -- ── Autocommands ───────────────────────────────────────────────
  source("profiles/apply.lua")
  source("autocmds.lua")

  -- ── Commands ───────────────────────────────────────────────────
  -- :Reset, :DiffOrig, :Redir, etc. Deferred to keep `nvim .` fast;
  -- the commands aren't typed in the first ~100ms of a session.
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function() source("commands.lua") end,
  })

  -- ── Highlights & colorscheme ───────────────────────────────────
  -- setup_tweaks() registers the ColorScheme autocmd that re-applies user
  -- tweaks on theme switches.
  --
  -- Persistence is on unless switched off. The picker that changes themes
  -- (SearchLeader+C) is a core keymap, so a pick made there has to survive a
  -- restart whether or not the colorscheme bundle is enabled; a picker whose
  -- result silently evaporates is worse than no picker. The cost is that the
  -- saved pick shadows `colorscheme` in lua/user/config.lua -- reported by
  -- :checkhealth noethervim, and switched off with
  -- `colorscheme_persistence = false`.
  local cs = require("noethervim.theme")
  cs.setup_tweaks()
  local persist = user_cfg.colorscheme_persistence ~= false
  if persist then
    cs.setup_persistence()
  end
  -- Fall back to gruvbox when the user has not picked a scheme. It is the
  -- shipped default, and the dashboard / statusline fallback colours are
  -- chosen against it, so an unconfigured install still looks coherent.
  -- Its spec is `lazy = true`; noethervim.theme loads it on demand here.
  -- Skip only when persistence actually restored a saved pick:
  -- `vim.g.colors_name` is not a safe test on its own, since lazy.nvim
  -- applies its own `install.colorscheme` fallback while it installs missing
  -- plugins on a first launch.
  if cs.source ~= "persisted" then
    cs.apply(user_cfg.colorscheme or cs.DEFAULT,
      user_cfg.colorscheme and "config" or "default")
  end
  source("highlights.lua")

  -- A bundle that recommends itself for a filetype is offered once, on the
  -- first buffer of that filetype, in an install without it. Not in a
  -- session without a UI, which could not show it.
  if #vim.api.nvim_list_uis() > 0 then require("noethervim.util.recommend").setup() end

  -- Registrations units need from the start, in id order, once NoetherVim
  -- itself is set up.
  local startup = M._host.startup or {}
  local ids = vim.tbl_keys(startup)
  table.sort(ids)
  for _, id in ipairs(ids) do
    if startup[id] then startup[id]() end
  end

  -- What NoetherVim set up, for :NoetherVim diff to compare the session
  -- against. Your hook files run later, from after/plugin/noethervim.lua
  -- (noethervim.user_layer).
  if load_user then
    M._snapshots.options_before = snapshot_options()
    M._snapshots.keymaps_before = snapshot_keymaps()
  end

  -- ── :NoetherVim ────────────────────────────────────────────────
  -- Registered now, not at VeryLazy. The name has to exist from the start:
  -- until it does, `:NoetherVim` is a bare prefix of
  -- `:NoetherVimHighlightUnderCursor`, which takes no arguments, so
  -- `:NoetherVim bundles` fails with a trailing characters error rather
  -- than running. That reaches anything driving Neovim before VeryLazy
  -- fires, a `-c` argument or a headless script among them.
  --
  -- Registering the name is not the same as loading the module: both
  -- callbacks require `noethervim.inspect` when they run, so the file is
  -- still read on first use rather than at startup.
  local inspect_cmd = {
    nargs    = "*",
    bang     = true,
    complete = function(arg, cmdline)
      return require("noethervim.inspect").complete(arg, cmdline)
    end,
    desc     = "NoetherVim inspection and comparison commands",
  }
  local function inspect_dispatch(opts)
    require("noethervim.inspect").dispatch(opts)
  end
  vim.api.nvim_create_user_command("NoetherVim", inspect_dispatch, inspect_cmd)
  -- Common misspelling, kept so it does not read as the command missing.
  vim.api.nvim_create_user_command("NeotherVim", inspect_dispatch, inspect_cmd)

  -- ── Deferred setup (helptags) ──────────────────────────────────
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      -- lazy.nvim generates helptags for plugins it manages, but in
      -- dev mode (rtp:prepend) it may not. Ensure :help noethervim
      -- works.
      local doc_dir = vim.api.nvim_get_runtime_file("doc/noethervim.txt", false)[1]
      if doc_dir then
        local dir = vim.fn.fnamemodify(doc_dir, ":h")
        if not vim.uv.fs_stat(dir .. "/tags") then
          pcall(vim.cmd, "helptags " .. vim.fn.fnameescape(dir))
        end
      end
    end,
  })
end

return M
