local PATH = (...):match("(.-)[^%.]+$")
local dirPATH = PATH:gsub("%.","/")

local codec = require(PATH .. "codec")

local json = {
  id = "json"

  requiresStartEvent = true,
  supportsBatching = true,

  threadLocation = dirPATH .. "thread.lua",
  channel = love.thread.newChannel(),
}

json.init = function(options)
  if not json.thread then
    json.thread = love.thread.newThread(json.threadLocation)
  end

  local filepath = "profile.json"
  if type(options) == "table" then
    if type(options.filepath) == "string" then
      filepath = options.filepath
    end
  end

  json.thread:start(json.channel, filepath)
  return true
end

json.shutdown = function()
  if json.thread and json.thread:isRunning() then

  end
end

json.startSession = function() end
json.finishSession = function() end

json.startBatch = function()
  json._setBatching(true)
  codec.enableEncodingBatching()
end
json.finishBatch = function()
  -- todo push batch to channel
  json._setBatching(false)
  local encodedMessage = codec.disableEncodingBatching()
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