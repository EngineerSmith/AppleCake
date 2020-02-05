local PATH = ... -- Path is passed into thread
local outputStream = require(PATH.."outputStream")
local channel = love.thread.getChannel(require(PATH.."threadConfig").id)

local exit = false

local function excuteCommand(c)
	if c.command == "open" then
		outputStream.openStream(c.args.file)
		return
	end
	if c.command == "close" then
		outputStream.closeStream()
		exit = true
		return
	end
	if c.command == "write" then
		if c.args.profile then
			outputStream.writeProfile(c.args.profile)
		elseif c.args.mark then
			outputStream.writeMark(c.args.mark)
		end
		return
	end
end

while not exit do		
	excuteCommand(channel:demand())
end