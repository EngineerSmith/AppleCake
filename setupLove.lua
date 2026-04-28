-- Script used to setup love for AppleCake, mostly taken from MintMousse
-- https://github.com/EngineerSmith/MintMousse

if not love.thread then
  require("love.thread")
end

if love.isThread == nil then
  -- Path module is only loaded on main thread. A user is very unlikely to load it before AppleCake, if ever
  love.isThread = love.path == nil
end
