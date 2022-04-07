local UUIDUtil = {}

local CollectionService = game:GetService("CollectionService")

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Evolve"))

local typeof = require("typeof")

local IsServer = game:GetService("RunService"):IsServer()

local GlobalDescendantCount = 0

function UUIDUtil.Generate(target,forceLoad)
	local target = (typeof(target)=="Instance" and target or typeof(target) == "CustomObject" and target:GetObject()) or nil
	if not target then return end

	local function Generate()
		GlobalDescendantCount = GlobalDescendantCount+(IsServer and 1 or -1)
		
		--if GlobalDescendantCount == 9  then print(debug.traceback()) end
		game.CollectionService:AddTag(target,"_UUID_"..GlobalDescendantCount)
		target:SetAttribute("UUID", GlobalDescendantCount)

		return GlobalDescendantCount
	end
	
	local function Process(target)
		
		local UUIDAttribute = target:GetAttribute("UUID")
		
		if forceLoad then return Generate() end
		if not UUIDAttribute then return Generate() end
		--if target.Name == "ClipBoard" then print(target,UUIDAttribute) end
			
		local ObjsSharingUUID = CollectionService:GetTagged("_UUID_"..UUIDAttribute)
		if #ObjsSharingUUID > 0 and ObjsSharingUUID[1] ~= target then
			for _,Tag in ipairs(CollectionService:GetTags(target)) do
				local RemoveUUID = Tag:sub(1,6) == "_UUID_" and CollectionService:RemoveTag(target,Tag)
			end
			return Generate()
		end
		
		return UUIDAttribute
	end

	return Process(target)
end

--Remove All UUIDs
--[[
local CollectionService = game:GetService("CollectionService")
for _,v in pairs(game:GetDescendants()) do
	pcall(function()
		v:SetAttribute("UUID",nil)
		for _,Tag in pairs(CollectionService:GetTags(v)) do
			local RemoveUUID = Tag:sub(1,6) == "_UUID_" and CollectionService:RemoveTag(v,Tag)
		end
	end)
end]]


return UUIDUtil