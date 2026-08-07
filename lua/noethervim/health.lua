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

--- Probe one `@requires` entry from a bundle's annotation header.
---
--- `note` requirements cannot be probed from Neovim -- a shared library a
--- plugin links against, "the REPL binary for your language", a vault path.
--- They are reported as info so they stay visible without pretending to a
--- pass/fail they cannot deliver.
---@param bundle string  `<category>.<name>`
---@param r noethervim.BundleRequirement
local function check_requirement(bundle, r)
  local detail = r.why and (r.label .. " -- " .. r.why) or r.label
  local hint = r.install and ("  [" .. r.install .. "]") or ""

  if r.kind == "note" then
    return h.info(("%s: %s%s"):format(bundle, detail, hint))
  end

  local present
  if r.kind == "exe" then
    present = vim.fn.executable(r.value) == 1
  elseif r.kind == "env" then
    present = (vim.env[r.value] or "") ~= ""
  elseif r.kind == "app" then
    -- GUI applications are not on PATH on macOS, so fs_stat the bundle.
    -- Elsewhere they usually are, so fall back to a normal probe.
    if vim.fn.has("mac") == 1 then
      present = vim.uv.fs_stat("/Applications/" .. r.value .. ".app") ~= nil
    else
      present = vim.fn.executable(r.value:lower()) == 1
    end
  end

  if present then
    h.ok(("%s: %s"):format(bundle, detail))
  elseif r.optional then
    h.warn(("%s: %s not found (optional)%s"):format(bundle, detail, hint))
  else
    h.error(("%s: %s not found%s"):format(bundle, detail, hint))
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

  -- ── Bundle requirements ─────────────────────────────────────────────
  -- Read from each active bundle's `@requires` annotation, which is the
  -- single source of truth shared with `:NoetherVim bundles` and the docs
  -- site. Adding a requirement means editing that bundle's header; nothing
  -- is listed here.
  do
    local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
    local root = init and vim.fn.fnamemodify(init, ":h:h:h")
    local keys = vim.tbl_keys(active_bundles)
    table.sort(keys)

    if root and #keys > 0 then
      h.start("Bundle requirements")
      local bundle_meta = require("noethervim.util.bundle_meta")
      local bundles_dir = root .. "/lua/noethervim/bundles"
      local found_any = false

      for _, key in ipairs(keys) do
        local meta = bundle_meta.get(bundles_dir, key)
        if meta then
          for _, err in ipairs(meta.errors) do h.error(err) end
          for _, req in ipairs(meta.requires) do
            found_any = true
            check_requirement(key, req)
          end
        end
      end

      if not found_any then
        h.ok("no external requirements for the active bundles")
      end
    end
  end

  -- ── Terminal ─────────────────────────────────────────────────────────
  -- Heuristic, and deliberately so: there is no reliable way to ask a
  -- terminal emulator what it supports from inside Neovim. `$TERM` and
  -- `$TERM_PROGRAM` are the only signals available, both are spoofable,
  -- and a multiplexer can sit in between and change the answer. Treat
  -- everything here as a hint that points at the right documentation, not
  -- as a verdict.
  h.start("Terminal (heuristic)")
  do
    local term         = vim.env.TERM or ""
    local term_program = vim.env.TERM_PROGRAM or ""

    if vim.fn.has("gui_running") == 1 then
      h.ok("Running in a GUI -- terminal capability checks do not apply")
    else
      h.info(("TERM=%s  TERM_PROGRAM=%s  COLORTERM=%s"):format(
        term ~= "" and term or "(unset)",
        term_program ~= "" and term_program or "(unset)",
        vim.env.COLORTERM or "(unset)"))

      -- True colour.
      if vim.o.termguicolors then
        h.ok("termguicolors is on")
      else
        h.warn("termguicolors is off -- the colorscheme will be approximated to 256 colours",
          { "Set vim.o.termguicolors = true in lua/user/options.lua if your terminal supports 24-bit colour" })
      end

      -- Shift+Enter as a distinct key. NoetherVim binds <S-CR> (smart-enter
      -- and friends), which a terminal can only deliver if it implements the
      -- kitty keyboard protocol; otherwise it sends a plain <CR> and the
      -- keymap silently never fires.
      local kkp = {
        ["xterm-kitty"]   = "kitty",
        ["xterm-ghostty"] = "Ghostty",
        ["alacritty"]     = "Alacritty",
        ["foot"]          = "foot",
        ["foot-extra"]    = "foot",
        ["rio"]           = "Rio",
      }
      local kkp_program = {
        WezTerm     = "WezTerm",
        ghostty     = "Ghostty",
        kitty       = "kitty",
        ["iTerm.app"] = "iTerm2 (3.5+)",
      }
      local known = kkp[term] or kkp_program[term_program]
      if known then
        h.ok(known .. " supports the kitty keyboard protocol -- <S-CR> is distinguishable from <CR>")
      elseif term_program == "Apple_Terminal" then
        h.warn("Apple Terminal cannot distinguish <S-CR> from <CR>",
          { "Keymaps bound to <S-CR> will not fire. Use kitty, Ghostty, WezTerm, or iTerm2 3.5+ if you want them." })
      else
        -- h.info takes a message only (h.warn / h.error are the ones that
        -- accept advice), so the hint goes inline.
        h.info("Could not identify the terminal's <S-CR> support.\n"
          .. "Test it: press <S-CR> in insert mode in a markdown list -- "
          .. "if a new list item appears, it works.")
      end

      if vim.env.TMUX then
        h.info("tmux detected. tmux needs `set -g extended-keys on` to forward\n"
          .. "<S-CR>; without it the inner terminal's support does not matter.")
      end

      -- Nerd Font. Not detectable at all -- the font lives in the terminal,
      -- which never reports it. Render samples instead and let the reader
      -- judge; boxes or blanks below mean the font is missing.
      local icons = require("noethervim.util.icons")
      h.info("Nerd Font is a baseline requirement (statusline, pickers and file\n"
        .. "icons all assume one). These should be glyphs, not boxes:  "
        .. table.concat({ icons.checkmark, icons.git, icons.find, icons.vim }, "  "))
    end
  end

  -- ── LaTeX (only when bundle is enabled) ──────────────────────────────
  -- Skip the whole section when the latex bundle isn't active, otherwise
  -- users without LaTeX get noise about missing latexmk / parsers.
  if bundle_active("languages.latex") or bundle_active("writing.zotero") then
    -- latexmk and pdflatex are covered by the bundle's `@requires`
    -- annotation above. What is left here is the checks that annotation
    -- cannot express: cross-platform PDF viewer discovery, and whether the
    -- treesitter parser can actually be built.
    h.start("LaTeX (noethervim.bundles.languages.latex / core vimtex)")

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

  -- ── Override drift ───────────────────────────────────────────────────
  -- An override keeps winning after the file it shadows changes, and nothing
  -- else in the system would say so: an upstream fix simply never arrives,
  -- and the resulting bug reproduces on one machine only.
  --
  -- Only overrides created through `:NoetherVim override` have a recorded
  -- baseline. One written by hand has nothing to compare against, and
  -- reporting it would be noise rather than information.
  do
    h.start("Override drift")
    local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
    local root = init and vim.fn.fnamemodify(init, ":h:h:h")

    if not root then
      h.info("Skipped -- cannot locate the NoetherVim source directory")
    else
      local base    = require("noethervim.util.override_base")
      local tracked = vim.tbl_count(base.load())
      local drifted = base.scan(root)

      if tracked == 0 then
        h.info("No overrides are tracked yet (created by `:NoetherVim override`)")
      elseif #drifted == 0 then
        h.ok(("%d tracked override(s), all current"):format(tracked))
      end

      for _, d in ipairs(drifted) do
        local name = vim.fn.fnamemodify(d.user_path, ":t:r")
        if d.current == nil then
          h.warn(("%s overrides %s, which no longer exists upstream"):format(
            vim.fn.fnamemodify(d.user_path, ":~"), d.rel))
        else
          h.warn(("%s changed since you overrode it -- compare with `:NoetherVim diff %s`, "
            .. "then re-run `:NoetherVim override` from it to clear this"):format(d.rel, name))
        end
      end
    end
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
  elseif ok_cfg and type(user_cfg) == "table" then
    local cfg_validator = require("noethervim.util.config")
    local errors, unknowns = cfg_validator.validate_user_config(user_cfg)
    for _, err in ipairs(errors) do h.warn(err) end
    if #unknowns > 0 then
      h.info("Unknown user.config keys (typo? or stale after distro update): "
        .. table.concat(unknowns, ", "))
    end
    if #errors == 0 and #unknowns == 0 then
      h.ok("user.config: schema valid")
    end
  end

  -- Colorscheme provenance. An interactive pick outlives the session that
  -- made it and takes priority over `colorscheme` in lua/user/config.lua, so
  -- "my colorscheme setting does nothing" has to be answerable from here.
  local cs = require("noethervim.util.colorscheme")
  h.info("Colorscheme: " .. cs.status())
  if cs.missing then
    h.warn(("colorscheme %q is not installed"):format(cs.missing),
      { "Enable the ui.colorscheme bundle, or add the plugin to lua/user/plugins/" })
  end
  if cs.dropped then
    h.warn(("saved colorscheme pick %q is no longer installed"):format(cs.dropped),
      { "Re-enable the bundle that provided it, or pick again with SearchLeader+C" })
  end
  if cs.source == "persisted" then
    h.info("The saved pick wins over `colorscheme` in lua/user/config.lua. "
      .. "Set colorscheme_persistence = false to make the config file authoritative.")
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

  -- ── Session / option drift ───────────────────────────────────────────
  -- Sessions saved while 'sessionoptions' contained `localoptions` can
  -- restore stale buffer-local values that override updated globals
  -- (e.g. spelllang stuck at "en_us" after the distro default moved to
  -- "en", or formatoptions frozen with `t` after the global rewrite).
  -- NoetherVim drops `localoptions` from the default `sessionoptions` to
  -- prevent new sessions from doing this, but pre-existing session files
  -- keep their stale state until re-saved.
  --
  -- We spot-check `spelllang` across loaded buffers: it is rarely set by
  -- ftplugins, so divergence from the global is a strong drift signal.
  -- formatoptions / textwidth are skipped because legitimate ftplugins
  -- routinely set them (python, lua, gitcommit, ...), which would drown
  -- the check in false positives.
  h.start("Session / option drift")
  do
    local global_sl = vim.go.spelllang
    local drift = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].buflisted
        and vim.bo[buf].buftype == ""
      then
        local local_sl = vim.bo[buf].spelllang
        if local_sl ~= "" and local_sl ~= global_sl then
          local name = vim.api.nvim_buf_get_name(buf)
          if name == "" then name = "[buffer " .. buf .. "]" end
          table.insert(drift, string.format(
            "  %s -- spelllang=%s (global=%s)",
            vim.fn.fnamemodify(name, ":~:."), local_sl, global_sl))
        end
      end
    end
    if #drift == 0 then
      h.ok("No spelllang drift across loaded buffers")
    else
      h.warn(("%d buffer(s) have spelllang differing from global -- "
        .. "likely a stale session restoring `localoptions`:"):format(#drift))
      for _, line in ipairs(drift) do h.info(line) end
      h.info("Fix: re-save the session with :SaveSession, or delete the "
        .. "stale session file under " .. vim.fn.stdpath("state") .. "/sessions/")
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
