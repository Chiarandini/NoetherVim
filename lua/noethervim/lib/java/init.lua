--- The Java that jdtls runs on, and what jdtls needs of it.

local M = {}

--- jdtls 1.63 bundles an Eclipse JDT compiled for Java 25, while its
--- launcher still only checks for 21: on 21 it starts and never comes up.
M.MIN = 25

local cached

--- The major version of the Java jdtls's launcher picks ($JAVA_HOME's, else
--- the one on PATH), or nil when there is none or it cannot be read.
---@return integer?
function M.major()
  if cached ~= nil then return cached or nil end
  local java = vim.env.JAVA_HOME and vim.fs.joinpath(vim.env.JAVA_HOME, "bin", "java") or "java"
  cached = false
  if vim.fn.executable(java) == 1 then
    local out = vim.fn.system({ java, "-version" })
    local v = tonumber(out:match('version "(%d+)'))
    -- "1.8.0_x" is Java 8.
    if v == 1 then v = tonumber(out:match('version "1%.(%d+)')) end
    cached = v or false
  end
  return cached or nil
end

--- Where to get a current JDK, and how jdtls finds it.
M.REMEDY = "install a JDK " .. M.MIN .. " or newer (https://adoptium.net/) and put it first on PATH, or point JAVA_HOME at it"

return M
