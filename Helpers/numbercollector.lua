-- NumberCollector Module Inline
function newNumberCollector(maxSize)
    return {
        numbers = {}, -- Table to store numbers
        maxSize = maxSize or 10,
        addNumber = function(self, num)
            table.insert(self.numbers, num)
            if #self.numbers > self.maxSize then
                table.remove(self.numbers, 1) -- Remove the oldest number
            end
        end,
        getAverage = function(self)
            local sum = 0
            for _, value in ipairs(self.numbers) do
                sum = sum + value
            end
            return #self.numbers > 0 and (sum / #self.numbers) or 0
        end,
        getLength = function(self)
            return #self.numbers
        end,
        clear = function(self)
            self.numbers = {}
        end
    }
end