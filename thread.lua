local _err = error
error = function(msg)
  _err("Error thrown by AppleCake Thread: "..tostring(msg))
end

local PATH, OWNER = ...
local outputStream = require(PATH.."outputStream")
local threadConfig = require(PATH.."threadConfig")

local out  = love.thread.getChannel(threadConfig.outStreamID)
local info = love.thread.getChannel(threadConfig.infoID)

local updateOwner = function(channel, owner)
  local info = channel:pop()
  info.owner = owner
  channel:push(info)
end

local commands = { }

commands["open"] = function(threadID, filepath)
  if info:peek().owner == nil then
    if OWNER ~= threadID then
      error("Thread "..threadID.."tried to begin session. Only thread "..OWNER..", that created the outputStream, can begin sessions")
    end
    outputStream.open(filepath)
    info:performAtomic(updateOwner, threadID)
  end
end

commands["close"] = function(threadID)
  if OWNER ~= threadID then
    error("Thread "..threadID.." tried to end session owned by thread "..OWNER)
  end
  outputStream.close()
  info:performAtomic(updateOwner, nil)
  return true
end

commands["writeProfile"] = outputStream.writeProfile
commands["writeMark"]    = outputStream.writeMark
commands["writeCounter"] = outputStream.writeCounter
  
while true do
  local cmd = out:demand()
  local fn = commands[cmd.command]
  if fn and fn(unpack(cmd)) then
    return
  end
end