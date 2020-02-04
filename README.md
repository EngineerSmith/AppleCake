# AppleCake
Visual Profiling tool for Love2D using Chromium's trace event profiling tool

* [AppleCake Functions](#AppleCake-functions)
* [Example](#Example)
* [Viewing the data](#Viewing-AppleCake)

## Installing
run `git clone https://github.com/EngineerSmith/AppleCake` in your projects lib folder or where you choose

You should be able to pull it into your project by requiring the folder you cloned the repository to, as the repository includes a `init.lua` file.
If you cloned it to the suggested lib, you would have something similar to `require("lib.AppleCake")()`

## Usage
### Require
First you want to obtain the profiling tool, this will return a function that you're more than likely will call straight away.
```lua
local profiler = require("lib.AppleCake")()
```
You can pass in false into this function that is return if you are wanting to disable the profiling tool. This will save time from trying to pull it out of your project when wanting to release it. 
```lua
local profiler = require("lib.AppleCake")(true) -- Default option, that will return AppleCake
local profiler = require("lib.AppleCake")(false) -- This option will turn AppleCake off
```
**Warning**  You can only set the debug attribute once, then whenever you try to include it again it will return the same table.
This is so you won't have to tell the library if you're in debug mode repeatively.  
E.g. if you do `require("lib.AppleCake")([true|false])`, then do `require("lib.AppleCake")([true|false])` again or in another file it will return the same table as the first require.
### AppleCake functions
#### .beginSession([filepath])
This will open a file to allow writing. `filepath` is a optional parameter. You can only have one session active at a time, this will be the file that is written to. If called again, it will close the previous session for you.
```lua
profiler.beginSession() --Default option will create file "profile.json" in the path the project is ran from.
profiler.beginSession("C:/file/path/profileSession.json")
```
#### .endSession()
This close's the active session, this function needs to be called otherwise the file will not be closed correctly.
```lua
profiler.endSession()
```
#### .profile(name, [profile])
This function create's a new profile, or reuses the table passed in.
```lua
local _profile = profiler.profile("love.update")

--Example of reusing profiles to save creating garbage
local _profile
local function foo()
	_profile = profiler.profile("foo", _profile)
	--...code
	_profile:stop()
end
```
#### .profileFunc([profile])
This function create's a new profile for the current function it within by generating a name. It will reuse the table passed in. This will generate the name as "\<function name\>@\<file.lua\>#\<lineNum\>" e.g. `function love.draw` in main.lua on line 24 becomes "draw@main.lua#24"
```lua
local _profile = profiler.profileFunc()

--Example of reusing profiles to save creating garbage
local _profile
local function foo()
	_profile = profiler.profileFunc(_profile)
	--...code
	_profile:stop()
end
```
#### .profile:stop()
This stops a profile and records the elapsed time since the profile was created. You cannot stop a profile more than once.
```lua
_profile:stop()
--or if you really wanted to
_profile.stop(_profile)
```
### Example
An example of AppleCake in a love2d project. Example uses underscore infront of profiling, this is not a requirement. It's formatted like this to stop possible clashes with other variables if you're adding it to an exisiting project
```lua
local lg = love.graphics

local profiler = require("lib.AppleCake")()
profiler.beginSession() --Will create "profile.json" next to main.lua

function love.quit()
	profiler.endSession() --Close the session when the program ends
end

local function loop(count)
	local _p = profiler.profile("Loop "..count) --Adding parameters to name than using profileFunc
	local n = 0
	for i=0,count do
		n = n + i
	end
	_p:stop()
end

local r = 0
local _pp --Example of reusing profile tables
function love.update(dt)
	_pp = profiler.profileFunc(_pp)
	r = r + 0.4 * dt
	loop(100000) --Nested profiling
	_pp:stop()
end

function love.draw()
	local _p = profiler.profileFunc() --Will create new table everytime this function is ran
	lg.push()
	lg.translate(50,50)
	lg.rotate(r)
	lg.rectangle("fill", 0,0,30,30)
	lg.pop()
	_p:stop()
end
```
### Viewing AppleCake
Open your Chromium browser of choice (Such as Chrome) and go to [chrome://tracing/](chrome://tracing/). Once the page has loaded, you can drag and drop the `*.json` into the page. This will then load and show you the profiling. You can use the tools to move around and look closer at the data. You can click on sections to see how long a profile took, along with it's name if you don't want to zoom in.  
Example of one frame from using the code in [Example](###Example).
![example](https://i.imgur.com/zabVoRs.png "Example of chrome tracing")
