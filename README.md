# AppleCake
Visual Profiling tool for Love2D using Chrome's trace tool. AppleCake has been tested and built on Love 11.3
## Features
*
*
*
## AppleCake Docs
You can view the docs at http://EngineerSmith.github.io/AppleCake or open `index.html` locally

## Installing
run `git clone https://github.com/EngineerSmith/AppleCake` in your projects lib folder or where you choose

You should be able to pull it into your project by requiring the folder you cloned the repository to, as the repository includes a `init.lua` file. See documentation for further details of how to require AppleCake.

## Example
An example of AppleCake in a love2d project. You can see more examples and how to use AppleCake in [AppleCake Docs](#AppleCake-Docs)
```lua
local appleCake = require("lib.AppleCake")(true) -- Set to false will remove the profiling tool from the project
appleCake.beginSession(true) -- Will create "profile.json" next to main.lua by default, and writes on another thread

function love.quit()
	appleCake.endSession() -- Close the session when the program ends
end

function love.load()
	appleCake.mark("Started load") -- Adds a mark, can be used to show an events or other details
end

local function loop(count)
	local _profileLoop = appleCake.profile("Loop "..count) -- Adding parameters to profiles name to view later
	local n = 0
	for i=0,count do
		n = n + i
	end
	_profileLoop:stop()
end

local r = 0
local k = 0
local _profileUpdate --Example of reusing profile tables to avoid garbage build up
function love.update(dt)
	_profileUpdate = appleCake.profileFunc(nil, _profileUpdate)
	r = r + 0.5 * dt
	loop(100000) -- Example of nested profiling, as the function has it's own profile
	_profileUpdate:stop()
	
	if k % 30 == 0 then -- We do it every 30 frames to not clutter our data
		appleCake.markMemory() -- Adds mark with details of current lua memory usage
	end
	k = k + 1
end

local lg = love.graphics
function love.draw()
	local _profileDraw = appleCake.profileFunc() -- This will create new profile table everytime this function is ran
	lg.push()
	lg.translate(50,50)
	lg.rotate(r)
	lg.rectangle("fill", 0,0,30,30)
	lg.pop()
	_profileDraw.args = lg.getStats() -- Set args that we can view later in the viewer
	_profileDraw:stop() -- By setting it to love.graphics.getStats we can see details of the draw
end

function love.keypressed(key)
	appleCake.mark("Key Pressed", {key=key}) -- Adds a mark everytime a key is pressed, with the key as an argument
end
```
## Viewing AppleCake
Open your Chromium browser of choice (Such as Chrome) and go to [chrome://tracing/](chrome://tracing/). Once the page has loaded, you can drag and drop the `*.json` into the page. This will then load and show you the profiling. You can use the tools to move around and look closer at the data. You can click on sections to see how long a profile took, along with it's name if you don't want to zoom in.  
Example of one frame from using the code in [Example](###Example).
![example](https://i.imgur.com/6SBDkSc.png "Example of chrome tracing")
