local m = {}


local tableTypes = {
	["CountedDictionary"] = function()
		
		local proxy = newproxy(true)
		local mtbl = getmetatable(proxy)

		mtbl._Length = 0
		mtbl._Stuff = {}

		mtbl.__newindex = function(self,i,v)
			local ShouldSubtract = self[i] and (v == nil)
			mtbl._Length += ShouldSubtract and -1 or v ~= nil and self[i] == nil and 1 or 0 --Only subtract if removing value dont do nothing if setting nil to nil
			mtbl._Stuff[i]=v
			local LengthFunction = not ShouldSubtract and typeof(mtbl[tostring(mtbl._Length)]) == "function" and mtbl[tostring(mtbl._Length)]()
		end
		mtbl.__index = mtbl._Stuff

		mtbl.__len = function()
			return mtbl._Length
		end
		
		return proxy
		
	end,
}


function m.new(type,...)
	assert(typeof(type)=="string","Table type must be provided as string value.")
	
	return tableTypes[type](...)
end

return m
