-- One optional Throw action. Keyboard F / gamepad R2 and the same touch button send
-- bounded intent; no aiming overlay, joins or secondary Call controls.
-- QA v735 W2: the same gui carries the park counter ("Pets playing 3/9", "Park full · 9/9").
-- Both stack above the Menu + Deck dock; the Throw button shows only while it can be pressed
-- or the ball is out, and the counter says the rest.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Copy=require(ReplicatedStorage.Shared.UICopy)
local Park=require(ReplicatedStorage.Shared.ParkLayout)
local Rail=require(script.Parent.NotificationRail)
local Counter=require(script.Parent.ParkCounter)
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
				Rail.enqueue(self.park.folder,"fetch-result",{text=self.note,duration=5})
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
	local button=Instance.new("TextButton");button.Name="Throw";button.Size=UDim2.fromOffset(104,Counter.ThrowHeight);button.AnchorPoint=Vector2.one
	button.BackgroundColor3=Color3.fromHex("#213C42");button.BackgroundTransparency=.12;button.TextColor3=Color3.fromHex("#BBF7D0")
	button.Font=Enum.Font.FredokaOne;button.TextSize=16;button.TextWrapped=true;button.Text=Copy.get("park.throw");button.Selectable=true;button.Parent=gui
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,14);corner.Parent=button
	local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromHex("#759D95");stroke.Transparency=.45;stroke.Parent=button
	table.insert(self.connections,button.Activated:Connect(function()self:throw()end))
	local count=Instance.new("TextLabel");count.Name="ParkCount";count.AnchorPoint=Vector2.one;count.Size=UDim2.fromOffset(0,Counter.LineHeight);count.AutomaticSize=Enum.AutomaticSize.X
	count.BackgroundColor3=button.BackgroundColor3;count.BackgroundTransparency=.12;count.TextColor3=Color3.fromHex("#E6F4EE")
	count.Font=Enum.Font.GothamMedium;count.TextSize=14;count.LineHeight=1.05;count.Text="";count.Visible=false;count.Parent=gui
	corner:Clone().Parent=count;stroke:Clone().Parent=count
	local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,Counter.Pad);pad.PaddingRight=UDim.new(0,Counter.Pad);pad.Parent=count
	gui.Parent=parent;self.gui,self.button,self.count=gui,button,count
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
	local inPark=context.active==true and site~=nil
	local ownerId=self.garden and self.garden.playerId
	local available=fetch and(if type(fetch.availableOwners)=="table"then fetch.availableOwners[tostring(ownerId)]==true else fetch.ready==true)
	-- The button is for throwing (or says the ball is out). While the pets are busy the counter speaks.
	local show=inPark and fetch~=nil and(fetch.stage~="idle"or available==true)
	self.enabled=show and fetch.stage=="idle"and available==true
	if not show then self.pending=nil end
	if not inPark then
		if self.gui then self.gui.Enabled=false end
		return
	end
	if not self.gui and not self:makeGui()then return end
	self.gui.Enabled=true
	local snapshot=self.garden and self.garden.snapshot
	-- Spencer, beta (25): "theres no pets playing bubble thing anymore?" The always-on count is back (the egg
	-- chip it hid behind lives in the top rail since beta (17)), so `quiet` is no longer passed.
	local status=Counter.status(snapshot and snapshot.actors,site,Park.Sites,false)
	local throwAt,countAt,height=Counter.layout(context.dockPosition or UDim2.new(1,-16,1,-16),show,status.lines)
	if status.text==nil then
		self.count.Visible=false
	else
		if self.count.Text~=status.text then
			self.count.Text=status.text;self.count.Size=UDim2.fromOffset(0,height)
			self.count.TextColor3=Color3.fromHex(if status.full then "#FDE68A"else "#E6F4EE")
		end
		self.count.Position=countAt;self.count.Visible=true
	end
	self.button.Visible=show
	if not show then return end
	self.button.Position=throwAt
	self.button.Active=self.enabled and not self.pending;self.button.AutoButtonColor=self.button.Active
	self.button.Text=Copy.get(if fetch.stage~="idle"then "park.ballOut"else "park.throw")
	self.button.TextTransparency=if self.button.Active then 0 else .35
	local now=os.clock()
	if self.pending and now-self.pending.at>2 then
		if self.pending.attempts<2 then
			self.pending.attempts+=1;self.pending.at=now;self.remote:FireServer(self.pending.packet)
		else self.pending=nil;Rail.enqueue(self.park.folder,"fetch-timeout",{text=Copy.get("park.fetchWait"),duration=5})end
	end

end
function Control:destroy()
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	if self.resultConnection then self.resultConnection:Disconnect()end
	if self.gui then self.gui:Destroy();self.gui=nil end
	self.pending=nil;self.enabled=false
end
return Control
