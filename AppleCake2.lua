local PATH = (...):match("(.-)[^%.]+$")

require(PATH .. "setupLove")
love.__applecake = PATH

local log = require(PATH .. "logger")
local setup = require(PATH .. "setup")
setup._bake()
local hooks = setup._hooks

local _getTime = love.timer.getTime
-- Time in microseconds
local getTime = function()
  return _getTime() * 1e+6
end

-- Benchmarking https://gist.github.com/EngineerSmith/f99c1ba503ec090f34b0659978a829c7
-- Performance: about the same as AppleCake 2.1's inline function, but more readable
local generateFuncName = function()
  local info = debug.getinfo(3, "fnS")
  local name = info.name or tostring(info.func):sub(10)
  if info.short_src then
    name = name .. "@" .. info.short_src
  end
  if info.linedefined then
    name = name .. "#" .. info.linedefined
  end
  return name
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

if not setup.isActive then
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

zoneMT.enable = function(self) self.enabled = true end
zoneMT.disable = function(self) self.enabled = false end
zoneMT.inherit = function(self) self.enabled = nil end
zoneMT.isEnabled = function(self)
  local current = self
  while current do
    if current.enabled ~= nil then return current.enabled end
    current = current.parent
  end
  return appleCake.isActive -- fallback
end

zoneMT.profile = function(self, name, args, profile)
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

zoneMT.profileFunc = function(self, args, profile)
  return self:profile(profile and profile.name or generateFuncName(), args, profile)
end

local counterWarnings = { } -- Used to prevent warning spam
zoneMT.counter = function(self, name, value, units)
  if not self:isEnabled() then return end
  local time = getTime()
  if type(value) ~= "number" then
    if not counterWarnings[name] then
      log:warning("counter (", name, ") received a non-number value. Type received:", type(value))
      counterWarnings[name] = true
    end
    return
  end

  for _, provider in ipairs(hooks) do
    provider.counter(self.category, name, time, value, units)
  end
end

zoneMT.mark = function(self, name, scope, args)
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
appleCake.setThreadName(not love.isThread and "main" or "thread_" .. setup.threadIndex)

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

local loveZone = appleCake.zone("love")

appleCake.autoProfileEvents = function()
  if not love.event then
    -- love.event won't be loaded in config, but this seems like the cleanest way to do this.
    -- Otherwise, if you do call `autoProfileEvents` within main.lua scope, but event module
    -- wasn't enabled, then you'd get the warning about calling before handlers have been created.
    log:info("autoProfileEvents was called, but love.event wasn't loaded.")
    return
  end
  if not love.handlers then
    log:warning("Cannot call autoProfileEvents before handlers have been created. (Move within main.lua scope)")
    return
  end

  if love.handlers then
    for k, v in pairs(love.handlers) do
      local name = "event love." .. k
      local p
      love.handlers[k] = function(...)
        p = loveZone:profile(name, { ... }, p)
        local returns = { v(...) }
        p:stop()
        return table.unpack(returns)
      end
    end
  end
end

local rootZone = getOrCreateZone("", true)

appleCake.snapshotMemory = function(zone)
  local usage = collectgarbage("count") * 1024
  (zone or rootZone):counter("Memory Usage", usage, "memory")
end

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
  return rootZone:profile(profile and profile.name or generateFuncName(), args, profile)
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