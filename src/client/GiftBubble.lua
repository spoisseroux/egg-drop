-- The gift chain's bubble over the pet (GiftChain; ONBOARDING-FUN-PASS section 2, Onboard "gifts"). Presentation only.
-- The art is Fable's GIFT-ART-BRIEF section 1 (numbers and curves in GiftArt):
--   bubble  over the pet: a white pill, its icon the 44 px wrapped egg on glass with a 2 px pink stroke (a gift never
--           reads as a need), the headline over a sub-line (NeedBubble's two-line look) and an "x" at its top right
--           (parks it). A tap on the pill does the step.
--   ribbon  the machine draws it (GiftRibbon on the dial); ribbon(on) hands it over (options.ribbon).
-- Onboarding part 2 (ONBOARDING-P2-BRIEF 1): the chip over the pet is gone (a parked gift is the ribbon, the machine's
-- "Free egg!" prompt and the Things row). Beta (40) note 6: the bubble no longer rides the animated body part. It sits
-- on its own un-animated anchor (a client-only part), moved every RenderStepped to the pet's ground point: X and Z
-- exactly (no dead zone), Y eased so the walk's hops never shake it.
-- Reduced Motion: no hop.
-- options: {parent, adornee() -> the pet's part (fallback), origin() -> the pet's ground point (Vector3) or nil,
--   onTap(), onClose(), reduced() -> bool, text(key) -> words, hidden() -> true under a menu, card or the Deck,
--   ribbon(on)}
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GiftArt=require(Shared:WaitForChild("GiftArt"))
local Draw=require(script.Parent:WaitForChild("GiftEggArt"))
local Bubble={};Bubble.__index=Bubble
Bubble.Ink=GiftArt.color("ink");Bubble.Fill=Color3.fromHex("#FFFFFF")
Bubble.H=68;Bubble.Lift=2.4
Bubble.Icon=GiftArt.EggSizes.pill
Bubble.Height=2.6   -- studs from the pet's ground point to the body (the old adornee) before the lift
Bubble.EaseY=10     -- 1/s: how fast the height follows the ground point (the hops are filtered, a slope is not)

local node=Draw.node
local function on(signal,fn)if typeof(signal)=="RBXScriptSignal"then return signal:Connect(fn)end;return nil end
local function round(parent,r)node("UICorner",parent,{CornerRadius=r or UDim.new(.5,0)})end

-- Pure: the anchor's next height, easing from `current` toward `target` over dt (exact when there is no current).
function Bubble.easeY(current,target,dt)
	if type(current)~="number"then return target end
	local k=1-math.exp(-Bubble.EaseY*math.max(0,dt or 0))
	return current+(target-current)*k
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
	on(pill.Activated,function()if self.shown and options.onTap then options.onTap()end end)
	on(close.Activated,function()if self.shown and options.onClose then options.onClose()end end)
	self.gui,self.pill=gui,pill
	-- The un-animated anchor: a client-only part (never replicated, never hit by a ray), moved every rendered frame.
	local ok,anchor=pcall(function()
		local part=Instance.new("Part")
		part.Name="EggDropGiftBubbleAnchor";part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
		part.Transparency=1;part.Size=Vector3.new(.2,.2,.2);part.CastShadow=false
		part.Parent=workspace.CurrentCamera or workspace
		return part
	end)
	self.anchor=if ok then anchor else nil
	if RunService:IsClient()then
		self.render=RunService.RenderStepped:Connect(function(dt)pcall(self.place,self,dt)end)
	end
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
-- The machine draws the ribbon now (GiftRibbon); this only hands the state over.
function Bubble:ribbon(value)
	self.ribbonOn=value==true
	if self.options.ribbon then pcall(self.options.ribbon,self.ribbonOn)end
end
-- The chip is gone (part 2); kept as a no-op so an older caller never errors.
function Bubble:chip()end
-- The pet's ground point now: its origin when the pet gives one, else its part.
function Bubble:ground()
	local o=self.options.origin and self.options.origin()or nil
	if typeof(o)=="Vector3"then return o,true end
	local part=self.options.adornee and self.options.adornee()or nil
	if part then return part.Position,false end
	return nil
end
-- Every rendered frame: the anchor goes to the pet (X, Z exact; Y eased), so the bubble never jitters with the walk.
function Bubble:place(dt)
	local anchor=self.anchor
	if not anchor then return end
	local at,ground=self:ground()
	if not at then self.y=nil;return end
	local target=at.Y+(if ground then Bubble.Height else 1.5)
	self.y=Bubble.easeY(self.y,target,dt)
	anchor.CFrame=CFrame.new(at.X,self.y,at.Z)
end
function Bubble:step(dt)
	self.time+=dt or 0
	local at=self:ground()
	local lift=0
	if self.hopAt then
		local t=(self.time-self.hopAt)/.45
		if t>=1 then self.hopAt=nil else lift=math.sin(t*math.pi)*.6 end
	end
	local hidden=self.options.hidden~=nil and self.options.hidden()==true
	local adornee=if self.anchor then self.anchor else(self.options.adornee and self.options.adornee()or nil)
	if self.anchor and self.y==nil and at then self:place(0)end
	self.gui.Adornee=if at then adornee else nil
	self.gui.Enabled=self.shown==true and at~=nil and adornee~=nil and not hidden
	self.gui.StudsOffsetWorldSpace=Vector3.new(0,Bubble.Lift+lift,0)
end
function Bubble:destroy()
	if self.render then self.render:Disconnect();self.render=nil end
	if self.anchor then self.anchor:Destroy();self.anchor=nil end
	self.gui:Destroy()
end
return Bubble
