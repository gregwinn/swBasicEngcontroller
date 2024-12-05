require("Helpers.counter")
require("Helpers.numbercollector")
require("Helpers.base")
require("Helpers.engine")
require("Helpers.afr")
require("Helpers.throttle")

local ticks = 0
local throttle = 0.22
local minIdleThrottle = 0.223
local maxRPS = 20
local engRPS = 15
local maxThrottleValue = 1
local targetAFR = 13.9
local airVolume = 0.4882
local fuelVolume = 0.0363

while ticks < 15 do
    ticks = ticks + 1

    --local throttleData = throttleController(minIdleThrottle, engRPS, maxRPS, throttle, maxThrottleValue)
    --maxThrottleValue = throttleData.maxThrottleValue

    local fuleOutpout = updateAFRControl(airVolume / fuelVolume, targetAFR, airVolume, fuelVolume)
    print(fuleOutpout)
end