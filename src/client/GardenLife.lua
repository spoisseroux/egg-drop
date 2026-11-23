-- Garden life (ALIVE-LIFE-BUILD-PLAN-2026-11-22, Alive step 5): petals off the blossom crowns in a gust, soap bubbles
-- drifting past the camera, a round bird on the crown where AmbientAudio's chirp came from, butterflies over the
-- flower patches, and Dewdrops hanging under the lime crowns that a strong gust shakes loose (WORLD-PASS item 3,
-- artifacts/world-pass-2026-11-22/FRUIT-LOOK.md). Client only and looks only: no remotes, no saves, nothing to collect.
-- LifeSim decides; this owns the parts.
--
-- mount() is nil with the build ceiling off (Alive.ceiling("life")). With the switch off only the Alive signal is
-- connected and nothing exists. On: one folder EggDropLife in the workspace (birds 3 x 6 parts, butterflies 4 x 3,
-- three petal anchors and two bubble anchors, each with a ParticleEmitter, 16 Dewdrop anchors each with a BillboardGui),
-- ONE Heartbeat at 30 Hz (15 at budget level 1) and ONE BulkMoveTo a step; a part not in use is moved far away, never
-- re-parented or resized.
--   Dewdrops: what falls is LifeSim's Grove, a pure function of the server time over every lime crown (the gust
--   number seeds it), so every client has the same fruit go whatever it sees or runs at. Drawing only: lime crowns
--   within 90 studs, nearest first, 16 / 8 shown (level 0 / 1, no sway at 1), at most 3 / 2 loose; a pet within 3 studs
--   bats a resting one in place; never landing on a find spot, the Dash course or a park kerb. Reduced Motion: they
--   just hang, every slot full.
--   Parked (a hatch, the board out of Room mode, my own race): everything hidden, nothing simulated.
--   A menu: bubbles stop starting; the rest goes on behind the shade.
--   Reduced Motion: no petals, bubbles or flight; a bird is just there on its crown, folded and still; fruit hangs.
--   Budget level 2: nothing at all (torn down, and it never comes back up that session).
--   The garden hour (GARDEN-HOUR-BUILD-PLAN-2026-11-23 slice D): with it on, bubbles, butterflies and birds start only
--   while its daylight is above .7 (Sim.day); the ones out finish (bubbles pop on time, butterflies fly off, birds sit out
--   their stay). Petals and Dewdrops never ask. The daylight is GardenHour's, from the server clock, so the gate is the
--   same on every client; with the hour off it is nil and nothing changes. On is HollowClock.hourOn(): the hour and the
--   Aero look painting it, so a client whose AeroWorld did not start keeps today's garden under today's light.
--   The switch off, or a step that throws: everything gone in that frame.
-- deps: ambient (the AmbientAudio instance: onChirp is set while on), dash() -> DashClient?, modalOpen(), reduced(),
--   mode(), plus fixtures for specs: alive {ceiling, on, changed}, world, heartbeat, now, camera() -> CFrame?,
--   root() -> Vector3?, move(parts, frames), hatching, level, spots, patches, stations, pad, course, crowns() -> "lime"|"pink",
--   groundY, warn, seed; pets() -> {Vector3} (the garden pets this client draws, for the fruit bat), finds {Vector3},
--   kerbs {{x, z, rx, rz}}, safe(x, z) -> boolean (walkable ground: IslandBounds.safeCell), daylight(now) -> number?
--   (the garden hour's, nil while it is off; read every Poll).
local GuiService=game:GetService("GuiService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Sim=require(script.Parent.LifeSim)
local Wind=require(script.Parent.Wind)

local Life={};Life.__index=Life
Life.Folder="EggDropLife"
Life.Poll=2        -- seconds: petal crowns re-picked, crown colour and the race read again
Life.Gate=.25      -- seconds between hatch checks
Life.MaxStep=.1
Life.Hidden=CFrame.new(0,4096,0)
Life.PetalReach=90 -- a crown farther than this from the camera drops no petals
Life.PetalTexture="rbxassetid://112974880714881"
Life.BubbleTexture="rbxassetid://77828632873187"
-- LOOK-R2 5: drawn by scripts/draw_life_textures.py, uploaded 2026-11-22.
Life.BirdEye="rbxassetid://127417519256529"
Life.BirdWing="rbxassetid://81512459364906"
Life.ButterflyWing="rbxassetid://108754043011076"
Life.ButterflyWingM="rbxassetid://95949019207820" -- the mirror of ButterflyWing
-- FRUIT-LOOK 1: assets/world/dewdrop.png (scripts/draw_world_textures.py), uploaded 2026-11-23. Billboard studs.
Life.DewdropTexture="rbxassetid://82054526707528"
Life.FruitSize=Vector2.new(1.1,1.28)
local hex=Color3.fromHex
Life.Ink=hex("#24304F")
Life.EyeInk=hex("#161C38")
-- LOOK-R2 1, picked by perch index % 3; the wing is its decals' Color3.
Life.BirdColours=table.freeze({
	[0]=table.freeze({body=hex("#2A6BE0"),wing=hex("#173F9E"),beak=hex("#FF9F1C")}), -- Tide
	[1]=table.freeze({body=hex("#FF7C6B"),wing=hex("#C93F3A"),beak=hex("#FFD23F")}), -- Coral
	[2]=table.freeze({body=hex("#FFD23F"),wing=hex("#E08A10"),beak=hex("#FF7A1A")}), -- Sun
})
-- LOOK 2: Rose, Citrus, Iris, Tide; one of each while four are alive.
Life.WingColours=table.freeze({hex("#FF327A"),hex("#FFCC00"),hex("#7A35F0"),hex("#0A4FD0")})
-- LOOK-R2 3, by emitter slot: lime crowns (Aero on) or pink.
Life.PetalColours=table.freeze({
	lime=table.freeze({hex("#FFF6C2"),hex("#FFE66B"),hex("#F4FFD0")}),
	pink=table.freeze({hex("#FFB8D6"),hex("#FF8FBF"),hex("#FFE3EE")}),
})
-- Petals leave downwind along the ground plane at Speed, slowed by Drag; LOOK-R2's small Acceleration sinks them to
-- grass height over the life (round 1's downward heading on top of it would sink them twice, under the lawn).
Life.PetalHeading=Wind.Direction
Life.PetalDrag=.25
Life.PetalSink=Vector3.new(0,-.5,0)
-- Bubbles: rise .4 and drift 1.5 to 3 a second downwind.
Life.BubbleHeading=(Wind.Direction*2.25+Vector3.new(0,Sim.BubbleRise,0)).Unit

local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end

-- Parts ---------------------------------------------------------------------------------------------------------
local function part(folder,name,class,size,colour,shape)
	local p=Instance.new(class or "Part")
	p.Name=name
	p.Anchored=true
	p.CastShadow=false
	p.CanCollide=false
	p.CanQuery=false
	p.CanTouch=false
	p.Massless=true
	p.Material=Enum.Material.SmoothPlastic
	p.Reflectance=0
	p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
	if shape then p.Shape=shape end
	p.Size=size
	p.Color=colour or Life.Ink
	p.Transparency=if colour==false then 1 else 0
	p.CFrame=Life.Hidden
	p.Parent=folder
	return p
end

-- A see-through plate's decal (LOOK-R2: a Decal still draws on a part at Transparency 1).
local function decal(p,face,texture,colour)
	local d=Instance.new("Decal")
	d.Name="Decal"..face.Name
	d.Texture=texture
	d.Face=face
	d.Color3=colour
	d.Transparency=0
	d.ZIndex=1
	d.Parent=p
	return d
end

local function petalEmitter(anchor)
	local e=Instance.new("ParticleEmitter")
	e.Name="Petals"
	e.Texture=Life.PetalTexture
	e.Rate=0
	e.Enabled=true
	e.LockedToPart=false
	e.EmissionDirection=Enum.NormalId.Front
	e.Shape=Enum.ParticleEmitterShape.Box
	e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface
	e.Orientation=Enum.ParticleOrientation.FacingCamera
	e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.40),NumberSequenceKeypoint.new(.10,.68,.12),NumberSequenceKeypoint.new(1,.60,.10)})
	e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.08,.05),NumberSequenceKeypoint.new(.75,.05),NumberSequenceKeypoint.new(1,1)})
	e.Squash=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.2,-.5),NumberSequenceKeypoint.new(.4,.1),
		NumberSequenceKeypoint.new(.6,-.5),NumberSequenceKeypoint.new(.8,.1),NumberSequenceKeypoint.new(1,-.3)})
	e.Rotation=NumberRange.new(0,360)
	e.RotSpeed=NumberRange.new(-120,120)
	e.LightEmission,e.LightInfluence,e.Brightness=0,.5,1
	e.ZOffset=0
	e.Speed=NumberRange.new(3.5,6)
	e.SpreadAngle=Vector2.new(25,25)
	e.Lifetime=NumberRange.new(5,Sim.PetalLife)
	e.Drag=Life.PetalDrag
	e.Acceleration=Life.PetalSink
	e.Parent=anchor
	return e
end

-- One fixed diameter per emitter (LOOK-R2 4): Size and Transparency are set here once and never again.
local function bubbleEmitter(anchor,kind)
	local e=Instance.new("ParticleEmitter")
	e.Name=if kind=="small"then "BubblesSmall"else "BubblesLarge"
	e.Texture=Life.BubbleTexture
	e.Rate=0
	e.Enabled=true
	e.LockedToPart=false
	e.EmissionDirection=Enum.NormalId.Front
	e.Orientation=Enum.ParticleOrientation.FacingCamera
	e.Color=ColorSequence.new(hex("#FFFFFF"))
	-- In over .4 s (1 to .10), out over the last .3 s of 9.
	e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.4/Sim.BubbleLife,.10),
		NumberSequenceKeypoint.new(1-.3/Sim.BubbleLife,.10),NumberSequenceKeypoint.new(1,1)})
	e.Size=NumberSequence.new(Sim.BubbleSizes[kind])
	e.LightEmission,e.LightInfluence,e.Brightness=0,0,1
	e.ZOffset=0
	local drift=Sim.BubbleDrift
	e.Speed=NumberRange.new(math.sqrt(drift[1]^2+Sim.BubbleRise^2),math.sqrt(drift[2]^2+Sim.BubbleRise^2))
	e.SpreadAngle=Vector2.new(8,8)
	e.Lifetime=NumberRange.new(Sim.BubbleLife)
	e.Rotation=NumberRange.new(0,360)
	e.RotSpeed=NumberRange.new(-15,15)
	e.Drag=0
	e.Acceleration=Vector3.zero
	e.Parent=anchor
	return e
end

-- A Dewdrop (FRUIT-LOOK 1): an invisible anchor at the image centre with one BillboardGui and its ImageLabel. The
-- entry caches what was last written so a step only writes what changed.
local function dewdrop(folder,slot)
	local anchor=part(folder,"LifeDewdrop"..slot,"Part",Vector3.new(.2,.2,.2),false)
	local gui=Instance.new("BillboardGui")
	gui.Name="Dewdrop"
	gui.Size=UDim2.fromScale(Life.FruitSize.X,Life.FruitSize.Y)
	gui.LightInfluence=.6
	gui.Brightness=1
	gui.AlwaysOnTop=false
	gui.MaxDistance=110
	gui.ClipsDescendants=false
	gui.Active=false
	gui.Parent=anchor
	local label=Instance.new("ImageLabel")
	label.Name="Image"
	label.Size=UDim2.fromScale(1,1)
	label.BackgroundTransparency=1
	label.BorderSizePixel=0
	label.Image=Life.DewdropTexture
	label.ImageColor3=Color3.new(1,1,1)
	label.ImageTransparency=0
	label.ScaleType=Enum.ScaleType.Stretch
	label.Rotation=0
	label.Parent=gui
	return{anchor=anchor,gui=gui,label=label,key=nil,position=nil,rotation=0,transparency=0,w=1,h=1}
end

-- Mount ---------------------------------------------------------------------------------------------------------
function Life.mount(deps)
	deps=deps or {}
	local Shared=ReplicatedStorage:WaitForChild("Shared")
	local alive=deps.alive or require(Shared:WaitForChild("Alive"))
	if not alive.ceiling("life")then return nil end
	local self=setmetatable({d=deps,alive=alive,enabled=false,connections={},seed=deps.seed or 20261122},Life)
	self.world=deps.world or workspace
	self.heartbeat=deps.heartbeat or RunService.Heartbeat
	self.now=deps.now or function()return workspace:GetServerTimeNow()end
	self.level=deps.level or require(script.Parent.AliveBudget).level
	self.hatching=deps.hatching or require(script.Parent.WindClient).hatching
	self.move=deps.move or function(parts,frames)workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
	self.camera=deps.camera or function()local c=workspace.CurrentCamera;return c and c.CFrame end
	self.warn=deps.warn or warn
	local board
	local function attribute(name)
		if not(board and board.Parent)then
			local boards=ReplicatedStorage:FindFirstChild("EggDropBoards")
			local player=Players.LocalPlayer
			board=boards and player and boards:FindFirstChild(tostring(player.UserId))
		end
		return board and board:GetAttribute(name)
	end
	self.mode=deps.mode or function()return attribute("Mode")end
	self.reduced=deps.reduced or function()return GuiService.ReducedMotionEnabled or attribute("ReducedEffects")==true end
	self.root=deps.root or function()
		local character=Players.LocalPlayer and Players.LocalPlayer.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		return root and root.Position
	end
	self.pets=deps.pets or function()return{}end
	self.daylight=deps.daylight or function(now)
		if not require(script.Parent.HollowClock).hourOn()then return nil end
		local Hour=require(Shared:WaitForChild("GardenHour"))
		return Hour.phase(now+Hour.offset()).daylight
	end
	table.insert(self.connections,alive.changed("life"):Connect(function()self:sync()end))
	self:sync()
	return self
end

function Life:sync()
	if self.destroyed then return end
	local on=self.alive.on("life")==true and Sim.level(self.level())<2
	if on==self.enabled then return end
	if not on then self:disable();return end
	local ok,problem=pcall(self.enable,self)
	if not ok then self:fail(problem)end
end

function Life:fail(problem)
	self:disable()
	self.warn("[Life] stopped: "..tostring(problem))
end

-- The world's places, read once a switch-on (data, never instances: crowns are merged meshes, revision 1).
function Life:places()
	local d=self.d
	local Shared=ReplicatedStorage:WaitForChild("Shared")
	self.spots=d.spots or require(script.Parent.LifeSpots)
	local stations=d.stations
	if not stations then
		stations={}
		for _,frame in pairs(require(Shared:WaitForChild("HollowWorldLayout")).Stations or {})do table.insert(stations,frame.Position)end
	end
	self.stations=stations
	local patches=d.patches
	if not patches then
		patches={}
		for _,row in ipairs(require(Shared:WaitForChild("WorldDressing")).Flowers or {})do table.insert(patches,Vector3.new(row[1],row[2],row[3]))end
	end
	self.patches=patches
	if d.course~=nil or d.pad~=nil then
		self.course,self.pad=d.course or nil,d.pad or nil
	else
		local Course=require(Shared:WaitForChild("DashCourse"))
		self.course=Sim.courseLine(Course.Main,Course.Branch)
		self.pad={x=Course.Pad.x/100,z=Course.Pad.z/100,r=Course.Pad.r/100}
	end
	self.groundY=d.groundY
	-- Dewdrops land only on walkable lawn, off every find spot and park kerb (FRUIT-LOOK 7). Shared data only: the
	-- grove decides what falls from this and the server time, never from this client's camera or settings.
	local finds=d.finds
	if not finds then
		finds={}
		for _,spot in ipairs(require(Shared:WaitForChild("FindSpots")))do table.insert(finds,Vector3.new(spot.x/100,spot.y/100,spot.z/100))end
	end
	local kerbs=d.kerbs
	if not kerbs then
		kerbs={}
		local Park=require(Shared:WaitForChild("ParkLayout"))
		for _,site in ipairs(Park.Sites or {Park})do
			table.insert(kerbs,{x=site.Center.X,z=site.Center.Z,rx=site.Radius.X,rz=site.Radius.Y})
		end
	end
	self.fruitWorld={stations=self.stations,pad=self.pad,course=self.course,finds=finds,kerbs=kerbs,
		groundY=d.groundY or require(Shared:WaitForChild("HollowWorldLayout")).groundY,
		safe=d.safe or require(Shared:WaitForChild("IslandBounds")).safeCell}
	self.crowns=d.crowns or function()
		local Aero=require(Shared:WaitForChild("Aero"))
		return if Aero.on()and Aero.trees()=="lime"then "lime"else "pink"
	end
end

function Life:enable()
	if self.enabled or self.destroyed then return end
	self.enabled=true
	self:places()
	local folder=Instance.new("Folder")
	folder.Name=Life.Folder
	self.folder=folder
	self.shown={}
	self.birdPool,self.flyPool,self.petalPool={},{},{}
	-- Birds (LOOK-R2 1, REVIEW-R2): body, two eye discs (thin cylinders, the eye decal on both round caps), a beak cube
	-- turned corner-first, two wing plates. Six parts.
	local Face=Enum.NormalId
	local white=Color3.new(1,1,1)
	for slot=1,Sim.Caps.birds[1]do
		local look=Life.BirdColours[0]
		local name="LifeBird"..slot.."_"
		local eyes={}
		for _,side in ipairs({"EyeR","EyeL"})do
			local disc=part(folder,name..side,"Part",Vector3.new(.06,.46,.46),Life.EyeInk,Enum.PartType.Cylinder)
			decal(disc,Face.Left,Life.BirdEye,white);decal(disc,Face.Right,Life.BirdEye,white)
			eyes[side]=disc
		end
		local wings={}
		for i,side in ipairs({"WingL","WingR"})do
			local plate=part(folder,name..side,"Part",Vector3.new(.04,.66,.46),false)
			decal(plate,Face.Left,Life.BirdWing,look.wing);decal(plate,Face.Right,Life.BirdWing,look.wing)
			wings[i]=plate
		end
		self.birdPool[slot]={
			part(folder,name.."Body","Part",Vector3.new(1.2,1.2,1.2),look.body,Enum.PartType.Ball),
			eyes.EyeR,
			part(folder,name.."Beak","Part",Vector3.new(.26,.26,.26),look.beak),
			wings[1],wings[2],
			eyes.EyeL,
		}
	end
	-- Butterflies (LOOK-R2 2): body, two wing plates thin in Z; each wing's two faces carry the file and its mirror, so
	-- from above and below the dark root touches the body and the larger lobe is forward.
	for slot=1,Sim.Caps.butterflies[1]do
		local wing=Life.WingColours[slot]
		local name="LifeButterfly"..slot.."_"
		local left=part(folder,name.."WingL","Part",Vector3.new(.70,.84,.02),false)
		decal(left,Face.Back,Life.ButterflyWingM,wing);decal(left,Face.Front,Life.ButterflyWing,wing)
		local right=part(folder,name.."WingR","Part",Vector3.new(.70,.84,.02),false)
		decal(right,Face.Back,Life.ButterflyWing,wing);decal(right,Face.Front,Life.ButterflyWingM,wing)
		self.flyPool[slot]={part(folder,name.."Body","Part",Vector3.new(.10,.10,.50),Life.Ink),left,right}
	end
	for slot=1,Sim.Caps.emitters[1]do
		local anchor=part(folder,"LifePetals"..slot,"Part",Vector3.new(1,1,1),false)
		self.petalPool[slot]={anchor=anchor,emitter=petalEmitter(anchor)}
	end
	self.fruitPool={}
	for slot=1,Sim.Fruit.pool do self.fruitPool[slot]=dewdrop(folder,slot)end
	self.bubblePool={}
	for _,kind in ipairs({"small","large"})do
		local anchor=part(folder,if kind=="small"then "LifeBubblesSmall"else "LifeBubblesLarge","Part",Vector3.new(.2,.2,.2),false)
		self.bubblePool[kind]={anchor=anchor,emitter=bubbleEmitter(anchor,kind)}
	end
	self.birds=Sim.Birds.new(self.seed)
	self.flies=Sim.Butterflies.new(self.seed+1)
	self.petals=Sim.Petals.new()
	self.bubbles=Sim.Bubbles.new(self.seed+2)
	self.grove=Sim.Grove.new(self.spots.Crowns or {},self.fruitWorld)
	self.loose=Sim.Loose.new()
	self.view,self.fruitOf,self.fruitCount={},{},0
	self.picked={}
	self.elapsed,self.since,self.steps,self.pollIn,self.gateIn=0,0,0,0,0
	self.parked,self.hatch,self.live,self.wasReduced,self.colours,self.lime=false,false,false,false,nil,false
	self:readDay(self.now())
	folder.Parent=self.world
	local ambient=self.d.ambient
	if ambient then
		self.hook=function(perch,position,cue)self:chirp(perch,position,cue)end
		ambient.onChirp=self.hook
	end
	self.beat=self.heartbeat:Connect(function(dt)
		local ok,problem=pcall(self.step,self,dt)
		if not ok then self:fail(problem)end
	end)
end

-- The garden hour's gate, read at enable and every Poll (a failing read is day: the garden as it was).
function Life:readDay(now)
	local ok,daylight=pcall(self.daylight,now)
	self.day=Sim.day(if ok then daylight else nil)
	return self.day
end

-- Off: nothing left but the Alive signal. Cannot throw past the folder's Destroy.
function Life:disable()
	if not self.enabled then return end
	self.enabled=false
	if self.beat then self.beat:Disconnect();self.beat=nil end
	local ambient=self.d.ambient
	if ambient and self.hook and ambient.onChirp==self.hook then ambient.onChirp=nil end
	self.hook=nil
	local folder=self.folder
	self.folder,self.shown,self.birdPool,self.flyPool,self.petalPool,self.bubblePool=nil,nil,nil,nil,nil,nil
	self.birds,self.flies,self.petals,self.bubbles,self.picked=nil,nil,nil,nil,nil
	self.fruitPool,self.grove,self.loose,self.view,self.fruitOf,self.fruitCount=nil,nil,nil,nil,nil,0
	if folder then folder:Destroy()end
end

function Life:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	table.clear(self.connections)
	self:disable()
end

-- Stepping ------------------------------------------------------------------------------------------------------
function Life:racing()
	local dash=self.d.dash and self.d.dash()
	return dash~=nil and dash:held()==true
end

function Life:clearEmitters()
	for _,slot in ipairs(self.petalPool)do slot.emitter:Clear()end
	for _,slot in pairs(self.bubblePool)do slot.emitter:Clear()end
	self.petals:clear()
	self.bubbles:clear()
end

-- Everything hidden in one move, every creature forgotten, every particle cleared.
function Life:park()
	self.parked=true
	self.birds:clear();self.flies:clear()
	self:clearEmitters()
	table.clear(self.picked)
	self:forgetFruit()
	local parts,frames={},{}
	for p in pairs(self.shown)do table.insert(parts,p);table.insert(frames,Life.Hidden)end
	table.clear(self.shown)
	if #parts>0 then self.move(parts,frames)end
end

-- The nearest blossom crowns (up to the level's emitter cap) within reach, none round the camera.
function Life:pick(eye,level)
	local near={}
	for _,crown in ipairs(self.spots.Crowns or {})do
		local d=(crown.position-eye).Magnitude
		if d<=Life.PetalReach and d>=Sim.Keep.camera+crown.size.X*.5 then table.insert(near,{crown=crown,d=d})end
	end
	table.sort(near,function(a,b)return a.d<b.d end)
	local picked={}
	for i=1,math.min(#near,Sim.cap("emitters",level))do picked[i]=near[i].crown end
	return picked
end

function Life:step(dt)
	if self.destroyed or not self.enabled then return end
	if not finite(dt)or dt<=0 then return end
	dt=math.min(dt,Life.MaxStep)
	self.elapsed+=dt;self.since+=dt
	local level=Sim.level(self.level())
	if level>=2 then self:disable();return end
	local rate=Sim.rate(level)
	if self.elapsed<rate then return end
	self.elapsed%=rate
	local tick=math.min(self.since,Life.MaxStep)
	self.since=0
	self.steps+=1
	-- Parked: the hatch first (it owns the screen), then the board, then my own race.
	self.gateIn-=tick
	if self.gateIn<=0 then
		self.gateIn=Life.Gate
		local ok,hatch=pcall(self.hatching)
		self.hatch=ok and hatch==true
	end
	if self.hatch or self.mode()~="Room"or self:racing()then
		if not self.parked then self:park()end
		return
	end
	if self.parked then self.parked=false;self.pollIn=0 end
	local camera=self.camera()
	if typeof(camera)~="CFrame"then return end
	local now=self.now()
	if not finite(now)then return end
	local reduced=self.reduced()==true
	if reduced and not self.wasReduced then self:clearEmitters();self.loose:clear()end
	self.wasReduced=reduced
	local eye=camera.Position
	local parts,frames,emits={},{},{}
	local function put(p,frame)
		table.insert(parts,p);table.insert(frames,frame)
		self.shown[p]=true
	end
	local function hide(p)
		if self.shown[p]then self.shown[p]=nil;table.insert(parts,p);table.insert(frames,Life.Hidden)end
	end
	-- Every Poll seconds: the race, the crown colour and the crowns that drop petals.
	self.pollIn-=tick
	if self.pollIn<=0 then
		self.pollIn=Life.Poll
		local dash=self.d.dash and self.d.dash()
		local ok,summary=pcall(function()return dash and dash:summary()end)
		self.live=ok and type(summary)=="table"and summary.phase=="live"
		self:readDay(now)
		local okColour,colours=pcall(self.crowns)
		self.lime=okColour and colours=="lime"
		colours=Life.PetalColours[okColour and colours or "pink"]or Life.PetalColours.pink
		local repaint=colours~=self.colours
		self.colours=colours
		local picked=if reduced then {}else self:pick(eye,level)
		for slot,entry in ipairs(self.petalPool)do
			local crown=picked[slot]
			if crown~=self.picked[slot]then
				self.picked[slot]=crown
				if crown then
					entry.anchor.Size=crown.size
					put(entry.anchor,CFrame.lookAt(crown.position,crown.position+Life.PetalHeading))
				else hide(entry.anchor)end
			end
			if repaint then entry.emitter.Color=ColorSequence.new(colours[slot])end
		end
	end
	local world={camera=eye,player=self.root(),stations=self.stations,pad=self.pad,course=if self.live then self.course else nil,groundY=self.groundY}
	-- Petals: an Emit against the live count, from the wind where each crown is.
	local winds={}
	for slot=1,#self.petalPool do
		local crown=self.picked[slot]
		winds[slot]=if crown and not reduced then Wind.at(crown.position,now)else false
	end
	for slot,n in ipairs(self.petals:step(now,tick,winds,Sim.cap("petals",level)))do
		if n>0 then table.insert(emits,{self.petalPool[slot].emitter,n})end
	end
	-- Bubbles: one every 3 s ahead of the camera, never in a menu, with Reduced Motion or at night, never in the way.
	-- The roll picks the small or the large emitter; only that one's anchor moves to the spot.
	local menu=self.d.modalOpen and self.d.modalOpen()==true
	if self.bubbles:due(now,Sim.cap("bubbles",level),not reduced and not menu and self.day)then
		local spot=Sim.bubbleSpot(camera,self.bubbles.random,world)
		if spot then
			local slot=self.bubblePool[self.bubbles:emit(now)]
			put(slot.anchor,CFrame.lookAt(spot,spot+Life.BubbleHeading))
			table.insert(emits,{slot.emitter,1})
		end
	end
	-- Wings: two poses swapped at 7.5 Hz (every 2 steps at 30 Hz, every step at 15 Hz); held at level 1.
	local flip=(self.steps//(if level>=1 then 1 else 2))%2==0
	local held=level>=1
	local used={}
	for _,b in ipairs(self.flies:step(now,tick,world,self.patches,Sim.cap("butterflies",level),reduced,self.day))do
		local pool=self.flyPool[b.colour]
		if pool then
			used[pool]=true
			local list=Sim.butterflyParts(Sim.butterflyRoot(b,now),Sim.butterflyFlap(b,now,flip,held))
			for i,p in ipairs(pool)do put(p,list[i])end
		end
	end
	for _,pool in ipairs(self.flyPool)do if not used[pool]then for _,p in ipairs(pool)do hide(p)end end end
	for _,bird in ipairs(self.birds:step(now,world,reduced,Sim.cap("birds",level)))do
		local pool=bird.slot and self.birdPool[bird.slot]
		if pool then
			used[pool]=true
			local list=Sim.birdParts(bird.root,bird.wings,bird.flick,Sim.birdFlap(flip,held))
			for i,p in ipairs(pool)do put(p,list[i])end
		end
	end
	for _,pool in ipairs(self.birdPool)do if not used[pool]then for _,p in ipairs(pool)do hide(p)end end end
	self:stepFruit(now,camera,level,reduced,put,hide)
	if #parts>0 then self.move(parts,frames)end
	-- After the move, so a bubble or a petal leaves from where its anchor now is.
	for _,emit in ipairs(emits)do emit[1]:Emit(emit[2])end
end

-- Dewdrops -------------------------------------------------------------------------------------------------------
-- Parked or the crowns gone pink: nothing drawn loose, every pool entry free (park/the pool loop moves the anchors
-- away). What falls is the grove's (a pure function of the server time), so nothing about it is forgotten.
function Life:forgetFruit()
	if not self.loose then return end
	self.loose:clear()
	table.clear(self.fruitOf)
	self.fruitCount=0
	for _,entry in ipairs(self.fruitPool)do entry.key,entry.position=nil,nil end
end

-- One step of fruit. The grove (every lime crown, refreshed once a second) says what hangs and what has fallen; only
-- the drawing is this client's: the nearest hanging slots up to the cap, the loose ones Loose draws (cap, reach, no
-- race, bats), nothing loose and every slot full with Reduced Motion. Each drawn fruit keeps its pool entry while it
-- lasts, and only changed properties are written.
local function differs(a,b,eps)return math.abs(a-b)>eps end
function Life:stepFruit(now,camera,level,reduced,put,hide)
	local pool,grove,F=self.fruitPool,self.grove,Sim.Fruit
	if not self.lime or level>=2 then
		-- Nothing assigned: nothing shown, nothing to walk.
		if next(self.fruitOf)==nil and #self.loose.list==0 then return end
		self:forgetFruit()
		for _,entry in ipairs(pool)do hide(entry.anchor)end
		return
	end
	if not grove.at or now<grove.at or now-grove.at>=Sim.Grove.Every then grove:refresh(now)end
	local want={}
	local hanging=0
	local eye,right=camera.Position,camera.RightVector
	if reduced then self.loose:clear()
	else
		local view=self.view
		view.camera,view.right=eye,right
		self.loose:step(now,grove:active(now),view,self.fruitWorld,self.pets,Sim.cap("loose",level),self.live)
	end
	local near={}
	for i,crown in ipairs(grove.crowns)do
		local d=(crown.position-eye).Magnitude
		if d<=F.reach then table.insert(near,{i=i,d=d})end
	end
	table.sort(near,function(x,y)return x.d<y.d end)
	local still=reduced or level>=1
	local room=math.min(Sim.cap("fruit",level),F.pool-#self.loose.list)
	local dot=right:Dot(Wind.Direction)
	for _,entry in ipairs(near)do
		if hanging>=room then break end
		local at=if still then 0 else Wind.at(grove.crowns[entry.i].position,now)
		for _,slot in ipairs(grove.stems[entry.i])do
			if hanging>=room then break end
			local scale=if reduced then 1 else grove:hanging(slot.key,now)
			if scale then
				hanging+=1
				local angle=Sim.fruitSway(slot.k,now,at,still)
				want[slot.key]={Sim.fruitHang(slot.stem,angle,scale),-angle*dot,scale,scale,0}
			end
		end
	end
	for _,loose in ipairs(self.loose.list)do
		local pose=Sim.fruitPose(loose,now)
		want[-loose.key]={pose.position,pose.rotation,pose.w,pose.h,pose.transparency}
	end
	self.fruitCount=hanging
	local of,free=self.fruitOf,{}
	for index,entry in ipairs(pool)do
		if entry.key~=nil and not want[entry.key]then
			of[entry.key]=nil;entry.key,entry.position=nil,nil
		end
		if entry.key==nil then
			hide(entry.anchor)
			table.insert(free,index)
		end
	end
	local size=Life.FruitSize
	for key,v in pairs(want)do
		local index=of[key]
		if not index then
			index=table.remove(free,1)
			if not index then continue end
			of[key]=index;pool[index].key=key
		end
		local entry=pool[index]
		local position,rotation,w,h,transparency=v[1],v[2],v[3],v[4],v[5]
		if entry.position~=position then entry.position=position;put(entry.anchor,CFrame.new(position))end
		if differs(entry.rotation,rotation,.05)then entry.rotation=rotation;entry.label.Rotation=rotation end
		if differs(entry.transparency,transparency,.005)then entry.transparency=transparency;entry.label.ImageTransparency=transparency end
		if differs(entry.w,w,.002)or differs(entry.h,h,.002)then
			entry.w,entry.h=w,h
			entry.gui.Size=UDim2.fromScale(size.X*w,size.Y*h)
		end
	end
end

-- AmbientAudio calls this for each chirp it actually plays. A bird comes in to that perch's crown, or the one
-- already there hops. Ignored while off, parked or with no landing there, and when the chirp's own position is not
-- that landing's tree (AmbientAudio reading other perches than LifeSpots was built from). Returns what LifeSim answered.
Life.SameTree=4
function Life:chirp(perch,position,_cue)
	if not self.enabled or self.parked or type(perch)~="number"then return nil end
	local level=Sim.level(self.level())
	local camera=self.camera()
	local now=self.now()
	if level>=2 or typeof(camera)~="CFrame"or not finite(now)then return nil end
	local landing=self.spots.Landings and self.spots.Landings[perch]
	if typeof(position)=="Vector3"and typeof(landing)=="Vector3"and Sim.flat(position,landing)>Life.SameTree then return nil,"perch"end
	local result,why=self.birds:chirp(now,perch,landing,Sim.cap("birds",level),{camera=camera.Position,stations=self.stations},
		self.reduced()==true,self.day)
	if result=="land"then
		local bird=self.birds:find(perch)
		local taken={}
		for _,other in ipairs(self.birds.list)do if other.slot then taken[other.slot]=true end end
		for slot=1,#self.birdPool do
			if not taken[slot]then
				bird.slot=slot
				local look=Life.BirdColours[bird.colour]or Life.BirdColours[0]
				local pool=self.birdPool[slot]
				pool[1].Color,pool[3].Color=look.body,look.beak
				for _,plate in ipairs({pool[4],pool[5]})do
					for _,d in ipairs(plate:GetChildren())do if d:IsA("Decal")then d.Color3=look.wing end end
				end
				break
			end
		end
	end
	return result,why
end

-- For specs and the perf probe: how much is alive.
function Life:counts()
	if not self.enabled then return{birds=0,butterflies=0,petals=0,bubbles=0,fruit=0,loose=0}end
	local now=self.now()
	return{birds=#self.birds.list,butterflies=#self.flies.list,petals=self.petals:count(now),bubbles=self.bubbles:count(now),
		fruit=if self.parked then 0 else self.fruitCount,loose=#self.loose.list}
end

return Life
