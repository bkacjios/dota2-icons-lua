local vpk = require("modules.vpk")

local pak = vpk.new()
pak:addFiles("test")
pak:save("test.vpk")

local f = assert(pak:getFile("something.txt"))
print(f:verify())
f:close()