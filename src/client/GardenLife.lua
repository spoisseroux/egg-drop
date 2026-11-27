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
local LifeArtR4=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LifeArtR4"))
-- GARDEN-PLAY-BRIEF-2 section 5 (the Alive `fruit` switch): the 3D fruit, the tree shake and the five bites.
local Fruit=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GardenFruit"))

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
-- Beta 14 B5 (WORLD-AND-NEST-LOOK 7): the fruit with a drawn stem (LifeArtR4 dewdropStem: today's fruit until it is
-- uploaded), 1.1 x 1.5 studs, 10% darker so it sits with the ambient.
Life.DewdropTexture=LifeArtR4.id("dewdropStem")
-- (Code review r1: today's stemless fruit keeps 1.1 x 1.28 until dewdropStem is uploaded, unstretched.)
Life.FruitSize=if LifeArtR4.uploaded("dewdropStem")then Vector2.new(1.1,1.5)else Vector2.new(1.1,1.28)
-- FABLE-REVIEW-R5 3: #CFCFC4 (was #E6E6DC); the redrawn image has no outline and a 35% highlight.
Life.FruitColour=Color3.fromHex("#CFCFC4")
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
-- The three leaf emitters (the cap stays 3). Beta 14 QA Q5 (WORLD-AND-NEST-LOOK 6): the leaf sheet (four leaves on one
-- 2 x 2 flipbook, LifeArtR4 leafSheet; each leaf keeps its start cell: FlipbookStartRandom, framerate 0), the petal
-- (tint follows the crowns, lime or pink) and the scud along the ground (the sheet again). QA-R2-LOOK 4, FABLE-REVIEW-R3
-- 4b and R4 2: emitter Size keys. An emitter draws its leaf 1.5 to 1.65 x Size (Studio check R4, beside a .5 cube); the
-- keys hold the drawn long side at .25 studs or less with the envelope (leaf A's .135 peak, kept for the sheet's cells,
-- 96 px as leaf A). The petal (.12 peak) is unchanged. [check] a leaf keeps one cell in flight (else the fallback, two
-- 1 x 2 sheets, leafSheetAC / leafSheetBD, and no scud).
Life.Leaves=table.freeze({
	table.freeze({name="LifeLeafSheet",sheet="leafSheet",size={.09,.135,.015,.12}}),
	table.freeze({name="LifeLeafPetal",texture=nil,size={.075,.12,.02,.105}}),
	table.freeze({name="LifeLeafSkitter",sheet="leafSheet",size={.09,.135,.015,.12},skitter=true}),
})
Life.Petal=2   -- the petal emitter's index (its tint follows the crowns)
Life.Skitter=3 -- the scud's
-- FABLE-REVIEW-R4 3: matte, no brighter than #F1E6C8 (pink follows the same rule).
Life.PetalColours=table.freeze({lime=hex("#F1E6C8"),pink=hex("#F0B4CE")})
Life.LeafAnchor=Vector3.new(4,2,4)
Life.SkitterAnchor=Vector3.new(1,.1,1)
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
	local art=spec.sheet or spec.texture
	e.Texture=if spec.sheet then LifeArtR4.id(spec.sheet)elseif spec.texture then LifeArt.id(spec.texture)else Life.PetalTexture
	e.Color=ColorSequence.new(if art then white else Life.PetalColours.lime)
	-- The sheet's grid only once its own file is uploaded (the stand-in is one leaf on the whole image).
	if spec.sheet and LifeArtR4.uploaded(spec.sheet)then
		e.FlipbookLayout=Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode=Enum.ParticleFlipbookMode.Loop
		e.FlipbookFramerate=NumberRange.new(0)
		e.FlipbookStartRandom=true
	end
	if spec.skitter then
		-- The scud (Q5): along the wind from an anchor turned to face it, flat, no fall, tumbling.
		local S=Sim.Skitter
		e.Rate=0
		e.Enabled=true
		e.LockedToPart=false
		e.EmissionDirection=Enum.NormalId.Front
		e.Shape=Enum.ParticleEmitterShape.Box
		e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
		e.Orientation=Enum.ParticleOrientation.FacingCamera
		local s=spec.size
		e.Size=keys({{0,s[1]},{.1,s[2],s[3]},{1,s[4]}})
		e.Transparency=keys({{0,1},{.1,.1},{.75,.1},{1,1}})
		e.Squash=keys({{0,0},{.2,-.5},{.35,0},{.6,-.5},{.75,0},{1,0}})
		e.Rotation=NumberRange.new(0,360)
		e.RotSpeed=NumberRange.new(-S.rotSpeed,S.rotSpeed)
		e.LightEmission,e.LightInfluence,e.Brightness=0,1,1
		e.ZOffset=0
		e.Speed=NumberRange.new(S.speed[1],S.speed[2])
		e.SpreadAngle=Vector2.new(S.spread,0)
		e.Lifetime=NumberRange.new(S.life[1],S.life[2])
		e.Drag=S.drag
		e.Acceleration=Vector3.zero
		e.Parent=anchor
		return e
	end
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
	e.RotSpeed=NumberRange.new(-L.rotSpeed,L.rotSpeed)
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
	label.ImageColor3=Life.FruitColour
	label.ImageTransparency=0
	label.ScaleType=Enum.ScaleType.Stretch
	label.Rotation=0
	label.Parent=gui
	return{anchor=anchor,gui=gui,label=label,key=nil,position=nil,rotation=0,transparency=0,w=1,h=1}
end

-- The 3D fruit (GARDEN-PLAY-BRIEF-2 section 5, the `fruit` switch): a bright body, a blush sunk in one shoulder, a
-- stem and a leaf, SmoothPlastic with no gloss, in place of the Dewdrop billboard (same slots, same pool of 16). Each
-- part moves with the BulkMoveTo; sizes and transparency are written only when they change.
local FRUIT_SIDE=Vector3.new(-Wind.Direction.Z,0,Wind.Direction.X) -- the hanging sway's axis (WindClient's Side)
local function fruitModel(folder,slot)
	local L=Fruit.Look
	local name="LifeFruit"..slot.."_"
	local body=part(folder,name.."Body","Part",Vector3.one*L.body.size,Color3.fromHex(L.body.colour),Enum.PartType.Ball)
	local blush=part(folder,name.."Blush","Part",Vector3.one*L.blush.size,Color3.fromHex(L.blush.colour),Enum.PartType.Ball)
	local stem=part(folder,name.."Stem","Part",L.stem.size,Color3.fromHex(L.stem.colour),Enum.PartType.Cylinder)
	local leaf=part(folder,name.."Leaf","Part",L.leaf.size,Color3.fromHex(L.leaf.colour))
	-- Beta 38 (GARDEN-B38-BRIEF 3a): a seated fruit's darker leaf disc behind it and the sprig's second leaf (hidden on
	-- the hanging ones).
	local C=Fruit.Canopy
	local shadow=part(folder,name.."Shadow","Part",Vector3.new(C.shadow.thick,C.shadow.across,C.shadow.across),
		Color3.fromHex(C.shadow.colour),Enum.PartType.Cylinder)
	local sprig=part(folder,name.."Sprig","Part",L.leaf.size,Color3.fromHex(L.leaf.colour))
	return{model=true,anchor=body,body=body,blush=blush,stem=stem,leaf=leaf,shadow=shadow,sprig=sprig,
		parts={body,blush,stem,leaf,shadow,sprig},
		key=nil,position=nil,frameKey=nil,w=1,h=1,transparency=0,stemAlpha=0,rotation=0,variety=nil,seatShown=false}
end
-- Beta 38: a canopy fruit's body scale in the tree (1.15 of Look.body.size .9).
local TREE_SCALE=Fruit.Canopy.size/Fruit.Look.body.size
local function hideFruit(entry,hide)
	if entry.model then for _,p in ipairs(entry.parts)do hide(p)end else hide(entry.anchor)end
end

-- The hand-off glow (GARDEN-LIFE-NEST-LOOK 1): one billboard on each butterfly's body, off by day. No PointLight.
-- size: studs (the butterfly's starts small; a night firefly's is Sim.Firefly.size).
local function glow(body,size)
	size=size or Sim.Butterfly.glowFrom
	local gui=Instance.new("BillboardGui")
	gui.Name="Glow"
	gui.Size=UDim2.fromScale(size,size)
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
	-- Beta 14 D2: where the player faces (the nudge's direction).
	self.heading=deps.heading or function()
		local character=Players.LocalPlayer and Players.LocalPlayer.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		return root and root.CFrame.LookVector
	end
	-- Beta 14 D2: my pet's snack asks about each resting fruit (LifePet sets it; nil: no snack).
	self.notice=deps.notice
	-- GARDEN-PLAY-BRIEF-2 section 5: the Alive `fruit` switch (read at each switch-on; a flip builds the garden again),
	-- a crown's rock (WindClient), the shake's buzz, the server's half (FruitClient: shake(i)), and the sounds.
	self.fruitOn=deps.fruit or function()return alive.ceiling("fruit")==true and alive.on("fruit")==true end
	self.rock=deps.rock or function(p)require(script.Parent.WindClient).shake(p)end
	self.buzz=deps.buzz or function(name)pcall(function()require(script.Parent.Haptics).play(name)end)end
	self.shook=deps.shook
	self.play=deps.play
	-- Beta 38 review 5 (the Shake prompt beside the pet's Say hi): promptBlocked() true while a menu, the deck, focus or
	-- the dash is up; sayHiNear() true while the pet's Say hi prompt is on and in its reach; inputKind() "Keyboard",
	-- "Gamepad" or "Touch". All optional and nil-safe (a throw counts as not blocked / not near).
	self.promptBlocked=deps.promptBlocked
	self.sayHiNear=deps.sayHiNear
	self.inputKind=deps.inputKind
	-- The Hush (Fable's garden expansion through the cave): quiet() true while the player is in it, so no leaves,
	-- bubbles, birds or fireflies follow them in (the ones out finish or fade). Optional, nil-safe; a throw is not quiet.
	self.quiet=deps.quiet
	self.pets=deps.pets or function()return{}end
	-- Beta 17 1.3 C: every player's character (a foraging bird keeps 10 studs off each and flushes at 7).
	self.players=deps.players or function()
		local out={}
		for _,player in ipairs(Players:GetPlayers())do
			local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then table.insert(out,root.Position)end
		end
		return out
	end
	-- One chirp when a foraging bird flushes (AmbientAudio's pool, at the bird). Specs pass their own.
	self.flushChirp=deps.flushChirp or function(position)
		local Ambient=require(script.Parent.AmbientAudio).shared
		if Ambient and not Ambient.destroyed then
			Ambient:chirp({cue="bird_chirp_"..math.random(1,6),position=position,pitch=1.08,volume=.45})
		end
	end
	-- The live kit crown parts (for the hanging fruit's sway only).
	self.kitParts=deps.kitParts or function()
		local room=workspace:FindFirstChild("EggDropLounge")
		local kit=room and room:FindFirstChild("AeroKit")
		local out={}
		for _,p in ipairs(kit and kit:GetChildren()or {})do
			if p:IsA("BasePart")and p:GetAttribute("WorldDressing")=="crown"then table.insert(out,p)end
		end
		return out
	end
	self.daylight=deps.daylight or function(now)
		if not require(script.Parent.HollowClock).hourOn()then return nil end
		local Hour=require(Shared:WaitForChild("GardenHour"))
		return Hour.phase(now+Hour.offset()).daylight
	end
	-- The leaves wait for the covered-place probe on the beta (LifeSim.LeafCoverChecked); Studio always has them.
	self.leavesGate=deps.leaves or function()return Sim.LeafCoverChecked==true or RunService:IsStudio()end
	-- Beta 14 B2 diagnostics: the budget level on the local player, one write per change (a phone at level 2 shows no
	-- garden life at all).
	self.report=deps.report or function(level)
		local player=Players.LocalPlayer
		if player then player:SetAttribute("AliveLevel",level)end
	end
	table.insert(self.connections,alive.changed("life"):Connect(function()self:sync()end))
	-- The fruit switch decides which fruit the pool holds: a flip builds the garden again (switch-on reads it).
	pcall(function()
		if alive.ceiling("fruit")~=true then return end
		table.insert(self.connections,alive.changed("fruit"):Connect(function()
			if self.enabled and self.fruit3d~=(self.fruitOn()==true)then self:disable();self:sync()end
		end))
	end)
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

-- The grove's crowns (beta 14 B5; architect r1): the Aero kit's lime-able crowns from its data module
-- (WorldAeroKit through AeroKit.crownFrame, Sim.kitCrowns), validated in a pcall; anything wrong (or none) is
-- LifeSpots.Crowns with one warning. A fixture's `groveCrowns`, or `spots` with crowns, is used as given.
Life.KitKinds=table.freeze({foliage_blossom=true})
function Life:readCrowns()
	local d=self.d
	if d.groveCrowns then return d.groveCrowns end
	if d.spots then return d.spots.Crowns or {}end
	local Shared=ReplicatedStorage:WaitForChild("Shared")
	local ok,crowns=pcall(function()
		-- Beta 38: the trees as graded while the tree grades are on (TreeGrades.kit), as the kit's parts stand.
		local data=require(Shared:WaitForChild("TreeGrades")).kit(require(Shared:WaitForChild("WorldAeroKit")),self.graded==true)
		local Kit=require(script.Parent.AeroKit)
		return Sim.kitCrowns(data,Kit.crownFrame,Life.KitKinds)
	end)
	if ok and type(crowns)=="table"and #crowns>0 then return crowns end
	if not Life.crownWarned then
		Life.crownWarned=true
		self.warn("[Life] Dewdrops on the old crown list: "..(if ok then "the kit has no lime crowns"else tostring(crowns)))
	end
	return self.spots.Crowns or {}
end
-- Beta 38: are the tree grades on (TreeGrades.on)? A fixture's crowns are never graded.
function Life:gradedNow()
	if self.d.groveCrowns or self.d.spots then return false end
	local ok,on=pcall(function()return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TreeGrades")).on()end)
	return ok and on==true
end
-- Hanging fruit follows its crown's sway (beta 14 B5): each grove crown with a pivot is matched (within .05) to a live
-- kit part (WorldDressing "crown" with WorldPivot and WorldRestCFrame); no match is a static stem. Drawing only: what
-- falls never reads a part. Re-read every Poll (the kit is rebuilt on an Aero switch).
Life.FollowMatch=.05
function Life:followCrowns()
	self.follow={}
	local ok,parts=pcall(self.kitParts)
	if not ok or type(parts)~="table"then return end
	for i,crown in ipairs(self.groveCrowns or {})do
		if typeof(crown.pivot)=="Vector3"then
			for _,p in ipairs(parts)do
				local pivot,rest=p:GetAttribute("WorldPivot"),p:GetAttribute("WorldRestCFrame")
				if typeof(pivot)=="Vector3"and typeof(rest)=="CFrame"and(pivot-crown.pivot).Magnitude<=Life.FollowMatch then
					self.follow[i]={part=p,inverse=rest:Inverse()}
					break
				end
			end
		end
	end
end

-- The world's places, read once a switch-on (data, never instances: crowns are merged meshes, revision 1).
function Life:places()
	local d=self.d
	local Shared=ReplicatedStorage:WaitForChild("Shared")
	self.spots=d.spots or require(script.Parent.LifeSpots)
	self.graded=self:gradedNow()
	self.groveCrowns=self:readCrowns()
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
	-- Beta 17 1.3 C: where a bird may forage (the Dewdrops' lawn rules, the course always) and the crowns it flies up to.
	local fruit=self.fruitWorld
	self.forageWorld={stations=fruit.stations,pad=fruit.pad,course=fruit.course,finds=fruit.finds,kerbs=fruit.kerbs,
		groundY=fruit.groundY,safe=fruit.safe,ok=fruit.safe,landings=self.spots.Landings,players=self.players,pets=self.pets}
	-- Fireflies rise from the shared ground; leaves start only over the island, never where they would drift under a roof.
	self.ground=groundY
	self.leafWorld={ground=d.leafGround or(if d.groundY then d.groundY else islandGround(Shared,groundY)),cover=d.cover or Sim.LeafCover}
	self.crowns=d.crowns or function()
		local Aero=require(Shared:WaitForChild("Aero"))
		return if Aero.on()and Aero.trees()=="lime"then "lime"else "pink"
	end
	-- Beta 14 B2: the night fireflies hover over the flower patches and the water's banks (WorldV7Data.wet).
	self.fireflySpots={patches=self.patches,banks=d.banks or Life.banks(Shared)}
	-- WORLD-FINISH-LOOK slice F: fireflies may use the terrace at night at budget level 0 only (HillNight's spots), while
	-- the `scene` switch is on, the island's sculpt is in and the tier is open. d.hill (specs): fn() -> bool; d.terrace:
	-- the spots. Live: the `scene` ceiling is closed, so `terrace` is never set and the pool is today's.
	-- The ceiling is read once here (code review: live never pays a per-step check); the switches at most once a second.
	if d.hill then self.hillOn=d.hill
	else
		local Alive=require(Shared:WaitForChild("Alive"))
		if Alive.ceiling("scene")then
			local Tier=require(Shared:WaitForChild("Tier"))
			local at,answer=-math.huge,false
			self.hillOn=function()
				local now=os.clock()
				if now-at>=1 then
					at=now
					answer=Alive.on("scene")==true and workspace:GetAttribute("CliffDen")==true and Tier.on()==true
				end
				return answer
			end
		end
	end
	self.terraceFireflies=d.terrace
	-- Beta 14 W3 (LifeScene): the ground under every kit crown (dapple), the water boxes (dragonflies), the garden hour's
	-- clock and daylight (lamps, the star), the scene's textures.
	self.sceneData=d.scene or Life.sceneData(Shared,groundY)
end

-- The scene's data from the shared modules (beta 14 W3); a missing piece is empty, never an error.
Life.Ripple="rbxassetid://123065684226119" -- the uploaded pool ring (WorldAero.Look.Textures.Ripple, AeroFalls)
function Life.sceneData(Shared,groundY)
	local data={crowns={},boxes={}}
	pcall(function()
		local kit=Sim.kitCrowns(require(Shared:WaitForChild("WorldAeroKit")),require(script.Parent.AeroKit).crownFrame)
		for _,crown in ipairs(kit)do
			local p=crown.position
			local g=groundY(p.X,p.Z)
			if type(g)=="number"and g==g and math.abs(g)<math.huge then table.insert(data.crowns,Vector3.new(p.X,g,p.Z))end
		end
	end)
	pcall(function()
		for _,box in ipairs(require(Shared:WaitForChild("WorldV7Data")).wet or {})do
			local c,s=box.center,box.size
			table.insert(data.boxes,{frame=CFrame.new(c[1],c[2],c[3])*CFrame.Angles(0,tonumber(box.yaw)or 0,0),hx=s[1]/2,hz=s[3]/2,y=c[2],
				name=box.name})
		end
	end)
	data.hourClock=function(now)
		if not require(script.Parent.HollowClock).hourOn()then return nil end
		return now+require(Shared:WaitForChild("GardenHour")).offset()
	end
	data.hourDaylight=function(s)return require(Shared:WaitForChild("GardenHour")).phase(s).daylight end
	-- Beta 17 (1.3 B): the river stones and bridge piers the flow rings sit round and the leaves skirt; the rings round
	-- the stones show while the Dash gate is the fete set (its stones are built).
	data.obstacles={}
	pcall(function()data.obstacles=require(Shared:WaitForChild("RiverStones")).obstacles()end)
	data.stones=function()
		local gate=workspace:FindFirstChild("GardenDash")
		return gate~=nil and gate:GetAttribute("Fete")==true
	end
	data.art=function(key)
		if key=="ripple"then return Life.Ripple end
		if key=="leaf"then return LifeArt.id("leafA")end
		if key=="halo"then return LifeArt.id("fireflyDot")end
		return LifeArtR4.id(key)
	end
	return data
end

-- Points just inside the water's banks, every Sim.Firefly bank step along each wet box's edge (data only). A missing or
-- malformed table is no banks.
Life.BankStep,Life.BankInset=4,1.5
function Life.banks(Shared)
	local out={}
	local ok,Data=pcall(function()return require(Shared:WaitForChild("WorldV7Data"))end)
	local wet=ok and type(Data)=="table"and Data.wet
	if type(wet)~="table"then return out end
	for _,box in ipairs(wet)do
		local c,s=box.center,box.size
		if type(c)=="table"and type(s)=="table"and #c==3 and #s==3 then
			local frame=CFrame.new(c[1],c[2],c[3])*CFrame.Angles(0,tonumber(box.yaw)or 0,0)
			local hx,hz=s[1]/2-Life.BankInset,s[3]/2-Life.BankInset
			if hx>0 and hz>0 then
				for _,edge in ipairs({{-hx,-hz,hx,-hz},{hx,-hz,hx,hz},{hx,hz,-hx,hz},{-hx,hz,-hx,-hz}})do
					local ax,az,bx,bz=edge[1],edge[2],edge[3],edge[4]
					local n=math.max(1,math.floor(math.sqrt((bx-ax)^2+(bz-az)^2)/Life.BankStep))
					for i=0,n-1 do
						local u=i/n
						table.insert(out,frame*Vector3.new(ax+(bx-ax)*u,0,az+(bz-az)*u))
					end
				end
			end
		end
	end
	return out
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
		local anchor=part(folder,Life.Leaves[index].name,"Part",if Life.Leaves[index].skitter then Life.SkitterAnchor else Life.LeafAnchor,false)
		self.leafPool[index]={anchor=anchor,emitter=leafEmitter(anchor,index)}
	end
	-- Beta 14 B2: the night fireflies, one invisible anchor and one glow billboard each (no PointLight).
	self.firePool={}
	for slot=1,Sim.Caps.fireflies[1]do
		local anchor=part(folder,"LifeFirefly"..slot,"Part",Vector3.new(.2,.2,.2),false)
		local gui,dot=glow(anchor,Sim.Firefly.size)
		self.firePool[slot]={anchor=anchor,glow=gui,dot=dot,glowOn=false,glowTr=nil}
	end
	self.fireflies=Sim.Fireflies.new(self.seed+4)
	self.fireIn=0
	self.fruitPool={}
	local okFruit,fruitOn=pcall(self.fruitOn)
	self.fruit3d=okFruit and fruitOn==true
	for slot=1,Sim.Fruit.pool do self.fruitPool[slot]=if self.fruit3d then fruitModel(folder,slot)else dewdrop(folder,slot)end
	self.shaken,self.shakeDrops,self.shakeReady,self.shakeLanded,self.shakeCount,self.shakeRoot={},{},{},{},0,nil
	if self.fruit3d then
		-- The shake's leaf cards (the leaf sheet's own emitter, so the drifting leaves keep theirs) and the bites' crumbs.
		local anchor=part(folder,"LifeShakeLeaves","Part",Life.LeafAnchor,false)
		self.shakeLeaves={anchor=anchor,emitter=leafEmitter(anchor,1)}
		local crumbAnchor=part(folder,"LifeFruitCrumbs","Part",Vector3.new(.2,.2,.2),false)
		self.crumbs={anchor=crumbAnchor,emitter=Life.crumbEmitter(crumbAnchor)}
		self:fruitVoices(folder)
		-- The fruit trees in the grove's order (both sort the lime crowns by tree name); a fallback crown list has none.
		self.fruitTrees={}
		local okTrees,trees=pcall(Fruit.trees,nil,self.graded==true)
		for i,crown in ipairs(self.groveCrowns or {})do
			local tree=okTrees and trees[i]
			if tree and tree.tree==crown.tree then self.fruitTrees[i]=tree end
		end
		-- Beta 38 (GARDEN-B38-BRIEF 3b): a "Shake" prompt at each fruit tree's trunk (E, gamepad X, or tap / click the
		-- pill), shown only while a shake is allowed for me (stepShake).
		self.shakePrompts={}
		for i,tree in pairs(self.fruitTrees)do
			local ok,prompt=pcall(self.shakePrompt,self,folder,i,tree)
			if ok then self.shakePrompts[i]=prompt else self.warn("[Life] shake prompt: "..tostring(prompt))end
		end
	end
	-- Beta 38: the canopy's slots with the 3D fruit (Sim.fruitCanopy); today's under the skirt without.
	self.fruitWorld.canopy=self.fruit3d
	self.bubblePool={}
	for _,kind in ipairs({"small","large"})do
		local anchor=part(folder,if kind=="small"then "LifeBubblesSmall"else "LifeBubblesLarge","Part",Vector3.new(.2,.2,.2),false)
		self.bubblePool[kind]={anchor=anchor,emitter=bubbleEmitter(anchor,kind)}
	end
	self.birds=Sim.Birds.new(self.seed)
	self.flies=Sim.Butterflies.new(self.seed+1)
	self.leaves=Sim.Leaves.new(self.seed+3)
	self.skitter=Sim.Skitters.new(self.seed+5)
	self.bubbles=Sim.Bubbles.new(self.seed+2)
	self.grove=Sim.Grove.new(self.groveCrowns,self.fruitWorld)
	self:followCrowns()
	self.loose=Sim.Loose.new()
	self.view,self.fruitOf,self.fruitCount={},{},0
	self.birdStill={}
	self.elapsed,self.since,self.steps,self.pollIn,self.gateIn,self.lookIn,self.windIn=0,0,0,0,0,0,0
	self.parked,self.hatch,self.live,self.wasReduced,self.colour,self.lime=false,false,false,false,nil,false
	-- One spot function for every step: round self.leafCentre (the player), never under a roof.
	self.leafPlace=function(_,random)return Sim.leafSpot(random,self.leafCentre,self.leafWorld)end
	-- The scud's: the same square, on the ground, never on the course while a race is live (self.skitterWorld.course).
	self.skitterWorld={ground=self.leafWorld.ground,cover=self.leafWorld.cover,course=nil}
	self.skitterPlace=function(random)return Sim.skitterSpot(random,self.leafCentre,self.skitterWorld)end
	local okGate,gate=pcall(self.leavesGate)
	self.leavesOn=okGate and gate==true
	self:readDay(self.now())
	self:readScene()
	self:syncScene()
	-- Beta 14 W3: the `scene` switch (the big breath and the scene's additions) is read every Poll; a flip polls at once.
	-- Connected only while on, so with `life` off nothing but its own signal is connected.
	self.sceneLink=self.alive.changed("scene"):Connect(function()self.pollIn=0 end)
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

-- The Alive `scene` switch (beta 14 W3): read at enable and every Poll; a failing read is off.
function Life:readScene()
	local ok,on=pcall(function()return self.alive.on("scene")end)
	self.scene=ok and on==true
	return self.scene
end
-- LifeScene's parts exist only while `scene` is on. A scene that fails to build or step is dropped with a warning;
-- the rest of garden life carries on.
function Life:syncScene()
	if self.scene and not self.sceneParts and not self.sceneFailed then
		local data=self.sceneData
		local ok,scene=pcall(function()
			return require(script.Parent.LifeScene).new({kit={folder=self.folder,part=part,decal=decal,spindle=spindle},
				art=data.art,crowns=data.crowns,boxes=data.boxes,hourClock=data.hourClock,hourDaylight=data.hourDaylight,seed=self.seed+11,
				obstacles=data.obstacles,stones=data.stones})
		end)
		if ok then self.sceneParts=scene else self:dropScene(scene)end
	elseif not self.scene and self.sceneParts then
		self:dropScene(nil)
	end
end
function Life:dropScene(problem)
	local scene=self.sceneParts
	self.sceneParts=nil
	if scene then
		local ok,parts=pcall(scene.destroy,scene)
		if ok then for _,p in ipairs(parts)do self.shown[p]=nil end end
	end
	if problem~=nil then
		self.sceneFailed=true
		self.warn("[Life] scene stopped: "..tostring(problem))
	end
end

-- Off: nothing left but the Alive signal. Cannot throw past the folder's Destroy.
function Life:disable()
	if not self.enabled then return end
	self.enabled=false
	if self.beat then self.beat:Disconnect();self.beat=nil end
	if self.sceneLink then self.sceneLink:Disconnect();self.sceneLink=nil end
	local ambient=self.d.ambient
	if ambient and self.hook and ambient.onChirp==self.hook then ambient.onChirp=nil end
	self.hook=nil
	local folder=self.folder
	self.folder,self.shown,self.birdPool,self.birdArt,self.flyPool,self.leafPool,self.bubblePool=nil,nil,nil,nil,nil,nil,nil
	self.birds,self.flies,self.leaves,self.bubbles,self.birdStill,self.skitter=nil,nil,nil,nil,nil,nil
	self.fruitPool,self.grove,self.loose,self.view,self.fruitOf,self.fruitCount=nil,nil,nil,nil,nil,0
	self.firePool,self.fireflies,self.sceneParts,self.sceneFailed=nil,nil,nil,nil
	self.shaken,self.shakeDrops,self.shakeReady,self.shakeLanded,self.shakeLeaves,self.crumbs,self.voices,self.fruitTrees=nil,nil,nil,nil,nil,nil,nil,nil
	self.shakePrompts,self.shakeAsk=nil,nil
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
	self.skitter:clear()
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
	self.fireflies:clear()
	for _,entry in ipairs(self.firePool)do self:glowOff(entry)end
	if self.sceneParts then pcall(self.sceneParts.park,self.sceneParts)end
	table.clear(self.birdStill)
	self:forgetFruit()
	self:promptStep(nil,false)
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
	if level~=self.reported then
		self.reported=level
		pcall(self.report,level)
	end
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
	local quiet=false
	if self.quiet then
		local okQuiet,value=pcall(self.quiet)
		quiet=okQuiet and value==true
	end
	self.hushed=quiet
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
		self:readScene()
		self:syncScene()
		-- Beta 38: the tree grades flipped (`scene`, or the trunk pack): the garden again on the new trees, next frame.
		if self:gradedNow()~=(self.graded==true)and not self.regrading then
			self.regrading=true
			;(self.d.defer or task.defer)(function()
				self.regrading=false
				if self.enabled and not self.destroyed then self:disable();self:sync()end
			end)
		end
		-- The big breath's drops follow the `scene` switch (the same on every client): a new grove when it flips.
		if(self.fruitWorld.breath==true)~=self.scene then
			self.fruitWorld.breath=self.scene
			self:forgetFruit()
			self.grove=Sim.Grove.new(self.groveCrowns,self.fruitWorld)
		end
		local okColour,colours=pcall(self.crowns)
		self.lime=okColour and colours=="lime"
		local colour=if self.lime then Life.PetalColours.lime else Life.PetalColours.pink
		if colour~=self.colour then
			self.colour=colour
			self.leafPool[Life.Petal].emitter.Color=ColorSequence.new(colour)
		end
		self:followCrowns()
	end
	local player=self.root()
	local world={camera=eye,player=player,stations=self.stations,pad=self.pad,course=if self.live then self.course else nil,
		groundY=self.groundY,ground=self.ground,safe=self.fruitWorld.safe,
		-- Beta 17 1.3 C: birds forage only with `scene` on, by day, out of the Hush (level 2 has no garden life at all).
		forage=if self.scene and self.day~=false and not quiet then self.forageWorld else nil}
	-- Leaves: round the player (the camera without a character), each emit at its own spot; the wind at 4 Hz (the
	-- falling ones only: the scud has none). The fall's wind is the gust alone (never the breath: architect r1); the
	-- big breath (`scene` on) triples the rate and runs the scud.
	local centre=if typeof(player)=="Vector3"then player else eye
	if self.leavesOn and not reduced and not quiet then
		local g=Wind.gust(centre,now)
		local breath=if self.scene then(Wind.breath(centre,now))else 0
		self.windIn-=tick
		if self.windIn<=0 then
			self.windIn=1/Sim.Leaf.accelHz
			local accel=Sim.leafWind(g,now)
			for index,entry in ipairs(self.leafPool)do
				if index~=Life.Skitter then entry.emitter.Acceleration=accel end
			end
		end
		self.leafCentre=centre
		for _,leaf in ipairs(self.leaves:step(now,tick,g,Sim.cap("leaves",level),level,self.leafPlace,breath>0))do
			local entry=self.leafPool[leaf.kind]
			put(entry.anchor,CFrame.new(leaf.at))
			table.insert(emits,{entry.emitter,1})
		end
		self.skitterWorld.course=if self.live then self.course else nil
		local scud=self.leafPool[Life.Skitter]
		for _,at in ipairs(self.skitter:step(now,tick,math.max(g,breath),Sim.cap("skitter",level),level,self.skitterPlace))do
			put(scud.anchor,CFrame.lookAt(at,at+Wind.Direction))
			table.insert(emits,{scud.emitter,1})
		end
	end
	-- Bubbles: one every 3 s ahead of the camera, never in a menu, with Reduced Motion or at night, never in the way.
	-- The roll picks the small or the large emitter; only that one's anchor moves to the spot.
	local menu=self.d.modalOpen and self.d.modalOpen()==true
	if self.bubbles:due(now,Sim.cap("bubbles",level),not reduced and not menu and not quiet and self.day)then
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
	self:stepFireflies(now,tick,world,level,reduced,put,hide)
	-- Birds: a sitting bird with nothing moving keeps its last frames (no write). In the big breath (`scene` on) each
	-- sitting bird hops a pair once.
	if self.scene then self.birds:breathe(now,function(at)return Wind.breath(at,now)end,reduced)end
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
	for _,event in ipairs(self.birds:drain())do
		if event.kind=="flush"then
			local ok,problem=pcall(self.flushChirp,event.position)
			if not ok then self.warn("[Life] flush chirp: "..tostring(problem));self.flushChirp=function()end end
		end
	end
	self.fruitEmits=emits
	self:stepFruit(now,camera,level,reduced,put,hide)
	local scene=self.sceneParts
	if scene then
		local ok,problem=pcall(scene.step,scene,{now=now,tick=tick,level=level,reduced=reduced,eye=eye,camera=camera,player=player,
			daylight=self.dusk,blow=Wind.blow,put=put,hide=hide})
		if not ok then
			self:dropScene(problem)
			-- This step's move never touches a destroyed part.
			for i=#parts,1,-1 do
				if parts[i].Parent==nil then table.remove(parts,i);table.remove(frames,i)end
			end
		end
	end
	if #parts>0 then self.move(parts,frames)end
	-- After the move, so a bubble or a leaf leaves from where its anchor now is.
	for _,emit in ipairs(emits)do emit[1]:Emit(emit[2])end
end

-- Night fireflies (beta 14 QA B2) ---------------------------------------------------------------------------------
-- Butterflies whose hand-off finished are adopted first; the population follows the garden hour's daylight (self.dusk,
-- read every Poll). Positions written at Sim.Firefly.hz, the glow's transparency only on change.
function Life:stepFireflies(now,tick,world,level,reduced,put,hide)
	local cap=Sim.cap("fireflies",level)
	-- Slice F: the terrace's hover points join the pool at level 0 with the hill's gate open (nil otherwise: today's).
	local terrace=nil
	if level==0 and self.hillOn and self.hillOn()==true then
		if not self.terraceFireflies then self.terraceFireflies=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HillNight")).terraceSpots()end
		terrace=self.terraceFireflies
	end
	self.fireflySpots.terrace=terrace
	for _,at in ipairs(self.flies.handed)do self.fireflies:adopt(now,at,cap)end
	table.clear(self.flies.handed)
	self.fireIn-=tick
	local write=self.fireIn<=0
	if write then self.fireIn=1/Sim.Firefly.hz end
	local used={}
	-- In the Hush the wanted count is none: the ones out fade, none follow.
	for _,f in ipairs(self.fireflies:step(now,tick,world,self.fireflySpots,cap,reduced,if self.hushed then nil else self.dusk))do
		local entry=self.firePool[f.slot]
		if entry then
			used[entry]=true
			local fresh=entry.owner~=f
			entry.owner=f
			if write or fresh then put(entry.anchor,CFrame.new(f.position))end
			local transparency=Sim.fireflyLook(f,now)
			if not entry.glowOn then entry.glow.Enabled=true;entry.glowOn=true end
			if fresh or entry.glowTr==nil or math.abs(entry.glowTr-transparency)>.01 or(transparency>=1 and entry.glowTr<1)then
				entry.glowTr=transparency;entry.dot.ImageTransparency=transparency
			end
		end
	end
	for _,entry in ipairs(self.firePool)do
		if not used[entry]then
			hide(entry.anchor)
			self:glowOff(entry)
			entry.owner,entry.glowTr=nil,nil
		end
	end
end

-- Dewdrops -------------------------------------------------------------------------------------------------------
-- Parked or the crowns gone pink: nothing drawn loose, every pool entry free (park/the pool loop moves the anchors
-- away). What falls is the grove's (a pure function of the server time), so nothing about it is forgotten.
function Life:forgetFruit()
	if not self.loose then return end
	self.loose:clear()
	table.clear(self.fruitOf)
	self.fruitCount=0
	for _,entry in ipairs(self.fruitPool)do entry.key,entry.position,entry.frameKey=nil,nil,nil end
end

-- One step of fruit. The grove (every lime crown, refreshed once a second) says what hangs and what has fallen; only
-- the drawing is this client's: the nearest hanging slots up to the cap, the loose ones Loose draws (cap, reach, no
-- race, bats), nothing loose and every slot full with Reduced Motion. Each drawn fruit keeps its pool entry while it
-- lasts, and only changed properties are written.
local function differs(a,b,eps)return math.abs(a-b)>eps end
function Life:stepFruit(now,camera,level,reduced,put,hide)
	local pool,grove,F=self.fruitPool,self.grove,Sim.Fruit
	if not self.lime or level>=2 then
		self:promptStep(now,false)
		-- Nothing assigned: nothing shown, nothing to walk.
		if next(self.fruitOf)==nil and #self.loose.list==0 then return end
		self:forgetFruit()
		for _,entry in ipairs(pool)do hideFruit(entry,hide)end
		return
	end
	if not grove.at or now<grove.at or now-grove.at>=Sim.Grove.Every then grove:refresh(now)end
	local want={}
	local hanging=0
	local eye,right=camera.Position,camera.RightVector
	-- The tree shake (the `fruit` switch); with Reduced Motion only its sounds.
	if self.fruit3d then self:stepShake(now,reduced,put)end
	if reduced then self.loose:clear()
	else
		local view=self.view
		view.camera,view.right=eye,right
		view.player=self.root()
		local okHeading,heading=pcall(self.heading)
		view.heading=if okHeading and typeof(heading)=="Vector3"then heading else nil
		self.loose:step(now,self:activeFruit(now),view,self.fruitWorld,self.pets,Sim.cap("loose",level),self.live,self.notice)
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
		local crownAt=grove.crowns[entry.i].position
		-- Beta 14 W3: with `scene` on the fruit sways with the big breath too (Wind.swayAt); what falls never reads it.
		local at=if still then 0 elseif self.scene then Wind.swayAt(crownAt,now)else Wind.at(crownAt,now)
		-- Beta 14 B5: at level 0, hanging from the crown's live pose (its sway), when the crown's part was found.
		local follow=not still and self.follow and self.follow[entry.i]
		local delta=follow and follow.part.Parent and follow.part.CFrame*follow.inverse
		local variety=self:fruitVariety(entry.i)
		for _,slot in ipairs(grove.stems[entry.i])do
			if hanging>=room then break end
			local scale=if reduced then 1 else grove:hanging(slot.key,now)
			if scale and self.fruit3d then
				local grown=self:shakenScale(slot.key,now)
				if grown then scale=if grown<=0 then nil else math.min(scale,grown)end
			end
			if scale then
				hanging+=1
				local angle=Sim.fruitSwayOf(slot,now,at,still)
				local stem=if delta then delta*slot.stem else slot.stem
				-- Beta 38: a canopy slot draws the 1.15 body, the tree's variety (a pear stands taller), seated or hanging.
				local w=if slot.hang then scale*TREE_SCALE else scale
				local h=if slot.hang then w*variety.tall else scale
				want[slot.key]={Sim.fruitHang(stem,angle,scale,slot.hang),-angle*dot,w,h,0,angle,FRUIT_SIDE,0,nil,
					if slot.seated then slot else nil,variety}
			end
		end
	end
	for _,loose in ipairs(self.loose.list)do
		local pose=Sim.fruitPose(loose,now)
		local heading=loose.heading
		local axis=if typeof(heading)=="Vector3"and heading.Magnitude>1e-3 then Vector3.new(heading.Z,0,-heading.X).Unit else FRUIT_SIDE
		-- Beta 38: a canopy fruit drops at its tree size and settles to the ground size over its first bounce.
		local grow=if self.fruit3d and loose.hang then Fruit.sizeAt(now,loose.t2,loose.t3)else 1
		local variety=self:fruitVariety(loose.i)
		want[-loose.key]={pose.position,pose.rotation,pose.w*grow,pose.h*grow*(if loose.hang then variety.tall else 1),
			pose.transparency,pose.rotation,axis,pose.turn,pose.eatT,nil,variety}
		-- Three crumbs a bite in the body's colour (the `fruit` switch's five bites).
		if self.crumbs and pose.bite>(loose.crumbed or 0)and typeof(pose.position)=="Vector3"then
			loose.crumbed=pose.bite
			put(self.crumbs.anchor,CFrame.new(pose.position))
			table.insert(self.fruitEmits,{self.crumbs.emitter,Fruit.Bites.crumbs})
		end
	end
	self.fruitCount=hanging
	local of,free=self.fruitOf,{}
	for index,entry in ipairs(pool)do
		if entry.key~=nil and not want[entry.key]then
			of[entry.key]=nil;entry.key,entry.position,entry.frameKey=nil,nil,nil
		end
		if entry.key==nil then
			hideFruit(entry,hide)
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
		if entry.model then self:drawFruit(entry,v,put,hide);continue end
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

-- The 3D fruit (GARDEN-PLAY-BRIEF-2 section 5) ----------------------------------------------------------------------
-- v: {position, rotation, w, h, transparency, tilt (degrees), axis, turn (degrees about up), eatT (seconds eaten),
-- seat (a seated canopy slot, or nil), variety (GardenFruit.Varieties entry, or nil: today's look)}.
local function moved(a,b,eps)return a==nil or math.abs(a-b)>eps end
-- The variety of grove crown i's tree (GardenFruit.variety; today's sunset look without a tree).
function Life:fruitVariety(i)
	local crown=self.grove and self.grove.crowns[i]
	return Fruit.variety(crown and crown.tree)
end
function Life:drawFruit(entry,v,put,hide)
	local L,B,C=Fruit.Look,Fruit.Bites,Fruit.Canopy
	local position,w,h,transparency,tilt,axis,turn,eatT=v[1],v[3],v[4],v[5],v[6]or 0,v[7]or FRUIT_SIDE,v[8]or 0,v[9]
	local seat,variety=v[10],v[11]
	local s=(w+h)/2
	-- Beta 38: the tree's variety (written only when it changes).
	if variety and entry.variety~=variety and entry.body then
		entry.variety=variety
		entry.body.Color=Color3.fromHex(variety.body)
		entry.blush.Color=Color3.fromHex(variety.blush)
	end
	-- The stem and leaf come off at the first bite: they drop and fade over stemFade.
	local stemAlpha=if eatT then math.clamp(eatT/B.stemFade,0,1)else 0
	local frameKey=string.format("%.3f,%.3f,%.3f,%.2f,%.2f,%.3f,%.3f,%.3f,%s",position.X,position.Y,position.Z,tilt,turn,w,h,stemAlpha,
		if seat then "s"else "")
	-- A seated fruit's leaf disc (on the leaves' face behind it, facing out) and sprig; hidden when not seated.
	if entry.shadow then
		if seat then
			local normal=seat.normal
			local up=if math.abs(normal.Y)>.9 then Vector3.xAxis else Vector3.yAxis
			local k=w/TREE_SCALE
			local behind=position-normal*(C.size/2-C.size*C.sunk)*k+normal*C.shadow.thick
			if entry.frameKey~=frameKey then
				put(entry.shadow,CFrame.fromMatrix(behind,normal,up,normal:Cross(up)))
				local frame=CFrame.new(position)*CFrame.fromAxisAngle(axis,math.rad(tilt))
				put(entry.sprig,frame*CFrame.new(C.sprig.at*s)*CFrame.Angles(0,0,math.rad(C.sprig.tilt)))
			end
			if moved(entry.seatK,k,.002)then
				entry.seatK=k
				entry.shadow.Size=Vector3.new(C.shadow.thick,math.max(.01,C.shadow.across*k),math.max(.01,C.shadow.across*k))
				entry.sprig.Size=L.leaf.size*math.max(.01,s)
			end
			entry.seatShown=true
		elseif entry.seatShown then
			entry.seatShown=false
			if hide then hide(entry.shadow);hide(entry.sprig)end
		end
	end
	if entry.frameKey~=frameKey then
		entry.frameKey=frameKey
		entry.position=position
		local frame=CFrame.new(position)*CFrame.fromAxisAngle(axis,math.rad(tilt))*CFrame.Angles(0,math.rad(turn),0)
		local drop=Vector3.new(0,B.stemDrop*stemAlpha,0)
		put(entry.body,frame)
		put(entry.blush,frame*CFrame.new(L.blush.at.X*w,L.blush.at.Y*h,L.blush.at.Z*w))
		-- A Cylinder's length is its X: stood up about Z.
		put(entry.stem,(frame*CFrame.new(L.stem.at*h)-drop)*CFrame.Angles(0,0,math.rad(90)))
		put(entry.leaf,(frame*CFrame.new(L.leaf.at*s)-drop)*CFrame.Angles(0,0,math.rad(L.leaf.tilt)))
	end
	if moved(entry.w,w,.002)or moved(entry.h,h,.002)then
		entry.w,entry.h=w,h
		local function at(n)return math.max(.01,n)end
		entry.body.Size=Vector3.new(at(L.body.size*w),at(L.body.size*h),at(L.body.size*w))
		entry.blush.Size=Vector3.one*at(L.blush.size*s)
		entry.stem.Size=L.stem.size*at(s)
		entry.leaf.Size=L.leaf.size*at(s)
	end
	if moved(entry.transparency,transparency,.005)or moved(entry.stemAlpha,stemAlpha,.005)then
		entry.transparency,entry.stemAlpha=transparency,stemAlpha
		entry.body.Transparency,entry.blush.Transparency=transparency,transparency
		local top=math.max(transparency,stemAlpha)
		entry.stem.Transparency,entry.leaf.Transparency=top,top
	end
end

-- The bites' crumbs: a small burst that falls. One emitter, moved to the fruit for each bite.
function Life.crumbEmitter(anchor)
	local e=Instance.new("ParticleEmitter")
	e.Name="Crumbs"
	e.Texture=LifeArt.id("fireflyDot")or ""
	e.Color=ColorSequence.new(Color3.fromHex(Fruit.Look.body.colour))
	e.Size=keys({{0,.09},{1,.04}})
	e.Transparency=keys({{0,0},{.7,0},{1,1}})
	e.Lifetime=NumberRange.new(.45,.7)
	e.Speed=NumberRange.new(2.2,3.6)
	e.SpreadAngle=Vector2.new(70,70)
	e.EmissionDirection=Enum.NormalId.Top
	e.Acceleration=Vector3.new(0,-24,0)
	e.Rate=0
	e.Enabled=true
	e.LockedToPart=false
	e.LightEmission,e.LightInfluence=0,1
	e.Parent=anchor
	return e
end

-- The fruit's sounds (existing takes; GardenFruit.Sounds): four voices on one invisible part, through the garden's cue
-- group so the Sound setting mutes them. LifePet plays the bites through Life:fruitSound too.
Life.FruitVoices=4
function Life:fruitVoices(folder)
	local anchor=part(folder,"LifeFruitAudio","Part",Vector3.new(.2,.2,.2),false)
	self.voices={}
	self.uris={}
	local group
	pcall(function()group=game:GetService("SoundService"):FindFirstChild("EggDropAmbientCues")end)
	for i=1,Life.FruitVoices do
		local holder=Instance.new("Attachment");holder.Name="voice"..i;holder.Parent=anchor
		local voice=Instance.new("Sound");voice.Name="fruit"..i
		voice.RollOffMode=Enum.RollOffMode.InverseTapered;voice.RollOffMinDistance=6;voice.RollOffMaxDistance=60
		voice.Volume=0;voice.SoundGroup=group;voice.Parent=holder
		table.insert(self.voices,{holder=holder,voice=voice,at=-math.huge})
	end
end
function Life:fruitUri(cue)
	if self.uris[cue]~=nil then return self.uris[cue]or nil end
	local out
	pcall(function()
		local Audio=require(script.Parent.BoardAudio)
		local asmr=Audio.AsmrIds and Audio.AsmrIds[cue]
		out=if type(asmr)=="number"and asmr>0 then "rbxassetid://"..asmr else Audio.uri(cue)
	end)
	self.uris[cue]=out or false
	return out
end
-- Play `cue` at `position` (nil: the player) at `volume`, `pitch`. Answers whether it played. A spec's `play` dep
-- hears it instead.
function Life:fruitSound(cue,position,volume,pitch)
	if not self.enabled then return false end
	if typeof(position)~="Vector3"then position=self.root()end
	if typeof(position)~="Vector3"then return false end
	volume,pitch=volume or 1,pitch or 1
	if self.play then
		local ok=pcall(self.play,cue,position,volume,pitch)
		return ok
	end
	if not self.voices then return false end
	local uri=self:fruitUri(cue)
	if not uri then return false end
	local pick
	for _,v in ipairs(self.voices)do if not v.voice.IsPlaying then pick=v;break end end
	if not pick then
		pick=self.voices[1]
		for _,v in ipairs(self.voices)do if v.at<pick.at then pick=v end end
	end
	pick.at=os.clock()
	pick.holder.WorldPosition=position
	local voice=pick.voice
	voice.SoundId=uri;voice.PlaybackSpeed=pitch;voice.Volume=volume;voice.TimePosition=0
	voice:Play()
	return true
end

-- A shaken slot: 0 while it hangs empty (Shake.hidden), then 0 to 1 as it grows back (Shake.grow); nil when it is on
-- the tree as usual.
function Life:shakenScale(key,now)
	local at=self.shaken and self.shaken[key]
	if not at then return nil end
	local S=Fruit.Shake
	local t=now-at
	if t<0 then return nil end -- beta 38: a shake's fruit hangs on till its let-go
	if t<S.hidden then return 0 end
	if t<S.hidden+S.grow then return math.max(.001,(t-S.hidden)/S.grow)end
	self.shaken[key]=nil
	return nil
end
-- What is off the trees now: the grove's drops (a shaken slot's own drops skipped while it grows back) and this
-- client's shake drops still about.
function Life:activeFruit(now)
	local active=self.grove:active(now)
	if not self.fruit3d or(#self.shakeDrops==0 and next(self.shaken)==nil)then return active end
	local S=Fruit.Shake
	for index=#active,1,-1 do
		local at=self.shaken[active[index].key]
		if at and active[index].start>=at and active[index].start<at+S.hidden+S.grow then table.remove(active,index)end
	end
	for index=#self.shakeDrops,1,-1 do
		local plan=self.shakeDrops[index]
		if now>=plan.gone then
			table.remove(self.shakeDrops,index)
			self.shakeLanded[plan.id]=nil
		elseif plan.start<=now then
			table.insert(active,plan)
		end
	end
	table.sort(active,function(a,b)return a.start<b.start end)
	return active
end
-- The tree shake: the player walks into a fruit tree's trunk faster than Shake.speed (the root's own speed between two
-- steps). The crown rocks (WindClient), eight leaf cards fall, one fruit drops with the gust drop's fall and bounces,
-- the rustle plays twice and the buzz; the server is told (FruitClient). That tree has nothing to shake till its fruit
-- grows back. Reduced Motion: the rustle and the buzz only (no rock, no leaves, nothing falls).
-- Beta 38 (GARDEN-B38-BRIEF 3b): the prompt shake. A press (the prompt's Triggered, or a spec) asks; the next step
-- shakes tree i when it is allowed for me and my root is within GardenFruit.promptReach of its trunk: the same shake
-- as a bump, so the server hears the same message.
function Life:askShake(i)
	if type(i)=="number"and self.shakePrompts and self.shakePrompts[i]then self.shakeAsk=i;return true end
	return false
end
-- One tree's prompt: an invisible anchor at the trunk, Fruit.Prompt.height over the ground.
function Life:shakePrompt(folder,i,tree)
	local ground=self.groundY and self.groundY(tree.x,tree.z)
	if type(ground)~="number"or ground~=ground then ground=4 end
	local anchor=part(folder,"LifeShakePrompt"..i,"Part",Vector3.new(.2,.2,.2),false)
	anchor.CFrame=CFrame.new(tree.x,ground+Fruit.Prompt.height,tree.z)
	local copy=function(key,fallback)
		local ok,text=pcall(function()return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UICopy")).get(key)end)
		return if ok and type(text)=="string"then text else fallback
	end
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name="FruitShakePrompt"
	prompt.ObjectText=copy("fruit.tree","Fruit tree")
	prompt.ActionText=copy("fruit.shake","Shake")
	prompt.HoldDuration=0
	prompt.RequiresLineOfSight=false
	prompt.MaxActivationDistance=Fruit.promptReach(tree)
	prompt.Enabled=false
	pcall(function()
		-- Say hi is E / gamepad X (RoomView): the Shake is R on a keyboard, so both show; on a gamepad it keeps X and
		-- Say hi wins while the pet is in its reach (Life.shakePromptWanted); touch taps either.
		prompt.KeyboardKeyCode,prompt.GamepadKeyCode=Life.ShakeKey,Enum.KeyCode.ButtonX
		prompt.ClickablePrompt=true
		prompt.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
	end)
	prompt:SetAttribute("FruitTree",i)
	prompt.Parent=anchor
	local triggered=prompt.Triggered
	if typeof(triggered)=="RBXScriptSignal"then
		triggered:Connect(function(who)
			if who==nil or who==Players.LocalPlayer then self:askShake(i)end
		end)
	end
	return{anchor=anchor,prompt=prompt,on=false}
end
Life.ShakeKey=Enum.KeyCode.R
-- Pure: a tree's Shake prompt shows when its shake is allowed (ready), nothing is up over the garden (a menu, the deck,
-- focus, the dash: blocked), and, on a gamepad, the pet's Say hi (the same button) is not in reach.
function Life.shakePromptWanted(ready,blocked,sayHiNear,inputKind)
	return ready==true and blocked~=true and not(sayHiNear==true and inputKind=="Gamepad")
end
local function ask(fn,...)
	if type(fn)~="function"then return nil end
	local ok,value=pcall(fn,...)
	return if ok then value else nil
end
function Life:shakeBlocked()return ask(self.promptBlocked)==true end
-- The prompts on while a shake is allowed for me (now past the tree's rest); `on` false: every prompt off.
function Life:promptStep(now,on)
	local blocked,near,kind
	if on~=false then blocked,near,kind=self:shakeBlocked(),ask(self.sayHiNear)==true,ask(self.inputKind)end
	for i,entry in pairs(self.shakePrompts or {})do
		local ready=on~=false and type(now)=="number"and now>=(self.shakeReady and self.shakeReady[i]or -math.huge)
		local want=Life.shakePromptWanted(ready,blocked,near,kind)
		if want~=entry.on then entry.on=want;entry.prompt.Enabled=want end
	end
end
function Life:stepShake(now,reduced,put)
	local root=self.root()
	if typeof(root)~="Vector3"or not self.lime then self.shakeRoot=nil;self.shakeAsk=nil;self:promptStep(now,false);return end
	local last=self.shakeRoot
	self.shakeRoot={at=root,t=now}
	-- The stem's pluck as a shake drop lets go; a landing thud and a light tick as it first lands.
	for _,plan in ipairs(self.shakeDrops)do
		if not self.shakeLanded[plan.id..":pluck"]and now>=plan.start then
			self.shakeLanded[plan.id..":pluck"]=true
			self:fruitSound(Fruit.Sounds.pluck,plan.stem,Fruit.Sounds.pluckVolume,Fruit.Sounds.pluckPitch)
		end
		if not self.shakeLanded[plan.id]and now>=plan.t2 then
			self.shakeLanded[plan.id]=true
			self:fruitSound(Fruit.Sounds.land,plan.p1,Fruit.Sounds.landVolume,1)
			pcall(self.buzz,Fruit.LandBuzz)
		end
	end
	local ask=self.shakeAsk
	self.shakeAsk=nil
	if ask and self:shakeBlocked()then ask=nil end -- a press that landed as a menu, the deck, focus or the dash opened
	if ask then
		local crown,tree=self.grove.crowns[ask],self.fruitTrees and self.fruitTrees[ask]
		if crown and tree and now>=(self.shakeReady[ask]or -math.huge)and Fruit.promptShakes(tree,root.X,root.Z)then
			self:shake(ask,crown,now,reduced,put)
		end
	end
	self:promptStep(now,true)
	if not last or now-last.t<=1e-3 or now-last.t>.5 then return end
	local speed=Sim.flat(root,last.at)/(now-last.t)
	if speed<Fruit.Shake.speed then return end
	for i,crown in ipairs(self.grove.crowns)do
		local tree=self.fruitTrees and self.fruitTrees[i]
		if tree and now>=(self.shakeReady[i]or -math.huge)and Fruit.shakes(tree,root.X,root.Z,speed)then
			self:shake(i,crown,now,reduced,put)
			return
		end
	end
end
-- Beta 38 (3b): the fruit lets go on the second swing (GardenFruit.dropTimes) and one shake in four a second follows;
-- an empty tree still shakes (leaves only). Sounds: the shake layer, the rustles and, with fruit, a low creak and a
-- pluck per fruit; an empty shake is the shake and the rustles alone, a little lower. Returns the first plan.
function Life:shake(i,crown,now,reduced,put)
	local S,Sounds=Fruit.Shake,Fruit.Sounds
	self.shakeReady[i]=now+S.hidden+S.grow
	local under=crown.position-Vector3.new(0,(typeof(crown.size)=="Vector3"and crown.size.Y or 4)*.25,0)
	self.shakeCount+=1
	-- What will fall (nothing falls under Reduced Motion: its sounds are the empty shake's).
	local plans={}
	if not reduced then
		local grove=self.grove
		local taken={}
		for k,letgo in ipairs(Fruit.dropTimes(now,self.shakeCount))do
			local plan=Sim.fruitShakePlan(i,crown,grove.stems[i],letgo,-(1000000+self.shakeCount*4+k),self.fruitWorld,function(key)
				return not taken[key]and grove:hanging(key,now)~=nil and self:shakenScale(key,now)==nil
			end)
			if not plan then break end
			taken[plan.key]=true
			table.insert(plans,plan)
		end
	end
	local full=#plans>0
	local pitch=if full then 1 else Sounds.emptyPitch
	self:fruitSound(Sounds.shake,under,Sounds.shakeVolume,Sounds.shakePitch*pitch)
	local takes={"a","b","c","d","e"}
	for k=1,Sounds.rustles do
		self:fruitSound(Sounds.rustle.."_"..takes[(self.shakeCount+k)%#takes+1],under,Sounds.rustleVolume,(.95+.1*(k-1))*pitch)
	end
	if full then self:fruitSound(Sounds.creak,under,Sounds.creakVolume,Sounds.creakPitch)end
	pcall(self.buzz,Fruit.Buzz)
	if self.shook then pcall(self.shook,i,#plans)end -- the server opens a claim per fruit that falls
	if reduced then return nil end
	local follow=self.follow and self.follow[i]
	if follow and follow.part.Parent then pcall(self.rock,follow.part)end
	if self.shakeLeaves then
		put(self.shakeLeaves.anchor,CFrame.new(under))
		table.insert(self.fruitEmits,{self.shakeLeaves.emitter,S.leaves})
	end
	for _,plan in ipairs(plans)do
		self.shaken[plan.key]=plan.start
		table.insert(self.shakeDrops,plan)
	end
	return plans[1]
end

-- AmbientAudio calls this for each chirp it actually plays. A bird comes in to that perch's crown, or the one
-- already there hops. Ignored while off, parked or with no landing there, and when the chirp's own position is not
-- that landing's tree (AmbientAudio reading other perches than LifeSpots was built from). Returns what LifeSim answered.
Life.SameTree=4
function Life:chirp(perch,position,_cue)
	if not self.enabled or self.parked or type(perch)~="number"then return nil end
	if self.hushed then return nil,"quiet"end
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
	if not self.enabled then return{birds=0,butterflies=0,leaves=0,petals=0,glows=0,bubbles=0,fruit=0,loose=0,fireflies=0}end
	local now=self.now()
	local leaves=self.leaves:count(now)
	local glows,fireflies=0,0
	for _,entry in ipairs(self.flyPool)do if entry.glowOn then glows+=1 end end
	for _,entry in ipairs(self.firePool)do if entry.glowOn then fireflies+=1 end end
	return{birds=#self.birds.list,butterflies=#self.flies.list,leaves=leaves,petals=leaves,glows=glows,bubbles=self.bubbles:count(now),
		fruit=if self.parked then 0 else self.fruitCount,loose=#self.loose.list,fireflies=fireflies}
end

return Life
