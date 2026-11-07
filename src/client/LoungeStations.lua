-- Client presentation/navigation only. Purchase and acknowledgment remain in EggHatchView.
local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
local Priority=require(script.Parent.JournalPromptPriority)
local Stations={};Stations.__index=Stations
local known={Eggs=true,Journal=true,Customize=true}
-- Nodes must still belong to the live player UI, not merely retained Lua references.
function Stations.uiLive(owner,playerGui,mainGui,overlayGui,...)
	if owner.destroyed or not playerGui or not mainGui or not overlayGui
		or not mainGui:IsDescendantOf(playerGui) or not overlayGui:IsDescendantOf(playerGui)
		or not mainGui.Enabled or not overlayGui.Enabled then return false end
	for index=1,select("#",...) do
		local node=select(index,...)
		if not node or not node:IsDescendantOf(playerGui) then return false end
	end
	return true
end
function Stations.canRoam(state)
	return state.uiReady==true and state.mode=="Room" and state.viewMode=="Room" and state.alive==true
		and not state.busy and not state.switchQueued and not state.focusing and not state.overlay
		and not state.menuOpen and not state.coreMenu and not state.textCapture
end
function Stations.canBrowse(snapshot,rank,trials)
	return type(snapshot)=="table" and snapshot.status=="Ready" and type(snapshot.inventoryMask)=="number"
		and Pets.ownedCount(rank or 0,trials or 0,snapshot.inventoryMask)>0
end
function Stations.hasPending(snapshot)
	local result=type(snapshot)=="table" and snapshot.lastHatch
	return type(result)=="table" and type(result.id)=="string" and #result.id>0 and Pets.byId[result.petId]~=nil
end
function Stations.canVisitEggs(snapshot,rank,trials)
	return Stations.hasPending(snapshot) or Stations.canBrowse(snapshot,rank,trials)
end
-- Explicit menu/tree browsing shares this route. Recovery only presents an existing ID.
function Stations.visitEggs(d)
	d.cancel()
	local state=d.read()
	if not state.uiReady or not state.alive or state.busy or state.coreMenu or state.textCapture
		or not Stations.canVisitEggs(state.snapshot,state.rank,state.trials) then return false end
	if state.mode=="Room" then
		if not Stations.canRoam(state) then return false end
		d.open();return true
	end
	if state.mode~="Board" or not state.uiReady or not d.canEnterFromBoard() then return false end
	local generation=d.generation()
	local character,camera=d.identity()
	d.sendMode("Room")
	local now,wait,spawn=d.now or os.clock,d.wait or task.wait,d.spawn or task.spawn
	spawn(function()
		local deadline=now()+4
		while now()<deadline and d.generation()==generation do
			local nextCharacter,nextCamera=d.identity()
			if nextCharacter~=character or nextCamera~=camera then return end
			local current=d.read()
			if not current.uiReady or current.coreMenu or current.textCapture or not current.alive then return end
			if current.mode=="Room" and current.viewMode=="Room" and not current.busy and not current.switchQueued then
				if Stations.canRoam(current) and Stations.canVisitEggs(current.snapshot,current.rank,current.trials) then d.open()end
				return
			end
			wait(.1)
		end
	end)
	return true
end
function Stations.new(dependencies)
	local self=setmetatable({dependencies=dependencies,prompts={},records={},connections={}},Stations)
	if dependencies.triggered then
		table.insert(self.connections,dependencies.triggered:Connect(function(prompt,who)self:dispatch(prompt,who)end))
	end
	self:refresh();return self
end
function Stations:watch(signal)
	table.insert(self.connections,signal:Connect(function()self:refresh()end))
end
function Stations:eligible(prompt,state)
	local lounge=self.lounge
	local part=prompt.Parent
	local id=prompt:GetAttribute("PocketClubStation")
	return known[id]==true and Stations.canRoam(state) and lounge~=nil
		and lounge==self.dependencies.lounge() and lounge:IsDescendantOf(workspace)
		and prompt:IsDescendantOf(lounge) and part~=nil and part:IsA("BasePart") and part:IsDescendantOf(lounge)
		and (id~="Eggs" or Stations.canVisitEggs(state.snapshot,state.rank,state.trials))
end
function Stations:nearest(state)
	if not state.position or not Stations.canRoam(state) then return nil end
	return Priority.nearest(state.position,self.prompts,function(prompt)return self:eligible(prompt,state)end,true)
end
function Stations:forget(prompt)
	local record=self.records[prompt]
	if not record then return end
	if record.owned and prompt.Parent then prompt.Enabled=false end
	for _,connection in ipairs(record.connections)do connection:Disconnect()end
	self.records[prompt]=nil
	local index=table.find(self.prompts,prompt);if index then table.remove(self.prompts,index)end
end
function Stations:observe(object)
	if self.destroyed then return end
	if not object:IsA("ProximityPrompt") or self.records[object] then return end
	local record={connections={},owned=false};self.records[object]=record
	local function changed()
		if self.destroyed then return end
		local owned=known[object:GetAttribute("PocketClubStation")]==true
		if owned and not record.owned then table.insert(self.prompts,object)
		elseif record.owned and not owned then
			object.Enabled=false
			local index=table.find(self.prompts,object);if index then table.remove(self.prompts,index)end
		end
		record.owned=owned
		self:refresh()
	end
	table.insert(record.connections,object:GetAttributeChangedSignal("PocketClubStation"):Connect(changed))
	table.insert(record.connections,object.AncestryChanged:Connect(function()
		if self.lounge and object:IsDescendantOf(self.lounge) then self:refresh()end
	end))
	if known[object:GetAttribute("PocketClubStation")] then record.owned=true;table.insert(self.prompts,object)end
	-- Streamed prompts must inherit the current owner before a render frame can display them.
	self:refresh()
end
function Stations:bind(lounge)
	if self.lounge==lounge then return end
	if self.added then self.added:Disconnect();self.added=nil end
	if self.removed then self.removed:Disconnect();self.removed=nil end
	local previous={};for prompt in pairs(self.records)do table.insert(previous,prompt)end
	for _,prompt in ipairs(previous)do self:forget(prompt)end
	self.lounge=lounge;self.winner=nil
	if not lounge then return end
	self.added=lounge.DescendantAdded:Connect(function(object)self:observe(object)end)
	self.removed=lounge.DescendantRemoving:Connect(function(object)
		if self.records[object] then self:forget(object)end
	end)
	for _,object in ipairs(lounge:GetDescendants())do self:observe(object)end
end
function Stations:refresh()
	if self.destroyed then return end
	self:bind(self.dependencies.lounge())
	local state=self.dependencies.read()
	local winner=self:nearest(state)
	for _,prompt in ipairs(self.prompts)do
		prompt.Enabled=self:eligible(prompt,state) and (winner==nil or prompt==winner)
	end
	self.winner=winner
end
function Stations:inReach()
	if self.destroyed then return false end
	-- Recompute against position/ownership; a stale pet E/X cannot beat an arriving station.
	return self:nearest(self.dependencies.read())~=nil
end
function Stations:dispatch(prompt,who)
	if self.destroyed or who~=self.dependencies.player or not self.records[prompt] or not prompt.Enabled then return false end
	local state=self.dependencies.read()
	if not self:eligible(prompt,state) or self:nearest(state)~=prompt then return false end
	local route=self.dependencies.routes[prompt:GetAttribute("PocketClubStation")]
	if not route then return false end
	route();self:refresh();return true
end
function Stations:destroy()
	if self.destroyed then return end
	self:bind(nil);self.destroyed=true
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	table.clear(self.connections)
end
return Stations
