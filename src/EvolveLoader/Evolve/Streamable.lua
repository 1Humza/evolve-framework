--!nonstrict

-- Streamable
-- Stephen Leitnick + Humza Mohammed
-- March 03, 2021

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Evolve"))

local Maid = require("Maid")
local typeof = require("typeof")
local Events = require("Events")

local CollectionService = game:GetService("CollectionService")

type StreamableWithInstance = {
	Instance: Instance?,
	_maid: typeof(Maid.new()),
	[any]: any,
}

--[=[
	@within Streamable
	@prop Instance Instance
	The current instance represented by the Streamable. If this
	is being observed, it will always exist. If not currently
	being observed, this will be `nil`.
]=]

--[=[
	@class Streamable
	@client
	Because parts in StreamingEnabled games can stream in and out of existence at
	any point in time, it is hard to write code to interact with them. This is
	where Streamables come into play. Streamables will observe the existence of
	a given instance, and will signal when the instance exists and does not
	exist.

	The API is very simple. Create a Streamable that points to a certain parent
	and looks for a specific child instance (typically a BasePart). Then, call
	the `Observe` method to observe when the instance streams in and out.

	```lua
	local Streamable = require(packages.Streamable).Streamable

	-- Models might take a bit to load, but the model instance
	-- is never removed, thus we can use WaitForChild.
	local model = workspace:WaitForChild("MyModel")

	-- Watch for a specific part in the model:
	local partStreamable = Streamable.new(model, "SomePart")

	partStreamable:Observe(function(part, trove)
		print(part:GetFullName() .. " added")
		-- Run code on the part here.
		-- Use the trove to manage cleanup when the part goes away.
		trove:Add(function()
			-- General cleanup stuff
			print(part.Name .. " removed")
		end)
	end)

	-- Watch for the PrimaryPart of a model to exist:
	local primaryStreamable = Streamable.primary(model)
	primaryStreamable:Observe(function(primary, trove)
		print("[Evolve] Model now has a PrimaryPart:", primary.Name)
		trove:Add(function()
			print("[Evolve] Model's PrimaryPart has been removed")
		end)
	end)

	-- At any given point, accessing the Instance field will
	-- reference the observed part, if it exists:
	if partStreamable.Instance then
		print("[Evolve] Streamable has its instance:", partStreamable.Instance)
	end

	-- When/if done, call Destroy on the streamable, which will
	-- also clean up any observers:
	partStreamable:Destroy()
	primaryStreamable:Destroy()
	```

	For more information on the mechanics of how StreamingEnabled works
	and what sort of behavior to expect, see the
	[Content Streaming](https://developer.roblox.com/en-us/articles/content-streaming#technical-behavior)
	page. It is important to understand that only BaseParts and their descendants are streamed in/out,
	whereas other instances are loaded during the initial client load. It is also important to understand
	that streaming only occurs on the client. The server has immediate access to everything right away.
]=]
local Streamable = {}
Streamable.__index = Streamable


--[=[
	@return Streamable
	@param parent Instance
	@param childName string

	Constructs a Streamable that watches for a direct child of name `childName`
	within the `parent` Instance. Call `Observe` to observe the existence of
	the child within the parent.
]=]
function Streamable.new(a: Instance | number, b: (string | number)?)

	local self: StreamableWithInstance = {
		_maid = Maid.new(),
		_shown = Events.new("Signal"),
		_shownMaid = Maid.new()
	}
	setmetatable(self, Streamable)
	
	self._maid:GiveTask(self._shownMaid)
	
	function self._setValue(value)
		if value==nil or self.Value then return end
		self.Value = value
		self._shown:Fire(value,self._shownMaid)
		self._shownMaid:GiveTask(value:GetPropertyChangedSignal("Parent"):Connect(function()
			if not value.Parent then
				self._shownMaid:DoCleaning()
			end
		end))
		self._shownMaid:GiveTask(function()
			if self.Value == value then
				self.Value = nil
			end
		end)
	end
	
	if typeof(a) == "Instance" and typeof(b) == "string" then
		newParentChildStreamable(self, a, b)
	elseif typeof(a) == "CustomObject" then
		newCustomObjectStreamable(self, b)
	elseif typeof(a) == "number" then
		newUUIDStreamable(self, a)
	end
	
	return self

end

function newParentChildStreamable(self, parent: Instance, childName: string)
	
	self._setValue(parent:FindFirstChild(childName))

	local function OnChildAdded(child: Instance)
		if child.Name == childName then
			self._setValue(child)
		end
	end

	self._maid:GiveTask(parent.ChildAdded:Connect(OnChildAdded))
	
end

function newUUIDStreamable(self, UUID: number)
	
	self._setValue(CollectionService:GetTagged("_UUID_"..UUID)[1])
	self._maid:GiveTask(CollectionService:GetInstanceAddedSignal("_UUID_"..UUID):Connect(self._setValue))
	
end

function newCustomObjectStreamable(self, UUID: number)
	
	local CO = require("CustomObjects")
	
	local function valueSet(value)
		if not value then return end
		self.Value = value
		self._shown:Fire(value,self._shownMaid)
		self._shownMaid:GiveTask(CO.Removed:Connect(function(removedObject)
			if removedObject:GetUUID() == UUID then
				self._shownMaid:DoCleaning()
				self.Value = nil
			end
		end))
	end
	valueSet(require(script.Parent.CustomObjects.Utils.Core).loaded_cache[UUID])
	
	local function OnCustomObjectAdded(newCustomObject)
		if newCustomObject:GetUUID() == UUID then
			valueSet(newCustomObject)
		end
	end
	
	self._maid:GiveTask(CO.Added:Connect(OnCustomObjectAdded))
	
end

--[=[
	@return Streamable
	@param parent Model

	Constructs a streamable that watches for the PrimaryPart of the
	given `parent` Model.
]=]
function Streamable.primary(parent: Model)

	local self: StreamableWithInstance = {
		_maid = Maid.new(),
		_shown = Events.new("Signal"),
		_shownMaid = Maid.new()
	}
	setmetatable(self, Streamable)

	self._maid:GiveTask(self._shownMaid)

	self.Instance = parent.PrimaryPart

	local function OnPrimaryPartChanged()
		local primaryPart = parent.PrimaryPart
		self._shownMaid:DoCleaning()
		self.Instance = primaryPart
		if primaryPart then
			self._shown:Fire(primaryPart, self._shownMaid)
		end
	end

	self._maid:GiveTask(parent:GetPropertyChangedSignal("PrimaryPart"):Connect(OnPrimaryPartChanged))
	if self.Instance then
		OnPrimaryPartChanged()
	end

	return self

end


export type Streamable = typeof(Streamable.new(workspace, "X"))
type Streamables = { Streamable }
type CompoundHandler = (Streamables, any) -> nil

--[=[
	@param streamables {Streamable}
	@param handler ({[child: string]: Instance}, trove: Trove) -> nil
	@return Trove
	Creates a compound streamable around all the given streamables. The compound
	streamable's observer handler will be fired once _all_ the given streamables
	are in existence, and will be cleaned up when _any_ of the streamables
	disappear.
	```lua
	local s1 = Streamable.new(workspace, "Part1")
	local s2 = Streamable.new(workspace, "Part2")
	local compoundTrove = StreamableUtil.Compound({S1 = s1, S2 = s2}, function(streamables, trove)
		local part1 = streamables.S1.Instance
		local part2 = streamables.S2.Instance
		trove:Add(function()
			print("[Evolve] Cleanup")
		end)
	end)
	```
]=]
function Streamable.Compound(streamables: Streamables, handler: CompoundHandler)
	
	local compoundMaid = Maid.new()
	local observeAllMaid = Maid.new()
	local allAvailable = false
	local function Check()
		if allAvailable then return end
		for _,streamable in pairs(streamables) do
			if not streamable.Value then
				return
			end
		end
		allAvailable = true
		handler(observeAllMaid)
	end
	local function Cleanup()
		if not allAvailable then return end
		allAvailable = false
		observeAllMaid:DoCleaning()
	end
	for _,streamable in pairs(streamables) do
		compoundMaid:GiveTask(streamable:Observe(function(_child, maid)
			Check()
			maid:GiveTask(Cleanup)
		end))
	end
	compoundMaid:GiveTask(Cleanup)
	return compoundMaid
	
end


--[=[
	@param handler (instance: Instance, trove: Trove) -> nil
	@return Connection

	Observes the instance. The handler is called anytime the
	instance comes into existence, and the trove given is
	cleaned up when the instance goes away.

	To stop observing, disconnect the returned connection.
]=]
function Streamable:Observe(handler)
	if self.Value then
		if typeof(self.Value) == "CustomObject" then
			if self.Value._ReadOnly._Obj then
				task.spawn(handler, self.Value, self._shownMaid)
			end
		else
			task.spawn(handler, self.Value, self._shownMaid)
		end
	end
	return self._shown:Connect(handler)
end


--[=[
	Destroys the Streamable. Any observers will be disconnected,
	which also means that troves within observers will be cleaned
	up. This should be called when a streamable is no longer needed.
]=]
function Streamable:Destroy()
	self._maid:Destroy()
end


return Streamable