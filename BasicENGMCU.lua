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
        simulator:setInputNumber(2, simulator:getSlider(1) * 20)

        -- Incoming Idle RPS (Proporty value 3 to 6)
        simulator:setInputNumber(3, simulator:getSlider(2) * 20)

        -- Incoming Throttle
        simulator:setInputNumber(4, simulator:getSlider(3))

        -- Incoming Proporty AFR (Proporty value 12 to 15)
        simulator:setInputNumber(8, simulator:getSlider(4) * 20)

        -- Engine Air Volume
        simulator:setInputNumber(5, 0)
        -- Engine Fuel Volume
        simulator:setInputNumber(6, 0)
        -- Engine Temp
        simulator:setInputNumber(7, 0)

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


ticks = 0
afrCounterValue = 0
fuelFlowOutput = 0
adjustedAFR = 14.6
adjustedAFRDec = adjustedAFR / 100
propAFR = 0
propAFRDec = 0.05
AirFlowOutputCounter = createAFRCounter(0.5, 0.0005, 0.02, 0.8)
FuelFlowOutputPid = PIDController(0.001)

underRPS = false

function onTick()
    ticks = ticks + 1

    -- Outputs
    -- 1: ENG Starter
    output.setBool(1, false)
    -- 2: ENG Started
    output.setBool(2, false)
    -- 3: Fuel Flow
    output.setNumber(3, 0)
    -- 4: Air Flow
    output.setNumber(4, 0)
    airFlowOutput = 0
    -- 5: Electric Engine
    output.setNumber(5, 0)
    -- 6: AFR Counter information
    output.setNumber(6, 0)
    -- 7: Engine AFR Calculation
    output.setNumber(7, 0)

    -- Inputs
    -- 1: ENG Start/Key
    keyOn = input.getBool(1)
    -- 2: ENG RPS
    engRPS = round(input.getNumber(2))
    -- 3: Idle RPS
    idleRPS = round(input.getNumber(3))
    -- 4: Throttle
    throttle = input.getNumber(4)
    -- 5: Air Volume
    airVolume = input.getNumber(5)
    -- 6: Fuel Volume
    fuelVolume = input.getNumber(6)
    engAFR = airVolume / (fuelVolume + 0.00001)  -- Avoid division by zero
    engAFRDec = engAFR / 100
    output.setNumber(7, fuelVolume)

    -- 7: Engine Temp
    engTemp = input.getNumber(7)
    -- 8: Proporty AFR (12 to 15)
    propAFR = input.getNumber(8)
    propAFRDec = propAFR / 100

    -- Logic
    -- Turn on starter if the RPS is less than 3
    output.setBool(1, startEngine(engRPS, keyOn))
    -- Check if the engine is running
    engOn = isEngineRunning(engRPS, keyOn, idleRPS)
    output.setBool(2, engOn)

    -- Fuel and Air flow based on throttle on if engine key is on
    if keyOn then

        if throttle <= propAFRDec then
            if engRPS < idleRPS then
                underRPS = true
                -- Adjust propAFRDec
                adjustedAFRDec = adjustedAFRDec + 0.0001
            else
                underRPS = false
                -- Adjust propAFRDec
                adjustedAFRDec = adjustedAFRDec - 0.0001
            end
        else
            adjustedAFRDec = propAFRDec
        end

        -- Configure min Throttle based on propAFR
        throttle = engineThrottleToIdle(throttle, propAFRDec)

        -- Calculate AFR based on temperature and desired stoichiometric coefficient 
        s = 0.2 
        T = engTemp 
        AFR = (14 - 2 * s) * (1 - 0.01 * T) + (15 - 5 * s) * (0.01 * T)


        -- Calculate desired air flow directly based on throttle and propAFR, and clamp it
        airFlowOutput = clamp(throttle, propAFRDec, 1)
        -- Adjust fuel flow to match the desired air flow and maintain AFR
        -- fuelFlowOutput = clamp(airFlowOutput / propAFR * afrCounterValue, propAFRDec / propAFR, 1) 
        initialFuelFlow = throttle * (6.88 + (0.0625 * 0)) / AFR
        
        -- Ensure that the fuelFlowOutput does not go below a safe minimum threshold
        -- if fuelFlowOutput < propAFRDec / propAFR then
        --     fuelFlowOutput = propAFRDec / propAFR
        -- end

        output.setNumber(3, fuelFlowOutput)
        output.setNumber(4, airFlowOutput)
        output.setNumber(6, afrCounterValue)
    end
end




function onDraw()
    -- Draw the screen
    if keyOn then
        screen.drawText(0, 0, "key on")
    else
        screen.drawText(0, 0, "key off")
    end
    
    if engOn then
        screen.drawText(0, 10, "ENG RUN")
    else
        screen.drawText(0, 10, "ENG OFF")
    end
    screen.drawText(0, 20, "AFR:" .. engAFR)
    screen.drawText(0, 30, "RPS:" .. engRPS)
    screen.drawText(0, 40, "Fuel:" .. fuelFlowOutput)
    screen.drawText(0, 50, "Air:" .. airFlowOutput)
    screen.drawText(0, 60, "PAFRd:" .. propAFRDec)
    screen.drawText(0, 70, "Thro:" .. throttle)

    if underRPS then
        screen.drawText(0, 80, "UP/DNW: UP")
    else
        screen.drawText(0, 80, "UP/DNW: DNW")
    end
end


