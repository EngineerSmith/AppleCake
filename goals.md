# AppleCake 3.0
- Zero-overhead when disabled (everything is JIT-ted out)
- Add zones to section profiling data, so sections can be disabled/enabled independently than the whole library being on/off
- Native support for MintMousse (support would be more on MM's side, but need to expose hooks)
- Support JSON export still (look into perfetto - I'm opening to the idea of distributing shared libraries, as long as we make a git actions to build it and have it in every release for every love supported platform)
- Automatic hooks into love.handlers
- Move docs to mkdocs-material
- Remove: jprof, old debug calls, etc.
- We want performance
- Keep threaded support!

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

ac.snapshotMemory(seconds:0.1) -- Time between snapshots, managed internally using love.timer

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

# Should we support the flow of `:profile(name, profile)
where we check if `args` is a table, and if it has our profile metatable - it means no more flow of:
local profile
profile = zone:profile("foobar", nil, profile) -- That additional nil - so easy to forget, but having it written out like this makes it easy to remember

# What about this idea? profile:start()

Where you can start a stopped profile, so you don't have to use the same `zone:profile` zone anymore, you could pass something like `zone:profile("foobar", nil, "doNotStart") or something, and then it can be used as an object?

I'm not sold on this idea, AppleCake 2.0, stuck with defining it every time, because it was simple - you didn't need to manage the lifetime of the object so well, you just created it, and passed it in if you wanted to reuse it.

]]

```