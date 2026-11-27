-- Drift balloons over the garden (GARDEN-PLAY-BRIEF-2 2026-11-26 section 6; DriftLanterns holds the numbers): nine
-- small hot-air balloons (an envelope with accent gores and skirt, ropes, a wood basket, a Neon burner flame) built
-- from plain parts on this client, each bobbing, drifting on its own small circle and swaying gently (WorldMotion.pose
-- "bob" and "sway", every balloon its own phase), with a burn every 6 to 10 s (the flame grows, the balloon lifts .4,
-- a soft exhale within 30 studs), and a soft seed-fluff emitter over the hub by day. Nothing replicates; they cannot be
-- touched.
--
-- Three carry a mascot (DriftLanterns.pickMascots, per session): a PetFactory baby at .45 world scale, a random roster
-- pet and palette, never a player's, dressed as an imp (horn buds) or a cherub (folded wings and a Neon halo). It is
-- anchored and query-free, its feet ride the basket (parkPose: never planted), and it has no clock of its own: this
-- one loop sets its origin and yaw and calls its update. Every 4 to 7 s it looks about or emotes (PetIdleBeats' poses,
-- injected; the beats' own scheduler is held off), and when the local player is within 35 studs it turns to them,
-- waves 1.2 s (the visual's greet) and hops, at most every 10 s, with a squeak within 25. Within 60 studs of the
-- camera it is posed every step, past that every 4th; past the cull it is left as it is (its balloon is still too).
--
-- Gate: the Alive `air` switch (beta and Studio); off, nothing is built (turned off at runtime, it is all taken down).
-- Day and night follow HollowClock.daylight like the lamps: under .3, over DriftLanterns.GlowSpan, the flame comes up
-- and flickers and the envelope warms (DriftLanterns.lookAt), and the four balloons nearest the camera carry the four
-- PointLights at their burners, flickering with the flame. One loop: 30 Hz while a balloon is within the cull distance
-- (90 studs on a phone, 150 elsewhere) of the camera and the garden is up (Mode Room); otherwise it sleeps and looks
-- again every .5 s. Reduced Motion: every balloon and mascot at rest, a steady flame, no fluff (the night look still
-- follows the clock; the burn and the squeak still sound).
--
-- Instance state for probes: workspace.DriftLanternsLocal (attributes AirAwake, AirParts, AirGlow, AirMascots); each
-- mascot's model is named mascot_<place id> (attributes MascotKind, MascotPet).
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Lanterns=require(Shared:WaitForChild("DriftLanterns"))
local World=require(Shared:WaitForChild("HollowWorldLayout"))
local IdleBeats=require(script.Parent.PetIdleBeats)

local Client={};Client.__index=Client
Client.Folder="DriftLanternsLocal"
Client.Voices=3
-- The fluff's look: the engine's own soft particle, tiny and cream, falling slowly (no new texture).
Client.FluffTexture="rbxasset://textures/particles/smoke_main.dds"

local function material(name,fallback)
	local ok,value=pcall(function()return(Enum.Material::any)[name]end)
	if ok and value~=nil then return value end
	return(Enum.Material::any)[fallback]
end

-- deps (specs): alive, parent, heartbeat (false: the spec steps), now, daylight() -> number, camera() -> Vector3,
-- listener() -> Vector3 (my character), mode() -> string, reduced() -> bool, phone() -> bool, move(parts, frames),
-- pose (WorldMotion.pose), delay(s, fn), seed, roster() -> {pet ids}, mascot(parent, origin, petId, appearance) ->
-- visual, cheer(visual), play(cue, position, volume, speed), uri(cue), group (SoundGroup), worldVersion.
function Client.mount(deps)
	deps=deps or {}
	local alive=deps.alive or require(Shared:WaitForChild("Alive"))
	if not alive.ceiling(Lanterns.Feature)then return nil end
	if(deps.worldVersion or World.WorldVersion)~="v7"then return nil end
	local self=setmetatable({d=deps,alive=alive,built=false,awake=false,connections={},clock=0,lookClock=math.huge},Client)
	self.now=deps.now or os.clock
	self.delay=deps.delay or task.delay
	self.mode=deps.mode or function()return "Room"end
	self.reduced=deps.reduced or function()return game:GetService("GuiService").ReducedMotionEnabled==true end
	self.daylight=deps.daylight or function()
		local ok,value=pcall(function()return require(script.Parent.HollowClock).daylight()end)
		return if ok and type(value)=="number"then value else 1
	end
	self.phone=deps.phone or function()
		local input=game:GetService("UserInputService")
		return input.TouchEnabled==true and input.KeyboardEnabled~=true
	end
	self.camera=deps.camera or function()
		local camera=workspace.CurrentCamera
		return camera and camera.CFrame.Position
	end
	self.listener=deps.listener or function()
		local character=Players.LocalPlayer and Players.LocalPlayer.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		return if root then root.Position else self.camera()
	end
	self.roster=deps.roster or function()
		local ok,ids=pcall(function()
			local out={}
			for _,pet in ipairs(require(Shared:WaitForChild("PetCatalog")).active)do table.insert(out,pet.id)end
			return out
		end)
		return if ok then ids else {}
	end
	self.buildMascot=deps.mascot or function(parent,origin,petId,appearance)
		local pet=require(Shared:WaitForChild("PetCatalog")).byId[petId]
		return require(script.Parent.PetFactory).new(parent,origin,pet,Lanterns.Mascot.scale,appearance)
	end
	self.cheer=deps.cheer or function(visual)
		pcall(function()require(script.Parent.PetReactions).trigger(visual,"cheer",os.clock())end)
	end
	self.pose=deps.pose or require(script.Parent.WorldMotion).pose
	-- Per session: a fresh seed each join unless a spec pins it.
	self.random=if deps.seed then Random.new(deps.seed)else Random.new()
	table.insert(self.connections,alive.changed(Lanterns.Feature):Connect(function()self:sync()end))
	self:sync()
	return self
end

function Client:sync()
	if self.destroyed then return end
	local on=self.alive.on(Lanterns.Feature)==true
	if on==self.built then return end
	if on then
		local ok,problem=pcall(self.build,self)
		if not ok then
			warn("[DriftLanterns] build failed: "..tostring(problem))
			self:teardown()
			return
		end
		self:wake()
	else
		self:teardown()
	end
end

local function part(name,size,cframe,colour,mat,parent)
	local p=Instance.new("Part")
	p.Name=name;p.Size=size;p.CFrame=cframe;p.Color=Color3.fromHex(colour);p.Material=mat
	p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
	p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
	p.Parent=parent
	return p
end
-- A mascot's rig is never touched, queried or collided with (the Body is queryable for a garden pet's prompts).
local function quiet(item)
	if item:IsA("BasePart")or item:IsA("Part")then item.CanQuery=false;item.CanTouch=false;item.CanCollide=false;item.Anchored=true end
end

function Client:build()
	if self.built then return end
	self.built=true
	local folder=Instance.new("Folder");folder.Name=Client.Folder
	folder.Parent=self.d.parent or workspace
	self.folder=folder
	local L=Lanterns.Look
	local smooth,wood,neon=material("SmoothPlastic","SmoothPlastic"),material("Wood","Wood"),material("Neon","Neon")
	local count=0
	-- The session's mascots, by place.
	local picks={}
	for _,pick in ipairs(Lanterns.pickMascots(self.random,self.roster()))do picks[pick.place]=pick end
	self.lanterns={}
	for i,place in ipairs(Lanterns.Places)do
		local pick=picks[i]
		local y=Lanterns.groundAt(place,World)+Lanterns.over(place,pick~=nil)
		local bobPhase,_,swayPhase,flickerPhase=Lanterns.phases(i)
		local rest=CFrame.new(place.x,y,place.z)*CFrame.Angles(0,bobPhase*math.pi,0)
		local accent=L.accents[place.accent]
		local pieces,offsets={}, {}
		-- B38: the mid and high layers are drawn larger (every size and offset times the place's scale).
		local s=Lanterns.scale(place)
		local function add(p,offset)
			if s~=1 then offset=CFrame.new(offset.Position*s)*offset.Rotation;p.Size*=s;p.CFrame=rest*offset end
			table.insert(pieces,p);table.insert(offsets,offset);count+=1;return p
		end
		local function cylinder(name,size,offset,colour,mat)
			local p=add(part(name,size,rest*offset,colour,mat,folder),offset)
			p.Shape=Enum.PartType.Cylinder
			return p
		end
		-- The envelope and its four upright gore rings (a Cylinder's axis is X: each disc stands in a vertical plane).
		local envelope=add(part(place.id.."_envelope",Vector3.new(L.envelope,L.envelope,L.envelope),rest,Lanterns.envelopeColour(place),smooth,folder),CFrame.new())
		envelope.Shape=Enum.PartType.Ball
		for k=0,L.gores-1 do
			cylinder(place.id.."_gore"..(k+1),Vector3.new(L.gore,L.goreAcross,L.goreAcross),CFrame.Angles(0,k*math.pi/L.gores,0),accent,smooth)
		end
		-- The skirt (stood up), four ropes down to the basket's corners, the basket and its rim.
		cylinder(place.id.."_skirt",Vector3.new(L.skirt,L.skirtAcross,L.skirtAcross),CFrame.new(0,L.skirtY,0)*CFrame.Angles(0,0,math.pi/2),accent,smooth)
		local ropeY=Lanterns.BasketTop+L.ropeLength/2
		for k,corner in ipairs({{1,1},{-1,1},{-1,-1},{1,-1}})do
			cylinder(place.id.."_rope"..k,Vector3.new(L.ropeLength,L.rope,L.rope),
				CFrame.new(corner[1]*L.ropeAt,ropeY,corner[2]*L.ropeAt)*CFrame.Angles(0,0,math.pi/2),L.ropeColour,smooth)
		end
		local basketOffset=CFrame.new(0,Lanterns.BasketTop-L.basket.Y/2,0)
		add(part(place.id.."_basket",L.basket,rest*basketOffset,L.basketColour,wood,folder),basketOffset)
		local rimOffset=CFrame.new(0,Lanterns.BasketTop,0)
		add(part(place.id.."_rim",L.rim,rest*rimOffset,L.rimColour,wood,folder),rimOffset)
		-- The burner's flame under the skirt.
		local flameOffset=CFrame.new(0,L.flameY,0)
		local flame=add(part(place.id.."_flame",Vector3.new(L.flame,L.flame,L.flame),rest*flameOffset,L.flameColour,neon,folder),flameOffset)
		flame.Shape=Enum.PartType.Ball;flame.Transparency=L.day.flameClear
		table.insert(self.lanterns,{index=i,place=place,rest=rest,pieces=pieces,offsets=offsets,envelope=envelope,flame=flame,
			bob=bobPhase,sway=swayPhase,flicker=flickerPhase,burnAt=-math.huge,
			nextBurn=if Lanterns.far(place)then math.huge else self.now()+self.random:NextNumber(0,Lanterns.Burn.gapMax),
			grow=1,flick=1,pick=pick,scale=s,far=Lanterns.far(place)})
	end
	-- Four lights, handed to the nearest balloons' burners at night.
	self.lights={}
	for k=1,Lanterns.Lights.count do
		local light=Instance.new("PointLight")
		light.Name="balloon_light"..k
		light.Range=Lanterns.Lights.range;light.Brightness=Lanterns.Lights.brightness
		light.Color=Color3.fromHex(L.flameColour);light.Shadows=false;light.Enabled=false
		light.Parent=self.lanterns[k].flame
		table.insert(self.lights,light)
	end
	-- The seed fluff over the hub.
	local F=Lanterns.Fluff
	local host=part("seed_fluff",F.size,CFrame.new(F.x,World.groundY(F.x,F.z)+F.over,F.z),F.colour,smooth,folder)
	host.Transparency=1
	count+=1
	local emitter=Instance.new("ParticleEmitter")
	emitter.Name="seed_fluff"
	emitter.Enabled=false
	pcall(function()
		emitter.Texture=Client.FluffTexture
		emitter.Rate=F.rate
		emitter.Lifetime=NumberRange.new(7,10)
		emitter.Speed=NumberRange.new(.3,.7)
		emitter.SpreadAngle=Vector2.new(40,40)
		emitter.EmissionDirection=Enum.NormalId.Bottom
		emitter.Acceleration=Vector3.new(.22,-.1,.08)
		emitter.Drag=.4
		emitter.Color=ColorSequence.new(Color3.fromHex(F.colour))
		emitter.LightEmission=0
		emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.14),NumberSequenceKeypoint.new(1,.2)})
		emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.15,.25),
			NumberSequenceKeypoint.new(.8,.35),NumberSequenceKeypoint.new(1,1)})
		emitter.Rotation=NumberRange.new(0,360)
		emitter.RotSpeed=NumberRange.new(-30,30)
		emitter.Shape=Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
	end)
	emitter.Parent=host
	self.emitter=emitter
	-- The sounds hang from one invisible part (attachments are positional), through the garden's cue group so the
	-- Sound setting and focus mute them.
	local anchor=part("balloon_audio",Vector3.new(.2,.2,.2),CFrame.new(),"#000000",smooth,folder)
	anchor.Transparency=1
	count+=1
	self.voices={}
	local group=self.d.group
	if group==nil then pcall(function()group=game:GetService("SoundService"):FindFirstChild("EggDropAmbientCues")end)end
	for i=1,Client.Voices do
		local holder=Instance.new("Attachment");holder.Name="voice"..i;holder.Parent=anchor
		local voice=Instance.new("Sound");voice.Name="balloon"..i
		voice.RollOffMode=Enum.RollOffMode.InverseTapered;voice.RollOffMinDistance=8;voice.RollOffMaxDistance=40
		voice.Volume=0;voice.SoundGroup=group;voice.Parent=holder
		table.insert(self.voices,{holder=holder,voice=voice,at=-math.huge})
	end
	self.uris={}
	-- The mascots.
	self.mascots={}
	for _,l in ipairs(self.lanterns)do
		if l.pick then
			local ok,problem=pcall(self.buildMascot_,self,l,folder)
			if ok then count+=problem else warn("[DriftLanterns] mascot skipped: "..tostring(problem))end
		end
	end
	self.parts=count
	self.glowNow=nil
	folder:SetAttribute("AirParts",count)
	folder:SetAttribute("AirMascots",#self.mascots)
end

-- One mascot in balloon l's basket; returns the parts it added to the budget (its halo).
function Client:buildMascot_(l,folder)
	local M=Lanterns.Mascot
	local pick=l.pick
	local restYaw=(l.flicker*2-1)*math.pi
	local visual=self.buildMascot(folder,(l.rest*CFrame.new(0,Lanterns.BasketTop,0)).Position,pick.petId,pick.appearance)
	assert(type(visual)=="table"and visual.model,"no visual")
	visual.model.Name="mascot_"..l.place.id
	visual.model:SetAttribute("MascotKind",pick.kind)
	visual.model:SetAttribute("MascotPet",pick.petId)
	-- Never a player's pet: no owner looks, no toy play; its feet ride the basket; its beats come from here.
	visual.parkPose=true;visual.idleBeatsEnabled=true;visual.personalPlayEnabled=false
	visual.cosmeticSeed=l.index;visual.yaw=restYaw
	-- The paws' top a little over the rim: the feet go that far under it (the rig's hand anchor at its scale).
	local anchors=visual.definition and visual.definition.anchors
	local hand=anchors and(anchors.HandR or anchors.HandL)
	local handY=(if type(hand)=="table"then hand[2]else .6)*(visual.scale or 1)
	local m={lantern=l,visual=visual,kind=pick.kind,restYaw=restYaw,footY=Lanterns.BasketTop+M.paws-handY,
		nextBeat=self.now()+Lanterns.lookGap(self.random),lastWave=nil,waveAt=nil,steps=0,acc=0,connections={}}
	for _,item in ipairs(visual.model:GetDescendants())do quiet(item)end
	pcall(function()table.insert(m.connections,visual.model.DescendantAdded:Connect(quiet))end)
	local added=0
	if Lanterns.Kinds[pick.kind].halo then
		local halo=part("mascot_"..l.place.id.."_halo",Vector3.new(M.haloThick,M.halo,M.halo),CFrame.new(),M.haloColour,
			material("Neon","Neon"),folder)
		halo.Shape=Enum.PartType.Cylinder
		m.halo=halo
		added+=1
	end
	l.mascot=m
	table.insert(self.mascots,m)
	self:poseMascot(m,l.rest,0,false)
	return added
end

function Client:teardown()
	self:sleep()
	for _,m in ipairs(self.mascots or {})do
		for _,c in ipairs(m.connections)do c:Disconnect()end
		pcall(function()m.visual:destroy()end)
	end
	if self.folder then self.folder:Destroy()end
	self.folder=nil;self.built=false
	self.lanterns,self.lights,self.emitter,self.voices,self.mascots=nil,nil,nil,nil,nil
end

function Client:cull()return if self.phone()then Lanterns.Cull.phone else Lanterns.Cull.desktop end
function Client:wanted()
	if not self.built or self.mode()~="Room"then return false end
	local camera=self.camera()
	if typeof(camera)~="Vector3"then return false end
	local phone=self.phone()
	for _,l in ipairs(self.lanterns)do if(l.rest.Position-camera).Magnitude<=Lanterns.cullFor(l.place,phone)then return true end end
	return false
end
function Client:wake()
	if self.destroyed or not self.built then return end
	if not self:wanted()then self:sleep(true);return end
	if self.awake then return end
	self.awake=true
	self.lookClock=math.huge
	if self.folder then self.folder:SetAttribute("AirAwake",true)end
	if self.d.heartbeat~=false then
		self.link=(self.d.heartbeat or RunService.Heartbeat):Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok then
				warn("[DriftLanterns] stopped: "..tostring(problem))
				pcall(self.destroy,self)
			end
		end)
	end
end
function Client:sleep(poll)
	if self.link then self.link:Disconnect();self.link=nil end
	if self.awake then
		self.awake=false
		if self.folder then self.folder:SetAttribute("AirAwake",false)end
		if self.emitter then self.emitter.Enabled=false end
	end
	if poll and not self.polling and not self.destroyed and self.d.heartbeat~=false then
		self.polling=true
		self.delay(Lanterns.Sleep,function()
			self.polling=false
			if not self.destroyed and self.built then self:wake()end
		end)
	end
end

-- Sound ---------------------------------------------------------------------------------------------------------
function Client:uri(cue)
	if self.d.uri then return self.d.uri(cue)end
	if self.uris[cue]~=nil then return self.uris[cue]or nil end
	local id=Lanterns.NewTakes[cue]
	local out=if type(id)=="number"and id>0 then "rbxassetid://"..id else nil
	if not out and Lanterns.NewTakes[cue]==nil then
		pcall(function()
			local Audio=require(script.Parent.BoardAudio)
			local asmr=Audio.AsmrIds and Audio.AsmrIds[cue]
			out=if type(asmr)=="number"and asmr>0 then "rbxassetid://"..asmr else Audio.uri(cue)
		end)
	end
	self.uris[cue]=out or false
	return out
end
-- Play one take of `kind` (Lanterns.Sounds) at `position` when the listener is in range. Returns the cue played.
function Client:sound(kind,position)
	local S=Lanterns.Sounds[kind]
	local listener=self.listener()
	if typeof(listener)~="Vector3"or(listener-position).Magnitude>S.range then return nil end
	-- Only takes that have ids (the new whooshes join once uploaded: NewTakes is [PLACEHOLDER] 0 until then).
	local takes={}
	for _,cue in ipairs(S.cues)do
		local new=Lanterns.NewTakes[cue]
		if(new==nil or new>0)and(self.d.play or self:uri(cue))then table.insert(takes,cue)end
	end
	if #takes==0 then return nil end
	local cue=takes[self.random:NextInteger(1,#takes)]
	local speed=S.speed*(1+self.random:NextNumber(-S.vary,S.vary))
	if self.d.play then self.d.play(cue,position,S.volume,speed);return cue end
	local uri=self:uri(cue)
	if not uri or not self.voices then return nil end
	local pick
	for _,v in ipairs(self.voices)do if not v.voice.IsPlaying then pick=v;break end end
	if not pick then
		pick=self.voices[1]
		for _,v in ipairs(self.voices)do if v.at<pick.at then pick=v end end
	end
	pick.at=self.now()
	pick.holder.Position=position
	local voice=pick.voice
	voice.SoundId=uri;voice.PlaybackSpeed=speed;voice.Volume=S.volume;voice.TimePosition=0
	voice:Play()
	return cue
end

-- Motion --------------------------------------------------------------------------------------------------------
-- Where balloon l is at t: its rest, drifted, bobbed and swayed about the envelope's centre.
function Client:frame(l,t)
	local M=Lanterns.motion(l.place)
	local at=l.rest+Lanterns.drift(l.index,t)
	at=self.pose("bob",at,nil,M.bob,M.bobPeriod,l.bob,t)
	return self.pose("sway",at,at.Position,M.sway,M.swayPeriod,l.sway,t)
end

-- The day / night look (Fable section 6): the envelope's warmth, the flame's see-through, the lights' owners, the fluff.
function Client:look(camera,reduced)
	local daylight=self.daylight()
	local glow=Lanterns.glow(daylight)
	local lit=Lanterns.lit(daylight)
	self.lit,self.daylightNow=lit,daylight
	local key=if lit then math.floor(glow*20+.5)else -1
	local look=Lanterns.lookAt(glow)
	self.lookNow=look
	if key~=self.glowNow then
		self.glowNow=key
		for _,l in ipairs(self.lanterns)do l.envelope.Color=Lanterns.lookAt(glow,l.place).envelope end
		if self.folder then self.folder:SetAttribute("AirGlow",if lit then math.floor(glow*100+.5)/100 else 0)end
	end
	self.lightHosts={}
	if lit and typeof(camera)=="Vector3"then
		-- The skyline pair never carries a light.
		local positions,owners={}, {}
		for _,l in ipairs(self.lanterns)do
			if not l.far then table.insert(positions,l.flame.CFrame.Position);table.insert(owners,l)end
		end
		local picks=Lanterns.nearest(positions,camera,#self.lights)
		for k,light in ipairs(self.lights)do
			local l=owners[picks[k]]
			if light.Parent~=l.flame then light.Parent=l.flame end
			self.lightHosts[k]=l
			light.Enabled=true
		end
	else
		for _,light in ipairs(self.lights)do light.Enabled=false end
	end
	self.emitter.Enabled=Lanterns.fluff(daylight)and not reduced
end

-- The flame's size and see-through for balloon l now (the burn's growth; at night the flicker), and its flicker.
function Client:burner(l,now,reduced)
	local L=Lanterns.Look
	local grow=if reduced then 1 else l.grow
	local flick=if self.lit and not reduced then Lanterns.flicker(now,l.flicker)else 1
	l.flick=flick
	local size=L.flame*grow*flick*(l.scale or 1)
	if l.flameSize~=size then l.flame.Size=Vector3.new(size,size,size);l.flameSize=size end
	-- A burn by day shows the flame (its see-through falls with the growth).
	local burning=math.clamp((grow-1)/(Lanterns.Burn.grow-1),0,1)
	local clear=(self.lookNow and self.lookNow.flameClear or L.day.flameClear)*(1-.8*burning)
	if l.flameClear~=clear then l.flame.Transparency=clear;l.flameClear=clear end
end

-- Mascots -------------------------------------------------------------------------------------------------------
local function wrap(a)return math.atan2(math.sin(a),math.cos(a))end
-- Start one of PetIdleBeats' beats on the visual (its own scheduler only continues it).
function Client.beat(visual,kind,side)
	local s=visual.idleBeat
	if not s then s={idle=0,clock=0,last=0};visual.idleBeat=s end
	s.kind,s.age,s.duration,s.side,s.previous,s.landed=kind,0,IdleBeats.Durations[kind]or 2,side,kind,false
	visual.poseDirty=true
end
-- Behaviour and pose for mascot m, its balloon at `base` (CFrame), `dt` since its last step.
function Client:poseMascot(m,base,dt,reduced,listener,daylight,update)
	local M=Lanterns.Mascot
	local visual=m.visual
	local now=self.now()
	m.acc+=dt
	visual.reducedEffects=reduced==true
	local distance=if typeof(listener)=="Vector3"then(listener-visual.origin).Magnitude else nil
	if Lanterns.shouldWave(distance,now,m.lastWave)then
		m.lastWave,m.waveAt,m.cheered=now,now,false
		if visual.idleBeat then visual.idleBeat.kind=nil end
		if not reduced then pcall(visual.greet,visual)end
		-- Sounds stay under Reduced Motion.
		local squeaked=self:sound("squeak",visual.origin)
		if squeaked and self.folder then self.folder:SetAttribute("AirLastSqueak",now)end
	end
	if reduced then
		if m.atRest and not update then return end
		m.atRest=true
	else
		m.atRest=false
		local waveAge=if m.waveAt then now-m.waveAt else math.huge
		local waving=waveAge<M.waveFor+M.hopFor
		if waving and not m.cheered and waveAge>=M.waveFor then m.cheered=true;self.cheer(visual)end
		-- Face the player once they have been waved at and are still near; otherwise ease back.
		local target=m.restYaw
		if m.lastWave and distance and distance<=M.waveRange then
			local d=listener-visual.origin
			if d.X*d.X+d.Z*d.Z>.01 then target=math.atan2(d.X,d.Z)end
		end
		local delta=wrap(target-(visual.yaw or 0))
		local turn=M.turnRate*dt
		visual.yaw=wrap((visual.yaw or 0)+math.clamp(delta,-turn,turn))
		-- A look about (or an emote) every 4 to 7 s, never over a wave.
		if waving then m.nextBeat=math.max(m.nextBeat,now+1)
		elseif now>=m.nextBeat then
			Client.beat(visual,Lanterns.pickBeat(self.random,daylight),if self.random:NextNumber()<.5 then -1 else 1)
			m.nextBeat=now+Lanterns.lookGap(self.random)
		end
		-- Hold PetIdleBeats' own picker off (it would sit the pet down in the basket).
		local s=visual.idleBeat
		if s and not s.kind then s.last=s.clock;s.idle=0 end
	end
	local hop=if reduced then 0 else Lanterns.hop(if m.waveAt then now-m.waveAt else nil)
	visual.origin=(base*CFrame.new(0,m.footY+hop,0)).Position
	if update==false then return end
	m.steps+=1
	local every=if update==true then 1 else(m.every or 1)
	if m.steps%every~=0 and not reduced then return end
	visual:update(m.acc)
	m.acc=0
	self:placeHalo(m,now,reduced)
end
-- The cherub's halo .25 over the head piece, bobbing .05.
function Client:placeHalo(m,now,reduced)
	if not m.halo then return end
	local M=Lanterns.Mascot
	local visual=m.visual
	if m.piecesRef~=visual.pieces then
		m.piecesRef=visual.pieces;m.head=nil
		for _,entry in ipairs(visual.pieces or {})do if entry.name=="Head"then m.head=entry.part;break end end
	end
	local top
	if m.head then top=m.head.CFrame.Position+Vector3.new(0,m.head.Size.Y/2,0)
	else top=visual.origin+Vector3.new(0,1.1*(visual.scale or 1),0)end
	local bob=if reduced then 0 else M.haloBob*math.sin(math.pi*2*now/M.haloPeriod+m.lantern.index)
	m.halo.CFrame=CFrame.new(top+Vector3.new(0,M.haloOver+bob,0))*CFrame.Angles(0,visual.yaw or 0,math.pi/2)
end

function Client:step(dt)
	if self.destroyed or not self.built then return end
	self.clock+=dt or 0
	self.lookClock+=dt or 0
	if self.clock<Lanterns.Rate then return end
	local stepDt=self.clock
	self.clock=0
	if not self:wanted()then self:sleep(true);return end
	local now=self.now()
	local camera=self.camera()
	local reduced=self.reduced()
	if self.lookClock>=Lanterns.LookRate then
		self.lookClock=0
		self:look(camera,reduced)
	end
	local listener=self.listener()
	local phone=self.phone()
	-- The skyline pair steps at FarRate.
	self.farClock=(self.farClock or math.huge)+stepDt
	local farStep=self.farClock>=Lanterns.FarRate
	if farStep then self.farClock=0 end
	local parts,frames={},{}
	for _,l in ipairs(self.lanterns)do
		local near=(l.rest.Position-camera).Magnitude<=Lanterns.cullFor(l.place,phone)and(farStep or not l.far)
		if near then
			-- The burner: its schedule runs (and sounds) under Reduced Motion too; only the growth and lift are still.
			if now>=l.nextBurn then
				l.burnAt,l.nextBurn=now,now+Lanterns.burnGap(self.random)
				self:sound("burn",l.flame.CFrame.Position)
			end
			local grow,lift=Lanterns.burn(now-l.burnAt)
			l.grow=grow
			self:burner(l,now,reduced)
			local base
			if not reduced or not l.atRest then
				base=if reduced then l.rest else self:frame(l,now)+Vector3.new(0,lift,0)
				local moved=not l.atRest or not reduced
				l.atRest=reduced
				if moved then
					for k,p in ipairs(l.pieces)do
						table.insert(parts,p);table.insert(frames,base*l.offsets[k])
					end
				end
				l.base=base
			end
			local m=l.mascot
			if m then
				m.every=if(l.rest.Position-camera).Magnitude<=Lanterns.Mascot.near then 1 else Lanterns.Mascot.slowEvery
				self:poseMascot(m,l.base or l.rest,stepDt,reduced,listener,self.daylightNow,if reduced and not m.atRest then true else nil)
			end
		end
	end
	if #parts>0 then
		if self.d.move then self.d.move(parts,frames)
		else workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
	end
	-- The lights flicker with their burners.
	if self.lit and self.lookNow and self.lightHosts then
		for k,light in ipairs(self.lights)do
			local l=self.lightHosts[k]
			if l then light.Brightness=self.lookNow.light*(if reduced then 1 else l.flick)end
		end
	end
end

function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,c in ipairs(self.connections)do c:Disconnect()end
	self:teardown()
end
return Client
