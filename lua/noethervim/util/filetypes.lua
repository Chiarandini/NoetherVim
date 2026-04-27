local M = {}

M.writing = {
  tex = true, markdown = true, norg = true, text = true,
  gitcommit = true, rst = true, typst = true,
}

M.non_code = {
  json = true, jsonc = true, yaml = true, toml = true,
  help = true, qf = true, oil = true, terminal = true,
  snacks_dashboard = true, lazy = true, mason = true,
  checkhealth = true, notify = true, TelescopePrompt = true,
  Trouble = true, trouble = true,
  ["dap-repl"] = true, dapui_scopes = true, dapui_breakpoints = true,
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
