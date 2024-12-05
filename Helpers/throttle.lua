local Throttle_maxValue = newNumberCollector(10)
function throttleController(minIdleThrottle, engRPS, maxRPS, throttle, maxThrottleValue)
    local deadbandLevels = {
        {range = 0.5, adjustment = 0.000001},
        {range = 1, adjustment = 0.00001},
        {range = 5, adjustment = 0.0001}
    }
    if throttle < minIdleThrottle then
        -- If throttle is below the minimum idle throttle, set it to the minimum idle throttle
        throttleOutput = minIdleThrottle
    else
        for _, level in ipairs(deadbandLevels) do
            if math.abs(engRPS - maxRPS) <= level.range then
                -- collect throttle values for max throttle value
                if level.range < 5 then
                    Throttle_maxValue.addNumber(Throttle_maxValue, throttleOutput)
                end

                -- set Max throttle value to throttleOutput
                if level.range == 0.5 then
                    maxThrottleValue = Throttle_maxValue.getAverage(Throttle_maxValue)
                    throttleOutput = maxThrottleValue
                end

                if engRPS < maxRPS then
                    throttleOutput = throttleOutput + level.adjustment
                elseif engRPS > maxRPS then
                    throttleOutput = throttleOutput - level.adjustment
                end
            else
                -- Out of deadband range
                if engRPS > maxRPS then
                    throttleOutput = minIdleThrottle
                else
                    throttleOutput = throttle
                end
            end
        end            
    end



    throttleOutput = clamp(throttleOutput, minIdleThrottle, maxThrottleValue)
    return {
        throttleOutput = throttleOutput,
        maxThrottleValue = maxThrottleValue
    }
end