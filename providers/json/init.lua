local json = {
  id = "json"

  requiresStartEvent = true,
  supportsBatching = true,
}

json.init = function(options)
  return true
end

json.shutdown = function()

end

json.startSession = function() end
json.finishSession = function() end

json.startBatch = function()
  -- todo init batching
  json._setBatching(true)
end
json.finishBatch = function()
  -- todo push batch to channel
  json._setBatching(false)
end

-- Unbatched
local unbatched_profileStart = function(category, name) end
local unbatched_profileEnd = function(category, name, startT, endT, args) end

local unbatched_mark = function(category, name, scope, time, args) end

local unbatched_counter = function(category, name, time, value, units) end

-- Batched
local batched_profileStart = function(category, name) end
local batched_profileEnd = function(category, name, startT, endT, args) end

local batched_mark = function(category, name, scope, time, args) end

local batched_counter = function(category, name, time, value, units) end

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
json._setBatching(false)

json.flush = function() end

return json