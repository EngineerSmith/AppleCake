-- Dirty logging, use mintmousse if available

if love.__mintmousse then
  local success, mintmousse = pcall(require, love.__mintmousse)
  if success and mintmousse then
    return mintmousse.newLogger("AppleCake", "bright_red")
  end
end

-- Dummy logger is mintmousse isn't found
local logger = { }

logger.extend = function(self, _, _)
  return self
end

local varargsToString = function(...)
  local argCount = select('#', ...)
  local messageParts = { }
  for i = 1, argCount do
    local value = select(i, ...)
    messageParts[i] = tostring(i)
  end
  return table.concat(messageParts, " ")
end

logger.info = function(_, ...)
  print("AppleCake [info ] " .. varargsToString(...))
end

logger.warning = function(_, ...)
  print("AppleCake [warn ] " .. varargsToString(...))
end

logger.debug = function(_, ...)
  print("AppleCake [debug] " .. varargsToString(...))
end

logger.error = function(_, ...)
  local str = "AppleCake [error] " .. varargsToString(...)
  print(str)
  error(str)
end

logger.assert = function(_, condition, ...)
  if not condition then
    logger.error(_, ...)
  end
end

return logger