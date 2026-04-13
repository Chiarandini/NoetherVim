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
  -- ── Neovim version ──────────────────────────────────────────────────
  h.start("Neovim version")
  local v = vim.version()
  if v.major > 0 or (v.major == 0 and v.minor >= 12) then
    h.ok(string.format("Neovim %d.%d.%d", v.major, v.minor, v.patch))
  else
    h.error(string.format(
      "Neovim %d.%d.%d — NoetherVim requires >= 0.12",
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

  -- ── LaTeX ────────────────────────────────────────────────────────────
  h.start("LaTeX (noethervim.bundles.latex / core vimtex)")
  check_exe("latexmk",  false)
  check_exe("pdflatex", false)
  if vim.fn.has("mac") == 1 then
    check_exe("skim",   false)
  else
    check_exe("zathura", false)
  end

  -- Treesitter latex parser: nvim-treesitter marks this parser as requiring
  -- tree-sitter generate, but NoetherVim overrides that so only a C compiler
  -- is needed. Check that cc is available and the parser is installed.
  if vim.fn.executable("cc") == 1 then
    h.ok("cc (C compiler — required for :TSInstall latex)")
  else
    h.error("cc not found — needed to compile the latex treesitter parser (:TSInstall latex)")
  end
  local parser_path = vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/parser/latex.so"
  if vim.uv.fs_stat(parser_path) then
    h.ok("latex treesitter parser installed")
  else
    h.warn("latex treesitter parser not installed — run :TSInstall latex")
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
    h.ok("Loaded user LSP overrides: " .. table.concat(nv._user_lsp, ", "))
  end
  if #nv._user_overrides > 0 then
    h.ok("Loaded user imperative overrides: " .. table.concat(nv._user_overrides, ", "))
  end

  -- ── Template version ─────────────────────────────────────────────────
  h.start("Template version")

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
    -- Upstream has no marker — version 1 (pre-release).
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
    h.info("No user plugins dir (optional) — add plugins to " .. user_plugins)
  end

  local ok_cfg, user_cfg = pcall(require, "user.config")
  if ok_cfg and type(user_cfg) ~= "table" then
    h.warn("lua/user/config.lua must return a table (got " .. type(user_cfg) .. ") — see templates/user/config.example.lua")
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
    h.warn("mapsearchleader is empty — search keymaps will collide with normal-mode keys")
  end

  -- ── Bundles ──────────────────────────────────────────────────────────
  h.start("Active bundles")
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    local active = {}
    for _, spec in ipairs(lazy.plugins()) do
      if spec._ and spec._.module then
        local mod = spec._.module
        if type(mod) == "string" then
          local bundle = mod:match("^noethervim%.bundles%.(.+)$")
          if bundle then active[bundle] = true end
        end
      end
    end
    -- Also detect via import paths in the lazy config
    for _, spec in ipairs(lazy.plugins()) do
      local imp = spec._ and spec._.imported
      if imp then
        local bundle = imp:match("^noethervim%.bundles%.(.+)$")
        if bundle then active[bundle] = true end
      end
    end
    if next(active) then
      local names = vim.tbl_keys(active)
      table.sort(names)
      for _, name in ipairs(names) do
        h.ok("noethervim.bundles." .. name)
      end
    else
      h.info("No bundles enabled")
    end
  else
    h.warn("lazy.nvim not available — cannot check active bundles")
  end
end

return M
