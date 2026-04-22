# Wants
- Zero-overhead when disabled (JIT-friendly)
- Add zones to section profiling data, so sections can be disabled/enabled independently than the whole library being on/off
- Native support for MintMousse (support would be more on MM's side, but need to add hooks)
- Support JSON export (Perfetto + MM, retire using chrome:\\tracing)
- Automatic hooks into love.handlers / common callbacks
- Docs via mkdocs-material
- remove: jprof, old debug-heavy paths, etc.

# Example
```lua
-- OLD
local appleCake = require("AppleCake")(true) -- False will remove the profiling tool from the project
appleCake.beginSession() -- Will create "profile.json" in the save directory by default
appleCake.setBuffer(true) -- buffer all profiling calls before pushing to be saved out. Function works per thread.

local thread = love.thread.newThread("TestThread.lua") -- Must start after appleCake has been started, to ensure this thread is owner of appleCake
thread:start() -- You can call appleCake's profiling and mark functions within another thread, see further docs for more details

function love.quit()
  appleCake.mark("Quit", "p")  -- Add markers for timeless events, by default it will show for the entire process, "t" will show mark for only the current thread in the data
  appleCake.endSession() -- In the event of a crash or endSession isn't reached, you can still recover the data
  -- End session also flushes any unflushed data, due to buffering being set to true
end

function love.load()
  appleCake.mark("Started load") -- Adds a mark, can be used to show an events or other details
end

local profileLoop -- Reuse tables to avoid garbage 
local function loop(count)
  profileLoop = appleCake.profile("Loop "..count, nil, profileLoop) -- Wrap a section of code in a profile, it doesn't have to be the entire function
  local n = 0
  for i=0,count do
    n = n + i
    appleCake.counter("loop", {n}) -- record variable, and make a bar graph of it's change
  end
  appleCake.counter("loop", {0})
  profileLoop:stop() -- will write the result to file - once data has been flushed (will do it instantly if setBuffer is false)
end

local r, mem = 0, 0
local profileUpdate -- Reuse tables to avoid garbage 
function love.update(dt)
  profileUpdate = appleCake.profileFunc(nil, profileUpdate) -- Auto-generates a name for the function once as we reuse, "update@main.lua#32"
  r = r + 0.5 * dt
  loop(100000) -- Example of nested profiling, as the function has it's own profile
  profileUpdate:stop()
  mem = mem + dt
  if mem > 0.1 then -- We record memory every 0.1 seconds
    appleCake.countMemory() -- Adds a bar on a bar graph with details of current lua memory usage
    mem = 0
  end
end

local lg = love.graphics
function love.draw() -- "draw@main.lua#45", generates name for function
  local profileDraw = appleCake.profileFunc() -- This will create new profile table every time this function is ran
  lg.push()
  lg.translate(50,50)
  lg.rotate(r)
  lg.rectangle("fill", 0,0,30,30)
  lg.pop()
  profileDraw.args = lg.getStats() -- Set args that we can view later in the viewer
  profileDraw:stop() -- By setting it to love.graphics.getStats we can see details of the draw
  appleCake.flush() -- Flush any profiling data out, would be useful to write love.run to include it
end

function love.keypressed(key)
  appleCake.mark("Key Pressed", nil, {key=key}) -- Adds a mark every time a key is pressed, with the key as an argument
end


------
-- new
-----
local ac = require("AppleCake") -- To disable, everything, don't call beginSession, or enable/disable the individual zones
ac.beginSession()
ac.endSession() -- Closes session if one is open, otherwise ignored.
-- Above should also end any open batches

ac.setThreadName(name)

ac.startBatch() -- Like start/end Frame
ac.endBatch()
-- Maybe even ac.startBatch("recordMemory") and we can auto record memory every 0.1 seconds or something, see countMemory

ac.addHook(channel[, options:nil]) -- if channel is nil, add/remove json based output library itself adds - stop thread
-- Options, passed to the channel as the first entry, used for things like filepath for the default json, e.g. ac.addHook(nil, { filepath = "date.profile" })
ac.removeHook(channel)
ac._onHookChange(channel, function(state --[[add/remove]]) end) -- Use this to manage the hook, we'll expose it, but mostly used internally
-- Message sent over channels:
{ -- encoded via string buffers
  type = "begin", options = options,
  time = unixTime,
}
{
  type = "profile", 
  name = name, args = args,
  start = getTime(), -- time since program start
  finish = getTime(),
  _stopped = false, -- this is an internal value - we can still send it since it'd take more time to remove than it's worth
} -- etc. pretty much the same as the old system, but more "open" to having "hooks"

ac.autoProfile() -- Auto adds profiling to all love.handlers
-- I wish we could do callbacks (non-events), but that is much difficult when `love.update` is a direct change to the `love` global table - I would have to add a metatable to `love` global to do it properly. OR have a custom game loop, which is just way over stepping for a profiling library

ac.countMemory() -- Can we have this automatically just do? While I like exposing the function, if someone used it without limiting it - the data is kind of pointless. Since it isn't a "real" way to record memory at all. Could we query the OS? Add ffi windows API, and unix support, and fallback to gc count?


local zone = ac.zone(name[, enabled:true]) -- optional enable/disable, if disabled, all children are disabled if they don't specify a state i.e. nil
local childZone = zone:extend(name[, enabled:true]) -- name:name
-- Is there a way we can do this without having to pass objects around? Can we use names as unique identifiers instead?

local profile = ac.profile(name[, args:nil, profile:nil]) -- reuse profile table to prevent repetitive memory assignments
local profile = zone:profile(name[, args:nil, profile:nil])

profile.args = fooBar -- still able to update and change them as the scope goes on
profile:stop()

local profile = ax.profileFunc([args:nil, profile:nil]) -- Update to use jit.util.funcinfo than debug.getinfo  to generate a function name
local profile = zone:profileFunc([args:nil, profile:nil])

ac.mark(name[, scope:"process", args:nil]) -- move from "p", "t" -> "process", "thread"
zone:mark(name[, scope:"process", args:nil])

local counter = ac.counter(name[, args, counter])
local counter = zone:counter(name[, args, counter])

--- Questions this brings up
-- Do zones need names? Can we remove names? If we have names can we use them to assign hierarchy?
-- Should we enforce frames? If we do, how do frames work on threads? That should be left to a gameloop profile, not for us to handle separately
-- If we did have frames, we could manually track GC memory usage - we need better memory insight than collectcarbage("count")
-- For zone names, could we use MM logging names? We could always generate a zone name for the file
-- Could we profile memory per zone to find hotspots? Not with the current way to get memory, it would just be too inefficient. 
-- What if there are multiple files with the same name e.g. init.lua; can we differentiate them? Can we add the zone name to their channel message so it can be recorded out?

--- Notes
-- The name that profile/mark/counters have is different from zones. This is human readable needing name, while zones don't have to be human readable

--- Answer
--[[

What about this idea:

name (all names, zones, profiling, mark) is like this: "engine.ai.pathfinding" - So this is two zones "engine" "ai", and one profile "pathfinding". If they're other profiles then they don't need it. This remove the low-level of how it previously worked, but makes it much more friendly to use. For example:
]]

local z = ac.zone("engine")
local p, p2
--
p = z:profile("ai", p) -- on the chart it's named "engine.ai"
p2 = z:profile("pathfinding", p2) -- on the chart it's just named "pathfinding", internally it's "engine.ai.pathfinding" - since it will be displayed on the flame graph as "pathfinding" within "engine.ai"
p2:stop()
p:stop()

-- question
local z2 = ac.zone("engine.ai.statemachine")
local p3 = z2:profile("idleState") -- how would this display?, what if it's not within the time scope of previous "ai.engine" profile? 
p3:stop()

-- question
-- How would this work for a function that's name is generated
local foo = function()
  local p4 = z2:profileFunc() -- will generated something like file@foo#165, or with the new name system "engine.ai.statemachine.file@foo#165" if not within any other scope
  p4:stop()
end

-- Ofc all strings will be added to a lookup, so they only need to be parsed once, so the 1st frame will take a hit, but everything after should be fine

```