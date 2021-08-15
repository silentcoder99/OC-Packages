local component = require("component")
local event = require("event")
local modem = component.modem

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

return Network
