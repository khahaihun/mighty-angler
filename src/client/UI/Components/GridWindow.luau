--!strict
local GridWindow = {}
-- Unclamped coordinates distinguish a grid above/below the scroll viewport from row zero.
function GridWindow.Rows(totalRows: number, pitch: number, gridHeight: number, top: number, bottom: number): (number, number)
 if totalRows <= 0 or bottom <= 0 or top >= gridHeight or bottom <= top then return 0, -1 end
 local first = math.max(0, math.floor(math.max(0, top) / pitch) - 1)
 local last = math.min(totalRows - 1, math.floor((math.min(gridHeight, bottom) - 1e-6) / pitch) + 1)
 return first, last
end
return GridWindow
