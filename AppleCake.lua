--[[
	AppleCake Profiling for Love2D
	https://github.com/EngineerSmith/AppleCake
	Docs can be found in the README.md
	
	Written by https://github.com/EngineerSmith or 
	PSmith#4624 on Discord
	
	You can view the profiling data visually by going to 
	chrome:\\tracing and dropping in the json created
]]

local outputStream = nil
local profileCount = 0

local loveGetTime = love.timer.getTime

local getTime = function() -- Returns time in microseconds
	return loveGetTime() * 1000000
end

local function errorOut(msg) -- Added to allow easy customization of error messages
	error("Error thrown by AppleCake profiling tool\n".. msg)
end

local function validateOutputStream()
	if not outputStream then
		errorOut("outputStream is Nil")
	end
end

local function beginSession(filepath)
	if outputStream then
		EndSession()
	end
	filepath = filepath or "profile.json"
	local err
	outputStream, err = io.open(filepath, "wb")
	if err then errorOut(err) end
	-- Header
	outputStream:write([[{"otherData":{},"traceEvents":[]])
	outputStream:flush()
end

local function endSession()
	validateOutputStream()
	
	-- Footer
	outputStream:write([[]}]])
	outputStream:flush()
	
	outputStream:close()
	outputStream = nil
	profileCount = 0
end

local function writeProfile(profile)
	validateOutputStream()
	if profileCount > 0 then
		outputStream:write(",")
	end
	profileCount = profileCount + 1
	
	local str = [[{"cat":"function","dur":]] .. (profile.finish - profile.start) ..
				[[,"name":"]] .. profile.name:gsub('"','/"') ..
				[[","ph":"X","pid":0,"ts":]] .. profile.start
	if profile.args then
		str = str .. [[,"args":{]]
		local n = 0
		for k, v in pairs(profile.args) do
			if n > 0 then
				str = str .. ","
			end
			n = n + 1
			str = str .. [["]] .. tostring(k) ..[[":]]
			if type(v) == "number" then
				str = str .. tostring(v)
			else
				str = str .. [["]] .. tostring(v) .. [["]]
			end
		end
		str = str .. "}}"
	else
		str = str .. "}"
	end
	outputStream:write(str)
	outputStream:flush()
end

local function stopProfile(profile)
	if profile._stopped then
		errorOut("Attempted to stop and write profile more than once")
	end
	profile.finish = getTime()
	writeProfile(profile)
	profile._stopped = true
end

local function start(name, args, profile)
	if profile then
		profile.name = name
		profile.start = getTime()
		profile._stopped = false
		profile.args = args
		return profile
	else
		return {
			name = name,
			start = getTime(),
			stop = stopProfile,
			args = args,
		}
	end
end

local function profileFunc(args, profile)
	if profile then
		return start(profile.name, args, profile)
	end
	local info = debug.getinfo(2, 'nS')
	if info and info.name then
		local name = info.name
		if info.short_src then
			name =  name .. "@" .. info.short_src
		
			if info.linedefined then
				name = name .. "#" .. info.linedefined
			end
		end
		return start(name, args)
	end
	errorOut("Could not generate name for this function")
end

local AppleCake = {
			beginSession = beginSession,
			endSession = endSession,
			profile = start,
			profileFunc = profileFunc,
		}
-- Following is used to disable AppleCake
local emptyFunc = function() end -- Used to decrease number of anon empty functions created
local emptyProfile = {stop=emptyFunc}
local AppleCakeRelease = {
			beginSession = emptyFunc,
			endSession = emptyFunc,
			profile = function() return emptyProfile end,
			profileFunc = function() return emptyProfile end,
		}
		
local isDebug = nil -- Used to return the same table as first requested

return function(debug)
	if isDebug ~= nil then
		debug = isDebug
	end
	if debug == nil then
		debug = true
	end
	if debug then
		isDebug = true
		return AppleCake
	else
		isDebug = false
		return AppleCakeRelease
	end
end