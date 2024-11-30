-- Start the engine
---@param rps number
---@param start boolean
function startEngine(rps, start)
    if (rps < 3 and start) then
        return true
    end
    return false
end

-- Check if the engine is running over the idle RPS
---@param rps number
---@param start boolean
function isEngineRunning(rps, start, idleRPS)
    idleRPS = idleRPS - 1
    if (rps >= idleRPS and start) then
        return true
    end
    return false
end

-- Air Fuel Ratio
---@param airVolume number
---@param fuelVolume number
---@return number
function engineAFR(airVolume, fuelVolume)
    -- Air Fuel Ratio
    afr = airVolume / (fuelVolume + 0.00001)
    if afr > 0 then
        return afr
    else
        return 0
    end
end

-- Engine Throttle to Idle
---@param throttle number
---@param afr number - as decimal
---@return number
function engineThrottleToIdle(throttle, afr)
    -- Throttle idle
    if throttle < afr then
        throttle = afr
    end
    return throttle
end

-- Check to see if Engine is idle
---@param rps number
---@param idleRPS number
---@return boolean
function isEngineIdle(rps, idleRPS)
    if rps <= idleRPS then
        return true
    end
    return false
end

-- Min-Max function
---@param value number
---@param min_value number
---@param max_value number
---@return number
function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    elseif value > max_value then
        return max_value
    else
        return value
    end
end