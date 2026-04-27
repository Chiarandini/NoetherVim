-- NoetherVim web search utilities
-- Command:  :Search [<engine>] <query>   (engines: see search_engines table)
--           :Search set <engine>          (set the default engine)
-- Lua API:  M.search_diagnostic_under_cursor(), M.search_selected_text(), M.open_plugin_repo()

local M = {}

local search_engines = {
  duckduckgo   = "https://duckduckgo.com/?q=%s",
  brave        = "https://search.brave.com/search?q=%s&source=web",
  ecosia       = "https://www.ecosia.org/search?method=index&q=%s",
  google       = "https://www.google.com/search?q=%s",
  github       = "https://github.com/search?q=%s&type=repositories",
  startpage    = "https://www.startpage.com/do/dsearch?query=%s",
  reddit       = "https://www.reddit.com/search/?q=%s",
  stackoverflow= "https://stackoverflow.com/search?q=%s",
  wikipedia    = "https://www.wikipedia.org/search-redirect.php?language=en&go=Go&search=%s",
  youtube      = "https://www.youtube.com/results?search_query=%s",
}

local current_engine = "brave"

local function open_url(url)
  vim.ui.open(url)
end

local function encode(query)
  return query:gsub("[^%w%-_.~]", function(c)
    return c == " " and "%20" or string.format("%%%02X", string.byte(c))
  end)
end

local function web_search(query, engine)
  if not query or query == "" then
    vim.notify("Empty query.", vim.log.levels.WARN, { title = "Web Search" })
    return
  end
  local url = search_engines[engine or current_engine]
  if not url then
    vim.notify("Unknown engine: " .. (engine or current_engine), vim.log.levels.ERROR,
      { title = "Web Search" })
    return
  end
  open_url(url:format(encode(query)))
end

-- ──────────────────────────────────────────────────────────────
--  :Search command (subcommand-dispatch)
-- ──────────────────────────────────────────────────────────────

--- :Search <query>...                 search with current default engine
--- :Search <engine> <query>...        search with the named engine
--- :Search set <engine>               change the default engine
local function search_cmd(o)
  local args = o.fargs
  if #args == 0 then
    vim.notify("Usage: :Search [<engine>|set] <query>", vim.log.levels.WARN,
      { title = "Web Search" })
    return
  end

  local first = args[1]

  if first == "set" then
    local engine = args[2]
    if not engine then
      vim.notify("Usage: :Search set <engine>", vim.log.levels.WARN,
        { title = "Search Engine" })
      return
    end
    if search_engines[engine] then
      current_engine = engine
      vim.notify("Engine: " .. engine, vim.log.levels.INFO, { title = "Search Engine" })
    else
      vim.notify("Unknown engine: " .. engine, vim.log.levels.ERROR,
        { title = "Search Engine" })
    end
    return
  end

  if search_engines[first] then
    local q = table.concat(vim.list_slice(args, 2), " ")
    if q == "" then
      vim.notify("Usage: :Search " .. first .. " <query>", vim.log.levels.WARN,
        { title = "Web Search" })
      return
    end
    vim.notify("Searching " .. first .. ": " .. q, vim.log.levels.INFO,
      { title = "Web Search" })
    web_search(q, first)
    return
  end

  -- Default: treat the whole arg list as the query for the current engine.
  local q = table.concat(args, " ")
  vim.notify("Searching: " .. q, vim.log.levels.INFO, { title = "Web Search" })
  web_search(q)
end

local function search_complete(_, line)
  local args = vim.split(line, "%s+", { trimempty = true })
  -- Completing the first arg: engine name OR "set".
  if #args <= 2 then
    local partial = args[2] or ""
    local matches = {}
    if ("set"):find(partial, 1, true) == 1 then
      table.insert(matches, "set")
    end
    for e in pairs(search_engines) do
      if e:find(partial, 1, true) == 1 then table.insert(matches, e) end
    end
    table.sort(matches)
    return matches
  end
  -- `:Search set <engine>` -- complete engine name.
  if args[2] == "set" and #args <= 3 then
    local partial = args[3] or ""
    local matches = {}
    for e in pairs(search_engines) do
      if e:find(partial, 1, true) == 1 then table.insert(matches, e) end
    end
    table.sort(matches)
    return matches
  end
  return {}
end

vim.api.nvim_create_user_command("Search", search_cmd, {
  nargs = "+",
  complete = search_complete,
  desc = "web search ([engine|set] query)",
})

-- ──────────────────────────────────────────────────────────────
--  Lua API
-- ──────────────────────────────────────────────────────────────

function M.search_diagnostic_under_cursor()
  local diags = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
  if #diags == 0 then
    vim.notify("No diagnostic under cursor", vim.log.levels.INFO, { title = "Web Search" })
    return
  end
  local q = diags[1].message .. " " .. (vim.bo.filetype ~= "" and vim.bo.filetype or vim.fn.expand("%:e"))
  web_search(q)
end

function M.search_selected_text()
  vim.cmd('silent normal! "xy')
  local text = vim.fn.getreg("x")
  if text == "" then
    vim.notify("No text selected", vim.log.levels.WARN, { title = "Web Search" })
    return
  end
  web_search(text:gsub("[\n\t]+", " "):gsub("%s+", " "))
end

function M.open_plugin_repo()
  local word = vim.fn.expand("<cWORD>")
  local repo = word:match('([^"%s]+/[^"%s]+)')
  if repo then
    open_url("https://github.com/" .. repo)
  else
    vim.notify("Not a GitHub repo name", vim.log.levels.WARN, { title = "Plugin Repo" })
  end
end

return M
