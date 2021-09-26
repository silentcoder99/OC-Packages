local Vec3 = require("Vec3")
local serial = require("serialization")
local fs = require("filesystem")
local shell = require("shell")

local metadataFile = "metadata"

Map = {}
Map.__index = Map

function Map:new(chunkSize, filePath)
  local obj = {
    chunkSize = chunkSize,
    filePath = filePath,
    numBlocks = 0,
    minBlock = Vec3:new(1000000, 1000000, 1000000),
    maxBlock = Vec3:new(-1000000, -1000000, -1000000),
    scannedChunks = {},
    unscannedChunks = {},
    cachedChunks = {},
    cacheSize = 40
  }

  setmetatable(obj, self)
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

function Map:scanRawChunk(chunkPos, geolyzer, scanPos)
  local pos = self:toWorldSpace(chunkPos) - scanPos --Make pos relative to marker not the robot
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

function Map:scanChunk(chunkPos, geolyzer, scanPos)
  local chunk = self:initializeChunk(chunkPos)

  local pos = self:toWorldSpace(chunkPos)
  local size = self.chunkSize

  local scanData = self:scanRawChunk(chunkPos, geolyzer, scanPos)
  if scanData == nil then
    self.unscannedChunks[tostring(chunkPos)] = true
    return nil
  else
    self.scannedChunks[tostring(chunkPos)] = true
  end

  local solidBlocks = 0
  local i = 1

  for y = pos.y, pos.y + size.y - 1 do
    for z = pos.z, pos.z + size.z - 1 do
      for x = pos.x, pos.x + size.x - 1 do

        local blockPos = Vec3:new(x, y, z)

        -- Don't include the robot itself in the scan
        if blockPos == scanPos then
          chunk[x][y][z] = 0
        else
          chunk[x][y][z] = scanData[i]
        end

        if scanData[i] ~= 0 and scanData[i] ~= nil then
          solidBlocks = solidBlocks + 1

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
function Map:scanAll(geolyzer, scanPos, chunkPos)
  local chunkPos = chunkPos or self:toChunkSpace(scanPos)

  if self.scannedChunks[tostring(chunkPos)] then
    return
  end

  local solidBlocks = self:scanChunk(chunkPos, geolyzer, scanPos)

  if solidBlocks ~= nil and solidBlocks > 0 then
    local neighbours = self:adjacentChunks(chunkPos)
    for _, neighbour in pairs(neighbours) do
      self:scanAll(geolyzer, scanPos, neighbour)
    end
  end
end

function Map:loadChunk(chunkPos)
  local chunkPath = self:chunkFilePath(chunkPos)
  local file, ioError = io.open(chunkPath, "r")

  if not file then
    return nil
  end

  local chunkStr = file:read("*all")
  local chunk = serial.unserialize(chunkStr)

  file:close()

  --Add chunk to cache
  local cache = self.cachedChunks
  local chunkStr = tostring(chunkPos)

  local cachedChunk = {}
  cachedChunk[chunkStr] = chunk

  table.insert(cache, 1, cachedChunk)
  cache[self.cacheSize + 1] = nil --Remove chunks outside of cache size

  return chunk
end

function Map:getCachedChunk(chunkPos)
  for i, cachedChunk in ipairs(self.cachedChunks) do
    local chunkStr, chunk = next(cachedChunk)
    if tostring(chunkPos) == chunkStr then
      return chunk
    end
  end

  return nil
end

function Map:getChunk(chunkPos)
  if not self.scannedChunks[tostring(chunkPos)] then
    return nil
  end

  local chunk = self:getCachedChunk(chunkPos)

  if not chunk then
    chunk = self:loadChunk(chunkPos)
  end

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

function Map:isEmpty(pos)
  local block = self:getBlock(pos)

  return block == 0
end

function Map:listChunks()
  local scriptPath = shell.resolve(".")
  local absolutePath = fs.concat(scriptPath, self.filePath)

  local chunkFileIter = fs.list(absolutePath)

  return function()
    local chunkFilename = ""

    repeat
      chunkFilename = chunkFileIter()
    until chunkFilename ~= metadataFile

    if not chunkFilename then
      return nil
    end

    local chunkPath = fs.concat(self.filePath, chunkFilename)
    local file = io.open(chunkPath, "r")
    local chunkStr = file:read("*all")

    file:close()

    local chunk = serial.unserialize(chunkStr)
    return chunk
  end
end

function Map:listBlocks()
  local chunkIter = self:listChunks()
  local chunk = chunkIter()

  local x, yList = next(chunk)
  local y, zList = next(yList)
  local z, block = next(zList)

  return function()
    local currentBlock = block
    local currX = x
    local currY = y
    local currZ = z

    z, block = next(zList, z)
    if not z then
      y, zList = next(yList, y)
      if not y then
        x, yList = next(chunk, x)
        if not x then
          chunk = chunkIter()
          if not chunk then
            return nil
          end
          x, yList = next(chunk)
          y, zList = next(yList)
          z, block = next(zList)
        end
        y, zList = next(yList)
        z, block = next(zList)
      end
      z, block = next(zList)
    end

    return currX, currY, currZ, currentBlock
  end
end

function Map:getSize()
  return self.maxBlock - self.minBlock + Vec3:new(1, 1, 1)
end

function Map:saveMetadata()
  local filePath = fs.concat(self.filePath, metadataFile)
  local file, ioError = io.open(filePath, "w")

  if not file then
    print("Error writing metadata", ioError)
    return
  end

  local metadataStr = serial.serialize(self)
  file:write(metadataStr)

  file:close()
end

function Map:loadMetadata()
  local filePath = fs.concat(self.filePath, metadataFile)
  local file, ioError = io.open(filePath, "r")

  if not file then
    print("Error reading metadata", ioError)
    return
  end

  local metadataStr = file:read("*all")
  local metadata = serial.unserialize(metadataStr)

  self.chunkSize = metadata.chunkSize
  self.numBlocks = metadata.numBlocks
  self.minBlock = metadata.minBlock
  self.maxBlock = metadata.maxBlock
  self.scannedChunks = metadata.scannedChunks
  self.unscannedChunks = metadata.unscannedChunks
    
  setmetatable(self.chunkSize, Vec3)
  setmetatable(self.minBlock, Vec3)
  setmetatable(self.maxBlock, Vec3)
end

return Map
