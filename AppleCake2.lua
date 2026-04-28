local PATH = (...):match("(.-)[^%.]+$")
local dirPATH = PATH:gsub("%.","/")

require(PATH .. "setupLove")

love.__applecake = PATH

local logging = require(PATH .. "logging")