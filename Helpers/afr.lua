fuelFlowAFRCounter = 0.5
function updateEngineFuelFlow(engineAFR, setAFR, engOn, throttle)
    if engOn then
        if engineAFR > setAFR then
            -- down
            fuelFlowAFRCounter = fuelFlowAFRCounter - 0.00005
        else
            -- up
            fuelFlowAFRCounter = fuelFlowAFRCounter + 0.00005
        end
        if fuelFlowAFRCounter < 0.2 then
            fuelFlowAFRCounter = 0.2
        end
        if fuelFlowAFRCounter > 0.8 then
            fuelFlowAFRCounter = 0.8
        end
    else
        fuelFlowAFRCounter = 0
    end
    return throttle * fuelFlowAFRCounter
end
