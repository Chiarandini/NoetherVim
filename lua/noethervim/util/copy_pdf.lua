---@class copy_pdf
local M = {}

function M.copy_pdf_to_clipboard()
  -- Get current buffer's filename
  local tex_file = vim.fn.expand('%:p')

  -- Check if current file is a .tex file
  if not tex_file:match('%.tex$') then
    vim.notify('Current file is not a .tex file', vim.log.levels.WARN)
    return
  end

  -- Replace .tex extension with .pdf
  local pdf_file = tex_file:gsub('%.tex$', '.pdf')

  -- Check if PDF file exists
  if vim.fn.filereadable(pdf_file) == 0 then
    vim.notify('PDF file not found: ' .. pdf_file, vim.log.levels.ERROR)
    return
  end

  -- Detect OS and build appropriate argv for clipboard copy.
  local os_name = vim.uv.os_uname().sysname
  local argv

  if os_name == 'Linux' then
    -- Try xclip first, then xsel as fallback
    if vim.fn.executable('xclip') == 1 then
      argv = { 'sh', '-c', 'xclip -selection clipboard -t application/pdf < "$1"', 'sh', pdf_file }
    elseif vim.fn.executable('xsel') == 1 then
      argv = { 'sh', '-c', 'xsel --clipboard --input < "$1"', 'sh', pdf_file }
    else
      vim.notify('xclip or xsel not found. Please install one of them.', vim.log.levels.ERROR)
      return
    end
  elseif os_name == 'Darwin' then -- macOS
    local script = 'set the clipboard to (read (POSIX file "' .. pdf_file:gsub('"', '\\"') .. '") as «class PDF »)'
    argv = { 'osascript', '-e', script }
  elseif os_name:match('Windows') then
    -- PowerShell Set-Clipboard -Path puts the file on the clipboard as a file drop;
    -- this pastes into Zotero, email clients, Explorer, etc. as the PDF attachment.
    local ps_path = pdf_file:gsub("'", "''")
    argv = { 'powershell', '-NoProfile', '-Command', "Set-Clipboard -LiteralPath '" .. ps_path .. "'" }
  else
    vim.notify('Unsupported operating system: ' .. os_name, vim.log.levels.ERROR)
    return
  end

  local obj = vim.system(argv, { text = true }):wait()
  if obj.code == 0 then
    vim.notify('PDF copied to clipboard: ' .. vim.fn.fnamemodify(pdf_file, ':t'))
  else
    vim.notify('Failed to copy PDF to clipboard: ' .. (obj.stderr or ''), vim.log.levels.ERROR)
  end
end


return M
