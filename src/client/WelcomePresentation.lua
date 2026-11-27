-- Procedural Welcome art only; never grants progress or fabricates player input.
-- hosts={meter,gesture,skip}; each must be an existing free well. No modal.
local Progress=require(game:GetService("ReplicatedStorage").Shared.WelcomeProgress)
local V2=require(script.Parent.OnboardV2)
local View={};View.__index=View
local CREAM=Color3.fromHex("#FFF0D2")
local MINT=Color3.fromHex("#94DFB7")
local INK=Color3.fromHex("#24313B")
local PILL=Color3.fromHex("#2F404C")
-- The First Hatch (Fable, can wait): the deck egg wears the reveal egg's look (blue spots, a lime band), so it is
-- the same egg that hatches.
local SPOT=Color3.fromHex("#3E5BE0")
local BAND=Color3.fromHex("#A6D53A")
local function node(class,parent,name,properties)
	local n=Instance.new(class);n.Name=name
	for key,value in pairs(properties or {})do n[key]=value end
	n.Parent=parent;return n
end
local function frame(parent,name,pos,size,color,z)
	return node("Frame",parent,name,{Position=pos,Size=size,BackgroundColor3=color,BorderSizePixel=0,
		Active=false,Selectable=false,ZIndex=z or parent.ZIndex+1})
end
local function round(n,radius)node("UICorner",n,"Round",{CornerRadius=UDim.new(radius or .5,0)})end
local function stroke(parent,name,points,z)
	local root=frame(parent,name,UDim2.fromScale(0,0),UDim2.fromScale(1,1),INK,z);root.BackgroundTransparency=1
	for i=1,#points-1 do
		local p,q=points[i],points[i+1];local dx,dy=q[1]-p[1],q[2]-p[2]
		local line=frame(root,"Line"..i,UDim2.fromScale((p[1]+q[1])/2,(p[2]+q[2])/2),UDim2.new(math.sqrt(dx*dx+dy*dy),0,0,2),INK,z+1)
		line.AnchorPoint=Vector2.new(.5,.5);line.Rotation=math.deg(math.atan2(dy,dx));round(line)
	end
	return root
end
-- Fit never escapes its well. A well smaller than the 8px inset is reported,
-- rather than overlapping field controls or inventing another screen region.
-- The First Hatch (Fable MUST 4): the shell is about .77 of its square frame wide, so the frame may run 1.2 times
-- the well's width (the shell then fills about 90% of it); the height keeps its 8 px inset.
function View.fit(width,height)
	local side=math.max(0,math.min(width*1.2-8,height-16))
	return side,(width-side)/2,(height-side)/2
end
-- The First Hatch (Onboard "opener", artifacts/onboarding-2026-11-26/PLAN.md item 1): every Welcome merge sends a
-- spark in its tier's colour from the merge point to the egg, which bumps when it lands. Reduced Motion: no flight,
-- no bump. Drawn in code; the sparks ride their own layer (sparkLayer) in absolute pixels. Fable
-- FABLE-REVIEW-FIRST-HATCH MUST 2: 24 px (16 on a phone) with a white core and a cream edge, a trail of 4 fading
-- dots, 450 ms ease-in on a 60 px arc, a chain's sparks 90 ms apart, and a 100 ms flash of its colour on the card.
View.Spark=table.freeze({time=.45,size=24,sizePhone=16,phoneHeight=500,lift=60,trail=4,trailGap=.05,stagger=.09,
	flash=.1,bump=.22,bumpScale=.14,max=6})
-- Pure: the spark's point at t (0..1) on a curve that rises over the straight line, from a to b (pixels).
function View.sparkPath(a,b,t)
	t=math.clamp(t,0,1)
	local lift=View.Spark.lift
	local c=(a+b)/2-Vector2.new(0,lift*2)
	local u=1-t
	return a*(u*u)+c*(2*u*t)+b*(t*t)
end
function View.new(hosts,d)
	d=d or {};local self=setmetatable({hosts=hosts,d=d,progress=Progress.new(),age=0,loop=0,links={},alive=true,sparks={}},View)
	local host=hosts.meter
	self.egg=frame(host,"WelcomeMysteryEgg",UDim2.fromScale(.5,.5),UDim2.fromOffset(0,0),CREAM,host.ZIndex+5)
	self.egg.BackgroundTransparency=1;self.egg.AnchorPoint=Vector2.new(.5,.5);self.egg.Visible=false
	self.bumpScale=node("UIScale",self.egg,"SparkBump",{Scale=1})
	-- The First Hatch: one pip per combo under the egg (three combos hatch it), shown only in the combo round.
	self.pips={}
	for i=1,3 do
		local pip=frame(host,"ComboPip"..i,UDim2.new(.5,(i-2)*18,1,-12),UDim2.fromOffset(12,12),CREAM,host.ZIndex+6)
		pip.AnchorPoint=Vector2.new(.5,.5);pip.BackgroundTransparency=1;pip.Visible=false;round(pip)
		node("UIStroke",pip,"Ring",{Color=CREAM,Thickness=2})
		self.pips[i]=pip
	end
	self.flash=node("UIStroke",host,"SparkFlash",{Thickness=3,Transparency=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	-- Connected strip ovoid: no image asset, gap between separate oval primitives,
	-- face marks or borrowed art. A subtle gradient supplies existing egg language.
	for i=0,47 do
		local y=(i+.5)/48;local width=.7*math.sin(math.pi*y)^.52*(.80+.30*y)
		local strip=frame(self.egg,"Shell"..i,UDim2.fromScale(.5-width/2,.07+y*.84),UDim2.fromScale(width,.84/48+.001),CREAM,self.egg.ZIndex+1)
		local soft=node("UIGradient",strip,"SoftShell",{Color=ColorSequence.new(CREAM,CREAM:Lerp(MINT,.18)),Rotation=0})
		if y>=.76 and y<=.84 then self.band=self.band or {};table.insert(self.band,{strip=strip,soft=soft})end
	end
	for i,p in ipairs({{.38,.32,.065,.09},{.62,.40,.05,.07},{.42,.65,.06,.08},{.57,.73,.045,.06},{.53,.24,.04,.055}})do
		local dot=frame(self.egg,"Speckle"..i,UDim2.fromScale(p[1],p[2]),UDim2.fromScale(p[3],p[4]),MINT,self.egg.ZIndex+2);round(dot)
		self.speckles=self.speckles or {};table.insert(self.speckles,dot)
	end
	self.cracks={
		stroke(self.egg,"CrackHigh",{{.30,.36},{.40,.40},{.36,.46},{.46,.50}},self.egg.ZIndex+3),
		stroke(self.egg,"CrackLow",{{.70,.64},{.60,.60},{.65,.54},{.55,.50}},self.egg.ZIndex+3),
		stroke(self.egg,"CrackJoin",{{.46,.50},{.50,.55},{.55,.50}},self.egg.ZIndex+3),
	}
	local gh=hosts.gesture
	self.ghost=frame(gh,"WelcomeGhost",UDim2.fromScale(.5,.5),UDim2.fromOffset(36,42),CREAM,gh.ZIndex+5)
	self.ghost.BackgroundTransparency=1;self.ghost.AnchorPoint=Vector2.new(.5,.5);self.ghost.Visible=false
	-- Thumb, palm and two short fingertips, all passive; real tray remains interactive.
	for i,p in ipairs({{9,15,23,23,-10},{2,11,12,22,-28},{13,2,8,23,0},{22,5,8,21,8}})do
		local n=frame(self.ghost,"Hand"..i,UDim2.fromOffset(p[1],p[2]),UDim2.fromOffset(p[3],p[4]),CREAM,self.ghost.ZIndex+1)
		n.Rotation=p[5];n.BackgroundTransparency=.35;round(n)
	end
	self.glyph=node("TextLabel",gh,"WelcomeInputGlyph",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),
		Text="",TextColor3=CREAM,TextSize=16,Font=Enum.Font.BuilderSansBold,TextWrapped=true,Active=false,Selectable=false,ZIndex=gh.ZIndex+5,Visible=false})
	local sh=hosts.skip
	-- QA v760: a bare "Skip" on the card read as stray text. It is now a small outlined
	-- button, "Skip tutorial", as wide as its well; the 48 px tall TextButton is the hit
	-- area and the 34 px pill inside it is what is drawn.
	self.skip=node("TextButton",sh,"WelcomeSkip",{Size=UDim2.new(1,0,0,48),AnchorPoint=Vector2.new(1,.5),Position=UDim2.fromScale(1,.5),
		Text="",BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=sh.ZIndex+6,AutoButtonColor=false})
	self.skipPill=frame(self.skip,"SkipPill",UDim2.fromScale(.5,.5),UDim2.new(1,0,0,34),PILL,sh.ZIndex+7)
	self.skipPill.AnchorPoint=Vector2.new(.5,.5);round(self.skipPill,.5)
	self.skipStroke=node("UIStroke",self.skipPill,"Outline",{Color=CREAM,Transparency=.5,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	self.skipLabel=node("TextLabel",self.skipPill,"Label",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text="",TextColor3=CREAM,TextSize=14,
		Font=Enum.Font.BuilderSansBold,Active=false,Selectable=false,ZIndex=sh.ZIndex+8})
	table.insert(self.links,self.skip.MouseButton1Down:Connect(function()self.skipPill.BackgroundColor3=PILL:Lerp(CREAM,.16)end))
	table.insert(self.links,self.skip.MouseButton1Up:Connect(function()self.skipPill.BackgroundColor3=PILL end))
	table.insert(self.links,self.skip.MouseLeave:Connect(function()self.skipPill.BackgroundColor3=PILL end))
	table.insert(self.links,self.skip.Activated:Connect(function()self:requestSkip()end))
	return self
end
function View:requestSkip()
	if not self.alive or not self.active or not self.snapshot or not self.snapshot.skipReady or self.snapshot.grantPending or self.pending or not self.d.skip then return false end
	self.pending=true;self:input();self.d.skip(self.snapshot.generation);self:paint();return true
end
function View:copy(key,vars)return self.d.copy(key,vars)end
function View:paint()
	if not self.alive then return end
	local s=self.snapshot or {};local wanted=self.active==true
	local scale=if self.d.scale then math.max(.01,self.d.scale())else 1
	-- UDim offsets quantize to integer layout pixels. Round the authored hit
	-- size UP before the ancestor UIScale, so .77 scale cannot turn 48px into
	-- 47.74px. Egg bounds round down to preserve their physical inset instead.
	self.skip.Size=UDim2.new(1,0,0,math.ceil(48/scale))
	self.skipPill.Size=UDim2.new(1,0,0,math.ceil(34/scale));self.skipLabel.TextSize=14/scale
	self.egg.Visible=wanted
	for index,crack in ipairs(self.cracks)do crack.Visible=wanted and index<=(self.stage or 0)end
	self.skip.Visible=wanted and s.skipReady==true and self.hosts.skip.AbsoluteSize.X>=71.999 and self.hosts.skip.AbsoluteSize.Y>=47.999
	self.skip:SetAttribute("LayoutBlocked",wanted and s.skipReady==true and not self.skip.Visible)
	self.skip.Interactable=not self.pending and not s.grantPending
	self.skipLabel.Text=self:copy(if self.pending or s.grantPending then "onboarding.welcome.saving"else "onboarding.welcome.skip")
	-- Fable (can wait): Skip tutorial at 60% so it does not compete with the egg
	local quiet=s.combo==true
	self.skipLabel.TextTransparency=if self.skip.Interactable then(if quiet then .4 else 0)else(if quiet then .6 else .4)
	self.skipStroke.Transparency=if self.skip.Interactable then(if quiet then .7 else .5)else(if quiet then .85 else .8)
	local input=wanted and(s.drops or 0)==0 and not self.interacted
	local reduced=s.reduced==true
	local touch=s.device=="Touch"
	self.ghost.Visible=input and touch and not reduced
	self.glyph.Visible=input and(not touch or reduced)
	self.glyph.Text=self:copy(if reduced and touch then "onboarding.welcome.static"elseif s.device=="Gamepad"then "onboarding.welcome.gamepad"
		elseif self.egg3d then "onb2.deck.click"else "onboarding.welcome.keyboard") -- onboarding v2: no key names
	local side=View.fit(self.hosts.meter.AbsoluteSize.X,self.hosts.meter.AbsoluteSize.Y)
	self.egg.Size=UDim2.fromOffset(math.floor(side/scale),math.floor(side/scale))
	-- Onboarding v2 step 1 (Onboard "egg3d"): the 3D egg and its pips take the pixel egg's place once it is drawn.
	local v2=self.egg3d~=nil and self.egg3d.shown
	if v2 and self.egg3d:ready()then self.egg.Visible=false end
	self.egg:SetAttribute("Inset",8);self.egg:SetAttribute("Stage",self.stage or 0)
	local combos=if s.combo==true then math.clamp(math.floor(s.charge or 0),0,3)else nil
	-- the combo round's egg wears the reveal egg's look (switch off: as before)
	if self.lookCombo~=(s.combo==true)then
		self.lookCombo=s.combo==true
		for _,dot in ipairs(self.speckles)do dot.BackgroundColor3=if self.lookCombo then SPOT else MINT end
		for _,b in ipairs(self.band)do b.strip.BackgroundColor3=if self.lookCombo then BAND else CREAM;b.soft.Enabled=not self.lookCombo end
	end
	for i,pip in ipairs(self.pips)do pip.Visible=wanted and combos~=nil and not v2;pip.BackgroundTransparency=if combos and i<=combos then 0 else 1 end
	self.egg:SetAttribute("LayoutBlocked",wanted and side<1)
end
function View:update(snapshot)
	if not self.alive then return end
	local old=self.snapshot;self.snapshot=table.clone(snapshot or {})
	local s=self.snapshot
	if not old or old.generation~=s.generation then self.age,self.loop,self.interacted,self.pending,self.replayed=0,0,false,false,false end
	self.active=s.active==true and(s.owned or 0)==0 and s.phase=="Welcome"and s.revealPending~=true
	if not self.active then self.age,self.loop=0,0;self.egg.Rotation=0;self.wobble=nil;self:clearSparks()end
	if s.grantPending==true then self.pending=true elseif old and old.grantPending==true then self.pending=false end
	local stage,cue=Progress.update(self.progress,s.generation,s.charge or 0,s.threshold,self.active)
	self.stage=stage
	-- Onboarding v2 step 1 (Onboard "egg3d"): the combo round's 3D egg, its words and pips (its own crack sounds).
	-- The calm deck's cards only (DeckScreen's Goals card holds the skip well); the portrait fallback keeps its pixel egg.
	local coach=self.hosts.skip and self.hosts.skip.Parent
	if s.combo==true and not self.egg3d and coach and coach.Name=="Goals"and V2.on("egg3d")then
		local ok,egg=pcall(function()
			return require(script.Parent.WelcomeEgg3D).new(self.hosts.meter,self.hosts.skip.Parent,{copy=self.d.copy,play=self.d.play,
				reduced=function()return self.snapshot~=nil and self.snapshot.reduced==true end,
				-- onboarding v3 section 5 (Onboard "deck2"): the cuter deck, read once for this round's egg
				deck2=V2.deck2On(),sparkLayer=self.d.sparkLayer,wellRect=self.d.wellRect,scale=self.d.scale,tucked=self.d.tucked})
		end)
		if ok then self.egg3d=egg else warn("[Onboard] egg3d: "..tostring(egg))end
	end
	if self.egg3d then self.egg3d:update({active=self.active and s.combo==true,combos=if s.combo==true then s.charge else 0,drops=s.drops,granted=(s.owned or 0)>0})end
	if cue then
		if not s.reduced then self.wobble=0 end
		if self.d.cue and not self.egg3d then self.d.cue(Progress.Pitches[cue],.35)end
	end
	self:paint()
	-- the combo round keeps its one goal in words: Hatch a friend (the pips count the combos)
	if s.combo==true then return "onboarding.welcome.friend"end
	return Progress.lesson(stage,s.drops)
end
function View:input()self.interacted=true;self.ghost.Visible=false;self.glyph.Visible=false end
-- A merge at `from` (absolute screen pixels), in `color`. Only the showing egg takes it; false when nothing flies.
-- chain, tier: the server's chain count and the merged tier. With deck2 (onboarding v3 section 5) a combo's merge
-- (chain 1, the one the server counts) sends its spark to the next pip instead (WelcomeDeck2).
function View:spark(from,color,pitch,chain,tier)
	if self.alive and chain==1 and self.egg3d and self.egg3d.deck2 and self.egg3d.shown then
		return self.egg3d:comboSpark(from,tier)
	end
	local egg3d=self.egg3d~=nil and self.egg3d.shown
	if not self.alive or not self.active or not(self.egg.Visible or egg3d)or typeof(from)~="Vector2"then return false end
	if self.snapshot and self.snapshot.reduced then return false end
	-- its own layer above the board (the board draws in a ScreenGui over the deck's); else the egg's own
	local gui=(self.d.sparkLayer and self.d.sparkLayer())or self.egg:FindFirstAncestorWhichIsA("LayerCollector")
	if not gui or #self.sparks>=View.Spark.max then return false end
	local S=View.Spark
	local size=if gui.AbsoluteSize.Y>0 and gui.AbsoluteSize.Y<S.phoneHeight then S.sizePhone else S.size
	local tint=if typeof(color)=="Color3"then color else MINT
	local function dot(name,scale,transparency)
		local d=node("Frame",nil,name,{Size=UDim2.fromOffset(size*scale,size*scale),AnchorPoint=Vector2.new(.5,.5),BorderSizePixel=0,
			BackgroundColor3=tint,BackgroundTransparency=transparency,Active=false,Selectable=false,ZIndex=200,Visible=false})
		round(d);d.Parent=gui;return d
	end
	local head=dot("WelcomeSpark",1,0)
	node("UIStroke",head,"Edge",{Color=CREAM,Thickness=2})
	local core=node("Frame",head,"Core",{Size=UDim2.fromScale(.45,.45),Position=UDim2.fromScale(.5,.5),AnchorPoint=Vector2.new(.5,.5),
		BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=201});round(core)
	local trail={}
	for i=1,S.trail do trail[i]=dot("WelcomeSparkTrail",1-.16*i,.25+.15*i)end
	-- a chain's sparks leave one after another
	local clock=self.sparkClock or 0
	local delay=math.max(0,(self.lastSparkAt or -math.huge)+S.stagger-clock)
	self.lastSparkAt=clock+delay
	local spark={dot=head,trail=trail,gui=gui,from=from,age=-delay,pitch=pitch,color=tint}
	table.insert(self.sparks,spark)
	self:stepSpark(spark,0)
	return true
end
function View:stepSpark(spark,dt)
	spark.age+=dt
	local S=View.Spark
	local target=self.egg.AbsolutePosition+self.egg.AbsoluteSize/2
	local base=spark.gui.AbsolutePosition
	local function at(age)
		local t=math.clamp(age/S.time,0,1)
		return View.sparkPath(spark.from,target,t*t)-base,t -- ease-in: it speeds into the egg
	end
	local p,t=at(spark.age)
	spark.dot.Visible=spark.age>=0
	spark.dot.Position=UDim2.fromOffset(p.X,p.Y)
	for i,ghost in ipairs(spark.trail)do
		local age=spark.age-i*S.trailGap
		ghost.Visible=age>=0 and t<1
		local q=at(math.max(0,age));ghost.Position=UDim2.fromOffset(q.X,q.Y)
	end
	return t>=1
end
function View:destroySpark(spark)
	spark.dot:Destroy()
	for _,ghost in ipairs(spark.trail or {})do ghost:Destroy()end
end
function View:clearSparks()
	for _,spark in ipairs(self.sparks)do self:destroySpark(spark)end
	table.clear(self.sparks);self.bumpAge=nil;self.bumpScale.Scale=1;self.flashAge=nil;self.flash.Transparency=1
end
-- Host acknowledgement/rejection clears a local button latch. Retrying keeps it
-- true; never infer a failed save from a timeout and present another reward.
function View:setSkipPending(pending)self.pending=pending==true;self:paint()end
function View:checkpoint()
	return {progress=self.progress,snapshot=self.snapshot and table.clone(self.snapshot),age=self.age,loop=self.loop,interacted=self.interacted,pending=self.pending,replayed=self.replayed}
end
function View:restore(checkpoint)
	if not checkpoint then return end
	for _,key in ipairs({"progress","snapshot","age","loop","interacted","pending","replayed"})do self[key]=checkpoint[key]end
end
function View:step(dt)
	if not self.alive or not self.active then return end
	dt=math.clamp(dt or 0,0,.25);self.age+=dt;self.loop+=dt
	self.sparkClock=(self.sparkClock or 0)+dt
	for index=#self.sparks,1,-1 do
		local spark=self.sparks[index]
		if self:stepSpark(spark,dt)then
			self:destroySpark(spark);table.remove(self.sparks,index)
			self.bumpAge=0;self.flashAge=0;self.flash.Color=spark.color or MINT
			if self.d.cue then self.d.cue(spark.pitch or 1.3,.16)end
		end
	end
	if self.flashAge then
		self.flashAge+=dt
		if self.flashAge>=View.Spark.flash then self.flashAge=nil;self.flash.Transparency=1 else self.flash.Transparency=self.flashAge/View.Spark.flash end
	end
	if self.bumpAge then
		self.bumpAge+=dt
		local u=self.bumpAge/View.Spark.bump
		if u>=1 then self.bumpAge=nil;self.bumpScale.Scale=1 else self.bumpScale.Scale=1+View.Spark.bumpScale*math.sin(math.pi*u)end
	end
	if self.age>=8 and not self.replayed and(self.snapshot.drops or 0)==0 and not self.interacted then
		self.replayed=true;self.loop=0;if self.d.quietCue then self.d.quietCue()end
	end
	if self.wobble then
		self.wobble+=dt
		if self.wobble>=.14 or self.snapshot.reduced then self.wobble=nil;self.egg.Rotation=0
		else self.egg.Rotation=3*math.sin(self.wobble/.14*math.pi*2)end
	end
	if self.ghost.Visible then
		local t=self.loop%3.6
		self.ghost.Visible=t<1.6
		local u=math.clamp(t/1.3,0,1)
		self.ghost.Position=UDim2.new(.30+.35*u,0,.5,if t>1.3 then -(t-1.3)/.3*14 else 0)
	elseif not self.interacted and self.snapshot.device=="Touch"and not self.snapshot.reduced and(self.snapshot.drops or 0)==0 then
		self.ghost.Visible=self.loop%3.6<1.6
	end
end
function View:destroy()
	if not self.alive then return end
	self:clearSparks();self.alive=false
	for _,link in ipairs(self.links)do link:Disconnect()end
	if self.egg3d then self.egg3d:destroy();self.egg3d=nil end
	self.egg:Destroy();self.ghost:Destroy();self.glyph:Destroy();self.skip:Destroy()
	self.flash:Destroy();for _,pip in ipairs(self.pips)do pip:Destroy()end
end
return View
