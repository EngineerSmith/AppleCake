local insert = table.insert
local concat = table.concat

local outputStream = nil
local profileCount = 0

local function errorOut(msg)
	error("Error thrown by AppleCake outputStream\n".. msg)
end

local function validateOutputStream()
	if outputStream == nil then
		errorOut("outputStream is Nil")
	end
end

local function openStream(filepath)
	if outputStream then
		closeStream()
	end
	filepath = filepath or "profile.json"
	local err
	outputStream, err = io.open(filepath, "wb")
	if err then errorOut(err) end
	-- Header
	outputStream:write("[")
	outputStream:flush()
end

local function closeStream()
	validateOutputStream()
	
	-- Footer
	outputStream:write("]")
	outputStream:flush()
	
	outputStream:close()
	outputStream = nil
	profileCount = 0
end

local function pushBack()
	if profileCount > 0 then
		outputStream:write(",")
	end
	profileCount = profileCount + 1
end

local function tableToJsonArray(tbl)
	local str = {}
	local n = 0
	for k, v in pairs(tbl) do
		if n > 0 then insert(str, ",") end
		n = n + 1
		insert(str,[["]] .. tostring(k) .. [[":]])
		if type(v) == "number" then
			insert(str, tostring(v))
		else
			insert(str, [["]] .. tostring(v) .. [["]])
		end
	end
	return concat(str)
end

local function writeArgs(args)
	outputStream:write([[,"args":{]])
	outputStream:write(tableToJsonArray(args))
	outputStream:write("}}")
end

local function writeProfile(profile, threadID)
	validateOutputStream()
	pushBack()
	
	outputStream:write([[{"cat":"function","dur":]], (profile.finish - profile.start))
	outputStream:write([[,"name":"]], tostring(profile.name:gsub('"','\"')))
	outputStream:write([[","ph":"X","pid":0,"tid":]], threadID)
	outputStream:write([[,"ts":]], profile.start)
	
	if profile.args then
		writeArgs(profile.args)
	else
		outputStream:write("}")
	end
	outputStream:flush()
end

local function writeMark(mark, threadID)
	validateOutputStream()
	pushBack()
	
	outputStream:write([[{"cat":"mark","name":"]], tostring(mark.name:gsub('"','\"')))
	outputStream:write([[","ph":"i","pid":0,"tid":]], threadID)
	outputStream:write([[,"s":"]], mark.scope)
	outputStream:write([[","ts":]], mark.start)
	
	if mark.args then
		writeArgs(mark.args)
	else
		outputStream:write("}")
	end
	outputStream:flush()
end

return {
	openStream = openStream, 
	closeStream = closeStream, 
	writeProfile = writeProfile,
	writeMark = writeMark,
}