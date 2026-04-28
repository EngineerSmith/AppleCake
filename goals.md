# AppleCake 3.0
Rough goals to achieve/keep
- Zero-overhead when disabled (everything is JIT-ted out)
- Add zones to section profiling data, so sections can be disabled/enabled independently than the whole library being on/off
- Native support for MintMousse (support would be more on MM's side, but need to expose hooks)
- Support JSON export still (look into perfetto - I'm opening to the idea of distributing shared libraries, as long as we make a git actions to build it and have it in every release for every love supported platform)
- Automatic hooks into love.handlers
- Move docs to mkdocs-material
- Remove: jprof, old debug calls, etc.
- We want performance
- Keep threaded support!

## 3.0 upgrades over 2.1
- Faster - by replacing debug.getinfo with jit.util.funcinfo
- Zones let you enable/disable areas of profiling
- Support for perfetto shared/dynamic library
- Support for custom hooks
- Removes old jprof code added to "market" the library by making it a drop in place
  * I don't want to maintain that code
- Enforced naming scheme (Could be seen as a negative, but allows for cooler implementation)


# Spec
```lua
local ac = require("AppleCake")

ac.beginSession() -- closes session if one is open, and opens a new one
ac.endSession() -- closes session if one is open, otherwise ignored
-- If there is no current session, all function calls should work like the library has been disabled!

ac.setThreadName(name) -- give a human readable name to the current thread

ac.startBatch() -- can be used for start/end frame
ac.endBatch()
-- The batch is using a string buffer, and will keep adding to the string buffer's buffer! This prevents profiles overwriting each other if reused within the same batch
-- Note, perfetto hook ignores batching

-- New system to support multiple outputs
ac.addHook(channel[, options:nil]) -- if channel is nil, add/remove library's implemented recorder
ac.removeHook(channel)
ac._onHookChange(channel, function(state) --[[add/remove]] end) -- Used internally, exposed for others to manage their own if they need access to this function

-- Example of messages:
 -- encoded via string buffers
{
  type = "begin", options = options,
  time = unixTime,
}
{
  type = "profile", 
  name = name, args = args,
  start = getTime(), -- time since program start
  finish = getTime(),
  _stopped = false, -- this is an internal value - we can still send it since it'd take more time to remove than it's worth
} -- etc. pretty much the same as the old system, but more "open" to having "hooks" w/ docs
{ -- new example, since I don't know exactly how adding to a string buffer works if you keep adding tables without reading it, how it decodes. TODO look into it!
  type = "batch",
  [1] = { -- contains array of messages
    type = "profile", ...
  }
  [n] = { ... }
}

-- Used internally, and exposed for those who add hooks
local encoded = ac._encode(message)
local message = ac._decode(encoded)

ac.autoProfile() -- Auto adds profiling zones for love.handler functions (events)

ac.snapshotMemory(seconds:0.1) -- Time between memory snapshots, managed internally using love.timer - still using a counter internally
-- What if you want to test memory before and after a function has ran?
-- Could we expose `getMemoryUsage` func, which can be put into an arg value e.g.
local profile = ac.profile("", { before = ac.getMemoryUsage() })
foo()
profile.args.after = ac.getMemoryUsage()
profile:stop()
-- So now we can have both! A constant snapshot of memory usage, but also detailed memory usage if required
-- Should profiles automatically check memory usage?


local zone = ac.zone(name[, enabled:true]) -- optional enable/disable, if disabled, all children are disabled if they don't specify enabled = true

local profile = ac.profile(name[, args:nil, profile:nil]) -- reuse profile table to prevent repetitive memory assignments
local profile = zone:profile(name[, args:nil, profile:nil])
-- If you use ac.profile, it uses an internal zone which is basically "nil"

profile.args = fooBar -- still able to update and change profile args as the scope goes on
profile:stop()

local profile = ac.profileFunc([args:nil, profile:nil]) -- Update to use jit.util.funcinfo than current debug.getinfo
local profile = zone:profileFunc([args:nil, profile:nil])

ac.mark(name[, scope:"process", args:nil]) -- move from "p", "t" to "process", "thread" - or better names
zone:mark(name[, scope:"process", args:nil])

local counter = ac.counter(name[, args:nil, counter:nil]) -- reuse counters as we had them before
local counter = zone:counter(name[, args:nil, counter:nil])

--[[
# Why zones?

AppleCake has always been a profiler you can add to your code, which you could disable without needing to removing all the code, but this is very binary, all or nothing. With zones, you can individually choose areas of code you want to profile, this doesn't just make profiling more targetted, it means a lot less performance is taken up by disabled zones.

The whole library can still be disabled, just never start a session!

# How do names work?

All names (zones, profiling, mark, counter, etc.) work with a separator, ie. "engine.ai.pathfinding" - so this could be two zones, "engine" and "ai", and one profile "pathfinding". This enforces a workflow that AppleCake 2.0 does not. But, we get more fine control over what is profiled or what isn't. Plus, if we give this as a searchable category, users can do "engine.ai.*" to find everything in their ai zone.

]]

-- Example
local z1 = ac.zone("engine")
local z2 = ac.zone("engine.ai") -- child of "engine"

local p1, p2
p1 = z1:profile("ai", nil, p) -- while there is a conflict, it can easily be resolved as zones are just categories - they can have the same namespace as a zone!
p2 = z1:profile("pathfinding", nil, p2) -- This will be in category "engine.ai.pathfinding", but in perfetto only show as "pathfinding", as the above profile will show "engine.ai", and thus, it can be inferred, that it is "engine.ai.pathfinding", while still being readable!

p2:stop()
p1:stop()

local z3 = ax.zone("engine.ai.stateMachine")
local p3 = z3:profile("idleState") -- As it's not within `p1`, it will appear as "engine.ai.stateMachine.idleState" as it's not within any other scope
p3:stop()

local p4
local foo = function()
  p4 = z3:profileFunc({ }, p4) -- Will appear as "engine.ai.stateMachine.file@foo#165, as profileFunc generates it's own name based on the call stack
  p4.args.data = "bar" -- it can be accessed and filled - note that we had to set it to an arg table, otherwise we would index nil (note, arg tables can also be reused)
  p4:stop()
end

--[[
# Questions

## Who should handle scopes? How should scopes be handled? 

I like the idea of handle once, cache into the profile table to be reused - we can always check if the scope or given name changes and update it accordingly. We can document that users should avoid dynamic names due to performance of handling the strings and scope. If they complain, we point them to the sign about dynamic names. This is a architecture choice of AppleCake 3.0

Zones handle scope; and there is a "global" table within AC which determines which scopes are enabled or disabled, so it can be easily checked if a scope is disabled, Note the following

# Should names be resolved when the profile is created once and put into a lookup table, or should the name, and scope be given to the hook to handle themselves?

Names should resolved once within the zone, and used again with the reusableProfile that can be passed back in

]]

-- this should be supported
ac.zone("engine", true)
ac.zone("engine", false) -- later disable it at runtime

-- Zones scopes are really this sort of tree structure with 3 states:
ac.zone("engine.ai", true) -- as true is specified, it overrules "engine" and this section is enabled
ac.zone("engine.ai") -- as nil, it just inheirts whatever it's parent says
ac.zone("engine.ai", false) -- as false is specified, it will ignore it's parent and be disabled even if parent is enabled

-- Consider for the zone object:
zone:enable()
zone:disable()
zone:isEnabled()
```

If we're going to be moving to using a shared/dynamic library for perfetto - should we still support json method? Perfetto handles it's own thread, rather than having to rely on internal love threads and messaging cost between them - so perfetto doesn't need encoded messages, it can be handled "on site". Since, I assume, it knows how to handle multiple threads hitting the same API - I guess we'd need to look into if we have to have some sort of "state" we need to pass between threads so they all use the same perfetto thread.

If we're not supporting json - that means the default hook needs a way to understand string buffers - unless we look at how we can do batching, or disable batching for perfetto. Then why do we have batching at all? Just for custom hooks?

Decision:
We support both, but all hooks have to be manually set before starting a session, otherwise nothing will happen


```lua
ac.addHook("json", { filepath = "profile.json" })
ac.addHook("perfetto", { filepath = "profile.perfetto", ignoreArgs = false }) -- ignoreArgs for profiles, and marks for performance reasoning over FFI C isn't JIT compilable
ac.beginSession()
ac.removeHook("json") -- Can't remove hooks during session? Or do we just "fake" ending the session for them if one is currently running? It's more control to the user than restricting them
ac.removeHook("perfetto")

```

Obviously, all hooks are synced across all threads via AppleCakes internals. Should we enforce, main thread only functions? Yes, just keeps it simple

# Old
Old feature list:
- Profile how long code takes
- Nested profiling, so you can get more detailed information
- mark timeless events when they happen
- Track variables on a bar graph as they change
- View variables later in the trace tool
- Profile Lua's memory usage in a bar graph format
- Multi-threaded profiling support
- Disable for release easily
- Recover Crashed data with ease
- Switch to and from jprof easily so you can try AppleCake out in your project

```lua
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

--// testThread.lua
local appleCake = require("AppleCake")() -- Will be disabled if the main thread set AppleCake to false
-- Note we don't set buffering so everything is pushed to the save thread as soon as it can be

local function foo() -- "foo@TestThread.lua#3"
  local profile = appleCake.profileFunc()
  local n = 0
  for i=0, 100000 do
    n = n + i
  end
  profile:stop()
end

while true do
  foo()
  love.timer.sleep(1) -- love.timer is required by AppleCake on threads, only if profiling is turned on
end
```