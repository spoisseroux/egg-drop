-- My own pet and the garden's life (beta 14 QA D2 / B5 and W3 row 1; WORLD-AND-NEST-LOOK section 7;
-- GARDEN-LIFE-BUILD-PLAN section 2c, architect r1): the Dewdrop snack and the big-breath look-up. The owner's own pet on
-- the owner's client only, looks only: no remote, no reward, nothing saved. Other players see the pet where the server
-- has it (as with the bat).
--
-- The garden pet's place is the server's (GardenState plans every path; PetFollow.activity draws its sample every
-- frame), so the snack is a presentation layer on top of that sample, the DashClient:drive / ParkClient:drive way:
--   notice  a Dewdrop comes to rest within 8 studs of my drawn pet (GardenLife's Loose asks on landing and every 2 s),
--           the pet is free and the last snack was 90 s or more ago: take it.
--   drive   (RoomView, right after PetFollow.activity) turn .3 s, a .4 s ears-up pause, trot to .9 studs of the fruit,
--           three .35 s nibbles, a .35 hop with the content face for 1.5 s and one heart rising 1 stud over .8 s, then
--           trot back to the live server sample and hand the pet back. Any rule broken (not free, a menu, a hatch, the
--           drawn pet more than 8 studs from its server position, ...) aborts: a .35 s ease back to the sample.
--   pose    (RoomView, right after the pet's update) the nibble's head dip, the SnackEating way (re-pose at zero dt, then
--           turn the head pieces).
-- The breath look-up: as the big breath (Alive `scene`) reaches a free pet, its head lifts for 1.2 s (careHeadPitch,
-- which PetCarePose resets every frame in the garden).
-- Switch: the Alive `snack` feature (its own: Spencer can turn the snack off alone; the beta place and Studio only). With
-- it off, or its ceiling false (live), drive and pose write nothing at all. Reduced Motion: no snack (fruit never falls).
-- deps: alive {ceiling, on}, now(), reduced(), busy() -> true while a menu, focus, a Stat snack, a hatch or a race owns
--   the pet, owner() -> my root position?, ownerStill() -> boolean, scene() -> boolean, breath(position, now) ->
--   strength, number, world (the heart's parent), audio(cue)?.
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local Pet={};Pet.__index=Pet
Pet.Snack=table.freeze({notice=8,cooldown=90,turn=.3,pause=.4,trot=3.5,arrive=.9,nibble=.35,nibbles=3,hop=.35,hopTime=.3,
	content=1.5,heart=.8,heartRise=1,heartSize=.6,back=.35,drift=8,leash=16,release=.3,pausePitch=-.15,nod=9,
	heartColour=Color3.fromHex("#F4A9C4"),heartImage="rbxassetid://129048015089227",lift=.5,sole=.025})
Pet.Look=table.freeze({pitch=-.25,rise=.2,hold=.7,fall=.3,over=.5})
local S=Pet.Snack

local function smooth(x)x=math.clamp(x,0,1);return x*x*(3-2*x)end
local function flat(a,b)return math.sqrt((a.X-b.X)^2+(a.Z-b.Z)^2)end
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end

-- Is the server's pet free for a snack? Its own business only: in the garden, no care, greeting, race or park, and
-- resting or pausing (a follow only while the owner stands still).
function Pet.free(actor,ownerStill)
	if type(actor)~="table"or actor.mode~="Room"then return false end
	if actor.care or actor.pairId or actor.dash or actor.park then return false end
	if actor.action=="greet"or actor.action=="focus"then return false end
	if actor.behavior=="rest"or actor.action=="wanderPause"or actor.action=="settle"then return true end
	return actor.behavior=="follow"and ownerStill==true
end

function Pet.new(deps)
	deps=deps or {}
	local alive=deps.alive or require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Alive"))
	local self=setmetatable({d=deps,alive=alive,active=nil,look=nil,cooldownUntil=-math.huge,lastActor=nil,lastBreath=nil},Pet)
	self.now=deps.now or function()return workspace:GetServerTimeNow()end
	return self
end

-- The `snack` switch: false with its ceiling off (live) or the switch off.
function Pet:on()
	local ok,on=pcall(function()return self.alive.ceiling("snack")and self.alive.on("snack")end)
	return ok and on==true
end
local function call(fn,...)
	if type(fn)~="function"then return nil end
	local ok,value=pcall(fn,...)
	return if ok then value else nil
end
function Pet:isBusy()return call(self.d.busy)==true or call(self.d.reduced)==true end

-- GardenLife's Loose asks about a resting drawn fruit: true takes it (my pet goes for it).
function Pet:notice(loose,now)
	if self.active or not self:on()or self:isBusy()or now<self.cooldownUntil then return false end
	local visual,actor=self.visual,self.lastActor
	if not visual or visual.destroyed or typeof(visual.origin)~="Vector3"or typeof(loose.rest)~="Vector3"then return false end
	if not Pet.free(actor,call(self.d.ownerStill)==true)then return false end
	if flat(visual.origin,loose.rest)>S.notice then return false end
	local owner=call(self.d.owner)
	if typeof(owner)=="Vector3"and flat(owner,loose.rest)>S.leash then return false end
	local fruit=loose.rest
	local to=Vector3.new(fruit.X-visual.origin.X,0,fruit.Z-visual.origin.Z)
	local stop=if to.Magnitude>S.arrive then fruit-to.Unit*S.arrive else visual.origin
	self.active={loose=loose,fruit=fruit,stop=Vector3.new(stop.X,fruit.Y-S.lift+S.sole,stop.Z),phase="turn",at=now,
		pos=visual.origin,yaw=visual.yaw or 0,fromYaw=visual.yaw or 0,wantYaw=math.atan2(to.X,to.Z)}
	self.cooldownUntil=now+S.cooldown
	return true
end

-- Hands the pet back: an ease from where it is drawn to the live sample over `back` seconds.
function Pet:abort(now)
	local a=self.active
	if not a then return end
	if a.loose and not a.loose.eaten then a.loose.taken=nil end
	if a.phase~="back"or not a.quick then a.phase,a.at,a.quick,a.from=("back"),now or self.now(),true,a.pos end
end
function Pet:release(visual)
	local a=self.active
	self.active=nil
	if a and a.loose and not a.loose.eaten then a.loose.taken=nil end
	if visual and not visual.destroyed then visual.poseDirty=true end
	self:dropHeart()
end

-- One frame after PetFollow.activity. actor nil: the activity did not draw the pet this frame (a race, the park,
-- focus): anything running is dropped at once.
function Pet:drive(visual,actor,now,dt)
	self.visual,self.lastActor=visual,actor
	local a=self.active
	if not self:on()then
		if a then self:release(visual)end
		self.look=nil
		return false
	end
	dt=if finite(dt)then math.clamp(dt,0,.1)else 0
	if not visual or visual.destroyed or typeof(visual.origin)~="Vector3"then if a then self:release(nil)end return false end
	if not actor then if a then self:release(visual)end self.look=nil return false end
	local sample=visual.origin
	if not a then return self:lookUp(visual,actor,now)end
	local free=Pet.free(actor,call(self.d.ownerStill)==true)and not self:isBusy()
	if a.phase~="back"and(not free or flat(a.pos,sample)>S.drift or(a.loose.quick and not a.loose.eaten))then self:abort(now)end
	local t=now-a.at
	local pos,moving=a.pos,0
	if a.phase=="turn"then
		a.yaw=a.fromYaw+math.atan2(math.sin(a.wantYaw-a.fromYaw),math.cos(a.wantYaw-a.fromYaw))*smooth(t/S.turn)
		if t>=S.turn then a.phase,a.at="pause",now end
	elseif a.phase=="pause"then
		visual.careHeadPitch=S.pausePitch
		visual.expression="curious"
		if t>=S.pause then a.phase,a.at="trot",now end
	elseif a.phase=="trot"then
		local to=Vector3.new(a.stop.X-pos.X,0,a.stop.Z-pos.Z)
		local step=S.trot*dt
		if to.Magnitude<=step then
			pos=Vector3.new(a.stop.X,a.stop.Y,a.stop.Z)
			a.phase,a.at="eat",now
			a.loose.eaten=now
			call(self.d.audio,"dewdrop_nibble")
		else
			local u=step/to.Magnitude
			pos=Vector3.new(pos.X+to.X*u,pos.Y+(a.stop.Y-pos.Y)*u,pos.Z+to.Z*u)
			a.yaw=math.atan2(to.X,to.Z)
			moving=S.trot
		end
	elseif a.phase=="eat"then
		local bite=math.floor(t/S.nibble)
		if bite~=a.bite then
			a.bite=bite
			if bite>=1 and bite<S.nibbles then call(self.d.audio,"dewdrop_nibble")end
		end
		if t>=S.nibble*S.nibbles then
			a.phase,a.at="glad",now
			visual.contentUntil=(visual.time or 0)+S.content
			self:heart(visual,now)
		end
	elseif a.phase=="glad"then
		local u=math.clamp(t/S.hopTime,0,1)
		pos=Vector3.new(a.stop.X,a.stop.Y,a.stop.Z)
		if u<1 then
			local lift=S.hop*4*u*(1-u)
			visual.origin=pos+Vector3.new(0,lift,0)
			a.pos=pos
			self:stepHeart(now)
			visual.yaw,visual.poseDirty=a.yaw,true
			return true
		end
		if t>=S.content then a.phase,a.at="back",now end
	end
	if a.phase=="back"and a.quick then
		-- An abort: eased from where it was to the live sample over `back` seconds.
		local u=(now-a.at)/S.back
		if u>=1 then
			self:release(visual)
			return false
		end
		local from=a.from or pos
		pos=from:Lerp(sample,smooth(u))
		local to=Vector3.new(sample.X-from.X,0,sample.Z-from.Z)
		if to.Magnitude>1e-3 then a.yaw=math.atan2(to.X,to.Z)end
		moving=math.min(to.Magnitude/S.back,S.trot*2)
	elseif a.phase=="back"then
		local to=Vector3.new(sample.X-pos.X,0,sample.Z-pos.Z)
		local step=S.trot*dt
		if to.Magnitude<=math.max(step,S.release)then
			self:stepHeart(now)
			self:release(visual)
			return false
		end
		local u=step/to.Magnitude
		pos=Vector3.new(pos.X+to.X*u,pos.Y+(sample.Y-pos.Y)*u,pos.Z+to.Z*u)
		a.yaw=math.atan2(to.X,to.Z)
		moving=S.trot
	end
	a.pos=pos
	visual.origin=pos
	visual.yaw=a.yaw
	if moving>0 then
		local Follow=require(script.Parent.PetFollow)
		visual.gaitWeight=math.clamp((moving-.025)/3.5,0,1)
		visual.travelSpeed=moving
		local stride=Follow.stride(moving,visual.worldScale)
		visual.gaitPhase=((visual.gaitPhase or 0)+math.min(moving*dt/stride,dt*Follow.CadenceCap)*math.pi*2)%(math.pi*2)
	elseif a.phase~="back"then
		visual.gaitWeight,visual.travelSpeed=0,0
	end
	visual.poseDirty=true
	self:stepHeart(now)
	return true
end

-- The breath look-up (scene on): once a breath, a free pet's head lifts for 1.2 s.
function Pet:lookUp(visual,actor,now)
	local L=Pet.Look
	local look=self.look
	if not look and call(self.d.scene)==true and Pet.free(actor,call(self.d.ownerStill)==true)and not self:isBusy()then
		local okBreath,v,b=pcall(self.d.breath or function()return 0 end,visual.origin,now)
		if okBreath and b~=nil and type(v)=="number"and v>L.over and b~=self.lastBreath then
			self.lastBreath=b
			look={start=now}
			self.look=look
		end
	end
	if not look then return false end
	local t=now-look.start
	local total=L.rise+L.hold+L.fall
	if t>=total or self:isBusy()then self.look=nil;visual.poseDirty=true;return false end
	local k=if t<L.rise then smooth(t/L.rise)elseif t<L.rise+L.hold then 1 else 1-smooth((t-L.rise-L.hold)/L.fall)
	visual.careHeadPitch=L.pitch*k
	visual.poseDirty=true
	return true
end

-- After the pet's update: the nibble's head dip, on top of this frame's pose (SnackEating's way).
local function headish(entry)
	local name,channel=entry.name or "",entry.channel
	return channel=="Head"or channel=="Face"or channel=="Charm"or name:find("Eye")or name:find("Glint")or name:find("Mouth")
		or name:find("Teeth")or name:find("Cheek")or name:find("Ear")
end
function Pet:pose(visual,_dt)
	local a=self.active
	if not a or a.phase~="eat"or not visual or visual.destroyed or not self:on()then return false end
	local t=self.now()-a.at
	local b=t%S.nibble
	local nod=math.rad(S.nod)*math.sin(math.clamp(b/S.nibble,0,1)*math.pi)
	if nod<=0 then return false end
	local head
	for _,entry in ipairs(visual.pieces or {})do if entry.name=="Head"then head=entry.part end end
	if not head then return false end
	for _,entry in ipairs(visual.pieces)do entry.lastFrame=nil;entry.lastSize=nil;entry.lastTransparency=nil end
	visual.poseDirty=true
	visual:update(0)
	local pivot=head.Position
	local turn=CFrame.new(pivot)*CFrame.fromAxisAngle(head.CFrame.RightVector,nod)*CFrame.new(-pivot)
	for _,entry in ipairs(visual.pieces)do if headish(entry)then entry.part.CFrame=turn*entry.part.CFrame end end
	return true
end

-- One heart mote: the only bright thing in the beat (it belongs to the pet). No UI, no number.
function Pet:heart(visual,now)
	self:dropHeart()
	local world=self.d.world or workspace
	local p=Instance.new("Part")
	p.Name="LifePetHeart"
	p.Anchored,p.CanCollide,p.CanQuery,p.CanTouch,p.CastShadow,p.Transparency=true,false,false,false,false,1
	p.Size=Vector3.new(.1,.1,.1)
	local at=(visual.origin or Vector3.zero)+Vector3.new(0,(visual.worldScale or 1)*1.6,0)
	p.CFrame=CFrame.new(at)
	local gui=Instance.new("BillboardGui")
	gui.Name="Heart"
	gui.Size=UDim2.fromScale(S.heartSize,S.heartSize)
	gui.LightInfluence=0
	gui.AlwaysOnTop=false
	gui.Parent=p
	local image=Instance.new("ImageLabel")
	image.Name="Image"
	image.Size=UDim2.fromScale(1,1)
	image.BackgroundTransparency=1
	image.Image=S.heartImage
	image.ImageColor3=S.heartColour
	image.Parent=gui
	p.Parent=world
	self.mote={part=p,image=image,from=at,start=now}
end
function Pet:stepHeart(now)
	local mote=self.mote
	if not mote then return end
	local t=now-mote.start
	if t>=S.heart then self:dropHeart();return end
	mote.part.CFrame=CFrame.new(mote.from+Vector3.new(0,S.heartRise*smooth(t/S.heart),0))
	mote.image.ImageTransparency=math.clamp((t-(S.heart-.3))/.3,0,1)
end
function Pet:dropHeart()
	if self.mote then pcall(function()self.mote.part:Destroy()end);self.mote=nil end
end

function Pet:destroy()
	if self.active then self:release(self.visual)end
	self:dropHeart()
	self.look=nil
end

return Pet
