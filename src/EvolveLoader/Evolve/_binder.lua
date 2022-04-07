local Binder = {}

local RunService = game:GetService("RunService")
local isClient,isServer = RunService:IsClient(),RunService:IsServer()
local env = (isClient and "Client") or (isServer and "Server")

local CollectionService = game:GetService("CollectionService")

local Classes = require(script.Parent._classes)

local tagPrefix = "Class."

function Binder.BindTags(classesDir)
	for path,class in pairs(Classes.Get(classesDir)) do
		if isClient and class:GetAttribute("HasServerSide") then continue end
		if isServer and (not class:FindFirstChild(class.Name.."-Server")) and (not class:FindFirstChild(class.Name.."-Shared")) then continue end
		local tag = tagPrefix..path
		--print('[Evolve] Creating binder for tag:', tag)
		local function Load(instance)
			if CollectionService:HasTag(instance,"_CustomObject") then return end
			if instance:IsDescendantOf(game:GetService("StarterGui")) 
				or instance:IsDescendantOf(game:GetService("StarterPlayer")) 
				or instance:IsDescendantOf(game:GetService("StarterPack")) 
			then return end --Avoids double wrapping: these directories clone to other directories
			--print("[Evolve] Found instance with class binder tag:",instance,CollectionService:GetTags(instance),tag,debug.traceback())
			require(script.Parent.CustomObjects).Wrap(instance,path)
		end
		
		CollectionService:GetInstanceAddedSignal(tag):Connect(Load)
		for _,instance in pairs(CollectionService:GetTagged(tag)) do
			Load(instance)
		end
		
	end
end


return Binder