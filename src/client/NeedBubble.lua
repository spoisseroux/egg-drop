-- Onboarding v3 slice B: the need bubble over the Bear (ONBOARDING-V3-PLAN-2026-11-23 section 4 and the art table).
-- A white glossy round bubble with a tail, a 2 px ink outline, a soft gloss arc and one icon, no words. Stand-in glyphs
-- until the six script-drawn icons are uploaded (IconIds). BearNeeds decides what shows and when.
--
-- Studio QA (2026-11-23): the Bear shuttles between idle spots ~3 studs apart in its first minute, and the bubble jumped
-- ~60 px with it, so taps missed. Now:
--  * the hit area is HitSize px (over the 96 px asked for), a clear button round the 72 px bubble (the icon is unchanged);
--  * the bubble hangs on its own local anchor that follows the Bear on a spring (Bubble.follow): a move under Dead studs
--    is ignored, a bigger one is chased smoothly until it is within Settle, a jump over Snap studs (a teleport) snaps;
--  * a small key cap shows the keyboard or gamepad key (options.keyHint) that does the same as a tap.
-- The bubble is gamepad-selectable. Fades in and out, pops in with a small hop and hops on the idle hint; Reduced Motion:
-- fades only, and the anchor follows at once (still ignoring small moves).
-- options: {parent = PlayerGui, adornee() -> the pet's part or nil, onTap(), reduced() -> bool, keyHint() -> text or nil,
--   world = where the anchor part lives (default workspace)}
local Bubble={};Bubble.__index=Bubble
Bubble.Glyph=table.freeze({hand="👋",ball="🎾",deck="🎮",moon="🌙",paws="🐾",egg="🥚"})
Bubble.IconIds=table.freeze({}) -- icon = asset id, once uploaded; a glyph until then
Bubble.Size=72        -- px, the drawn bubble
Bubble.HitSize=108    -- px, the tap target round it
Bubble.Lift=2.2       -- studs over the top of the pet
Bubble.Fade=.2
Bubble.HopTime=.45;Bubble.HopHeight=.6
Bubble.Dead=2         -- studs: the Bear moving less than this leaves the bubble where it is
Bubble.Settle=.15     -- studs: a chase ends this close
Bubble.Rate=3.5       -- the spring: about 1 - e^(-Rate dt) of the way each frame
Bubble.Snap=30        -- studs: further than this is a teleport, the bubble snaps
Bubble.Ink=Color3.fromHex("#24304F")
Bubble.Shade=Color3.fromHex("#E6ECF7")

-- Pure: where the bubble hangs now. state = {at, chasing} (kept by the caller), target = over the Bear now.
function Bubble.follow(state,target,dt,reduced)
	if typeof(target)~="Vector3"then return state.at end
	local at=state.at
	if typeof(at)~="Vector3"then state.at,state.chasing=target,false;return target end
	local gap=(target-at).Magnitude
	if gap>=Bubble.Snap then state.at,state.chasing=target,false;return target end
	if not state.chasing then
		if gap<Bubble.Dead then return at end
		state.chasing=true
	end
	if reduced then state.at,state.chasing=target,false;return target end
	local step=1-math.exp(-Bubble.Rate*math.max(0,dt or 0))
	at=at:Lerp(target,step)
	if(target-at).Magnitude<=Bubble.Settle then at,state.chasing=target,false end
	state.at=at
	return at
end

function Bubble.new(options)
	options=options or {}
	local self=setmetatable({options=options,alpha=1,target=1,hopAt=nil,time=0,spot={}},Bubble)
	local anchor=Instance.new("Part")
	anchor.Name="EggDropNeedAnchor";anchor.Size=Vector3.new(.2,.2,.2);anchor.Transparency=1
	anchor.Anchored,anchor.CanCollide,anchor.CanQuery,anchor.CanTouch,anchor.CastShadow,anchor.Massless=true,false,false,false,false,true
	local gui=Instance.new("BillboardGui")
	gui.Name="EggDropNeedBubble";gui.Adornee=anchor;gui.Size=UDim2.fromOffset(Bubble.HitSize,Bubble.HitSize)
	gui.AlwaysOnTop=true;gui.Active=true;gui.LightInfluence=0;gui.ResetOnSpawn=false;gui.Enabled=false;gui.MaxDistance=140
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	-- The drawn bubble, centred in the hit area, its tail below it.
	local art=Instance.new("Frame")
	art.Name="Art";art.AnchorPoint=Vector2.new(.5,.5);art.Position=UDim2.new(.5,0,.5,-6);art.Size=UDim2.fromOffset(Bubble.Size,Bubble.Size)
	art.BackgroundColor3=Color3.new(1,1,1);art.BorderSizePixel=0;art.ZIndex=2;art.Parent=gui
	local tail=Instance.new("Frame")
	tail.Name="Tail";tail.AnchorPoint=Vector2.new(.5,.5);tail.Position=UDim2.new(.5,0,1,-3);tail.Size=UDim2.fromOffset(16,16)
	tail.Rotation=45;tail.BackgroundColor3=Color3.new(1,1,1);tail.BorderSizePixel=0;tail.ZIndex=1;tail.Parent=art
	local tailEdge=Instance.new("UIStroke");tailEdge.Color=Bubble.Ink;tailEdge.Thickness=2;tailEdge.Parent=tail
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(.5,0);corner.Parent=art
	local edge=Instance.new("UIStroke");edge.Color=Bubble.Ink;edge.Thickness=2;edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;edge.Parent=art
	local shade=Instance.new("UIGradient");shade.Rotation=90
	shade.Color=ColorSequence.new(Color3.new(1,1,1),Bubble.Shade);shade.Parent=art
	-- The gloss arc: a soft white crescent over the top left.
	local gloss=Instance.new("Frame")
	gloss.Name="Gloss";gloss.AnchorPoint=Vector2.new(.5,0);gloss.Position=UDim2.fromScale(.42,.1);gloss.Size=UDim2.fromScale(.56,.2)
	gloss.BackgroundColor3=Color3.new(1,1,1);gloss.BackgroundTransparency=.15;gloss.BorderSizePixel=0;gloss.Rotation=-18;gloss.ZIndex=3;gloss.Parent=art
	local glossCorner=Instance.new("UICorner");glossCorner.CornerRadius=UDim.new(.5,0);glossCorner.Parent=gloss
	local icon=Instance.new("TextLabel")
	icon.Name="Icon";icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.54);icon.Size=UDim2.fromScale(.6,.6)
	icon.BackgroundTransparency=1;icon.TextScaled=true;icon.Font=Enum.Font.FredokaOne;icon.TextColor3=Bubble.Ink;icon.ZIndex=4;icon.Parent=art
	local image=Instance.new("ImageLabel")
	image.Name="IconImage";image.AnchorPoint=Vector2.new(.5,.5);image.Position=UDim2.fromScale(.5,.54);image.Size=UDim2.fromScale(.64,.64)
	image.BackgroundTransparency=1;image.Visible=false;image.ZIndex=4;image.Parent=art
	-- The key cap: bottom right of the bubble, the key that does what a tap does.
	local key=Instance.new("TextLabel")
	key.Name="Key";key.AnchorPoint=Vector2.new(.5,.5);key.Position=UDim2.fromScale(.86,.86);key.Size=UDim2.fromOffset(26,22)
	key.BackgroundColor3=Bubble.Ink;key.TextColor3=Color3.new(1,1,1);key.Font=Enum.Font.GothamBold;key.TextSize=13;key.ZIndex=5
	key.BorderSizePixel=0;key.Visible=false;key.Parent=art
	local keyCorner=Instance.new("UICorner");keyCorner.CornerRadius=UDim.new(0,6);keyCorner.Parent=key
	-- The hit area: the whole billboard, clear, over everything.
	local button=Instance.new("TextButton")
	button.Name="Hit";button.Text="";button.AutoButtonColor=false;button.Selectable=true;button.Active=true;button.BackgroundTransparency=1
	button.Size=UDim2.fromScale(1,1);button.BorderSizePixel=0;button.ZIndex=10;button.Parent=gui
	button.Activated:Connect(function()
		if self.shown and self.alpha<.6 and options.onTap then options.onTap()end
	end)
	anchor.Parent=options.world or workspace
	gui.Parent=options.parent
	self.anchor,self.gui,self.button,self.art,self.tail,self.edge,self.tailEdge,self.gloss,self.icon,self.image,self.key=
		anchor,gui,button,art,tail,edge,tailEdge,gloss,icon,image,key
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
	self.art.BackgroundTransparency=a;self.tail.BackgroundTransparency=a
	self.edge.Transparency=a;self.tailEdge.Transparency=a
	self.gloss.BackgroundTransparency=.15+.85*a
	self.icon.TextTransparency=a;self.image.ImageTransparency=a
	self.key.BackgroundTransparency=a;self.key.TextTransparency=a
end
function Bubble:step(dt)
	dt=dt or 0
	self.time+=dt
	local adornee=self.options.adornee and self.options.adornee()or nil
	if self.part~=adornee then
		self.part,self.top=adornee,nil
		if adornee then
			local model=adornee:FindFirstAncestorWhichIsA("Model")
			local ok,size=pcall(function()return if model then model:GetExtentsSize()else adornee.Size end)
			self.top=if ok and typeof(size)=="Vector3"then size.Y*.5 else 1.5
		end
	end
	local reduced=self:reduced()
	if adornee then
		local at=Bubble.follow(self.spot,adornee.Position+Vector3.new(0,(self.top or 1.5)+Bubble.Lift,0),dt,reduced)
		self.anchor.CFrame=CFrame.new(at)
	end
	local fade=if reduced then 1 else dt/Bubble.Fade
	if self.alpha<self.target then self.alpha=math.min(self.target,self.alpha+fade)
	elseif self.alpha>self.target then self.alpha=math.max(self.target,self.alpha-fade)end
	local hint=self.options.keyHint and self.options.keyHint()or nil
	self.key.Visible=type(hint)=="string"and hint~=""
	if self.key.Visible then self.key.Text=hint end
	self:paint()
	local lift=0
	if self.hopAt then
		local t=(self.time-self.hopAt)/Bubble.HopTime
		if t>=1 or reduced then self.hopAt=nil else lift=math.sin(t*math.pi)*Bubble.HopHeight end
	end
	self.gui.StudsOffsetWorldSpace=Vector3.new(0,lift,0)
	self.gui.Enabled=adornee~=nil and self.alpha<1
	self.button.Active=self.shown==true
	-- Out of sight: the next showing starts over the Bear, not where it was.
	if not self.gui.Enabled then self.spot.at=nil end
end
function Bubble:destroy()self.gui:Destroy();self.anchor:Destroy()end
return Bubble
