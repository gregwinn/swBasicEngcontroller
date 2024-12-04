require("Helpers.counter")
require("Helpers.numbercollector")
require("Helpers.base")
require("Helpers.engine")
require("Helpers.afr")

local ticks = 0
while ticks < 10 do
    ticks = ticks + 0.1
    local rpsData = stabilizeIdleRPS(ticks, 8, 0)
    
    print("RPS " .. ticks)
    print(rpsData.throttle)
end