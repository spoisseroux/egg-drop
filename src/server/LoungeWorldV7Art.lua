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
	for i,entry in ipairs(Data.perimeter)do
		local cf,size=box(entry)
		invisible(walls,"Wall"..i,cf,size,true)
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
	at("EggNestLight",s.Eggs.Position+Vector3.new(0,4,0),12,1.4,warm)
	at("CradleLight",s.Journal.Position+Vector3.new(0,5,0),12,1.3,warm)
	at("KioskLight",s.Customize.Position+Vector3.new(0,5,0),12,1.3,warm)
	at("ToyLawnLight",s.ToyLawn.Position+Vector3.new(0,5,0),12,1,warm)
	at("PlazaLight",World.Hub+Vector3.new(0,7,0),22,1.2,warm)
	at("LanternLight",Vector3.new(-31.8,8.8,-16.7),10,1.2,warm)
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

-- Flowing water overlays: beams scroll the water texture downstream and down
-- the falls. Client WorldMotion stops them when Reduced Motion is on.
function Art.water(room)
	local folder=Instance.new("Folder");folder.Name="WaterFlow";folder.Parent=room
	local function anchor(position,up)
		local p=invisible(folder,"FlowAnchor",CFrame.new(position),Vector3.new(.1,.1,.1),false)
		local a=Instance.new("Attachment")
		a.Axis,a.SecondaryAxis=Vector3.xAxis,up
		a.Parent=p
		return a
	end
	local stream=Data.beams.stream
	for i=1,#stream-1 do
		local a,b=stream[i],stream[i+1]
		local beam=Instance.new("Beam")
		beam.Attachment0=anchor(Vector3.new(a[1],a[2],a[3]),Vector3.yAxis)
		beam.Attachment1=anchor(Vector3.new(b[1],b[2],b[3]),Vector3.yAxis)
		beam.Width0,beam.Width1=a[4],b[4]
		beam.FaceCamera=false
		beam.Texture=Data.waterTexture
		beam.TextureMode=Enum.TextureMode.Static
		beam.TextureLength=1
		beam.TextureSpeed=.15
		beam.Transparency=NumberSequence.new(.55)
		beam.LightInfluence=1
		beam.Segments=4
		beam:SetAttribute("WorldFlowSpeed",.15)
		beam.Parent=beam.Attachment0.Parent
	end
	for _,fall in ipairs(Data.beams.falls)do
		local beam=Instance.new("Beam")
		beam.Attachment0=anchor(Vector3.new(table.unpack(fall.top)),Vector3.zAxis)
		beam.Attachment1=anchor(Vector3.new(table.unpack(fall.bottom)),Vector3.zAxis)
		beam.Width0,beam.Width1=fall.width,fall.width*1.1
		beam.FaceCamera=true
		beam.Texture=Data.fallTexture
		beam.TextureMode=Enum.TextureMode.Wrap
		beam.TextureLength=8
		beam.TextureSpeed=1.3
		beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(.8,.55),NumberSequenceKeypoint.new(1,1)})
		beam.LightInfluence=1
		beam:SetAttribute("WorldFlowSpeed",1.3)
		beam.Parent=beam.Attachment0.Parent
	end
end

function Art.build(room)
	Art.lighting()
	Art.meshes(room)
	Art.collision(room)
	Art.stations(room)
	Art.lights(room)
	Art.careStatus(room)
	Art.water(room)
	room:SetAttribute("WorldVersion","v7")
end

return Art
