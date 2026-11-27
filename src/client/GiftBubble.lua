-- The gift chain's pieces over the pet (GiftChain; ONBOARDING-FUN-PASS section 2, Onboard "gifts"). Presentation only.
-- The art is Fable's GIFT-ART-BRIEF section 1 (numbers and curves in GiftArt):
--   bubble  over the pet: a white pill, its icon the 44 px wrapped egg on glass with a 2 px pink stroke (a gift never
--           reads as a need), the headline over a sub-line (NeedBubble's two-line look) and an "x" at its top right
--           (parks it). A tap on the pill does the step.
--   chip    over the pet beside it: the wrapped egg on a 36 px glass disc (2 px ink stroke, 52 px hit). It waits, it
--           does not ask: a 3 px bob on a 2.4 s sine; every 6 s the bow wiggles once (+-10 degrees, .3 s) with one
--           glint (AeroUI.sweep). No sound, buzz, badge or number. Parking pops it 0, 1.15, 1.0 in .25 s with cup_shine
--           at .25; within 10 studs it is 1.15, beyond 60 at 60%; hidden under any menu, card or the Deck. A tap: the
--           press, the menu click and the drop buzz, then it starts the gift.
--   ribbon  the machine draws it (GiftRibbon on the dial); ribbon(on) hands it over (options.ribbon).
-- Reduced Motion: no bob, wiggle or glint.
-- options: {parent, adornee() -> the pet's part, onTap(), onClose(), onChip(), reduced() -> bool, text(key) -> words,
--   hidden() -> true under a menu, card or the Deck, distance() -> studs from the player to the pet, play(name, speed,
--   volume), haptic(name), ribbon(on)}
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GiftArt=require(Shared:WaitForChild("GiftArt"))
local Draw=require(script.Parent:WaitForChild("GiftEggArt"))
local Bubble={};Bubble.__index=Bubble
Bubble.Ink=GiftArt.color("ink");Bubble.Fill=Color3.fromHex("#FFFFFF")
Bubble.H=68;Bubble.Chip=GiftArt.Chip.size;Bubble.ChipHit=GiftArt.Chip.hit;Bubble.Lift=2.4
Bubble.Icon=GiftArt.EggSizes.pill
Bubble.Press=table.freeze({down=.94,top=1.04,seconds=.06,back=.22})

local node=Draw.node
local function on(signal,fn)if typeof(signal)=="RBXScriptSignal"then return signal:Connect(fn)end;return nil end
local function round(parent,r)node("UICorner",parent,{CornerRadius=r or UDim.new(.5,0)})end
local aero=nil
local function sweep(face)
	if aero==nil then local ok,m=pcall(require,script.Parent:WaitForChild("AeroUI"));aero=if ok then m else false end
	if aero then pcall(aero.sweep,face)end
end

function Bubble.new(options)
	local self=setmetatable({options=options,time=0},Bubble)
	local gui=node("BillboardGui",options.parent,{Name="EggDropGiftBubble",Size=UDim2.fromOffset(300,96),AlwaysOnTop=true,Active=true,
		LightInfluence=0,ResetOnSpawn=false,Enabled=false,MaxDistance=140,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
	local pill=node("TextButton",gui,{Name="Pill",Text="",AutoButtonColor=false,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
		Size=UDim2.fromOffset(260,Bubble.H),BackgroundColor3=Bubble.Fill,BorderSizePixel=0,Selectable=true})
	round(pill,UDim.new(0,Bubble.H/2));node("UIStroke",pill,{Color=Bubble.Ink,Thickness=2})
	-- the icon: the 44 px wrapped egg on glass with a pink stroke
	local icon=node("Frame",pill,{Name="Icon",AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,10,.5,0),Size=UDim2.fromOffset(Bubble.Icon+4,Bubble.Icon+4),
		BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=GiftArt.GlassTransparency,BorderSizePixel=0,ZIndex=2})
	round(icon);node("UIStroke",icon,{Color=GiftArt.color("pink"),Thickness=2})
	Draw.egg(icon,Bubble.Icon-8,nil,3)
	self.head=node("TextLabel",pill,{Name="Head",BackgroundTransparency=1,Position=UDim2.new(0,66,0,10),Size=UDim2.new(1,-102,0,26),
		Font=Enum.Font.BuilderSansExtraBold,TextSize=20,TextColor3=Bubble.Ink,TextXAlignment=Enum.TextXAlignment.Left,Text=""})
	self.sub=node("TextLabel",pill,{Name="Sub",BackgroundTransparency=1,Position=UDim2.new(0,66,0,36),Size=UDim2.new(1,-102,0,18),
		Font=Enum.Font.BuilderSansBold,TextSize=14,TextColor3=Bubble.Ink,TextTransparency=.3,TextXAlignment=Enum.TextXAlignment.Left,Text=""})
	local close=node("TextButton",pill,{Name="Close",Text="×",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,4,0,-4),Size=UDim2.fromOffset(28,28),
		BackgroundColor3=Bubble.Ink,TextColor3=Bubble.Fill,Font=Enum.Font.GothamBold,TextSize=20,AutoButtonColor=true,BorderSizePixel=0,Selectable=true})
	round(close)
	self.scale=node("UIScale",pill,{Scale=1})
	on(pill.Activated,function()if self.shown and options.onTap then options.onTap()end end)
	on(close.Activated,function()if self.shown and options.onClose then options.onClose()end end)
	-- the chip: a 52 px hit, the 36 px glass disc, the wrapped egg on it
	local C=GiftArt.Chip
	local chip=node("BillboardGui",options.parent,{Name="EggDropGiftChip",Size=UDim2.fromOffset(C.hit+16,C.hit+16),AlwaysOnTop=true,
		Active=true,LightInfluence=0,ResetOnSpawn=false,Enabled=false,MaxDistance=140})
	local hit=node("TextButton",chip,{Name="Hit",Text="",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(C.hit,C.hit),
		BackgroundTransparency=1,AutoButtonColor=false,BorderSizePixel=0,Selectable=true})
	local float=node("Frame",hit,{Name="Float",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(C.size,C.size),
		BackgroundTransparency=1,BorderSizePixel=0,Active=false})
	self.chipScale=node("UIScale",float,{Scale=1})
	local disc=node("Frame",float,{Name="Disc",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=GiftArt.GlassTransparency,
		BorderSizePixel=0,ZIndex=2,Active=false})
	round(disc);node("UIStroke",disc,{Color=Bubble.Ink,Thickness=2})
	local drawn=Draw.egg(disc,C.egg,nil,3)
	self.chipFloat,self.chipDisc,self.chipBow=float,disc,drawn.bow
	on(hit.Activated,function()
		if not self.chipOn then return end
		self.pressAt=self.time
		if options.play then pcall(options.play,"menu",1,.5)end
		if options.haptic then pcall(options.haptic,"drop")end
		if options.onChip then options.onChip()end
	end)
	self.gui,self.pill,self.chipGui=gui,pill,chip
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
function Bubble:chip(value)
	value=value==true
	if value and not self.chipOn then
		self.parkedAt=self.time
		if self.options.play then pcall(self.options.play,"cup_shine",1,GiftArt.Chip.shine)end
	end
	self.chipOn=value
end
-- The machine draws the ribbon now (GiftRibbon); this only hands the state over.
function Bubble:ribbon(value)
	self.ribbonOn=value==true
	if self.options.ribbon then pcall(self.options.ribbon,self.ribbonOn)end
end
-- The press on the chip: .94 in 60 ms, back through 1.04.
function Bubble:pressScale()
	if not self.pressAt or self:reduced()then return 1 end
	local P=Bubble.Press
	local t=self.time-self.pressAt
	if t<P.seconds then return 1-(1-P.down)*t/P.seconds end
	local u=(t-P.seconds)/P.back
	if u>=1 then self.pressAt=nil;return 1 end
	-- a damped swing back: through 1 at a third, a little over (toward P.top) after
	return 1-(1-P.down)*math.cos(u*math.pi*1.5)*(1-u)
end
function Bubble:step(dt)
	self.time+=dt or 0
	local part=self.options.adornee and self.options.adornee()or nil
	local lift=0
	if self.hopAt then
		local t=(self.time-self.hopAt)/.45
		if t>=1 then self.hopAt=nil else lift=math.sin(t*math.pi)*.6 end
	end
	local hidden=self.options.hidden~=nil and self.options.hidden()==true
	self.gui.Adornee=part
	self.gui.Enabled=self.shown==true and part~=nil and not hidden
	self.gui.StudsOffsetWorldSpace=Vector3.new(0,Bubble.Lift+1.5+lift,0)
	self.chipGui.Adornee=part
	local chipShown=self.chipOn==true and part~=nil and not self.gui.Enabled and not hidden
	self.chipGui.Enabled=chipShown
	self.chipGui.StudsOffsetWorldSpace=Vector3.new(0,Bubble.Lift+1.2,0)
	if not chipShown then return end
	local distance=self.options.distance and self.options.distance()or nil
	local reduced=self:reduced()
	local s=GiftArt.chip(self.time,if self.parkedAt then self.time-self.parkedAt else nil,distance,reduced)
	self.chipFloat.Position=UDim2.new(.5,0,.5,s.y)
	self.chipScale.Scale=s.scale*self:pressScale()
	self.chipBow.Rotation=s.bow
	if s.alpha~=self.chipAlpha then self.chipAlpha=s.alpha;Draw.fade(self.chipFloat,s.alpha)end
	if s.cycle>0 and s.cycle~=self.glintCycle then sweep(self.chipDisc)end
	self.glintCycle=s.cycle
end
function Bubble:destroy()
	self.gui:Destroy();self.chipGui:Destroy()
end
return Bubble
