--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


--[====[ HOTKEYS ]====]
-- Press F6 to simulate this file
-- Press F7 to build the project, copy the output from /_build/out/ into the game to use
-- Remember to set your Author name etc. in the settings: CTRL+COMMA


--[====[ EDITABLE SIMULATOR CONFIG - *automatically removed from the F7 build output ]====]
---@section __LB_SIMULATOR_ONLY__
do
    ---@type Simulator -- Set properties and screen sizes here - will run once when the script is loaded
    simulator = simulator
    simulator:setScreen(1, "3x3")
    simulator:setProperty("IdleRPS", 4)

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)

        -- Incoming data from start/key
        simulator:setInputBool(1, simulator:getIsToggled(1))

        -- Incoming ENG RPS, should be a whole number only
        --simulator:setInputNumber(2, simulator:getSlider(1) * 20)
        simulator:setInputNumber(2, simulator:getSlider(1) * 10)

        -- Incoming Idle RPS (Proporty value 5 to 10) hardset to 6 for testing
        simulator:setInputNumber(3, 6)

        -- Incoming Throttle
        simulator:setInputNumber(4, simulator:getSlider(3))

        -- Engine Air Volume
        simulator:setInputNumber(5, 0)
        -- Engine Fuel Volume
        simulator:setInputNumber(6, 0)
        -- Engine Temp
        simulator:setInputNumber(7, 0)

        -- Incoming Proporty AFR (Proporty value 12 to 15)
        simulator:setInputNumber(8, 14.2)
        -- Proporty: Start Colling at Temp
        simulator:setInputNumber(9, 70)
        -- Battery
        simulator:setInputNumber(10, simulator:getSlider(4))

        -- NEW! button/slider options from the UI
        --simulator:setInputBool(31, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)
        --simulator:setInputNumber(31, simulator:getSlider(1))        -- set input 31 to the value of slider 1

        --simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)
        --simulator:setInputNumber(32, simulator:getSlider(2) * 50)   -- set input 32 to the value from slider 2 * 50
    end
end
---@endsection


--[====[ IN-GAME CODE ]====]

-- try require("Folder.Filename") to include code from another file in this, so you can store code in libraries
-- the "LifeBoatAPI" is included by default in /_build/libs/ - you can use require("LifeBoatAPI") to get this, and use all the LifeBoatAPI.<functions>!

require("Helpers.base")
require("Helpers.engine")
require("Helpers.afr")

ticks = 0
fuelFlowOutput = 0
fuelFlowSmoothed = 0
airFlowOutput = 0
airFlowSmoothed = 0
throttleOutput = 0.001
local throttleCap = 1.0
local electricRPSFactor = 10
local mainClutchOutput = 0
local rpsOverMin = false
local electricEngineOutput = 0
local maxRPS = 20 -- Maximum allowable RPS
local maxRPSDeadband = 0.3
local fuelTankWarning = false
local minIdleThrottle = 0.001

-- Throttle buffer settings
local throttleBuffer = {}
local throttleBufferSize = 10

local pidClutch = {
    Kp = 0.001,  -- Proportional gain
    Ki = 0.002,  -- Integral gain
    Kd = 0.003, -- Derivative gain
    integral = 0,
    prevError = 0
}
local dt = 1 / 60 -- Assume 60 Hz system

function onTick()
    ticks = ticks + 1

    -- Outputs
    -- 1: ENG Starter (boolean)
    -- 2: ENG Started (boolean)
    -- 3: Fuel Flow (number)
    -- 4: Air Flow (number)
    -- 5: To Electric Engine (Number)
    -- 6: To Cooling Pumps/Fan (boolean)
    -- 7: Clutch (number)
    -- 8: To Clutch Controller
        -- 1: ENG RPS (number)
        -- 2: ENG Temp (number)
        -- 3: Drive Clutch ready (boolean)
    -- 9: Fuel Warning (boolean)
    -- 10: Tank Level  (number)
    -- 11: Testing block (number)

    -- Inputs
    -- 1: ENG Start/Key
    keyOn = input.getBool(1)
    -- 2: ENG RPS
    engRPS = input.getNumber(2)
    -- 3: Proparty: Idle RPS (5 to 10)
    idleRPS = round(input.getNumber(3))
    -- 4: Throttle
    throttle = input.getNumber(4)
    -- 5: Air Volume
    airVolume = input.getNumber(5)
    -- 6: Fuel Volume
    fuelVolume = input.getNumber(6)
    engAFR = getEngineAFR(airVolume, fuelVolume)
    engAFRDec = engAFR / 100
    -- 7: Engine Temp
    engTemp = input.getNumber(7)
    -- 8: Proporty: AFR (12 to 15)
    propAFR = input.getNumber(8)
    propAFRDec = propAFR / 100
    -- 9: Proporty: Start Colling at Temp
    startTemp = input.getNumber(9)
    -- 10: Battery
    battery = input.getNumber(10)
    -- 11: Fuel Level
        -- Small tank: 3.63L
        -- Medium tank: 133.42L
        -- Large tank: 696.09L
    tankLevel = input.getNumber(11)
    -- 12: Tank Size
    tankSize = input.getNumber(12)



    -- Check if the engine is running
    engOn = isEngineRunning(engRPS, keyOn)
    output.setBool(2, engOn)

    -- Logic
    if keyOn then
        engineStarterEngaged = actionStartEngine(engRPS)
        output.setBool(1, engineStarterEngaged)
        
        -- Keep throttle trend
        local throttleTrend = updateTrend(throttle, throttleBuffer, throttleBufferSize)

        -- Air / Fuel Flow
        -- if minIdleThrottle > throttle and throttle > 0 then
        --     throttle = minIdleThrottle
        --     output.setNumber(11, 1)
        -- end
        if throttle >= throttleOutput or throttle > 0 then
            output.setNumber(11, 2)
            -- Electric Assist
            -- Calculate Effective RPS
            local effectiveRPS = engRPS - (electricEngineOutput * electricRPSFactor)
            -- Electric Assist
            if throttleTrend > 0 then
                electricEngineOutput = math.min(1.0, electricEngineOutput + 0.001) -- Gradually increase electric assist
            else
                electricEngineOutput = math.max(0, electricEngineOutput - 0.001) -- Gradually decrease electric assist
            end

            -- Manage Throttle and Effective RPS
            if effectiveRPS > maxRPS then
                output.setNumber(11, 3)
                -- Effective RPS exceeds max, reduce throttle and throttleCap
                throttleCap = math.max(throttleCap - 0.0001, 0.01) -- Gradually reduce throttle cap
                throttleOutput = math.min(throttleOutput - 0.0001, throttleCap) -- Reduce throttle within cap
            elseif math.abs(effectiveRPS - maxRPS) <= maxRPSDeadband then
                output.setNumber(11, 4)
                -- Effective RPS is within deadband near maxRPS
                if throttleTrend < 0 then
                    -- User is throttling down, decrease throttleOutput smoothly
                    if throttle < throttleOutput then
                        -- Reduce throttleOutput faster to match user input
                        throttleOutput = math.max(throttleOutput - 0.0005, throttle, minIdleThrottle)
                    else
                        -- Ensure throttleOutput respects throttleCap but doesn't spike back up
                        throttleOutput = math.min(throttleOutput, throttleCap)
                    end
                    -- Disable electric assist when throttling down
                    electricEngineOutput = 0
                elseif effectiveRPS > maxRPS then
                    -- Gradually reduce throttle to maintain maxRPS
                    throttleOutput = math.max(throttleOutput - 0.00005, minIdleThrottle)
                else
                    output.setNumber(11, 5)
                    -- Maintain throttle to avoid dropping RPS below maxRPS
                    -- Gradual recovery to user throttle while maintaining stability
                    if throttle > throttleOutput then
                        -- Gradually increase throttle toward user input
                        throttleOutput = math.min(throttleOutput + 0.0001, throttle, throttleCap)
                    else
                        -- Maintain adjusted throttle or idle minimum
                        throttleOutput = math.max(throttleOutput, minIdleThrottle)
                    end

                end
            else
                -- When not near maxRPS
                if throttleOutput < throttle then
                    -- Gradually increase throttle if user throttles up
                    throttleCap = math.min(throttleCap + 0.00001, 1.0) -- Gradually restore throttle cap
                    throttleOutput = math.min(throttleOutput + 0.00005, throttleCap) -- Respect the cap
                else
                    -- Gradual adjustment instead of abrupt reset to throttle
                    throttleOutput = math.max(math.min(throttleOutput + 0.0001, throttleCap), minIdleThrottle)
                end
            end
        else
            output.setNumber(11, 6)
            throttleOutput = throttle
            throttleData = stabilizeIdleRPS(engRPS, idleRPS, throttleOutput)
            throttleOutput = throttleData.throttle
            electricEngineOutput = throttleData.electricEngine
            minIdleThrottle = throttleData.minimumIdleThrottle
        end

        fuelFlowOutput = throttleOutput * updateAFRControl(engAFR, propAFR, airVolume)
        airFlowOutput = throttleOutput

        -- Main Clutch
        -- Check to make sure Engine is ready for main clutch to engage.
        rpsOverMin = isEngineRPSAcceptable(idleRPS, engRPS, 1)
        if rpsOverMin and not engineStarterEngaged then
            -- Get clutch engagement value
            mainClutchOutput = actionClutch(mainClutchOutput, dt, pidClutch)
        end

        -- Fuel Level
        fuelPst = (tankLevel / tankSize) * 100
        if fuelPst < 10 then
            fuelTankWarning = true
        else
            fuelTankWarning = false
        end


        output.setNumber(3, fuelFlowOutput)
        output.setNumber(4, airFlowOutput)
        output.setNumber(5, electricEngineOutput)
        output.setNumber(7, mainClutchOutput)

    else
        -- Engine off
        fuelFlowOutput = 0
        airFlowOutput = 0
        mainClutchOutput = 0
        minIdleThrottle = 0.001
        output.setNumber(3, 0)
        output.setNumber(4, 0)
        output.setNumber(5, 0)
        output.setNumber(7, 0)
    end

    -- Cooling
    -- Cooling may be required if the engine is not running and the temperature is above the startTemp
    output.setBool(6, actionStartCooling(engTemp, startTemp, battery))
    
    -- Fuel Level
    fuelPst = (tankLevel / tankSize) * 100
    if fuelPst < 10 then
        fuelTankWarning = true
    else
        fuelTankWarning = false
    end
    output.setBool(9, fuelTankWarning)

    output.setNumber(10, tankLevel)
end

function onDraw()
    
end