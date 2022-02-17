local LoadUtil = {}

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Evolve"))

local Core = require(script.Parent.Core)
local UUIDUtil = require(script.Parent.UUID)

local typeof = require("typeof")
local Events = require("Events")

local Awaits = {}
function LoadUtil.Await(CustomObject,Index)
	local PropertyAdded = Awaits[CustomObject:GetUUID()..Index] or Events.new("Signal")
	local ObjHasProperty,ObjPropertyValue = Core.CheckIfHasProperty(CustomObject:GetObject(),Index)
	--print('[Evolve] awaiting', Index, ObjHasProperty,ObjPropertyValue, CustomObject[Index],CustomObject,typeof(CustomObject[Index]))
	--print(debug.traceback())
	
	local Value = CustomObject[Index]

	if typeof(Value) == "SerializedCustomObject" then
		
		local stored_tbl = Core.unloaded_cache[Value._Obj.UUID]
		
		--print(Index,'Waiting',getmetatable(Value),Value._Obj,Core.unloaded_cache)
		rawset(stored_tbl,"__Loaded",coroutine.wrap(function()
			--print('[Evolve] Loaded FUnc Fired')
			PropertyAdded:Fire()
		end))
	--elseif typeof(rawget(CustomObject,"_Properties")[Index]) == "SerializedInstance" then
	--[[elseif typeof(Value) == "NestedPropertyTable" then
		local metaTable = getmetatable(Value)
		--print(#metaTable._unloadedTable,#Value)
		if #metaTable._unloadedTable > #Value then
			metaTable.__newIndexPassThru = metaTable.__newIndexPassThru or function(self,i,v)
				local checkifTableFullyLoaded =  #metaTable._unloadedTable == #Value and PropertyAdded:Fire()
			end
		else
			return Value
		end--]]
	elseif Value then
		return Value
	elseif ObjHasProperty and ObjPropertyValue then
		return ObjPropertyValue
	elseif ObjHasProperty then
		local PropertyChangeConnection
		PropertyChangeConnection = CustomObject:GetObject():GetPropertyChangedSignal(Index):Connect(function()
			PropertyAdded:Fire()
			PropertyChangeConnection:Disconnect()
		end)
	else
		rawset(CustomObject,"_await_"..Index,coroutine.wrap(function(i,v)
			--print(i,v)
			PropertyAdded:Fire()
		end))
	end
	
	Awaits[CustomObject:GetUUID()..Index] = PropertyAdded
	PropertyAdded:Wait()
	Awaits[CustomObject:GetUUID()..Index] = nil
	
	--print('[Evolve] wait complete',Index)
	return CustomObject[Index]
end

--[[LoadUtil.TrackedInstances = setmetatable({},{__newindex=function(s,i,v)
	if typeof(v)=="table" then
		v[3]=TrackDestroy(game:GetService("CollectionService"):GetTagged("_UUID_"..i)[1])
	end
	rawset(s,i,v)
end})]]
LoadUtil.DescendantAddedToReplicatedDirectory = Events.new("Signal")

local RunService = game:GetService("RunService")

if RunService:IsServer() then
	
	game.DescendantAdded:Connect(function(Descendant)

		local Success,UUID = pcall(function() return Descendant:GetAttribute("UUID") end)
		if not (Success and UUID) then return end
		
		UUIDUtil.Generate(Descendant) --if is a clone of instance with UUID this will give it new one
		local Replicate = Core.IsReplicable(Descendant) and LoadUtil.DescendantAddedToReplicatedDirectory:Fire(Descendant)
		
	end)
	
	game.DescendantRemoving:Connect(function(Descendant)
		
		local Success,UUID = pcall(function() return Descendant:GetAttribute("UUID") end)
		if not (Success and UUID) then return end
		
		local Object = Core.loaded_cache[UUID]
		if not Object then return end
		
		RunService.Heartbeat:Wait()--Make sure destroy conneciton will register

		local Destroy = (not Object._ReadOnly._DestroyedConn.Connected) and Object:Destroy()
		
	end)

elseif RunService:IsClient() then
	

end


return LoadUtil