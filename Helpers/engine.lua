-- Start the engine
---@param rps number
function actionStartEngine(rps)
    if (rps < 3) then
        return true
    end
    return false
end

-- Check if the engine is running over the idle RPS
---@param rps number
---@param start boolean
function isEngineRunning(rps, start)
    if (rps >= 3 and start) then
        return true
    end
    return false
end

-- Air Fuel Ratio
---@param airVolume number
---@param fuelVolume number
---@return number
function getEngineAFR(airVolume, fuelVolume)
    -- Air Fuel Ratio
    airVolume = airVolume * 1000
    fuelVolume = fuelVolume * 1000
    afr = airVolume / (fuelVolume + 0.00001)
    return afr
end


-- Cooling for engine based on temp
---comment
---@param engTemp number in Celsius
---@param startTemp number in Celsius
---@return boolean
function actionStartCooling(engTemp, startTemp, battery)
    if (engTemp > startTemp) and battery > 0.4 then
        return true
    end
    return false
end

--- Checks if the engine's RPS is within an acceptable range of the target RPS.
---@param targetRPS number: The desired target RPS.
---@param currentRPS number: The current measured RPS.
---@param tolerance number: The maximum allowable difference below the target (default: 1 RPS).
---@return boolean: True if RPS is acceptable, False otherwise.
function isEngineRPSAcceptable(targetRPS, currentRPS, tolerance)
    tolerance = tolerance or 1 -- Default tolerance is 1 RPS
    return currentRPS >= (targetRPS - tolerance)
end
