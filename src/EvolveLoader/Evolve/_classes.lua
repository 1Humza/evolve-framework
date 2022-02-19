local Classes = {}

local splitter = "."
local classDirectoryTypes = {
	"SubClasses",
	"ChildClasses"
}

function Classes.Get(dir)--returns dictionary [path]=class
	local classes = {}

	local function process(dir,path)
		for _,class in pairs(dir:GetChildren()) do
			for _,directoryType in pairs(classDirectoryTypes) do
				if class:FindFirstChild(directoryType) then
					process(class[directoryType],path..class.Name..splitter)
				end
			end
			if class:FindFirstChildWhichIsA("ModuleScript") then
				classes[path..class.Name] = class
			else
				process(class,path..class.Name..splitter)
			end
		end
	end
	process(dir,"")

	return classes
end

function Classes.GetClass(dir,path)--returns class from path	
	local dirNames = string.split(path,splitter)
	
	local function FindInNestedDir(dirName)
		local subDir
		for i,directoryType in pairs(classDirectoryTypes) do
			subDir = dir:FindFirstChild(directoryType) and dir[directoryType]:FindFirstChild(dirName)
			if subDir then return subDir end
		end
	end
	
	for _,dirName in pairs(dirNames) do
		local foundInNestedDir = FindInNestedDir(dirName)
		dir = foundInNestedDir or dir
		if foundInNestedDir then continue end
		if not dir:FindFirstChild(dirName) then return end
		dir = dir[dirName]
	end
	
	if #dir:GetChildren() == 0 then return end
	return dir
end

return Classes
