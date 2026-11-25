-- The Play Den on this client, step A (PLAY-DEN-BUILD-PLAN.md, architect verdict applied). mount() answers nil with the
-- build ceiling off (live). It follows `Den_open` (DenHost writes it once the room is really open), never the switch:
-- with it missing nothing here exists and the meadow keeps today's flow.
--   * Three prompts on local invisible anchors at DenLayout.prompts (never on the server's parts, so nothing waits for
--     the model): the Garden Dash gate (today's mode picker, DashClient:gate; "Leave line" held while waiting in the
--     den), the Pocket Deck table (deps.deck(): the Deck button's own path) and the notice board (deps.things(): the
--     Things to do page). One E at a time (Exclusivity OnePerButton, 6 studs), E / ButtonX like the race gate.
--   * The sign's name: a SurfaceGui on the server's sign part, once it is there.
-- deps: dash() -> DashClient?, deck(), things(), free() -> bool (the garden is free: Room mode, can roam, no modal),
-- thingsOn() -> bool. Specs may replace world, heartbeat, layout() -> layout, isOpen() -> bool, lounge() -> Model?.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local PlayDen=require(Shared:WaitForChild("PlayDen"))
local Layout=require(Shared:WaitForChild("DenLayout"))
local UICopy=require(Shared:WaitForChild("UICopy"))
local Client={};Client.__index=Client
Client.Folder="EggDropDenPrompts"
Client.Reach=6
Client.Every=.25
Client.LeaveHold=.4

function Client.mount(d)
	if not PlayDen.ceiling()then return nil end
	local self=setmetatable({d=d,isOpen=false,wait=0,prompts={}},Client)
	self.world=d.world or workspace
	self.openNow=d.isOpen or PlayDen.isOpen
	self.changed=(d.changed or PlayDen.changed())
	self.connections={self.changed:Connect(function()self:sync()end),
		(d.heartbeat or game:GetService("RunService").Heartbeat):Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok and not self.warned then self.warned=true;warn("[Den] client: "..tostring(problem))end
		end)}
	self:sync()
	return self
end
function Client:sync()
	local on=self.openNow()==true
	if on==self.isOpen then return end
	if on then
		local ok,problem=pcall(self.open,self)
		if not ok then warn("[Den] not opened: "..tostring(problem));pcall(self.close,self)end
	else pcall(self.close,self)end
end
function Client:open()
	local layout=(self.d.layout or Layout.current)()
	if not layout then return end
	self.layout=layout
	local folder=Instance.new("Folder")
	folder.Name=Client.Folder
	local spots=Layout.prompts(layout)
	local function prompt(id,at,object,action)
		if typeof(at)~="Vector3"then return end
		local anchor=Instance.new("Part")
		anchor.Name="Den_"..id
		anchor.Size=Vector3.new(.2,.2,.2);anchor.CFrame=CFrame.new(at)
		anchor.Anchored,anchor.CanCollide,anchor.CanQuery,anchor.CanTouch=true,false,false,false
		anchor.Transparency,anchor.CastShadow=1,false
		anchor.Parent=folder
		local p=Instance.new("ProximityPrompt")
		p.Name="DenPrompt";p.ObjectText=UICopy.get(object);p.ActionText=UICopy.get(action)
		p.KeyboardKeyCode,p.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
		p.RequiresLineOfSight=false;p.HoldDuration=0;p.MaxActivationDistance=Client.Reach;p.Enabled=false
		pcall(function()p.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton end)
		p:SetAttribute("DenPrompt",id)
		p.Parent=anchor
		table.insert(self.connections,p.Triggered:Connect(function()
			local ok,problem=pcall(self.use,self,id)
			if not ok then warn("[Den] "..id..": "..tostring(problem))end
		end))
		self.prompts[id]=p
	end
	prompt("gate",spots.gate,"dash.title","dash.prompt")
	prompt("deck",spots.deck,"den.table","things.play")
	prompt("board",spots.board,"den.board","things.title")
	folder.Parent=self.world
	self.folder=folder
	self.isOpen=true
	self:refresh()
end
function Client:close()
	self.isOpen=false
	for id,p in pairs(self.prompts)do self.prompts[id]=nil;pcall(function()p.Enabled=false end)end
	if self.folder then self.folder:Destroy();self.folder=nil end
	if self.signGui then pcall(function()self.signGui:Destroy()end);self.signGui=nil end
	self.layout=nil
end
function Client:destroy()
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	table.clear(self.connections)
	self:close()
end

-- Pure: each prompt's state. ctx: free, thingsOn, dash = nil | {open, held, panel, waiting, anchor}.
-- Returns {gate = {enabled, text key, hold}, deck = {enabled}, board = {enabled}}.
function Client.state(ctx)
	local dash=ctx.dash
	local free=ctx.free==true
	local held=dash~=nil and dash.held==true
	local gate={enabled=false,text="dash.prompt",hold=0}
	if dash and dash.open then
		if dash.waiting then
			gate.text,gate.hold="dash.line.prompt",Client.LeaveHold
			gate.enabled=free and not held and dash.anchor=="den"
		else gate.enabled=free and not held and not dash.panel end
	end
	return{gate=gate,deck={enabled=free and not held},board={enabled=free and not held and ctx.thingsOn==true}}
end
function Client:context()
	local dash=self.d.dash and self.d.dash()
	local info=nil
	if dash and dash.isOpen and not dash.dead then
		info={open=true,held=dash:held(),panel=dash:panelOpen(),waiting=dash:waiting()~=nil,anchor=dash:waitAnchor()}
	end
	return{free=self.d.free()==true,thingsOn=self.d.thingsOn and self.d.thingsOn()==true,dash=info}
end
function Client:refresh()
	local s=Client.state(self:context())
	local gate=self.prompts.gate
	if gate then
		local text=UICopy.get(s.gate.text)
		if gate.ActionText~=text then gate.ActionText=text end
		if gate.HoldDuration~=s.gate.hold then gate.HoldDuration=s.gate.hold end
		if gate.Enabled~=s.gate.enabled then gate.Enabled=s.gate.enabled end
	end
	for _,id in ipairs({"deck","board"})do
		local p=self.prompts[id]
		if p and p.Enabled~=s[id].enabled then p.Enabled=s[id].enabled end
	end
	self:sign()
end
-- The sign's name, once the server's sign part has arrived.
function Client:sign()
	if self.signGui and self.signGui.Parent then return end
	local lounge=if self.d.lounge then self.d.lounge()else self.world:FindFirstChild("EggDropLounge")
	local model=lounge and lounge:FindFirstChild(PlayDen.Model)
	local part=model and model:FindFirstChild("W7D_Sign")
	if not part then return end
	local gui=Instance.new("SurfaceGui")
	gui.Name="DenSign";gui.Face=Enum.NormalId.Front;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=40
	gui.LightInfluence=1
	local label=Instance.new("TextLabel")
	label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1);label.TextScaled=true
	label.Font=Enum.Font.FredokaOne;label.TextColor3=Color3.fromHex("#F3E6C8");label.Text=UICopy.get("den.name")
	local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(.06,0);pad.PaddingRight=UDim.new(.06,0)
	pad.PaddingTop=UDim.new(.12,0);pad.PaddingBottom=UDim.new(.12,0);pad.Parent=label
	label.Parent=gui
	gui.Parent=part
	self.signGui=gui
end
function Client:step(dt)
	self:sync()
	if not self.isOpen then return end
	self.wait-=dt
	if self.wait>0 then return end
	self.wait=Client.Every
	self:refresh()
end
function Client:use(id)
	local s=Client.state(self:context())
	if not s[id]or not s[id].enabled then return end
	if id=="gate"then
		local dash=self.d.dash and self.d.dash()
		if dash then dash:gate()end
	elseif id=="deck"then self.d.deck()
	elseif id=="board"then self.d.things()end
end
return Client
