# AppleCake
Visual Profiling tool for Love2D using Chrome's trace tool. AppleCake has been tested and built on Love 11.3
## Features
* **Profile** how long functions take, with nesting!
* **Mark** timeless events
* **View Variables** in trace tool as args
* Profile **Luas memory** usage
* **Multi-threaded profiling** support
* **Disable for release**, so you won't have to go through and remove AppleCake
* Recover **Crashed** data with ease
## AppleCake Docs
You can view the docs at https://EngineerSmith.github.io/AppleCake/ or open the `index.html` locally
## Installing
run `git clone https://github.com/EngineerSmith/AppleCake` in your projects lib folder or where you choose  
You should be able to pull it into your project by requiring the folder you cloned the repository to, as the repository includes a `init.lua` file. See documentation for further details of how to require AppleCake.
## Example
An example of AppleCake in a love2d project. You can see many more examples and how to use AppleCake in [AppleCake Docs](#AppleCake-Docs)
```lua
local appleCake = require("lib.AppleCake")(true) -- Set to false will remove the profiling tool from the project
appleCake.beginSession() --Will write to "profile.json" by default

function love.quit()
	appleCake.endSession() -- Close the session when the program ends
end

function love.load()
	appleCake.mark("Started load") -- Adds a mark, can be used to show a timeless events or other details
end

local function loop(count)
	local profileLoop = appleCake.profile("Loop "..count)
	local n = 0
	for i=0,count do
		n = n + i
	end
	profileLoop:stop()
end

local r = 0
local profileUpdate --Example of reusing profile tables to avoid garbage
function love.update(dt)
	profileUpdate = appleCake.profileFunc(nil, profileUpdate)
	r = r + 0.5 * dt
	loop(100000) -- Example of nested profiling, as the function has it's own profile
	profileUpdate:stop()
	
	if r % 15 == 0 then -- We do it every 30 frames to not clutter our data
		appleCake.markMemory() -- Adds mark with details of current Lua memory usage
	end
end

local lg = love.graphics
function love.draw()
	local _profileDraw = appleCake.profileFunc() -- This will create new profile table every time this function is ran
	lg.push()
	lg.rotate(r)
	lg.rectangle("fill", 0,0,30,30)
	lg.pop()
	_profileDraw.args = lg.getStats() -- Set args that we can view later in the viewer
	_profileDraw:stop() -- By setting it to love.graphics.getStats we can see details of the draw
end

function love.keypressed(key)
	appleCake.mark("Key Pressed", {key=key}) -- Adds a mark every time a key is pressed, with the key as an argument
end
```
## Viewing AppleCake
Open Chrome and go to `chrome://tracing/`. Once the page has loaded, you can drag and drop the created `*.json` into the page. This will then load and show you the profiling data it's recorded. You can use the tools to move around and look closer at the data.  
Example of a frame of data, see the docs for more examples and details.
![example](https://i.imgur.com/6SBDkSc.png "Example of chrome tracing")
