local Vec3 = require("Vec3")
local serial = require("serialization")

Map = {}
Map.__index = Map

function Map:new(chunkSize, filePath)
  local obj = {
    chunkSize = chunkSize,
    filePath = filePath,
    numBlocks = 0,
    minBlock = Vec3:new(1000000, 1000000, 1000000),
    maxBlock = Vec3:new(-1000000, -1000000, -1000000)
  }

  setmetatable(obj, self)
  return obj
end

function Map:unserialize(str)
  local map = serial.unserialize(str)

  setmetatable(map, self)
  setmetatable(map.chunkSize, Vec3)
  setmetatable(map.minBlock, Vec3)
  setmetatable(map.maxBlock, Vec3)

  return map
end

function Map:toChunkSpace(pos)
  return Vec3:new(
  math.floor(pos.x / self.chunkSize.x),
  math.floor(pos.y / self.chunkSize.y),
  math.floor(pos.z / self.chunkSize.z)
  )
end

function Map:toWorldSpace(chunkPos)
  return Vec3:new(
  chunkPos.x * self.chunkSize.x,
  chunkPos.y * self.chunkSize.y,
  chunkPos.z * self.chunkSize.z
  )
end

function Map:initializeChunk(chunkPos)
  local chunkSize = self.chunkSize
  local pos = self:toWorldSpace(chunkPos)

  local newChunk = {}

  for x = pos.x, pos.x + chunkSize.x - 1 do
    newChunk[x] = {}

    for y = pos.y, pos.y + chunkSize.y - 1 do
      newChunk[x][y] = {}
    end
  end

  return newChunk
end

function Map:scanRawChunk(chunkPos, geolyzer)
  local pos = self:toWorldSpace(chunkPos)
  local size = self.chunkSize

  local success, result = pcall(geolyzer.scan, pos.x, pos.z, pos.y, size.x, size.z, size.y)

  if success then
    return result
  end

  print("Geolyzer error", result)
  return nil
end

function Map:chunkFilePath(chunkPos)
  return self.filePath .. "/" .. chunkPos.x .. "-" .. chunkPos.y .. "-" .. chunkPos.z
end

function Map:saveChunk(chunkPos, chunk)
  local filePath = self:chunkFilePath(chunkPos)
  local file, ioError = io.open(filePath, "w")

  if not file then
    print("Error writing chunk file", ioError)
    return
  end

  local chunkStr = serial.serialize(chunk)
  file:write(chunkStr)
  
  file:close()
end

function Map:scanChunk(chunkPos, geolyzer)
  local chunk = self:initializeChunk(chunkPos)

  local pos = self:toWorldSpace(chunkPos)
  local size = self.chunkSize

  local scanData = self:scanRawChunk(chunkPos, geolyzer)
  if scanData == nil then
    return nil
  end

  local solidBlocks = 0
  local i = 1

  for y = pos.y, pos.y + size.y - 1 do
    for z = pos.z, pos.z + size.z - 1 do
      for x = pos.x, pos.x + size.x - 1 do
        chunk[x][y][z] = scanData[i]

        if scanData[i] ~= 0 and scanData[i] ~= nil then
          solidBlocks = solidBlocks + 1

          local blockPos = Vec3:new(x, y, z)

          self.minBlock.x = math.min(blockPos.x, self.minBlock.x)
          self.minBlock.y = math.min(blockPos.y, self.minBlock.y)
          self.minBlock.z = math.min(blockPos.z, self.minBlock.z)

          self.maxBlock.x = math.max(blockPos.x, self.maxBlock.x)
          self.maxBlock.y = math.max(blockPos.y, self.maxBlock.y)
          self.maxBlock.z = math.max(blockPos.z, self.maxBlock.z)
        end

        i = i + 1
        self.numBlocks = self.numBlocks + 1
      end
    end
  end

  self:saveChunk(chunkPos, chunk)
  return solidBlocks
end

function Map:scanArea(pos, size, geolyzer)
  local minChunk = self:toChunkSpace(pos)
  local maxPos = pos + size + Vec3:new(-1, -1, -1)
  local maxChunk = self:toChunkSpace(maxPos)

  for x = minChunk.x, maxChunk.x do
    for y = minChunk.y, maxChunk.y do
      for z = minChunk.z, maxChunk.z do
        local chunkPos = Vec3:new(x, y, z)
        self:scanChunk(chunkPos, geolyzer)
      end
    end
  end
end

function Map:adjacentChunks(chunkPos)
  local neighbours = {}
  table.insert(neighbours, chunkPos + Vec3:new(1, 0, 0))
  table.insert(neighbours, chunkPos + Vec3:new(0, 1, 0))
  table.insert(neighbours, chunkPos + Vec3:new(0, 0, 1))
  table.insert(neighbours, chunkPos + Vec3:new(-1, 0, 0))
  table.insert(neighbours, chunkPos + Vec3:new(0, -1, 0))
  table.insert(neighbours, chunkPos + Vec3:new(0, 0, -1))

  return neighbours
end

-- Scans all blocks connected to the geolyzer
function Map:scanAll(geolyzer, chunkPos, scannedChunks)
  local chunkPos = chunkPos or Vec3:new(0, 0, 0)
  local scannedChunks = scannedChunks or {}

  if scannedChunks[tostring(chunkPos)] then
    return
  end

  local solidBlocks = self:scanChunk(chunkPos, geolyzer)
  scannedChunks[tostring(chunkPos)] = true

  if solidBlocks ~= nil and solidBlocks > 0 then
    local neighbours = self:adjacentChunks(chunkPos)
    for _, neighbour in pairs(neighbours) do
      self:scanAll(geolyzer, neighbour, scannedChunks)
    end
  end
end

function Map:getChunk(chunkPos)
  local chunkPath = self:chunkFilePath(chunkPos)
  local file, ioError = io.open(chunkPath, "r")

  if not file then
    print("Error reading chunk file", ioError)
    return nil
  end

  local chunkStr = file:read("*all")
  local chunk = serial.unserialize(chunkStr)

  return chunk
end

function Map:getBlock(pos)
  local chunkPos = self:toChunkSpace(pos)
  local chunk = self:getChunk(chunkPos)

  if not chunk then
    return nil
  end

  return chunk[pos.x][pos.y][pos.z]
end

function Map:getSize()
  return self.maxBlock - self.minBlock + Vec3:new(1, 1, 1)
end

return Map
