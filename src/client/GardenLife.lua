-- Garden life (ALIVE-LIFE-BUILD-PLAN-2026-11-22, Alive step 5; round 3 for beta 12 QA L1-L3:
-- artifacts/qa-2026-11-23-beta12/GARDEN-LIFE-NEST-LOOK.md and GARDEN-LIFE-NEST-BUILD-PLAN.md): leaves always drifting
-- down round the player, soap bubbles drifting past the camera, a small songbird on the crown where AmbientAudio's chirp
-- came from, butterflies over the flower patches that turn into fireflies at dusk, and Dewdrops hanging under the lime
-- crowns that a strong gust shakes loose (WORLD-PASS item 3, artifacts/world-pass-2026-11-22/FRUIT-LOOK.md). Client only
-- and looks only: no remotes, no saves, nothing to collect. LifeSim decides; this owns the parts.
--
-- mount() is nil with the build ceiling off (Alive.ceiling("life")). With the switch off only the Alive signal is
-- connected and nothing exists. On: one folder EggDropLife in the workspace (birds 3 x 8 parts, butterflies 4 x 3 with
-- a glow billboard each, three leaf anchors and two bubble anchors, each with a ParticleEmitter, 16 Dewdrop anchors
-- each with a BillboardGui), ONE Heartbeat at 30 Hz (15 at budget level 1) and ONE BulkMoveTo a step; a part not in use
-- is moved far away, never re-parented or resized. Textures come from LifeArt (the uploaded ids, or stand-ins until then).
--   Leaves: three emitters (leaf A, leaf B, a pale petal) whose anchors move to a fresh spot round the player for each
--   emit (LifeSim.leafSpot: 72 studs square, 11 over the ground, never where the drift would carry it under a roof);
--   28 / 14 alive at most, their Acceleration (the wind) written at 4 Hz. Shown on the beta once the covered-place list
--   came from the Studio probe (LifeSim.LeafCoverChecked, true since 2026-11-23); always in Studio.
--   Butterflies: wing decals, body and glow written at 10 Hz and only on change; at dusk (daylight under .30) each hands
--   off to a firefly glow (LifeSim), and a park or Reduced Motion turns every glow off at once.
--   Birds: a sitting bird with nothing moving is not written again.
--   Dewdrops: what falls is LifeSim's Grove, a pure function of the server time over every lime crown (the gust
--   number seeds it), so every client has the same fruit go whatever it sees or runs at. Drawing only: lime crowns
--   within 90 studs, nearest first, 16 / 8 shown (level 0 / 1, no sway at 1), at most 3 / 2 loose; a pet within 3 studs
--   bats a resting one in place; never landing on a find spot, the Dash course or a park kerb. Reduced Motion: they
--   just hang, every slot full.
--   Parked (a hatch, the board out of Room mode, my own race): everything hidden, nothing simulated.
--   A menu: bubbles stop starting; the rest goes on behind the shade.
--   Reduced Motion: no leaves, bubbles or flight; a bird is just there on its crown, folded and still; fruit hangs.
--   Budget level 2: nothing at all (torn down, and it never comes back up that session).
--   The garden hour (GARDEN-HOUR-BUILD-PLAN-2026-11-23 slice D): with it on, bubbles and birds start only while its
--   daylight is above .7 (Sim.day); butterflies fly over .30 and spawn over .34. Leaves and Dewdrops never ask. The
--   daylight is GardenHour's, from the server clock, so the gate is the same on every client; with the hour off it is
--   nil and nothing changes. On is HollowClock.hourOn(): the hour and the Aero look painting it, so a client whose
--   AeroWorld did not start keeps today's garden under today's light.
--   The switch off, or a step that throws: everything gone in that frame.
-- deps: ambient (the AmbientAudio instance: onChirp is set while on), dash() -> DashClient?, modalOpen(), reduced(),
--   mode(), plus fixtures for specs: alive {ceiling, on, changed}, world, heartbeat, now, camera() -> CFrame?,
--   root() -> Vector3?, move(parts, frames), hatching, level, spots, patches, stations, pad, course, crowns() -> "lime"|"pink",
--   groundY, warn, seed; pets() -> {Vector3} (the garden pets this client draws, for the fruit bat), finds {Vector3},
--   kerbs {{x, z, rx, rz}}, safe(x, z) -> boolean (walkable ground: IslandBounds.safeCell), daylight(now) -> number?
--   (the garden hour's, nil while it is off; read every Poll), leafGround(x, z) -> y? (nil off the island), cover
--   (the covered places), leaves() -> boolean (the leaves' gate).
local GuiService=game:GetService("GuiService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Sim=require(script.Parent.LifeSim)
local Wind=require(script.Parent.Wind)
local LifeArt=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LifeArt"))

local Life={};Life.__index=Life
Life.Folder="EggDropLife"
Life.Poll=2        -- seconds: crown colour, the race and the garden hour read again
Life.Gate=.25      -- seconds between hatch checks
Life.MaxStep=.1
Life.LookHz=10     -- butterfly wing, body and glow writes a second
Life.Hidden=CFrame.new(0,4096,0)
Life.PetalTexture=LifeArt.Petal
Life.BubbleTexture="rbxassetid://77828632873187"
-- FRUIT-LOOK 1: assets/world/dewdrop.png (scripts/draw_world_textures.py), uploaded 2026-11-23. Billboard studs.
Life.DewdropTexture="rbxassetid://82054526707528"
Life.FruitSize=Vector2.new(1.1,1.28)
local hex=Color3.fromHex
local white=Color3.new(1,1,1)
-- Round 3 (GARDEN-LIFE-NEST-LOOK 1): butterfly slot -> its wing file and mirror, full colour (Color3 white).
Life.ButterflyArt=table.freeze({
	table.freeze({"butterflyAmber","butterflyAmberM"}),table.freeze({"butterflyChalk","butterflyChalkM"}),
	table.freeze({"butterflyDusk","butterflyDuskM"}),table.freeze({"butterflyMeadow","butterflyMeadowM"}),
})
Life.ButterflyBody=hex("#33271C") -- FABLE-REVIEW-R1 1: a spindle (Sphere mesh), not a plank
Life.Glow=table.freeze({colour=hex("#E8FF8A"),brightness=2,maxDistance=110})
-- Round 3 (GARDEN-LIFE-NEST-LOOK 3), picked by perch index % 3; the wing is a full-colour file, the breast and tail
-- are tinted decals.
Life.BirdLooks=table.freeze({
	-- FABLE-REVIEW-R3 3: horn beaks (and legs), at least 35% brighter than the head (dark on dark was invisible).
	[0]=table.freeze({name="Ember",body=hex("#EADBC2"),breast=hex("#D9713A"),head=hex("#7A6248"),tail=hex("#5E4A36"),beak=hex("#E2A548"),wing="birdWingEmber"}),
	[1]=table.freeze({name="Slate",body=hex("#EBDCC4"),breast=hex("#E0A070"),head=hex("#6F8FB3"),tail=hex("#465E7E"),beak=hex("#E8B45A"),wing="birdWingSlate"}),
	[2]=table.freeze({name="Moss",body=hex("#E6D788"),breast=hex("#A6A45E"),head=hex("#6E7A4A"),tail=hex("#4A5230"),beak=hex("#D98A4A"),wing="birdWingMoss"}),
})
Life.EyeInk=hex("#14110F")
Life.ButterflySize=Vector3.new(.04,.035,.18) -- QA-R2-LOOK 4 (was .09, .08, .42 with the 1.2 span)
Life.ButterflyWing=Vector3.new(.24,.29,.02)  -- span .52: 1 : 10 of the avatar, 1 : 3 of a pet
Life.BirdMaterial=Enum.Material.Sand -- matte, fine grain (FABLE-REVIEW-R1 2; Fabric if it reads as gravel)
-- Round 3 (GARDEN-LIFE-NEST-LOOK 2): the three leaf emitters. The petal's tint follows the crowns (lime or pink).
-- QA-R2-LOOK 4, FABLE-REVIEW-R3 4b and R4 2: emitter Size keys. An emitter draws its leaf 1.5 to 1.65 x Size (Studio
-- check R4, beside a .5 cube); the keys hold the drawn long side at .25 studs or less with the envelope (leaf A .135
-- peak, B .125). The petal (.12 peak) is unchanged.
Life.Leaves=table.freeze({
	table.freeze({name="LifeLeafA",texture="leafA",size={.09,.135,.015,.12}}),
	table.freeze({name="LifeLeafB",texture="leafB",size={.08,.125,.015,.11}}),
	table.freeze({name="LifeLeafPetal",texture=nil,size={.075,.12,.02,.105}}),
})
-- FABLE-REVIEW-R4 3: matte, no brighter than #F1E6C8 (pink follows the same rule).
Life.PetalColours=table.freeze({lime=hex("#F1E6C8"),pink=hex("#F0B4CE")})
Life.LeafAnchor=Vector3.new(4,2,4)
-- Bubbles: rise .4 and drift 1.5 to 3 a second downwind.
Life.BubbleHeading=(Wind.Direction*2.25+Vector3.new(0,Sim.BubbleRise,0)).Unit

local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end

-- Parts ---------------------------------------------------------------------------------------------------------
-- A Sphere SpecialMesh on a block: a rounded spindle or beak in the block's own proportions (no extra part).
local function spindle(p)
	local mesh=Instance.new("SpecialMesh")
	mesh.Name="Spindle"
	mesh.MeshType=Enum.MeshType.Sphere
	mesh.Scale=Vector3.new(1,1,1)
	mesh.Parent=p
	return mesh
end
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
	p.Color=colour or Life.ButterflyBody
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

local function keys(list)
	local out={}
	for _,point in ipairs(list)do table.insert(out,NumberSequenceKeypoint.new(point[1],point[2],point[3]or 0))end
	return NumberSequence.new(out)
end
-- One leaf emitter (GARDEN-LIFE-NEST-LOOK 2): Emit only, from a small box GardenLife moves to each leaf's spot.
local function leafEmitter(anchor,index)
	local L,spec=Sim.Leaf,Life.Leaves[index]
	local e=Instance.new("ParticleEmitter")
	e.Name="Leaves"
	e.Texture=if spec.texture then LifeArt.id(spec.texture)else Life.PetalTexture
	e.Color=ColorSequence.new(if spec.texture then white else Life.PetalColours.lime)
	e.Rate=0
	e.Enabled=true
	e.LockedToPart=false
	e.EmissionDirection=Enum.NormalId.Bottom
	e.Shape=Enum.ParticleEmitterShape.Box
	e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
	e.Orientation=Enum.ParticleOrientation.FacingCamera
	local s=spec.size
	e.Size=keys({{0,s[1]},{.1,s[2],s[3]},{1,s[4]}})
	e.Transparency=keys({{0,1},{.08,.1},{.88,.1},{1,1}})
	e.Squash=keys({{0,0},{.25,-.35},{.5,.05},{.75,-.35},{1,0}})
	e.Rotation=NumberRange.new(0,360)
	e.RotSpeed=NumberRange.new(-45,45)
	e.LightEmission,e.LightInfluence,e.Brightness=0,1,1
	e.ZOffset=0
	e.Speed=NumberRange.new(L.speed[1],L.speed[2])
	e.SpreadAngle=Vector2.new(L.spread,L.spread)
	e.Lifetime=NumberRange.new(L.life[index][1],L.life[index][2])
	e.Drag=L.drag
	e.Acceleration=Sim.leafWind(0,0)
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

-- The hand-off glow (GARDEN-LIFE-NEST-LOOK 1): one billboard on each butterfly's body, off by day. No PointLight.
local function glow(body)
	local gui=Instance.new("BillboardGui")
	gui.Name="Glow"
	gui.Size=UDim2.fromScale(Sim.Butterfly.glowFrom,Sim.Butterfly.glowFrom)
	gui.LightInfluence=0
	gui.Brightness=Life.Glow.brightness
	gui.AlwaysOnTop=false
	gui.MaxDistance=Life.Glow.maxDistance
	gui.ClipsDescendants=false
	gui.Active=false
	gui.Enabled=false
	gui.Parent=body
	local label=Instance.new("ImageLabel")
	label.Name="Dot"
	label.Size=UDim2.fromScale(1,1)
	label.BackgroundTransparency=1
	label.BorderSizePixel=0
	label.Image=LifeArt.id("fireflyDot")
	label.ImageColor3=Life.Glow.colour
	label.ImageTransparency=1
	label.ScaleType=Enum.ScaleType.Stretch
	label.Parent=gui
	return gui,label
end

-- Off the island's ground grid (the sky round it): no leaf there.
local function islandGround(Shared,groundY)
	local ok,Data=pcall(function()return require(Shared:WaitForChild("WorldV7Data"))end)
	local G=ok and type(Data)=="table"and Data.ground
	if type(G)~="table"or type(G.h)~="table"then return groundY end
	return function(x,z)
		local i,j=math.floor((x-G.x0)/G.step+.5),math.floor((z-G.z0)/G.step+.5)
		if i<0 or j<0 or i>=G.nx or j>=G.nz then return nil end
		local v=G.h[j*G.nx+i+1]
		if type(v)~="number"or v<=-900 then return nil end
		return groundY(x,z)
	end
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
	-- The leaves wait for the covered-place probe on the beta (LifeSim.LeafCoverChecked); Studio always has them.
	self.leavesGate=deps.leaves or function()return Sim.LeafCoverChecked==true or RunService:IsStudio()end
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
	local groundY=d.groundY or require(Shared:WaitForChild("HollowWorldLayout")).groundY
	self.fruitWorld={stations=self.stations,pad=self.pad,course=self.course,finds=finds,kerbs=kerbs,groundY=groundY,
		safe=d.safe or require(Shared:WaitForChild("IslandBounds")).safeCell}
	-- Fireflies rise from the shared ground; leaves start only over the island, never where they would drift under a roof.
	self.ground=groundY
	self.leafWorld={ground=d.leafGround or(if d.groundY then d.groundY else islandGround(Shared,groundY)),cover=d.cover or Sim.LeafCover}
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
	self.birdPool,self.birdArt,self.flyPool,self.leafPool={},{},{},{}
	-- Birds (round 3; FABLE-REVIEW-R1 2, R3 3): body (the breast decal on its Front) and head in matte Sand, a horn beak,
	-- two bead eyes with no shine, two wing plates, the tail wedge, two legs. Ten parts. Each slot starts with a different wing file, so all three load at once.
	local Face=Enum.NormalId
	for slot=1,Sim.Caps.birds[1]do
		local look=Life.BirdLooks[(slot-1)%3]
		local name="LifeBird"..slot.."_"
		-- QA-R2-LOOK 3: an egg tipped nose-up (a Sphere-meshed block), not a ball.
		local S=Sim.BirdShape
		local bodyPart=part(folder,name.."Body","Part",S.body,look.body)
		spindle(bodyPart)
		bodyPart.Material=Life.BirdMaterial
		local art={wings={},tail={}}
		local breast=LifeArt.id("birdBreast")
		if breast then art.breast=decal(bodyPart,Face.Front,breast,look.breast)end
		local eyes={}
		for _,side in ipairs({"EyeR","EyeL"})do
			local eye=part(folder,name..side,"Part",Vector3.one*S.eye,Life.EyeInk,Enum.PartType.Ball)
			eyes[side]=eye
		end
		local wings={}
		for i,side in ipairs({"WingL","WingR"})do
			local plate=part(folder,name..side,"Part",S.wing,false)
			table.insert(art.wings,decal(plate,Face.Left,LifeArt.id(look.wing),white))
			table.insert(art.wings,decal(plate,Face.Right,LifeArt.id(look.wing),white))
			wings[i]=plate
		end
		-- FABLE-REVIEW-R3 3: a solid wedge (never a hair edge-on), turned over so its Bottom face is on top: the tail file there.
		local tail=part(folder,name.."Tail","WedgePart",S.tail,look.tail)
		tail.Material=Life.BirdMaterial
		local tailFile=LifeArt.id("birdTail")
		art.tail=if tailFile then{decal(tail,Face.Bottom,tailFile,look.tail)}else{}
		art.wing=look.wing
		local head=part(folder,name.."Head","Part",Vector3.one*S.head,look.head,Enum.PartType.Ball)
		head.Material=Life.BirdMaterial
		-- A bright rounded cone: a spindle half buried in the face, round from the front, a short point from the side.
		local beak=part(folder,name.."Beak","Part",S.beak,look.beak)
		spindle(beak)
		local legs={}
		for _,side in ipairs({"LegR","LegL"})do legs[side]=part(folder,name..side,"Part",S.leg,look.beak)end
		self.birdPool[slot]={
			bodyPart,
			head,
			beak,
			eyes.EyeR,eyes.EyeL,
			wings[1],wings[2],
			tail,
			legs.LegR,legs.LegL,
		}
		self.birdArt[slot]=art
	end
	-- Butterflies (round 3): body, two wing plates thin in Z; each wing's two faces carry the slot's file and its mirror,
	-- so from above and below the dark root touches the body and the larger lobe is forward. A glow on the body.
	for slot=1,Sim.Caps.butterflies[1]do
		local art=Life.ButterflyArt[slot]
		local file,mirror=LifeArt.id(art[1]),LifeArt.id(art[2])
		local name="LifeButterfly"..slot.."_"
		local left=part(folder,name.."WingL","Part",Life.ButterflyWing,false)
		local right=part(folder,name.."WingR","Part",Life.ButterflyWing,false)
		local decals={decal(left,Face.Back,mirror,white),decal(left,Face.Front,file,white),
			decal(right,Face.Back,file,white),decal(right,Face.Front,mirror,white)}
		local bodyPart=part(folder,name.."Body","Part",Life.ButterflySize,Life.ButterflyBody)
		spindle(bodyPart)
		local gui,dot=glow(bodyPart)
		self.flyPool[slot]={parts={bodyPart,left,right},decals=decals,glow=gui,dot=dot,
			owner=nil,wing=0,body=0,glowOn=false,glowSize=nil,glowTr=nil}
	end
	for index in ipairs(Life.Leaves)do
		local anchor=part(folder,Life.Leaves[index].name,"Part",Life.LeafAnchor,false)
		self.leafPool[index]={anchor=anchor,emitter=leafEmitter(anchor,index)}
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
	self.leaves=Sim.Leaves.new(self.seed+3)
	self.bubbles=Sim.Bubbles.new(self.seed+2)
	self.grove=Sim.Grove.new(self.spots.Crowns or {},self.fruitWorld)
	self.loose=Sim.Loose.new()
	self.view,self.fruitOf,self.fruitCount={},{},0
	self.birdStill={}
	self.elapsed,self.since,self.steps,self.pollIn,self.gateIn,self.lookIn,self.windIn=0,0,0,0,0,0,0
	self.parked,self.hatch,self.live,self.wasReduced,self.colour,self.lime=false,false,false,false,nil,false
	-- One spot function for every step: round self.leafCentre (the player), never under a roof.
	self.leafPlace=function(_,random)return Sim.leafSpot(random,self.leafCentre,self.leafWorld)end
	local okGate,gate=pcall(self.leavesGate)
	self.leavesOn=okGate and gate==true
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

-- The garden hour's gate, read at enable and every Poll (a failing read is day: the garden as it was). self.dusk is
-- the raw daylight for the butterflies (nil: day).
function Life:readDay(now)
	local ok,daylight=pcall(self.daylight,now)
	daylight=if ok and type(daylight)=="number"and daylight==daylight then daylight else nil
	self.dusk=daylight
	self.day=Sim.day(daylight)
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
	self.folder,self.shown,self.birdPool,self.birdArt,self.flyPool,self.leafPool,self.bubblePool=nil,nil,nil,nil,nil,nil,nil
	self.birds,self.flies,self.leaves,self.bubbles,self.birdStill=nil,nil,nil,nil,nil
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
	for _,slot in ipairs(self.leafPool)do slot.emitter:Clear()end
	for _,slot in pairs(self.bubblePool)do slot.emitter:Clear()end
	self.leaves:clear()
	self.bubbles:clear()
end

-- Every butterfly glow off at once (a park, Reduced Motion, a slot let go).
function Life:glowOff(entry)
	if entry.glowOn then entry.glow.Enabled=false;entry.glowOn=false end
end

-- Everything hidden in one move, every creature forgotten, every particle cleared, every glow off.
function Life:park()
	self.parked=true
	self.birds:clear();self.flies:clear()
	self:clearEmitters()
	for _,entry in ipairs(self.flyPool)do self:glowOff(entry);entry.owner=nil end
	table.clear(self.birdStill)
	self:forgetFruit()
	local parts,frames={},{}
	for p in pairs(self.shown)do table.insert(parts,p);table.insert(frames,Life.Hidden)end
	table.clear(self.shown)
	if #parts>0 then self.move(parts,frames)end
end

-- A butterfly slot's wings, body and glow, written only when they change (force: a new butterfly in the slot).
-- Changed by more than eps, or reaching its end (0 or 1) exactly, so a fade never stops a hair short.
local function changed(a,b,eps)return a==nil or b==nil or math.abs(a-b)>eps or((b==0 or b==1)and a~=b)end
function Life:paintButterfly(entry,look,force)
	if force or changed(entry.wing,look.wing,.01)then
		entry.wing=look.wing
		for _,d in ipairs(entry.decals)do d.Transparency=look.wing end
	end
	if force or changed(entry.body,look.body,.01)then
		entry.body=look.body
		entry.parts[1].Transparency=look.body
	end
	local g=look.glow
	if g then
		if not entry.glowOn then entry.glow.Enabled=true;entry.glowOn=true end
		if force or changed(entry.glowSize,g.size,.01)then entry.glowSize=g.size;entry.glow.Size=UDim2.fromScale(g.size,g.size)end
		if force or changed(entry.glowTr,g.transparency,.01)then entry.glowTr=g.transparency;entry.dot.ImageTransparency=g.transparency end
	else
		self:glowOff(entry)
		entry.glowSize,entry.glowTr=nil,nil
	end
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
	-- Every Poll seconds: the race, the crown colour (the petal leaves' tint) and the garden hour.
	self.pollIn-=tick
	if self.pollIn<=0 then
		self.pollIn=Life.Poll
		local dash=self.d.dash and self.d.dash()
		local ok,summary=pcall(function()return dash and dash:summary()end)
		self.live=ok and type(summary)=="table"and summary.phase=="live"
		self:readDay(now)
		local okColour,colours=pcall(self.crowns)
		self.lime=okColour and colours=="lime"
		local colour=if self.lime then Life.PetalColours.lime else Life.PetalColours.pink
		if colour~=self.colour then
			self.colour=colour
			self.leafPool[3].emitter.Color=ColorSequence.new(colour)
		end
	end
	local player=self.root()
	local world={camera=eye,player=player,stations=self.stations,pad=self.pad,course=if self.live then self.course else nil,
		groundY=self.groundY,ground=self.ground}
	-- Leaves: round the player (the camera without a character), each emit at its own spot; the wind at 4 Hz.
	local centre=if typeof(player)=="Vector3"then player else eye
	if self.leavesOn and not reduced then
		local g=Wind.gust(centre,now)
		self.windIn-=tick
		if self.windIn<=0 then
			self.windIn=1/Sim.Leaf.accelHz
			local accel=Sim.leafWind(g,now)
			for _,entry in ipairs(self.leafPool)do entry.emitter.Acceleration=accel end
		end
		self.leafCentre=centre
		for _,leaf in ipairs(self.leaves:step(now,tick,g,Sim.cap("leaves",level),level,self.leafPlace))do
			local entry=self.leafPool[leaf.kind]
			put(entry.anchor,CFrame.new(leaf.at))
			table.insert(emits,{entry.emitter,1})
		end
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
	-- Butterflies: one continuous wing angle; wings, body and glow painted at 10 Hz (at once for a new one).
	self.lookIn-=tick
	local paint=self.lookIn<=0
	if paint then self.lookIn=1/Life.LookHz end
	local used={}
	for _,b in ipairs(self.flies:step(now,tick,world,self.patches,Sim.cap("butterflies",level),reduced,self.dusk))do
		local entry=self.flyPool[b.colour]
		if entry then
			used[entry]=true
			local list=Sim.butterflyParts(Sim.butterflyRoot(b,now,level),Sim.butterflyFlap(b,now,level))
			for i,p in ipairs(entry.parts)do put(p,list[i])end
			local fresh=entry.owner~=b
			if fresh or paint then
				entry.owner=b
				self:paintButterfly(entry,Sim.butterflyLook(b,now),fresh)
			end
		end
	end
	for _,entry in ipairs(self.flyPool)do
		if not used[entry]then
			for _,p in ipairs(entry.parts)do hide(p)end
			self:glowOff(entry)
			entry.owner=nil
		end
	end
	-- Birds: a sitting bird with nothing moving keeps its last frames (no write).
	local still=self.birdStill
	for _,bird in ipairs(self.birds:step(now,world,reduced,Sim.cap("birds",level),level))do
		local pool=bird.slot and self.birdPool[bird.slot]
		if pool then
			used[pool]=true
			if not(bird.still and still[bird.slot]==bird)then
				local list=Sim.birdParts(bird.root,bird.wings,bird.flick,bird.phi,bird.turn,bird.tau,bird.tuck)
				-- A nil frame (the legs in flight) parks that part: hidden.
				for i,p in ipairs(pool)do if list[i]then put(p,list[i])else hide(p)end end
			end
			still[bird.slot]=if bird.still then bird else nil
		end
	end
	for slot,pool in ipairs(self.birdPool)do
		if not used[pool]then still[slot]=nil;for _,p in ipairs(pool)do hide(p)end end
	end
	self:stepFruit(now,camera,level,reduced,put,hide)
	if #parts>0 then self.move(parts,frames)end
	-- After the move, so a bubble or a leaf leaves from where its anchor now is.
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
				self.birdStill[slot]=nil
				self:paintBird(slot,Life.BirdLooks[bird.colour]or Life.BirdLooks[0])
				break
			end
		end
	end
	return result,why
end
-- A landing bird's colourway: body, head and beak colours, the breast and tail tints, the wing file.
function Life:paintBird(slot,look)
	local pool,art=self.birdPool[slot],self.birdArt[slot]
	pool[1].Color,pool[2].Color,pool[3].Color=look.body,look.head,look.beak
	pool[8].Color=look.tail
	if pool[9]then pool[9].Color,pool[10].Color=look.beak,look.beak end
	if art.breast then art.breast.Color3=look.breast end
	for _,d in ipairs(art.tail)do d.Color3=look.tail end
	if art.wing~=look.wing then
		art.wing=look.wing
		local texture=LifeArt.id(look.wing)
		for _,d in ipairs(art.wings)do d.Texture=texture end
	end
end

-- For specs and the perf probe: how much is alive. `petals` is `leaves` under its old name (one build).
function Life:counts()
	if not self.enabled then return{birds=0,butterflies=0,leaves=0,petals=0,glows=0,bubbles=0,fruit=0,loose=0}end
	local now=self.now()
	local leaves=self.leaves:count(now)
	local glows=0
	for _,entry in ipairs(self.flyPool)do if entry.glowOn then glows+=1 end end
	return{birds=#self.birds.list,butterflies=#self.flies.list,leaves=leaves,petals=leaves,glows=glows,bubbles=self.bubbles:count(now),
		fruit=if self.parked then 0 else self.fruitCount,loose=#self.loose.list}
end

return Life
