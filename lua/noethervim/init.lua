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
---@return table<string, any>
local function snapshot_options()
  local snap = {}
  for _, name in ipairs(TRACKED_OPTIONS) do
    snap[name] = vim.o[name]
  end
  return snap
end

---@class noethervim.KeymapSnapshot
---@field mode string
---@field lhs string
---@field rhs string
---@field desc string
---@field callback? function

--- Capture all keymaps across all modes, keyed by "mode|lhs".
---@return table<string, noethervim.KeymapSnapshot>
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

--- Initialize NoetherVim. Called from the lazy.nvim `config` callback
--- of the NoetherVim plugin spec.
---
--- All user-facing configuration lives in `lua/user/config.lua`; this
--- function reads it once, validates type-level shape, and distributes
--- values to the subsystems that need them. See |noethervim-user-config|.
function M.setup()
  -- Determine whether to load user overrides.
  local load_user = not vim.env.NOETHERVIM_NO_USER
                    and not vim.g.noethervim_no_user
  M._user_loaded = load_user

  -- Read the single user-facing config surface. Missing file is the
  -- bare-Neovim case; defaults apply across the board.
  local user_cfg = {}
  if load_user then
    local ok, loaded = pcall(require, "user.config")
    if ok and type(loaded) == "table" then
      user_cfg = loaded
    elseif ok and loaded ~= nil then
      vim.notify("user/config.lua: expected return table, got " .. type(loaded),
        vim.log.levels.WARN)
    end
  end

  -- Type-check at the boundary. Bad values become a vim.notify warning
  -- rather than a hard crash; setup continues with whatever salvageable
  -- fields remain. Unknown-field (typo) detection runs in :checkhealth.
  local cfg = require("noethervim.util.config")
  for _, err in ipairs(cfg.validate_types(user_cfg)) do
    vim.notify("noethervim.setup: " .. err, vim.log.levels.WARN)
  end

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

  -- Forward statusline overrides to the registry that the heirline
  -- config callback reads at UIEnter.
  require("noethervim.statusline").configure(user_cfg.statusline)

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
  -- Core servers (lua/noethervim/lsp/*.lua). Just registrations via
  -- `vim.lsp.config()`; the server starts when a matching FileType is
  -- triggered. Deferred to first real-file FileType (oil/dashboard
  -- buffers don't need LSP), then on demand. This shaves ~4ms off
  -- `nvim .` startup since the directory buffer never triggers LSP.
  do
    local lsp_loaded = false
    local function load_lsp_configs()
      if lsp_loaded then return end
      lsp_loaded = true
      for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/noethervim/lsp/*.lua", true)) do
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
    end
    -- Trigger before the first language-bearing buffer attaches to LSP.
    -- FileType fires for every buffer including `oil`/`snacks_dashboard`;
    -- gate on a real on-disk filename so directory browsing doesn't pay
    -- the cost. BufReadPost is a belt-and-suspenders fallback.
    --
    -- We `vim.schedule` the actual load so the FileType handler returns
    -- immediately -- the file is visible the moment treesitter / syntax
    -- finishes, and LSP attaches one tick later. Re-fire FileType after
    -- registration so `vim.lsp.enable`'s autocmd actually picks up the
    -- current buffer (it normally only fires for buffers opened after
    -- `enable()`).
    local lsp_group = vim.api.nvim_create_augroup("NoetherVimLspLoader", { clear = true })
    vim.api.nvim_create_autocmd({ "FileType", "BufReadPost" }, {
      group = lsp_group,
      callback = function(args)
        if args.event == "FileType" then
          local ft = args.match
          if ft == "" or ft == "oil" or ft == "snacks_dashboard"
              or ft == "alpha" or ft == "lazy" then
            return
          end
        end
        local buf = args.buf
        vim.schedule(function()
          load_lsp_configs()
          -- Replay FileType for the buffer so the LSP autostart autocmds
          -- (registered by the per-server `vim.lsp.enable` calls) see it.
          -- Skip buffers without a window: re-firing FileType on a hidden
          -- buffer runs ftplugin code (treesitter.start, etc.) that
          -- assumes a window context and errors out. LSP can only attach
          -- to a displayed buffer anyway.
          if vim.api.nvim_buf_is_valid(buf)
              and #vim.fn.win_findbuf(buf) > 0 then
            vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
          end
        end)
        vim.api.nvim_del_augroup_by_id(lsp_group)
      end,
    })
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
  -- :Reset, :DiffOrig, :Redir, etc. Deferred to keep `nvim .` fast;
  -- the commands aren't typed in the first ~100ms of a session.
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function() require("noethervim.commands") end,
  })

  -- ── Highlights & colorscheme ───────────────────────────────────
  -- setup_tweaks() registers the ColorScheme autocmd that re-applies
  -- user tweaks on theme switches. It runs unconditionally so that
  -- util.colorscheme.tweak() works whether or not the colorscheme
  -- bundle is enabled. setup_persistence() is bundle-gated because it
  -- overrides user_cfg.colorscheme with the saved pick.
  local cs = require("noethervim.util.colorscheme")
  cs.setup_tweaks()
  if user_cfg.colorscheme_persistence then
    cs.setup_persistence()
  end
  if user_cfg.colorscheme then
    -- Persistence may have already applied a saved scheme; only apply
    -- the default if no persisted choice was loaded.
    if not user_cfg.colorscheme_persistence or vim.g.colors_name == nil then
      pcall(vim.cmd.colorscheme, user_cfg.colorscheme)
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

  -- ── Release the keymap.set wrapper ─────────────────────────────
  -- All setup-scope keymaps have now been registered. User-time
  -- vim.keymap.set calls (ftplugin, post-load plugin configs,
  -- interactive :lua) run against the stock function.
  keymap_registry.uninstall()

  -- ── Deferred setup (inspect + helptags) ────────────────────────
  -- These register pickers/commands that aren't reachable in the first
  -- ~100ms of a session; running them at VeryLazy keeps `nvim .` fast.
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function()
      require("noethervim.inspect").setup()
      -- lazy.nvim generates helptags for plugins it manages, but in
      -- dev mode (rtp:prepend) it may not.  Ensure :help noethervim
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
