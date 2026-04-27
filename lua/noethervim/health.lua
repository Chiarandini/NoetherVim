-- :checkhealth noethervim
local h = vim.health

local function check_exe(name, required)
  if vim.fn.executable(name) == 1 then
    h.ok(name)
  elseif required then
    h.error(name .. " not found (required)")
  else
    h.warn(name .. " not found (optional)")
  end
end

local M = {}

function M.check()
  -- ── Active bundles (computed once; reused by gating + listing) ───────
  -- lazy.core.config.spec.modules is the authoritative list of what was
  -- imported during lazy.setup(). Per-plugin spec._.module / spec._.imported
  -- do not exist; reading them returns nil for every plugin.
  local active_bundles = {}
  do
    local ok_lazy_cfg, lazy_cfg = pcall(require, "lazy.core.config")
    if ok_lazy_cfg and lazy_cfg.spec and lazy_cfg.spec.modules then
      for _, mod in ipairs(lazy_cfg.spec.modules) do
        local bundle = mod:match("^noethervim%.bundles%.(.+)$")
        if bundle then active_bundles[bundle] = true end
      end
    end
  end
  local function bundle_active(name) return active_bundles[name] == true end

  -- ── Neovim version ──────────────────────────────────────────────────
  h.start("Neovim version")
  local v = vim.version()
  if v.major > 0 or (v.major == 0 and v.minor >= 12) then
    h.ok(string.format("Neovim %d.%d.%d", v.major, v.minor, v.patch))
  else
    h.error(string.format(
      "Neovim %d.%d.%d -- NoetherVim requires >= 0.12",
      v.major, v.minor, v.patch
    ))
  end

  -- ── Required tools ──────────────────────────────────────────────────
  h.start("Required tools")
  check_exe("git", true)
  check_exe("rg",  true)   -- ripgrep (Telescope/Snacks grep)
  check_exe("fd",  true)   -- fd (Snacks file picker)

  -- ── Optional tools ──────────────────────────────────────────────────
  h.start("Optional tools")
  check_exe("node",         false)  -- some LSPs (ts_ls, etc.)
  check_exe("zoxide",       false)  -- SearchLeader+ff zoxide picker
  check_exe("lazygit",      false)  -- <c-w><c-g> float terminal
  check_exe("tree-sitter",  false)  -- required by nvim-treesitter to build parsers

  -- ── LaTeX (only when bundle is enabled) ──────────────────────────────
  -- Skip the whole section when the latex bundle isn't active, otherwise
  -- users without LaTeX get noise about missing latexmk / parsers.
  if bundle_active("languages.latex") or bundle_active("languages.latex-zotero") then
    h.start("LaTeX (noethervim.bundles.languages.latex / core vimtex)")
    check_exe("latexmk",  false)
    check_exe("pdflatex", false)

    -- PDF viewer detection. macOS apps live in /Applications and are not
    -- on PATH, so executable() always fails for them -- must fs_stat the
    -- .app bundle directly.
    if vim.fn.has("mac") == 1 then
      local mac_apps = { "Skim.app", "Preview.app" }
      local found
      for _, app in ipairs(mac_apps) do
        if vim.uv.fs_stat("/Applications/" .. app) then found = app; break end
      end
      if found then
        h.ok("PDF viewer (" .. found .. ")")
      else
        h.warn("no PDF viewer found in /Applications -- tried: " .. table.concat(mac_apps, ", "))
      end
    else
      local viewers
      if vim.fn.has("win32") == 1 then
        viewers = { "SumatraPDF", "SumatraPDF.exe" }
      else
        viewers = { "zathura", "okular", "sioyek", "evince" }
      end
      local found
      for _, viewer in ipairs(viewers) do
        if vim.fn.executable(viewer) == 1 then found = viewer; break end
      end
      if found then
        h.ok("PDF viewer (" .. found .. ")")
      else
        h.warn("no PDF viewer found -- tried: " .. table.concat(viewers, ", "))
      end
    end

    -- Treesitter latex parser: nvim-treesitter marks this parser as requiring
    -- tree-sitter generate, but NoetherVim overrides that so only a C compiler
    -- is needed. Check that cc is available and the parser is installed.
    if vim.fn.executable("cc") == 1 then
      h.ok("cc (C compiler -- required for :TSInstall latex)")
    else
      h.error("cc not found -- needed to compile the latex treesitter parser (:TSInstall latex)")
    end
    -- nvim-treesitter's main branch installs parsers to stdpath("data")/site/parser/,
    -- the master branch to lazy/nvim-treesitter/parser/. Use rtp lookup so the
    -- check works regardless of branch / install layout.
    if #vim.api.nvim_get_runtime_file("parser/latex.so", false) > 0 then
      h.ok("latex treesitter parser installed")
    else
      h.warn("latex treesitter parser not installed -- run :TSInstall latex")
    end
  end

  -- ── User override system ──────────────────────────────────────────────
  h.start("User override system")

  local nv = require("noethervim")
  if nv._user_loaded then
    h.ok("User overrides: ACTIVE")
  else
    h.warn("User overrides: DISABLED")
    if vim.env.NOETHERVIM_NO_USER then
      h.info("  NOETHERVIM_NO_USER is set")
    end
    if vim.g.noethervim_no_user then
      h.info("  vim.g.noethervim_no_user is set")
    end
  end

  -- Report which user override files were loaded
  if #nv._user_modules > 0 then
    h.ok("Loaded user modules: " .. table.concat(nv._user_modules, ", "))
  else
    h.info("No user module overrides found (options, keymaps, etc.)")
  end
  if #nv._user_lsp > 0 then
    h.ok("Loaded user LSP files: " .. table.concat(nv._user_lsp, ", "))
  end
  if #nv._user_overrides > 0 then
    h.ok("Loaded user imperative overrides: " .. table.concat(nv._user_overrides, ", "))
  end

  -- ── Template version ─────────────────────────────────────────────────
  -- Skip in dev mode: the local-testing init.lua is a wrapper, not a
  -- user-template instance, so it intentionally has no version marker.
  h.start("Template version")
  if vim.g.noethervim_dev then
    h.info("Skipped (vim.g.noethervim_dev set -- not a user-template install)")
  else
  local user_init = vim.fn.stdpath("config") .. "/init.lua"
  local upstream_init = vim.api.nvim_get_runtime_file("init.lua.example", false)[1]

  local function read_template_version(path)
    if not path or not vim.uv.fs_stat(path) then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    if not line then return nil end
    return line:match("noethervim%-template%-version:%s*(%d+)")
  end

  local user_version     = read_template_version(user_init)
  local upstream_version = read_template_version(upstream_init)

  if not upstream_version then
    -- Upstream has no marker -- version 1 (pre-release).
    -- Any user template (with or without a marker) is current.
    h.ok("Template version: current")
  elseif not user_version then
    -- Upstream added a version marker but user still has the old template.
    h.warn(string.format(
      "Your init.lua has no template version marker, but v%s is available. " ..
      "See init.lua.example for new features.",
      upstream_version
    ))
  elseif tonumber(user_version) < tonumber(upstream_version) then
    h.warn(string.format(
      "Your init.lua is based on template v%s, but v%s is available. " ..
      "See init.lua.example for new features.",
      user_version, upstream_version
    ))
  else
    h.ok("Template version: " .. user_version .. " (up to date)")
  end
  end

  -- ── Configuration ────────────────────────────────────────────────────
  h.start("Configuration")

  local config_dir = vim.fn.stdpath("config")
  if vim.uv.fs_stat(config_dir) then
    h.ok("User config dir: " .. config_dir)
  else
    h.error("User config dir missing: " .. config_dir)
  end

  local user_plugins = config_dir .. "/lua/user/plugins"
  if vim.uv.fs_stat(user_plugins) then
    h.ok("User plugins dir present")
  else
    h.info("No user plugins dir (optional) -- add plugins to " .. user_plugins)
  end

  local ok_cfg, user_cfg = pcall(require, "user.config")
  if ok_cfg and type(user_cfg) ~= "table" then
    h.warn("lua/user/config.lua must return a table (got " .. type(user_cfg) .. ") -- see templates/user/config.example.lua")
  end

  local obsidian_vault = (function()
    return ok_cfg and type(user_cfg) == "table" and user_cfg.obsidian_vault or nil
  end)()
  if obsidian_vault then
    if vim.uv.fs_stat(vim.fn.expand(obsidian_vault)) then
      h.ok("Obsidian vault found: " .. obsidian_vault)
    else
      h.warn("Obsidian vault configured but not found: " .. obsidian_vault)
    end
  else
    h.info("Obsidian vault not configured (set obsidian_vault in user/config.lua)")
  end

  -- ── Search leader ────────────────────────────────────────────────────
  h.start("Search leader")
  local search_leader = require("noethervim.util").search_leader
  h.ok("mapsearchleader: " .. search_leader)
  if search_leader == "" then
    h.warn("mapsearchleader is empty -- search keymaps will collide with normal-mode keys")
  end

  -- ── Bundles ──────────────────────────────────────────────────────────
  h.start("Active bundles")
  if next(active_bundles) then
    local names = vim.tbl_keys(active_bundles)
    table.sort(names)
    for _, name in ipairs(names) do
      h.ok("noethervim.bundles." .. name)
    end
  else
    h.info("No bundles enabled")
  end

  -- ── Spec errors ──────────────────────────────────────────────────────
  -- lazy.core.config.spec.notifs collects every ERROR/WARN emitted while
  -- resolving the spec. The stock init.lua.example installs
  -- `util.buffer_notify()` before lazy.setup so these surface as snacks
  -- toasts after VimEnter instead of the cmdline ErrorMsg that would
  -- otherwise fire the hit-enter prompt on the dashboard. Toasts are
  -- transient, so mirror the same list here -- stale imports stay
  -- visible in :checkhealth long after the toast has scrolled away.
  h.start("Spec errors")
  local ok_lazy_cfg, lazy_cfg = pcall(require, "lazy.core.config")
  if not ok_lazy_cfg or not lazy_cfg.spec then
    h.info("Skipped (lazy.nvim not initialised)")
  else
    local errors = {}
    for _, n in ipairs(lazy_cfg.spec.notifs or {}) do
      if n.level == vim.log.levels.ERROR then
        errors[#errors + 1] = n.msg
      end
    end
    if #errors == 0 then
      h.ok("No spec errors")
    else
      for _, msg in ipairs(errors) do h.error(msg) end
      h.info("Most common cause: a bundle imported in init.lua was "
        .. "removed or renamed upstream. Remove the stale import.")
    end
  end

  -- ── Override conflicts ───────────────────────────────────────────────
  -- Diff the keymap snapshots captured by init.lua around user.keymaps load
  -- to surface every core mapping the user redefined. Informational only --
  -- redefining a core mapping is a supported pattern, not an error.
  h.start("Override conflicts")
  if not nv._user_loaded then
    h.info("Skipped (user overrides disabled)")
  elseif not (nv._snapshots and nv._snapshots.keymaps_before and nv._snapshots.keymaps_after) then
    h.info("Snapshots unavailable -- keymap diff cannot be computed")
  else
    local before = nv._snapshots.keymaps_before
    local after  = nv._snapshots.keymaps_after
    local conflicts = {}
    for key, after_km in pairs(after) do
      local before_km = before[key]
      if before_km and before_km.desc ~= after_km.desc then
        table.insert(conflicts, string.format("[%s] %s  '%s' -> '%s'",
          after_km.mode, after_km.lhs,
          before_km.desc ~= "" and before_km.desc or "(no desc)",
          after_km.desc  ~= "" and after_km.desc  or "(no desc)"))
      end
    end
    if #conflicts == 0 then
      h.ok("No core keymaps overridden by user")
    else
      table.sort(conflicts)
      h.info(("User overrides %d core keymap(s):"):format(#conflicts))
      for _, c in ipairs(conflicts) do h.info("  " .. c) end
    end
  end

  -- ── LSP servers ──────────────────────────────────────────────────────
  -- List the LSP configs NoetherVim ships in lua/noethervim/lsp/. Server
  -- binaries can come from Mason or the system; checking each individually
  -- requires a server-name -> binary-name map we don't maintain here, so
  -- defer detail to :Mason / :LspInfo.
  h.start("LSP servers")
  local lsp_files = vim.api.nvim_get_runtime_file("lua/noethervim/lsp/*.lua", true)
  local server_names = {}
  for _, p in ipairs(lsp_files) do
    table.insert(server_names, vim.fn.fnamemodify(p, ":t:r"))
  end
  table.sort(server_names)
  if #server_names > 0 then
    h.ok(("Core LSP configs (%d): %s"):format(#server_names, table.concat(server_names, ", ")))
  else
    h.warn("No LSP configs found in lua/noethervim/lsp/")
  end
  if pcall(require, "mason") then
    h.ok("mason.nvim loaded -- run :Mason to inspect installation status")
  else
    h.info("mason.nvim not loaded -- install LSP binaries manually or via :Mason")
  end

  -- ── Feature flags ────────────────────────────────────────────────────
  -- Runtime-detected capabilities and distribution opt-out flags, so users
  -- can confirm what's active in their session. Add new entries here as
  -- flags are introduced; remove entries when the flag is gone.
  h.start("Feature flags")
  if vim.api.nvim__redraw then
    h.ok("nvim__redraw API present (statusline busy-spinner updates smoothly)")
  else
    h.warn("nvim__redraw missing -- busy-spinner falls back to redrawstatus")
  end
  if vim.g.noethervim_dashboard == false then
    h.info("Dashboard: disabled (vim.g.noethervim_dashboard = false)")
  else
    h.ok("Dashboard: enabled")
  end
  if vim.g.noethervim_dev then
    h.info("Dev mode: ON (vim.g.noethervim_dev set)")
  end
  if vim.env.NOETHERVIM_NO_USER or vim.g.noethervim_no_user then
    h.info("User overrides: SUPPRESSED (NOETHERVIM_NO_USER or vim.g.noethervim_no_user set)")
  end
end

return M
