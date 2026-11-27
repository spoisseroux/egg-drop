-- The gift chain's pieces in the garden (GiftChain; ONBOARDING-FUN-PASS section 2, Onboard "gifts"). Presentation only:
--   bubble  over the pet: a white pill, a gift glyph, the headline over a sub-line (NeedBubble's two-line look) and an
--           "x" at its top right (parks it). A tap on the pill does the step.
--   chip    over the pet beside it: a 36 px wrapped gift; a tap starts the parked gift.
--   ribbon  over the egg machine's dial while a gift waits there; a tap starts it too.
-- Fable owns the final art (a wrapped-egg chip, the dial's ribbon); these are drawn placeholders in the bubble's palette.
-- options: {parent, adornee() -> the pet's part, machine() -> a part at the machine or nil, onTap(), onClose(), onChip(),
--   reduced() -> bool, text(key) -> words}
local Bubble={};Bubble.__index=Bubble
Bubble.Ink=Color3.fromHex("#1B2A4A");Bubble.Fill=Color3.fromHex("#FFFFFF");Bubble.Gold=Color3.fromHex("#FFD86B")
Bubble.Ribbon=Color3.fromHex("#FF7AB8")
Bubble.Glyph="🎁"
Bubble.H=68;Bubble.Chip=36;Bubble.ChipHit=52;Bubble.Lift=2.4

local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent
	return n
end
local function on(signal,fn)if typeof(signal)=="RBXScriptSignal"then return signal:Connect(fn)end;return nil end
local function round(parent,r)node("UICorner",parent,{CornerRadius=r or UDim.new(.5,0)})end
local function edge(parent)node("UIStroke",parent,{Color=Bubble.Ink,Thickness=2})end

function Bubble.new(options)
	local self=setmetatable({options=options,time=0},Bubble)
	local gui=node("BillboardGui",options.parent,{Name="EggDropGiftBubble",Size=UDim2.fromOffset(300,96),AlwaysOnTop=true,Active=true,
		LightInfluence=0,ResetOnSpawn=false,Enabled=false,MaxDistance=140,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
	local pill=node("TextButton",gui,{Name="Pill",Text="",AutoButtonColor=false,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
		Size=UDim2.fromOffset(260,Bubble.H),BackgroundColor3=Bubble.Fill,BorderSizePixel=0,Selectable=true})
	round(pill,UDim.new(0,Bubble.H/2));edge(pill)
	node("TextLabel",pill,{Name="Icon",BackgroundTransparency=1,Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(48,48),
		Text=Bubble.Glyph,TextScaled=true,Font=Enum.Font.FredokaOne,TextColor3=Bubble.Ink})
	self.head=node("TextLabel",pill,{Name="Head",BackgroundTransparency=1,Position=UDim2.new(0,64,0,10),Size=UDim2.new(1,-100,0,26),
		Font=Enum.Font.BuilderSansExtraBold,TextSize=20,TextColor3=Bubble.Ink,TextXAlignment=Enum.TextXAlignment.Left,Text=""})
	self.sub=node("TextLabel",pill,{Name="Sub",BackgroundTransparency=1,Position=UDim2.new(0,64,0,36),Size=UDim2.new(1,-100,0,18),
		Font=Enum.Font.BuilderSansBold,TextSize=14,TextColor3=Bubble.Ink,TextTransparency=.3,TextXAlignment=Enum.TextXAlignment.Left,Text=""})
	local close=node("TextButton",pill,{Name="Close",Text="×",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,4,0,-4),Size=UDim2.fromOffset(28,28),
		BackgroundColor3=Bubble.Ink,TextColor3=Bubble.Fill,Font=Enum.Font.GothamBold,TextSize=20,AutoButtonColor=true,BorderSizePixel=0,Selectable=true})
	round(close)
	self.scale=node("UIScale",pill,{Scale=1})
	on(pill.Activated,function()if self.shown and options.onTap then options.onTap()end end)
	on(close.Activated,function()if self.shown and options.onClose then options.onClose()end end)
	-- the chip
	local chip=node("BillboardGui",options.parent,{Name="EggDropGiftChip",Size=UDim2.fromOffset(Bubble.ChipHit,Bubble.ChipHit),AlwaysOnTop=true,
		Active=true,LightInfluence=0,ResetOnSpawn=false,Enabled=false,MaxDistance=140})
	local chipButton=node("TextButton",chip,{Name="Hit",Text=Bubble.Glyph,TextScaled=true,Font=Enum.Font.FredokaOne,AnchorPoint=Vector2.new(.5,.5),
		Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(Bubble.Chip,Bubble.Chip),BackgroundColor3=Bubble.Fill,AutoButtonColor=false,
		BorderSizePixel=0,Selectable=true})
	round(chipButton);edge(chipButton)
	self.chipScale=node("UIScale",chipButton,{Scale=1})
	on(chipButton.Activated,function()if self.chipOn and options.onChip then options.onChip()end end)
	-- the ribbon on the machine
	local ribbon=node("BillboardGui",options.parent,{Name="EggDropGiftRibbon",Size=UDim2.fromOffset(Bubble.ChipHit,Bubble.ChipHit),AlwaysOnTop=true,
		Active=true,LightInfluence=0,ResetOnSpawn=false,Enabled=false,MaxDistance=180,StudsOffsetWorldSpace=Vector3.new(0,1.2,0)})
	local bow=node("TextButton",ribbon,{Name="Hit",Text="🎀",TextScaled=true,Font=Enum.Font.FredokaOne,AnchorPoint=Vector2.new(.5,.5),
		Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(Bubble.Chip,Bubble.Chip),BackgroundColor3=Bubble.Ribbon,AutoButtonColor=false,
		BorderSizePixel=0,Selectable=true})
	round(bow);edge(bow)
	on(bow.Activated,function()if self.ribbonOn and options.onChip then options.onChip()end end)
	self.gui,self.pill,self.chipGui,self.ribbonGui=gui,pill,chip,ribbon
	return self
end
function Bubble:reduced()return self.options.reduced~=nil and self.options.reduced()==true end
function Bubble:set(visible,head,sub)
	self.shown=visible==true
	if self.shown then
		local text=self.options.text or function(k)return k end
		self.head.Text=text(head or "");self.sub.Text=if sub then text(sub)else ""
	end
end
function Bubble:hop()if not self:reduced()then self.hopAt=self.time end end
function Bubble:chip(value)self.chipOn=value==true end
function Bubble:ribbon(value)self.ribbonOn=value==true end
function Bubble:step(dt)
	self.time+=dt or 0
	local part=self.options.adornee and self.options.adornee()or nil
	local lift=0
	if self.hopAt then
		local t=(self.time-self.hopAt)/.45
		if t>=1 then self.hopAt=nil else lift=math.sin(t*math.pi)*.6 end
	end
	self.gui.Adornee=part
	self.gui.Enabled=self.shown==true and part~=nil
	self.gui.StudsOffsetWorldSpace=Vector3.new(0,Bubble.Lift+1.5+lift,0)
	self.chipGui.Adornee=part
	self.chipGui.Enabled=self.chipOn==true and part~=nil and not self.gui.Enabled
	self.chipGui.StudsOffsetWorldSpace=Vector3.new(0,Bubble.Lift+1.2,0)
	local pulse=if self:reduced()then 1 else 1+.075*(1-math.cos(self.time*math.pi*2/1.2))
	self.chipScale.Scale=pulse
	local machine=self.options.machine and self.options.machine()or nil
	self.ribbonGui.Adornee=machine
	self.ribbonGui.Enabled=self.ribbonOn==true and machine~=nil
end
function Bubble:destroy()
	self.gui:Destroy();self.chipGui:Destroy();self.ribbonGui:Destroy()
end
return Bubble
