local network = require("Network")
local HoloArray = require("HoloArray")
local Vec3 = require("Vec3")
local Map = require("Map")

local port = 1
local addressFile = "array"
local mapPath = "map"
local chunkSize = Vec3:new(8, 1, 8)

function colorFunc(pos, block)
    if block == 0 or block == nil then
        return 0
    end
    
    if pos.y == -2 or pos.y == -6 then
        return 1
    else
        return 2
    end
end

local array = HoloArray:new(Vec3:new(2, 1, 2))
array:setProjectors(addressFile)

local green = 0x00FF00
local red = 0xFF0000

array:setPaletteColor(1, green)
array:setPaletteColor(2, red)
    
print("Waiting for map data...")

network.receiveDirectory(port, mapPath)

print("Map data received")

print("Displaying map...")

local map = Map:new(chunkSize, mapPath)
map:loadMetadata()

array:clear()
array:showMap(map, colorFunc)
