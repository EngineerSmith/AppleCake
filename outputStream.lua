local outputStream = nil
local profileCount = 0

local function errorOut(msg)
	error("Error thrown by AppleCake outputStream\n".. msg)
end

local function validateOutputStream()
	if not outputStream then
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

local function tableToJson(tbl)
	local str = ""
	local n = 0
	for k, v in pairs(tbl) do
		if n > 0 then str = str .. "," end
		n = n + 1
		str = str .. [["]] .. tostring(k) .. [[":]]
		if type(v) == "number" then
			str = str .. tostring(v)
		else
			str = str .. [["]] .. tostring(v) .. [["]]
		end
	end
	return str
end

local function writeProfile(profile)
	validateOutputStream()
	pushBack()
	
	local str = [[{"cat":"function","dur":]] .. (profile.finish - profile.start) ..
				[[,"name":"]] .. profile.name:gsub('"','\"') ..
				[[","ph":"X","pid":0,"tid":0,"ts":]] .. profile.start
	if profile.id then
		str = str .. [[,"id":"]] .. tostring(profile.id) .. [["]]
	end
	if profile.args then
		str = str .. [[,"args":{]] .. tableToJson(profile.args) .. "}}"
	else
		str = str .. "}"
	end
	outputStream:write(str)
	outputStream:flush()
end

local function writeMark(mark)
	validateOutputStream()
	pushBack()
	
	local str = [[{"cat":"mark","name":"]] .. mark.name:gsub('"','\"') ..
				[[","ph":"i","pid":1,"tid":0,"s":"g","ts":]] .. mark.start
	if mark.id then
		str = str .. [[,"id":"]] .. tostring(mark.id) .. [["]]
	end
	if mark.args then
		str = str .. [[,"args":{]] .. tableToJson(mark.args) .. "}}"
	else
		str = str .. "}"
	end
	outputStream:write(str)
	outputStream:flush()
end

return {
	openStream = openStream, 
	closeStream = closeStream, 
	writeProfile = writeProfile,
	writeMark = writeMark,
}