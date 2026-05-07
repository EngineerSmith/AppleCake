local dictionary = {
  -- todo
}
local bufferEnc = require("string.buffer").new({
  dict = dictionary,
})
local bufferDec = require("string.buffer").new({
  dict = dictionary,
})

local codec = {
  isBatching = false,
}

codec.isBuffered = function()
  return #bufferEnc > 0, #bufferDec > 0
end

codec.encode = function(message)
  bufferEnc:encode(message)
  return not codec.isBatching and codec.flush() or nil
end

codec.flush = function()
  local encodedMessage = bufferEnc:get()
  bufferEnc:reset()
  return encodedMessage
end

codec.decode = function(encodedMessage)
  return bufferDec:set(encodedMessage):decode()
end

codec.decodeBatch = function(encodedMessage, callback)
  bufferDec:set(encodedMessage)
  while select(2, codec.isBuffered()) do
    local success, message = pcall(bufferDec.decode, bufferDec)
    if success then
      callback(message)
    else
      break
    end
  end
end

codec.enableEncodingBatching = function()
  codec.isBatching = true
end

codec.disableEncodingBatching = function()
  codec.isBatching = false
  return code.flush()
end

return codec