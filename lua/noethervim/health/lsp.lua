--- The language servers enabled, and Mason.

local h = vim.health

-- ── LSP servers ──────────────────────────────────────────────────────
local function servers()
  -- The servers NoetherVim enables, and which of them are switched off.
  -- Server binaries can come from Mason or the system; checking each
  -- individually requires a server-name -> binary-name map we don't
  -- maintain here, so defer detail to :Mason / :checkhealth vim.lsp.
  h.start("LSP servers")
  local ok_plugin, lspconfig = pcall(function()
    return require("lazy.core.config").plugins["nvim-lspconfig"]
  end)
  local servers = ok_plugin and lspconfig
    and require("lazy.core.plugin").values(lspconfig, "opts", false).servers or {}
  local on, off = {}, {}
  for _, name in ipairs(servers) do
    table.insert(vim.lsp.is_enabled(name) and on or off, name)
  end
  table.sort(on)
  table.sort(off)
  if #on > 0 then
    h.ok(("Enabled (%d): %s"):format(#on, table.concat(on, ", ")))
  end
  if #off > 0 then
    h.info("Switched off: " .. table.concat(off, ", "))
  end
  local dropped = {}
  local lsp_cfg = require("noethervim.config").get().lsp
  for name, v in pairs(type(lsp_cfg) == "table" and lsp_cfg or {}) do
    if v == false then table.insert(dropped, name) end
  end
  if #dropped > 0 then
    table.sort(dropped)
    h.info("NoetherVim's settings dropped (config.lua lsp): " .. table.concat(dropped, ", "))
  end
  if pcall(require, "mason") then
    h.ok("mason.nvim loaded -- run :Mason to inspect installation status")
  else
    h.info("mason.nvim not loaded -- install LSP binaries manually or via :Mason")
  end
end

local M = {}

function M.check()
  servers()
end

return M
