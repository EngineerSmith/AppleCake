-- Script used to setup love for AppleCake, taken from MintMousse's style
-- https://github.com/EngineerSmith/MintMousse/blob/main/setupLove.lua

local errMsg = "AppleCake: Library is missing dependency LÖVE's %s module."

if not love.thread then
  assert(pcall(require, "love.thread"), errMsg:format("thread"))
end

if not love.timer then
  assert(pcall(require, "love.timer"), errMsg:format("timer"))
end

if love.isThread == nil then
  -- Path module is only loaded on main thread. A user is very unlikely to load it before AppleCake, if ever
  love.isThread = love.path == nil
end
