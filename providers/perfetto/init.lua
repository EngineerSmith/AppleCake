local require("ffi")

local perfetto = {
  id = "perfetto",

  requiresStartEvent = true,
  supportsBatching = false,
}

local libraryInit = false
perfetto.init = function(options)
  if libraryInit == false then
    libraryInit = true
    -- setup ffi, load library, etc.
  end

  -- We define two functions to avoid branching
  if options.ignoreArgs then
    perfetto.profileEnd = function(category, name, _, _, _) end

    perfetto.mark = function(category, name, scope, _) end
  else
    perfetto.profileEnd = function(category, name, _, _, args) end

    perfetto.mark = function(category, name, scope, _, args) end
  end
  return true
end

perfetto.shutdown = function()

end

perfetto.startSession = function() end
perfetto.finishSession = function() end

perfetto.profileStart = function(category, name) end

perfetto.counter = function(category, name, _, value, units) end

perfetto.flush = function() end

return perfetto