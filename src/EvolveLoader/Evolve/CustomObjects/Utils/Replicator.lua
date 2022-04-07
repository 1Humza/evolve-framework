local Replicator = {}

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Evolve"))

local CustomObjectsModule = game.ReplicatedStorage.Evolve.CustomObjects

local CustomObjects = require(CustomObjectsModule)
local Core = require(CustomObjectsModule.Utils.Core)
local SerializeUtil = require(CustomObjectsModule.Utils.Serialize)

local Promise = require("Promise")
local typeof = require("typeof")
local Events = require("Events")


local Queue

local function DoProcess(queueIndex,args)
	processingUUID,processingData = queueIndex,args
	Queue[queueIndex] = nil
	
	local Obj,ClassName,i,v = unpack(args)
	
	--warn("[Evolve] Processing replication data:",queueIndex,Obj,typeof(Obj),ClassName,Queue,i,v)

	if typeof(Obj) == "SerializedInstance" then
		local Item = Core.loaded_cache[Obj.UUID] or CustomObjects.Wrap({_Obj = Obj,_ClassName = ClassName})
		if typeof(v) == "SerializedCustomObject" then
			--print('[Evolve] Recieved CustomObject data. Wrapping..', v)
			Item[i] = CustomObjects.Wrap(v)
		elseif typeof(v) == "SerializedNestedPropertyTable" then
			SerializeUtil.GetEnclosingDir(Item,v._path)[v._path[#v._path]] = Core.NewNestedPropertyTable(Item,v._data,v._path)	
		elseif typeof(i) == "NestedPropertyPath" then
			local path = i._nestedtblpath
			for i,v in ipairs(path) do
				path[i] = tonumber(v) or v 
			end
			--print('[Evolve] Updating nested table value:',Item,path,v)
			SerializeUtil.GetEnclosingDir(Item,path)[path[#path]] = (type(v) == "table" and unpack(SerializeUtil.Decode({v}))) or v --using type to escape typeof
		elseif typeof(v) == "table" or typeof(v) == "SerializedInstance" then
			--print('[Evolve] Recieved table. Attemping to decode:',Item,i,v)
			Item[i] = SerializeUtil.Decode(v)
		else
			--print('[Evolve] Replicating property change:',Item,i,v)
			Item[i] = v
		end

	elseif typeof(Obj) == "SerializedCustomObject" then
		--print('[Evolve] Recieved SerializedCustomObject. Wrapping..',Obj)
		CustomObjects.Wrap(Obj)
	elseif Obj and typeof(ClassName) == "number" and i == "_DESTROY" then
		--print('[Evolve] Recieved _DESTROY signal from server:',Obj,Core.loaded_cache)
	end
	
	processingUUID,processingData = nil,nil
end

local function ProcessData(Queue)	
	
	local processed = {}
	
	local queueIndex, args = next(Queue)
	
	while args ~= nil do
		DoProcess(queueIndex,args)
		
		processingUUID,processingData = nil,nil
		queueIndex, args = next(Queue)
	end
	
end

local function manageThread(s,i,v)
	
	local mtbl = getmetatable(s)
	local thread = mtbl._thread
	
	rawset(s,i,v)
	--warn("[Evolve] Added to replication queue",i,v,Core.loaded_cache,debug.traceback())
	
	--local threadDead = (not thread) or coroutine.status(thread)=="dead"
	--if not threadDead then return end

	--mtbl._thread = coroutine.create(function()
		--warn("[Evolve] Starting replication queue processing",s)
		--ProcessData(s)
		task.spawn(DoProcess,i,v)
	--end)
	--task.spawn(mtbl._thread)
	
end

Queue = setmetatable({},{
	_thread = nil,
	__newindex = manageThread,
})
Replicator.Queue = Queue

local Requests = {}
Replicator.Requests = Requests

local processingUUID,processingData


CustomObjectsModule.SendObjects.OnClientEvent:Connect(function(UUID,Obj,ClassName,i,v)
	--print('[Evolve] Client recieving data:', UUID,Obj,ClassName,i,v)
	local loadingObj = Queue[UUID] or SerializeUtil.Decode_Queue[UUID] or (processingUUID == UUID and processingData)
	if loadingObj then
		if typeof(i) == "NestedPropertyPath" then
			local path = i._nestedtblpath
			SerializeUtil.GetEnclosingDir(loadingObj,path)[path[#path]] = v
		elseif i==nil and v==nil then --Block SerializedCO from loading again while it's already in loading
			return
		else
			loadingObj[i] = v
		end
		--print('[Evolve] Replicating property change prior to loading:',UUID,Obj,ClassName,i,v)
		return
	end
	
	Queue[UUID] = {Obj,ClassName,i,v}
	
end)


local function DoesExist(UUID)
	return Core.loaded_cache[UUID] or SerializeUtil.Decode_Queue[UUID] or Queue[UUID] or (processingUUID == UUID and processingData)
end
Replicator.DoesExist = DoesExist

local function RequestData(UUID)
	--print('[Evolve] Asking server for info for UUID:',UUID)
	Requests[UUID] = Promise.new(function(resolve)
		resolve(CustomObjectsModule.RequestReplication:InvokeServer(UUID))
	end)
	return Requests[UUID]
end

function Replicator.Load(UUID)
	--print('[Evolve] Load request:',UUID)
	
	if Requests[UUID] or DoesExist(UUID) then return end 
		
	Requests[UUID] = RequestData(UUID)
	local value = Requests[UUID]:expect()
	
	if DoesExist(UUID) then return end
	
	if Requests[UUID] and Requests[UUID] ~= "InstantLoad" then --would be if InstantLoad runs before
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
		local exists = DoesExist(UUID)
		if exists then return exists end
	end
	
	--print('[Evolve] Instant load request recieved:',UUID,"Sending to decode.")
	Requests[UUID] = nil

	local LoadedCO = CustomObjects.Wrap(serializedCustomObject)	
	return LoadedCO
	
end

return Replicator