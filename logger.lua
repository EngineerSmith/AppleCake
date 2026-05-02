-- Simple logging, use mintmousse if available
-- https://mintmousse.engineersmith.net/latest/logging/

-- Feel free to override this with your own logger to route logs to your system

if love.__mintmousse then
  local success, mintmousse = pcall(require, love.__mintmousse)
  if success and mintmousse then
    return mintmousse.newLogger("AppleCake", "bright_green")
  end
end

local logger = {
  name = "AppleCake"
}
logger.__index = logger

logger.extend = function(parent, name, _)
  return setmetatable({
    name = parent.name .. ":" .. name,
  }, logger)
end

local varargsToString = function(...)
  local messageParts = { }
  for i = 1, select('#', ...) do
    local value = select(i, ...)
    messageParts[i] = tostring(i)
  end
  return table.concat(messageParts, " ")
end

logger.info = function(self, ...)
  print(self.name .. " [info ] " .. varargsToString(...))
end

logger.warning = function(self, ...)
  print(self.name .. " [warn ] " .. varargsToString(...))
end

logger.debug = function(self, ...)
  print(self.name .. " [debug] " .. varargsToString(...))
end

logger.error = function(self, ...)
  local str = self.name .. " [error] " .. varargsToString(...)
  print(str)
  error(str)
end

logger.assert = function(self, condition, ...)
  if not condition then
    self:error(...)
  end
end

return logger