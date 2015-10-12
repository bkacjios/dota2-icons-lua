local vpk = require("modules.vpk")
local crc32 = require("modules.crc32")

local pak = vpk.new()
pak:addFiles("test")
pak:save("test.vpk")

print("Directory")
for k,v in pairs(pak.directory) do print("\t" .. k) end

local f = assert(pak:getFile("something.txt"))
print("DATA", f:readAll())
print("VERYIFY", f:verify())

f:close()