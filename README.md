# AppleCake
Visual Profiling tool for Love2D using Chromium's trace event profiling tool

* [AppleCake Functions](#AppleCake-functions)
* [Example](#Example)
* [Viewing the data](#Viewing-AppleCake)
* [Recovering profiling data](#Crash)

## Installing
run `git clone https://github.com/EngineerSmith/AppleCake` in your projects lib folder or where you choose

You should be able to pull it into your project by requiring the folder you cloned the repository to, as the repository includes a `init.lua` file.
If you cloned it to the suggested lib, you would have something similar to `require("lib.AppleCake")()`

## Usage
### Require
First you want to obtain the profiling tool, this will return a function that you're more than likely will call straight away.
```lua
local appleCake = require("lib.AppleCake")()
```
You can pass in false into this function that is return if you are wanting to disable the profiling tool. This will save time from trying to pull it out of your project when wanting to release it. 
```lua
local appleCake = require("lib.AppleCake")(true) -- Default option, that will return AppleCake
local appleCake = require("lib.AppleCake")(false) -- This option will turn AppleCake off
```
**Warning**  You can only set the debug attribute once, then whenever you try to include it again it will return the same table.
This is so you won't have to tell the library if you're in debug mode repeatively.  
E.g. if you do `require("lib.AppleCake")([true|false])`, then do `require("lib.AppleCake")([true|false])` again or in another file it will return the same table as the first require.
### AppleCake functions
#### .beginSession([filepath])
This will open a file to allow writing. `filepath` is a optional parameter. You can only have one session active at a time. If called again, it will close the previous session for you. Sessions will overwrite the file if it already exists.
```lua
appleCake.beginSession() --Default option will create file "profile.json" in the path the project is ran from.
appleCake.beginSession("C:/file/path/profileSession.json")
```
#### .endSession()
This close's the active session, this function needs to be called otherwise the file will not be closed correctly with the right formatting. If in the event of a crash, you might add "]}" to the end of the json to recover the data, see (Crash)[#Crash].
```lua
appleCake.endSession()
```
#### .profile(name, [profile])
This function create's a new profile, or reuses the table passed in.
```lua
local _profile = appleCake.profile("love.update")

--Example of reusing profiles to save creating garbage
local _profile
local function foo()
	_profile = appleCake.profile("foo", _profile)
	--...code
	_profile:stop()
end
```
#### .profileFunc([profile])
This function create's a new profile for the current function it within by generating a name. It will reuse the table passed in. This will generate the name as "\<function name\>@\<file.lua\>#\<lineNum\>" e.g. `function love.draw` in main.lua on line 24 becomes "draw​@main.lua#24"
```lua
local _profile = appleCake.profileFunc()

--Example of reusing profiles to save creating garbage
local _profile
local function foo()
	_profile = appleCake.profileFunc(_profile)
	--...code
	_profile:stop()
end
```
#### .profile:stop()
This stops a profile and records the elapsed time since the profile was created. You cannot stop a profile more than once, but can reuse the table by passing it back into AppleCake.
```lua
_profile:stop()
```
## Example
An example of AppleCake in a love2d project. Example uses underscore infront of profiles, this is not a requirement. It's formatted like this to stop possible clashes with other variables if you're adding it to an exisiting project and to make the variables stand out.
```lua
local appleCake = require("lib.AppleCake")(true) -- Set to false will remove the profiling tool from the project
appleCake.beginSession() -- Will create "profile.json" next to main.lua by default

function love.quit()
	appleCake.endSession() -- Close the session when the program ends
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
local _profileUpdate --Example of reusing profile tables to avoid garbage build up
function love.update(dt)
	_profileUpdate = appleCake.profileFunc(_profileUpdate)
	r = r + 0.5 * dt
	loop(100000) -- Example of nested profiling, as the function has it's own profile
	_profileUpdate:stop()
end

local lg = love.graphics
function love.draw()
	local _profileDraw = appleCake.profileFunc() -- This will create new profile table everytime this function is ran
	lg.push()
	lg.translate(50,50)
	lg.rotate(r)
	lg.rectangle("fill", 0,0,30,30)
	lg.pop()
	_profileDraw:stop()
end
```
## Viewing AppleCake
Open your Chromium browser of choice (Such as Chrome) and go to [chrome://tracing/](chrome://tracing/). Once the page has loaded, you can drag and drop the `*.json` into the page. This will then load and show you the profiling. You can use the tools to move around and look closer at the data. You can click on sections to see how long a profile took, along with it's name if you don't want to zoom in.  
Example of one frame from using the code in [Example](###Example).
![example](https://i.imgur.com/6SBDkSc.png "Example of chrome tracing")
## Crash
If your application crashes or you didn't close the session, it is possible to recover the profiling data by adding "]}" to the json file, then continuing to use it as you normally would as the file is flushed everytime a profile is added.
