local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicatedModuleFolder = Instance.new("Folder")
ReplicatedModuleFolder.Name = "Modules"
ReplicatedModuleFolder.Parent = ReplicatedStorage

local ServerModules = game:GetService("ServerScriptService").Modules

for _,Module in ipairs(ServerModules.Shared:GetChildren()) do Module.Parent = ReplicatedModuleFolder end
for _,Module in ipairs(ServerModules.Client:GetChildren()) do Module.Parent = ReplicatedModuleFolder end
for _,Module in ipairs(ServerModules.Server:GetChildren()) do Module.Parent = ServerModules end
ServerModules.Shared:Destroy()
ServerModules.Client:Destroy()
ServerModules.Server:Destroy()

local function ReplicateDirectory(Directory)

	local function CreateDirectory(Name,Parent)

		local Dir = Instance.new("Folder")
		Dir.Name = Name
		Dir.Parent = Parent

		return Dir
	end
	
	local function LoadChildClasses(Directory)
		for _,Class in ipairs(Directory:GetChildren()) do
			if Class:FindFirstChild("ChildClasses") then
				LoadChildClasses(Class.ChildClasses)
			end
			if Directory.Name == "ChildClasses" then

				for _,Module in ipairs(Class:GetChildren()) do
					if Module:IsA("ModuleScript") then
						
						local Suffix = Module.Name:sub(Module.Name:find(Module.Parent.Name,1,true))
						local Ancestor = Directory
						while Ancestor.Name ~= "Classes" do
							if Ancestor.Parent.Name:find("Classes") then
								local ParentModule = Ancestor:FindFirstChild(Ancestor.Name..Suffix)
								if ParentModule then
									for i,v in pairs(require(ParentModule)) do
										require(Module)[i] = v
									end
								end
							end
							Ancestor = Ancestor.Parent
						end
					end
				end

			end
		end
	end
	--LoadChildClasses(Directory)

	local function ReplicateClass(Class)

		local HasServerModules = Class:FindFirstChild(Class.Name..'-Server')
		local HasClientModules = Class:FindFirstChild(Class.Name..'-Shared') or Class:FindFirstChild(Class.Name..'-Client')

		--local FormattedCorrectly = HasServerModules or HasClientModules
		
		--if not FormattedCorrectly then return end
		--local RemoveBrokenClass = not FormattedCorrectly and --warn("[Evolve] Class:",Class,"Empty or Module(s) incorrectly named. Will not load.",Class:Destroy())

		local NewClass = CreateDirectory(Class.Name)
		
		local x = HasServerModules and NewClass:SetAttribute("HasServerSide",true)

		for _,Child in ipairs(Class:GetChildren()) do
			if Child:IsA("Folder") and Child.Name:find("Classes")then
				local NewDirectory = ReplicateDirectory(Child)
				if #NewDirectory:GetChildren() > 0 then
					NewDirectory.Parent = NewClass
				end
			elseif Child:IsA("Folder") and not Child.Name:find("Classes") then
				ReplicateClass(Child).Parent = NewClass
			elseif HasClientModules and Child:IsA("ModuleScript") then
				if Child.Name ~= Class.Name.."-Server" then
					Child.Parent = NewClass
				end
			end
		end

		if not HasServerModules and HasClientModules then Class:Destroy() end

		return NewClass
	end

	local NewDirectory = CreateDirectory(Directory.Name)

	for _,Child in ipairs(Directory:GetChildren()) do
		if Child:IsA("Folder") then
			local NewClass = ReplicateClass(Child)
			if NewClass then NewClass.Parent = NewDirectory end
		elseif Child:IsA("ModuleScript") then
			if Directory.Name:find("Classes") then
				--warn("[Evolve] Module:",Child,"found outside of Class folder. Will not load.")
				Child:Destroy()
			end
		end
	end

	return NewDirectory
end

ReplicateDirectory(ServerModules.Classes).Parent = ReplicatedModuleFolder

local EvolveModule = script.Evolve
EvolveModule.Parent = ReplicatedStorage

local Binder = require(EvolveModule._binder)
Binder.BindTags(ReplicatedModuleFolder.Classes)
Binder.BindTags(ServerModules.Classes)

require(EvolveModule)("CustomObjects")