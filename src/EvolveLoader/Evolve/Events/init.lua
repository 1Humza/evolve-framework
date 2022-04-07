local Util = {}

local Signal = require(script.Signal)

function Util.new(ClassName)
	if ClassName == "Signal" then
		return Signal.new()
	end
	
	local newEvent = Instance.new(ClassName)
	newEvent.Name = "⠀"
	newEvent.Parent = script

	return newEvent
end

return Util
