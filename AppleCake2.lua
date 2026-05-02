local PATH = (...):match("(.-)[^%.]+$")
local dirPATH = PATH:gsub("%.","/")

require(PATH .. "setupLove")

love.__applecake = PATH

local log = require(PATH .. "logger")

-- TODO use channel to sync information across threads, such as what hooks should be active so they can correct route.
local acSync = love.thread.getChannel("AppleCakeSync")

-- Ah, this introduces a lot of issues, or needing a polling function on every thread for AppleCake.
-- Can we alter the plan to prevent needing a polling function?
-- Such as removing the ability to remove hooks?
-- Where you define how you want the AppleCake library to work, and then before starting any other threads
-- you "bake" these settings? 

-- With AppleCake 2.1, it was pretty much 0 setup
-- You'd just "enable" or "disable" the library in the main thread, and then just continue to use it anywhere
-- This is what I want still. Maybe instead of AppleCake returning a function to be called, it returns a table
-- In this table is our "addHook", "_registerProvider" functions, etc. Then you do `.bake(enable/disable)`
-- This then puts the info into the sync channel, which all threads can just check, and then when they are required
-- Instead of returning the table to setup AppleCake, they just return the enabled/disabled library
-- I would want to change how require works too, since on the main thread, I wouldn't want every file doing
-- require("libs.AppleCake") and getting the setup table, so we should change _G to return the correct AppleCake instant

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

-- Note, AppleCake disabled vars is also used when zones are disabled
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

  local zoneRegistry = { }

  local zoneMT = { }
  zoneMT.__index = zoneMT

  -- This is broken
  -- What if we create zones in this order, then their parents are incorrect:
  -- engine
  -- engine.ai.pathfinding - thinks engine is parent
  -- engine.ai -- should have child pathfinding, but doesn't

  local getOrCreateZone = function(category, enabled)
    if zoneRegistry[category] then
      if enabled ~= nil then
        zoneRegistry[category].enabled = enabled
      end
      return zoneRegistry[category]
    end

    local self = setmetatable({ }, zoneMT)
    self.category = category
    self.enabled = enabled

    if category ~= "" then
      local parentCategory = category:match("^(.*)%.[^%.]+$") or ""
      self.parent = getOrCreateZone(parentCategory)
    end

    zoneRegistry[category] = self
    return self
  end

  zone.enable = function(self) self.enabled = true end
  zone.disable = function(self) self.enabled = false end
  zone.inherit = function(self) self.enabled = nil end
  zone.isEnabled = function(self)
    if self.enabled ~= nil then
      return self.enabled
    end
    if self.parent then
      return self.parent:isEnabled()
    end
    return appleCake.isActive -- fallback
  end

  zone.profile = function(self, name, args, profile)
    if not self:isEnabled() then return emptyProfile end
    local start = getTime()

    local profile = profile or setmetatable({ }, activeProfileMT)

    profile.category = self.category
    profile.name = name
    profile.args = args or profile.args
    profile.start = start

    for _, provider in ipairs(appleCake._hooks) do
      if provider.profileStart then
        provider.profileStart(profile.category, profile.name)
      end
    end

    return profile
  end

  zone.counter = function(self, name, value)
    if not self:isEnabled() then return end
    local time = getTime()

    for _, provider in ipairs(appleCake._hooks) do
      provider.counter(self.category, name, time, value)
    end
  end

  zone.mark = function(self, name, scope, args)
    if not self:isEnabled() then return end
    local time = getTime()
    scope = scope or "process"

    for _, provider in ipairs(appleCake._hooks) do
      provider.mark(self.category, name, scope, time, args)
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
  end

  -- Wait, how does this work if threads don't know what hooks it should be calling? We need a thread mechanic to share hook definitions
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

  appleCake.flush = function()
    for _, provider in ipairs(appleCake.hooks) do
      provider.flush()
    end
  end

  appleCake.autoProfile = function()
    -- todo
  end

  appleCake.snapshotMemory = function()
    -- todo
  end

  local rootZone = getOrCreateZone("") -- We should be able to enable/disable this zone itself too
  appleCake.zone = function(category, enabled)
    if type(category) ~= "string" then
      log:warning("zone arg category expected type string")
      return nil
    end
    return getOrCreateZone(category, enabled)
  end

  appleCake.profile = function(name, args, profile)
    return rootZone:profile(name, args, profile)
  end

  appleCake.profileFunc = function()
    -- TODO use jit.funcinfo over debug info
  end

  appleCake.counter = function(name, value)
    rootZone:counter(name, value)
  end

  appleCake.mark = function(name, scope, args)
    rootZone:mark(name, scope, args)
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