-- NoetherVim inspection, comparison, and status commands.
-- Loaded at the end of noethervim.setup().
-- All commands live under the :NoetherVim namespace.
-- See :help noethervim-inspect for documentation.

local SearchLeader = require("noethervim.util").search_leader
local Snacks = require("snacks")

local M = {}

-- ── Helpers ──────────────────────────────────────────────────────

--- Resolve the root directory of the NoetherVim installation.
local function noethervim_root()
  local init = vim.api.nvim_get_runtime_file("lua/noethervim/init.lua", false)[1]
  if not init then return nil end
  -- init is <root>/lua/noethervim/init.lua → go up 3 levels
  return vim.fn.fnamemodify(init, ":h:h:h")
end

--- Return the effective NoetherVim root: the dev directory when
--- vim.g.noethervim_dev is set, otherwise the installed location.
local function effective_root()
  if vim.g.noethervim_dev then
    return vim.fn.expand(vim.g.noethervim_dev)
  end
  return noethervim_root()
end

--- Resolve the user config lua/user/ directory.
local function user_dir()
  return vim.fn.stdpath("config") .. "/lua/user/"
end

--- Get snapshot data from the init module.
local function snapshots()
  return require("noethervim")._snapshots
end

--- Confirm callback for pickers that should open files readonly.
--- Prevents accidental edits to distribution source or installed plugins.
--- In dev mode (vim.g.noethervim_dev), NoetherVim source files open editable.
local function confirm_readonly(picker, item)
  picker:close()
  if not item or not item.file then return end
  -- Resolve the full path (item.file may be relative to item.cwd)
  local file = Snacks.picker.util.path(item)
  if not file then return end
  -- In dev mode, open NoetherVim source files as editable
  local editable = false
  if vim.g.noethervim_dev then
    local dev = vim.fs.normalize(vim.fn.expand(vim.g.noethervim_dev))
    editable = vim.startswith(vim.fs.normalize(file), dev)
  end
  if editable then
    vim.cmd("edit " .. vim.fn.fnameescape(file))
  else
    vim.cmd("view " .. vim.fn.fnameescape(file))
    vim.bo.readonly = true
    vim.bo.modifiable = false
  end
  if item.pos and item.pos[1] and item.pos[1] > 0 then
    pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] or 0 })
    vim.cmd("norm! zzzv")
  end
end

-- ── Bundle catalog ──────────────────────────────────────────────
-- Static metadata for the :NoetherVim bundles picker.
-- When adding a new bundle, add an entry here too.
-- See docs/bundle-development.md for details.

local bundle_catalog = {
  -- Languages
  { name = "rust",           cat = "Languages",  desc = "rustaceanvim — macro expansion, runnables, crate graph" },
  { name = "go",             cat = "Languages",  desc = "go.nvim — test gen, struct tags, interface impl" },
  { name = "java",           cat = "Languages",  desc = "nvim-jdtls — proper Java LSP support" },
  { name = "python",         cat = "Languages",  desc = "venv-selector — virtual environment switching" },
  { name = "latex",          cat = "Languages",  desc = "VimTeX + noethervim-tex (snippets, textobjects)" },
  { name = "latex-zotero",   cat = "Languages",  desc = "Zotero citation picker" },
  { name = "web-dev",        cat = "Languages",  desc = "template-string auto-conversion + color preview" },
  -- Tools
  { name = "debug",          cat = "Tools",      desc = "nvim-dap + UI (Python, Lua, JS/TS, Go)" },
  { name = "test",           cat = "Tools",      desc = "neotest test runner" },
  { name = "repl",           cat = "Tools",      desc = "iron.nvim interactive REPL" },
  { name = "task-runner",    cat = "Tools",      desc = "overseer.nvim + compiler.nvim (run file)" },
  { name = "database",       cat = "Tools",      desc = "vim-dadbod + UI + SQL completion" },
  { name = "http",           cat = "Tools",      desc = "kulala.nvim HTTP/REST/gRPC/GraphQL client" },
  { name = "git",            cat = "Tools",      desc = "Fugit2, diffview, git-conflict" },
  { name = "ai",             cat = "Tools",      desc = "CodeCompanion (Anthropic, OpenAI, Gemini, Ollama)" },
  { name = "refactoring",    cat = "Tools",      desc = "extract function/variable/block" },
  -- Navigation & editing
  { name = "harpoon",        cat = "Navigation", desc = "fast per-project file marks" },
  { name = "flash",          cat = "Navigation", desc = "enhanced f/t and / motions with labels" },
  { name = "projects",       cat = "Navigation", desc = "project switcher via snacks.picker" },
  { name = "editing-extras", cat = "Navigation", desc = "argmark + decorative comment boxes" },
  { name = "neoclip",        cat = "Navigation", desc = "persistent clipboard history" },
  -- Writing & notes
  { name = "markdown",       cat = "Writing",    desc = "render, preview, tables, math, image paste" },
  { name = "obsidian",       cat = "Writing",    desc = "Obsidian vault integration (pair with markdown bundle)" },
  { name = "neorg",          cat = "Writing",    desc = ".norg wiki / note-taking" },
  { name = "translation",    cat = "Writing",    desc = "in-editor translation (Google, Yandex)" },
  -- Terminal & environment
  { name = "better-term",    cat = "Terminal",   desc = "named/numbered terminal windows" },
  { name = "tmux",           cat = "Terminal",   desc = "automatic tmux window naming" },
  { name = "remote-dev",     cat = "Terminal",   desc = "distant.nvim SSH editing" },
  -- UI & appearance
  { name = "colorscheme",    cat = "UI",         desc = "10 popular themes + persistence" },
  { name = "eye-candy",      cat = "UI",         desc = "animations, scrollbar, block display" },
  { name = "minimap",        cat = "UI",         desc = "sidebar minimap with git/diagnostic markers" },
  { name = "helpview",       cat = "UI",         desc = "rendered :help pages" },
  -- Practice & utilities
  { name = "training",       cat = "Practice",   desc = "vim-be-good, speedtyper, typr" },
  { name = "dev-tools",      cat = "Practice",   desc = "StartupTime benchmarking, Luapad scratchpad" },
  { name = "presentation",   cat = "Practice",   desc = "presenting.nvim + showkeys" },
  { name = "hardtime",       cat = "Practice",   desc = "motion habit trainer" },
}

-- Category display order (matches init.lua.example)
local cat_order = { Languages = 1, Tools = 2, Navigation = 3, Writing = 4, Terminal = 5, UI = 6, Practice = 7 }

-- ── File & Grep Pickers (Phase 5) ───────────────────────────────

function M.files()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  Snacks.picker.files({ cwd = root, title = "NoetherVim Source", confirm = confirm_readonly })
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

function M.bundles()
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end

  -- Detect which bundles are enabled via lazy.nvim's imported modules
  local enabled = {}
  local ok, lazy_cfg = pcall(require, "lazy.core.config")
  if ok and lazy_cfg.spec then
    for _, mod in ipairs(lazy_cfg.spec.modules) do
      local name = mod:match("^noethervim%.bundles%.(.+)$")
      if name then enabled[name] = true end
    end
  end

  local icons = require("noethervim.util.icons")
  local bundles_dir = root .. "/lua/noethervim/bundles"
  local items = {}
  for _, entry in ipairs(bundle_catalog) do
    local is_enabled = enabled[entry.name] or false
    table.insert(items, {
      text = entry.cat .. " " .. entry.name .. " " .. entry.desc .. (is_enabled and " enabled" or ""),
      file = vim.fs.joinpath(bundles_dir, entry.name .. ".lua"),
      cat_order = cat_order[entry.cat] or 99,
      cat_text = "[" .. entry.cat .. "]",
      bundle_name = entry.name,
      desc = entry.desc,
      enabled = is_enabled,
    })
  end

  table.sort(items, function(a, b)
    if a.cat_order ~= b.cat_order then return a.cat_order < b.cat_order end
    return a.bundle_name < b.bundle_name
  end)

  Snacks.picker({
    title   = "NoetherVim Bundles",
    items   = items,
    preview = "file",
    confirm = confirm_readonly,
    format  = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-14s", item.cat_text), "SnacksPickerLabel" }
      ret[#ret + 1] = { string.format("%-18s", item.bundle_name) }
      if item.enabled then
        ret[#ret + 1] = { icons.checkmark .. " ", "DiagnosticOk" }
      else
        ret[#ret + 1] = { "  " }
      end
      ret[#ret + 1] = { item.desc, "Comment" }
      return ret
    end,
  })
end

function M.plugins()
  local plugin_dir = vim.fn.stdpath("data") .. "/lazy"
  if vim.fn.isdirectory(plugin_dir) == 0 then
    return vim.notify("NoetherVim: no lazy plugin directory found", vim.log.levels.ERROR)
  end
  Snacks.picker.files({ cwd = plugin_dir, title = "Installed Plugins", confirm = confirm_readonly })
end

-- ── Status (Phase 4.3) ──────────────────────────────────────────

function M.status()
  local nv = require("noethervim")
  local lines = {}

  if nv._user_loaded then
    table.insert(lines, "User overrides: ACTIVE")
  else
    table.insert(lines, "User overrides: DISABLED")
    if vim.env.NOETHERVIM_NO_USER then
      table.insert(lines, "  (NOETHERVIM_NO_USER is set)")
    end
    if vim.g.noethervim_no_user then
      table.insert(lines, "  (vim.g.noethervim_no_user is set)")
    end
  end

  if #nv._user_modules > 0 then
    table.insert(lines, "Loaded modules: " .. table.concat(nv._user_modules, ", "))
  end
  if #nv._user_lsp > 0 then
    table.insert(lines, "Loaded LSP overrides: " .. table.concat(nv._user_lsp, ", "))
  end
  if #nv._user_overrides > 0 then
    table.insert(lines, "Loaded overrides: " .. table.concat(nv._user_overrides, ", "))
  end
  if #nv._user_modules == 0 and #nv._user_lsp == 0 and #nv._user_overrides == 0 and nv._user_loaded then
    table.insert(lines, "No user override files found.")
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "NoetherVim" })
end

-- ── Keymap source helpers ────────────────────────────────────────

-- Characters that are special in Vim's magic-mode regex and need
-- escaping.  Notably, ( ) { } + are NOT special in magic mode —
-- escaping them would turn them INTO regex operators (\(, \+, etc.).
local VIM_ESCAPE_CHARS = "/\\[].*^$~"

-- Vim regex character class matching either quote type (" or ').
-- Lua source code uses both interchangeably.
local Q = [=[["']]=]

--- Compare two keymap snapshots for equality.
--- Callback functions from nvim_get_keymap get new references on each
--- call, so identity comparison fails for Neovim defaults.  When both
--- have callbacks and the same rhs, treat them as equal.
local function same_mapping(a, b)
  if a.rhs ~= b.rhs then return false end
  if a.callback == b.callback then return true end
  if a.callback and b.callback then return true end
  return false
end

--- Build Vim search patterns that might locate how `lhs` is written
--- in source code.  Leaders are resolved at runtime so we try every
--- plausible notation, most-specific first.
---
--- Pattern philosophy:
---   1. Leader-specific (most reliable)
---   2. Context-aware quoted: "lhs" preceded by { ( , or ..
---      (avoids matching mode strings like "n" in vim.keymap.set)
---   3. Toggle-strip for [x / ]x style keymaps
---   4. Vimscript mapping commands
---   5. Bare unquoted (last resort, only for longer keymaps)
local function keymap_search_patterns(lhs)
  local sl           = vim.g.mapsearchleader or "<Space>"
  local resolved_sl  = vim.api.nvim_replace_termcodes(sl, true, true, true)
  local leader       = vim.g.mapleader or "\\"
  local localleader  = vim.g.maplocalleader or "\\"

  local starts_with_leader      = #leader > 0      and lhs:sub(1, #leader) == leader
  local starts_with_localleader = #localleader > 0  and lhs:sub(1, #localleader) == localleader
  local starts_with_sl          = #resolved_sl > 0  and lhs:sub(1, #resolved_sl) == resolved_sl

  local pats = {}

  -- ── 1. Leader-specific ────────────────────────────────────────
  -- <Leader>tail — matches `"<leader>tail"` or `'<leader>tail'`
  if starts_with_leader then
    local tail = vim.fn.escape(lhs:sub(#leader + 1), VIM_ESCAPE_CHARS)
    pats[#pats + 1] = [[\c<Leader>]] .. tail .. Q
    pats[#pats + 1] = [[\c<Leader>]] .. tail
  end

  -- <LocalLeader>tail
  if starts_with_localleader then
    local tail = vim.fn.escape(lhs:sub(#localleader + 1), VIM_ESCAPE_CHARS)
    pats[#pats + 1] = [[\c<LocalLeader>]] .. tail .. Q
    pats[#pats + 1] = [[\c<LocalLeader>]] .. tail
  end

  -- SearchLeader concatenation: SearchLeader .. "tail"
  -- For single-char tails, the generic `.. "x"` pattern matches noise
  -- like `dir .. "/"` or `mkdir(_, "p")`.  Match the literal variable
  -- name `SearchLeader` instead — it's consistent across all distro specs.
  -- For multi-char tails, the generic `.. "tail"` is specific enough.
  if starts_with_sl then
    local tail_raw = lhs:sub(#resolved_sl + 1)
    local tail_esc = vim.fn.escape(tail_raw, VIM_ESCAPE_CHARS)
    -- Specific: SearchLeader .. "tail" (reliable for any tail length)
    pats[#pats + 1] = [[\cSearchLeader\s*\.\.\s*]] .. Q .. tail_esc .. Q
    -- Generic: .. "tail" (only for multi-char tails)
    if #tail_raw > 1 then
      pats[#pats + 1] = [[\C\.\.\s*]] .. Q .. tail_esc .. Q
    end
    -- keytrans notation for special-key tails (<space>, <C-B>, etc.)
    local tail_notation = vim.fn.keytrans(tail_raw)
    if tail_notation ~= tail_raw then
      local notation_esc = vim.fn.escape(tail_notation, VIM_ESCAPE_CHARS)
      pats[#pats + 1] = [[\c\.\.\s*]] .. Q .. notation_esc .. Q
      pats[#pats + 1] = [[\c]] .. Q .. notation_esc .. Q
    end
  end

  -- ── 2. Context-aware quoted ───────────────────────────────────
  -- Match "lhs" or 'lhs' in keymap-defining contexts.
  -- Q matches either ' or " (Lua uses both interchangeably).
  --
  -- Use \C (case-sensitive) for short keymaps so that "S" doesn't
  -- match "s" (a different keymap); use \c for longer keymaps where
  -- case differences in <Key> notation need to be tolerated.
  local escaped = vim.fn.escape(lhs, VIM_ESCAPE_CHARS)
  local case = #lhs <= 2 and [[\C]] or [[\c]]

  -- Comma-preceded: matches the 2nd arg of vim.keymap.set("mode", "lhs")
  -- without matching the 1st arg (mode string).  Critical for single-char
  -- keymaps like "n" where mode == lhs.
  pats[#pats + 1] = case .. [[,\s*]] .. Q .. escaped .. Q
  -- Brace/paren/comma-preceded: also matches lazy spec { "lhs", ... }
  pats[#pats + 1] = case .. [=[[{,(]\s*]=] .. Q .. escaped .. Q
  pats[#pats + 1] = case .. [[\.\.\s*]] .. Q .. escaped .. Q
  -- Case-insensitive retry if lhs contains <Key> notation
  if #lhs <= 2 and lhs:find("<") then
    pats[#pats + 1] = [=[\c[{,(]\s*]=] .. Q .. escaped .. Q
  end

  -- ── 3. Toggle keymaps ─────────────────────────────────────────
  -- toggle("base", ...) prepends [ or ].
  -- AFTER context-aware so that direct definitions like
  -- map("[<C-L>", ...) are found first.
  if lhs:match("^[%[%]]") and #lhs > 2 then
    local base = vim.fn.escape(lhs:sub(2), VIM_ESCAPE_CHARS)
    pats[#pats + 1] = case .. [=[[{,(]\s*]=] .. Q .. base .. Q
  end

  -- ── 4. keytrans notation ────────────────────────────────────────
  -- The API resolves special keys (e.g. <Space> → literal space).
  -- User spec files often write `"<space>h"` — keytrans converts the
  -- resolved lhs back to notation form so we can match it.
  local lhs_notation = vim.fn.keytrans(lhs)
  if lhs_notation ~= lhs then
    local notation_esc = vim.fn.escape(lhs_notation, VIM_ESCAPE_CHARS)
    pats[#pats + 1] = [=[\c[{,(]\s*]=] .. Q .. notation_esc .. Q
    pats[#pats + 1] = [[\c]] .. Q .. notation_esc .. Q
  end

  -- ── 5. Vimscript mappings ─────────────────────────────────────
  pats[#pats + 1] = [[\cmap\s\+]] .. escaped
  if lhs_notation ~= lhs then
    local notation_esc = vim.fn.escape(lhs_notation, VIM_ESCAPE_CHARS)
    pats[#pats + 1] = [[\cmap\s\+]] .. notation_esc
  end

  -- ── 6. Bare unquoted (last resort) ────────────────────────────
  -- Only useful for multi-char keymaps; for single/double-char
  -- keymaps it matches noise everywhere.
  if #lhs > 2 then
    pats[#pats + 1] = [[\c]] .. escaped
  end

  -- ── Synonym expansion ─────────────────────────────────────────
  -- <M- ↔ <A- (API normalises <A- to <M-), <lt> → <
  local extra = {}
  for _, p in ipairs(pats) do
    if p:find("<M%-") then
      extra[#extra + 1] = (p:gsub("<M%-", "<A-"))
    elseif p:find("<A%-") then
      extra[#extra + 1] = (p:gsub("<A%-", "<M-"))
    end
    if p:find("<lt>") then
      extra[#extra + 1] = (p:gsub("<lt>", "<"))
    end
  end
  for _, e in ipairs(extra) do pats[#pats + 1] = e end

  return pats
end

--- Build plain-text needles for detecting which core file defines a
--- keymap.  Used for content:find(needle, 1, true) matching.
local function keymap_file_needles(lhs)
  local sl          = vim.g.mapsearchleader or "<Space>"
  local resolved_sl = vim.api.nvim_replace_termcodes(sl, true, true, true)
  local leader      = vim.g.mapleader or "\\"
  local localleader = vim.g.maplocalleader or "\\"

  local needles = {}
  if #leader > 0 and lhs:sub(1, #leader) == leader then
    needles[#needles + 1] = "<leader>" .. lhs:sub(#leader + 1)
  end
  if #localleader > 0 and lhs:sub(1, #localleader) == localleader then
    needles[#needles + 1] = "<localleader>" .. lhs:sub(#localleader + 1)
  end
  if #resolved_sl > 0 and lhs:sub(1, #resolved_sl) == resolved_sl then
    local tail = lhs:sub(#resolved_sl + 1)
    needles[#needles + 1] = '"' .. tail .. '"'
    needles[#needles + 1] = "'" .. tail .. "'"
  end
  if lhs:match("^[%[%]]") then
    local base = lhs:sub(2)
    -- Only add toggle-strip needles for multi-char bases; single-char
    -- bases like "e" or "q" match dashboard keys and other noise.
    if #base > 1 then
      needles[#needles + 1] = '"' .. base .. '"'
      needles[#needles + 1] = "'" .. base .. "'"
    end
  end
  -- keytrans notation: API resolves <Space> to literal space, etc.
  -- User files write "<space>h" — keytrans gives us "<Space>h".
  local lhs_notation = vim.fn.keytrans(lhs)
  if lhs_notation ~= lhs then
    needles[#needles + 1] = lhs_notation
  end
  -- Quoted full lhs (both quote types; more specific than raw)
  needles[#needles + 1] = '"' .. lhs .. '"'
  needles[#needles + 1] = "'" .. lhs .. "'"
  needles[#needles + 1] = lhs

  -- Synonyms: <M- ↔ <A-, <lt> → <
  local extra = {}
  for _, n in ipairs(needles) do
    if n:find("<M%-") then extra[#extra + 1] = (n:gsub("<M%-", "<A-")) end
    if n:find("<lt>") then extra[#extra + 1] = (n:gsub("<lt>", "<")) end
  end
  for _, e in ipairs(extra) do needles[#needles + 1] = e end
  return needles
end

--- Files that may define keymaps via vim.keymap.set (not lazy specs).
--- Includes core modules, plugin/bundle config() functions, and user keymaps.
local function keymap_candidate_files(root)
  local files = {
    root .. "/lua/noethervim/keymaps.lua",
    root .. "/lua/noethervim/toggles.lua",
    root .. "/lua/noethervim/inspect.lua",
    root .. "/lua/noethervim/commands.lua",
    root .. "/lua/noethervim/autocmds.lua",
    root .. "/lua/noethervim/init.lua",
  }
  -- Plugin and bundle files (keymaps set in config() functions)
  for _, dir in ipairs({
    root .. "/lua/noethervim/plugins",
    root .. "/lua/noethervim/bundles",
  }) do
    local handle = vim.uv.fs_scandir(dir)
    if handle then
      while true do
        local name, ftype = vim.uv.fs_scandir_next(handle)
        if not name then break end
        if (ftype == "file" or ftype == "link") and name:match("%.lua$") then
          files[#files + 1] = vim.fs.joinpath(dir, name)
        end
      end
    end
  end
  -- User keymaps file (vim.keymap.set calls outside lazy specs)
  local ukeymaps = vim.fn.stdpath("config") .. "/lua/user/keymaps.lua"
  if vim.uv.fs_stat(ukeymaps) then
    files[#files + 1] = ukeymaps
  end
  return files
end

-- ── Shared: jump to keymap source definition ────────────────────
-- Used by diff_keymaps (confirm handler) and the guide (<CR>).

--- Jump to the source definition of a keymap.
--- Opens the file containing the definition (readonly in non-dev mode)
--- and positions the cursor on the defining line.
---
--- @param mode string   Keymap mode ("n", "i", "v", etc.)
--- @param lhs  string   Resolved keymap lhs (from nvim_get_keymap)
--- @param opts? table   { source = string? }  Optional lazy handler source hint.
function M.jump_to_keymap(mode, lhs, opts)
  opts = opts or {}
  local root = effective_root()
  if not root then return end
  local readonly = not vim.g.noethervim_dev
  local patterns = keymap_search_patterns(lhs)

  --- Try all search patterns in the current buffer.
  --- Two passes: first prefers lines where a compatible mode appears
  --- (avoids jumping to a different-mode definition of the same lhs,
  --- e.g. "i" <M-BS> vs "c" <M-BS>).  Falls back to any match.
  local function try_patterns_in_buffer()
    local mode_strs = { '"' .. mode .. '"' }
    if mode == "s" or mode == "x" then
      mode_strs[#mode_strs + 1] = '"v"'
    elseif mode == "v" then
      mode_strs[#mode_strs + 1] = '"x"'
    end

    local function line_has_mode(line)
      for _, mq in ipairs(mode_strs) do
        if line:find(mq, 1, true) then return true end
      end
      return false
    end

    -- Pass 1: mode-matching lines only
    for _, pat in ipairs(patterns) do
      local found = vim.fn.search(pat, "w")
      while found > 0 do
        local line = vim.fn.getline(found)
        if line:match("^%s*%-%-") then
          found = vim.fn.search(pat, "W")
        elseif line_has_mode(line) then
          return true
        else
          found = vim.fn.search(pat, "W")
        end
      end
    end
    -- Pass 2: any non-comment match
    for _, pat in ipairs(patterns) do
      local found = vim.fn.search(pat, "w")
      while found > 0 and vim.fn.getline(found):match("^%s*%-%-") do
        found = vim.fn.search(pat, "W")
      end
      if found > 0 then return true end
    end
    return false
  end

  local function open_file(path)
    vim.cmd((readonly and "view " or "edit ") .. vim.fn.fnameescape(path))
    if readonly then vim.bo.readonly = true; vim.bo.modifiable = false end
  end

  -- Resolve source file: use hint when available, else scan candidates.
  local file = opts.source
  if not file or not vim.uv.fs_stat(file) then
    file = nil
    local needles = keymap_file_needles(lhs)
    local candidates = keymap_candidate_files(root)
    for pass = 1, 2 do
      for _, path in ipairs(candidates) do
        if vim.uv.fs_stat(path) then
          local content = table.concat(vim.fn.readfile(path), "\n"):lower()
          for _, needle in ipairs(needles) do
            local is_raw = (needle == lhs)
            if (pass == 1 and not is_raw) or (pass == 2 and is_raw) then
              if content:find(needle:lower(), 1, true) then
                file = path
                break
              end
            end
          end
          if file then break end
        end
      end
      if file then break end
    end
    file = file or candidates[1]
  end

  open_file(file)
  if try_patterns_in_buffer() then return end

  -- Search failed in the primary file.  Try user plugin/keymaps files.
  local udir = user_dir()
  local user_candidates = {}
  if opts.source then
    local src_name = vim.fn.fnamemodify(opts.source, ":t")
    user_candidates[#user_candidates + 1] = udir .. "plugins/" .. src_name
  end
  user_candidates[#user_candidates + 1] = udir .. "keymaps.lua"
  local user_plugins = udir .. "plugins/"
  local handle = vim.uv.fs_scandir(user_plugins)
  if handle then
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle)
      if not name then break end
      if (ftype == "file" or ftype == "link") and name:match("%.lua$") then
        user_candidates[#user_candidates + 1] = user_plugins .. name
      end
    end
  end

  local seen = { [file] = true }
  for _, upath in ipairs(user_candidates) do
    if not seen[upath] and vim.uv.fs_stat(upath) then
      seen[upath] = true
      open_file(upath)
      if try_patterns_in_buffer() then return end
    end
  end
end

-- ── Comparison: Keymaps (Phase 6.1) ─────────────────────────────

function M.diff_keymaps()
  local snap = snapshots()
  if not snap.keymaps_before or not snap.keymaps_after then
    return vim.notify("NoetherVim: no keymap snapshots (user overrides may be disabled)", vim.log.levels.WARN)
  end

  local before = snap.keymaps_before
  local after  = snap.keymaps_after
  local items  = {}

  -- Map resolved keymaps to lazy plugin modules for source navigation.
  -- `managed` includes ALL lazy handler keys (even user-only dev plugins
  -- that keymap_sources can't map to a spec file).
  local key_sources, lazy_managed = require("noethervim.util").keymap_sources()

  -- Baseline: keymaps that existed before NoetherVim core loaded.
  -- Keymaps present in baseline, unchanged by core AND user, and not
  -- from any lazy spec are Neovim defaults — skip them.
  local baseline = snap.keymaps_baseline or {}

  -- Collect all keys from both snapshots
  local all_keys = {}
  for k in pairs(before) do all_keys[k] = true end
  for k in pairs(after)  do all_keys[k] = true end

  for key in pairs(all_keys) do
    local bl = baseline[key]
    local b  = before[key]
    local a  = after[key]
    local tag, mode, lhs, desc

    if a and not b then
      -- New keymap added by user
      tag  = "[USER]"
      mode = a.mode
      lhs  = a.lhs
      desc = a.desc
    elseif b and not a then
      -- Keymap deleted by user
      tag  = "[DELETED]"
      mode = b.mode
      lhs  = b.lhs
      desc = b.desc
    elseif a and b then
      -- Check if changed
      local changed = (a.rhs ~= b.rhs) or (a.callback ~= b.callback)
      if changed then
        tag  = "[OVERRIDE]"
        mode = a.mode
        lhs  = a.lhs
        desc = a.desc ~= "" and a.desc or b.desc
      else
        -- Skip Neovim defaults: present in baseline, unchanged by
        -- core and user, and not managed by any lazy spec.
        if bl and not key_sources[key] and not lazy_managed[key]
           and same_mapping(bl, b) then
          goto continue
        end
        tag  = "[CORE]"
        mode = a.mode
        lhs  = a.lhs
        desc = a.desc
      end
    end

    if tag then
      local display_lhs = lhs:gsub(" ", "␣"):gsub("<lt>", "<")
      table.insert(items, {
        text   = tag .. " " .. mode .. " " .. display_lhs .. " " .. desc,
        tag    = tag,
        mode   = mode,
        lhs    = lhs,
        desc   = desc,
        source = key_sources[key],
      })
    end
    ::continue::
  end

  -- Re-classify [CORE] keymaps from lazy handlers: if none of the
  -- file-detection needles match the attributed distro spec file,
  -- the key was added by a user spec override → show as [USER].
  local reclassify_cache = {}
  for _, item in ipairs(items) do
    if item.tag == "[CORE]" and item.source then
      local src = item.source
      if reclassify_cache[src] == nil then
        reclassify_cache[src] = vim.uv.fs_stat(src)
          and table.concat(vim.fn.readfile(src), "\n") or ""
      end
      local content = reclassify_cache[src]
      local needles = keymap_file_needles(item.lhs)
      local found_in_distro = false
      for _, needle in ipairs(needles) do
        -- Skip the raw lhs: too broad, matches comments/descriptions.
        -- Use case-sensitive matching so "fB" doesn't match distro's "fb".
        if needle ~= item.lhs and content:find(needle, 1, true) then
          found_in_distro = true
          break
        end
      end
      -- Retry case-insensitive for <Leader>/<LocalLeader> notation
      -- differences (e.g. <Leader> vs <leader>).
      if not found_in_distro then
        local content_lower = content:lower()
        for _, needle in ipairs(needles) do
          if needle ~= item.lhs and needle:find("<[Ll]") then
            if content_lower:find(needle:lower(), 1, true) then
              found_in_distro = true
              break
            end
          end
        end
      end
      if not found_in_distro then
        item.tag = "[USER]"
        item.text = "[USER]" .. item.text:sub(7)
      end
    end
  end

  -- Sort: USER/OVERRIDE/DELETED first, then by mode+lhs
  local tag_order = { ["[USER]"] = 1, ["[OVERRIDE]"] = 2, ["[DELETED]"] = 3, ["[CORE]"] = 4 }
  local tag_hl = {
    ["[USER]"]     = "DiagnosticOk",
    ["[OVERRIDE]"] = "DiagnosticWarn",
    ["[DELETED]"]  = "DiagnosticError",
    ["[CORE]"]     = "Comment",
  }
  table.sort(items, function(a, b)
    local oa = tag_order[a.tag] or 5
    local ob = tag_order[b.tag] or 5
    if oa ~= ob then return oa < ob end
    if a.mode ~= b.mode then return a.mode < b.mode end
    return a.lhs < b.lhs
  end)

  Snacks.picker({
    title  = "NoetherVim Keymap Comparison",
    items  = items,
    layout = { preset = "select", preview = "main" },
    win = { input = { keys = {
      -- Space inserts ␣ so the search matches the visible display
      ["<Space>"] = {
        function() vim.api.nvim_feedkeys("␣", "n", true) end,
        mode = { "i" }, nowait = true, desc = "insert ␣",
      },
    } } },
    format = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-11s", item.tag), tag_hl[item.tag] or "Comment" }
      ret[#ret + 1] = { string.format(" [%s] ", item.mode), "Special" }
      -- Replace literal spaces with ␣ so SearchLeader prefixes are visible
      ret[#ret + 1] = { string.format("%-16s ", item.lhs:gsub(" ", "␣"):gsub("<lt>", "<")), "SnacksPickerFile" }
      ret[#ret + 1] = { item.desc, "Comment" }
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      if item.tag == "[USER]" or item.tag == "[OVERRIDE]" then
        local file = user_dir() .. "keymaps.lua"
        if vim.uv.fs_stat(file) then
          vim.cmd("edit " .. vim.fn.fnameescape(file))
          vim.fn.search(vim.fn.escape(item.lhs, VIM_ESCAPE_CHARS), "w")
        end
        return
      end
      M.jump_to_keymap(item.mode, item.lhs, { source = item.source })
    end,
  })
end

-- ── Comparison: Options (Phase 6.2) ─────────────────────────────

function M.diff_options()
  local snap = snapshots()
  if not snap.options_before or not snap.options_after then
    return vim.notify("NoetherVim: no option snapshots (user overrides may be disabled)", vim.log.levels.WARN)
  end

  local before = snap.options_before
  local after  = snap.options_after
  local items  = {}

  for name, default_val in pairs(before) do
    local current_val = after[name]
    local tag = (current_val ~= default_val) and "[OVERRIDE]" or "[CORE]"
    table.insert(items, {
      text        = tag .. " " .. name .. " " .. tostring(current_val) .. " " .. tostring(default_val),
      tag         = tag,
      name        = name,
      current     = tostring(current_val),
      default_val = tostring(default_val),
    })
  end

  local tag_order = { ["[OVERRIDE]"] = 1, ["[CORE]"] = 2 }
  local tag_hl = {
    ["[OVERRIDE]"] = "DiagnosticWarn",
    ["[CORE]"]     = "Comment",
  }
  table.sort(items, function(a, b)
    local oa = tag_order[a.tag] or 3
    local ob = tag_order[b.tag] or 3
    if oa ~= ob then return oa < ob end
    return a.name < b.name
  end)

  Snacks.picker({
    title  = "NoetherVim Option Comparison",
    items  = items,
    layout = { preset = "select", preview = "main" },
    format = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-11s", item.tag), tag_hl[item.tag] or "Comment" }
      ret[#ret + 1] = { string.format(" %-20s", item.name), "SnacksPickerFile" }
      ret[#ret + 1] = { " = " }
      ret[#ret + 1] = { string.format("%-12s", item.current), item.tag == "[OVERRIDE]" and "DiagnosticWarn" or "SnacksPickerFile" }
      ret[#ret + 1] = { " (default: ", "Comment" }
      ret[#ret + 1] = { item.default_val, "Comment" }
      ret[#ret + 1] = { ")", "Comment" }
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      local file, readonly
      if item.tag == "[OVERRIDE]" then
        file = user_dir() .. "options.lua"
        readonly = false
      else
        local root = effective_root()
        if root then file = root .. "/lua/noethervim/options.lua" end
        readonly = not vim.g.noethervim_dev
      end
      if file and vim.uv.fs_stat(file) then
        vim.cmd((readonly and "view " or "edit ") .. vim.fn.fnameescape(file))
        if readonly then vim.bo.readonly = true; vim.bo.modifiable = false end
        vim.fn.search(vim.fn.escape(item.name, "/\\[]{}().*+^$~"), "w")
      end
    end,
  })
end

-- ── Debug: keymap source diagnostic ─────────────────────────────

--- Test source-file detection and search-pattern matching for every
--- keymap.  Opens a scratch buffer with OK/MISS status per keymap.
--- Run with :NoetherVim debug keymaps
function M.debug_keymaps()
  local snap = snapshots()
  if not snap.keymaps_before or not snap.keymaps_after then
    return vim.notify("NoetherVim: no keymap snapshots", vim.log.levels.WARN)
  end

  local key_sources, lazy_managed = require("noethervim.util").keymap_sources()
  local root = effective_root()
  if not root then return end

  local baseline   = snap.keymaps_baseline or {}
  local before     = snap.keymaps_before
  local after      = snap.keymaps_after
  local candidates = keymap_candidate_files(root)

  -- Also include user plugin files as search candidates
  local udir = user_dir() .. "plugins/"
  local user_files = {}
  local handle = vim.uv.fs_scandir(udir)
  if handle then
    while true do
      local name, ftype = vim.uv.fs_scandir_next(handle)
      if not name then break end
      if (ftype == "file" or ftype == "link") and name:match("%.lua$") then
        user_files[#user_files + 1] = udir .. name
      end
    end
  end

  -- Cache file contents for repeated scanning
  local file_cache = {}
  local function get_lines(path)
    if file_cache[path] == nil then
      file_cache[path] = vim.uv.fs_stat(path) and vim.fn.readfile(path) or {}
    end
    return file_cache[path]
  end

  --- Try search patterns against a file's lines.
  local function try_file(path, patterns)
    local lines = get_lines(path)
    for _, pat in ipairs(patterns) do
      for i, line in ipairs(lines) do
        if not line:match("^%s*%-%-") and vim.fn.match(line, pat) >= 0 then
          return pat, i
        end
      end
    end
    return nil, nil
  end

  local results = {}
  local skipped = 0

  -- Only test keymaps that would appear in the diff picker
  -- (skip Neovim defaults using the same filter as diff_keymaps).
  local all_keys = {}
  for k in pairs(before) do all_keys[k] = true end
  for k in pairs(after)  do all_keys[k] = true end

  for key in pairs(all_keys) do
    local b  = before[key]
    local a  = after[key]
    local bl = baseline[key]

    -- Same Neovim-default filter as diff_keymaps
    if a and b and bl and not key_sources[key] and not lazy_managed[key]
       and same_mapping(bl, b) and same_mapping(b, a) then
      skipped = skipped + 1
      goto next_key
    end

    local km = a or b
    local lhs = km.lhs

    -- Step 1: determine source file (distro)
    local file = key_sources[key]
    if not file or not vim.uv.fs_stat(file) then
      file = nil
      local needles = keymap_file_needles(lhs)
      for pass = 1, 2 do
        for _, path in ipairs(candidates) do
          local lines = get_lines(path)
          if #lines > 0 then
            local content = table.concat(lines, "\n"):lower()
            for _, needle in ipairs(needles) do
              local is_raw = (needle == lhs)
              if (pass == 1 and not is_raw) or (pass == 2 and is_raw) then
                if content:find(needle:lower(), 1, true) then
                  file = path
                  break
                end
              end
            end
            if file then break end
          end
        end
        if file then break end
      end
    end

    -- Step 2: test search patterns
    local patterns = keymap_search_patterns(lhs)
    local found_pat, found_line
    if file then
      found_pat, found_line = try_file(file, patterns)
    end

    -- Step 3: if distro file failed, try user plugin files
    if not found_pat then
      for _, upath in ipairs(user_files) do
        found_pat, found_line = try_file(upath, patterns)
        if found_pat then
          file = upath
          break
        end
      end
    end

    results[#results + 1] = {
      mode  = km.mode,
      lhs   = lhs,
      desc  = km.desc,
      file  = file and vim.fn.fnamemodify(file, ":t") or "???",
      found = found_line ~= nil,
      line  = found_line or 0,
      pat   = found_pat,
    }
    ::next_key::
  end

  -- Sort: misses first, then by mode+lhs
  table.sort(results, function(a, b)
    if a.found ~= b.found then return not a.found end
    if a.mode ~= b.mode then return a.mode < b.mode end
    return a.lhs < b.lhs
  end)

  local fail_count = 0
  for _, r in ipairs(results) do
    if not r.found then fail_count = fail_count + 1 end
  end

  local out = {
    "NoetherVim Keymap Source Diagnostic",
    string.format("Total: %d keymaps, %d found, %d missed (%d Neovim defaults filtered)",
      #results, #results - fail_count, fail_count, skipped),
    string.rep("─", 80),
  }
  for _, r in ipairs(results) do
    out[#out + 1] = string.format("[%s] [%s] %-20s  %-16s L%-5s %s",
      r.found and "OK  " or "MISS",
      r.mode, r.lhs, r.file,
      r.found and tostring(r.line) or "?",
      r.desc)
  end

  vim.cmd("tabnew")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_name(0, "noethervim://keymap-diagnostic")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, out)
end

-- ── Comparison: File side-by-side (Phase 6.3) ───────────────────

--- Scan a directory for .lua module names (without extension).
local function scan_lua_modules(dir)
  local modules = {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return modules end
  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if (ftype == "file" or ftype == "link") and name:match("%.lua$") then
      modules[#modules + 1] = name:gsub("%.lua$", "")
    end
  end
  table.sort(modules)
  return modules
end

--- Open a side-by-side split for a specific module (direct call path).
--- Used by :NoetherVim diff <name> when a name is provided.
local function open_diff_split(module_name)
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end

  local upstream = nil
  local candidates = {
    root .. "/lua/noethervim/" .. module_name .. ".lua",
    root .. "/lua/noethervim/plugins/" .. module_name .. ".lua",
    root .. "/lua/noethervim/bundles/" .. module_name .. ".lua",
    root .. "/lua/noethervim/lsp/" .. module_name .. ".lua",
  }
  for _, path in ipairs(candidates) do
    if vim.uv.fs_stat(path) then
      upstream = path
      break
    end
  end

  if not upstream then
    return vim.notify("NoetherVim: no upstream file found for '" .. module_name .. "'", vim.log.levels.WARN)
  end

  local udir = user_dir()
  local user_file = nil
  local user_candidates = {
    udir .. module_name .. ".lua",
    udir .. "plugins/" .. module_name .. ".lua",
    udir .. "overrides/" .. module_name .. ".lua",
    udir .. "lsp/" .. module_name .. ".lua",
  }
  for _, path in ipairs(user_candidates) do
    if vim.uv.fs_stat(path) then
      user_file = path
      break
    end
  end

  local readonly = not vim.g.noethervim_dev
  if readonly then
    vim.cmd("view " .. vim.fn.fnameescape(upstream))
    vim.bo.readonly = true
    vim.bo.modifiable = false
  else
    vim.cmd("edit " .. vim.fn.fnameescape(upstream))
  end
  if user_file then
    vim.cmd("vsplit " .. vim.fn.fnameescape(user_file))
  else
    vim.notify("NoetherVim: no user override for '" .. module_name .. "' (showing upstream only)", vim.log.levels.INFO)
  end
end

function M.diff_file(module_name)
  -- Direct open when called with a specific module name
  if module_name and module_name ~= "" then
    open_diff_split(module_name)
    return
  end

  -- Picker mode — browse all diffable modules
  local root = effective_root()
  if not root then return vim.notify("NoetherVim: cannot locate source directory", vim.log.levels.ERROR) end
  local udir = user_dir()
  local icons = require("noethervim.util.icons")

  local diff_cat_order = { Core = 1, Plugin = 2, Bundle = 3, LSP = 4 }
  local groups = {
    { cat = "Core",   dir = root .. "/lua/noethervim",         user_dirs = { udir } },
    { cat = "Plugin", dir = root .. "/lua/noethervim/plugins", user_dirs = { udir .. "plugins/" } },
    { cat = "Bundle", dir = root .. "/lua/noethervim/bundles", user_dirs = { udir .. "plugins/" } },
    { cat = "LSP",    dir = root .. "/lua/noethervim/lsp",     user_dirs = { udir .. "lsp/" } },
  }

  -- Detect which bundles are enabled (same logic as M.bundles())
  local enabled_bundles = {}
  local ok, lazy_cfg = pcall(require, "lazy.core.config")
  if ok and lazy_cfg.spec then
    for _, mod in ipairs(lazy_cfg.spec.modules) do
      local name = mod:match("^noethervim%.bundles%.(.+)$")
      if name then enabled_bundles[name] = true end
    end
  end

  local items = {}
  for _, group in ipairs(groups) do
    for _, mod in ipairs(scan_lua_modules(group.dir)) do
      if not (group.cat == "Core" and mod == "init") then
        local upstream_path = vim.fs.joinpath(group.dir, mod .. ".lua")
        local user_path = nil
        for _, ud in ipairs(group.user_dirs) do
          local candidate = ud .. mod .. ".lua"
          if vim.uv.fs_stat(candidate) then
            user_path = candidate
            break
          end
        end
        if not user_path then
          local override = udir .. "overrides/" .. mod .. ".lua"
          if vim.uv.fs_stat(override) then user_path = override end
        end

        local is_enabled = group.cat ~= "Bundle" or enabled_bundles[mod] or false
        table.insert(items, {
          text      = group.cat .. " " .. mod
                      .. (is_enabled and " enabled" or "")
                      .. (user_path and " override" or ""),
          file      = upstream_path,
          cat       = group.cat,
          cat_order = diff_cat_order[group.cat] or 99,
          name      = mod,
          upstream  = upstream_path,
          user_file = user_path,
          has_override = user_path ~= nil,
          enabled   = is_enabled,
        })
      end
    end
  end

  table.sort(items, function(a, b)
    if a.cat_order ~= b.cat_order then return a.cat_order < b.cat_order end
    return a.name < b.name
  end)

  Snacks.picker({
    title   = "NoetherVim Module Comparison",
    items   = items,
    preview = "file",
    format  = function(item)
      local ret = {} ---@type snacks.picker.Highlight[]
      ret[#ret + 1] = { string.format("%-10s", "[" .. item.cat .. "]"), "SnacksPickerLabel" }
      ret[#ret + 1] = { string.format(" %-22s", item.name) }
      -- Enabled status (checkmark for enabled bundles, spacer otherwise)
      if item.cat == "Bundle" and item.enabled then
        ret[#ret + 1] = { icons.checkmark .. " ", "DiagnosticOk" }
      else
        ret[#ret + 1] = { "  " }
      end
      -- Override status
      if item.has_override then
        ret[#ret + 1] = { "override", "DiagnosticWarn" }
      else
        ret[#ret + 1] = { "—", "Comment" }
      end
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      local readonly = not vim.g.noethervim_dev
      if readonly then
        vim.cmd("view " .. vim.fn.fnameescape(item.upstream))
        vim.bo.readonly = true
        vim.bo.modifiable = false
      else
        vim.cmd("edit " .. vim.fn.fnameescape(item.upstream))
      end
      if item.user_file then
        vim.cmd("vsplit " .. vim.fn.fnameescape(item.user_file))
      else
        vim.notify("NoetherVim: no user override for '" .. item.name .. "' (showing upstream only)", vim.log.levels.INFO)
      end
    end,
  })
end

-- ── Diff dispatcher ──────────────────────────────────────────────

function M.diff(what)
  if what == "keymaps" then
    M.diff_keymaps()
  elseif what == "options" then
    M.diff_options()
  else
    M.diff_file(what)
  end
end

-- ── Override: open user file for current source ─────────────

--- Core modules with direct user overrides in lua/user/.
local CORE_OVERRIDE_MODULES = {
  options = true, keymaps = true, autocmds = true, highlights = true,
}

--- Map a NoetherVim source file to its user override path.
--- Returns (user_path, category) or (nil, nil).
local function map_to_user_path(bufpath)
  local root = effective_root()
  if not root then return nil, nil end
  local config = vim.fn.stdpath("config")
  local udir = user_dir()

  -- Resolve real paths so symlinks don't break the prefix check.
  bufpath = vim.uv.fs_realpath(bufpath) or vim.fs.normalize(bufpath)
  root = vim.uv.fs_realpath(root) or vim.fs.normalize(root)
  if not vim.startswith(bufpath, root .. "/") then return nil, nil end
  local rel = bufpath:sub(#root + 2)

  -- lua/noethervim/plugins/<dir>/<file> → user/plugins/<dir>.lua
  local plugin_subdir = rel:match("^lua/noethervim/plugins/([^/]+)/")
  if plugin_subdir then
    return udir .. "plugins/" .. plugin_subdir .. ".lua", "plugin"
  end
  -- lua/noethervim/plugins/<name>.lua → user/plugins/<name>.lua
  local plugin = rel:match("^lua/noethervim/plugins/(.+%.lua)$")
  if plugin then return udir .. "plugins/" .. plugin, "plugin" end
  -- lua/noethervim/bundles/<name>.lua → user/plugins/<name>.lua
  local bundle = rel:match("^lua/noethervim/bundles/(.+%.lua)$")
  if bundle then return udir .. "plugins/" .. bundle, "bundle" end
  -- lua/noethervim/lsp/<name>.lua → user/lsp/<name>.lua
  local lsp = rel:match("^lua/noethervim/lsp/(.+%.lua)$")
  if lsp then return udir .. "lsp/" .. lsp, "lsp" end
  -- lua/noethervim/<name>.lua → user/<name>.lua or user/overrides/<name>.lua
  local core = rel:match("^lua/noethervim/([^/]+)%.lua$")
  if core then
    if CORE_OVERRIDE_MODULES[core] then
      return udir .. core .. ".lua", "core"
    end
    return udir .. "overrides/" .. core .. ".lua", "override"
  end
  -- ftplugin/<path> → <config>/ftplugin/<path>
  local ft = rel:match("^ftplugin/(.+)$")
  if ft then return config .. "/ftplugin/" .. ft, "ftplugin" end

  return nil, nil
end

--- Minimal seed content for a new override file.
local function seed_content(rel_path, category)
  local name = vim.fn.fnamemodify(rel_path, ":t:r")
  local lines = { "-- Override: " .. rel_path }
  if category == "plugin" or category == "bundle" then
    lines[#lines + 1] = "-- See :help noethervim-user-plugins"
    lines[#lines + 1] = "return {}"
  elseif category == "lsp" then
    lines[#lines + 1] = "-- See :help noethervim-user-lsp"
    lines[#lines + 1] = 'vim.lsp.config("' .. name .. '", {'
    lines[#lines + 1] = "})"
  elseif category == "core" then
    lines[#lines + 1] = "-- See noethervim/" .. name .. ".lua for defaults."
  elseif category == "override" then
    lines[#lines + 1] = "-- Imperative override (runs after all other setup)."
    lines[#lines + 1] = "-- See :help noethervim-user-overrides"
  elseif category == "ftplugin" then
    lines[#lines + 1] = "-- Filetype settings — runs after the distribution ftplugin."
  end
  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
end

function M.override()
  local bufpath = vim.api.nvim_buf_get_name(0)
  if bufpath == "" then
    return vim.notify("NoetherVim: current buffer has no file", vim.log.levels.WARN)
  end

  local user_path, category = map_to_user_path(bufpath)
  if not user_path then
    return vim.notify("NoetherVim: no override mapping for this file", vim.log.levels.WARN)
  end

  -- Create parent directory if needed
  local parent = vim.fn.fnamemodify(user_path, ":h")
  if vim.fn.isdirectory(parent) == 0 then
    vim.fn.mkdir(parent, "p")
  end

  -- Seed the file with a minimal template if it's new
  local is_new = not vim.uv.fs_stat(user_path)
  if is_new then
    local root = vim.fs.normalize(effective_root())
    local rel = vim.fs.normalize(bufpath):sub(#root + 2)
    local content = seed_content(rel, category)
    local fd = vim.uv.fs_open(user_path, "w", 420) -- 0644
    if fd then
      vim.uv.fs_write(fd, content)
      vim.uv.fs_close(fd)
    end
  end

  vim.cmd("vsplit " .. vim.fn.fnameescape(user_path))
  if is_new then
    vim.notify("NoetherVim: created " .. vim.fn.fnamemodify(user_path, ":~"), vim.log.levels.INFO)
  end
end

-- ── Command dispatcher ───────────────────────────────────────────

local subcommands = {
  files    = M.files,
  grep     = M.grep,
  user     = M.user,
  plugins  = M.plugins,
  bundles  = M.bundles,
  status   = M.status,
  diff     = function(args) M.diff(args) end,
  override = M.override,
  guide    = function() require("noethervim.guide").open() end,
  debug    = function(args)
    if args == "keymaps" then M.debug_keymaps()
    else vim.notify("NoetherVim: debug targets: keymaps", vim.log.levels.INFO) end
  end,
}

local subcommand_names = vim.tbl_keys(subcommands)
table.sort(subcommand_names)

function M.setup()
  -- ── :NoetherVim command ──────────────────────────────────────
  local function noethervim_handler(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })
    local cmd  = args[1]
    if not cmd then
      -- No subcommand: show the source file picker as default
      M.files()
      return
    end
    local fn = subcommands[cmd]
    if fn then
      fn(args[2])
    else
      vim.notify("NoetherVim: unknown subcommand '" .. cmd .. "'", vim.log.levels.ERROR)
    end
  end

  local noethervim_cmd_opts = {
    nargs = "*",
    complete = function(_, cmdline)
      local args = vim.split(cmdline, "%s+", { trimempty = true })
      -- Complete subcommand name
      if #args <= 2 then
        return vim.tbl_filter(function(s)
          return s:find(args[2] or "", 1, true) == 1
        end, subcommand_names)
      end
      -- Complete diff targets (auto-generated from filesystem)
      if args[2] == "diff" and #args <= 3 then
        local targets = {}
        local seen = {}
        local root = effective_root()
        if root then
          for _, dir in ipairs({
            root .. "/lua/noethervim",
            root .. "/lua/noethervim/plugins",
            root .. "/lua/noethervim/bundles",
            root .. "/lua/noethervim/lsp",
          }) do
            for _, mod in ipairs(scan_lua_modules(dir)) do
              if mod ~= "init" and not seen[mod] then
                seen[mod] = true
                targets[#targets + 1] = mod
              end
            end
          end
        end
        table.sort(targets)
        return vim.tbl_filter(function(s)
          return s:find(args[3] or "", 1, true) == 1
        end, targets)
      end
      -- Complete debug targets
      if args[2] == "debug" and #args <= 3 then
        return vim.tbl_filter(function(s)
          return s:find(args[3] or "", 1, true) == 1
        end, { "keymaps" })
      end
      return {}
    end,
    desc = "NoetherVim inspection and comparison commands",
  }

  vim.api.nvim_create_user_command("NoetherVim",  noethervim_handler, noethervim_cmd_opts)
  vim.api.nvim_create_user_command("NeotherVim",  noethervim_handler, noethervim_cmd_opts) -- common misspelling alias

  -- ── Keymaps (SearchLeader+c prefix) ──────────────────────────
  -- Note: SearchLeader+cu (user settings), +cc (config lua),
  -- +cf (ftplugins), +cs (snippets) are defined in
  -- snacks.lua.  These keymaps extend the same namespace.
  vim.keymap.set("n", SearchLeader .. "cnn", M.files,        { desc = "[n]oetherVim source" })
  vim.keymap.set("n", SearchLeader .. "cng", M.grep,         { desc = "[n]oetherVim [g]rep" })
  vim.keymap.set("n", SearchLeader .. "cb", M.bundles,       { desc = "[b]undles" })
  vim.keymap.set("n", SearchLeader .. "ck", M.diff_keymaps, { desc = "diff [k]eymaps" })
  vim.keymap.set("n", SearchLeader .. "co", M.diff_options, { desc = "diff [o]ptions" })

  vim.keymap.set("n", SearchLeader .. "?", function()
    require("noethervim.guide").open()
  end, { desc = "keymap guide" })

  vim.keymap.set("n", "<leader>i", "<cmd>edit $MYVIMRC<cr>", { desc = "open [i]nit.lua" })

  -- ── upstream compare ────────────────────────────────────────
  vim.keymap.set("n", SearchLeader .. "cd", function()
    M.diff_file()
  end, { desc = "[d]iff file" })

  vim.keymap.set("n", SearchLeader .. "ce", M.override, { desc = "[e]dit override" })
end

return M
