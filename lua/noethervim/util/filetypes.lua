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

local ok_cfg, user_cfg = pcall(require, "user.config")
if ok_cfg and type(user_cfg) == "table" then
  for _, ft in ipairs(user_cfg.writing_filetypes or {}) do
    M.writing[ft] = true
  end
  for _, ft in ipairs(user_cfg.non_code_filetypes or {}) do
    M.non_code[ft] = true
  end
end

return M
