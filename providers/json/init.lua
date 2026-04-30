local json = {
  name = "Json"

  requiresStartEvent = true,
  supportsBatching = true,
}

json.init = function(options)
  return true
end

json.shutdown = function()

end

json.beginSession = function() end
json.endSession = function() end

json.profileStart = function(zone, name) end
json.profileEnd = function(zone, name, startT, endT, args) end

json.mark = function(zone, name, scope, time, args) end

json.counter = function(zone, name, time, key, value) end

json.flush = function() end

return json