local PATH = (...):match("(.-)[^%.]+$")
local dirPATH = PATH:gsub("%.","/")

require(PATH .. "setupLove")

love.__applecake = PATH

local log = require(PATH .. "logger")

local isActive, threadIndex

local processName, threadName

local setActiveMode = function(active)
  if isActive == nil then
    local c = love.thread.getChannel("AppleCakeController")
    c:performAtomic(function()
      local controller = c:pop()
      if controller then
        isActive = controller.isActive
        threadIndex = controller.threadIndex
      else
        isActive = active == true or active == nil
        threadIndex = 0
        if isActive then
          log:info("AppleCake enabled")
        else
          log:info("AppleCake disabled")
        end
      end
      c:push({ isActive = isActive, threadIndex = threadIndex + 1 })
    end)
  end
end

local _getTime = love.timer.getTime
local getTime = function() -- Time in microseconds
  return _getTime() * 1e+6
end

local emptyFunc = function() end
local emptyProfile = { stop = emptyFunc, args = { }}
local emptyCounter = { }
local emptyZone = {
  profile = function(_, _, _) return emptyProfile end,
  profileFunc = function(_, _) return emptyProfile end,
  counter = emptyFunc,
  mark = emptyFunc,
  enable = emptyFunc,
  disable = emptyFunc,
  isEnabled = function() return false end,
}

local appleCakeDisabled = {
  isActive = false,
  startSession      = emptyFunc,
  finishSession     = emptyFunc,
  addHook           = emptyFunc,
  removeHook        = emptyFunc,
  _registerProvider = emptyFunc,
  setProcessName    = emptyFunc,
  setThreadName     = emptyFunc,
  startBatch        = emptyFunc,
  endBatch          = emptyFunc,
  autoProfile       = emptyFunc,
  snapshotMemory    = emptyFunc,
  zone = function(_, _) return emptyZone end,
  profile     = emptyZone.profile,
  profileFunc = emptyZone.profileFunc,
  counter     = emptyZone.counter,
  mark        = emptyZone.mark,
}

local appleCake
local buildAppleCake = function()
  if appleCake then return end

  appleCake = {
    isActive = true,
    _sessionActive = false,
    _providers = { }
    _hooks = { },
  }

  local activeProfileMT = { }
  activeProfileMT.__index = activeProfileMT

  activeProfileMT.stop = function(self)
    self.finish = getTime()
    for _, provider in ipairs(appleCake._hooks) do
      provider.profileEnd(self.category, self.name, self.start, self.finish, self.args)
    end
  end

  if not love.isThread then

  -- Sessions
    appleCake.startSession = function()
      if appleCake._sessionActive then
        appleCake.finishSession()
      end
      appleCake._sessionActive = true
      for _, provider in ipairs(appleCake._hooks) do
        provider.startSession()
      end
    end

    appleCake.finishSession = function()
      if not appleCake._sessionActive then
        return
      end
      appleCake._sessionActive = false
      for _, provider in ipairs(appleCake._hooks) do
        provider.finishSession()
      end
    end

  -- Hooks
    appleCake.addHook = function(providerID, options)
      local provider = appleCake._providers[providerID]
      if not provider then
        log:warning("Could not find provider:", providerID)
        return false, "not found"
      end

      local success, errMsg = pcall(provider.init, options)
      if not success then
        log:warning("Couldn't initiate provider:", providerID, ". Reason:", errMsg)
        return false, "not init"
      end

      table.insert(appleCake._hooks, provider)
      log:info("Added hook:", providerID)

      provider.setProcessName(processName)
      provider.setThreadName(threadName)
      return true
    end

    appleCake.removeHook = function(providerID)
      local providerIndex
      for i, p in ipairs(appleCake._hooks) do
        if p.id == providerID then
          providerIndex = i
          break
        end
      end
      if not providerIndex then
        log:warning("Couldn't find provider to remove:", providerID)
        return false
      end
      local provider = appleCake._hooks[i]
      if appleCake._sessionActive then
        provider.finishSession()
      end
      provider.shutdown()
      table.remove(appleCake._hooks, providerIndex)
      return true
    end

    appleCake.shutdown = function()
      appleCake.finishSession()
      for _, provider in ipairs(appleCake._hooks) do
        provider.shutdown()
      end
      appleCake._hooks = { }
    end

    appleCake._registerProvider = function(provider)
      appleCake._providers[provider.id] = provider
    end
    --[[
    How should hooks work? Call backs? Let's figure out what each one needs

    FOR PERFETTO:
      profile start event: category + name + flowID[optional][Start/End]
      profile end event: category + args[optional]
      counter: category + name + value + units[optional] (OR) counterMultiplier[optional]
      mark: category + name + scope + args[optional] + flowID[optional][Start/End]

    JSON:
      profile end event: category + name + startTime + finishTime + args[optional] + flowID[optional][Start/End] +threadID
      counter: category + name + value + units[optional] (OR) counterMultiplier[optional] + threadID
      mark: category + name + scope + args[optional] + flowID[optional][Start/End] + threadID

    Note, Perfetto can't be batched. So we should be able to define that, to tell AppleCake "Don't batch for this hook even if you've been told to"

    We're going for an interface based approach, where they all have functions they need to implement
    We don't care about flowIDs start/end right now - focus on getting 1:1 feature with AppleCake 2.1
    ]]
  end

  processName = love.filesystem.getIdentity()
  appleCake.setProcessName = function(name)
    if type(name) ~= "string" then
      log:warning("setProcessName arg name expected type string")
      return
    end
    processName = name
    for _, provider in ipairs(appleCake.hooks) do
      provider.setProcessName(processName)
    end
  end

  threadName = (threadIndex == 0 and "main" or "thread:" .. threadIndex)
  appleCake.setThreadName = function(name)
    if type(name) ~= "string" then
      log:Warning("setThreadName arg name expected type string")
      return
    end
    threadName = name
    for _, provider in ipairs(appleCake.hooks) do
      provider.setThreadName(name)
    end
  end

  appleCake.startBatch = function()
    for _, provider in ipairs(appleCake.hooks) do
      if provider.supportsBatching then
        provider.startBatch()
      end
    end
  end

  appleCake.finishBatch = function()
    for _, provider in ipairs(appleCake.hooks) do
      if provider.supportsBatching then
        provider.finishBatch()
      end
    end
  end

  appleCake.autoProfile = function()
    -- todo blocked by profiles
  end

  appleCake.snapshotMemory = function()
    -- todo blocked by counters
  end

  appleCake.profile = function()
    -- todo blocked by zones
  end

  appleCake.profileFunc = function()
    -- todo blocked by zones
  end

  appleCake.counter = function()
    -- todo blocked by zones
  end

  appleCake.mark = function()
    -- todo blocked by zones
  end

end

return function(active)
  setActiveMode(active)
  if not isActive then
    return appleCakeDisabled
  end
  buildAppleCake()
  return appleCake
end