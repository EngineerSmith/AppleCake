local PATH = (...):match("(.-)[^%.]+$")
local dirPATH = PATH:gsub("%.","/")
--[[
	AppleCake Profiling for Love2D
	https://github.com/EngineerSmith/AppleCake
	Docs can be found in the README.md
	License is MIT, details can be found in the LICENSE file
	
	Written by https://github.com/EngineerSmith or 
	PSmith#4624 on Discord
	
	You can view the profiling data visually by going to 
	chrome:\\tracing and dropping in the json created.
	Check README.md#Viewing-AppleCake for more details
]]

local config = require(PATH.."threadConfig")
local threadID = tonumber(tostring(config):sub(8)) --Produces a unique id based on memory
local isDebug = nil -- Used to return the same table as first requested

local loveThread = love.thread

if love.timer  == nil then -- If AppleCake is required on a thread, need to load time
	love.timer = require("love.timer")
end

local loveGetTime = love.timer.getTime

local outStreamChannel = loveThread.getChannel(config.outStreamID)
local infoChannel = loveThread.getChannel(config.infoID)
local thread = nil
local commandTbl = {threadID=threadID}

local getTime = function() -- Return time in microseconds
	return loveGetTime() * 1000000
end

local function errorOut(msg)
	error("Error thrown by AppleCake\n".. msg)
end

local function beginSession(filepath)
	if thread then
		endSession()
	end
	
	thread = loveThread.newThread(dirPATH.."thread.lua")
	commandTbl.command = "open"
	commandTbl.args = {file=filepath}
	outStreamChannel:push(commandTbl)
	thread:start(PATH, threadID)
end

local function endSession()
	if thread then 
		commandTbl.command = "close"
		commandTbl.args = nil
		outStreamChannel:push(commandTbl)
		thread:wait()
		thread = nil
	else
		local info = infoChannel:peek()
		if info then
			errorOut("Current session is owned by "..info.owner..". The session can only be closed within the thread that started it.")
		end
	end
end

local function stopProfile(profile)
	profile.finish = getTime()
	if profile._stopped then
		errorOut("Attempted to stop and write profile more than once. If attempting to reuse profile, ensure it is passed back into function to reset it's use.")
	end
	profile.stop = nil -- Can't push functions
	commandTbl.command = "write"
	commandTbl.args = {profile=profile}
	outStreamChannel:push(commandTbl)
	profile.stop = stopProfile
	profile._stopped = true
end

local function start(name, args, profile)
	if profile then
		profile.name = name
		profile.args = args
		profile._stopped = false
		profile.start = getTime()
		return profile
	else
		return {
			name = name,
			args = args,
			stop = stopProfile,
			start = getTime(),
		}
	end
end

local function profileFunc(args, profile)
	if profile then
		return start(profile.name, args, profile)
	end
	local info = debug.getinfo(2, 'fnS')
	if info then
		local name
		if info.name then
			name = info.name
		elseif info.func then -- Attempt to create a name from memory address
			name = tostring(info.func):sub(10)
		else
			goto out
		end
		if info.short_src then
			name =  name .. "@" .. info.short_src
			if info.linedefined then
				name = name .. "#" .. info.linedefined
			end
		end
		return start(name, args)
	end
	::out::
	errorOut("Could not generate name for this function")
end

local function mark(name, scope, args)
	if scope == nil or (scope ~= "p" and scope ~= "t") then
		scope = "p"
	end
	commandTbl.command = "write"
	commandTbl.args = {mark={name=name,args=args,start=getTime(),scope=scope}}
	outStreamChannel:push(commandTbl)
end

local function markMemory(scope)
	local num = collectgarbage("count")
	mark("Memory usage", scope, {bytes=num*1024,kbytes=num,mbytes=num/1024})
end

local AppleCake = {
			beginSession = beginSession,
			endSession   = endSession,
			profile      = start,
			profileFunc  = profileFunc,
			mark         = mark,
			markMemory   = markMemory,
			isDebug      = true,
			_stopProfile = stopProfile,
		}
-- Disable AppleCake
local emptyFunc = function() end -- Used to decrease number of anon empty functions created
local emptyProfile = {stop=emptyFunc}
local AppleCakeRelease = {
			beginSession = emptyFunc,
			endSession   = emptyFunc,
			profile      = function() return emptyProfile end,
			profileFunc  = function() return emptyProfile end,
			mark         = emptyFunc,
			markMemory   = emptyFunc,
			isDebug      = false,
			_stopProfile = emptyFunc,
		}
		
local function setDebugMode(debug)
	if isDebug == nil then
		local info = infoChannel:peek()
		if info then
			isDebug = info.debug
		else
			if debug == nil then
				debug = true
			end
			isDebug = debug
			infoChannel:push({debug=debug})
		end
	end
end

return function(debug)
	setDebugMode(debug)
	if isDebug then
		return AppleCake
	else
		return AppleCakeRelease
	end
end