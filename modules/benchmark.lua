local print = print
local clock = os.clock
local format = string.format

module("modules.benchmark")

local time

function start()
	time = clock()
end

function finish(msg, ...)
	print(format(msg:gsub("{time}", clock()-time), ...))
end