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

  -- Detect OS and use appropriate clipboard command
  local os_name = vim.uv.os_uname().sysname
  local cmd

  local escaped = vim.fn.shellescape(pdf_file)

  if os_name == 'Linux' then
    -- Try xclip first, then xsel as fallback
    if vim.fn.executable('xclip') == 1 then
      cmd = 'xclip -selection clipboard -t application/pdf ' .. escaped
    elseif vim.fn.executable('xsel') == 1 then
      cmd = 'xsel --clipboard --input < ' .. escaped
    else
      vim.notify('xclip or xsel not found. Please install one of them.', vim.log.levels.ERROR)
      return
    end
  elseif os_name == 'Darwin' then -- macOS
    cmd = 'osascript -e \'set the clipboard to (read (POSIX file ' .. escaped .. ') as «class PDF »)\''
  elseif os_name:match('Windows') then
    -- Windows doesn't have a built-in command to copy files to clipboard
    -- This copies the file path instead
    cmd = 'echo ' .. escaped .. ' | clip'
    vim.notify('Note: Copying file path to clipboard (Windows limitation)', vim.log.levels.INFO)
  else
    vim.notify('Unsupported operating system: ' .. os_name, vim.log.levels.ERROR)
    return
  end

  -- Execute the command
  local result = vim.fn.system(cmd)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    vim.notify('PDF copied to clipboard: ' .. vim.fn.fnamemodify(pdf_file, ':t'))
  else
    vim.notify('Failed to copy PDF to clipboard: ' .. result, vim.log.levels.ERROR)
  end
end


return M
