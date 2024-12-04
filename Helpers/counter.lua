-- UpDownCounter Module Inline
function newUpDownCounter(value, minValue, maxValue, step)
    return {
        value = value or 0,
        minValue = minValue or 0,
        maxValue = maxValue or 1,
        step = step or 1,
        increment = function(self)
            self.value = math.min(self.value + self.step, self.maxValue)
        end,
        decrement = function(self)
            self.value = math.max(self.value - self.step, self.minValue)
        end,
        setValue = function(self, value)
            self.value = math.max(self.minValue, math.min(value, self.maxValue))
        end,
        setBounds = function(self, minValue, maxValue)
            self.minValue = minValue or self.minValue
            self.maxValue = maxValue or self.maxValue
            self.value = math.max(self.minValue, math.min(self.value, self.maxValue))
        end,
        microAdjustmentDown = function(self, adjustment)
            self.value = math.abs(adjustment - self.value)
        end,
        microAdjustmentUp = function(self, adjustment)
            self.value = math.abs(adjustment + self.value)
        end,
        getValue = function(self)
            return self.value
        end
    }
end