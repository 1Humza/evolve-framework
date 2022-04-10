local Core = {}

local RunService = game:GetService("RunService")


local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Evolve"))

local UUIDUtil = require(script.Parent.UUID)
local Events = require("Events")
local typeof = require("typeof")
local Table = require("Table")
local Maid = require("Maid")



Core.unloaded_cache = (RunService:IsClient() and setmetatable({},{__mode="v"})) or nil
Core.loaded_cache = {}
Core.awaiting_cache = setmetatable({},{__mode="v"})




function Core.CheckIfHasProperty(Item,Property,CanBeChild)
	if not Item then return false, nil end
	local success, response = pcall(function()
		return Item[Property]
	end)
	if CanBeChild == false and Item:FindFirstChild(Property) then return false, nil end
	return success, response
end

Core.NonReplicatedDirs = {
	["ReplicatedFirst"] = true,
	["NetworkServer"] = true,
	["ServerScriptService"] = true,
	["ServerStorage"] = true
}
function Core.IsReplicable(Obj)
	local Obj = typeof(Obj) == "Instance" and Obj or typeof(Obj) == "CustomObject" and Obj:GetObject()
	return Obj and not(Obj:IsDescendantOf(game:GetService("ReplicatedFirst")) and Obj:IsDescendantOf(game:GetService("NetworkServer")) and Obj:IsDescendantOf(game:GetService("ServerScriptService")) and Obj:IsDescendantOf(game:GetService("ServerStorage"))) or not Obj and false
end



function Core.FormatObj(v)
	if not v:GetAttribute("UUID")  then
		v:GetAttributeChangedSignal("UUID"):wait()
	end
	return {['Instance']=v,['UUID']=v:GetAttribute("UUID") }
end



function Core.NewNestedPropertyTable(CustomObject,displayTable,path) --Client table will keep track of streamables in table as come in/out & replication signals on change

	local Load = require(script.Parent.Load)

	local metaTable = {}--Behind the display, handles requests

	metaTable._path = path
	metaTable._root = CustomObject
	metaTable._data = {}

	metaTable.__call = function(self)
		return metaTable._data
	end

	metaTable.__index = metaTable._data

	metaTable.__newindex = function(self,i,v)
		
		local ReplicatedServerObject = RunService:IsServer() and Core.IsReplicable(CustomObject)

		if ReplicatedServerObject then --Only apply index restrictions for replicable entities
			assert(typeof(i) == "string" or typeof(i) == "number", "Invalid Key type "..typeof(i)..". Expected string or number.")
		end

		local newPath = typeof(v) == "table" and not getmetatable(v) and {unpack(metaTable._path)}
		local addNewDirToPath = newPath and table.insert(newPath,i)
		local isNewValue = metaTable._data[i] ~= v
		metaTable._data[i] = (newPath and Core.NewNestedPropertyTable(CustomObject,v,newPath) or v)

		if ReplicatedServerObject and isNewValue then
			local newPath = {_nestedtblpath={unpack(metaTable._path)}}
			newPath._nestedtblpath[#metaTable._path+1]=tostring(i)
			require(script.Parent.Serialize).ReplicateChange(CustomObject,newPath,v)
		end

	end

	local newNPT = setmetatable({
		_content = metaTable._data
	},metaTable)

	if displayTable then
		for i,v in pairs(displayTable) do
			if (i=="_root"or i=="_path") then continue end-- ignore serialized tags
			newNPT[i]= v--invoke __newindex to process original table
		end
	end

	return newNPT
end


function Core.NewCustomObject(_ReadOnly,IsReplicated)
	local ClassName = _ReadOnly._ClassName
	local args = (typeof(IsReplicated) == "table" and IsReplicated) or {}
	if next(args) then IsReplicated = nil end

	local Response = require.RequestClass(ClassName,IsReplicated)

	local NewCO = setmetatable({
		_Properties = {},
		_ReadOnly = _ReadOnly,
		_Class = (typeof(Response) == "string" and error(Response)) or ((typeof(Response) == "table" and Response) or (IsReplicated and {}) or error("Cannot find Class: "..ClassName,2)),
	},require("CustomObjects"))

	_ReadOnly._ShownMaid = Maid.new()

	local Constructor = NewCO._Class.new
	if IsReplicated and not Constructor then
		_ReadOnly._NewRan = true
		return NewCO
	end
	
	local mtbl = getmetatable(NewCO._Class)
	if mtbl then
		local superclasses = mtbl._classes
		for _,superclass in ipairs(superclasses) do--new
			local returnedObj = superclass.new and superclass.new(NewCO,unpack(args))
			_ReadOnly._Obj = _ReadOnly._Obj or returnedObj
		end
	end

	assert(Constructor,'Cannot create new object of Class "'..ClassName..'"'.."; 'new' constructor not found.")
	local a,b = Constructor(NewCO,unpack(args))
	local newObj = typeof(a) == "Instance" and a or nil
	local props = b or (not newObj and a) or nil
	
	_ReadOnly._Obj = _ReadOnly._Obj or newObj
	_ReadOnly._UUID = _ReadOnly._UUID or UUIDUtil.Generate(_ReadOnly._Obj)
	_ReadOnly._Loaded = Core.awaiting_cache[_ReadOnly._UUID] or Events.new("Signal")

	for prop,v in pairs(props or {}) do
		NewCO[prop] = v-- Iterating through all properties allows __newindex to process them.
	end
	
	local mtbl = getmetatable(NewCO._Class)
	if mtbl then
		local superclasses = mtbl._classes
		for _,superclass in ipairs(superclasses) do--Initialize
			if not (NewCO._ReadOnly._AutoInit and superclass.Initialize) then continue end
			superclass.Initialize(NewCO,_ReadOnly._ShownMaid,unpack(args))
		end
		local con
		con = _ReadOnly._Loaded:Connect(function()
			con:Disconnect()
			for i,superclass in ipairs(superclasses) do--Start
				if not superclass.Start then continue end
				superclass.Start(NewCO,_ReadOnly._ShownMaid)
			end
		end)

	end

	_ReadOnly._NewRan = true

	return NewCO
end


return Core