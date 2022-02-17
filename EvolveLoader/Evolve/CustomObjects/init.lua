local CO = {}

local RunService = game:GetService("RunService")

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Evolve"))

local CollectionService = game:GetService("CollectionService")
local Utils = script:WaitForChild("Utils")

local SerializeUtil = require(Utils.Serialize)
local UUIDUtil = require(Utils.UUID)
local Core = require(Utils.Core)

local typeof = require("typeof")
local Events = require("Events")
local Maid = require("Maid")

CO.Added = Events.new("Signal")
CO.Removed = Events.new("Signal")

function CO.new(Class,...)
	assert(typeof(Class)=="string", "Argument[1] is "..typeof(Class)..". String expected.")

	local _ReadOnly = {
		_ClassName = Class
	}
	local CustomObject = Core.NewCustomObject(_ReadOnly,{...})

	assert(_ReadOnly._Obj, "Instance not returned by 'new' constructor of class "..'"'..Class..'"')
	
	UUIDUtil.Generate(_ReadOnly._Obj)
	CustomObject:_init(...)

	return CustomObject
end

function CO.Wrap(Data,Class,...)

	local IsSerialized = typeof(Data) == "SerializedCustomObject" or typeof(Data) == "SerializedCustomObjectList"

	assert(Data and (typeof(Data) == "Instance" or IsSerialized), "Attempt to call Wrap on "..typeof(Data)..". Expected Instance.")

	local UUID = (not IsSerialized) and (Data:GetAttribute("UUID") or UUIDUtil.Generate(Data))or (IsSerialized and Data.UUID)
		
	local cachedValue = Core.loaded_cache[UUID]
	if (typeof(cachedValue) == "CustomObject") or ((not Class) and (not IsSerialized)) then
		assert(cachedValue, "CustomObject "..tostring(cachedValue).." does not exist or `Initialize` function is still running.")
		return cachedValue
	end
	
	local CustomObject

	if IsSerialized then

		CustomObject = SerializeUtil.Decode(Data,Class)

	else

		local _ReadOnly = {}
		_ReadOnly._Obj = Data
		_ReadOnly._UUID = UUID
		_ReadOnly._ClassName = Class

		CustomObject = Core.NewCustomObject(_ReadOnly,{...})
	end

	--warn("[Evolve] Calling _init: ",CustomObject._ClassName,CustomObject)
	
	CustomObject:_init(...)
	
	return CustomObject
end

function CO.Await(arg)
	--print("[Evolve] Awaiting CustomObject:",arg)
	local waitingInit = Core.awaiting_cache
	local UUID = (typeof(arg) == "number" and arg) or (arg:GetAttribute("UUID") or UUIDUtil.Generate(arg))
	if Core.loaded_cache[UUID] then return Core.loaded_cache[UUID] end
	
	if waitingInit[UUID] then
		local i = 2
		local trace = {debug.info(coroutine.running(),i,"sn")}
		while #trace>0 do
			if trace[1]:find(waitingInit[UUID]:GetClassName().."%-") and trace[2]:find("Initialize") or trace[2]:find("new") then
				error("Infinite yield caused by calling Await function within `Initialize` function of same class.",i)
			end
			i+=1
			trace = {debug.info(coroutine.running(),i,"sn")}
		end--]]
	end
	
	waitingInit[UUID] = waitingInit[UUID] or Events.new("Signal")
	return Core.loaded_cache[UUID] or typeof(waitingInit[UUID]) == "Signal" and waitingInit[UUID]:Wait()
		or typeof(waitingInit[UUID]) == "CustomObject" and waitingInit[UUID]._ReadOnly._Loaded:Wait()
end

local function DoInit(Target,...)
	if Target._Class.Initialize then
		Target._Class.Initialize(Target,Target._ReadOnly._ShownMaid,...)
	end
end
function CO._init(CustomObject,...)
	
	if not CustomObject:GetObject() then return end

	local UUID = CustomObject:GetUUID()
	local Obj = CustomObject:GetObject()

	local _ReadOnly = CustomObject._ReadOnly

	_ReadOnly._DestroyedConn = Obj:GetPropertyChangedSignal("Parent"):Connect(function()end)

	Core.awaiting_cache[UUID] = CustomObject

	local Init = _ReadOnly._AutoInit and DoInit(CustomObject,...)
	local Replicate = RunService:IsServer() and Core.IsReplicable(CustomObject) and script.SendObjects:FireAllClients(UUID,SerializeUtil.Encode(CustomObject))

	Core.loaded_cache[UUID] = CustomObject

	CollectionService:AddTag(Obj,"_CustomObject")

	Core.awaiting_cache[UUID] = nil
	local FireLoadedEvent = CustomObject._Loaded and CustomObject._Loaded:Fire(CustomObject)
	CustomObject._ReadOnly._Loaded = nil

	CO.Added:Fire(CustomObject)

	return CustomObject
	
end

function CO:Initialize()
	local NewRan = self._ReadOnly._NewRan
	self._ReadOnly._AutoInit = ((not NewRan) and true) or nil --defer init until object is loaded(called from .new())
	local yieldTilLoad = NewRan and self._Loaded and self._Loaded:Wait()
	local doInit = NewRan and DoInit(self) --only actually do it if it's not coming from .new()
end

function CO:Destroy()
	local _ReadOnly = self._ReadOnly

	Core.loaded_cache[self:GetUUID()] = nil
	Core.unloaded_cache[self:GetUUID()] = nil

	_ReadOnly._Obj:Destroy()

	local CleanUp = self._Properties._CleanUp and self._Properties:_CleanUp()
	_ReadOnly._ShownMaid:DoCleaning()

	SerializeUtil.serialized_cache[_ReadOnly._Obj] = nil
	SerializeUtil.serialized_changes[self] = nil
	
	local fireRemoved = RunService:IsClient() and CO.Removed:Fire(self)
	--print('[Evolve] Destroy() called on:',self)
	--local ReplicateDestruction = RunService:IsServer() and script.SendObjects:FireAllClients(self:GetUUID(),_ReadOnly._Obj,"_DESTROY")
end

function CO:GetObject()
	return self._ReadOnly._Obj
end

function CO:GetClassName()
	return self._ReadOnly._ClassName
end

function CO:GetUUID()
	return self._ReadOnly._UUID
end

--CO.Await = LoadUtil.Await

function CO:GetPropertyChangedSignal(property)
	local hasProperty,value = Core.CheckIfHasProperty(self:GetObject(),property)
	if hasProperty then return self:GetObject():GetPropertyChangedSignal(property) end
	
	local _ReadOnly = self._ReadOnly
	_ReadOnly._PropertyChangedSignals = _ReadOnly._PropertyChangedSignals or {}

	local Signal = _ReadOnly._PropertyChangedSignals[property] or Events.new("Signal")
	_ReadOnly._PropertyChangedSignals[property] = Signal
	
	return Signal
end

function CO:AddSearchBank(Additional,Original)
	local Original = Original or self
	local _ReadOnly = rawget(self,"_ReadOnly")
	_ReadOnly._SearchBanks = _ReadOnly._SearchBanks or {}
	_ReadOnly._SearchBanks[Original] = Additional
end

function CO:__index(i)
	local SB = self._ReadOnly._SearchBanks
	if SB and ((SB[i] and SB[i][i]) or (SB[self] and SB[self][i])) then
		return (SB[i] and SB[i][i]) or (SB[self] and SB[self][i])
	elseif self._Properties[i] ~= nil then
		local Value = self._Properties[i]
		if typeof(Value) == "SerializedInstance" then
			return self._Properties[i].Instance
		elseif typeof(Value) == "CustomObject" and Value._ReadOnly._UnloadedReference then
			return nil
		end

		return Value
	elseif CO[i] ~= nil then
		return CO[i]
	elseif self._Class[i] ~= nil then
		return self._Class[i]
	elseif self._ReadOnly[i] ~= nil then
		return self._ReadOnly[i]
	else
		local ObjHasProperty, ObjProperty = Core.CheckIfHasProperty(self._ReadOnly._Obj,i,true)

		if type(ObjProperty) == "function" then
			if i:lower() == "destroy" or i:lower() == "remove" then
				self:Destroy()
			end
			local ChangeSelfArgAndRun = function(...)
				local args = {...}
				args[1] = self._ReadOnly._Obj
				return ObjProperty(unpack(args))
			end

			return ChangeSelfArgAndRun
		end
		return (ObjHasProperty and ObjProperty) or nil

	end
end

--[[function CO:__tostring()
	return tostring(self:GetObject())
end]]

function CO:__newindex(i,v)
	local _ReadOnly = self._ReadOnly
	local ObjHasProperty, ObjProperty = Core.CheckIfHasProperty(_ReadOnly._Obj,i,false)
	if ObjHasProperty then
		_ReadOnly._Obj[i] = v
	else
		assert(CO[i]==nil and _ReadOnly[i]==nil,"Unable to overwrite ReadOnly property: "..tostring(i))
		local v = (typeof(v) == "table" and Core.NewNestedPropertyTable(self,v,{i})) or v
		UUIDUtil.Generate(v)
		SerializeUtil.ReplicateChange(self,i,v)
		self._Properties[i] = v
	end
	local FireChangedSignal = _ReadOnly._PropertyChangedSignals and _ReadOnly._PropertyChangedSignals[i] and _ReadOnly._PropertyChangedSignals[i]:Fire(v)
	local AwaitFunc = rawget(self,"_await_"..tostring(i)) and rawget(self,"_await_"..tostring(i))()
end

function CO:Clone(AlreadyCloned)

	local function FindClone(Original)
		local UUID = Original:GetAttribute("UUID")
		for _,Object in ipairs(game:GetService("CollectionService"):GetTagged("_UUID_"..UUID)) do
			if Object ~= Original then
				return Object
			end
		end
		return nil
	end

	local Object = self:GetObject()

	local NewObject = (not AlreadyCloned and Object:Clone()) or Object
	local UUID = UUIDUtil.Generate(NewObject,true)
	local NewCO = Core.NewCustomObject({
		_Obj = NewObject,
		_UUID = UUID,
		_ClassName = self:GetClassName()
	})
	Core.loaded_cache[UUID] = NewCO

	local function ExtractProperties(Properties)
		local Cache = {}
		for i,Property in pairs(Properties) do
			if typeof(Property) == "CustomObject" and Property:GetObject():IsDescendantOf(Object) then

				local ClonedObject = FindClone(Property:GetObject())
				UUIDUtil.Generate(ClonedObject)
				Cache[i] = Property:Clone(true)

			elseif typeof(Property) == "SerializedInstance" and Property.Instance:IsDescendantOf(Object) then

				local ClonedObject = FindClone(Object)
				UUIDUtil.Generate(ClonedObject)
				Cache[i] = Core.FormatObj(ClonedObject)

			elseif typeof(Property) == "table" then
				Cache[i] = ExtractProperties(Property)
			else
				Cache[i] = Property
			end
		end
		return Cache
	end
	NewCO._Properties = ExtractProperties(self._Properties)
	NewCO:_init()

	local Replicate = RunService:IsServer() and Core.IsReplicable(NewCO) and script.SendObjects:FireAllClients(UUID,SerializeUtil.Encode(NewCO))

	local Trace = debug.traceback()
	if (Trace:find('function Initialize')) then
		error("Infinite operation due to 'Clone' called in initialization function. Try cloning the Instance by calling 'GetObject' on the Custom Object.")
	end

	return NewCO
end


if game:GetService("RunService"):IsServer() then
	script.RequestReplication.OnServerInvoke = function(player,UUID)
		--print("[Evolve] Recieved replication request from client",player,"for UUID:",UUID,Core.loaded_cache[UUID])
		return SerializeUtil.Encode(Core.loaded_cache[UUID])
	end
	
	local function PlayerAdded(Player)
		script["Custom Objects Replicator"]:Clone().Parent = Player.PlayerGui
	end
	game.Players.PlayerAdded:Connect(PlayerAdded)
	for _,Player in pairs(game.Players:GetPlayers()) do
		PlayerAdded(Player)
	end

	require(Utils.Load).DescendantAddedToReplicatedDirectory:Connect(function(Descendant)

		local UUID = Descendant:GetAttribute("UUID")
		local CustomObject = UUID and Core.loaded_cache[UUID]

		if not CustomObject then return end

		local function VerifyIndexes(tbl)
			for i,v in pairs(tbl) do
				assert(typeof(i) =="number" or typeof(i)=="string","CustomObject: ".."'"..tostring(CustomObject).."'".." Class: ".."'"..CustomObject:GetClassName().."'".." Error: Expected index type number or type string(unable to replicate other index value types) when indexing properties. Got type: "..typeof(i))
				local recurse = typeof(v) == "table" and VerifyIndexes(v)	
			end
		end
		VerifyIndexes(rawget(CustomObject,"_Properties"))

		local EncodedCO = SerializeUtil.serialized_changes[CustomObject] or SerializeUtil.Encode(CustomObject)
		script.SendObjects:FireAllClients(UUID,EncodedCO)
	end)

	--UUIDUtil.InitialGenerate()
end

return CO