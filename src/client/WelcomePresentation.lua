-- Procedural Welcome art only; never grants progress or fabricates player input.
-- hosts={meter,gesture,skip}; each must be an existing free well. No modal.
local Progress=require(game:GetService("ReplicatedStorage").Shared.WelcomeProgress)
local View={};View.__index=View
local CREAM=Color3.fromHex("#FFF0D2")
local MINT=Color3.fromHex("#94DFB7")
local INK=Color3.fromHex("#24313B")
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
function View.fit(width,height)
	local side=math.max(0,math.min(width-16,height-16))
	return side,(width-side)/2,(height-side)/2
end
function View.new(hosts,d)
	d=d or {};local self=setmetatable({hosts=hosts,d=d,progress=Progress.new(),age=0,loop=0,links={},alive=true},View)
	local host=hosts.meter
	self.egg=frame(host,"WelcomeMysteryEgg",UDim2.fromScale(.5,.5),UDim2.fromOffset(0,0),CREAM,host.ZIndex+5)
	self.egg.BackgroundTransparency=1;self.egg.AnchorPoint=Vector2.new(.5,.5);self.egg.Visible=false
	-- Connected strip ovoid: no image asset, gap between separate oval primitives,
	-- face marks or borrowed art. A subtle gradient supplies existing egg language.
	for i=0,47 do
		local y=(i+.5)/48;local width=.7*math.sin(math.pi*y)^.52*(.80+.30*y)
		local strip=frame(self.egg,"Shell"..i,UDim2.fromScale(.5-width/2,.07+y*.84),UDim2.fromScale(width,.84/48+.001),CREAM,self.egg.ZIndex+1)
		node("UIGradient",strip,"SoftShell",{Color=ColorSequence.new(CREAM,CREAM:Lerp(MINT,.18)),Rotation=0})
	end
	for i,p in ipairs({{.38,.32,.065,.09},{.62,.40,.05,.07},{.42,.65,.06,.08},{.57,.73,.045,.06},{.53,.24,.04,.055}})do
		local dot=frame(self.egg,"Speckle"..i,UDim2.fromScale(p[1],p[2]),UDim2.fromScale(p[3],p[4]),MINT,self.egg.ZIndex+2);round(dot)
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
	self.skip=node("TextButton",sh,"WelcomeSkip",{Size=UDim2.fromOffset(72,48),AnchorPoint=Vector2.new(1,.5),Position=UDim2.fromScale(1,.5),
		Text="",TextColor3=CREAM,TextSize=14,TextWrapped=true,Font=Enum.Font.BuilderSansBold,BackgroundColor3=INK,BackgroundTransparency=.12,
		BorderSizePixel=0,Visible=false,ZIndex=sh.ZIndex+6,AutoButtonColor=true})
	round(self.skip,.25)
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
	self.skip.Size=UDim2.fromOffset(math.ceil(72/scale),math.ceil(48/scale));self.skip.TextSize=14/scale
	self.egg.Visible=wanted
	for index,crack in ipairs(self.cracks)do crack.Visible=wanted and index<=(self.stage or 0)end
	self.skip.Visible=wanted and s.skipReady==true and self.hosts.skip.AbsoluteSize.X>=71.999 and self.hosts.skip.AbsoluteSize.Y>=47.999
	self.skip:SetAttribute("LayoutBlocked",wanted and s.skipReady==true and not self.skip.Visible)
	self.skip.Interactable=not self.pending and not s.grantPending
	self.skip.Text=self:copy(if self.pending or s.grantPending then "onboarding.welcome.saving"else "onboarding.welcome.skip")
	local input=wanted and(s.drops or 0)==0 and not self.interacted
	local reduced=s.reduced==true
	local touch=s.device=="Touch"
	self.ghost.Visible=input and touch and not reduced
	self.glyph.Visible=input and(not touch or reduced)
	self.glyph.Text=self:copy(if reduced and touch then "onboarding.welcome.static"elseif s.device=="Gamepad"then "onboarding.welcome.gamepad"else "onboarding.welcome.keyboard")
	local side=View.fit(self.hosts.meter.AbsoluteSize.X,self.hosts.meter.AbsoluteSize.Y)
	self.egg.Size=UDim2.fromOffset(math.floor(side/scale),math.floor(side/scale))
	self.egg:SetAttribute("Inset",8);self.egg:SetAttribute("Stage",self.stage or 0)
	self.egg:SetAttribute("LayoutBlocked",wanted and side<1)
end
function View:update(snapshot)
	if not self.alive then return end
	local old=self.snapshot;self.snapshot=table.clone(snapshot or {})
	local s=self.snapshot
	if not old or old.generation~=s.generation then self.age,self.loop,self.interacted,self.pending,self.replayed=0,0,false,false,false end
	self.active=s.active==true and(s.owned or 0)==0 and s.phase=="Welcome"and s.revealPending~=true
	if not self.active then self.age,self.loop=0,0;self.egg.Rotation=0;self.wobble=nil end
	if s.grantPending==true then self.pending=true elseif old and old.grantPending==true then self.pending=false end
	local stage,cue=Progress.update(self.progress,s.generation,s.charge or 0,s.threshold,self.active)
	self.stage=stage
	if cue then
		if not s.reduced then self.wobble=0 end
		if self.d.cue then self.d.cue(Progress.Pitches[cue],.35)end
	end
	self:paint()
	return Progress.lesson(stage,s.drops)
end
function View:input()self.interacted=true;self.ghost.Visible=false;self.glyph.Visible=false end
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
	if not self.alive then return end;self.alive=false
	for _,link in ipairs(self.links)do link:Disconnect()end
	self.egg:Destroy();self.ghost:Destroy();self.glyph:Destroy();self.skip:Destroy()
end
return View
