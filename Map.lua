local Vec3 = require("Vec3")
local component = require("component")
local geo = component.geolyzer

Map = {}
function Map:new(chunkSize, filePath)
  local obj = {
    chunkSize = chunkSize,
    filePath = filePath,
    chunks = {},
    numBlocks = 0,
    minBlock = Vec3:new(1000000, 1000000, 1000000),
    maxBlock = Vec3:new(-1000000, -1000000, -1000000)
  }
  setmetatable(obj, self)
  self.__index = self
  return obj
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
  if self.chunks[tostring(chunkPos)] then
    return
  end

  local chunkSize = self.chunkSize
  local pos = self:toWorldSpace(chunkPos)

  local newChunk = {}

  for x = pos.x, pos.x + chunkSize.x - 1 do
    newChunk[x] = {}

    for y = pos.y, pos.y + chunkSize.y - 1 do
      newChunk[x][y] = {}
    end
  end

  self.chunks[tostring(chunkPos)] = newChunk
end

function Map:scanRawChunk(chunkPos)
  local pos = self:toWorldSpace(chunkPos)
  local size = self.chunkSize

  local success, result = pcall(geo.scan, pos.x, pos.z, pos.y, size.x, size.z, size.y)

  if success then
    return result
  end

  print("Geolyzer error", result)
  return nil
end

function Map:scanChunk(chunkPos)
  self:initializeChunk(chunkPos)

  local pos = self:toWorldSpace(chunkPos)
  local size = self.chunkSize
  local chunkStr = tostring(chunkPos)
  local chunk = self.chunks[chunkStr]

  local scanData = self:scanRawChunk(chunkPos)
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

  return solidBlocks
end

function Map:scanArea(pos, size)
  local minChunk = self:toChunkSpace(pos)
  local maxPos = pos + size + Vec3:new(-1, -1, -1)
  local maxChunk = self:toChunkSpace(maxPos)

  for x = minChunk.x, maxChunk.x do
    for y = minChunk.y, maxChunk.y do
      for z = minChunk.z, maxChunk.z do
        local chunkPos = Vec3:new(x, y, z)
        self:scanChunk(chunkPos)
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
function Map:scanAll(chunkPos, scannedChunks)
  local chunkPos = chunkPos or Vec3:new(0, 0, 0)
  local scannedChunks = scannedChunks or {}

  if scannedChunks[tostring(chunkPos)] then
    return
  end

  local solidBlocks = self:scanChunk(chunkPos)
  scannedChunks[tostring(chunkPos)] = true

  if solidBlocks ~= nil and solidBlocks > 0 then
    local neighbours = self:adjacentChunks(chunkPos)
    for _, neighbour in pairs(neighbours) do
      self:scanAll(neighbour, scannedChunks)
    end
  end
end

function Map:getBlock(pos)
  local chunkPos = self:toChunkSpace(pos)
  local chunkStr = toString(chunkPos)
  local chunk = self.chunks[chunkStr]

  if not chunk then
    return nil
  end

  return chunk[pos.x][pos.y][pos.z]
end

function Map:getSize()
  return self.maxBlock - self.minBlock + Vec3:new(1, 1, 1)
end

return Map
