local PATH = (...):match("(.-)[^%.]+$")
local dirPATH = PATH:gsub("%.","/")
--[[
	AppleCake Profiling for Love2D
	https://github.com/EngineerSmith/AppleCake
	Docs can be found in the README.md
	
	Written by https://github.com/EngineerSmith or 
	PSmith#4624 on Discord
	
	You can view the profiling data visually by going to 
	chrome:\\tracing and dropping in the json created
]]

local channel = nil
local thread = nil

local outputStream = require(PATH.."outputStream")

local loveThread = love.thread
local loveGetTime = love.timer.getTime

local getTime = function() -- Returns time in microseconds
	return loveGetTime() * 1000000
end

local function errorOut(msg)
	error("Error thrown by AppleCake\n".. msg)
end

local function beginSession(threaded, filepath)
	if thread then
		endSession()
	end
	if threaded == nil or threaded then
		thread = loveThread.newThread(dirPATH.."thread.lua")
		channel = loveThread.getChannel(require(PATH.."threadConfig").id)
		channel:push({command="open",args={file=filepath}})
		thread:start(PATH)
	else
		outputStream.openStream(filepath)
	end
end

local function endSession()
	if thread then
		channel:push({command="close"})
		thread:wait()
		thread = nil
	else
		outputStream.closeStream()
	end
end

local function stopProfile(profile)
	if profile._stopped then
		errorOut("Attempted to stop and write profile more than once")
	end
	profile.finish = getTime()
	if thread then
		profile.stop = nil --Can't push functions
		channel:push({command="write",args={profile=profile}})
		profile.stop = stopProfile
	else
		outputStream.writeProfile(profile)
	end
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

local function mark(name, args, id)
	local mark = {name=name,args=args,start=getTime(),id=id}
	if thread then
		channel:push({command="write",args={mark=mark}})
	else
		outputStream.writeMark(mark)
	end
end

local AppleCake = {
			beginSession = beginSession,
			endSession = endSession,
			profile = start,
			profileFunc = profileFunc,
			mark = mark,
		}
-- Following is used to disable AppleCake
local emptyFunc = function() end -- Used to decrease number of anon empty functions created
local emptyProfile = {stop=emptyFunc}
local AppleCakeRelease = {
			beginSession = emptyFunc,
			endSession = emptyFunc,
			profile = function() return emptyProfile end,
			profileFunc = function() return emptyProfile end,
			mark = emptyFunc,
		}
		
local isDebug = nil -- Used to return the same table as first requested

return function(debug)
	if isDebug ~= nil then
		debug = isDebug
	end
	if debug == nil or debug then
		isDebug = true
		return AppleCake
	else
		isDebug = false
		return AppleCakeRelease
	end
end