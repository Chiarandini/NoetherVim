--- Neovim, the tools NoetherVim calls, and the terminal it runs in.

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

-- ── Neovim version ──────────────────────────────────────────────────
local function neovim()
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
end

-- ── Required tools ──────────────────────────────────────────────────
local function required()
  h.start("Required tools")
  check_exe("git", true)
  check_exe("rg",  true)   -- ripgrep (Telescope/Snacks grep)
  check_exe("fd",  true)   -- fd (Snacks file picker)
end

-- ── Optional tools ──────────────────────────────────────────────────
local function optional()
  h.start("Optional tools")
  check_exe("node",         false)  -- some LSPs (ts_ls, etc.)
  check_exe("zoxide",       false)  -- SearchLeader+ff zoxide picker
  check_exe("lazygit",      false)  -- <c-w><c-g> float terminal
  check_exe("tree-sitter",  false)  -- required by nvim-treesitter to build parsers
end

-- ── Terminal ─────────────────────────────────────────────────────────
local function terminal()
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
end

local M = {}

function M.check()
  neovim()
  required()
  optional()
  terminal()
end

return M
