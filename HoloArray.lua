local Vec3 = require("Vec3")
local component = require("component")
local holo = component.hologram
 
local holoResolution = Vec3:new(48, 32, 48)
 
HoloArray = {}
function HoloArray:new(size)
    local projectors = {}
    
    for x = 1, size.x do
        projectors[x] = {}
        
        for y = 1, size.y do
            projectors[x][y] = {}
        end
    end
    
    local obj = {
        size = size,
        projectors = projectors
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end
 
function HoloArray:getResolution()
    return self.size * holoResolution
end
 
function HoloArray:setProjectors(filename)
    local addresses = {}

    for address in io.lines(filename) do
        table.insert(addresses, address)
    end

    local i = 1
    for y = 1, self.size.y do
        for z = 1, self.size.z do
            for x = 1, self.size.x do
                local address = component.get(addresses[i])
                local proxy = component.proxy(address)
                
                self.projectors[x][y][z] = proxy
                i = i + 1
            end
        end
    end
end
 
function HoloArray:toProjectorSpace(pos)
    return Vec3:new(
        math.floor((pos.x - 1) / holoResolution.x) + 1,
        math.floor((pos.y - 1) / holoResolution.y) + 1,
        math.floor((pos.z - 1) / holoResolution.z) + 1
    )
end
 
function HoloArray:toWorldSpace(pos)
    return Vec3:new(
        (pos.x - 1) * holoResolution.x + 1,
        (pos.y - 1) * holoResolution.y + 1,
        (pos.z - 1) * holoResolution.z + 1
    )
end
 
-- Get the location of the point within it's respective projector
function HoloArray:toLocalSpace(pos)
    local projectorPos = self:toProjectorSpace(pos)
    return pos - self:toWorldSpace(projectorPos) + Vec3:new(1, 1, 1)
end
 
function HoloArray:set(x, y, z, value)
    local resolution = self:getResolution()
    if x < 1 or x > resolution.x or
            y < 1 or y > resolution.y or
            z < 1 or z > resolution.z then
        return nil
    end
    
    local pos = Vec3:new(x, y, z)
    local projectorPos = self:toProjectorSpace(pos)
    local localPos = self:toLocalSpace(pos)
    
    local projector = self.projectors[projectorPos.x][projectorPos.y][projectorPos.z]
    
    projector.set(localPos.x, localPos.y, localPos.z, value)
end

function HoloArray:showMap(map, colorFunc)
    local pos = map.minBlock
    local size = map:getSize()
    local resolution = self:getResolution()

    local offset = ((resolution - size) / Vec3:new(2, 2, 2)):map(math.floor) + Vec3:new(1, 1, 1) - pos

    for x = pos.x, pos.x + size.x - 1 do
        for y = pos.y, pos.y + size.y - 1 do
            for z = pos.z, pos.z + size.z - 1 do
                local block = map:getBlock(Vec3:new(x, y, z))
                local holoPos = Vec3:new(x, y, z) + offset

                local colorIndex = colorFunc(block)
                self:set(holoPos.x, holoPos.y, holoPos.z, colorIndex)
            end
        end
    end
end
 
-- Invoke a function on all projectors
function HoloArray:invoke(funcName, ...)
    
    print("First arg", ...)
    
    for x = 1, self.size.x do
        for y = 1, self.size.y do
            for z = 1, self.size.z do
                print(funcName, ...)
                self.projectors[x][y][z][funcName](...)
            end
        end
    end
end
 
function HoloArray:setPaletteColor(number, value)
    print("Setting palette", number, value)
    self:invoke("setPaletteColor", number, value)
end
 
function HoloArray:clear()
    self:invoke("clear")
end
 
return HoloArray
