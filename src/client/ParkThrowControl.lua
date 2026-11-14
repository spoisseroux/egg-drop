-- One optional Throw action. Keyboard F / gamepad R2 and the same touch button send
-- bounded intent; no aiming overlay, joins or secondary Call controls.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Copy=require(ReplicatedStorage.Shared.UICopy)
local Park=require(ReplicatedStorage.Shared.ParkLayout)
local Rail=require(script.Parent.NotificationRail)
local Control={};Control.__index=Control
function Control.new(parkClient,options)
	local self=setmetatable({park=parkClient,garden=options.garden,guiParent=options.gui,connections={},seq=0},Control)
	-- Injected fixtures need no input or PlayerGui instances.
	if options.park then self.fixture=true;return self end
	local remotes=ReplicatedStorage:FindFirstChild("Remotes")
	self.remote=remotes and remotes:FindFirstChild("GardenIntent")
	local result=remotes and remotes:FindFirstChild("ParkResult")
	local function bind(remote)
		if remote.Name=="ParkResult"and not self.resultConnection then
			self.resultConnection=remote.OnClientEvent:Connect(function(packet)
				if type(packet)~="table"or packet.kind~="parkThrow"or not self.pending or packet.seq~=self.pending.packet.seq then return end
				self.pending=nil
				self.note=Copy.get(if packet.status=="Applied"then "park.fetching"elseif packet.reason=="NoLane"then "park.fetchUnavailable"else "park.fetchWait")
				self.noteUntil=os.clock()+2
				Rail.enqueue(self.park.folder,"fetch-result",{text=self.note,duration=3.5})
			end)
		end
	end
	if result then bind(result)end
	if remotes then table.insert(self.connections,remotes.ChildAdded:Connect(bind))end
	table.insert(self.connections,Input.InputBegan:Connect(function(input,processed)
		if not processed and(input.KeyCode==Enum.KeyCode.F or input.KeyCode==Enum.KeyCode.ButtonR2)and not Input:GetFocusedTextBox()then self:throw()end
	end))
	return self
end
function Control:makeGui()
	local parent=self.guiParent or Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not parent then return false end
	local gui=Instance.new("ScreenGui");gui.Name="EggDropParkThrow";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=4;gui.Enabled=false
	local button=Instance.new("TextButton");button.Name="Throw";button.Size=UDim2.fromOffset(92,48);button.AnchorPoint=Vector2.one
	button.BackgroundColor3=Color3.fromHex("#213C42");button.BackgroundTransparency=.12;button.TextColor3=Color3.fromHex("#BBF7D0")
	button.Font=Enum.Font.FredokaOne;button.TextSize=16;button.TextWrapped=true;button.Text=Copy.get("park.throw");button.Selectable=true;button.Parent=gui
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,14);corner.Parent=button
	local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("#759D95");stroke.Transparency=.45;stroke.Parent=button
	table.insert(self.connections,button.Activated:Connect(function()self:throw()end))
	gui.Parent=parent;self.gui,self.button=gui,button
	return true
end
function Control:throw()
	if not self.enabled or self.pending or not self.remote or not self.garden then return false end
	local ownerId=self.garden.playerId
	local actor=self.garden.snapshot and self.garden.snapshot.actors[tostring(ownerId)]
	if not actor or actor.mode~="Room"or not actor.parkId or not Park.ById[actor.parkId]then return false end
	self.seq+=1
	local packet={kind="parkThrow",seq=self.seq,petId=actor.petId,characterId=actor.characterId,petGeneration=actor.petGeneration}
	self.pending={packet=packet,at=os.clock(),attempts=1};self.remote:FireServer(packet)
	return true
end
function Control:step(_,context)
	if self.fixture then return end
	context=context or {}
	local site=Park.siteAt(context.ownerPosition,self.siteId)
	self.siteId=site and site.Id or nil
	local child=site and self.park.sites[site.Id]
	local block=child and child:block()
	local fetch=block and block.fetch
	local show=context.active==true and site~=nil and fetch~=nil and(fetch.laneReady==true or fetch.ready==true or fetch.stage~="idle")
	local ownerId=self.garden and self.garden.playerId
	local available=fetch and(if type(fetch.availableOwners)=="table"then fetch.availableOwners[tostring(ownerId)]==true else fetch.ready==true)
	self.enabled=show and fetch.stage=="idle"and available==true
	if not show then
		if self.gui then self.gui.Enabled=false end
		self.pending=nil;return
	end
	if not self.gui and not self:makeGui()then return end
	self.gui.Enabled=true
	local dock=context.dockPosition or UDim2.new(1,-16,1,-16)
	self.button.Position=UDim2.new(1,-132,dock.Y.Scale,dock.Y.Offset)
	self.button.Active=self.enabled and not self.pending;self.button.AutoButtonColor=self.button.Active
	self.button.Text=Copy.get(if fetch.stage~="idle"then "park.ballOut"elseif not available then "park.waitIdle"else "park.throw")
	self.button.TextTransparency=if self.button.Active then 0 else .35
	local now=os.clock()
	if self.pending and now-self.pending.at>2 then
		if self.pending.attempts<2 then
			self.pending.attempts+=1;self.pending.at=now;self.remote:FireServer(self.pending.packet)
		else self.pending=nil;Rail.enqueue(self.park.folder,"fetch-timeout",{text=Copy.get("park.fetchWait"),duration=3.5})end
	end

end
function Control:destroy()
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	if self.resultConnection then self.resultConnection:Disconnect()end
	if self.gui then self.gui:Destroy();self.gui=nil end
	self.pending=nil;self.enabled=false
end
return Control
