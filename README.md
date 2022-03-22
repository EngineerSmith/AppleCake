# AppleCake
Visual Profiling tool for Love2D using Chrome's trace tool. AppleCake has been tested and built on Love 11.3
## Features
* **Profile** how long functions take, with profile nesting!
* **Mark** timeless events
* **Count** map variable changes onto a graph
* **View Variables** in trace tool as args
* Profile **Lua memory** usage
* **Multi-threaded profiling** support
* **Disable for release** easily
* Recover **Crashed** data with ease
* Switch to and from **jprof** easily so you can try it out on your project
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
    if i % 10 == 0 then
      n = n + i
      appleCake.counter("loop", {n}) -- not best practice; an example of what you can do
    end
  end
  appleCake.counter("loop", {0}) -- reset graph to 0 after counting has stopped
  profileLoop:stop()
end

local r, mem = 0, 0
local profileUpdate --Example of reusing profile tables to avoid garbage
function love.update(dt)
  profileUpdate = appleCake.profileFunc(nil, profileUpdate)
  r = r + 0.5 * dt
  loop(100000) -- Example of nested profiling, as the function has it's own profile
  profileUpdate:stop()
  if mem < 0.5 then -- We do it every 0.5 seconds to over strain the system
    appleCake.countMemory() -- Adds counter with details of current Lua memory usage, this becomes a graph
    mem = 0
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
## Jprof
To help make it easier to try out or migrate, you can easily use existing jprof calls. Below shows off how, with 2 additional functions to make it fit into AppleCakes workflow capitalized to show their seperation from usualu jprof calls
```lua
local appleCake = require("lib.AppleCake")(true) -- Set to false will remove the profiling tool from the project

local jprof = appleCake.jprof
-- One of the different function from normal jprof
jprof.START() -- takes in filename to know where it should write to
-- equally can call appleCake.beginSession(filename)

function love.quit()
  jprof.write()
  -- similar to the orginal, except appleCake needs to open the file from the start to work (see above),
  -- so this closes the current file and opens the given file.
  -- You can call `appleCake.endSession` to close the current file without opening a file
end

local function loop(count)
  jprof.push("Loop "..count)
  local n = 0
  for i=0,count do
    if i % 10 == 0 then
      n = n + i
    end
  end
  jprof.pop("Loop "..count)
end

local r = 0
local profileUpdate --Example of reusing profile tables to avoid garbage
function love.update(dt)
  jprof.push("frame")
  jprof.push("love.update")
  r = r + 0.5 * dt
  loop(100000) -- Example of nested profiling, as the function has it's own profile
  
  jprof.COUNTMEMORY() -- tracks memory; as we don't track memory each time push is called like jprof
  -- renamed function from appleCake.countMemory
  jprof.pop("love.update")
end

local lg = love.graphics
function love.draw()
  jprof.push("love.draw")
  lg.push()
  lg.translate(30*math.sqrt(2),30*math.sqrt(2))
  lg.rotate(r)
  lg.rectangle("fill", 0,0,30,30)
  lg.pop()
  jprof.pop("love.draw")
  jprof.pop("frame")
end
```
