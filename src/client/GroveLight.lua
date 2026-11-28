-- The Hidden Grove's light (GROVE-MOCKUP "Lighting", GROVE-BUILD-PLAN 4, ARCH-REVIEW-GROVE 7). Built by GroveWorld inside
-- its folder and destroyed with it; client only, nothing replicates, nothing collides.
--   * rays: one Beam per data ray (canopy to above the lawn), FaceCamera, 1 segment, LightInfluence 0, LightEmission 1,
--     about .8 clear, the streaks drifting (TextureSpeed); at most 5 on a touch-only device. Faded by the garden hour's
--     phase (GardenHour.phase): full in the day hold, cyan in the night hold (the moon is where the 10.5 sun is), 0 at
--     dawn and golden hour, blended by its k. Hour off: HollowClock.daylight(). Level 1 keeps half; level 2 none.
--     Reduced Motion: the rays stand still.
--   * motes: one ParticleEmitter per shown ray (6 to 10 alive, the glint texture, drifting up); off at level 1 or more
--     and under Reduced Motion.
--   * bubbles: one slow soap bubble per data path (3 to 5), the Bubble Spring's look; off at level 2 and Reduced Motion.
--   * lanterns: the role "lanterns" meshes glow (Glow.material, their kind's colour; a vertex-coloured mesh keeps a white
--     part colour) only while DriftLanterns.lit (daylight under .3); no new PointLights.
--   * sun gate: a SunRays multiplier while the camera faces the gate, through AeroWorld's look (look.setSunRays); this
--     file never writes HollowSunRays (HollowClock and AeroWorld.paintLight own it).
-- The pure parts are first so specs test them offline.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Values=require(Shared:WaitForChild("WorldAero"))
local Lanterns=require(Shared:WaitForChild("DriftLanterns"))
local Rules=require(Shared:WaitForChild("Grove"))
local Light={}
Light.Name="GroveLight"
Light.Weights=table.freeze({day=1,night=1,dawn=0,golden=0})
Light.NightPhases=table.freeze({night=true})
Light.PhoneRays=5
Light.Ray=table.freeze({clear=.8,edge=.12,speed=.035,length=60,emission=1,
	day=Color3.fromHex("#FFF2D2"),night=Color3.fromHex("#9FE8FF"),
	-- [check] Fable: the falls strand's streaks stand in for a drawn ray texture.
	texture=Values.Waterfall.Textures.Strand})
Light.Mote=table.freeze({alive=8,life=8,speed=.6,size=.22,lift=.15,emission=1,texture=Values.GlintTexture})
Light.Bubble=table.freeze({material=Enum.Material.Glass,look=Values.Surfaces.bubble,rate=1/20})
-- The lanterns' night look. A mesh that holds both kinds in its vertex colours (the grove's GV_Glow__glow, kind
-- "vertex") keeps them: Neon over a white part colour, so the vertex colours carry warm and aqua; by day it is the
-- template's SmoothPlastic, white, the vertex colours bright as drawn. [check] in Studio at night: if Neon flattens the
-- vertex colours to white, set Glow.material to Enum.Material.SmoothPlastic (no glow, colours kept).
Light.Glow=table.freeze({material=Enum.Material.Neon,warm=Color3.fromHex("#FFC96A"),aqua=Color3.fromHex("#6FE6FF"),
	vertex=Color3.new(1,1,1)})
-- SunRays toward the gate: WorldAero's .03 up to .08 as the camera looks within Near degrees of it (none past Far).
Light.Sun=table.freeze({base=Values.SunRays.Intensity,peak=.08,near=15,far=40,step=.02})
Light.Every=table.freeze({look=.5,sun=.25})

local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
local function finite(v)return type(v)=="number"and v==v and math.abs(v)<math.huge end

-- Pure: the rays' {weight 0..1, night} for a garden-hour phase (GardenHour.phase: phase, from, k).
function Light.phaseLook(at)
	if type(at)~="table"or Light.Weights[at.phase]==nil then return nil end
	local to=Light.Weights[at.phase]
	if not at.from or Light.Weights[at.from]==nil then return{weight=to,night=Light.NightPhases[at.phase]==true}end
	local k=if finite(at.k)then math.clamp(at.k,0,1)else 1
	local from=Light.Weights[at.from]
	-- Next to each other one phase has no rays, so the colour is the other one's.
	local lit=if to>0 then at.phase else at.from
	return{weight=from+(to-from)*k,night=Light.NightPhases[lit]==true}
end
-- Pure: the same from a daylight alone (the hour off: HollowClock.daylight()). Day over .9, night under .12; 0 between
-- .7 and .3 (golden, dawn).
function Light.daylightLook(daylight)
	if not finite(daylight)then return{weight=0,night=false}end
	if daylight>=.5 then return{weight=smooth((daylight-.7)/.2),night=false}end
	return{weight=smooth((.3-daylight)/.18),night=true}
end
-- Pure: how many rays show of `total` at a budget level (level 1 half, rounded up; 2 none; touch-only at most 5).
function Light.rayCount(total,level,phone)
	total=math.max(0,math.floor(total or 0))
	if phone then total=math.min(total,Light.PhoneRays)end
	if level>=2 then return 0 end
	if level>=1 then return math.ceil(total/2)end
	return total
end
-- Which rays (indices into the data's) show: evenly spread over the list, so half of nine keeps the ring's spread.
function Light.rayPick(total,count)
	local out={}
	if count<=0 then return out end
	if count>=total then for i=1,total do out[i]=i end;return out end
	for k=1,count do out[k]=math.floor((k-1)*total/count)+1 end
	return out
end
function Light.motesOn(level,reduced)return level<1 and not reduced end
function Light.bubblesOn(level,reduced)return level<2 and not reduced end
function Light.rayMoves(reduced)return not reduced end
-- Pure: a ray's transparency at a weight (0 shows nothing; 1 is Ray.clear in the middle, fading at both ends).
function Light.rayClear(weight)
	weight=math.clamp(weight or 0,0,1)
	return 1-(1-Light.Ray.clear)*weight
end
function Light.rayColour(night)return if night then Light.Ray.night else Light.Ray.day end
-- Which rays show (indices into `rays`, the data's): a touch-only device takes only those marked phone (all, if none
-- are), at most PhoneRays; then the level's count, evenly spread over them.
function Light.rayChoice(rays,level,phone)
	local pool={}
	for index,ray in ipairs(rays)do if not phone or ray.phone==true then table.insert(pool,index)end end
	if phone and #pool==0 then for index in ipairs(rays)do table.insert(pool,index)end end
	local out={}
	for k,at in ipairs(Light.rayPick(#pool,Light.rayCount(#pool,level,phone)))do out[k]=pool[at]end
	return out
end
-- Pure: the unit direction to the sun gate (degrees: az from +X toward +Z, el over the horizon).
function Light.gateDirection(gate)
	local az,el=math.rad(gate.az),math.rad(gate.el)
	return Vector3.new(math.cos(el)*math.cos(az),math.sin(el),math.cos(el)*math.sin(az))
end
-- Pure: the SunRays multiplier for a camera look (unit) and the gate direction: 1 looking away, peak/base facing it.
function Light.sunGain(look,gate)
	if typeof(look)~="Vector3"or typeof(gate)~="Vector3"then return 1 end
	local S=Light.Sun
	local angle=math.deg(math.acos(math.clamp(look:Dot(gate),-1,1)))
	local facing=smooth((S.far-angle)/(S.far-S.near))
	return 1+(S.peak/S.base-1)*facing
end
-- Pure: the lanterns lit (DriftLanterns' night: daylight under .3).
function Light.lanternsLit(daylight)return Lanterns.lit(daylight)end
-- Pure: a closed path's leg lengths (leg i from point i to the next, the last back to the first) and their total.
function Light.pathLengths(path)
	local n=#path
	local lengths,total={},0
	for i=1,n do
		local d=(path[i%n+1]-path[i]).Magnitude
		lengths[i]=d;total+=d
	end
	return lengths,total
end
-- Pure: a point on a closed path (a list of Vector3) at t seconds, one loop a period, starting `phase` (0..1) round.
-- lengths, total: Light.pathLengths(path), when the caller keeps them (the bubbles do: built once, read at 20 Hz).
function Light.pathPoint(path,period,t,phase,lengths,total)
	local n=#path
	if n==0 then return nil end
	if n==1 then return path[1]end
	if not lengths then lengths,total=Light.pathLengths(path)end
	if total<=0 then return path[1]end
	local at=((t/period+(phase or 0))%1)*total
	for i=1,n do
		if at<=lengths[i]or i==n then
			local f=if lengths[i]>0 then math.clamp(at/lengths[i],0,1)else 0
			return path[i]:Lerp(path[i%n+1],f)
		end
		at-=lengths[i]
	end
	return path[1]
end

-- Builder -------------------------------------------------------------------------------------------------------------
local function vector(list)return Vector3.new(list[1],list[2],list[3])end
local function inert(p)
	p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow=true,false,false,false,false
	p.Massless=true
end
local function holder(folder,name,cframe,size)
	local p=Instance.new("Part")
	p.Name=name
	inert(p)
	p.Transparency=1
	p.Size=size or Vector3.new(.2,.2,.2)
	p.CFrame=cframe
	p.Parent=folder
	return p
end

-- options: folder, data (WorldGrove), lanterns ({{part, kind, material, color}}), level, reduced, phone,
-- hour (GardenHour: on(), time(), phase(t)), daylight() (HollowClock's), camera() -> CFrame?, setSunRays(gain),
-- connect(fn) -> connection (Heartbeat; nil in specs: they call step), now(). Returns the handle.
function Light.build(options)
	local data=options.data
	local folder=Instance.new("Folder")
	folder.Name=Light.Name
	local self={folder=folder,rays={},bubbles={},lanterns=options.lanterns or {},level=options.level or 0,
		reduced=options.reduced==true,phone=options.phone==true,clock={look=math.huge,sun=math.huge,bubble=math.huge},
		look={weight=-1,night=nil},gain=1,lit=nil,elapsed=0}
	local gate=Light.gateDirection(data.sunGate)
	-- Rays: one holder at the origin, two attachments a ray.
	local rayHolder=holder(folder,"GroveRays",CFrame.new())
	for index,ray in ipairs(data.rays)do
		-- A foot on raised ground is stopped over it (Grove.rayEnds; options.groundY: HollowWorldLayout's).
		local from,to,w1=Rules.rayEnds(ray,options.groundY)
		local a0=Instance.new("Attachment");a0.Name="RayFrom"..index;a0.Position=from;a0.Parent=rayHolder
		local a1=Instance.new("Attachment");a1.Name="RayTo"..index;a1.Position=to;a1.Parent=rayHolder
		local beam=Instance.new("Beam")
		beam.Name="GroveRay"..index
		beam.Attachment0,beam.Attachment1=a0,a1
		beam.Width0,beam.Width1=ray.w0,w1
		beam.FaceCamera=true
		beam.Segments=1
		beam.LightInfluence,beam.LightEmission=0,Light.Ray.emission
		beam.Texture=Light.Ray.texture
		beam.TextureMode=Enum.TextureMode.Wrap
		beam.TextureLength=Light.Ray.length
		beam.TextureSpeed=0
		beam.Enabled=false
		beam.Parent=rayHolder
		-- The ray's motes: a box along it, the middle two thirds.
		local length=(to-from).Magnitude
		local mid=from:Lerp(to,.5)
		local box=holder(folder,"GroveMotes"..index,CFrame.lookAt(mid,to),Vector3.new(math.max(ray.w0,ray.w1)*.6,math.max(ray.w0,ray.w1)*.6,length*.66))
		local e=Instance.new("ParticleEmitter")
		e.Name="Motes"
		e.Texture=Light.Mote.texture
		e.Shape,e.ShapeStyle=Enum.ParticleEmitterShape.Box,Enum.ParticleEmitterShapeStyle.Volume
		e.Rate=Light.Mote.alive/Light.Mote.life
		e.Lifetime=NumberRange.new(Light.Mote.life*.75,Light.Mote.life)
		e.Speed=NumberRange.new(0,Light.Mote.speed)
		e.SpreadAngle=Vector2.new(180,180)
		e.Acceleration=Vector3.new(0,Light.Mote.lift,0)
		e.Size=NumberSequence.new(Light.Mote.size)
		e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.2),NumberSequenceKeypoint.new(.7,.2),NumberSequenceKeypoint.new(1,1)})
		e.LightEmission,e.LightInfluence=Light.Mote.emission,0
		e.Enabled=false
		e.Parent=box
		table.insert(self.rays,{index=index,beam=beam,motes=e,box=box})
	end
	-- Bubbles: a ball a path, parked clear until shown.
	for index,bubble in ipairs(data.bubbles)do
		local path={}
		for _,point in ipairs(bubble.path)do table.insert(path,vector(point))end
		local ball=holder(folder,"GroveBubble"..index,CFrame.new(path[1]),Vector3.one*bubble.size)
		ball.Shape=Enum.PartType.Ball
		ball.Material=Light.Bubble.material
		ball.Color,ball.Reflectance=Light.Bubble.look.Color,Light.Bubble.look.Reflectance
		ball.Transparency=1
		local lengths,total=Light.pathLengths(path)
		table.insert(self.bubbles,{part=ball,path=path,lengths=lengths,total=total,period=bubble.period,
			phase=(index-1)/math.max(#data.bubbles,1),shown=false})
	end

	local function rayLook()
		local hour=options.hour
		if hour then
			local ok,on=pcall(hour.on)
			if ok and on==true then
				local okPhase,at=pcall(function()return hour.phase(hour.time())end)
				local look=okPhase and Light.phaseLook(at)
				if look then return look end
			end
		end
		local ok,daylight=pcall(options.daylight or function()return Values.Daylight end)
		return Light.daylightLook(if ok then daylight else Values.Daylight)
	end
	local function daylightNow()
		local ok,daylight=pcall(options.daylight or function()return Values.Daylight end)
		return if ok then daylight else Values.Daylight
	end
	-- Rays and motes to the state (only changes are written).
	function self.paintRays(look)
		look=look or self.look
		local shown={}
		for _,index in ipairs(Light.rayChoice(data.rays,self.level,self.phone))do shown[index]=true end
		local visible=look.weight>.02
		local clear=Light.rayClear(look.weight)
		-- The sequences are made only when the clear value or the night flag changes (this runs every .5 s).
		if self.sequenceClear~=clear then
			local edge=Light.Ray.edge
			self.sequenceClear=clear
			self.sequence=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(edge,clear),
				NumberSequenceKeypoint.new(1-edge,clear),NumberSequenceKeypoint.new(1,1)})
		end
		if self.colourNight~=look.night or self.colour==nil then
			self.colourNight=look.night
			self.colour=ColorSequence.new(Light.rayColour(look.night))
		end
		local sequence,colour=self.sequence,self.colour
		local speed=if Light.rayMoves(self.reduced)then Light.Ray.speed else 0
		local motes=Light.motesOn(self.level,self.reduced)
		for _,ray in ipairs(self.rays)do
			local on=visible and shown[ray.index]==true
			if ray.on~=on then ray.on=on;ray.beam.Enabled=on end
			if on and(ray.clear~=clear or ray.night~=look.night)then
				ray.clear,ray.night=clear,look.night
				ray.beam.Transparency=sequence
				ray.beam.Color=colour
			end
			if ray.speed~=speed then ray.speed=speed;ray.beam.TextureSpeed=speed end
			local emit=on and motes
			if ray.emit~=emit then
				ray.emit=emit;ray.motes.Enabled=emit
				if not emit then ray.motes:Clear()end
			end
		end
		self.look=look
	end
	function self.paintLanterns(lit)
		if self.lit==lit then return end
		self.lit=lit
		for _,lantern in ipairs(self.lanterns)do
			local part=lantern.part
			pcall(function()
				if lit then
					part.Material=Light.Glow.material
					part.Color=Light.Glow[lantern.kind]or Light.Glow.warm
				else
					part.Material,part.Color=lantern.material,lantern.color
				end
			end)
		end
	end
	function self.paintBubbles(now)
		local on=Light.bubblesOn(self.level,self.reduced)
		for _,bubble in ipairs(self.bubbles)do
			if on then
				local at=Light.pathPoint(bubble.path,bubble.period,now,bubble.phase,bubble.lengths,bubble.total)
				bubble.part.CFrame=CFrame.new(at)
				if not bubble.shown then bubble.shown=true;bubble.part.Transparency=Light.Bubble.look.Transparency end
			elseif bubble.shown then
				bubble.shown=false;bubble.part.Transparency=1
			end
		end
	end
	function self.paintSun()
		local camera=options.camera and options.camera()
		local look=camera and camera.LookVector
		local gain=if self.look.weight>.02 and not self.look.night then Light.sunGain(look,gate)else 1
		if math.abs(gain-self.gain)<Light.Sun.step and not(gain==1 and self.gain~=1)then return end
		self.gain=gain
		if options.setSunRays then pcall(options.setSunRays,gain)end
	end
	-- One frame: the light's look and the lanterns every Every.look, the sun gate every Every.sun, bubbles at Bubble.rate.
	function self.step(dt)
		local clock=self.clock
		clock.look+=dt;clock.sun+=dt;clock.bubble+=dt
		if clock.look>=Light.Every.look then
			clock.look=0
			self.paintRays(rayLook())
			self.paintLanterns(Light.lanternsLit(daylightNow()))
		end
		if clock.sun>=Light.Every.sun then clock.sun=0;self.paintSun()end
		if clock.bubble>=Light.Bubble.rate and #self.bubbles>0 then
			clock.bubble=0
			self.paintBubbles((options.now or os.clock)())
		end
	end
	-- {level, reduced}: what AeroWorld passes on its timer and on Reduced Motion's signal.
	function self.update(changes)
		changes=changes or {}
		if changes.level~=nil then self.level=math.max(self.level,changes.level)end
		if changes.reduced~=nil then self.reduced=changes.reduced==true end
		self.paintRays()
		self.paintBubbles((options.now or os.clock)())
	end
	local link=options.connect and options.connect(function(dt)
		local ok,problem=pcall(self.step,math.min(dt,.25))
		if not ok and options.warn then options.warn(problem)end
	end)
	function self.destroy()
		if link then link:Disconnect();link=nil end
		if self.gain~=1 and options.setSunRays then pcall(options.setSunRays,1)end
		self.gain=1
		pcall(function()folder:Destroy()end)
	end
	folder.Parent=options.parent
	self.step(math.huge)
	return self
end
return Light
