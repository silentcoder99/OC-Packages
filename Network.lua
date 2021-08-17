local component = require("component")
local event = require("event")
local modem = component.modem
local fs = require("filesystem")
local shell = require("shell")

local endPacket = "end"
local strPacketSize = 8000

Network = {}

function Network.splitString(str)
  local length = string.len(str)

  if length <= strPacketSize then
    return {str}
  end

  local head = string.sub(str, 1, strPacketSize)
  local tail = string.sub(str, strPacketSize + 1, length)

  local packets = {head}
  for _, packet in pairs(Network.splitString(tail)) do
    table.insert(packets, packet)
  end

  return packets
end

function Network.broadcastString(port, str)
  local strPackets = Network.splitString(str) 

  for _, packet in pairs(strPackets) do
    modem.broadcast(port, packet)
  end

  modem.broadcast(port, endPacket)
end

function Network.pullString(port)
  local str = ""

  modem.open(port)
  
  while true do
    local _, _, _, _, distance, message = event.pull("modem_message")

    if distance == 0 then
      if message == "end" then
        break
      end

      str = str .. message
    end
  end

  return str
end


function Network.listen(port)
  modem.open(port)
  print(string.format("Listening for packets on port %d...", port))

  while true do
    local _, _, _, _, distance, message = event.pull("modem_message")


    if string.len(message) > 20 then
      message = string.sub(message, 1, 20)
    end

    if distance == 0 then
      print("Package", message)
    end

    if message == "end" then
      break
    end
  end

  modem.close(port)
end

function Network.sendFile(port, path)
  local file = io.open(path, "r")
  local fileStr = file:read("*all")

  file:close()

  Network.broadcastString(port, fileStr)
end

function Network.receiveFile(port, path)
  local fileStr = Network.pullString(port)

  local file = io.open(path, "w")
  file:write(fileStr)
  
  file:close()
end

function Network.sendDirectory(port, path)
  local endPacket = "endDir"

  local scriptPath = shell.resolve(".")
  local absolutePath = fs.concat(scriptPath, path)

  for filename in fs.list(absolutePath) do
    local filePath = fs.concat(path, filename)

    Network.broadcastString(port, filename)
    Network.sendFile(port, filePath)
  end

  Network.broadcastString(port, endPacket)
end

function Network.receiveDirectory(port, path)
  local endPacket = "endDir"
  
  local scriptPath = shell.resolve(".")
  local absolutePath = fs.concat(scriptPath, path)

  if not fs.isDirectory(absolutePath) then
    fs.makeDirectory(absolutePath)
  end

  while true do
    local filename = Network.pullString(port)

    if filename == endPacket then
      break
    end

    local filePath = fs.concat(path, filename)
    Network.receiveFile(port, filePath)
  end
end

return Network
