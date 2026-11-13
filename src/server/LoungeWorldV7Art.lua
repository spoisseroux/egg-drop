-- World 1 v7: the floating sky island. Clones the authored meshes from
-- ServerStorage.WorldAssets.WorldV7 (assets/world/WorldAssets.rbxmx) into the
-- lounge and adds the gameplay pieces the meshes cannot carry: the invisible
-- Floor bounds, perimeter wall, cave blocker, fall catch, wet and blocked pet
-- regions, the bridge support, station prompts, lights and water beams.
local Lighting=game:GetService("Lighting")
local ServerStorage=game:GetService("ServerStorage")
local Shared=game:GetService("ReplicatedStorage").Shared
local World=require(Shared.HollowWorldLayout)
local Data=require(Shared.WorldV7Data)
local Flags=require(Shared.FeatureFlags)
local Dusk=require(Shared.WorldDusk)
local Dressing=require(Shared.WorldDressing)

local Art={}

local function invisible(room,name,cframe,size,collide)
	local p=Instance.new("Part")
	p.Name,p.Size,p.CFrame=name,size,cframe
	p.Anchored,p.CanCollide,p.CanTouch=true,collide==true,false
	p.CanQuery=collide==true
	p.Transparency,p.CastShadow=1,false
	p.Material=Enum.Material.SmoothPlastic
	p.Parent=room
	return p
end

local function box(entry)
	local c,s=entry.center,entry.size
	return CFrame.new(c[1],c[2],c[3])*CFrame.Angles(0,entry.yaw or 0,0),Vector3.new(s[1],s[2],s[3])
end

function Art.lighting()
	-- Day/night off (FeatureFlags.DayNight=false): the locked dusk from WorldDusk, which the
	-- client clock repaints with the same values.
	if not Flags.DayNight then
		Dusk.apply(Lighting,Data)
		return
	end
	Lighting.ClockTime=14.5
	Lighting.Brightness=2.3
	Lighting.Ambient=Color3.fromHex("#9C9C92")
	Lighting.OutdoorAmbient=Color3.fromHex("#A4AEB4")
	Lighting.ColorShift_Top=Color3.fromHex("#FFF4E5")
	Lighting.EnvironmentDiffuseScale=.35
	Lighting.EnvironmentSpecularScale=.2
	Lighting.ShadowSoftness=.6
	local air=Lighting:FindFirstChildOfClass("Atmosphere")or Instance.new("Atmosphere")
	air.Density,air.Offset,air.Haze,air.Glare=.16,0,.35,0
	air.Color,air.Decay=Color3.fromHex("#CFE6F5"),Color3.fromHex("#A9C6E0")
	air.Parent=Lighting
	local grade=Lighting:FindFirstChild("SproutHollowGrade")or Instance.new("ColorCorrectionEffect")
	grade.Name,grade.Contrast,grade.Saturation,grade.TintColor="SproutHollowGrade",.03,.05,Color3.fromHex("#F4F8FF")
	grade.Parent=Lighting
	-- Day faces by default; HollowClock swaps to the night faces after dusk.
	local sky=Lighting:FindFirstChild("WorldSky")or Instance.new("Sky")
	sky.Name="WorldSky"
	for _,face in ipairs({"Bk","Dn","Ft","Lf","Rt","Up"})do sky["Skybox"..face]=Data.sky.day[face]end
	sky.CelestialBodiesShown,sky.StarCount=false,0
	sky.Parent=Lighting
end

function Art.meshes(room)
	local template=ServerStorage:FindFirstChild("WorldAssets")and ServerStorage.WorldAssets:FindFirstChild("WorldV7")
	if not template then warn("[World v7] ServerStorage.WorldAssets.WorldV7 is missing; the island will be empty")return nil end
	local world=template:Clone()
	world.Name="World"
	local count,tris=0,0
	for _,part in ipairs(world:GetChildren())do
		if not part:IsA("BasePart")then continue end
		count+=1
		part.Anchored=true
		local info=Data.parts[part.Name]
		-- Merged meshes span the island: bounds-based queries (overlap boxes,
		-- camera blockers, rest-path solids) skip them and use rays instead.
		part:SetAttribute("WorldMesh",true)
		if info then
			part:SetAttribute("WorldRegion",info.region)
			if info.motion then
				part:SetAttribute("WorldMotion",info.motion.kind)
				part:SetAttribute("WorldMotionAmp",info.motion.amp)
				part:SetAttribute("WorldMotionPeriod",info.motion.period)
				part:SetAttribute("WorldMotionPhase",info.motion.phase)
				part:SetAttribute("WorldRestCFrame",part.CFrame)
				-- Distant movers (castle flags, the cloud sea) animate beyond WorldMotion.Range.
				if info.motion.far then part:SetAttribute("WorldMotionFar",true)end
				if info.pivot then part:SetAttribute("WorldPivot",Vector3.new(table.unpack(info.pivot)))end
			end
		end
	end
	world:SetAttribute("MeshParts",count)
	world:SetAttribute("Triangles",Data.triangles)
	world.Parent=room
	return world
end

function Art.collision(room)
	-- Pet and camera code clamp to this box; it never collides or blocks rays.
	invisible(room,"Floor",CFrame.new(World.FloorCenterX,World.FloorTop-.5,World.FloorCenterZ),
		Vector3.new(World.Width,1,World.Depth),false):SetAttribute("PlayableWidth",World.Width)
	room.Floor:SetAttribute("PlayableDepth",World.Depth)
	local walls=Instance.new("Folder");walls.Name="PerimeterWall";walls.Parent=room
	-- QA 2026-11-13: the generated boxes were mirrored across the ring tangent (walk-through gaps); the yaw is fixed
	-- in scripts/build_world_v7_chunks.py. Walls block players only: rays (camera, pets, prompts) pass through.
	for i,entry in ipairs(Data.perimeter)do
		local cf,size=box(entry)
		invisible(walls,"Wall"..i,cf,size,true).CanQuery=false
	end
	local cf,size=box(Data.caveBlocker)
	invisible(room,"CaveBlocker",cf,size,true)
	cf,size=box(Data.fallCatch)
	local catch=invisible(room,"FallCatch",cf,size,false)
	catch.CanTouch=true
	-- Pets: wet footprints (stream, pools, spring), blocked player-only ground and the bridge.
	local regions=Instance.new("Folder");regions.Name="PetRegions";regions.Parent=room
	for _,entry in ipairs(Data.wet)do
		local wcf,wsize=box(entry)
		invisible(regions,entry.name,wcf,Vector3.new(wsize.X,.2,wsize.Z),false):SetAttribute("GardenWetRegion",true)
	end
	for _,entry in ipairs(World.Wet)do
		invisible(regions,entry.name,CFrame.new(entry.center.X,World.FloorTop-.7,entry.center.Y)*CFrame.Angles(0,entry.yaw,0),
			Vector3.new(entry.size.X,.2,entry.size.Y),false):SetAttribute("GardenWetRegion",true)
	end
	for _,entry in ipairs(World.Blocked)do
		invisible(regions,entry.name,CFrame.new(entry.center.X,World.FloorTop+.5,entry.center.Y)*CFrame.Angles(0,entry.yaw,0),
			Vector3.new(entry.size.X,1,entry.size.Y),false):SetAttribute("GardenBlockedRegion",true)
	end
	for id,span in pairs(World.WalkableSpans)do
		invisible(room,id.."Support",CFrame.new(span.center),span.size,true):SetAttribute("GardenWalkableSpan",id)
	end
end

local function prompt(parent,id,action,distance,offset)
	local p=Instance.new("ProximityPrompt")
	p.ActionText,p.ObjectText=action,""
	p.UIOffset=offset or Vector2.zero
	p.Style=Enum.ProximityPromptStyle.Default
	p.KeyboardKeyCode,p.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
	p.ClickablePrompt,p.RequiresLineOfSight,p.HoldDuration=true,false,0
	p.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
	p.MaxActivationDistance=distance
	p:SetAttribute("PocketClubStation",id)
	p.Parent=parent
	return p
end

function Art.stations(room)
	local s=World.Stations
	-- Prompt anchors sit inside the station meshes; they never collide.
	local eggs=invisible(room,"EggsSign",s.Eggs*CFrame.new(0,2.2,0),Vector3.new(2.4,.6,.2),false)
	prompt(eggs,"Eggs","Browse eggs",7,Vector2.new(72,-16)).Name="BrowseEggs"
	local deck=invisible(room,"CustomizeTop",s.Customize*CFrame.new(0,2.4,.6),Vector3.new(3,.3,2),false)
	prompt(deck,"Customize","Style deck",7,Vector2.new(112,-12))
	-- The Journal prompt is the care station: GardenCareLayout measures reach from it.
	local careLayout=require(Shared.GardenCareLayout)
	local journal=invisible(room,"JournalTop",CFrame.new(careLayout.Prompt),Vector3.new(2,.3,2),false)
	prompt(journal,"Journal","Open companions",7,Vector2.new(72,-12))
	require(script.Parent.LoungeCareArt)(room)
end

local function light(parent,range,brightness,color)
	local l=Instance.new("PointLight")
	l.Name="HollowPathLight"
	l.Range,l.Brightness,l.Color,l.Shadows=range,brightness,color,false
	l:SetAttribute("HollowLamp",true)
	l:SetAttribute("HollowDayBrightness",0)
	l:SetAttribute("HollowNightBrightness",brightness)
	l.Parent=parent
	return l
end

function Art.lights(room)
	local folder=Instance.new("Folder");folder.Name="Lights";folder.Parent=room
	local warm,cyan=Color3.fromHex("#FFD5A0"),Color3.fromHex("#7FE8FF")
	local function at(name,position,range,brightness,color)
		local p=invisible(folder,name,CFrame.new(position),Vector3.new(.2,.2,.2),false)
		p:SetAttribute("HollowLampFixture",true)
		return light(p,range,brightness,color)
	end
	for i,p in ipairs(World.Lamps)do if World.LitLamps[i]then at("Lamp"..i,p,14,1.6,warm)end end
	local s=World.Stations
	-- QA 2026-11-12: these five overlap on the white hub marble and blew it out at night,
	-- so each is about 40% dimmer and the plaza light no longer reaches every station.
	at("EggNestLight",s.Eggs.Position+Vector3.new(0,4,0),10,.85,warm)
	at("CradleLight",s.Journal.Position+Vector3.new(0,5,0),10,.8,warm)
	at("KioskLight",s.Customize.Position+Vector3.new(0,5,0),10,.8,warm)
	at("ToyLawnLight",s.ToyLawn.Position+Vector3.new(0,5,0),12,1,warm)
	at("PlazaLight",World.Hub+Vector3.new(0,7,0),14,.6,warm)
	at("LanternLight",Vector3.new(-31.8,8.8,-16.7),8,.8,warm)
	at("BridgeLight",Vector3.new(2.5,7,21),12,1,warm)
	at("RotundaLight",Vector3.new(-60,19,50),16,1.2,warm)
	at("ArrivalLight",s.ArrivalDais.Position+Vector3.new(0,3,0),14,1.6,cyan)
	at("GrottoLight",Vector3.new(-7,7,-106),18,2,cyan)
end

-- Dock feedback on the visible cradle. The legacy machine's coloured parts are
-- hidden supports under the v7 mesh, so its free/occupied colours move to the
-- cradle's neon mobile (always visible) and the cradle lamp (night). Values
-- follow CARE-MACHINE-ART.md: the occupied gauge aqua #62DEDC; the free mobile
-- keeps its authored warm glow. GardenCareClient paints both from the bay state.
Art.CareStatus={mobileRest="#FFD889",mobileOccupied="#62DEDC",lightRest="#FFD5A0",lightOccupied="#7FE8FF"}
function Art.careStatus(room)
	local c=Art.CareStatus
	local function mark(item,rest,occupied)
		if not item then return end
		item:SetAttribute("CareRestColor",rest)
		item:SetAttribute("CareOccupiedColor",occupied)
		item:SetAttribute("CareStatusSurface",true)
	end
	local meshes=room:FindFirstChild("World")
	mark(meshes and meshes:FindFirstChild("W7_CradleMobile__glow_warm"),c.mobileRest,c.mobileOccupied)
	local lights=room:FindFirstChild("Lights")
	local fixture=lights and lights:FindFirstChild("CradleLight")
	mark(fixture and fixture:FindFirstChildOfClass("PointLight"),c.lightRest,c.lightOccupied)
end

-- Moving water (QA 2026-11-13, Q3.1-4). The stream and pools keep their mesh water and gain
-- scrolling Texture skins (the old stream beams sat 0.08 studs above the mesh, z-fought with it
-- and stretched the texture into light-blue streaks). Each waterfall sheet gets one flat beam
-- in its own plane (the old camera-facing beam billboarded and missed the lower sheet), and the
-- foam where the falls land throws gentle splash and mist particles. Client WorldMotion scrolls
-- the skins and stills skins, beams and particles while Reduced Motion is on.
Art.WaterSkins={
	-- part, studs per tile, transparency, flow (studs/s in the part's top-face U, V), layer name
	{part="W7_Water__water_stream",studs=16,transparency=.5,flow={.55,-.95},name="FlowSkin"},
	{part="W7_Water__water_stream",studs=10,transparency=.72,flow={.15,-.6},name="FlowGlint"},
	{part="W7_Water__water_pool",studs=14,transparency=.6,flow={.18,-.12},name="FlowSkin"},
	{part="W7_Landmarks__water",studs=8,transparency=.6,flow={.12,.08},name="FlowSkin"},
}
Art.FoamTexture="rbxasset://textures/particles/smoke_main.dds"

local function foam(folder,entry)
	local c,s=entry.center,entry.size
	local area=s[1]*s[3]
	local p=invisible(folder,entry.name,CFrame.new(c[1],c[2]+.3,c[3]),Vector3.new(math.max(s[1]*.8,1),.2,math.max(s[3]*.8,1)),false)
	local splash=Instance.new("ParticleEmitter")
	splash.Name="Splash"
	splash.Texture=Art.FoamTexture
	splash.Shape=Enum.ParticleEmitterShape.Box
	splash.EmissionDirection=Enum.NormalId.Top
	splash.Rate=math.clamp(area*.25,6,22)
	splash.Lifetime=NumberRange.new(.45,.85)
	splash.Speed=NumberRange.new(4,8)
	splash.SpreadAngle=Vector2.new(28,28)
	splash.Acceleration=Vector3.new(0,-24,0)
	splash.Drag=1
	splash.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,.12)})
	splash.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(.7,.45),NumberSequenceKeypoint.new(1,1)})
	splash.Color=ColorSequence.new(Color3.fromHex("#FFF8FA"))
	splash.LightInfluence,splash.LightEmission=.6,.15
	splash.Rotation,splash.RotSpeed=NumberRange.new(0,360),NumberRange.new(-90,90)
	splash.Parent=p
	local mist=Instance.new("ParticleEmitter")
	mist.Name="Mist"
	mist.Texture=Art.FoamTexture
	mist.Shape=Enum.ParticleEmitterShape.Box
	mist.EmissionDirection=Enum.NormalId.Top
	mist.Rate=math.clamp(area*.05,2,6)
	mist.Lifetime=NumberRange.new(2.5,4)
	mist.Speed=NumberRange.new(.6,1.6)
	mist.SpreadAngle=Vector2.new(35,35)
	mist.Acceleration=Vector3.new(0,.4,0)
	mist.Drag=.6
	mist.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2),NumberSequenceKeypoint.new(1,5.5)})
	mist.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.72),NumberSequenceKeypoint.new(1,1)})
	mist.Color=ColorSequence.new(Color3.fromHex("#FFF1F4"))
	mist.LightInfluence,mist.LightEmission=1,0
	mist.Rotation,mist.RotSpeed=NumberRange.new(0,360),NumberRange.new(-12,12)
	mist.Parent=p
	return p
end

function Art.water(room)
	local folder=Instance.new("Folder");folder.Name="WaterFlow";folder.Parent=room
	-- A beam lies in the plane its attachments' Axis is normal to; SecondaryAxis is world up.
	local function anchor(position,normal)
		local p=invisible(folder,"FlowAnchor",CFrame.new(position),Vector3.new(.1,.1,.1),false)
		local a=Instance.new("Attachment")
		local up=if math.abs(normal.Y)>.9 then Vector3.xAxis else Vector3.yAxis
		a.CFrame=CFrame.fromMatrix(Vector3.zero,normal,up)
		a.Parent=p
		return a
	end
	local meshes=room:FindFirstChild("World")
	for _,skin in ipairs(Art.WaterSkins)do
		local part=meshes and meshes:FindFirstChild(skin.part)
		if not part then continue end
		local t=Instance.new("Texture")
		t.Name=skin.name
		t.Face=Enum.NormalId.Top
		t.Texture=Data.waterTexture
		t.StudsPerTileU,t.StudsPerTileV=skin.studs,skin.studs
		t.Transparency=skin.transparency
		t:SetAttribute("WorldFlowU",skin.flow[1])
		t:SetAttribute("WorldFlowV",skin.flow[2])
		t.Parent=part
	end
	local sheets=Data.beams.sheets or {}
	for _,sheet in ipairs(sheets)do
		local normal=Vector3.new(table.unpack(sheet.normal)).Unit
		local beam=Instance.new("Beam")
		beam.Name=sheet.name
		beam.Attachment0=anchor(Vector3.new(table.unpack(sheet.top)),normal)
		beam.Attachment1=anchor(Vector3.new(table.unpack(sheet.bottom)),normal)
		beam.Width0,beam.Width1=sheet.width0,sheet.width1
		beam.FaceCamera=false
		beam.Texture=Data.fallTexture
		beam.TextureMode=Enum.TextureMode.Wrap
		beam.TextureLength=8
		beam.TextureSpeed=1.3
		beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(.85,.5),NumberSequenceKeypoint.new(1,.9)})
		beam.LightInfluence=1
		beam.Segments=6
		beam:SetAttribute("WorldFlowSpeed",1.3)
		beam.Parent=beam.Attachment0.Parent
	end
	for _,entry in ipairs(Data.foam or {})do foam(folder,entry)end
end

-- Frond bushes at rock bases and path edges (batch 2026-11-13, W1): clones of the
-- ServerStorage.WorldAssets.Dressing templates at WorldDressing.Bushes. Decoration only:
-- no collision, queries or shadows. Skipped (with one warning) until the meshes are uploaded.
function Art.dressing(room)
	local assets=ServerStorage:FindFirstChild("WorldAssets")
	local templates=assets and assets:FindFirstChild("Dressing")
	if not templates then warn("[World v7] WorldAssets.Dressing is missing; frond bushes skipped")return nil end
	local folder=Instance.new("Folder");folder.Name="Dressing"
	local count=0
	for index,entry in ipairs(Dressing.Bushes)do
		if index>Dressing.MaxBushes then break end
		local template=templates:FindFirstChild(Dressing.BushKinds[entry[4]])
		if not template then continue end
		local cframe,size=Dressing.bushPlacement(entry)
		local bush=template:Clone()
		bush.Anchored,bush.CanCollide,bush.CanQuery,bush.CanTouch,bush.CastShadow=true,false,false,false,false
		bush.Size,bush.CFrame=size,cframe
		bush:SetAttribute("WorldDressing","bush")
		bush.Parent=folder
		count+=1
	end
	folder:SetAttribute("Bushes",count)
	folder.Parent=room
	return folder
end

function Art.build(room)
	Art.lighting()
	Art.meshes(room)
	Art.collision(room)
	Art.stations(room)
	Art.lights(room)
	Art.careStatus(room)
	Art.water(room)
	Art.dressing(room)
	room:SetAttribute("WorldVersion","v7")
end

return Art
