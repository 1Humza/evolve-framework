local Util = {}

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Evolve"))

local typeof = require("typeof")

local UUIDUtil = require(script.Parent.UUID)
local Core = require(script.Parent.Core)
local Streamable = require("Streamable")

Util.serialized_cache = {}
local serialized_cache = Util.serialized_cache

Util.serialized_changes = {}

local function Serialize(PropertyTbl)

	local SerializedProperties = {}

	for i,v in pairs(PropertyTbl) do

		if typeof(v) == "CustomObject" then
			SerializedProperties[i] = {_Obj = Core.FormatObj(v:GetObject()),_ClassName = v:GetClassName()}
		elseif typeof(v) == "table" then
			SerializedProperties[i] = Serialize(v)
		elseif typeof(v) == "NestedPropertyTable" then
			--warn("[Evolve] Serializing..Found NestedPropertyTable!",i,v)
			local SerializedTable = Serialize(v)
			for i,v in pairs(SerializedTable) do
				SerializedTable[i]=nil
				SerializedTable[tostring(i)] = v--avoid mixed tables
			end
			SerializedTable._path = getmetatable(v)._path
			SerializedTable._root = unpack(Serialize({getmetatable(v)._root}))
			SerializedProperties[i] = SerializedTable
		elseif typeof(v) == "Instance" then
			local GenerateUUID = UUIDUtil.Generate(v)
			SerializedProperties[i] = Core.FormatObj(v)
		else
			SerializedProperties[i] = v
		end

	end
	return SerializedProperties
end

function Util.Encode(CustomObject)
	
	local SerializedObj = {}
	local _ReadOnly = rawget(CustomObject,"_ReadOnly")
	local Obj = _ReadOnly._Obj

	if not serialized_cache[Obj] then

		SerializedObj = Serialize(rawget(CustomObject,"_Properties"))
		SerializedObj['_Obj'] = Core.FormatObj(Obj)
		SerializedObj['_ClassName'] = _ReadOnly._ClassName
		
		--print('[Evolve] Creating new Serialization cache entry:',Obj,SerializedObj)
		serialized_cache[Obj] = SerializedObj
	else
		--print('[Evolve] Existing encoded cache exists. Returning that instead.')
		SerializedObj = serialized_cache[Obj]
	end
	
	return SerializedObj
end

local function MakeNewCustomObject(Data,newData)
	local loaded_cache = Core.loaded_cache
	
	local _ReadOnly = {}
	_ReadOnly._Obj = Data._Obj.Instance
	_ReadOnly._UUID = Data._Obj.UUID
	_ReadOnly._ClassName = Data._ClassName
	_ReadOnly._UnloadedReference = ((not newData) and true) or nil
	local NewCO = Core.NewCustomObject(_ReadOnly,true)
	
	--warn("[Evolve] Making new CustomObject:",Data,Data._Obj.Instance)

	return NewCO
end

Util.Decode_Queue = {}
local Decode_Queue = Util.Decode_Queue

function Util.Decode(Data,dataSet)
	--print("[Evolve] Request to decode recieved:",Data,dataSet)
	
	local Replicator = require(script.Parent.Replicator)

	local unloaded_cache = Core.unloaded_cache
	local loaded_cache = Core.loaded_cache

	local function Process(Data,newData)
		--print("[Evolve] Decoding data:",typeof(Data),Data)

		local target_tbl = {}

		if typeof(Data) == "SerializedCustomObject" then
			
			local UUID = Data._Obj.UUID
			
			--print("[Evolve] Loading SerializedCustomObject..",Data,UUID,loaded_cache[UUID],Decode_Queue[UUID],unloaded_cache[UUID])
			local cachedCustomObject = loaded_cache[UUID] or unloaded_cache[UUID] or Decode_Queue[UUID]
			
			target_tbl = cachedCustomObject or MakeNewCustomObject(Data,newData)
			Decode_Queue[UUID] = target_tbl
			--warn("[Evolve] Added", UUID, "to decode queue.",Decode_Queue)
			
			if not Data._Obj.Instance then
				Data._Obj.Instance = game:GetService("CollectionService"):GetTagged("_UUID_"..UUID)[1]
				target_tbl._ReadOnly._Obj = Data._Obj.Instance
				--print("[Evolve] Checking if instance exists...",Data._Obj.Instance)
				if not Data._Obj.Instance then
					--warn("[Evolve] Instance not found, waiting for _Obj:",target_tbl)
				end
			end

		end
		
		for i,v in pairs(Data) do
			if i == "_Obj" or i == "_ClassName" then continue end
			--print("[Evolve] Processing data:",i,typeof(v),v)
								
			if typeof(v) == "SerializedCustomObject" then
				local UUID = v._Obj.UUID
				--warn("[Evolve] Decoding.. ",Data,"Found SerializedCustomObject",v)
				
				v._Obj.Instance = v._Obj.Instance or game:GetService("CollectionService"):GetTagged("_UUID_"..UUID)[1]
				
				--print("[Evolve] Loading nested SerializedCustomObject.. Creating new Streamable:",Data,i,v,UUID,Decode_Queue,loaded_cache[UUID],Decode_Queue[UUID],unloaded_cache[UUID])
				local newCustomObject = loaded_cache[UUID] or unloaded_cache[UUID] or Decode_Queue[UUID] or Replicator.InstantLoad(UUID)
				
				local streamable = Streamable.new(newCustomObject,UUID)
				
				if not newCustomObject._ReadOnly._Obj then
					unloaded_cache[UUID] = newCustomObject
				end
				
				target_tbl[i] = streamable
			elseif typeof(v) == "SerializedInstance" then
				local UUID = v.UUID
				
				v = ((not v.Instance or v.Instance:IsDescendantOf(workspace)) and Streamable.new(UUID)) or v.Instance
				
				--print("[Evolve] Found SerializedInstance. Created new Streamable.",i,v)
				
				target_tbl[i] = v
			elseif typeof(v) == "SerializedNestedPropertyTable" then
				for a,b in pairs(v) do
					v[a]=nil
					v[tonumber(a) or a] = b
				end
				target_tbl[--[[unpack(Process({i}))]]i] = Core.NewNestedPropertyTable(Process(v._root),Process(v),v._path)
				--warn('[Evolve] NestedPropertyTable decoded:',i,v,target_tbl[i])
				
			else
				target_tbl[i] = v
			end
			
		end
		
		--print('[Evolve] Table decoded:',target_tbl)

		return target_tbl
	end
	
	local x = Process(Data,true)
	
	Decode_Queue[Data._Obj.UUID] = nil
	x._ReadOnly._UnloadedReference = nil
	
	--warn('[Evolve] CustomObject decoded:',x)

	return x
end

function Util.SetNestedTableValue(root,path,v)
	local dir = root
	for i,dirName in ipairs(path) do
		if i == "_path" then continue end
		if tonumber(i) == #path then
			dir[dirName] = v
			continue
		end
		dir[dirName] = dir[dirName] or {}
		dir = dir[dirName]
	end
end

function Util.ReplicateChange(self,i,v)
	local Obj = self:GetObject()
	
	if not (game:GetService("RunService"):IsServer() and serialized_cache[Obj]) then return end
	
	if typeof(v) == "Instance" or typeof(v) == "table" or typeof(v) == "NestedPropertyTable" then
		--print('[Evolve] Replicating NestedPropertyTable:',self,i,v)
		v = unpack(Serialize({v}))
	elseif typeof(v) == "CustomObject" then
		v = (serialized_cache[Obj] and {_Obj = Core.FormatObj(v:GetObject()),_ClassName = v:GetClassName()}) or Util.Encode(v)
	end
		
	if typeof(i) == "NestedPropertyPath" then
		Util.SetNestedTableValue(serialized_cache[Obj],i,v)
	else
		serialized_cache[Obj][i] = v
	end
	
	if Core.IsReplicable(Obj) then
		--print('[Evolve] Sending replicated change!', Core.FormatObj(Obj),self:GetClassName(),i,v)
		script.Parent.Parent.SendObjects:FireAllClients(Obj:GetAttribute("UUID"),Core.FormatObj(Obj),self:GetClassName(),i,v)
	else
		Util.serialized_changes[self] = Util.serialized_changes[self] or {_Obj = Core.FormatObj(self:GetObject()),_ClassName = self:GetClassName()}
		if typeof(i) == "NestedPropertyPath" then
			Util.SetNestedTableValue(Util.serialized_changes[self],i,v)
		end
		Util.serialized_changes[self][i] = v
	end
end

return Util