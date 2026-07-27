--- Filetype lists the distro keys behaviour off, with the `lua/user/config.lua`
--- extensions already folded in.  Requiring this module is the only supported
--- way to read them; the tables are built once at load time.

local M = {}

M.writing = {
  tex = true, markdown = true, norg = true, text = true,
  gitcommit = true, gitsendemail = true, mail = true,
  rst = true, typst = true,
}

M.non_code = {
  json = true, jsonc = true, yaml = true, toml = true,
  help = true, man = true, lspinfo = true, query = true,
  qf = true, oil = true, terminal = true,
  snacks_dashboard = true, snacks_picker_input = true,
  snacks_layout_box = true, snacks_notif = true,
  snacks_terminal = true,
  lazy = true, mason = true, checkhealth = true,
  notify = true, TelescopePrompt = true,
  Trouble = true, trouble = true,
  ["dap-repl"] = true, ["dap-float"] = true,
  dapui_scopes = true, dapui_breakpoints = true,
  dapui_stacks = true, dapui_watches = true, dapui_console = true,
}

--- Filetypes where a bare `q` closes the window.  A list rather than a set,
--- because it is handed straight to an autocmd `pattern`.
---
--- Editable filetypes are deliberately absent: `q` would shadow macro
--- recording in a buffer you might actually type into.  `qf` is handled by
--- ftplugin/qf.lua instead.
M.q_close = {
  "help", "man", "lspinfo", "checkhealth",
  "notify", "fugitiveblame",
  "startuptime", "lazy", "mason",
  "spectre_panel", "crunner", "dap-float",
  "DressingInput", "cmp_menu",
  "typr", "snacks_notif", "snacks_terminal",
  "nvim-undotree", "undotree", "diff",
}

local ok_cfg, user_cfg = pcall(require, "user.config")
if ok_cfg and type(user_cfg) == "table" then
  for _, ft in ipairs(user_cfg.writing_filetypes or {}) do
    M.writing[ft] = true
  end
  for _, ft in ipairs(user_cfg.non_code_filetypes or {}) do
    M.non_code[ft] = true
  end
  for _, ft in ipairs(user_cfg.q_close_filetypes or {}) do
    if not vim.tbl_contains(M.q_close, ft) then
      M.q_close[#M.q_close + 1] = ft
    end
  end
end

return M
