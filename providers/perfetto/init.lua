local require("ffi")

local perfetto = {
  name = "Perfetto",

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
    perfetto.profileEnd = function(zone, name, _, _, _) end

    perfetto.mark = function(zone, name, scope, _) end
  else
    perfetto.profileEnd = function(zone, name, _, _, args) end

    perfetto.mark = function(zone, name, scope, time, args) end
  end
  return true
end

perfetto.shutdown = function()

end

perfetto.beginSession = function() end
perfetto.endSession = function() end

perfetto.profileStart = function(zone, name) end

perfetto.counter = function(zone, name, time, key, value) end

perfetto.flush = function() end

return perfetto