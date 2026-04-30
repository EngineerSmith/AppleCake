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

json.startBatch = function()
  -- todo init batching
  json._setBatching(true)
end
json.endBatch = function()
  -- todo push batch to channel
  json._setBatching(false)
end

local unbatched_profileStart = function(zone, name) end
local unbatched_profileEnd = function(zone, name, startT, endT, args) end

local unbatched_mark = function(zone, name, scope, time, args) end

local unbatched_counter = function(zone, name, time, key, value) end

local batched_profileStart = function(zone, name) end
local batched_profileEnd = function(zone, name, startT, endT, args) end

local batched_mark = function(zone, name, scope, time, args) end

local batched_counter = function(zone, name, time, key, value) end

json._setBatching = function(isBatching)
  if isBatching then
    json.profileStart = batched_profileStart
    json.profileEnd = batched_profileEnd
    json.mark = batched_mark
    json.counter = batched_counter
  else
    json.profileStart = unbatched_profileStart
    json.profileEnd = unbatched_profileEnd
    json.mark = unbatched_mark
    json.counter = unbatched_counter
  end
end

json.flush = function() end

return json