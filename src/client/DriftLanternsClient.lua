-- Drift lanterns, the garden's air (GARDEN-PLAY-BRIEF 2026-11-26 section 4; DriftLanterns holds the numbers): nine
-- round paper lanterns (a globe round a glowing core, ribs, caps and a tassel) built from plain parts on this client, each bobbing, drifting on its own small circle and
-- swaying (WorldMotion.pose "bob" and "sway", every lantern its own phase), and a soft seed-fluff emitter over the hub
-- by day. Nothing replicates; they cannot be touched.
--
-- Gate: the Alive `air` switch (beta and Studio); off, nothing is built (turned off at runtime, it is all taken down).
-- Day and night follow HollowClock.daylight like the lamps: under .3, over DriftLanterns.GlowSpan, the Neon core and
-- the see-through Cardboard globe warm (DriftLanterns.lookAt, Fable B35), and the four lanterns nearest the camera carry
-- the four PointLights on their cores. One loop: 30 Hz while a lantern is within the cull
-- distance (90 studs on a phone, 150 elsewhere) of the camera and the garden is up (Mode Room); otherwise it sleeps and
-- looks again every .5 s. Reduced Motion: every lantern at rest and no fluff (the night look still follows the clock).
--
-- Instance state for probes: workspace.DriftLanternsLocal (attributes AirAwake, AirParts, AirGlow).
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Lanterns=require(Shared:WaitForChild("DriftLanterns"))
local World=require(Shared:WaitForChild("HollowWorldLayout"))

local Client={};Client.__index=Client
Client.Folder="DriftLanternsLocal"
-- The fluff's look: the engine's own soft particle, tiny and cream, falling slowly (no new texture).
Client.FluffTexture="rbxasset://textures/particles/smoke_main.dds"

local function material(name,fallback)
	local ok,value=pcall(function()return(Enum.Material::any)[name]end)
	if ok and value~=nil then return value end
	return(Enum.Material::any)[fallback]
end

-- deps (specs): alive, parent, heartbeat (false: the spec steps), now, daylight() -> number, camera() -> Vector3,
-- mode() -> string, reduced() -> bool, phone() -> bool, move(parts, frames), pose (WorldMotion.pose), delay(s, fn),
-- worldVersion.
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
	self.pose=deps.pose or require(script.Parent.WorldMotion).pose
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

function Client:build()
	if self.built then return end
	self.built=true
	local folder=Instance.new("Folder");folder.Name=Client.Folder
	folder.Parent=self.d.parent or workspace
	self.folder=folder
	local L=Lanterns.Look
	local paper,smooth,wood=material("Cardboard","SmoothPlastic"),material("SmoothPlastic","SmoothPlastic"),material("Wood","Wood")
	local neon=material("Neon","Neon")
	local count=0
	self.lanterns={}
	for i,place in ipairs(Lanterns.Places)do
		local y=World.groundY(place.x,place.z)+place.over
		local rest=CFrame.new(place.x,y,place.z)*CFrame.Angles(0,Lanterns.phases(i)*math.pi,0)
		local accent=L.accents[place.accent]
		local pieces,offsets={}, {}
		local function add(p,offset)table.insert(pieces,p);table.insert(offsets,offset);count+=1;return p end
		local function disc(name,tall,across,dy,colour,mat)
			local offset=CFrame.new(0,dy,0)*CFrame.Angles(0,0,math.pi/2) -- a Cylinder's axis is X: stood up
			local p=add(part(name,Vector3.new(tall,across,across),rest*offset,colour,mat,folder),offset)
			p.Shape=Enum.PartType.Cylinder
			return p
		end
		-- The see-through paper globe round its Neon core.
		local globe=add(part(place.id.."_globe",Vector3.new(L.globe,L.globe,L.globe),rest,L.day.paper,paper,folder),CFrame.new())
		globe.Shape=Enum.PartType.Ball;globe.Transparency=L.day.paperClear
		local core=add(part(place.id.."_core",Vector3.new(L.core,L.core,L.core),rest,L.day.core,neon,folder),CFrame.new())
		core.Shape=Enum.PartType.Ball;core.Transparency=L.day.coreClear
		-- The paper's hoops, in the accent.
		for k,rib in ipairs(L.ribs)do disc(place.id.."_rib"..k,L.rib,rib[2],rib[1],accent,smooth)end
		-- Bark caps top and bottom, and the tassel under the lower one.
		disc(place.id.."_cap1",L.cap,L.capAcross,L.capY,L.bark,wood)
		disc(place.id.."_cap2",L.cap,L.capAcross,-L.capY,L.bark,wood)
		local tasselOffset=CFrame.new(0,-L.capY-L.cap/2-L.tassel/2,0)
		add(part(place.id.."_tassel",Vector3.new(L.tasselWidth,L.tassel,L.tasselWidth),rest*tasselOffset,accent,smooth,folder),tasselOffset)
		local bob,_,sway=Lanterns.phases(i)
		table.insert(self.lanterns,{index=i,rest=rest,pieces=pieces,offsets=offsets,globe=globe,core=core,bob=bob,sway=sway,
			top=L.capY+L.cap/2})
	end
	-- Four lights, handed to the nearest lanterns at night.
	self.lights={}
	for k=1,Lanterns.Lights.count do
		local light=Instance.new("PointLight")
		light.Name="lantern_light"..k
		light.Range=Lanterns.Lights.range;light.Brightness=Lanterns.Lights.brightness
		light.Color=Color3.fromHex(L.night.core);light.Shadows=false;light.Enabled=false
		light.Parent=self.lanterns[k].core
		table.insert(self.lights,light)
	end
	-- The seed fluff over the hub.
	local F=Lanterns.Fluff
	local host=part("seed_fluff",F.size,CFrame.new(F.x,World.groundY(F.x,F.z)+F.over,F.z),F.colour,material("SmoothPlastic","SmoothPlastic"),folder)
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
	self.parts=count
	self.glowNow=nil
	folder:SetAttribute("AirParts",count)
end

function Client:teardown()
	self:sleep()
	if self.folder then self.folder:Destroy()end
	self.folder=nil;self.built=false
	self.lanterns,self.lights,self.emitter=nil,nil,nil
end

function Client:cull()return if self.phone()then Lanterns.Cull.phone else Lanterns.Cull.desktop end
function Client:wanted()
	if not self.built or self.mode()~="Room"then return false end
	local camera=self.camera()
	if typeof(camera)~="Vector3"then return false end
	local reach=self:cull()
	for _,l in ipairs(self.lanterns)do if(l.rest.Position-camera).Magnitude<=reach then return true end end
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

-- Where lantern l is at t: its rest, drifted, bobbed and swayed about its top.
function Client:frame(l,t)
	local M=Lanterns.Motion
	local at=l.rest+Lanterns.drift(l.index,t)
	at=self.pose("bob",at,nil,M.bob,M.bobPeriod,l.bob,t)
	return self.pose("sway",at,(at*CFrame.new(0,l.top,0)).Position,M.sway,M.swayPeriod,l.sway,t)
end

-- The day / night look (Fable B35): the core and paper colours and see-through, the lights' owners and brightness,
-- the fluff.
function Client:look(camera,reduced)
	local daylight=self.daylight()
	local glow=Lanterns.glow(daylight)
	local lit=Lanterns.lit(daylight)
	local key=if lit then math.floor(glow*20+.5)else -1
	local look=Lanterns.lookAt(glow)
	if key~=self.glowNow then
		self.glowNow=key
		for _,l in ipairs(self.lanterns)do
			l.core.Color=look.core;l.core.Transparency=look.coreClear
			l.globe.Color=look.paper;l.globe.Transparency=look.paperClear
		end
		if self.folder then self.folder:SetAttribute("AirGlow",if lit then math.floor(glow*100+.5)/100 else 0)end
	end
	if lit and typeof(camera)=="Vector3"then
		local positions={}
		for i,l in ipairs(self.lanterns)do positions[i]=l.core.CFrame.Position end
		local picks=Lanterns.nearest(positions,camera,#self.lights)
		for k,light in ipairs(self.lights)do
			local host=self.lanterns[picks[k]].core
			if light.Parent~=host then light.Parent=host end
			light.Brightness=look.light
			light.Enabled=true
		end
	else
		for _,light in ipairs(self.lights)do light.Enabled=false end
	end
	self.emitter.Enabled=Lanterns.fluff(daylight)and not reduced
end

function Client:step(dt)
	if self.destroyed or not self.built then return end
	self.clock+=dt or 0
	self.lookClock+=dt or 0
	if self.clock<Lanterns.Rate then return end
	self.clock=0
	if not self:wanted()then self:sleep(true);return end
	local now=self.now()
	local camera=self.camera()
	local reduced=self.reduced()
	if self.lookClock>=Lanterns.LookRate then
		self.lookClock=0
		self:look(camera,reduced)
	end
	local reach=self:cull()
	local parts,frames={},{}
	for _,l in ipairs(self.lanterns)do
		local near=(l.rest.Position-camera).Magnitude<=reach
		if near and(not reduced or not l.atRest)then
			local base=if reduced then l.rest else self:frame(l,now)
			l.atRest=reduced
			for k,p in ipairs(l.pieces)do
				table.insert(parts,p);table.insert(frames,base*l.offsets[k])
			end
		end
	end
	if #parts>0 then
		if self.d.move then self.d.move(parts,frames)
		else workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
	end
end

function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,c in ipairs(self.connections)do c:Disconnect()end
	self:teardown()
end
return Client
