-- NoetherVim plugin: Abolish
-- Smart find-and-replace with case preservation.
--
-- Abolish is an amazing but often-overlooked Vim plugin by tpope. It provides:
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
--   Coercion operators (cr<key>):
--     crs  →  snake_case
--     crm  →  MixedCase (PascalCase)
--     crc  →  camelCase
--     cru  →  UPPER_CASE
--     cr-  →  dash-case
--     cr.  →  dot.case
--     cr<space> → space case
--
-- Override via: { "tpope/vim-abolish", opts = { ... } }

return {
	"tpope/vim-abolish",
	event = "VeryLazy",
}
