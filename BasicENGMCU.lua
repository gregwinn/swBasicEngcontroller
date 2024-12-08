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
require("Helpers.numbercollector")
require("Helpers.base")
require("Helpers.engine")
require("Helpers.afr")
require("Helpers.throttle")
require("Helpers.battery")

local ticks = 0
local fuelFlowOutput = 0
local airFlowOutput = 0
local throttleOutput = 0.01
local electricEngineOutput = 0
local mainClutchOutput = 0
local maxRPS = 20
local batteryLevel = 0

function onTick()
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
    idleRPS = input.getNumber(3)
    -- 4: Throttle
    throttle = input.getNumber(4)
    -- 5: Air Volume
    airVolume = input.getNumber(5)
    -- 6: Fuel Volume
    fuelVolume = input.getNumber(6)
    engAFR = getEngineAFR(airVolume, fuelVolume)
    propAFR = input.getNumber(8)
    battery = input.getNumber(10)
    batteryLevel = getBatteryLevel(battery)

    tankLevel = input.getNumber(11)
    tankSize = input.getNumber(12)

    ticks = ticks + 1

    -- Determine if the engine is running
    engOn = isEngineRunning(engRPS, keyOn)
    output.setBool(2, engOn)

    if keyOn then
        engineStarterEngaged = actionStartEngine(engRPS)
        output.setBool(1, engineStarterEngaged)
    
    
        if throttle == 0 then
            throttleData = throttleController(engRPS, idleRPS, true)
            throttleOutput = throttleData.throttle
        else
            local throttleToRPS = clamp(throttle * maxRPS, idleRPS, maxRPS) or idleRPS
            throttleData = throttleController(engRPS, throttleToRPS, false)
            throttleOutput = throttleData.throttle
            electricEngineOutput = throttleData.electricEngine
            output.setNumber(11, throttleToRPS)
        end

    
        -- Fuel and Air Flow Adjustment
        fuelFlowOutput = updateAFRControl(propAFR, airFlowOutput)
        airFlowOutput = throttleOutput
    
        -- Main Clutch Logic
        if engRPS >= (idleRPS - 1) and not engineStarterEngaged then
            mainClutchOutput = actionClutch(mainClutchOutput, 0, {
                Kp = 0.1,
                Ki = 0,
                Kd = 0,
            })
        end

        -- Battery Check
        if batteryLevel < 40 then
            electricEngineOutput = 0
        end
    
        -- Output Values
        output.setNumber(3, fuelFlowOutput)
        output.setNumber(4, airFlowOutput)
        output.setNumber(5, electricEngineOutput)
        output.setNumber(7, mainClutchOutput)
        output.setNumber(11, fuelFlowOutput)
    else
        -- Engine Off Logic
        fuelFlowOutput, airFlowOutput, electricEngineOutput = 0, 0, 0
        throttleOutput = 0.01
        output.setNumber(3, 0)
        output.setNumber(4, 0)
        output.setNumber(5, 0)
        output.setNumber(7, 0)
    end
    
    -- Fuel Warning Logic
    fuelPst = (tankLevel / tankSize) * 100
    output.setBool(9, fuelPst < 10)
    output.setNumber(10, tankLevel)
end


function onDraw()
    
end