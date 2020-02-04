--[[
	AppleCake Profiling for Love2D
	https://github.com/EngineerSmith/AppleCake
	Docs - https://github.com/EngineerSmith/AppleCake/wiki
	
	Written by https://github.com/EngineerSmith or 
	PSmith#4624 on Discord
	
	You can view the profiling data visually by going to 
	chrome:\\tracing and dropping in the file created
]]

local outputStream = nil
local profileCount = 0

local loveGetTime = love.timer.getTime

local getTime = function() -- Returns time in microseconds
	return loveGetTime() * 1000000
end

local function errorOut(msg)
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
	--Header
	outputStream:write([[{"otherData":{},"traceEvents":[]])
	outputStream:flush()
end

local function endSession()
	validateOutputStream()
	
	--Footer
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
				[[","ph":"X","pid":0,"ts":]] .. profile.start .. "}"
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

local function start(name, profile)
	if profile then
		profile.name = name
		profile.start = getTime()
		profile._stopped = false
		return profile
	else
		return {
			name = name,
			start = getTime(),
			stop = stopProfile
		}
	end
end

local function profileFunc(profile)
	if profile then
		return start(profile.name, profile)
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
		return start(name)
	end
	errorOut("Could not generate name for this function function")
end

local AppleCake = {
			beginSession = beginSession,
			endSession = endSession,
			profile = start,
			profileFunc = profileFunc,
		}
local AppleCakeRelease = {
			beginSession = function(filepath) end,
			endSession = function() end,
			profile = function(name, profile) return profile or {stop=function() end} end,
			profileFunc = function(profile) return profile or {stop=function() end} end
		}
		
local isDebug = nil

return function(debug)
	if isDebug ~= nil then
		debug = isDebug
	end
	if not debug then
		isDebug = true
		return AppleCake
	else
		isDebug = false
		return AppleCakeRelease
	end
end