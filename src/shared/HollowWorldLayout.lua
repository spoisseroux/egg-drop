-- Authored world coordinates, one table per world version. Everything that
-- places gameplay (spawn, stations, toy lawn, rest spots, bridges, wet and
-- blocked regions) reads the active table, so switching WorldVersion moves
-- all of it together.
--   "v7"     the World 1 v7 floating sky island (assets/world, 2026-11-12)
--   "legacy" the approved greybox garden (2026-11-11, LoungeGreyboxArt)
-- ReplicatedStorage attribute WorldVersion overrides the default in Studio.
local DEFAULT_VERSION="v7"
local function points(values)return table.freeze(values)end

-- The hub (stations, hatch tree, spawn, toy lawn, creek nook, spring meadow)
-- with the approved greybox landscape around it. Every crossing bridge spans
-- X over water that runs along Z.
local Legacy={
	WorldVersion="legacy",
	-- Floor covers greybox-local X -121..120, Z -100..100.
	Width=241,Depth=200,FloorCenterX=-10.5,FloorCenterZ=25,FloorTop=4,
	-- greybox-local + offset = world; the greybox landmark tree sits on the hatch tree.
	GreyboxOffset=Vector3.new(-10,4,25),
	Spawn=CFrame.new(0,4,4)*CFrame.Angles(0,math.pi,0),
    Spring=table.freeze({
        LawnCenter=Vector2.new(-10,88),LawnSize=Vector2.new(14,12),
        Rest=Vector3.new(-10,4.025,87),
        RestWest=Vector3.new(-12.5,4.025,87),RestEast=Vector3.new(-7.5,4.025,87),
        BasinCenter=Vector3.new(-14,4.20,99),BasinSize=Vector3.new(7,.12,3.6),
    }),
    WalkableSpans=table.freeze({
        PrimaryBridge=table.freeze({center=Vector3.new(17.6,4.25,-9.4),size=Vector3.new(10.0,.21,4.5),crossing=true}),
        WestBridge=table.freeze({center=Vector3.new(-83,4.25,35),size=Vector3.new(16.0,.21,6.0),crossing=true}),
        RestNook=table.freeze({center=Vector3.new(26,4.025,-15.2),size=Vector3.new(8.3,.25,5.0)}),
    }),
	Landmarks=table.freeze({Spring=Vector2.new(-10,88),WestBridge=Vector2.new(-83,35),Cave=Vector2.new(10,-72)}),
	Routes=table.freeze({
        SpringApproach=points({Vector2.new(0,39),Vector2.new(0,48)}),
        SpringLoop=points({Vector2.new(0,48),Vector2.new(-12,60),Vector2.new(-17,77),Vector2.new(-9,91),Vector2.new(5,83),Vector2.new(6,63),Vector2.new(0,48)}),
	}),
	Lamps=points({Vector2.new(-72,31),Vector2.new(-18,89),Vector2.new(65,-18),Vector2.new(44,40),
		Vector2.new(-3,69),Vector2.new(-7,51),Vector2.new(4,-68)}),
	LitLamps=table.freeze({[1]=true,[2]=true,[7]=true}),
}
function Legacy.groundY(_x,_z)return Legacy.FloorTop end

-- World 1 v7. Positions come from artifacts/world1-mockup/v7/stations.json;
-- heights were measured by raycast against the imported meshes in Studio.
local Data=require(script.Parent.WorldV7Data)
local V7={
	WorldVersion="v7",
	-- Bounds of the walkable island (inside the perimeter wall), used as the
	-- invisible non-colliding Floor part that pet and camera code clamp to.
	Width=228,Depth=176,FloorCenterX=4,FloorCenterZ=-2,FloorTop=4,
	-- Arrival dais, facing the hub plaza across the bridge.
	Spawn=CFrame.lookAt(Vector3.new(96,4.52,66),Vector3.new(-30,4.52,4)),
	Hub=Vector3.new(-30,4.12,4),
	-- Gameplay stations: front is local +Z before the yaw (stations.json).
	Stations=table.freeze({
		Eggs=CFrame.new(-31,4.1,-11)*CFrame.Angles(0,-.35,0),
		Journal=CFrame.new(-17,4.2,-15)*CFrame.Angles(0,-.5,0),
		Customize=CFrame.new(-46,4.2,-9)*CFrame.Angles(0,.45,0),
		ToyLawn=CFrame.new(-30,4.1,18.5),
		ArrivalDais=CFrame.new(96,4.05,66),
	}),
	-- Rest daises; Y is the measured walking surface + .025.
	Rest=table.freeze({
		CreekNook=Vector3.new(1,4.691,-33),
		SpringRestWest=Vector3.new(49.5,4.435,14),
		SpringRestEast=Vector3.new(54.5,4.435,14),
	}),
	-- The marble bridge: deck walking surface 4.34, crossing along X at Z 21.
	WalkableSpans=table.freeze({
		MainBridge=table.freeze({center=Vector3.new(2.5,4.235,21),size=Vector3.new(21,.21,4),crossing=true}),
	}),
	-- Player-only ground pets walk around: {center XZ, size XZ, yaw}.
	Blocked=table.freeze({
		table.freeze({name="Knoll",center=Vector2.new(-63,45),size=Vector2.new(38,44),yaw=0}),
		table.freeze({name="KnollStairs",center=Vector2.new(-46,31.5),size=Vector2.new(34,9),yaw=math.atan2(-25,-22)}),
	}),
	-- Extra wet footprints beside the generated stream/pool boxes.
	Wet=table.freeze({
		table.freeze({name="BubbleSpring",center=Vector2.new(52,3),size=Vector2.new(7,4.4),yaw=0}),
	}),
	Landmarks=table.freeze({Hub=Vector2.new(-30,4),Bridge=Vector2.new(2.5,21),Rotunda=Vector2.new(-60,50),Cave=Vector2.new(-7,-101),
		Arrival=Vector2.new(96,66),TumbleFalls=Vector2.new(77,-77),SkyFalls=Vector2.new(-6,64)}),
	Routes=table.freeze({
		-- Arrival dais -> bridge -> hub plaza, along the dirt path.
		ArrivalToHub=points({Vector2.new(96,66),Vector2.new(60,50),Vector2.new(32,29),Vector2.new(14,21),
			Vector2.new(-9,21),Vector2.new(-20,12),Vector2.new(-30,4)}),
	}),
	-- Lamp orb centres (the light sits in the orb). QA 2026-11-13: lamps 1 and 2 stood on the
	-- arrival path; they moved onto the grass at its edge (scripts/build_world_v7_chunks.py LAMP_MOVES).
	Lamps=points({Vector3.new(69.65,8.982,51.97),Vector3.new(29.44,8.986,29.85),Vector3.new(-9,9,23),Vector3.new(-12,9,-44),
		Vector3.new(-70,9,-3),Vector3.new(50,9,-10),Vector3.new(-22,9.2,38)}),
	LitLamps=table.freeze({[1]=true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true}),
}
-- Bare ground height (the lawn, not stations or architecture) from a 4-stud grid.
local G=Data.ground
function V7.groundY(x,z)
	local fx,fz=(x-G.x0)/G.step,(z-G.z0)/G.step
	local i,j=math.floor(fx),math.floor(fz)
	local function at(a,b)
		if a<0 or b<0 or a>=G.nx or b>=G.nz then return nil end
		local v=G.h[b*G.nx+a+1];return if v>-900 then v else nil
	end
	local h00,h10,h01,h11=at(i,j),at(i+1,j),at(i,j+1),at(i+1,j+1)
	local known={}
	for _,v in ipairs({h00,h10,h01,h11})do if v then table.insert(known,v)end end
	if #known==0 then return V7.FloorTop end
	if #known<4 then local s=0;for _,v in ipairs(known)do s+=v end;return s/#known end
	local u,v=fx-i,fz-j
	return h00*(1-u)*(1-v)+h10*u*(1-v)+h01*(1-u)*v+h11*u*v
end

local version=DEFAULT_VERSION
local ok,override=pcall(function()return game:GetService("ReplicatedStorage"):GetAttribute("WorldVersion")end)
if ok and(override=="legacy"or override=="v7")then version=override end
local Active=table.clone(if version=="v7"then V7 else Legacy)
Active.Legacy=table.freeze(Legacy)
Active.V7=table.freeze(V7)
return table.freeze(Active)
