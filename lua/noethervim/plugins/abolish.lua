-- NoetherVim plugin: Abolish
-- Smart find-and-replace with case preservation.
--
-- Pinned to the Chiarandini/vim-abolish fork, which adds an -expr={fn}
-- option (and corresponding g:abolish_default_expr) so Abolish-defined
-- abbreviations can be gated by a predicate at expansion time. NoetherVim
-- uses this to restrict typo correction to comments / @spell regions in
-- code buffers while keeping unconditional expansion in writing buffers.
--
-- The fork is upstream-compatible: with neither -expr= nor
-- g:abolish_default_expr set, behaviour is identical to tpope/vim-abolish.
--
-- Abolish provides:
--
--   :Subvert/{pattern}/{replacement}/g
--     Like :s but preserves the case shape of each match.
--     Example:  :Subvert/facilit{y,ies}/building{}/g
--       → facility  → building
--       → Facility  → Building
--       → FACILITY  → BUILDING
--
--   :Abolish {typo} {correction}
--     Auto-correct typos in insert mode (like :iabbrev but smarter).
--     Handles all case variants automatically:
--       :Abolish teh the   →  corrects teh, Teh, TEH
--
--    A particularly powerful feature is the ability to stack cases:
--       :Abolish neeed{ed} need{}
--         → neeed → need, neeeded → needed
--       :Abolish {,sub}lienear {}linear
--         → lienear → linear, sublienear → sublinear
--       :Abolish {conditi,approximati}no{,s} {}on{}
--         → conditino → condition, approximatinos → approximations
--       :Abolish {,un}nec{ce,ces,e}sar{y,ily} {}nec{es}sar{}
--         → one line catches necesary, unneccesary, necessarilly, …
--
--     Combined with automatic case handling, a single :Abolish line
--     can correct dozens of misspelling and case combinations at once.
--     Add your own in lua/user/plugins/ -- see templates/user/plugins/example.lua.
--
--   Context gating (NoetherVim default):
--     In code buffers, :Abolish expansions only fire when the cursor sits
--     inside a comment or @spell-captured region. Use [oA / ]oA to force
--     unconditional expansion in the current buffer. To opt a specific
--     :Abolish line out of gating, pass -expr= explicitly:
--       :Abolish -expr= teh the    " always expands
--
--   Coercion operators (cr<key>):
--     crs  →  snake_case
--     crm  →  MixedCase (PascalCase)
--     crc  →  camelCase
--     cru  →  UPPER_CASE
--     cr-  →  dash-case
--     cr.  →  dot.case
--     cr<space> → space case
--
-- Override via: { "Chiarandini/vim-abolish", opts = { ... } }

local fork_local = vim.fn.expand("~/programming/vim-abolish")
local source = vim.fn.isdirectory(fork_local) == 1
  and { name = "vim-abolish", dir = fork_local }
  or  { "Chiarandini/vim-abolish", commit = "e79c5b2" }

return vim.tbl_extend("force", source, {
  event = "VeryLazy",
  init = function()
    vim.g.abolish_default_expr = "NoetherAbolishSpell"
    vim.cmd([[
      function! NoetherAbolishSpell(typo, correction) abort
        return luaeval('require("noethervim.abolish_ctx").in_spell_region()')
              \ ? a:correction : a:typo
      endfunction
    ]])
  end,
})
