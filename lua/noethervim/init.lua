--- NoetherVim distribution entry point.
--- Called as the `config` function of the NoetherVim lazy plugin spec.
--- Runs after lazy.nvim has resolved all specs and loaded eager plugins.
---
--- User override files in lua/user/ are automatically loaded after each
--- core module.  Set NOETHERVIM_NO_USER=1 or vim.g.noethervim_no_user
--- to skip all user overrides (useful for debugging).
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
local function snapshot_options()
  local snap = {}
  for _, name in ipairs(TRACKED_OPTIONS) do
    snap[name] = vim.o[name]
  end
  return snap
end

--- Capture all keymaps across all modes, keyed by "mode|lhs".
local function snapshot_keymaps()
  local snap = {}
  for _, mode in ipairs({ "n", "i", "v", "x", "s", "o", "c", "t" }) do
    for _, km in ipairs(vim.api.nvim_get_keymap(mode)) do
      snap[mode .. "|" .. km.lhs] = {
        mode     = mode,
        lhs      = km.lhs,
        rhs      = km.rhs or "",
        desc     = km.desc or "",
        callback = km.callback,
      }
    end
  end
  return snap
end

-- ── Setup ────────────────────────────────────────────────────────

--- Which user modules were actually found and loaded.
--- Read by `:checkhealth noethervim`; not part of the public API.
---@private
M._user_loaded = false
---@private
M._user_modules   = {}
---@private
M._user_lsp       = {}
---@private
M._user_overrides = {}

--- Initialize NoetherVim. Called by `init.lua.example` as the lazy.nvim
--- `config = function(_, opts) require("noethervim").setup(opts) end` shim.
---
--- See |noethervim-user-config| for the user-override system this orchestrates.
---
---@param opts? noethervim.Config
function M.setup(opts)
  opts = opts or {}

  -- Determine whether to load user overrides.
  local load_user = not vim.env.NOETHERVIM_NO_USER
                    and not vim.g.noethervim_no_user
  M._user_loaded = load_user

  -- Setup-time keymap source registry: wraps vim.keymap.set so every
  -- imperative registration records file+line for the inspect picker and
  -- the guide jumper. Uninstalled at the end of setup() so user-time
  -- calls hit the stock function.
  local keymap_registry = require("noethervim.util.keymap_registry")
  keymap_registry.install()

  --- Attempt to load a user override module.  Silent no-op if the file
  --- doesn't exist.  Tracks successfully loaded modules for health/status.
  local function user(mod)
    if not load_user then return end
    local ok, err = pcall(require, "user." .. mod)
    if ok then
      table.insert(M._user_modules, mod)
    elseif err and not err:match("module 'user%." .. mod .. "' not found") then
      vim.notify("user/" .. mod .. ".lua: " .. err, vim.log.levels.WARN)
    end
  end

  -- Forward statusline overrides
  if opts.statusline then
    require("noethervim.statusline").configure(opts.statusline)
  end

  -- Disable unused external providers
  vim.g.loaded_ruby_provider = 0
  vim.g.loaded_perl_provider = 0
  vim.g.loaded_node_provider = 0

  -- ── Core options ───────────────────────────────────────────────
  require("noethervim.options")
  if load_user then M._snapshots.options_before = snapshot_options() end
  user("options")
  if load_user then M._snapshots.options_after = snapshot_options() end

  -- Lazy management keymaps (under <C-w>l prefix, Window namespace)
  vim.keymap.set("n", "<c-w>ll", "<cmd>Lazy<cr>",             { desc = "Lazy" })
  vim.keymap.set("n", "<c-w>li", "<cmd>Lazy install<cr>",     { desc = "Lazy install" })
  vim.keymap.set("n", "<c-w>ls", "<cmd>Lazy sync<cr>",        { desc = "Lazy sync" })
  vim.keymap.set("n", "<c-w>lp", "<cmd>Lazy profile<cr>",     { desc = "Lazy profile" })
  vim.keymap.set("n", "<c-w>ld", "<cmd>Lazy debug<cr>",       { desc = "Lazy debug" })
  vim.keymap.set("n", "<c-w><c-g>",
    "<cmd>lua Snacks.terminal('lazygit')<cr>", { desc = "lazygit" })

  -- ── LSP server configs ─────────────────────────────────────────
  -- Core servers (lua/noethervim/lsp/*.lua)
  local lsp_paths = vim.api.nvim_get_runtime_file("lua/noethervim/lsp/*.lua", true)
  for _, path in ipairs(lsp_paths) do
    local name = vim.fn.fnamemodify(path, ":t:r")
    require("noethervim.lsp." .. name)
  end
  -- User LSP overrides (vim.lsp.config deep-merges when called again)
  if load_user then
    for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/user/lsp/*.lua", true)) do
      local name = vim.fn.fnamemodify(path, ":t:r")
      local ok = pcall(require, "user.lsp." .. name)
      if ok then table.insert(M._user_lsp, name) end
    end
  end

  -- ── Core keymaps + toggles ─────────────────────────────────────
  -- Baseline: keymaps that exist before NoetherVim core loads
  -- (Neovim defaults + lazy plugin handler keymaps).
  -- Used to filter Neovim defaults from the diff picker.
  if load_user then M._snapshots.keymaps_baseline = snapshot_keymaps() end
  require("noethervim.keymaps")
  require("noethervim.toggles")
  if load_user then M._snapshots.keymaps_before = snapshot_keymaps() end
  user("keymaps")
  if load_user then M._snapshots.keymaps_after = snapshot_keymaps() end

  -- ── Autocommands ───────────────────────────────────────────────
  require("noethervim.autocmds")
  user("autocmds")

  -- ── Commands ───────────────────────────────────────────────────
  require("noethervim.commands")

  -- ── Highlights & colorscheme ───────────────────────────────────
  -- setup_tweaks() registers the ColorScheme autocmd that re-applies
  -- user tweaks on theme switches. It runs unconditionally so that
  -- util.colorscheme.tweak() works whether or not the colorscheme
  -- bundle is enabled. setup_persistence() is bundle-gated because it
  -- overrides opts.colorscheme with the saved pick.
  local cs = require("noethervim.util.colorscheme")
  cs.setup_tweaks()
  if opts.colorscheme_persistence then
    cs.setup_persistence()
  end
  if opts.colorscheme then
    -- Persistence may have already applied a saved scheme; only apply
    -- the default if no persisted choice was loaded.
    if not opts.colorscheme_persistence or vim.g.colors_name == nil then
      pcall(vim.cmd.colorscheme, opts.colorscheme)
    end
  end
  require("noethervim.highlights")
  user("highlights")  -- after colorscheme so user highlights are not overwritten

  -- ── Imperative user overrides (last-resort solution) ───────
  -- Files in lua/user/overrides/*.lua run after everything else.
  -- See :help noethervim-user-overrides for when to use this.
  if load_user then
    for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/user/overrides/*.lua", true)) do
      local name = vim.fn.fnamemodify(path, ":t:r")
      local ok = pcall(require, "user.overrides." .. name)
      if ok then table.insert(M._user_overrides, name) end
    end
  end

  -- ── Inspection & comparison commands ───────────────────────────
  require("noethervim.inspect").setup()

  -- ── Release the keymap.set wrapper ─────────────────────────────
  -- All setup-scope keymaps have now been registered. User-time
  -- vim.keymap.set calls (ftplugin, post-load plugin configs,
  -- interactive :lua) run against the stock function.
  keymap_registry.uninstall()

  -- ── Helptags ───────────────────────────────────────────────────
  -- lazy.nvim generates helptags for plugins it manages, but in dev
  -- mode (rtp:prepend) it may not.  Ensure :help noethervim works.
  local doc_dir = vim.api.nvim_get_runtime_file("doc/noethervim.txt", false)[1]
  if doc_dir then
    local dir = vim.fn.fnamemodify(doc_dir, ":h")
    if not vim.uv.fs_stat(dir .. "/tags") then
      pcall(vim.cmd, "helptags " .. vim.fn.fnameescape(dir))
    end
  end
end

return M
