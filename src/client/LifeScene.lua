-- The garden's scene, the parts (beta 14 QA W3; WORLD-AND-NEST-LOOK section 1; GARDEN-LIFE-BUILD-PLAN section 4):
-- dapple under the nearest crowns, koi and their rise rings in the falls pool, a far flock, dragonflies over the water,
-- the lamps lighting one by one at dusk and a shooting star a night. LifeSceneSim decides; this owns the parts.
-- Made by GardenLife only while the Alive `life` AND `scene` switches are on (the beta place and Studio: their ceiling),
-- inside its folder, and stepped from its one Heartbeat: every moving part goes through its put / hide (one BulkMoveTo,
-- hidden at once when GardenLife parks). Client only, looks only. A texture still pending upload (LifeArtR4 id nil)
-- builds nothing for that item.
--   Reduced Motion: no koi, flock, dragonflies or star; the dapple is static shade; lamps light all at once.
--   Budget level 1: 3 dapple, 2 koi, 3 birds, 1 dragonfly, no PointLights. Level 2: GardenLife is torn down.
-- deps: kit {folder, part, decal, spindle}, art(key) -> id?, crowns {Vector3} (the ground under every kit crown),
--   boxes {{frame, hx, hz, y}} (the water), hourClock(now) -> the garden hour's clock (server time + its offset; nil
--   with the hour off: no lamps, no star), hourDaylight(s) -> daylight at hour-second s (to place the lamps' dusk), seed.
local Sim=require(script.Parent.LifeSceneSim)

local Scene={};Scene.__index=Scene
local Face=Enum.NormalId

local function smoothIn(t,length)
	if length<=0 then return 1 end
	local x=math.clamp(t/length,0,1)
	return x*x*(3-2*x)
end

local function flatPlate(kit,name,size,texture,colour)
	local p=kit.part(kit.folder,name,"Part",size,false)
	local d=kit.decal(p,Face.Top,texture,colour or Color3.new(1,1,1))
	return p,d
end

function Scene.new(deps)
	local self=setmetatable({d=deps,kit=deps.kit,seed=deps.seed or 20261123},Scene)
	local kit,art=self.kit,deps.art
	-- Dapple (row 3): 6 plates, the shade texture tinted dark green.
	self.dapple={}
	local dapple=art("dapple")
	if dapple then
		local D=Sim.Dapple
		for slot=1,Sim.Caps.dapple[1]do
			local p,d=flatPlate(kit,"SceneDapple"..slot,Vector3.new(D.size,.05,D.size),dapple,D.colour)
			self.dapple[slot]={part=p,decal=d,crown=nil,shown=nil,since=0}
		end
	end
	-- Koi (row 4): 3 plates under the water, 3 rings on it.
	self.koi,self.rings={},{}
	local K=Sim.Koi
	local files={art("koiA"),art("koiB"),art("koiC")}
	if files[1]and files[2]and files[3]then
		for k=1,Sim.Caps.koi[1]do
			local p,d=flatPlate(kit,"SceneKoi"..k,K.size,files[k])
			if K.over then d.Transparency=K.overTransparency end
			self.koi[k]={part=p,decal=d}
		end
		for k=1,3 do
			local p,d=flatPlate(kit,"SceneRipple"..k,Vector3.new(K.ripple.from,.02,K.ripple.from),art("ripple"))
			self.rings[k]={part=p,decal=d,start=nil,size=K.ripple.from}
		end
	end
	self.shift,self.shy=Vector3.zero,0
	self.random=Random.new(self.seed)
	self.riseAt=nil
	-- The far flock (row 5): 5 birds x 2 plain wing plates.
	self.flock={}
	local F=Sim.Flock
	for k=1,Sim.Caps.flock[1]do
		local left=kit.part(kit.folder,"SceneFlock"..k.."_L","Part",F.wing,F.colour)
		local right=kit.part(kit.folder,"SceneFlock"..k.."_R","Part",F.wing,F.colour)
		self.flock[k]={left,right}
	end
	-- Dragonflies (row 8): a body spindle and two pale wing plates each.
	self.flies={}
	local DF=Sim.Dragonfly
	for k=1,Sim.Caps.dragonflies[1]do
		local body=kit.part(kit.folder,"SceneDragonfly"..k.."_Body","Part",DF.body,DF.bodyColour)
		kit.spindle(body)
		local wl=kit.part(kit.folder,"SceneDragonfly"..k.."_WingL","Part",DF.wing,DF.wingColour)
		local wr=kit.part(kit.folder,"SceneDragonfly"..k.."_WingR","Part",DF.wing,DF.wingColour)
		wl.Transparency,wr.Transparency=DF.wingTransparency,DF.wingTransparency
		self.flies[k]={body,wl,wr}
	end
	self.dragonflies=Sim.Dragonflies.new(self.seed+1)
	-- Lamps (row 6): one still anchor at the origin, an Attachment a lamp with a warm halo, a PointLight on the nearest 4
	-- (level 0 only). Nothing here moves; levels are written on change.
	local L=Sim.Lamp
	self.lampAnchor=kit.part(kit.folder,"SceneLamps","Part",Vector3.new(.2,.2,.2),false)
	self.lampAnchor.CFrame=CFrame.identity
	self.lamps={}
	self.order=Sim.lampOrder()
	self.rank={}
	for rank,i in ipairs(self.order)do self.rank[i]=rank end
	for i,at in ipairs(Sim.Lamps)do
		local a=Instance.new("Attachment")
		a.Name="Lamp"..i
		a.Position=at
		a.Parent=self.lampAnchor
		local gui=Instance.new("BillboardGui")
		gui.Name="Halo"
		gui.Size=UDim2.fromScale(L.halo,L.halo)
		gui.LightInfluence=0
		gui.Brightness=1.5
		gui.AlwaysOnTop=false
		gui.MaxDistance=200
		gui.Active=false
		gui.Enabled=false
		gui.Adornee=a
		gui.Parent=a
		local dot=Instance.new("ImageLabel")
		dot.Name="Dot"
		dot.Size=UDim2.fromScale(1,1)
		dot.BackgroundTransparency=1
		dot.Image=art("halo")or ""
		dot.ImageColor3=L.colour
		dot.ImageTransparency=1
		dot.Parent=gui
		local light=Instance.new("PointLight")
		light.Name="Light"
		light.Color=L.colour
		light.Range=L.range
		light.Brightness=0
		light.Shadows=false
		light.Enabled=false
		light.Parent=a
		self.lamps[i]={attachment=a,gui=gui,dot=dot,light=light,level=0,lit=false}
	end
	-- The shooting star (row 6): one Beam between two attachments on a still anchor, on for .7 s a streak.
	local S=Sim.Star
	self.starAnchor=kit.part(kit.folder,"SceneStar","Part",Vector3.new(.2,.2,.2),false)
	self.starAnchor.CFrame=CFrame.identity
	local tail,head=Instance.new("Attachment"),Instance.new("Attachment")
	tail.Name,head.Name="Tail","Head"
	tail.Parent,head.Parent=self.starAnchor,self.starAnchor
	local beam=Instance.new("Beam")
	beam.Name="Streak"
	beam.Attachment0,beam.Attachment1=tail,head
	beam.Width0,beam.Width1=S.width*.4,S.width
	beam.Color=ColorSequence.new(S.colour)
	beam.LightEmission,beam.LightInfluence=1,0
	beam.FaceCamera=true
	beam.Segments=1
	beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.7,.3),NumberSequenceKeypoint.new(1,0)})
	beam.Enabled=false
	beam.Parent=self.starAnchor
	self.star={tail=tail,head=head,beam=beam,on=false,key=nil,camera=nil}
	self.dappleIn,self.koiIn,self.flockIn=0,0,0
	self.cross=nil
	return self
end

-- The lamps' dusk and dawn in the hour (once; the hour is the same every hour).
function Scene:crossings()
	if self.cross==nil then
		local ok,cross=pcall(Sim.crossings,self.d.hourDaylight)
		self.cross=if ok and cross then cross else false
	end
	return self.cross or nil
end

-- One step. ctx {now, tick, level, reduced, eye (Vector3), camera (CFrame), player (Vector3?), daylight (nil: the hour
-- off, day), blow(position, now) (the gust or the breath), put(part, frame), hide(part)}.
function Scene:step(ctx)
	local now,tick,level,reduced=ctx.now,ctx.tick,ctx.level,ctx.reduced
	local put,hide=ctx.put,ctx.hide
	local day=ctx.daylight==nil or ctx.daylight>.7
	self:stepDapple(ctx)
	-- Koi and rings.
	if #self.koi>0 then
		local count=if reduced then 0 else Sim.cap("koi",level)
		self.koiIn-=tick
		local write=self.koiIn<=0
		if write then self.koiIn=1/Sim.Koi.hz end
		self.shift,self.shy=Sim.koiShift(self.shift,ctx.player,tick)
		for k,koi in ipairs(self.koi)do
			if k<=count then
				if write then put(koi.part,(Sim.koiPose(k,now,self.shift,self.shy)))end
			else hide(koi.part)end
		end
		if count>0 then
			self.riseAt=self.riseAt or now+self.random:NextNumber(Sim.Koi.rise[1],Sim.Koi.rise[2])
			if now>=self.riseAt then
				self.riseAt=now+self.random:NextNumber(Sim.Koi.rise[1],Sim.Koi.rise[2])
				for _,ring in ipairs(self.rings)do
					if not ring.start then
						local _,at=Sim.koiPose(self.random:NextInteger(1,count),now,self.shift,self.shy)
						ring.start,ring.at=now,Vector3.new(at.X,Sim.Pool.centre.Y+Sim.Koi.ripple.lift,at.Z)
						break
					end
				end
			end
		end
		for _,ring in ipairs(self.rings)do
			local size,transparency
			if ring.start and count>0 then size,transparency=Sim.ripple(now-ring.start)end
			if size then
				-- A ring grows: the one place a part is resized (3 small plates, 1.4 s at a time).
				if math.abs(size-ring.size)>.01 then ring.size=size;ring.part.Size=Vector3.new(size,.02,size)end
				ring.decal.Transparency=transparency
				put(ring.part,CFrame.new(ring.at))
			else
				ring.start=nil
				hide(ring.part)
			end
		end
	end
	-- The far flock (shared flights, by day).
	local n,age=Sim.flockAt(now)
	local birds=if n and day and not reduced then Sim.cap("flock",level)else 0
	self.flockIn-=tick
	local writeFlock=self.flockIn<=0
	if writeFlock then self.flockIn=1/Sim.Flock.hz end
	local frames=if birds>0 and writeFlock then Sim.flockBirds(n,age,now,birds)else nil
	for k,pair in ipairs(self.flock)do
		if k<=birds then
			if frames then put(pair[1],frames[k][1]);put(pair[2],frames[k][2])end
		else hide(pair[1]);hide(pair[2])end
	end
	-- Dragonflies (by day).
	local flies=self.dragonflies:step(now,self.d.boxes,ctx.eye,if reduced then 0 else Sim.cap("dragonflies",level),day)
	for k,parts in ipairs(self.flies)do
		local fly=flies[k]
		if fly then
			local list=Sim.dragonflyParts(fly,now)
			for i,p in ipairs(parts)do put(p,list[i])end
		else for _,p in ipairs(parts)do hide(p)end end
	end
	self:stepLamps(ctx)
	self:stepStar(ctx)
end

-- Dapple: the nearest crowns re-picked every second; a plate moving to another crown fades out and in; static shade
-- under Reduced Motion; the decal follows the daylight.
function Scene:stepDapple(ctx)
	if #self.dapple==0 then return end
	local D=Sim.Dapple
	local now,level=ctx.now,ctx.level
	local count=Sim.cap("dapple",level)
	self.pickIn=(self.pickIn or 0)-ctx.tick
	if self.pickIn<=0 or self.picked==nil then
		self.pickIn=D.pick
		self.picked=Sim.nearest(self.d.crowns,ctx.eye,count)
	end
	self.dappleIn-=ctx.tick
	local write=self.dappleIn<=0
	if write then self.dappleIn=1/D.hz end
	local base=Sim.dappleTransparency(ctx.daylight)
	for slot,entry in ipairs(self.dapple)do
		local i=self.picked[slot]
		if slot>count or not i or base>=1 then
			if entry.crown then ctx.hide(entry.part);entry.crown=nil;entry.shown=nil end
		else
			if entry.crown~=i then entry.crown,entry.since=i,now end
			local fade=smoothIn(now-entry.since,D.fade)
			local transparency=base+(1-base)*(1-fade)
			if entry.shown==nil or math.abs(entry.shown-transparency)>.01 then entry.shown=transparency;entry.decal.Transparency=transparency end
			if write or entry.frameFor~=i then
				entry.frameFor=i
				local centre=self.d.crowns[i]
				local g=if ctx.reduced then 0 else ctx.blow(centre,now)
				local t=if ctx.reduced then 0 else now
				ctx.put(entry.part,Sim.dapplePose(centre,t,g,(i*1.7)%9))
			end
		end
	end
end

-- Lamps: levels on the shared hour clock, written only when they change; PointLights on the nearest 4 at level 0.
function Scene:stepLamps(ctx)
	local L=Sim.Lamp
	local clock=self.d.hourClock and self.d.hourClock(ctx.now)
	local s=if type(clock)=="number"then clock%Sim.Period else nil
	local cross=s and self:crossings()
	local lights=Sim.cap("lights",ctx.level)
	local lit={}
	if lights>0 and typeof(ctx.eye)=="Vector3"then
		for k,i in ipairs(Sim.nearest(Sim.Lamps,ctx.eye,lights))do lit[i]=k end
	end
	for i,lamp in ipairs(self.lamps)do
		local level=if cross then Sim.lampLevel(self.rank[i],s,cross,ctx.reduced)else 0
		if math.abs(level-lamp.level)>.01 or(level==0)~=(lamp.level==0)then
			lamp.level=level
			lamp.gui.Enabled=level>0
			lamp.dot.ImageTransparency=1-(1-L.haloTransparency)*level
		end
		local want=lit[i]~=nil and level>0
		if want~=lamp.lit or(want and math.abs(lamp.light.Brightness-L.brightness*level)>.02)then
			lamp.lit=want
			lamp.light.Enabled=want
			lamp.light.Brightness=if want then L.brightness*level else 0
		end
	end
end

-- The shooting star: the streak's timing is shared; its place is fixed for this camera when it starts.
function Scene:stepStar(ctx)
	local star=self.star
	local t=self.d.hourClock and self.d.hourClock(ctx.now)
	local j,u,hour
	if t and not ctx.reduced then j,u,hour=Sim.starAt(t)end
	if j then
		local key=hour*4+j
		if star.key~=key then star.key,star.camera=key,ctx.camera end
		local head,tail=Sim.starStreak(hour,j,u,star.camera)
		star.head.Position,star.tail.Position=head,tail
		if not star.on then star.on=true;star.beam.Enabled=true end
	elseif star.on then
		star.on=false
		star.beam.Enabled=false
	end
end

-- Parked (a hatch, a deck round, my own race): GardenLife's park has hidden every moving part; lamps stay as they are
-- (light, not motion); the star goes out.
function Scene:park()
	self.dragonflies:clear()
	self.picked=nil
	for _,entry in ipairs(self.dapple)do entry.crown=nil;entry.shown=nil end
	for _,ring in ipairs(self.rings)do ring.start=nil end
	if self.star.on then self.star.on=false;self.star.beam.Enabled=false end
end

function Scene:destroy()
	self:park()
	for _,lamp in ipairs(self.lamps)do lamp.gui.Enabled=false;lamp.light.Enabled=false end
	local parts={self.lampAnchor,self.starAnchor}
	for _,entry in ipairs(self.dapple)do table.insert(parts,entry.part)end
	for _,koi in ipairs(self.koi)do table.insert(parts,koi.part)end
	for _,ring in ipairs(self.rings)do table.insert(parts,ring.part)end
	for _,pair in ipairs(self.flock)do table.insert(parts,pair[1]);table.insert(parts,pair[2])end
	for _,list in ipairs(self.flies)do for _,p in ipairs(list)do table.insert(parts,p)end end
	for _,p in ipairs(parts)do pcall(function()p:Destroy()end)end
	return parts
end

-- For specs and the perf probe.
function Scene:counts()
	local lamps,lights=0,0
	for _,lamp in ipairs(self.lamps)do
		if lamp.level>0 then lamps+=1 end
		if lamp.lit then lights+=1 end
	end
	return{dapple=#self.dapple,koi=#self.koi,flies=#self.dragonflies.list,lamps=lamps,lights=lights,star=self.star.on}
end

return Scene
