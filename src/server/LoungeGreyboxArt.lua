-- Approved garden greybox (2026-11-11) around the existing hub. Geometry is
-- authored in greybox-local studs (floor top 0, landmark tree at 10,-30; see
-- scripts/GardenGreybox.lua) and placed by HollowWorldLayout.GreyboxOffset so
-- the landmark lands on the hatch tree. Pets stay on the ground: terraces,
-- ramps, pillars and the ledge are player-only. Water is a flat sheet on the
-- floor, tagged as a wet region; the west creek is crossed by WestBridge.
local World=require(game:GetService("ReplicatedStorage").Shared.HollowWorldLayout)
local Art={}

local CLIFF,CLIFF_DARK="968AC4","766AA8"
local GRASS,STONE,WOOD,BARK="72B85B","E2D0A0","AE7951","765239"
local WATER,WATER_DEEP,SEA="45C5D0","267BA0","286EBE"

-- {name, local center, size, color, collide[, transparency]}
Art.Blocks=table.freeze({
	{"GreyboxCliffNorth1",Vector3.new(-104,31,-111),Vector3.new(32,62,22),CLIFF,true},
	{"GreyboxCliffNorth2",Vector3.new(-64,28,-111),Vector3.new(48,56,22),CLIFF_DARK,true},
	{"GreyboxCliffNorth3",Vector3.new(-15,32,-111),Vector3.new(50,64,22),CLIFF,true},
	{"GreyboxCliffNorth4",Vector3.new(50,29,-111),Vector3.new(40,58,22),CLIFF_DARK,true},
	{"GreyboxCliffNorth5",Vector3.new(97.5,33,-111),Vector3.new(55,66,22),CLIFF,true},
	{"GreyboxCaveLintel",Vector3.new(20,40,-111),Vector3.new(20,40,22),CLIFF,true},
	{"GreyboxCaveBack",Vector3.new(20,10,-120),Vector3.new(20,20,4),CLIFF_DARK,true},
	{"GreyboxCliffEast1",Vector3.new(131,30,-77.5),Vector3.new(22,60,45),CLIFF,true},
	{"GreyboxCliffEast2",Vector3.new(131,27,-30),Vector3.new(22,54,50),CLIFF_DARK,true},
	{"GreyboxCliffEast3",Vector3.new(131,31,20),Vector3.new(22,62,50),CLIFF,true},
	{"GreyboxCliffEast4",Vector3.new(131,25,72.5),Vector3.new(22,50,55),CLIFF_DARK,true},
	{"GreyboxCliffNECorner",Vector3.new(128,35,-108),Vector3.new(30,70,30),CLIFF,true},
	{"GreyboxWestOutcrop",Vector3.new(-129,15,-80),Vector3.new(18,30,40),CLIFF_DARK,true},
	{"GreyboxSouthRimLip",Vector3.new(0,.5,102),Vector3.new(240,3,4),GRASS,true},
	{"GreyboxSouthCliffFace",Vector3.new(0,-22,106),Vector3.new(260,44,6),CLIFF_DARK,true},
	{"GreyboxTerraceLow",Vector3.new(100,4,-20),Vector3.new(40,8,80),GRASS,true},
	{"GreyboxTerraceHigh",Vector3.new(105,8,-75),Vector3.new(30,16,50),GRASS,true},
	{"GreyboxNookRoof",Vector3.new(112,18,10),Vector3.new(16,2,14),CLIFF,true},
	{"GreyboxNookPost",Vector3.new(105,12.5,4),Vector3.new(2,9,2),BARK,true},
	{"GreyboxNookPost",Vector3.new(105,12.5,16),Vector3.new(2,9,2),BARK,true},
	{"GreyboxPillarLedge",Vector3.new(-110,10.5,-17),Vector3.new(18,21,12),CLIFF,true},
	{"GreyboxWaterfall",Vector3.new(-75,27,-99),Vector3.new(12,56,2),WATER,false,.15},
	{"GreyboxWaterfallFoam",Vector3.new(-75,.06,-95),Vector3.new(16,.12,6),"F1EEDB",false},
	{"GreyboxSea",Vector3.new(0,-40,900),Vector3.new(2000,1,2000),SEA,false},
})

-- Wedge ramps: full height at local +Z. {name, local center, size, yaw degrees}
Art.Ramps=table.freeze({
	{"GreyboxRampLow",Vector3.new(68,4,8),Vector3.new(10,8,24),90},
	{"GreyboxRampHigh",Vector3.new(100,12,-40),Vector3.new(10,8,20),180},
})

-- Stepping pillars to the lookout ledge: 10-stud tops, 3.5-stud rises.
Art.Pillars=table.freeze({
	{Vector3.new(-107,1.75,39),3.5},{Vector3.new(-107,3.5,28),7},{Vector3.new(-107,5.25,17),10.5},
	{Vector3.new(-107,7,6),14},{Vector3.new(-107,8.75,-5),17.5},
})

-- Flat water sheets (local XZ center, XZ size). Every one is a wet region.
Art.Water=table.freeze({
	{"GreyboxPond",Vector2.new(-75,-65),Vector2.new(36,70)},
	{"GreyboxCreek",Vector2.new(-73,35),Vector2.new(12,130)},
})

-- Player-only obstacles pets walk around (local XZ center, XZ size). Each becomes
-- an invisible GardenBlockedRegion footprint in the wet list, so follow legs,
-- rest paths and the planner's corner graph all avoid them.
Art.PetBlocks=table.freeze({
	{Vector2.new(100,-20),Vector2.new(40,80)}, -- low terrace
	{Vector2.new(105,-75),Vector2.new(30,50)}, -- high terrace
	{Vector2.new(68,8),Vector2.new(24,10)}, -- low ramp (yawed 90)
	{Vector2.new(100,-40),Vector2.new(10,20)}, -- high ramp
	{Vector2.new(-107,17),Vector2.new(10,54)}, -- pillar row
	{Vector2.new(-110,-17),Vector2.new(18,12)}, -- pillar ledge
	{Vector2.new(128,-108),Vector2.new(30,30)}, -- north-east cliff corner
})

-- Decorative stepping stones in the creek (players only).
Art.CreekStones=table.freeze({Vector2.new(-75,55),Vector2.new(-73,61),Vector2.new(-71,67)})

function Art.toWorld(position)
	return position+World.GreyboxOffset
end

function Art.build(room,part)
	local function box(name,position,size,color,collide)
		local p=part(room,name,size,CFrame.new(position),Color3.fromHex(color),collide==true)
		p.CanTouch=false;p.CanQuery=collide==true;return p
	end
	for _,entry in ipairs(Art.Blocks)do
		local name,center,size,color,collide,transparency=table.unpack(entry)
		local p=box(name,Art.toWorld(center),size,color,collide)
		if transparency then p.Transparency=transparency end
		if not collide then p.CastShadow=false end
		if color==CLIFF or color==CLIFF_DARK then p.Material=Enum.Material.Slate end
	end
	for _,entry in ipairs(Art.Ramps)do
		local name,center,size,yaw=table.unpack(entry)
		local ramp=Instance.new("WedgePart")
		ramp.Name,ramp.Size,ramp.Anchored,ramp.CanCollide,ramp.CanQuery,ramp.CanTouch=name,size,true,true,true,false
		ramp.CFrame=CFrame.new(Art.toWorld(center))*CFrame.Angles(0,math.rad(yaw),0)
		ramp.Color,ramp.Material,ramp.TopSurface,ramp.BottomSurface=Color3.fromHex(GRASS),Enum.Material.SmoothPlastic,Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
		ramp.Parent=room
	end
	for _,entry in ipairs(Art.Pillars)do
		local center,height=entry[1],entry[2]
		local p=box("GreyboxPillar",Art.toWorld(center),Vector3.new(height,10,10),STONE,true)
		p.Shape=Enum.PartType.Cylinder;p.CFrame=CFrame.new(p.Position)*CFrame.Angles(0,0,math.pi/2)
	end
	local top=World.FloorTop
	for _,entry in ipairs(Art.Water)do
		local name,center,size=table.unpack(entry)
		local world=Art.toWorld(Vector3.new(center.X,0,center.Y))
		local sheet=box(name,Vector3.new(world.X,top+.045,world.Z),Vector3.new(size.X,.09,size.Y),WATER,false)
		sheet.CastShadow=false;sheet:SetAttribute("GardenWetRegion",true)
		local deep=box(name.."Depth",Vector3.new(world.X,top+.07,world.Z),Vector3.new(size.X-2,.06,size.Y-2),WATER_DEEP,false)
		deep.CastShadow=false
	end
	for _,stone in ipairs(Art.CreekStones)do
		local world=Art.toWorld(Vector3.new(stone.X,0,stone.Y))
		local p=box("GreyboxCreekStone",Vector3.new(world.X,top+.25,world.Z),Vector3.new(.5,5,5),STONE,true)
		p.Shape=Enum.PartType.Cylinder;p.CFrame=CFrame.new(p.Position)*CFrame.Angles(0,0,math.pi/2)
	end
	for _,entry in ipairs(Art.PetBlocks)do
		local center,size=entry[1],entry[2]
		local world=Art.toWorld(Vector3.new(center.X,0,center.Y))
		local block=box("GreyboxPetBlock",Vector3.new(world.X,top+.5,world.Z),Vector3.new(size.X,1,size.Y),GRASS,false)
		block.Transparency,block.CastShadow,block.CanQuery=1,false,false
		block:SetAttribute("GardenBlockedRegion",true)
	end
	-- West crossing: an invisible support span plus visible planks and rails.
	local bridge=World.WalkableSpans.WestBridge
	local deck=box("GreyboxBridgeSupport",bridge.center,bridge.size,GRASS,true)
	deck.Transparency=1;deck:SetAttribute("GardenWalkableSpan","WestBridge")
	local left=bridge.center.X-bridge.size.X*.5
	for i=0,math.floor(bridge.size.X/.8)-1 do
		local plank=box("GreyboxBridgePlank",Vector3.new(left+.4+i*.8,bridge.center.Y+.01,bridge.center.Z),
			Vector3.new(.72,bridge.size.Y,bridge.size.Z),if i%2==0 then WOOD else BARK,false)
		plank.Material=Enum.Material.WoodPlanks
	end
	for _,side in ipairs({-1,1})do
		local z=bridge.center.Z+side*(bridge.size.Z*.5-.15)
		box("GreyboxBridgeRail",Vector3.new(bridge.center.X,top+1.15,z),Vector3.new(bridge.size.X,.15,.15),WOOD,true)
		for _,dx in ipairs({-.5,0,.5})do
			box("GreyboxBridgePost",Vector3.new(bridge.center.X+dx*(bridge.size.X-.4),top+.65,z),Vector3.new(.22,1.2,.22),BARK,true)
		end
	end
end

return Art
