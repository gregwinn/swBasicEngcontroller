-- PID Controller function
---kp = Proporcional gain
---@param kp number
---@return function
function PIDController(kp)
    return function(setpoint, process_variable)
        local error = setpoint - process_variable
        local output = kp * error
        return output
    end
end

function round(num)
    if num >= 0 then
        return math.floor(num + 0.5)
    else
        return math.ceil(num - 0.5)
    end
end

-- Up-Down Counter function with min, max values and reset
function createAFRCounter(start, step, min, max)
    local count = start or 0
    local increment = step or 1
    local minValue = min or -math.huge  -- Default to negative infinity if min is not provided
    local maxValue = max or math.huge   -- Default to positive infinity if max is not provided

    return {
        up = function()
            count = count + increment
            if count > maxValue then
                count = maxValue
            end
            return count
        end,
        down = function()
            count = count - increment
            if count < minValue then
                count = minValue
            end
            return count
        end,
        reset = function(newStart)
            count = newStart or 0
        end,
        get = function()
            return count
        end
    }
end
