local PATH = (...):match("(.-)[^%.]+$")
local dirPATH = PATH:gsub("%.","/")

require(PATH .. "setupLove")
love.__applecake = PATH

local log = require(PATH .. "logger")
local setup = require(PATH .. "setup")
setup._bake()
local hooks = setup._hooks

local _getTime = love.timer.getTime
local getTime = function() -- Time in microseconds
  return _getTime() * 1e+6
end

-- Note, AppleCake disabled vars is also used when zones are disabled
local emptyFunc = function() end
local emptyProfile = { stop = emptyFunc, args = { }}
local emptyCounter = { }
local emptyZone = {
  profile     = function(_, _, _) return emptyProfile end,
  profileFunc = function(_, _)    return emptyProfile end,
  counter = emptyFunc,
  mark    = emptyFunc,
  enable  = emptyFunc,
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
  finishBatch       = emptyFunc,
  autoProfileEvents = emptyFunc,
  snapshotMemory    = emptyFunc,
  zone = function(_, _) return emptyZone end,
  profile     = emptyZone.profile,
  profileFunc = emptyZone.profileFunc,
  counter     = emptyZone.counter,
  mark        = emptyZone.mark,
}

if not setup.isActive then
  return appleCakeDisabled
end

local appleCake = {
  isActive = true,
  _sessionActive = false,
}

local activeProfileMT = { }
activeProfileMT.__index = activeProfileMT

activeProfileMT.stop = function(self)
  self.finish = getTime()
  for _, provider in ipairs(hooks) do
    provider.profileEnd(self.category, self.name, self.start, self.finish, self.args)
  end
end

local zoneRegistry = { }

local zoneMT = { }
zoneMT.__index = zoneMT

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

  for _, provider in ipairs(hooks) do
    if provider.profileStart then
      provider.profileStart(profile.category, profile.name)
    end
  end

  return profile
end

zone.counter = function(self, name, value, units)
  if not self:isEnabled() then return end
  local time = getTime()

  for _, provider in ipairs(hooks) do
    provider.counter(self.category, name, time, value)
  end
end

zone.mark = function(self, name, scope, args)
  if not self:isEnabled() then return end
  local time = getTime()
  local scope = scope or "process"

  for _, provider in ipairs(hooks) do
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
    for _, provider in ipairs(hooks) do
      provider.startSession()
    end
  end

  appleCake.finishSession = function()
    if not appleCake._sessionActive then
      return
    end
    appleCake._sessionActive = false
    for _, provider in ipairs(hooks) do
      provider.finishSession()
    end
  end

  -- How should this function work if we don't tell other threads that AC is shutdown?
  -- We could just find that acceptable, after all - at this point we expect everything to stop.
  appleCake.shutdown = function()
    appleCake.finishSession()
    for _, provider in ipairs(hooks) do
      provider.shutdown()
    end
    appleCake.isActive = false
  end

  appleCake.setProcessName = function(name)
    if type(name) ~= "string" then
      log:warning("setProcessName arg name expected type string")
      return
    end
    for _, provider in ipairs(hooks) do
      provider.setProcessName(name)
    end
  end
  appleCake.setProcessName(love.filesystem.getIdentity())

end

appleCake.setThreadName = function(name)
  if type(name) ~= "string" then
    log:Warning("setThreadName arg name expected type string")
    return
  end
  for _, provider in ipairs(hooks) do
    provider.setThreadName(name)
  end
end
appleCake.setThreadName(setup.threadIndex == 0 and "main" or "thread:" .. setup.threadIndex)

appleCake.startBatch = function()
  for _, provider in ipairs(hooks) do
    if provider.supportsBatching then
      provider.startBatch()
    end
  end
end

appleCake.finishBatch = function()
  for _, provider in ipairs(hooks) do
    if provider.supportsBatching then
      provider.finishBatch()
    end
  end
end

appleCake.flush = function()
  for _, provider in ipairs(hooks) do
    provider.flush()
  end
end

appleCake.autoProfileEvents = function()
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

appleCake.profileFunc = function(args, profile)
  local name = profile.name
  if not name then
    -- TODO use jit.funcinfo over debug info name
  end
  return rootZone:profile(name, args, profile)
end

appleCake.counter = function(name, value, units)
  rootZone:counter(name, value, units)
end

appleCake.mark = function(name, scope, args)
  rootZone:mark(name, scope, args)
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

return appleCake