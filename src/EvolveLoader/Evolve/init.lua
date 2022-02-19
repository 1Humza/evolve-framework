local Evolve = setmetatable(
	{},
	{ __call = function(tbl,Request,IsReplicated)
		if Request == "Libraries" then
			return Libraries
		elseif Request then
			return RequestModule(Request,IsReplicated)
		end
	end}
)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

if RunService:IsStudio() and (RunService:IsClient() and RunService:IsServer()) then return Evolve end

local Classes = require(script._classes)

Libraries = {script}
Evolve.Libraries = Libraries

local ClassDirs = {}

function RequestModule(Request,IsReplicated)
	
	if typeof(Request) == "Instance" and Request:IsA("ModuleScript") then
		return require(Request)
	end
	
	for _,Lib in ipairs(Libraries) do
		if Lib:FindFirstChild(Request) then
			return require(Lib[Request])
		end
	end
	
	error("Module not found: "..Request,3)
	
end

function Evolve.RequestClass(Request,IsReplicated)
 
	local Class
	local classDir
	
	local Dirs = Request:split(".")
	
	for LibIndex,Library in ipairs(Libraries) do
		
		if Library:FindFirstChild("Classes") then
			
			classDir = Classes.GetClass(Library.Classes,Request)
			if not classDir then continue end
			
			local function LoadModule(module)
				local Module = typeof(module) == "table" and module or require(module)
				
				if Class == nil then Class = Module return end

				local existingMtbl = getmetatable(Class)

				if not existingMtbl then					
					local mtbl = {_classes={Module}}
					mtbl.__index = function(s,i)
						local v = mtbl[i]
						if v then return v end
						for _,dir in ipairs(mtbl._classes) do
							v = dir[i]
							if v then return v end
						end
					end
					setmetatable(Class,mtbl)
				elseif not existingMtbl._processed then
					table.insert(existingMtbl._classes,1,Module)
					--print(existingMtbl._classes)
				end
			end
			
			for _,Module in ipairs(classDir:GetChildren()) do
				if Module:IsA("ModuleScript") then
					local Name = Module.Name
					if RunService:IsServer() and Name:sub(#Name-5,#Name) == "Client" then continue end
					LoadModule(Module)
				end
			end
			
			if classDir.Parent.Name == "ChildClasses" then

				local Ancestor = classDir.Parent
				while Ancestor:IsA("Folder") and Ancestor.Name ~= "SubClasses" and Ancestor.Name ~= "Classes" do
					for _,Module in pairs(Ancestor:GetChildren()) do
						if Module:IsA("ModuleScript") then
							local Name = Module.Name
							if RunService:IsServer() and Name:sub(#Name-5,#Name) == "Client" then continue end
							LoadModule(Module)
						end
					end
					Ancestor = Ancestor.Parent
				end
			end
			
		end
	end
	
	assert(Class or IsReplicated, "Unable to locate class: "..Request)
	if getmetatable(Class) then
		getmetatable(Class)._processed = true
	end
	
	--print("[Evolve] Loading class:",Request,Class,getmetatable(Class))
		
	return Class
end

if RunService:IsServer() then
	ServerModules = game:GetService("ServerScriptService"):WaitForChild("Modules")
	table.insert(Libraries,ServerModules)
end

ClientModules = ReplicatedStorage:WaitForChild("Modules")
table.insert(Libraries,ClientModules)


return Evolve
