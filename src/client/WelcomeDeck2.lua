-- Onboarding v3 section 5 (Onboard "deck2", artifacts/qa-2026-11-27-beta37/ONBOARDING-V3-BRIEF.md; Spencer, beta 37:
-- "a cuter Welcome deck"). The egg3d deck (WelcomeEgg3D) dressed inside its two existing cards; the board, its rules
-- and the server's combo count are untouched. Presentation only, built in code from GUI frames (no new assets; the
-- step pictures reuse the deck's own ball art, JellySprite.preview).
--   left card  a glass sky (#2FA8F0 to #0E5FB8), a 1 px white top highlight, three rising bubbles at 12%; the top 45%
--              a looping picture of the step (a ball falls and squashes; two balls bump into a bigger one; the 64 px
--              sun-gold numeral), the line under it punching 1.25 with a menu tick on each change
--   egg card   a sky fill (#C9F1FF to #58B8F2), the hatch card's grass arc at the egg's foot, a soft shadow; the egg
--              knocks from inside (WelcomeEgg3D asks knock()); three egg pips, the next one breathing
--   a combo    the spark arcs from the merge to its pip (0.35 s, 4 beads), the pip pops with a ring, the egg hops
--              (WelcomeEgg3D), the card's border flashes the merged tier's light, a word punches over the well
--   combo 3    the pips fly into the egg, one light sweep, then the egg's rise (WelcomeEgg3D) and the tuck; the onboarding
--              fun pass: until the deck tucks for the stork the egg knocks every 0.4 s and the border pulses gold
-- Reduced Motion: no loops, arc, knock, pops, flight or sweep; colour, words, sound and buzz stay.
-- WelcomeEgg3D owns it: Deck2.new(egg) after the egg is built; counted(n, clock) when the server's count reaches n;
-- step(clock) -> the combos whose pips popped now; paint(clock, combos, drops, line); comboSpark(from, tier).
local Shared=game:GetService("ReplicatedStorage").Shared
local V2=require(script.Parent.OnboardV2)
local D=V2.Deck2
local Deck2={};Deck2.__index=Deck2
local WHITE=Color3.new(1,1,1)
local NAVY=Color3.fromHex("#0E3F86")
local WORD_INK=Color3.fromHex("#15102B")

local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent;return n
end
local function frame(parent,name,z,props)
	local f=node("Frame",parent,{Name=name,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=z,Active=false,Selectable=false})
	for k,v in pairs(props or {})do f[k]=v end
	return f
end
local function round(n)node("UICorner",n,{CornerRadius=UDim.new(.5,0)})end
local function cornerOf(object,fallback)
	local c=object and object:FindFirstChildOfClass("UICorner")
	return if c then c.CornerRadius else fallback or UDim.new(0,10)
end
local function lightOf(tier)
	local ok,c=pcall(function()return require(Shared.BallThemes).lightColor(tier)end)
	return if ok and typeof(c)=="Color3"then c else D.gold
end
local function set(object,key,value)if object[key]~=value then object[key]=value end end

function Deck2.new(egg)
	local self=setmetatable({egg=egg,d=egg.d or {},made={},shown=false,sent=0,popped=0,countAt={},landAt={},tier={},popAt={},
		sparks={},kind=nil,lineText=nil,alive=true},Deck2)
	local ok,problem=pcall(function()self:build()end)
	if not ok then self:destroy();error(problem,0)end
	return self
end
function Deck2:keep(object)table.insert(self.made,object);return object end
function Deck2:reduced()return self.egg:reduced()end

-- ── Build ───────────────────────────────────────────────────────────────────────────────────────────────────────
function Deck2:build()
	local egg=self.egg
	local meter=egg.meter
	local z=meter.ZIndex
	local corner=cornerOf(meter.Parent)
	-- The egg card: a sky fill with the flash stroke, the grass arc, the shadow, the sweep.
	self.fill=self:keep(frame(meter,"Deck2EggSky",z+1,{Size=UDim2.fromScale(1,1),BackgroundTransparency=0,BackgroundColor3=WHITE,Visible=false}))
	node("UICorner",self.fill,{CornerRadius=corner})
	node("UIGradient",self.fill,{Rotation=90,Color=ColorSequence.new(D.eggTop,D.eggBottom)})
	local G=require(Shared.HatchAero).Grass
	self.grassClip=self:keep(frame(meter,"Deck2GrassClip",z+2,{ClipsDescendants=true,Visible=false}))
	self.grassHill=frame(self.grassClip,"Hill",z+2,{AnchorPoint=Vector2.new(.5,0),BackgroundTransparency=0,BackgroundColor3=WHITE})
	round(self.grassHill)
	self.grassGradient=node("UIGradient",self.grassHill,{Rotation=90})
	node("UIStroke",self.grassHill,{Color=WHITE,Thickness=1,Transparency=G.highlight,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	-- the card's own rounded foot under the clipped hill (a clip frame cannot follow the card's corners)
	self.grassFoot=self:keep(frame(meter,"Deck2GrassFoot",z+2,{BackgroundTransparency=0,BackgroundColor3=G.bottom,Visible=false}))
	node("UICorner",self.grassFoot,{CornerRadius=corner})
	self.grassColors={top=G.top,bottom=G.bottom}
	self.corner=corner
	-- the soft shadow (beta 39: a round frame with a sideways gradient read as a grey bar, over EggPreview3D's own hard
	-- one, which WelcomeEgg3D now hides): a radial blob stretched to an ellipse, placed every frame (Deck2:paintShadow)
	local blob=require(Shared.UnderstoryArt)
	self.shadow=self:keep(node("ImageLabel",meter,{Name="Deck2EggShadow",BackgroundTransparency=1,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),
		Image=if blob.filled(blob.Blob)then blob.Blob else "",ImageColor3=WHITE,ImageTransparency=1,ScaleType=Enum.ScaleType.Stretch,
		ZIndex=z+3,Visible=false,Active=false,Selectable=false}))
	self.sweepFrame=self:keep(frame(meter,"Deck2Sweep",z+8,{Size=UDim2.fromScale(1,1),BackgroundTransparency=0,BackgroundColor3=WHITE,Visible=false}))
	node("UICorner",self.sweepFrame,{CornerRadius=corner})
	self.sweepBand=node("UIGradient",self.sweepFrame,{Rotation=25,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),
		NumberSequenceKeypoint.new(.4,1),NumberSequenceKeypoint.new(.5,D.sweepAlpha),NumberSequenceKeypoint.new(.6,1),NumberSequenceKeypoint.new(1,1)}),
		Offset=Vector2.new(-1,0)})
	-- the border flash, over the grass and the egg
	self.flashFrame=self:keep(frame(meter,"Deck2Flash",z+8,{Size=UDim2.fromScale(1,1),Visible=false}))
	node("UICorner",self.flashFrame,{CornerRadius=corner})
	self.flash=node("UIStroke",self.flashFrame,{Thickness=3,Transparency=1,Color=D.gold,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	-- over the egg's viewport (WelcomeEgg3D's well is z + 5, EggPreview3D draws at z + 6)
	self:buildPips(z+9)
	if egg.cover then self:buildCard()end
end
-- Three egg pips: a CanvasGroup body (a round foot and a narrower crown, so the two read as one egg when faded), a
-- white glint when filled, and a pop ring. Beta 42 note 11 (C11): an empty pip is a solid navy egg (WelcomeEgg3D's
-- pipEmpty) with no outline; the old Path2D ring sat outside the CanvasGroup at full opacity and read as a stray oval.
function Deck2:buildPips(z)
	local meter=self.egg.meter
	local W,H=D.pipW,D.pipH
	self.pipRow=self:keep(frame(meter,"Deck2Pips",z,{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-D.pipPad),
		Size=UDim2.fromOffset(W*3+D.pipGap*2,H),Visible=false}))
	self.pips={}
	for i=1,3 do
		local home=Vector2.new((i-1)*(W+D.pipGap)+W/2,H/2)
		local holder=frame(self.pipRow,"EggPip"..i,z,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(home.X,home.Y),Size=UDim2.fromOffset(W,H)})
		local scale=node("UIScale",holder,{Scale=1})
		local body=node("CanvasGroup",holder,{Name="Body",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=z,GroupTransparency=D.pipEmptyAlpha})
		local foot=frame(body,"Foot",z,{AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromScale(.5,1),Size=UDim2.fromOffset(W,W),BackgroundTransparency=0,BackgroundColor3=D.pipEmpty})
		round(foot)
		local crown=frame(body,"Crown",z,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.fromOffset(math.floor(W*.8+.5),math.floor(W*.8+.5)),
			BackgroundTransparency=0,BackgroundColor3=D.pipEmpty})
		round(crown)
		local glint=frame(body,"Glint",z+1,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.34,.3),Size=UDim2.fromOffset(math.max(3,math.floor(W*.24)),math.max(4,math.floor(W*.32))),
			BackgroundTransparency=.05,BackgroundColor3=WHITE,Rotation=-20,Visible=false})
		round(glint)
		local pop=frame(self.pipRow,"PopRing"..i,z,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(home.X,home.Y),Size=UDim2.fromOffset(W,W),Visible=false})
		round(pop)
		local popStroke=node("UIStroke",pop,{Color=D.gold,Thickness=2,Transparency=0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		self.pips[i]={holder=holder,scale=scale,body=body,foot=foot,crown=crown,glint=glint,pop=pop,popStroke=popStroke,home=home}
	end
end
-- The left card: dress WelcomeEgg3D's cover (the sky, the highlight, the bubbles) and add the picture over its line.
function Deck2:buildCard()
	local egg=self.egg
	local cover=egg.cover
	local z=cover.ZIndex
	self.coverColor=cover.BackgroundColor3
	cover.BackgroundColor3=WHITE
	self.sky=self:keep(node("UIGradient",cover,{Name="Deck2Sky",Rotation=90,Color=ColorSequence.new(D.skyTop,D.skyBottom)}))
	local r=cornerOf(cover).Offset
	self.highlight=self:keep(frame(cover,"Deck2Highlight",z+1,{Position=UDim2.fromOffset(r,1),Size=UDim2.new(1,-r*2,0,1),BackgroundTransparency=D.highlight,BackgroundColor3=WHITE}))
	self.bubbles={}
	for i=1,D.bubbles do
		local size=D.bubbleSizes[i]or 12
		local b=self:keep(frame(cover,"Deck2Bubble"..i,z,{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(size,size),BackgroundTransparency=1,BackgroundColor3=WHITE}))
		round(b)
		local rim=node("UIStroke",b,{Color=WHITE,Thickness=1,Transparency=D.bubbleRim,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		local spec=frame(b,"Spec",z,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.32,.3),Size=UDim2.fromOffset(math.max(2,math.floor(size*.22)),math.max(2,math.floor(size*.22))),
			BackgroundTransparency=1,BackgroundColor3=WHITE})
		round(spec)
		self.bubbles[i]={node=b,rim=rim,spec=spec}
	end
	-- the picture (top 45%): the falling ball, the two balls and the bigger one, the numeral
	self.picture=self:keep(frame(cover,"Deck2Picture",z+1,{Position=UDim2.fromOffset(0,4),Size=UDim2.new(1,0,D.picture,-4)}))
	local Sprite=require(script.Parent.JellySprite)
	local function ball(name,tier,expr)
		local holder=frame(self.picture,name,z+1,{AnchorPoint=Vector2.new(.5,1),Visible=false})
		local preview=Sprite.preview(holder,z+1)
		return{holder=holder,preview=preview,tier=tier,expr=expr}
	end
	self.balls={drop=ball("DropBall",1,"idle"),left=ball("LeftBall",1,"idle"),right=ball("RightBall",1,"idle"),merged=ball("MergedBall",2,"merged")}
	self.numeral=node("TextLabel",self.picture,{Name="Numeral",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.55),
		Size=UDim2.fromScale(1,1),Text="",TextColor3=D.gold,TextScaled=true,Font=Enum.Font.GothamBlack,ZIndex=z+1,Visible=false})
	node("UITextSizeConstraint",self.numeral,{MaxTextSize=D.numeral,MinTextSize=18})
	node("UIStroke",self.numeral,{Color=NAVY,Thickness=2,Transparency=.35})
	self.numeralScale=node("UIScale",self.numeral,{Scale=1})
	-- the line moves under the picture and gets its punch
	local line=egg.line
	self.lineWas={Position=line.Position,Size=line.Size,AnchorPoint=line.AnchorPoint}
	self.linePunch=self:keep(node("UIScale",line,{Name="Deck2Punch",Scale=1}))
end
function Deck2:layoutCard()
	local cover=self.egg.cover
	local coach=self.egg.coach
	if not cover or not coach then return end
	local cw,ch=coach.Size.X.Offset-4,coach.Size.Y.Offset-4
	if cw<=0 or ch<=0 then
		-- a scale-sized card: its drawn size over the deck's scale
		local k=self.egg.d.scale and math.max(.01,self.egg.d.scale())or 1
		cw,ch=cover.AbsoluteSize.X/k,cover.AbsoluteSize.Y/k
	end
	local skip=coach:FindFirstChild("WelcomeSkipWell")
	local skipTop=if skip and skip.Size.Y.Offset>0 then skip.Position.Y.Offset-2 else ch-6
	cw,ch,skipTop=math.floor(cw),math.floor(ch),math.floor(skipTop)
	local key=string.format("%d %d %d",cw,ch,skipTop)
	if self.cardKey==key then return end
	self.cardKey=key
	self.cardW,self.cardH=cw,ch
	local picH=math.floor(ch*D.picture)
	self.picH=picH-4
	local ballSize=math.max(12,math.min(D.ball,math.floor((picH-8)*.55),math.floor(cw*.34)))
	self.ballSize=ballSize
	for name,b in pairs(self.balls)do
		local s=if name=="merged"then math.floor(ballSize*D.merged+.5)else ballSize
		b.size=s;b.holder.Size=UDim2.fromOffset(s,s)
	end
	local line=self.egg.line
	local top=picH+2
	local height=math.max(24,skipTop-4-top)
	line.AnchorPoint=Vector2.new(.5,0);line.Position=UDim2.new(.5,0,0,top);line.Size=UDim2.new(1,-16,0,height)
end
-- The egg card's grass arc and shadow, at the egg's foot (WelcomeEgg3D's well ends `pad + pip + pad` over the foot).
function Deck2:layoutEgg()
	local meter=self.egg.meter
	local host=meter.Parent
	local w,h=host and host.Size.X.Offset or 0,host and host.Size.Y.Offset or 0
	if w<=0 or h<=0 then
		local k=self.egg.d.scale and math.max(.01,self.egg.d.scale())or 1
		w,h=meter.AbsoluteSize.X/k,meter.AbsoluteSize.Y/k
	end
	w,h=math.floor(w),math.floor(h)
	local key=string.format("%d %d",w,h)
	if self.eggKey==key or w<1 or h<1 then return end
	self.eggKey=key
	local E=V2.Deck
	local wellBottom=h-(E.pad+E.pip+E.pad)
	local foot=wellBottom/h-.02
	local crest=V2.grassCrest(foot)
	local r=self.corner.Offset+self.corner.Scale*math.min(w,h)
	local top=math.floor(crest*h+.5)
	local clipBottom=math.max(top+1,math.floor(h-r))
	self.grassClip.Position=UDim2.fromOffset(0,top);self.grassClip.Size=UDim2.new(1,0,0,clipBottom-top)
	local d=math.floor(3*w+.5)
	self.grassHill.Position=UDim2.new(.5,0,0,0);self.grassHill.Size=UDim2.fromOffset(d,d)
	local shows=math.clamp((h-top)/d,.01,.99)
	self.grassGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,self.grassColors.top),ColorSequenceKeypoint.new(shows,self.grassColors.bottom),
		ColorSequenceKeypoint.new(1,self.grassColors.bottom)})
	local footH=math.max(2,math.floor(r*2+.5))
	self.grassFoot.Position=UDim2.new(0,0,1,-footH);self.grassFoot.Size=UDim2.new(1,0,0,footH)
	self.crestY=top
end
-- The soft shadow under the 3D egg, on the grass top: follows the egg's centre and width (EggPreview3D's geometry, in
-- its well at the card's pad), shrinking and fading as the egg hops or rises. Hidden until the 3D egg is in.
-- rise: the egg's lift in px; fade: its own fade (WelcomeEgg3D:paint, after the pose).
function Deck2:paintShadow(preview,rise,fade)
	if not self.alive or not self.shown then return end
	local g=preview and preview.loaded==true and preview.geo
	local well=self.egg.well
	if not(g and well and self.crestY)then set(self.shadow,"ImageTransparency",1);return end
	local x,y,w,h,transparency=V2.eggShadow(well.Position.X.Offset+g.cx,g.ew,self.crestY,rise,fade)
	set(self.shadow,"Position",UDim2.fromOffset(x,y));set(self.shadow,"Size",UDim2.fromOffset(w,h))
	set(self.shadow,"ImageTransparency",transparency)
end

-- ── Combos ──────────────────────────────────────────────────────────────────────────────────────────────────────
function Deck2:reset()
	self.sent,self.popped=0,0
	table.clear(self.countAt);table.clear(self.landAt);table.clear(self.tier);table.clear(self.popAt)
	self:clearSparks()
	self.flashAt,self.wordAt,self.finaleAt=nil,nil,nil
	for _,p in ipairs(self.pips)do p.holder.Position=UDim2.fromOffset(p.home.X,p.home.Y)end
end
-- The server's count reached n at `clock` (WelcomeEgg3D's clock).
function Deck2:counted(n,clock)if n>=1 and n<=3 and not self.countAt[n]then self.countAt[n]=clock end end
-- Counted pips not popped yet: the egg stays up for them.
function Deck2:pending()
	for n=self.popped+1,3 do if self.countAt[n]then return true end end
	return false
end
-- A combo's merge at `from` (screen px): its spark flies to the next pip. Reduced Motion: no arc (the tier is kept
-- for the flash). False when nothing flies.
function Deck2:comboSpark(from,tier)
	if not self.alive or self.sent>=3 then return false end
	self.sent+=1
	local n=self.sent
	self.tier[n]=tier
	if self:reduced()or typeof(from)~="Vector2"then return false end
	local gui=self.d.sparkLayer and self.d.sparkLayer()
	if not gui then return false end
	local clock=self.egg.clock
	local color=lightOf(tier)
	local function dot(name,size,alpha)
		local f=frame(gui,name,200,{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(size,size),BackgroundTransparency=alpha,BackgroundColor3=color,Visible=false})
		round(f);return f
	end
	local head=dot("Deck2Spark",D.spark,0)
	node("UIStroke",head,{Color=WHITE,Thickness=2})
	local core=frame(head,"Core",201,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.45,.45),BackgroundTransparency=0,BackgroundColor3=WHITE})
	round(core)
	local beads={}
	for i=1,D.beads do beads[i]=dot("Deck2SparkBead",math.max(4,math.floor(D.spark*(1-.17*i))),.2+.15*i)end
	table.insert(self.sparks,{n=n,from=from,at=clock,head=head,beads=beads,gui=gui})
	self.landAt[n]=clock+D.arc
	return true
end
function Deck2:pipCenter(n)
	local p=self.pips[n]
	return p.holder.AbsolutePosition+p.holder.AbsoluteSize/2
end
function Deck2:stepSparks(clock)
	for index=#self.sparks,1,-1 do
		local s=self.sparks[index]
		local age=clock-s.at
		local target=self:pipCenter(s.n)
		local base=s.gui.AbsolutePosition
		local u=V2.arcProgress(age)
		local p=V2.arc(s.from,target,u)-base
		s.head.Visible=true;s.head.Position=UDim2.fromOffset(p.X,p.Y)
		for i,b in ipairs(s.beads)do
			local a=age-i*D.beadGap
			b.Visible=a>0 and u<1
			if b.Visible then local q=V2.arc(s.from,target,V2.arcProgress(a))-base;b.Position=UDim2.fromOffset(q.X,q.Y)end
		end
		if u>=1 then self:dropSpark(s);table.remove(self.sparks,index)end
	end
end
function Deck2:dropSpark(s)
	s.head:Destroy()
	for _,b in ipairs(s.beads)do b:Destroy()end
end
function Deck2:clearSparks()
	for _,s in ipairs(self.sparks)do self:dropSpark(s)end
	table.clear(self.sparks)
end
-- The pips that pop at `clock` (in order: pip n waits for pip n - 1). Each pop flashes the border in its merged
-- tier's light and punches its word.
function Deck2:step(clock)
	local out={}
	if not self.alive then return out end
	self:stepSparks(clock)
	local reduced=self:reduced()
	for n=self.popped+1,3 do
		local at=V2.pipPopAt(self.countAt[n],self.landAt[n],reduced)
		if not at or clock<at then break end
		self.popped=n;self.popAt[n]=clock
		self.flashAt,self.flashColor=clock,lightOf(self.tier[n]or n)
		self.wordAt,self.wordKey,self.wordTier=clock,V2.comboWord(n),self.tier[n]or n
		if n>=3 then self.finaleAt=clock end
		table.insert(out,n)
	end
	return out
end
-- The knock (WelcomeEgg3D adds the twitch to the egg's tilt): due every 4, 2.5, then 1.2 s as combos land; a quiet
-- tap. Returns the twitch (degrees) now.
-- holding (the onboarding fun pass): combo 3 is in and the deck waits for the stork: every 0.4 s.
function Deck2:knock(clock,combos,holding)
	if not self.shown then return 0 end
	local reduced=self:reduced()
	self.knockLast=self.knockLast or clock
	if V2.knockDue(clock,self.knockLast,combos,reduced,holding)then
		self.knockLast=clock;self.knockAt=clock
		local K=D.knock
		if self.d.play then pcall(self.d.play,K.cue,K.pitch,K.gain)end
	end
	if reduced or not self.knockAt then return 0 end
	return V2.knockTwitch(clock-self.knockAt)
end

-- ── Paint ───────────────────────────────────────────────────────────────────────────────────────────────────────
function Deck2:setShown(on)
	on=on==true
	if on==self.shown then return end
	self.shown=on
	for _,o in ipairs({self.fill,self.grassClip,self.grassFoot,self.shadow,self.flashFrame,self.pipRow,self.picture})do if o then o.Visible=on end end
	if not on then
		self.sweepFrame.Visible=false
		if self.word then self.word.Visible=false end
		self:clearSparks()
		self.knockLast=nil
	end
end
function Deck2:paintCard(clock,combos,drops,line,reduced)
	if not self.picture then return end
	self:layoutCard()
	for i,b in ipairs(self.bubbles)do
		local u,sway,alpha=V2.cardBubble(i,clock,reduced)
		local x=D.bubbleX[i]or .5
		set(b.node,"Position",UDim2.new(x,math.floor(sway+.5),1-u,0))
		set(b.node,"BackgroundTransparency",alpha)
		local edge=math.clamp((1-alpha)/D.bubbleAlpha,0,1)
		set(b.rim,"Transparency",1-(1-D.bubbleRim)*edge)
		set(b.spec,"BackgroundTransparency",1-.8*edge)
	end
	local kind=V2.picture(drops,combos)
	if kind~=self.kind then self.kind=kind;self.kindAt=clock end
	local t=clock-(self.kindAt or clock)
	local balls=self.balls
	local picH=self.picH or 40
	local theme=require(Shared.BallThemes).current
	local function show(b,on,x,yBottom,sx,sy,alpha)
		b.holder.Visible=on
		if not on then return end
		b.preview.set(theme,b.tier,b.expr,0,false)
		set(b.holder,"Position",UDim2.new(x,0,0,math.floor(yBottom+.5)))
		set(b.holder,"Size",UDim2.fromOffset(math.max(1,math.floor(b.size*sx+.5)),math.max(1,math.floor(b.size*sy+.5))))
		local a=math.floor(alpha*20+.5)/20
		if b.alpha~=a or b.writes~=b.preview.writes then
			b.alpha,b.writes=a,b.preview.writes
			for _,run in ipairs(b.preview.root:GetChildren())do if run:IsA("Frame")then set(run,"BackgroundTransparency",a)end end
		end
	end
	local floor=picH
	if kind=="drop"then
		local fall,sx,sy,alpha=V2.dropBall(t,reduced)
		local top=balls.drop.size+2
		show(balls.drop,true,.5,top+(floor-top)*fall,sx,sy,alpha)
	else show(balls.drop,false)end
	if kind=="match"then
		local l,r,grow,alpha=V2.matchBalls(t,reduced)
		local share=balls.left.size/math.max(1,self.cardW or 100)
		show(balls.left,grow<.6,.5+l*share,floor,1,1,alpha)
		show(balls.right,grow<.6,.5+r*share,floor,1,1,alpha)
		show(balls.merged,grow>0,.5,floor,grow,grow,alpha)
	else show(balls.left,false);show(balls.right,false);show(balls.merged,false)end
	local numeral=V2.numeral(kind)
	self.numeral.Visible=numeral~=nil
	if numeral then
		local ok,text=pcall(self.d.copy or function(k)return k end,numeral)
		set(self.numeral,"Text",if ok and type(text)=="string"then text else "")
		set(self.numeralScale,"Scale",if reduced then 1 else V2.punch(t,D.punch,D.punchTime))
	end
	-- the line: punch 1.25 with a menu tick on each change (not the first)
	if line~=self.lineText then
		if self.lineText~=nil and line~=""then
			self.punchAt=clock
			local K=D.tick
			if self.d.play then pcall(self.d.play,K.cue,K.pitch,K.gain)end
		end
		self.lineText=line
	end
	set(self.linePunch,"Scale",if reduced or not self.punchAt then 1 else V2.punch(clock-self.punchAt,D.punch,D.punchTime))
end
function Deck2:paintPips(clock,combos,reduced)
	local finale=if self.finaleAt then clock-self.finaleAt else nil
	local target
	if finale then
		-- the egg's centre in the pip row's own (authored) pixels
		local well=self.egg.well
		local row=self.pipRow
		local k=row.AbsoluteSize.X/math.max(1,row.Size.X.Offset)
		local c=(well.AbsolutePosition+well.AbsoluteSize/2-row.AbsolutePosition)/math.max(.01,k)
		target=c
	end
	for i,p in ipairs(self.pips)do
		local filled=V2.pip(i,combos)=="filled"
		set(p.foot,"BackgroundColor3",if filled then D.pipFilled else D.pipEmpty)
		set(p.crown,"BackgroundColor3",if filled then D.pipFilled else D.pipEmpty)
		set(p.glint,"Visible",filled)
		local alpha=if filled then 0 else D.pipEmptyAlpha
		local scale=1
		local popAge=if self.popAt[i]then clock-self.popAt[i]else nil
		local s,ring,ringAlpha=V2.pipPop(popAge,reduced)
		scale=s
		if i==combos+1 and combos<3 then scale*=V2.breathe(clock,reduced)end
		local pos=p.home
		if finale and target then
			local u,flyScale,fade=V2.pipFly(i,finale,reduced)
			pos=p.home:Lerp(target,u)
			scale*=flyScale
			alpha=alpha+(1-alpha)*fade
		end
		set(p.holder,"Position",UDim2.fromOffset(math.floor(pos.X+.5),math.floor(pos.Y+.5)))
		set(p.scale,"Scale",scale)
		set(p.body,"GroupTransparency",alpha)
		local showRing=ringAlpha<1 and not finale
		set(p.pop,"Visible",showRing)
		if showRing then
			local size=math.floor(D.pipW*ring+.5)
			set(p.pop,"Size",UDim2.fromOffset(size,size))
			set(p.popStroke,"Transparency",ringAlpha)
		end
	end
end
function Deck2:paintWord(clock,reduced)
	local shownWord,scale,fade=V2.wordLook(if self.wordAt then clock-self.wordAt else nil,reduced)
	if not shownWord then
		if self.word then self.word.Visible=false end
		return
	end
	local gui=self.d.sparkLayer and self.d.sparkLayer()
	local rect=self.d.wellRect
	if not gui or not rect then return end
	local ok,at,size=pcall(rect)
	if not ok or typeof(at)~="Vector2"or typeof(size)~="Vector2"then return end
	if not self.word or self.word.Parent~=gui then
		if self.word then self.word:Destroy()end
		self.word=node("TextLabel",gui,{Name="Deck2Word",BackgroundTransparency=1,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),
			Font=Enum.Font.GothamBlack,TextScaled=true,TextColor3=WHITE,TextStrokeColor3=WORD_INK,TextStrokeTransparency=.15,ZIndex=210,Active=false})
		self.wordLimit=node("UITextSizeConstraint",self.word,{MinTextSize=12,MaxTextSize=34})
		self.wordScale=node("UIScale",self.word,{Scale=1})
	end
	local word=self.word
	if self.wordShownKey~=self.wordKey then
		self.wordShownKey=self.wordKey
		local ok2,text=pcall(self.d.copy or function(k)return k end,self.wordKey)
		word.Text=if ok2 and type(text)=="string"then text else ""
		word.TextColor3=lightOf(self.wordTier):Lerp(WHITE,.55)
	end
	local p=at+Vector2.new(size.X/2,size.Y*.3)-gui.AbsolutePosition
	set(word,"Position",UDim2.fromOffset(math.floor(p.X+.5),math.floor(p.Y+.5)))
	set(word,"Size",UDim2.fromOffset(math.max(40,math.floor(size.X-12)),44))
	set(self.wordLimit,"MaxTextSize",math.clamp(math.floor(size.X*.11),18,34))
	set(self.wordScale,"Scale",scale)
	set(word,"TextTransparency",fade)
	set(word,"TextStrokeTransparency",.15+.85*fade)
	set(word,"Visible",true)
end
-- combos: the pips shown filled (popped); line: the left card's text now; holdAge: s into the fun pass's hold (nil:
-- none): the border pulses gold (V2.holdPulse) until the rise.
function Deck2:paint(clock,combos,drops,line,holdAge)
	if not self.alive or not self.shown then return end
	local reduced=self:reduced()
	self:layoutEgg()
	self:paintCard(clock,combos,drops,line,reduced)
	self:paintPips(clock,combos,reduced)
	local flash=V2.flashAlpha(if self.flashAt then clock-self.flashAt else nil)
	if holdAge then
		set(self.flash,"Transparency",math.min(flash,V2.holdPulse(holdAge,reduced)))
		set(self.flash,"Color",if flash<1 and self.flashColor then self.flashColor else D.gold)
	else
		set(self.flash,"Transparency",flash)
		if self.flashColor then set(self.flash,"Color",self.flashColor)end
	end
	local offset=V2.sweep(if self.finaleAt then clock-self.finaleAt else nil,reduced)
	set(self.sweepFrame,"Visible",offset~=nil)
	if offset then self.sweepBand.Offset=Vector2.new(offset,0)end
	self:paintWord(clock,reduced)
end
function Deck2:destroy()
	if not self.alive then return end
	self.alive=false
	self:clearSparks()
	if self.word then self.word:Destroy();self.word=nil end
	local egg=self.egg
	if egg.cover and self.coverColor then egg.cover.BackgroundColor3=self.coverColor end
	if egg.line and self.lineWas then for k,v in pairs(self.lineWas)do egg.line[k]=v end end
	for _,o in ipairs(self.made)do o:Destroy()end
	table.clear(self.made)
end
return Deck2
