local outputStream = { }

local insert, concat = table.insert, table.concat

local stream

outputStream.open = function(filepath)
  if stream then
    outputStream.close()
  end
  filepath = filepath or "profile.json"
  local errorMessage
  stream, errorMessage = io.open(filepath, "wb")
  if not stream then
    error("Could not open file("..tostring(filepath)..")for writing")
  end
  stream:write("[")
  stream:flush()
end

local shouldPushBack = false

outputStream.close = function(filepath)
  if not stream then
    return
  end
  stream:write("]")
  stream:close()
  stream = nil
  shouldPushBack = false
end

local pushBack = function()
  if shouldPushBack then
    stream:write(",")
  end
  shouldPushBack = true
end

local writeJsonArray
writeJsonArray = function(tbl)
  local str = { "{" }
  for k, v in pairs(tbl) do
    insert(str, ([["%s":]]):format(tostring(k)))
    local t = type(v)
    if t == "table" then
      insert(str, writeJsonArray(v))
    elseif t == "number" then
      insert(str, tostring(v))
    elseif t == "userdata" and v:typeOf("Data") then
      insert(str, ([["%s"]]):format(v:getString()))
    elseif t ~= "userdata" then
      insert(str, ([["%s"]]):format(tostring(v)))
    end
    insert(str, ",")
  end
  if #str == 1 then
    str[1] = "{}"
  else
    str[#str] = "}"
  end
  return concat(str)
end

outputStream.writeProfile = function(profile, threadID)
  if not stream then
    error("No file opened")
  end
  pushBack()
  stream:write(([[{"cat":"function","dur":%d,"name":"%s","ph":"X","pid":0,"tid":%d,"ts":%d]]):format(profile.finish-profile.start, profile.name:gsub('"','\"'), threadID, profile.start))
  if profile.args then
    stream:write([[,"args":]])
    stream:write(writeJsonArray(profile.args))
  end
  stream:write("}")
  stream:flush()
end

outputStream.writeMark = function(mark, threadID)
  if not stream then
    error("No file opened")
  end
  pushBack()
  stream:write(([[{"cat":"mark","name":"%s","ph":"i","pid":0,"tid":%d,"s":"%s","ts":%d]]):format(mark.name:gsub('"', '\"'), threadID, mark.scope, mark.start))
  if mark.args then
    stream:write([[,"args":]])
    stream:write(writeJsonArray(mark.args))
  end
  stream:write("}")
  stream:flush()
end

outputStream.writeCounter = function(counter, threadID)
  if not stream then
    error("No file opened")
  end
  pushBack()
  stream:write(([[{"cat":"counter","name":"%s","ph":"C","pid":0,"tid":%d, "ts":%d]]):format(counter.name, threadID, counter.start))
  if counter.args then
    stream:write([[,"args":]])
    stream:write(writeJsonArray(counter.args))
  end
  stream:write("}")
  stream:flush()
end

return outputStream