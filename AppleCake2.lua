local PATH = (...):match("(.-)[^%.]+$")
local dirPATH = PATH:gsub("%.","/")

require(PATH .. "setupLove")

love.__applecake = PATH

local log = require(PATH .. "logger")

local isActive, threadIndex

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
  beginSession   = emptyFunc,
  endSession     = emptyFunc,
  setProcessName = emptyFunc,
  setThreadName  = emptyFunc,
  startBatch     = emptyFunc,
  endBatch       = emptyFunc,
  addHook        = emptyFunc,
  removeHook     = emptyFunc,
  _onHookChange  = emptyFunc,
  autoProfile    = emptyFunc,
  snapshotMemory = emptyFunc,
  zone = function(_, _) return emptyZone end,
  profile     = emptyZone.profile,
  profileFunc = emptyZone.profileFunc,
  counter     = emptyZone.counter,
  mark        = emptyZone.mark,
}

local appleCake
local buildAppleCake = function()
  appleCake = {
    isActive = true,
    _sessionActive = false,
    _providers = { }
    _hooks = { },
  }

  -- Sessions
  appleCake.beginSession = function()
    if appleCake._sessionActive then
      appleCake.endSession()
    end
    appleCake._sessionActive = true
  end

  appleCake.endSession = function()
    if not appleCake._sessionActive then
      return
    end
    appleCake._sessionActive = false
  end

  -- Hooks
  if not love.isThread then
    appleCake.addHook = function(providerID, options)
      -- check if provider exists
      -- run init(options), if return true, it works, false, it failed, log event
    end

    appleCake.removeHook = function(providerID)

    end

    appleCake._registerProvider = function(provider)
      appleCake._providers[provider.name] = provider
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

      ]]
    end

  end
end

return function(active)
  setActiveMode(active)
  if not isActive then
    return appleCakeDisabled
  end
  if not appleCake then
    buildAppleCake()
  end
  return appleCake
end