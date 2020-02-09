local PATH, OWNER = ...
local outputStream = require(PATH.."outputStream")

local config = require(PATH.."threadConfig")
local outStreamChannel = love.thread.getChannel(config.outStreamID)
local infoChannel = love.thread.getChannel(config.infoID)

local function errorOut(msg)
	error("Error thrown by AppleCake thread\n".. msg)
end

local info = infoChannel:peek()
if info.owner ~= nil then
	errorOut("Cannot create new outputStream thread due to one already exsiting; owned by thread "..info.owner)
end

local exit = false

local function UpdateOwner(owner)
	local info = infoChannel:pop()
	info.owner = owner
	infoChannel:push(info)
end

local function excuteCommand(c)
	if c.command == "open" then
		local info = infoChannel:peek()
		if info.owner == nil then
			if OWNER == c.threadID then
				outputStream.openStream(c.args.file)
				infoChannel:performAtomic(UpdateOwner, OWNER)
			else
				errorOut("Thread "..c.threadID.." tried to begin session. Only thread "..OWNER..", that created the outputStream, can begin sessions")
			end
		end	
		return
	end
	if c.command == "close" then
		if OWNER == c.threadID then
			outputStream.closeStream()
			infoChannel:performAtomic(UpdateOwner, nil)
			exit = true
		else
			errorOut("Thread "..c.threadID.." tried to end session owned by thread "..OWNER)
		end
		return
	end
	if c.command == "write" then
		if c.args.profile then
			outputStream.writeProfile(c.args.profile, c.threadID)
		elseif c.args.mark then
			outputStream.writeMark(c.args.mark, c.threadID)
		end
		return
	end
end

while not exit do		
	excuteCommand(outStreamChannel:demand())
end