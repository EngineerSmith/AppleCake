# AppleCake
Visual Profiling tool for Love2D using Chromium's trace tool. AppleCake 2 works with Love 11.4-5 and Love 12.0

## Features
* **Profile** how long functions take, with profile nesting!
* **Mark** timeless events
* **Track** variable changes onto a graph
* **View Variables** in trace tool as args
* Profile **Lua memory** usage
* **Multi-threaded profiling** support
* **Disable for release** easily
* Recover **Crashed** data with ease

## AppleCake Docs
You can view the docs at https://engineersmith.github.io/AppleCake-Docs/ or open the `index.html` locally from that repo

## Installing
run `git clone https://github.com/EngineerSmith/AppleCake` in your project's lib folder or where you choose  
You should be able to pull it into your project by requiring the folder you cloned the repository to, as the repository includes a `init.lua` file. See documentation for further details of how to require AppleCake correctly.

```lua
-- Point of entry, e.g. main.lua
local appleCake = require("lib.AppleCake")(true)  -- turn on profiling
local appleCake = require("lib.AppleCake")(false) -- turn off profiling

-- Other files and threads
local appleCake = require("lib.AppleCake")()      -- get whatever appleCake has been loaded by the first call
```
## Example
An example of AppleCake in a love2d project. You can see many more examples and how to use AppleCake in [AppleCake Docs](#AppleCake-Docs)
```lua
local appleCake = require("lib.AppleCake")(true) -- Set to false will remove the profiling tool from the project
appleCake.setBuffer(true) -- Buffer any profile calls to increase performance
appleCake.beginSession() --Will write to "profile.json" by default in the save directory
appleCake.setName("Example")

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
  mem = mem + dt
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
  appleCake.flush() -- Flush any profiling data to be saved
end

function love.keypressed(key)
  appleCake.mark("Key Pressed", "p", {key=key}) -- Adds a mark every time a key is pressed, with the key as an argument
end
```

## Viewing AppleCake profiling data
Open your Chromium browser (Chrome and Edge have been tested to work) and go to `about://tracing`. If you don't have a Chromium browser, you can go to https://ui.perfetto.dev/v23.0-b574f45ca/assets/catapult_trace_viewer.html and it should work the same.

Once the page has loaded, you can drag and drop the created profile JSON into the page. This will then load and show you the data. You can use the tools to move around, but it's recommended to use the keyboard shortcuts. Press `?` on your keyboard or in the top right of the page to see the shortcuts.
Example of a frame of data, see the docs for more examples and details.
![example](https://i.imgur.com/6SBDkSc.png "Example of chrome tracing")
