local vpk = require("modules.vpk")
local crc32 = require("modules.crc32")
local imlib2 = require("modules.imlib2")

local pak = vpk.new()
pak:addFiles("test")
pak:save("test.vpk")

print("Directory")
for k,v in pairs(pak.directory) do print("\t" .. k) end

local f = assert(pak:getFile("something.txt"))
print("DATA", f:readAll())
print("VERYIFY", f:verify())

f:close()

local font = imlib2.font("Hypatia-Sans-Pro/11")
print(font:getSize("Tiejajdsiao"))

imlib2.font.addPath("fonts/")
imlib2.font.getPaths()

local img = imlib2.image("prerendered_items/dagon.png")
print(img, img:getSize())
img:blur(3)

local test = imlib2.image.new(32, 32,true)
print(test, test:getSize())
test:fillElipse(16,16,8,8,imlib2.color.blue)
test:blur(3)

img:blendImage(test, false, 0, 0, 128, 64, 0, 0, 128, 64)
test:free()

img:save("test.png")
img:free()