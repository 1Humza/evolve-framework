local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Evolve"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local EvolveModule = ReplicatedStorage.Evolve
local CustomObjectsModule = EvolveModule.CustomObjects

local CustomObject = require(CustomObjectsModule)
local Core = require(CustomObjectsModule.Utils.Core)
local UUIDUtil = require(CustomObjectsModule.Utils.UUID)
local Serialize = require(CustomObjectsModule.Utils.Serialize)
local Replicator = require(CustomObjectsModule.Utils.Replicator)

local typeof = require("typeof")
local Events = require("Events")
local _classes = require("_classes")

local Binder = require(EvolveModule._binder)
Binder.BindTags(ReplicatedStorage:WaitForChild("Modules").Classes)



function ProcessInstance(instance)
	local Success,UUID
	
	UUID = instance:GetAttribute("UUID")
	if not UUID then return end
	
	local CheckClone = UUID<0 and UUIDUtil.Generate(instance) --if is a clone of instance (made on client) with UUID this will give it new one
	if CheckClone then return end
	
	--warn("[Evolve] New Instance with UUID added:",UUID,instance)
	if Replicator.DoesExist(UUID) then return end
	
	local unloaded_CO = Core.unloaded_cache[UUID]
	if unloaded_CO then
		--print("[Evolve] Reloading unloaded CustomObject:", unloaded_CO,instance)
		unloaded_CO._ReadOnly._Obj = instance
		Core.unloaded_cache[UUID] = nil
		Core.loaded_cache[UUID] = unloaded_CO
		Core.strong_ref[UUID] = unloaded_CO
		unloaded_CO:_init()
		return
	end
	
	for _,tag in pairs(CollectionService:GetTags(instance)) do --Only ask sever to replicate if it has serverside
		if tag:sub(1,6) == "Class." then
			local class = _classes.GetClass(ReplicatedStorage.Modules.Classes,tag:gsub("Class.",""))
			if not (class and class:GetAttribute("HasServerSide")) then
				return--if no serverside then return
			end
		end
	end
	
	Replicator.Load(UUID)

end

CollectionService:GetInstanceAddedSignal("_CustomObject"):Connect(ProcessInstance)

for _,Instance in pairs(CollectionService:GetTagged("_CustomObject")) do
	ProcessInstance(Instance)
end






CollectionService:GetInstanceRemovedSignal("_CustomObject"):Connect(function(Descendant)
	
	local Success,UUID = pcall(function() return Descendant:GetAttribute("UUID") end)
	if not (Success and UUID) then return end

	Core.unloaded_cache[UUID] = Core.loaded_cache[UUID]
	Core.loaded_cache[UUID] = nil
	Core.strong_ref[UUID] = nil
	
	--[[local customObject = Core.loaded_cache[UUID]
	--warn(Descendant,typeof(customObject), 'Removed.',customObject,Core.unloaded_cache)
	
	local isLoading = (not customObject) and Replicator.Requests[UUID] or Replicator.Queue[UUID]
	
	local function CleanUp(customObject)
		local Loaded = customObject._Loaded and customObject._Loaded:Wait()

		Core.loaded_cache[UUID] = nil
		Core.strong_ref[UUID] = nil
		Core.unloaded_cache[UUID] = customObject
		customObject._ReadOnly._ShownMaid:DoCleaning()
		CustomObject.Removed:Fire(customObject)
		customObject = nil
		Descendant = nil
	end
	
	if customObject then
		CleanUp(customObject)
	elseif isLoading then
		local conn
		conn = CustomObject.Added:Connect(function(customObject)
			if customObject:GetUUID() == UUID then
				conn:Disconnect()
				CleanUp(customObject)
			end
		end)
	end]]

end)