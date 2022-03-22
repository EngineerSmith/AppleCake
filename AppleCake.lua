local PATH = (...):match("(.-)[^%.]+$")
local dirPATH = PATH:gsub("%.","/") -- for thread.lua to be read as a file
--[[
  AppleCake Profiling for Love2D
  https://github.com/EngineerSmith/AppleCake
  Docs can be found in the README.md
  License is MIT, details can be found in the LICENSE file

  Written by https://github.com/EngineerSmith or 
  EngineerSmith#4628 on Discord

  You can view the profiling data visually by going to 
  chrome:\\tracing and dropping in the json created.
  Check README.md#Viewing-AppleCake for more details
]]

local lt = love.thread or require("love.thread")

local threadConfig = require(PATH.."threadConfig")
local info = lt.getChannel(threadConfig.infoID)

local _err= error
local error = function(msg)
  _err("Error thrown by AppleCake: "..tostring(msg))
end

local isActive = nil -- Used to return the same table as first requested

local function setActiveMode(active)
  if isActive == nil then
    local i = info:peek()
    if i then
      isActive = i.active
    else
      if active == nil then
        active = true
      end
      isActive = active
      info:push({ active = active })
    end
  end
end

local emptyFunc = function() end
local emptyProfile = {stop=emptyFunc, args={}}
local emptyCounter = { }

local AppleCakeRelease = {
  beginSession = emptyFunc,
  endSession   = emptyFunc,
  profile      = function() return emptyProfile end,
  stopProfile  = emptyFunc,
  profileFunc  = function() return emptyProfile end,
  mark         = emptyFunc,
  counter      = function() return emptyCounter end,
  countMemory  = function() return emptyCounter end,
  isDebug      = false,
  -- Deprecated
  markMemory   = emptyFunc,
  _stopProfile = emptyFunc,
}

local AppleCake

return function(active)
  setActiveMode(active)
  if not isActive then
    return AppleCakeRelease
  end
  if AppleCake then -- return appleCake if it's already been made
    return AppleCake
  end
  
  AppleCake = {
    isDebug = true,
  }
  
  local threadID = tonumber(tostring(threadConfig):sub(8)) --Produces a unique consistent id based on memory (if nobody changes require)
  local commandTbl = { threadID }
  
  if not love.timer then
    require("love.timer")
  end
  local _getTime = love.timer.getTime
  local getTime = function() -- Return time in microseconds
    return _getTime() * 1000000
  end
  
  local thread
  local outStream = love.thread.getChannel(threadConfig.outStreamID)
  
  AppleCake.beginSession = function(filepath)
    if thread then
      AppleCake.endSession()
    else
      thread = lt.newThread(dirPATH.."thread.lua")
    end
    commandTbl.command = "open"
    commandTbl[2] = filepath
    outStream:push(commandTbl)
    commandTbl[2] = nil
    thread:start(PATH, threadID)
  end
  
  AppleCake.endSession = function()
    if thread and thread:isRunning() then
      outStream:performAtomic(function()
          outStream:clear()
          commandTbl.command = "close"
          outStream:push(commandTbl)
        end)
      thread:wait()
    else
      local i = info:peek()
      if i then
        error("The session can only be closed within the thread that started it.")
      end
    end
  end
  
  -- Profile a section of code
  AppleCake.profile = function(name, args, profile)
    if profile then
      profile.name = name
      profile.args = args
      profile._stopped = false
      profile.start = getTime()
      return profile
    else
      return {
          profile = true,
          name = name,
          args = args,
          stop = AppleCake.stopProfile,
          start = getTime(),
        }
    end
  end
  
  AppleCake.stopProfile = function(profile)
    if profile._stopped then
      error("Attempted to stop and write profile more than once. If attempting to reuse profile, ensure it is passed back into the function which created it to reset it's use")
    end
    profile.stop = nil -- Can't push functions
    profile.finish = getTime()
    commandTbl[2] = profile
    outStream:push(commandTbl)
    commandTbl[2] = nil
    profile.stop = AppleCake.stopProfile
    profile._stopped = true
  end
  
  -- Profile time taken within a function
  AppleCake.profileFunc = function(args, profile)
    if profile then
      return AppleCake.profile(profile.name, args, profile)
    end
    local info = debug.getinfo(2, "fnS")
    if info then
      local name
      if info.name then
        name = info.name
      elseif info.func then -- Attempt to create a name from memory address
        name = tostring(info.func):sub(10)
      else
        error("Could not generate name for this function")
      end
      if info.short_src then
          name = name.."@"..info.short_src..(info.linedefined and "#"..info.linedefined or "")
      end
      return AppleCake.profile(name, args)
    end
  end
  
  -- Mark an event at a point in time
  AppleCake.mark = function(name, scope, args)
    if scope == nil or (scope ~= "p" and scope ~= "t") then
      scope = "p"
    end
    commandTbl.command = "write"
    commandTbl[2] = {
        mark = true,
        name = name,
        args = args,
        start = getTime(),
        scope = scope,
      }
    outStream:push(commandTbl)
    commandTbl[2] = nil
  end
  
  -- Track variable over time
  AppleCake.counter = function(name, args, counter)
    commandTbl.command = "write"
    if counter then
      counter.name  = name
      counter.args  = args
      counter.start = getTime()
    else
      counter = {
          counter = true,
          name    = name,
          args    = args,
          start   = getTime(),
        }
    end
    commandTbl[2] = counter
    outStream:push(commandTbl)
    commandTbl[2] = nil
    return counter
  end
  
  local memArg, mem = { }, nil
  AppleCake.countMemory = function()
    memArg.kilobytes = collectgarbage("count")
    mem = AppleCake.counter("Memory usage", memArg, mem)
  end
  
  --[[ Deprecated functions ]]
  
  -- _stopProfile deprecated with stopProfile
  AppleCake._stopProfile = AppleCake.stopProfile
  
  -- markMemory deprecated with countMemory
  AppleCake.markMemory = AppleCake.countMemory
  
  return AppleCake
end