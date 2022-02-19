local Replicator = {}

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Evolve"))

local CustomObjectsModule = game.ReplicatedStorage.Evolve.CustomObjects

local CustomObjects = require(CustomObjectsModule)
local Core = require(CustomObjectsModule.Utils.Core)
local SerializeUtil = require(CustomObjectsModule.Utils.Serialize)

local Promise = require("Promise")
local typeof = require("typeof")
local Events = require("Events")

function manageThread(s,i,v)
	
	local mtbl = getmetatable(s)
	local thread = mtbl._thread
	
	rawset(s,i,v)
	--warn("[Evolve] Added to replication queue",i,v)

	local threadDead = (not thread) or coroutine.status(thread)=="dead"
	if not threadDead then return end

	mtbl._thread = coroutine.create(function()
		--warn("[Evolve] Starting replication queue processing",s)
		ProcessData(s)
	end)
	task.spawn(mtbl._thread)
	
end

local Queue = setmetatable({},{
	_thread = nil,
	__newindex = function(s,i,v)
		manageThread(s,i,v)
	end,
})
Replicator.Queue = Queue

local Requests = {}
Replicator.Requests = Requests


function ProcessData(Queue)	
	
	local processed = {}
	
	local queueIndex, args = next(Queue)
	
	while args ~= nil do
		--table.remove(Queue,queueIndex)
		
		local Obj,ClassName,i,v = unpack(args)
		
		--warn("[Evolve] Processing replication data:",Obj,typeof(Obj),ClassName,Queue,i,v)

		if typeof(Obj) == "SerializedInstance" then
			local Item = Core.loaded_cache[Obj.UUID] or CustomObjects.Wrap({_Obj = Obj,_ClassName = ClassName})
			if typeof(v) == "SerializedCustomObject" then
				--print('[Evolve] Recieved CustomObject data. Wrapping..', v)
				Item[i] = CustomObjects.Wrap(v)
			elseif typeof(v) == "SerializedNestedPropertyTable" then
				SerializeUtil.SetNestedTableValue(Item,v._path,Core.NewNestedPropertyTable(Item,v,v._path))			
			elseif typeof(i) == "NestedPropertyPath" then
				--print('[Evolve] Updating nested table value:',Item,i,v)
				SerializeUtil.SetNestedTableValue(Item,i,v)
			elseif typeof(v) == "table" or typeof(v) == "SerializedInstance" then
				--print('[Evolve] Recieved table. Attemping to decode:',Item,i,v)
				Item[i] = SerializeUtil.Decode(v)
			else
				--print('[Evolve] Replicating property change:',Item,i,v)
				Item[i] = v
			end

			--print(Item,i,v)
		elseif typeof(Obj) == "SerializedCustomObject" then
			--print('[Evolve] Recieved SerializedCustomObject. Wrapping..',Obj)
			CustomObjects.Wrap(Obj)
		elseif Obj and typeof(ClassName) == "number" and i == "_DESTROY" then
			--print('[Evolve] Recieved _DESTROY signal from server:',Obj,Core.loaded_cache)
		end
		
		Queue[queueIndex] = nil
		queueIndex, args = next(Queue)
	end
	
end


CustomObjectsModule.SendObjects.OnClientEvent:Connect(function(UUID,Obj,ClassName,i,v)
	
	if not Core.loaded_cache[UUID] then return end

	Queue[UUID] = {Obj,ClassName,i,v}

end)

function RequestData(UUID)
	Requests[UUID] = Promise.new(function(resolve)
		resolve(CustomObjectsModule.RequestReplication:InvokeServer(UUID))
	end)
	return Requests[UUID]
end

function Replicator.Load(UUID)
	
	if Requests[UUID] then return end 
	
	--print('[Evolve] Requesting server info for UUID:',UUID)
	
	Requests[UUID] = RequestData(UUID)
	local value = Requests[UUID]:expect()
	
	if Requests[UUID] ~= "InstantLoad" then --would be if InstantLoad runs before
		Queue[UUID] = {value}
		Requests[UUID] = nil
	end
	
end


function Replicator.InstantLoad(UUID)
	
	--print('[Evolve] Instant load requested:',UUID)
	local serializedCustomObject
	
	if Queue[UUID] then
		serializedCustomObject = unpack(Queue[UUID])
		Queue[UUID]=nil
		--print('[Evolve] Instant load extracted data from Queue:',UUID,Queue)
	else
		local request = Requests[UUID]
		if not request then
			request = RequestData(UUID)
		end
		Requests[UUID] = "InstantLoad"
		serializedCustomObject = request:expect()
	end
		
	local LoadedCO = CustomObjects.Wrap(serializedCustomObject)
	
	Requests[UUID] = nil
	
	return LoadedCO
	
end

return Replicator