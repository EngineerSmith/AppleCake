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
  }
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