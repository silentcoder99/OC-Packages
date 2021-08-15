local rb = require("robot")
local event = require("event")
 
while true do
    local _, _, char, _, _ = event.pull("key_down")
    local str = string.char(char)
 
    if str == 'q' then
        break
    end
    if str == 'w' then
        rb.forward()
    end
    if str == 's' then
        rb.back()
    end
    if str == 'a' then
        rb.turnLeft()
    end
    if str == 'd' then
        rb.turnRight()
    end
    if str == 'r' then
        rb.up()
    end
    if str == 'f' then
        rb.down()
    end
end
