local GetType = function(Entity)
	if typeof(Entity) == "table" then
		if getmetatable(Entity) and Entity._ReadOnly and Entity._ReadOnly._ClassName then
			return "CustomObject"
		elseif Entity._setValue and getmetatable(Entity).Observe then
			return "Streamable"
		elseif Entity._Obj and Entity._ClassName then
			return "SerializedCustomObject"
		elseif Entity.UUID then
			return "SerializedInstance"
		elseif getmetatable(Entity) and getmetatable(Entity)._path and getmetatable(Entity)._root then
			return "NestedPropertyTable"
		elseif Entity._path and Entity._root then
			return "SerializedNestedPropertyTable"
		elseif typeof(Entity[1]) == "table" and Entity[1].UUID and Entity[1]._ClassName then
			return "SerializedCustomObjectTable"
		elseif Entity._path==true then
			return "NestedPropertyPath"
		elseif require(script)(Entity[1]) == "SerializedCustomObject" then
			return "SerializedCustomObjectList"
		elseif typeof(Entity.Disconnect) == "function" then
			return "RBXScriptConnection"
		elseif typeof(Entity.Fire) == "function" and typeof(Entity.Connect) == "function" then
			return "Signal"
		end
	end
	return typeof(Entity)
end

return GetType
