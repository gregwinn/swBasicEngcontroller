-- Update Fuel Flow for AFR Control
--- Adjusts fuel flow to maintain the target AFR using a PI controller.
---@param targetAFR number Desired AFR
---@param airFlow number Measured air intake volume
---@return number Adjusted fuel flow factor
function updateAFRControl(targetAFR, airFlow)
    local ratio = targetAFR / 7.05
    local targetFuelFlow = airFlow / ratio
    
    return targetFuelFlow
end