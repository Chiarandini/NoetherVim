--- The java bundle's check for :checkhealth noethervim: whether the Java
--- jdtls runs on is new enough.
---@param h table vim.health
return function(h)
  if not require("lazy.core.config").plugins["nvim-jdtls"] then return end
  h.start("Java (languages.java bundle)")
  local java = require("noethervim.lib.java")
  local major = java.major()
  if not major then
    h.warn("no java found ($JAVA_HOME, else PATH): jdtls cannot start", { java.REMEDY })
  elseif major < java.MIN then
    h.warn(("jdtls runs on Java %d here; it needs %d or newer, and on %d the Java language server never starts")
      :format(major, java.MIN, major), { java.REMEDY })
  else
    h.ok(("Java %d for jdtls"):format(major))
  end
end
