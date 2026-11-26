-- Onboarding v2 step 1 (Onboard "egg3d", ONBOARDING-V2.md; Spencer: "maybe make the egg on the pocket deck 3d and
-- spinning?"). The Welcome round's calm deck: the left card says one thing at a time (no GOALS tab, one centred line,
-- three shell pips under it) and the right card is the real Companion Egg in 3D (EggPreview3D's shell meshes), full
-- card height, spinning. Each combo the spark lands, a fill chime, the egg hops, wobbles, turns once and is lit a little
-- brighter and a pip fills; combo 3 lifts it out of the card in a rising light. Beta (36), Spencer: no big shiny circle
-- and no cracks here ("we're gonna be cracking it ourselves in 3d"): the egg only cracks in the world (step 3).
-- Presentation only (WelcomePresentation owns it; the server counts the combos and grants the Bear). Built in code; the
-- 3D shell is the one Hatch eggs shows. Until its meshes are in, `ready()` is false and the pixel egg stays.
--   local egg=WelcomeEgg3D.new(meterWell, coachCard, {copy, play(cue, speed, gain), haptic(name), reduced()})
--   egg:update({active, combos, drops}) ; egg:destroy()
local RunService=game:GetService("RunService")
local V2=require(script.Parent.OnboardV2)
local Egg={};Egg.__index=Egg
local D=V2.Deck

local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent;return n
end
local function round(n)node("UICorner",n,{CornerRadius=UDim.new(.5,0)})end

function Egg.new(meter,coach,deps)
	deps=deps or {}
	local self=setmetatable({meter=meter,coach=coach,d=deps,clock=0,combos=0,shown=false,pops={},alive=true},Egg)
	local z=meter.ZIndex+5
	-- The egg card: an 8 px inset well, a soft backing, the viewport, the pips at its foot.
	local well=node("Frame",meter,{Name="WelcomeEgg3D",BackgroundTransparency=1,Position=UDim2.fromOffset(D.pad,D.pad),
		Size=UDim2.new(1,-D.pad*2,1,-D.pad*2-D.pip-D.pad),ZIndex=z,Visible=false,Active=false})
	self.well=well
	-- Beta (36), Spencer: "we dont need that giant shiny circle"; Fable: no disc at all. The egg itself is lit a little
	-- brighter each combo (the viewport's light). No crack on the deck: the egg cracks in the world (step 3).
	local ok,preview=pcall(function()
		local Preview=require(script.Parent.EggPreview3D)
		return Preview.new(well,{reduced=function()return self:reduced()end,
			onLoaded=function()if self.alive then self:paint()end end})
	end)
	if ok and preview then
		self.preview=preview;pcall(function()preview:setType("companion",true)end)
		self.ambient,self.lightColor=preview.viewport.Ambient,preview.viewport.LightColor
		-- Fable B37 1b: preload the shell's map with the egg hidden (at most D.preloadCap s), then fade it in
		self.createdAt=os.clock()
		task.spawn(function()
			pcall(function()
				local map=V2.closedMap()or require(game:GetService("ReplicatedStorage").Shared.EggModels).Types.companion.colorMap
				game:GetService("ContentProvider"):PreloadAsync({map})
			end)
			if self.alive and not self.preloadedAt then self.preloadedAt=os.clock()end
		end)
	end
	-- The pips: 22 px shells, empty (navy, a light ring) or filled (gold).
	self.pipRow=node("Frame",meter,{Name="ComboPips3D",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-D.pad),
		Size=UDim2.fromOffset(D.pip*3+D.pipGap*2,D.pip),BackgroundTransparency=1,ZIndex=z+1,Visible=false})
	self.pips={}
	for i=1,3 do
		local pip=node("Frame",self.pipRow,{Name="Pip"..i,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset((i-1)*(D.pip+D.pipGap)+D.pip/2,D.pip/2),
			Size=UDim2.fromOffset(D.pip,D.pip*1.18),BackgroundColor3=D.pipEmpty,BorderSizePixel=0,ZIndex=z+2})
		round(pip)
		local ring=node("UIStroke",pip,{Color=D.pipRing,Thickness=2})
		local scale=node("UIScale",pip,{Scale=1})
		self.pips[i]={frame=pip,ring=ring,scale=scale}
	end
	-- The instruction: over the left card's GOALS tab and its line (one centred line, 18 to 34 px, white on the card's
	-- navy); the card's Skip tutorial well draws above it (ZIndex 30).
	if coach then
		local cover=node("Frame",coach,{Name="WelcomeInstruction",BorderSizePixel=0,Position=UDim2.fromOffset(2,2),Size=UDim2.new(1,-4,1,-4),
			BackgroundColor3=coach.BackgroundColor3,ZIndex=29,Visible=false,Active=false})
		local corner=coach:FindFirstChildOfClass("UICorner")
		node("UICorner",cover,{CornerRadius=if corner then corner.CornerRadius else UDim.new(0,10)})
		local label=node("TextLabel",cover,{Name="Line",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,-28),
			Size=UDim2.new(1,-20,.5,0),Text="",TextColor3=D.ink,TextScaled=true,TextWrapped=true,Font=Enum.Font.BuilderSansBold,
			TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=30})
		node("UITextSizeConstraint",label,{MinTextSize=D.textMin,MaxTextSize=D.textMax})
		self.cover,self.line=cover,label
	end
	return self
end
function Egg:reduced()
	if self.d.reduced then return self.d.reduced()==true end
	return false
end
-- The 3D egg is drawn (its meshes and texture are in). Until then WelcomePresentation keeps the pixel egg.
function Egg:ready()return self.preview~=nil and self.preview.loaded==true and self:revealAt()~=nil end
-- When the 3D egg may show: its map preloaded, or D.preloadCap s after it was made.
function Egg:revealAt()
	if self.preloadedAt then return self.preloadedAt end
	if self.createdAt and os.clock()-self.createdAt>=D.preloadCap then self.preloadedAt=self.createdAt+D.preloadCap;return self.preloadedAt end
	return nil
end
-- Combo n's sound: a rising fill chime and a soft buzz (beta 36: never a crack here; it cracks in the world).
function Egg:play(n)
	local C=V2.ComboChime
	if self.d.play then pcall(self.d.play,C.cue,C.pitches[n]or 1,C.gain)end
	pcall(function()require(script.Parent.Haptics).play(C.haptic)end)
end
-- s: {active (the calm Welcome combo round is up), combos, drops}.
function Egg:update(s)
	if not self.alive then return end
	s=s or {}
	local combos=math.clamp(math.floor(tonumber(s.combos)or 0),0,3)
	-- The Bear is granted on combo 3; a snapshot may say so before it shows the third combo: finish the count.
	if s.granted and self.shown and s.active~=true then combos=3 end
	if combos>self.combos then
		for n=self.combos+1,combos do
			self.beatAt=self.clock
			self.pops[n]=self.clock
			self:play(n)
		end
		if combos>=3 and not self.finaleAt then self.finaleAt=self.clock end
	elseif combos<self.combos and s.active then
		-- a new Welcome round (rejoin, replayed save): start over
		self.finaleAt,self.beatAt=nil,nil;table.clear(self.pops)
	end
	-- after the round (the Bear granted) the count is kept for the finale
	self.combos=if s.active then combos else math.max(self.combos,combos)
	self.drops=s.drops or 0
	-- Shown while the round is up, and through combo 3's finale after it ends (the Bear is granted that moment).
	local finaleLeft=self.finaleAt~=nil and self.clock-self.finaleAt<D.finale
	local show=(s.active==true and not(self.finaleAt and not finaleLeft))or(self.shown and finaleLeft)
	self:setShown(show)
	self:paint()
end
function Egg:setShown(on)
	on=on==true
	if on==self.shown then return end
	self.shown=on
	self.well.Visible=on;self.pipRow.Visible=on
	if self.cover then self.cover.Visible=on end
	if on and not self.link then
		self.link=RunService.Heartbeat:Connect(function(dt)self:step(dt)end)
	elseif not on and self.link then self.link:Disconnect();self.link=nil end
end
function Egg:step(dt)
	if not self.alive then return end
	self.clock+=math.clamp(dt or 0,0,.1)
	if self.finaleAt and self.clock-self.finaleAt>=D.finale and self.shown then
		-- the finale is over: stay hidden until a new round
		self:setShown(false)
		return
	end
	self:paint()
end
function Egg:paint()
	if not self.alive then return end
	local reduced=self:reduced()
	if self.cover then
		local copy=self.d.copy or function(key)return key end
		local key=V2.deckLine(self.drops,self.combos)
		local ok,text=pcall(copy,key)
		self.line.Text=if ok and type(text)=="string"then text else ""
		if self.coach then self.cover.BackgroundColor3=self.coach.BackgroundColor3 end
	end
	for i,pip in ipairs(self.pips)do
		local filled=V2.pip(i,self.combos)=="filled"
		pip.frame.BackgroundColor3=if filled then D.pipFilled else D.pipEmpty
		pip.ring.Color=if filled then D.pipFilled else D.pipRing
		pip.scale.Scale=if reduced then 1 else V2.pipScale(self.pops[i]and self.clock-self.pops[i]or nil)
	end
	local preview=self.preview
	if not preview or not preview.geo then return end
	local beat=if self.beatAt then self.clock-self.beatAt else nil
	local yaw,tilt,hop=V2.eggPose(self.clock,beat,reduced)
	-- the egg's own light: a little brighter each combo, a brief flare on the hop, the finale's rise
	local light,lift,fade=V2.glow(self.combos),0,0
	if beat and beat<D.wobbleTime and not reduced then light+=D.lightFlare*(1-beat/D.wobbleTime)end
	if self.finaleAt then light,lift,fade=V2.finale(self.clock-self.finaleAt,reduced)end
	local studs=1.834 -- the preview camera's frame height in studs (EggPreview3D:measure)
	pcall(function()preview:pose(math.rad(yaw),tilt,(hop+lift)*studs,1,0,0,0,fade,1)end)
	-- hidden until its map is in, then a 150 ms fade in (Reduced Motion: at once)
	local shownAt=self:revealAt()
	local reveal=if not shownAt then 0 elseif reduced then 1 else math.clamp((os.clock()-shownAt)/D.fadeIn,0,1)
	preview.viewport.ImageTransparency=math.max(fade,1-reveal)
	if self.ambient then
		preview.viewport.Ambient=V2.lift(self.ambient,light)
		preview.viewport.LightColor=V2.lift(self.lightColor,light*.5)
	end
	-- Beta (36) / Fable: none of the preview's own shine (its bloom disc, sheen, specular, sparkles, peek light) and no
	-- Neon core on the deck; the closed egg's map (no zig-zag) once it is uploaded (V2.closedMap).
	for _,d in ipairs(preview.bloom or {})do d.Visible=false end
	for _,key in ipairs({"sheenClip","glow","crack","white"})do local f=preview[key];if f then f.Visible=false end end
	for _,s in ipairs(preview.sparkles or {})do s.holder.Visible=false end
	local parts=preview.parts or {}
	if parts.Core then parts.Core.Transparency=1 end
	-- a cream base under the map, so a frame without it is never grey (Fable B37 1b)
	for _,key in ipairs({"TopShell","BottomShell"})do local p=parts[key];if p and p.Color~=D.base then p.Color=D.base end end
	local closed=V2.closedMap()
	if closed then
		for _,key in ipairs({"TopShell","BottomShell"})do local p=parts[key];if p and p.TextureID~=closed then p.TextureID=closed end end
	end
end
function Egg:destroy()
	if not self.alive then return end
	self.alive=false
	if self.link then self.link:Disconnect();self.link=nil end
	if self.preview then pcall(function()self.preview:destroy()end)end
	self.well:Destroy();self.pipRow:Destroy()
	if self.cover then self.cover:Destroy()end
end
return Egg
