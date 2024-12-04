-- PID Constants for AFR Control
local Kp_AFR = 0.0001 -- Proportional gain for AFR control
local Ki_AFR = 0.00001 -- Integral gain for AFR control
local Kd_AFR = 0.00025 -- Derivative gain for AFR control
local previousErrorAFR = 0 -- Track the last error for derivative calculation
local integralLimit_AFR = 0.05 -- Limit for the integral term to prevent windup

-- Deadband for AFR Adjustment
local AFR_DEADBAND = 0.15 -- No adjustments made if error is within this range

-- RPS Controls
local adjustedThrottle = 0
local adjustedThrottleCounter = newUpDownCounter(0.14,  0.0000001, 1, 0.0005)
local RPS_microAdjustment1 = 0.00005
local RPS_microAdjustment2 = 0.00001
local RPS_microAdjustment3 = 0.000005
local RPS_deadband1 = 1
local RPS_deadband2 = 0.4
local RPS_deadband3 = 0.15
local RPS_Values = newNumberCollector(20)
local Throttle_Values = newNumberCollector(10)

-- Persistent Variables
local integralAFR = 0 -- Integral accumulator for AFR control
local fuelFlowAFRCounter = 0.5 -- Initial fuel flow adjustment factor

-- Electric Engine Boost Logic
local electricEngine = 0


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
    local deadbandLevels = {
        {range = RPS_deadband3, adjustment = RPS_microAdjustment3},
        {range = RPS_deadband2, adjustment = RPS_microAdjustment2},
        {range = RPS_deadband1, adjustment = RPS_microAdjustment1}
    }

    -- Check which deadband the current RPS falls into
    for _, level in ipairs(deadbandLevels) do
        if math.abs(currentRPS - targetRPS) <= level.range then
            if currentRPS < targetRPS then
                adjustedThrottleCounter.microAdjustmentUp(adjustedThrottleCounter, level.adjustment)
            elseif currentRPS > targetRPS then
                adjustedThrottleCounter.microAdjustmentDown(adjustedThrottleCounter, level.adjustment)
            end
            
            -- Record RPS and Throttle Values for trends
            RPS_Values.addNumber(RPS_Values, currentRPS)
            Throttle_Values.addNumber(Throttle_Values, adjustedThrottleCounter.getValue(adjustedThrottleCounter))
            
            -- Check for stability after collecting enough values
            if RPS_Values.getLength(RPS_Values) >= 20 then
                adjustedThrottleCounter.setValue(adjustedThrottleCounter, Throttle_Values.getAverage(Throttle_Values))
            end
            
            adjustedThrottle = adjustedThrottleCounter.getValue(adjustedThrottleCounter)
            return {
                throttle = adjustedThrottle,
                electricEngine = electricEngine,
                minIdleThrottle = Throttle_Values.getAverage(Throttle_Values)
            }
        end
    end

    -- Handle cases outside the deadbands
    if currentRPS > targetRPS then
        adjustedThrottleCounter.decrement(adjustedThrottleCounter)
    elseif currentRPS < targetRPS then
        adjustedThrottleCounter.increment(adjustedThrottleCounter)
    end

    adjustedThrottle = adjustedThrottleCounter.getValue(adjustedThrottleCounter)

    return {
        throttle = adjustedThrottle,
        electricEngine = electricEngine,
        minIdleThrottle = Throttle_Values.getAverage(Throttle_Values)
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
