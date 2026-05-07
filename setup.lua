local PATH = (...):match("(.-)[^%.]+$")

local log = require(PATH .. "logger"):extend("setup", "bright_blue")

local acSync = love.thread.getChannel("AppleCakeSyncSetup")
acSync:performAtomic(function(c)
  local s = c:peek()
  if not s then
    c:push({
      status = "raw",
      threadIndex = 0,
    })
  end
end)

local _setup = { }
local setupMT = {
  __index = function(_, key)
    return _setup[key]
  end,
  __newindex = function(_, key, value) 
    _setup[key] = value
  end,
}
local setup = setmetatable({
  isActive = true,
  _providers = { },
  _hooks = { },
}, setupMT)

local baked = false
setup._bake = function()
  if baked then return end
  baked = true

  setupMT.__newindex = function(_, _, _)
    log:warning("Cannot change AppleCake's setup table after you've required AppleCake")
  end

  -- Clean up functions
  local keys = { }
  for k, v in ipairs(_setup) do
    if type(v) == "function" then
      table.insert(keys, k)
    end
  end
  for _, key in ipairs(keys) do
    _setup[key] = nil
  end
  _setup._providers = nil

  local s
  acSync:performAtomic(function(c)
    s = c:pop()
    if s.status == "baked" then
      -- Cannot change settings already baked
      return
    end
    s.status = "baked"
    s.isActive = _setup.isActive

    if s.isActive then
      if #_setup._hooks == 0 then
        s.isActive = false
      else
        s.hooks = { }
        for _, provider in ipairs(_setup._hooks) do
          table.insert(s.hooks, provider.__module)
        end
      end
    end

    c:push(s)
  end)
  if _setup.isActive ~= s.isActive then
    _setup.isActive = s.isActive
    log:info("AppleCake disabled due to no active hooks")
  else
    log:info("AppleCake settings baked,", #_setup._hooks, "hooks added")
  end
end

setup.enable = function()
  setup.isActive = true
end

setup.disable = function()
  setup.isActive = false
end

setup.addHook = function(providerID, options)
  local provider = setup._providers[providerID]
  if not provider then
    log:warning("Could not find provider:", providerID)
    return false, "not found"
  end

  local success, errMsg = pcall(provider.init, options, setup.threadIndex)
  if not success then
    log:warning("Couldn't initiate provider:", providerID, ". Reason:", errMsg)
    return false, "not init"
  end

  table.insert(setup._hooks, provider)
  log:info("Added hook:", provider.name or provider.id)

  return true
end

setup.removeHook = function(providerID)
  local providerIndex
  for i, p in ipairs(setup._hooks) do
    if p.id == providerID then
      providerIndex = i
      break
    end
  end
  if not providerIndex then
    log:warning("Couldn't find provider to remove:", providerID)
    return false
  end

  local provider = setup._hooks[providerIndex]
  provider.shutdown()
  table.remove(setup._hooks, providerIndex)
  return true
end

setup._registerProvider = function(providerModule)
  local provider = require(providerModule)
  provider.__module = providerModule
  setup._providers[provider.id] = provider
end

local s
acSync:performAtomic(function(c)
  s = c:pop()
  setup.threadIndex = s.threadIndex
  s.threadIndex = s.threadIndex + 1
  c:push(s)
end)
if s.status == "baked" then
  setup.isActive = s.isActive
  if s.isActive then
    for _, providerModule in ipairs(s.hooks) do
      table.insert(_setup._hooks, require(providerModule))
    end
  end
  setup._bake()
end

----- Default providers
setup._registerProvider(PATH .. "providers.json")
setup._registerProvider(PATH .. "providers.perfetto")

return setup