-- PID Constants for AFR Control
local Kp_AFR = 0.0001 -- Proportional gain for AFR control
local Ki_AFR = 0.00001 -- Integral gain for AFR control
local Kd_AFR = 0.00025 -- Derivative gain for AFR control
local previousErrorAFR = 0 -- Track the last error for derivative calculation
local integralLimit_AFR = 0.05 -- Limit for the integral term to prevent windup

-- Deadband for AFR Adjustment
local AFR_DEADBAND = 0.15 -- No adjustments made if error is within this range

-- PID Constants for RPS (Idle Speed) Control
local Kp_RPS = 0.1  -- Proportional gain for RPS control
local Ki_RPS = 0.05  -- Integral gain for RPS control
local Kd_RPS = 0.02 -- Derivative gain for RPS control
local integralLimit_RPS = 2 -- Limit for the RPS integral term
local previousErrorRPS = 0 -- Track the last error for derivative calculation
local minThrottle = 0.015 -- Initial minimum throttle (starting point)
local minIdleThrottle = 0.001

-- Persistent Variables
local integralAFR = 0 -- Integral accumulator for AFR control
local integralRPS = 0 -- Integral accumulator for RPS control
local fuelFlowAFRCounter = 0.5 -- Initial fuel flow adjustment factor

local rpsBuffer = {} -- Buffer to store recent RPS values
local rpsBufferSize = 10 -- Number of readings to track

-- Electric Engine Boost Logic
local electricEngine = 0
local electricIncrement = 0.0001 -- Step size for electric engine adjustment
local electricThreshold = 1 -- RPS difference to activate electric engine
local electricDeadband = 0.2 -- RPS range to deactivate electric engine

-- Update Fuel Flow for AFR Control
--- Adjusts fuel flow to maintain the target AFR using a PI controller.
---@param engineAFR number Current measured AFR
---@param targetAFR number Desired AFR
---@param airFlow number Measured air intake volume
---@return number Adjusted fuel flow factor
function updateAFRControl(engineAFR, targetAFR, airFlow)
    local error = targetAFR - engineAFR
    local derivative = error - previousErrorAFR -- Change in error
    previousErrorAFR = error -- Update previous error

    -- Skip adjustment if the error is within the deadband
    if math.abs(error) <= AFR_DEADBAND then
        return fuelFlowAFRCounter
    end

    -- Proportional-Integral-Derivative Control for AFR
    integralAFR = integralAFR + error

    -- Limit integral to prevent windup
    if integralAFR > integralLimit_AFR then
        integralAFR = integralLimit_AFR
    elseif integralAFR < -integralLimit_AFR then
        integralAFR = -integralLimit_AFR
    end

    local adjustment = (Kp_AFR * error) + (Ki_AFR * integralAFR) + (Kd_AFR * derivative)

    -- Adjust fuel flow counter based on air flow
    fuelFlowAFRCounter = fuelFlowAFRCounter + adjustment * airFlow
    fuelFlowAFRCounter = math.max(0.1, math.min(1.0, fuelFlowAFRCounter)) -- Clamp fuel flow factor

    return fuelFlowAFRCounter
end

-- Stabilize Idle RPS
---@param currentRPS number: Current measured RPS
---@param targetRPS number: Desired idle RPS
---@param throttle number: Current throttle value
---@return table: Adjusted throttle value and electric engine boost, and minimumIdleThrottle
function stabilizeIdleRPS(currentRPS, targetRPS, throttle)
    local error = targetRPS - currentRPS
    local derivative = error - previousErrorRPS -- Change in error
    previousErrorRPS = error -- Update previous error

    -- Proportional-Integral-Derivative Control for RPS
    integralRPS = integralRPS + error

    -- Limit integral to prevent windup
    if integralRPS > integralLimit_RPS then
        integralRPS = integralLimit_RPS
    elseif integralRPS < -integralLimit_RPS then
        integralRPS = -integralLimit_RPS
    end

    local adjustment = (Kp_RPS * error) + (Ki_RPS * integralRPS) + (Kd_RPS * derivative)

    -- Min Throttle Logic
    local plateauOffset = 0.6 -- RPS offset where the engine plateaus
    local adaptiveIncrement = 0.0002 -- Base throttle increment
    local adaptiveMultiplier = 2.0 -- Boost multiplier
    local startupThreshold = targetRPS - plateauOffset -- Keep momentum active until past plateau

    if currentRPS < startupThreshold then
        -- Adaptive momentum boost near plateau
        local increment = adaptiveIncrement * adaptiveMultiplier
        minThrottle = math.min(minThrottle + increment, 1.0)
    else
        -- Post-startup adjustments
        local deadband = 0.2 -- Close range around the target RPS for small adjustments
        local fineGrainDeadband = 0.01 -- Smaller deadband for fine adjustments
        local largeAdjustmentRange = 0.6 -- Larger range for aggressive corrections
        local largeIncrement = 0.0002 -- Increment for large adjustments
        local smallIncrement = 0.00002 -- Increment for small adjustments

        -- Determine adjustment level
        if currentRPS <= targetRPS - largeAdjustmentRange then
            -- Large adjustment for low RPS
            minThrottle = math.min(minThrottle + largeIncrement, 1.0)
        elseif currentRPS > targetRPS + largeAdjustmentRange then
            -- Large adjustment for high RPS
            minThrottle = math.max(minThrottle - largeIncrement, 0.01)
        elseif math.abs(currentRPS - targetRPS) <= deadband then
            -- Small adjustments based on trend when within the deadband
            local rpsTrend = updateTrend(currentRPS, rpsBuffer, rpsBufferSize)
            if rpsTrend > 0 then
                -- RPS is increasing; reduce throttle slightly
                minThrottle = math.max(minThrottle - smallIncrement, 0.01)
            elseif rpsTrend < 0 then
                -- RPS is decreasing; increase throttle slightly
                minThrottle = math.min(minThrottle + smallIncrement, 1.0)
            end
            if rpsTrend <= fineGrainDeadband or rpsTrend >= fineGrainDeadband then
                minIdleThrottle = minThrottle
            end
        end
    end

    -- Electric Engine Logic
    if currentRPS < targetRPS - electricThreshold then
        -- Significantly below target RPS: Gradually increase electric engine power
        electricEngine = math.min(1.0, electricEngine + electricIncrement)
    elseif currentRPS >= targetRPS - 0.3 and currentRPS < targetRPS then
        -- Near target RPS but below: Maintain or slightly reduce electric power
        electricEngine = math.max(electricEngine - (electricIncrement / 2), 0)
    elseif math.abs(currentRPS - targetRPS) <= electricDeadband then
        -- Within target RPS range (deadband): Turn off the electric engine
        electricEngine = 0
    elseif currentRPS >= targetRPS + 0.7 then
        -- Well above target RPS: Ensure the electric engine is off
        electricEngine = 0
    end

    -- **Compensation After Electric Engine Turns Off**
    if electricEngine == 0 and currentRPS < targetRPS then
        -- Boost minThrottle if RPS is below target and electric engine is off
        minThrottle = math.min(minThrottle + adaptiveIncrement * 2, 1.0)
    end

    -- Ensure throttle is above minThrottle
    local adjustedThrottle = math.max(minThrottle, throttle + adjustment)

    -- **Dynamic Recovery Logic**
    if electricEngine == 0 and currentRPS < targetRPS - 0.5 then
        -- Aggressively boost throttle to recover after electric engine disengages
        adjustedThrottle = math.min(adjustedThrottle + adaptiveIncrement * 5, 1.0)
    end

    return { 
        throttle = clamp(adjustedThrottle, minThrottle, 1), 
        electricEngine = electricEngine,
        minimumIdleThrottle = minIdleThrottle
    }
end


-- Is AFR Within Range
--- Checks if the current AFR is within a specified tolerance of the target AFR.
---@param engineAFR number Current measured AFR
---@param targetAFR number Desired AFR
---@param tolerance number Allowed tolerance for the AFR
---@return boolean True if AFR is within the range, otherwise false
function isAFRWithinRange(engineAFR, targetAFR, tolerance)
    return math.abs(engineAFR - targetAFR) <= tolerance
end
