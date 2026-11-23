-- Onboarding v3 slice B: the need bubble over the Bear (ONBOARDING-V3-PLAN-2026-11-23 section 4 and the art table).
-- A white glossy round bubble with a tail, a 2 px ink outline, a soft gloss arc and one icon, no words. Stand-in glyphs
-- until the six script-drawn icons are uploaded (IconIds). One BillboardGui in PlayerGui, adorned to my pet; the whole
-- bubble is one button (72 px, over the 44 px phone minimum) and gamepad-selectable. It fades in and out, pops in with a
-- small hop and hops on the idle hint; Reduced Motion: fades only. BearNeeds decides what shows and when.
-- options: {parent = PlayerGui, adornee() -> the pet's part or nil, onTap(), reduced() -> bool}
local Bubble={};Bubble.__index=Bubble
Bubble.Glyph=table.freeze({hand="👋",ball="🎾",deck="🎮",moon="🌙",paws="🐾",egg="🥚"})
Bubble.IconIds=table.freeze({}) -- icon = asset id, once uploaded; a glyph until then
Bubble.Size=72        -- px, the tap target
Bubble.Lift=2.2       -- studs over the top of the pet
Bubble.Fade=.2
Bubble.HopTime=.45;Bubble.HopHeight=.6
Bubble.Ink=Color3.fromHex("#24304F")
Bubble.Shade=Color3.fromHex("#E6ECF7")

function Bubble.new(options)
	options=options or {}
	local self=setmetatable({options=options,alpha=1,target=1,hopAt=nil,time=0},Bubble)
	local gui=Instance.new("BillboardGui")
	gui.Name="EggDropNeedBubble";gui.Size=UDim2.fromOffset(Bubble.Size,Bubble.Size+14);gui.AlwaysOnTop=true;gui.Active=true
	gui.LightInfluence=0;gui.ResetOnSpawn=false;gui.Enabled=false;gui.MaxDistance=140;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	local tail=Instance.new("Frame")
	tail.Name="Tail";tail.AnchorPoint=Vector2.new(.5,.5);tail.Position=UDim2.new(.5,0,0,Bubble.Size-3);tail.Size=UDim2.fromOffset(16,16)
	tail.Rotation=45;tail.BackgroundColor3=Color3.new(1,1,1);tail.BorderSizePixel=0;tail.ZIndex=1;tail.Parent=gui
	local tailEdge=Instance.new("UIStroke");tailEdge.Color=Bubble.Ink;tailEdge.Thickness=2;tailEdge.Parent=tail
	local button=Instance.new("TextButton")
	button.Name="Bubble";button.Text="";button.AutoButtonColor=false;button.Selectable=true;button.Active=true
	button.Size=UDim2.fromOffset(Bubble.Size,Bubble.Size);button.BackgroundColor3=Color3.new(1,1,1);button.BorderSizePixel=0;button.ZIndex=2
	button.Parent=gui
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=button
	local edge=Instance.new("UIStroke");edge.Color=Bubble.Ink;edge.Thickness=2;edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;edge.Parent=button
	local shade=Instance.new("UIGradient");shade.Rotation=90
	shade.Color=ColorSequence.new(Color3.new(1,1,1),Bubble.Shade);shade.Parent=button
	-- The gloss arc: a soft white crescent over the top left.
	local gloss=Instance.new("Frame")
	gloss.Name="Gloss";gloss.AnchorPoint=Vector2.new(.5,0);gloss.Position=UDim2.fromScale(.42,.1);gloss.Size=UDim2.fromScale(.56,.2)
	gloss.BackgroundColor3=Color3.new(1,1,1);gloss.BackgroundTransparency=.15;gloss.BorderSizePixel=0;gloss.Rotation=-18;gloss.ZIndex=3;gloss.Parent=button
	local glossCorner=Instance.new("UICorner");glossCorner.CornerRadius=UDim.new(.5,0);glossCorner.Parent=gloss
	local icon=Instance.new("TextLabel")
	icon.Name="Icon";icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.54);icon.Size=UDim2.fromScale(.6,.6)
	icon.BackgroundTransparency=1;icon.TextScaled=true;icon.Font=Enum.Font.FredokaOne;icon.TextColor3=Bubble.Ink;icon.ZIndex=4;icon.Parent=button
	local image=Instance.new("ImageLabel")
	image.Name="IconImage";image.AnchorPoint=Vector2.new(.5,.5);image.Position=UDim2.fromScale(.5,.54);image.Size=UDim2.fromScale(.64,.64)
	image.BackgroundTransparency=1;image.Visible=false;image.ZIndex=4;image.Parent=button
	button.Activated:Connect(function()
		if self.shown and self.alpha<.6 and options.onTap then options.onTap()end
	end)
	gui.Parent=options.parent
	self.gui,self.button,self.tail,self.edge,self.tailEdge,self.gloss,self.icon,self.image=gui,button,tail,edge,tailEdge,gloss,icon,image
	return self
end
function Bubble:reduced()return self.options.reduced~=nil and self.options.reduced()==true end
-- Show `icon` (a Glyph key), or hide (visible false).
function Bubble:set(icon,visible)
	if visible and icon then
		local id=Bubble.IconIds[icon]
		self.image.Visible=id~=nil
		if id then self.image.Image="rbxassetid://"..id end
		self.icon.Text=if id then "" else Bubble.Glyph[icon]or "?"
		self.icon.Visible=id==nil
		if not self.shown then self:hop()end
		self.shown,self.kind,self.target=true,icon,0
		self.gui:SetAttribute("Need",icon)
	else
		self.shown,self.target=false,1
		self.gui:SetAttribute("Need",nil)
	end
end
function Bubble:hop()
	if not self:reduced()then self.hopAt=self.time end
end
function Bubble:paint()
	local a=self.alpha
	self.button.BackgroundTransparency=a;self.tail.BackgroundTransparency=a
	self.edge.Transparency=a;self.tailEdge.Transparency=a
	self.gloss.BackgroundTransparency=.15+.85*a
	self.icon.TextTransparency=a;self.image.ImageTransparency=a
end
function Bubble:step(dt)
	dt=dt or 0
	self.time+=dt
	local adornee=self.options.adornee and self.options.adornee()or nil
	if self.gui.Adornee~=adornee then
		self.gui.Adornee=adornee
		self.top=nil
		if adornee then
			local model=adornee:FindFirstAncestorWhichIsA("Model")
			local ok,size=pcall(function()return if model then model:GetExtentsSize()else adornee.Size end)
			self.top=if ok and typeof(size)=="Vector3"then size.Y*.5 else 1.5
		end
	end
	local step=if self:reduced()then 1 else dt/Bubble.Fade
	if self.alpha<self.target then self.alpha=math.min(self.target,self.alpha+step)
	elseif self.alpha>self.target then self.alpha=math.max(self.target,self.alpha-step)end
	self:paint()
	local lift=0
	if self.hopAt then
		local t=(self.time-self.hopAt)/Bubble.HopTime
		if t>=1 or self:reduced()then self.hopAt=nil else lift=math.sin(t*math.pi)*Bubble.HopHeight end
	end
	self.gui.StudsOffsetWorldSpace=Vector3.new(0,(self.top or 1.5)+Bubble.Lift+lift,0)
	self.gui.Enabled=adornee~=nil and self.alpha<1
	self.button.Active=self.shown==true
end
function Bubble:destroy()self.gui:Destroy()end
return Bubble
