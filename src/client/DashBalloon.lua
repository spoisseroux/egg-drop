-- The Garden Dash start balloon (GARDEN-PLAY-BRIEF-2 section 7, Fable 2026-11-26; Spencer: "Make the balloon above
-- garden dash start more interesting too? something more fun?"). While the start gate is the fete set (GardenDash's
-- Fete attribute, the Alive `scene` switch; DashProps.fete), a hot-air balloon tethered over the start line in place of
-- the cloth ball: a 5-stud rose envelope with four cream gores, a skirt, four ropes to a wicker basket, a burner flame
-- under the skirt, six pennants on each of the two tethers to the post tops, a starter mascot (a roster baby at .45, never
-- a player's) in the basket with a small flag, and a pool of leaf cards.
--
-- The race drives it (frame's cue: the heat's GO on this client's clock and its phase; everyone near sees it, racers
-- and onlookers): each countdown beat (3, 2, 1) the flame burns and the envelope puffs 8% (asmr_pop); on GO it jumps
-- 1.5 studs, drops 20 leaf cards in the accents and the mascot swings its flag (spin_whoosh); when the results come the
-- mascot hops twice. Between races it bobs, the bunting flutters 10 degrees and the burner flares now and then.
--
-- Local, anchored, never collides, touches or answers a raycast. Nothing hangs below DashFete.Clear (9.6) over the
-- lanes: the basket's bottom is 12.25 up and a card fades before it falls under 10.1. Its own budget (Balloon.MaxParts)
-- and folder, apart from the race props' 60. Drawn only within the cull distance (90 studs on a phone, 150 elsewhere).
-- Reduced Motion: it hangs still (no bob, flutter, puff, jump, hop, swing or cards); the sounds stay.
local Shared=game:GetService("ReplicatedStorage").Shared
local Course=require(Shared.DashCourse)
local Grid=require(Shared.DashGrid)
local Balloon={};Balloon.__index=Balloon
Balloon.FolderName="GardenDashBalloon"
Balloon.MaxParts=48
Balloon.Height=18          -- the envelope's middle over the start line (the old ball's was 16; the basket hangs under it)
Balloon.Cull=table.freeze({phone=90,desktop=150})
local hex=Color3.fromHex
Balloon.Look=table.freeze({
	envelope=5,envelopeColour=hex("#D9776B"),gore=hex("#EFE6D2"),goreWidth=.08,
	skirt=Vector2.new(.83,2.0),skirtY=-2.67,
	rope=Vector2.new(.06,1.6),ropeColour=hex("#8A6A3C"),ropeTop=-3.0,ropeTopOut=.95,ropeLowOut=.68,
	basket=Vector3.new(1.5,1.15,1.5),basketColour=hex("#8A6A3C"),rim=Vector3.new(1.58,.12,1.58),rimColour=hex("#6B4A2E"),basketTop=-4.6,
	flame=.45,flameColour=hex("#FFB347"),flameY=-3.3,
	tether=hex("#B79A66"),tetherWidth=.08,postTop=11.85, -- DashFete.Start: the posts' cap tops
	pennant=Vector3.new(.04,.4,.5),accents=table.freeze({hex("#E8785A"),hex("#7FB8A4"),hex("#F2C14E")}),pennants=6,
	pole=Vector2.new(.04,1.0),poleColour=hex("#6B4A2E"),flag=Vector3.new(.04,.4,.6),flagColour=hex("#F2C14E"),
	card=Vector3.new(.5,.04,.36),cards=20,
})
-- The motion ([PLACEHOLDER]s to tune in Studio).
Balloon.Motion=table.freeze({
	bob=.6,period=4,                 -- as the old ball
	flutter=10,flutterHz=1.3,        -- the pennants, degrees about their rope
	puff=.08,puffTime=.4,            -- a countdown beat: the envelope 8% bigger and back in two wobbles
	burn=1.6,burnTime=.5,            -- the flame on a beat (and the idle flare, smaller)
	idleBurn=1.35,idleEvery=7,idleSpread=3,idleLift=.3,
	jump=1.5,jumpTime=1.4,           -- GO
	swing=40,swingTime=1.1,          -- the mascot's flag on GO
	hop=.5,hopTime=.34,hops=2,       -- the results: two hops
	cardLife=2.6,cardFade=.4,cardFall=2.2,cardOut=3.2,cardFloor=10.1,
	beatWindow=.5,                   -- a beat (or GO) is played only this soon after its time (a late join skips it)
})
Balloon.Mascot=table.freeze({scale=.45,floor=-5.6,turn=0,flag=Vector3.new(.42,-4.95,-.25)})
Balloon.Sounds=table.freeze({pop=table.freeze({"asmr_pop_a","asmr_pop_b","asmr_pop_c"}),popVolume=.55,go="spin_whoosh",goVolume=.5})

-- Pure motion ------------------------------------------------------------------------------------------------------
local function ease(u)u=math.clamp(u,0,1);return u*u*(3-2*u)end
-- 0 at u 0, 1 at `rise`, back to 0 in two wobbles by u 1.
local function wobble(u,rise)
	if u<=0 or u>=1 then return 0 end
	if u<rise then return ease(u/rise)end
	local k=(u-rise)/(1-rise)
	return math.cos(k*math.pi*4)*(1-k)^2
end
Balloon.wobble=wobble
-- The envelope's scale `t` after a beat (1 outside).
function Balloon.puff(t)return 1+Balloon.Motion.puff*wobble(t/Balloon.Motion.puffTime,.3)end
-- The flame's scale `t` after a burn of `size` (1.6 on a beat).
function Balloon.burn(t,size)
	local M=Balloon.Motion
	local u=t/M.burnTime
	if u<=0 or u>=1 then return 1 end
	return 1+((size or M.burn)-1)*math.sin(math.pi*u)
end
-- The rig's lift `t` after GO (studs).
function Balloon.jump(t)return Balloon.Motion.jump*wobble(t/Balloon.Motion.jumpTime,.25)end
-- The mascot's hop `t` after the results came (studs): two hops.
function Balloon.hop(t)
	local M=Balloon.Motion
	if t<=0 or t>=M.hopTime*M.hops then return 0 end
	local u=(t%M.hopTime)/M.hopTime
	return M.hop*4*u*(1-u)
end
-- The flag's swing `t` after GO (radians).
function Balloon.swing(t)
	local M=Balloon.Motion
	local u=t/M.swingTime
	if u<=0 or u>=1 then return 0 end
	return math.rad(M.swing)*math.sin(u*math.pi*5)*(1-u)
end
local function hash(seed,i,k)
	local x=math.sin(seed*12.9898+i*78.233+k*37.719)*43758.5453
	return x-math.floor(x)
end
-- A GO leaf card `t` seconds in: its offset from the basket's bottom (rig axes: X along the start line, Z along the
-- course), its turn and how seen it is. It pops out sideways (along the line, away from the lanes' middle), flutters down
-- and fades before it drops `floorDrop` under the basket.
function Balloon.card(seed,i,t,floorDrop)
	local M=Balloon.Motion
	local side=if i%2==0 then 1 else -1
	local out=M.cardOut*(.5+.5*hash(seed,i,1))
	local a=(hash(seed,i,2)-.5)*1.2
	local spread=1-math.exp(-t*1.6)
	local pop,g=1.6+hash(seed,i,3)*1.2,8
	local t1=(pop+M.cardFall)/g -- it falls no faster than cardFall (a fluttering card)
	local y=if t<t1 then pop*t-.5*g*t*t else pop*t1-.5*g*t1*t1-M.cardFall*(t-t1)
	y=math.max(y,-floorDrop)
	local flutter=.25*math.sin(t*9+i)
	local seen=1-math.clamp((t-(M.cardLife-M.cardFade))/M.cardFade,0,1)
	seen=math.min(seen,math.clamp((y+floorDrop)/.3,0,1)) -- gone before it reaches the floor
	return Vector3.new(side*out*spread+flutter,y,out*.5*math.sin(a)*spread),math.sin(t*6+i)*1.2,t*(3+hash(seed,i,4)*2)*side,seen
end

-- Pure: the race's cues since the last call. state (the balloon's memory) and cue {raceId, goAt, phase} (nil: no race).
-- Answers {kind = "beat" | "go" | "finish", at}: a beat at GO - 3, - 2, - 1, GO at GO, the finish when the phase turns to
-- results; each once a race, and a beat or GO only within Motion.beatWindow of its time.
function Balloon.cues(state,now,cue)
	local out={}
	if type(cue)~="table"or type(cue.goAt)~="number"or cue.raceId==nil then return out end
	if state.raceId~=cue.raceId then state.raceId,state.fired,state.finished=cue.raceId,{},false end
	local window=Balloon.Motion.beatWindow
	for k=3,0,-1 do
		local at=cue.goAt-k
		if not state.fired[k]and now>=at then
			state.fired[k]=true
			if now-at<=window then table.insert(out,{kind=if k==0 then "go"else "beat",at=at})end
		end
	end
	if cue.phase=="results"and not state.finished then
		state.finished=true
		table.insert(out,{kind="finish",at=now})
	end
	return out
end

-- Building ---------------------------------------------------------------------------------------------------------
local function part(parent,name,size,colour,shape,material,class)
	local item=Instance.new(class or "Part")
	item.Name=name;item.Size=size;item.Color=colour
	if shape then item.Shape=shape end
	item.Anchored=true;item.CanCollide=false;item.CanQuery=false;item.CanTouch=false;item.CastShadow=false
	item.Material=material or Enum.Material.SmoothPlastic
	item.TopSurface=Enum.SurfaceType.Smooth;item.BottomSurface=Enum.SurfaceType.Smooth
	item.Parent=parent
	return item
end
local UPRIGHT=CFrame.Angles(0,0,math.pi/2) -- a Cylinder's axis (X) turned to the world's up

-- parent: where the folder goes; options (specs): mascot(folder, origin) -> a pet visual or nil, sound(cue, part,
-- volume, speed), camera() -> Vector3, phone() -> bool, terrain.
function Balloon.new(parent,options)
	options=options or {}
	local self=setmetatable({parent=parent,o=options,parts={},locals={},count=0,state={},cards={},pennants={},seed=1}
		,Balloon)
	local L=Balloon.Look
	local folder=Instance.new("Folder");folder.Name=Balloon.FolderName;folder.Parent=parent
	self.folder=folder
	local x,y,z,yaw=Course.at(0)
	self.ground=y
	self.at=CFrame.new(x,y+Balloon.Height,z)*CFrame.Angles(0,yaw,0)
	self.yaw=yaw
	local function add(name,size,colour,shape,frame,material,class)
		if self.count>=Balloon.MaxParts then return nil end
		self.count+=1
		local item=part(folder,name,size,colour,shape,material,class)
		table.insert(self.parts,item);table.insert(self.locals,frame)
		item.CFrame=self.at*frame
		return item,#self.parts
	end
	local matte,wood,neon=Enum.Material.SmoothPlastic,Enum.Material.Wood,Enum.Material.Neon
	local d=L.envelope
	self.envelope,self.envelopeIndex=add("Envelope",Vector3.one*d,L.envelopeColour,Enum.PartType.Ball,CFrame.identity,matte)
	self.gores={}
	for k=0,3 do
		local gore=add("Gore"..(k+1),Vector3.new(L.goreWidth,d+.06,d+.06),L.gore,Enum.PartType.Cylinder,CFrame.Angles(0,k*math.pi/4,0),matte)
		table.insert(self.gores,gore)
	end
	add("Skirt",Vector3.new(L.skirt.X,L.skirt.Y,L.skirt.Y),L.envelopeColour,Enum.PartType.Cylinder,CFrame.new(0,L.skirtY,0)*UPRIGHT,matte)
	local low=L.basketTop+.02
	for k=0,3 do
		local a=k*math.pi/2+math.pi/4
		local top=Vector3.new(math.cos(a)*L.ropeTopOut,L.ropeTop,math.sin(a)*L.ropeTopOut)
		local foot=Vector3.new(math.cos(a)*L.ropeLowOut*math.sqrt(2),low,math.sin(a)*L.ropeLowOut*math.sqrt(2))
		local mid,along=(top+foot)/2,(top-foot)
		add("Rope"..(k+1),Vector3.new(along.Magnitude,L.rope.X,L.rope.X),L.ropeColour,Enum.PartType.Cylinder,
			CFrame.lookAt(mid,mid+along)*CFrame.Angles(0,math.pi/2,0),matte)
	end
	self.basket=add("Basket",L.basket,L.basketColour,nil,CFrame.new(0,L.basketTop-L.basket.Y/2,0),wood)
	add("BasketRim",L.rim,L.rimColour,nil,CFrame.new(0,L.basketTop,0),wood)
	self.flame,self.flameIndex=add("Flame",Vector3.one*L.flame,L.flameColour,Enum.PartType.Ball,CFrame.new(0,L.flameY,0),neon)
	-- The mascot's flag: a pole and a pennant on it, swung about the pole's foot.
	local M=Balloon.Mascot
	self.flagFoot=CFrame.new(M.flag)
	self.pole,self.poleIndex=add("FlagPole",Vector3.new(L.pole.Y,L.pole.X,L.pole.X),L.poleColour,Enum.PartType.Cylinder,
		self.flagFoot*CFrame.new(0,L.pole.Y/2,0)*UPRIGHT,wood)
	self.flagPart,self.flagIndex=add("Flag",L.flag,L.flagColour,nil,self.flagFoot*CFrame.new(0,L.pole.Y-L.flag.Y/2,L.flag.Z/2),matte)
	-- The tethers: a basket corner on each side to that post's top (Beams; Attachments ride the basket part).
	self.tethers={}
	local terrain=options.terrain or workspace:FindFirstChildOfClass("Terrain")
	local course=CFrame.new(x,y,z)*CFrame.Angles(0,yaw,0)
	for _,side in ipairs({-1,1})do
		local post=(course*CFrame.new(side*Grid.PostOut/100,L.postTop,0)).Position
		local corner=Vector3.new(side*L.basket.X/2,-L.basket.Y/2,0)
		local top=Instance.new("Attachment");top.Name="BalloonRope";top.Position=corner;top.Parent=self.basket
		local foot=Instance.new("Attachment");foot.Name="DashBalloonFoot";foot.WorldPosition=post;foot.Parent=terrain or self.basket
		local rope=Instance.new("Beam");rope.Name="BalloonRope";rope.Attachment0,rope.Attachment1=top,foot
		rope.Width0,rope.Width1=L.tetherWidth,L.tetherWidth;rope.FaceCamera=true;rope.Segments=1
		rope.Color=ColorSequence.new(L.tether);rope.LightEmission=0;rope.LightInfluence=1
		rope.Parent=self.basket
		table.insert(self.tethers,{side=side,post=post,corner=CFrame.new(side*L.basket.X/2,L.basketTop-L.basket.Y,0),foot=foot,rope=rope})
		for k=1,L.pennants do
			local p=add("Pennant",L.pennant,L.accents[(k+(if side>0 then 1 else 0))%#L.accents+1],nil,CFrame.identity,matte,"WedgePart")
			if p then table.insert(self.pennants,{part=p,index=#self.parts,side=side,k=k})end
		end
	end
	-- The GO cards, parked out of sight in the basket.
	for k=1,L.cards do
		local card=add("GoCard",L.card,L.accents[(k-1)%#L.accents+1],nil,CFrame.new(0,L.basketTop-.4,0),matte)
		if card then card.Transparency=1;table.insert(self.cards,{part=card,index=#self.parts,k=k,at=nil})end
	end
	folder:SetAttribute("BalloonParts",self.count)
	-- The starter mascot: a roster baby, never a player's.
	self.mascot=Balloon.makeMascot(self,options)
	self.drawn=false
	self:pose(0,true,0)
	return self
end
-- A roster baby at Mascot.scale in the basket (nil when PetFactory is not there, or it fails).
function Balloon.makeMascot(self,options)
	local origin=(self.at*CFrame.new(0,Balloon.Mascot.floor,0)).Position
	if options.mascot then return options.mascot(self.folder,origin)end
	local ok,visual=pcall(function()
		local roster=require(Shared.PetCatalog).active
		if not roster or #roster==0 then return nil end
		local pet=roster[Random.new():NextInteger(1,#roster)]
		local made=require(script.Parent.PetFactory).new(self.folder,origin,pet,Balloon.Mascot.scale,nil,{priority=3})
		made.yaw=self.yaw+Balloon.Mascot.turn
		return made
	end)
	if ok then return visual end
	warn("[Dash] balloon mascot: "..tostring(visual))
	return nil
end

function Balloon:cull()
	local phone=if self.o.phone then self.o.phone()else(function()
		local input=game:GetService("UserInputService")
		return input.TouchEnabled==true and input.KeyboardEnabled~=true
	end)()
	return if phone then Balloon.Cull.phone else Balloon.Cull.desktop
end
function Balloon:sound(kind)
	local S=Balloon.Sounds
	local cue=if kind=="go"then S.go else S.pop[math.random(1,#S.pop)]
	local volume=if kind=="go"then S.goVolume else S.popVolume
	local speed=1+(math.random()*2-1)*.06
	if self.o.sound then return self.o.sound(cue,self.envelope,volume,speed)end
	pcall(function()
		local Audio=require(script.Parent.BoardAudio)
		local id=Audio.AsmrIds and Audio.AsmrIds[cue]
		local uri=if type(id)=="number"and id>0 then "rbxassetid://"..id else Audio.uri(cue)
		if not uri then return end
		local sound=Instance.new("Sound")
		sound.SoundId=uri;sound.Volume=volume;sound.PlaybackSpeed=speed
		sound.RollOffMinDistance=12;sound.RollOffMaxDistance=120
		sound.SoundGroup=game:GetService("SoundService"):FindFirstChild("EggDropSFX")
		sound.Parent=self.envelope
		sound.Ended:Once(function()sound:Destroy()end)
		task.delay(4,function()if sound.Parent then sound:Destroy()end end)
		sound:Play()
	end)
end

-- Once a frame. now: the race clock (workspace:GetServerTimeNow); still: Reduced Motion; cue: {raceId, goAt, phase}.
function Balloon:frame(now,still,cue,dt)
	for _,event in ipairs(Balloon.cues(self.state,now,cue))do
		if event.kind=="beat"then self.beatAt=event.at;self.burnAt,self.burnSize=event.at,Balloon.Motion.burn;self:sound("beat")
		elseif event.kind=="go"then
			self.goAt=event.at;self.burnAt,self.burnSize=event.at,Balloon.Motion.burn;self:sound("go")
			if not still then self.seed+=1;for _,card in ipairs(self.cards)do card.at=event.at end end
		else self.finishAt=event.at end
	end
	-- The idle flare, now and then.
	local M=Balloon.Motion
	self.nextBurn=self.nextBurn or now+M.idleEvery
	if now>=self.nextBurn then
		self.nextBurn=now+M.idleEvery+(math.random()*2-1)*M.idleSpread
		if not self.burnAt or now-self.burnAt>M.burnTime then self.burnAt,self.burnSize=now,M.idleBurn end
	end
	local camera=if self.o.camera then self.o.camera()else(workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
	local near=typeof(camera)~="Vector3"or(camera-self.at.Position).Magnitude<=self:cull()
	if not near then return end
	self:pose(now,still,dt or 0)
end

function Balloon:pose(now,still,dt)
	local M,L=Balloon.Motion,Balloon.Look
	local lift=0
	if not still then
		lift=M.bob*math.sin(now/M.period*math.pi*2)
		if self.goAt then lift+=Balloon.jump(now-self.goAt)end
		if self.burnAt and self.burnSize==M.idleBurn then lift+=M.idleLift*math.sin(math.pi*math.clamp((now-self.burnAt)/M.burnTime,0,1))end
	end
	local root=self.at*CFrame.new(0,lift,0)
	local frames={}
	for i,frame in ipairs(self.locals)do frames[i]=root*frame end
	-- The envelope's puff (sizes, only while it moves) and the flame's burn.
	local puff=if still or not self.beatAt then 1 else Balloon.puff(now-self.beatAt)
	if puff~=self.puffed then
		self.puffed=puff
		local d=L.envelope*puff
		if self.envelope then self.envelope.Size=Vector3.one*d end
		for _,gore in ipairs(self.gores)do gore.Size=Vector3.new(L.goreWidth,d+.06,d+.06)end
	end
	local burn=if self.burnAt then Balloon.burn(now-self.burnAt,self.burnSize)else 1
	if burn~=self.burned and self.flame then self.burned=burn;self.flame.Size=Vector3.one*L.flame*burn end
	-- The flag: swung about its foot on GO.
	local swing=if still or not self.goAt then 0 else Balloon.swing(now-self.goAt)
	local foot=root*self.flagFoot*CFrame.Angles(0,0,swing)
	if self.poleIndex then frames[self.poleIndex]=foot*CFrame.new(0,L.pole.Y/2,0)*UPRIGHT end
	if self.flagIndex then frames[self.flagIndex]=foot*CFrame.new(0,L.pole.Y-L.flag.Y/2,L.flag.Z/2)end
	-- The bunting: six pennants along each tether, hanging under it, fluttering.
	for _,pennant in ipairs(self.pennants)do
		local tether=self.tethers[if pennant.side<0 then 1 else 2]
		local from=(root*tether.corner).Position
		local along=tether.post-from
		local f=pennant.k/(L.pennants+1)
		local at=from+along*f
		local flutter=if still then 0 else math.rad(M.flutter)*math.sin(now*M.flutterHz*math.pi*2+pennant.k*1.7+pennant.side)
		-- A WedgePart turned over: its long top edge along the rope, its point hanging down at one end.
		frames[pennant.index]=CFrame.lookAt(at,at+along)*CFrame.Angles(0,0,flutter)*CFrame.new(0,-L.pennant.Y/2,0)*CFrame.Angles(math.pi,0,0)
	end
	-- The GO cards.
	local basketLow=root*CFrame.new(0,L.basketTop-L.basket.Y,0)
	local floorDrop=math.max(.5,basketLow.Position.Y-(self.ground+M.cardFloor))
	for _,card in ipairs(self.cards)do
		if card.at then
			local t=now-card.at
			if t>=M.cardLife or still or t<0 then
				if t>=M.cardLife or still then card.at=nil end
				card.part.Transparency=1
			else
				local offset,rx,ry,seen=Balloon.card(self.seed,card.k,t,floorDrop)
				card.part.Transparency=1-seen
				frames[card.index]=basketLow*CFrame.new(offset)*CFrame.Angles(rx,ry,0)
			end
		end
	end
	workspace:BulkMoveTo(self.parts,frames,Enum.BulkMoveMode.FireCFrameChanged)
	-- The mascot: in the basket, hopping when the results come.
	local mascot=self.mascot
	if mascot and not mascot.destroyed then
		local hop=if still or not self.finishAt then 0 else Balloon.hop(now-self.finishAt)
		mascot.origin=(root*CFrame.new(0,Balloon.Mascot.floor+hop,0)).Position
		mascot.yaw=self.yaw+Balloon.Mascot.turn
		mascot.reducedEffects=still
		if mascot.update then pcall(mascot.update,mascot,dt)end
	end
end

function Balloon:destroy()
	if self.mascot and self.mascot.destroy then pcall(self.mascot.destroy,self.mascot)end
	for _,tether in ipairs(self.tethers or {})do if tether.foot then tether.foot:Destroy()end end
	if self.folder then self.folder:Destroy();self.folder=nil end
	self.mascot=nil
end
return Balloon
