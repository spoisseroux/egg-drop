-- Pet Park playground (BUILD-PLAN 2026-11-13, slice K1). Location A: the open lawn north of
-- Station_PicnicEast (34, 46), beside the arrival path. Everything below is placed from one
-- centre so the whole park moves together if the Studio raycast check asks for it.
--
-- Placement notes (from assets/world/world-v7-walk.json, the 1-stud walk surface):
--   * The scope's first guess, centre (45, 59), put a tree trunk (51.5, 55.5) inside the kerb.
--     The centre moved 8 studs to (45, 67): that trunk sits ~1.3 studs outside the kerb and the
--     west trunk (30, 59.5) ~2 studs outside. Both are canopy-only for pets (pets never collide).
--     With the centre at (36, 66) the west tree (30, 59.5) and two blossom shrubs fell inside the
--     kerb; they were removed from the world mesh (Spencer 2026-11-13, world-v7 declutter).
--   * No wet box or blocked region overlaps the park; the dirt path (walk tiles "P") is 20+
--     studs east, the Routes.ArrivalToHub centre-line ~15 studs south-east of the east kerb.
--   * Six flat flower decals (WorldDressing.Flowers) lie inside; equipment may cover them.
-- Ground heights use World.groundY (4-stud bare-ground grid, ~4.50-4.60 here). Every value
-- marked [RAYCAST in Studio] must be confirmed against the live lawn before K2 places art.
--
-- Frames: Roblox world studs, +Y up. A yaw is the heading of the pet/equipment front,
-- atan2(direction.X, direction.Z) (the same convention as GardenActivity). Pose positions
-- are the pet root's ground point (sole height) unless named seat/pivot/top.
local World=require(script.Parent.HollowWorldLayout)
local Park={}
Park.Enabled=World.WorldVersion=="v7"
Park.Version=1

local CX,CZ=36,66 -- Studio raycast sweep 2026-11-13: every anchor, the rim and a ring 2 studs outside it land on flat W7C ground (y 4.55); (45,67) clipped a collision hole at x 54-62, z 64-72, and (39,70) put the south-west gate on the trunk at (30,59.5)
local function ground(x,z)return World.groundY(x,z)+.025 end -- [RAYCAST in Studio]
local function at(dx,dz)return Vector3.new(CX+dx,ground(CX+dx,CZ+dz),CZ+dz)end
local function lift(position,height)return position+Vector3.new(0,height,0)end
local PI=math.pi
local EAST,WEST,NORTH,SOUTH=PI*.5,-PI*.5,0,PI -- yaw facing +X, -X, +Z, -Z

Park.Center=at(0,0)
-- Kerb ellipse radii (X, Z): 32 x 22 studs outside, ankle-high.
Park.Radius=Vector2.new(16,11)
Park.Kerb=table.freeze({height=.35,width=.6}) -- K2 art guide, not gameplay
-- Membership hysteresis: an owner joins 0.5 studs inside the kerb and leaves 1.5 studs outside.
Park.EnterInset=.5
Park.LeaveOutset=1.5
Park.WalkSpeed=4

-- Ellipse point at parametric angle theta (0 = +X, pi/2 = +Z).
local function rim(theta)return Vector3.new(CX+Park.Radius.X*math.cos(theta),0,CZ+Park.Radius.Y*math.sin(theta))end
local function gateway(id,theta,width)
	local point=rim(theta)
	local outward=Vector3.new(math.cos(theta)/Park.Radius.X,0,math.sin(theta)/Park.Radius.Y).Unit
	return table.freeze({id=id,angle=theta,width=width,position=Vector3.new(point.X,ground(point.X,point.Z),point.Z),
		yaw=math.atan2(-outward.X,-outward.Z)}) -- yaw faces into the park
end
-- Two open gaps in the kerb (no fence): east toward the arrival path, south-west toward the
-- picnic table and the hub. Star-orb posts stand at each side of the gap (K2).
Park.Gateways=table.freeze({
	gateway("east",-.26,4),      -- (51.5, 63.2) raycast-checked
	gateway("southwest",-2.09,4) -- (28.1, 56.4) raycast-checked
})

-- Equipment roots: K2 mounts each model at CFrame(position) * yaw. keepout is a pet-free radius
-- for mingle wandering (visual meshes are non-colliding; players get simple colliders).
local function equipment(id,position,yaw,keepout,extra)
	local entry={id=id,position=position,yaw=yaw,keepout=keepout}
	for key,value in pairs(extra or {})do entry[key]=value end
	return table.freeze(entry)
end
local swingCenter=at(-8,5)
local seesawCenter=at(1,7)
local slideBase=at(9,6)    -- top deck footprint (54, 73)
local slideEnd=at(9,-1.5)  -- chute foot on the lawn (54, 65.5)
local sandCenter=at(-10,-2)
local ballCenter=at(9,-6)   -- (45, 60): furthest east the kerb and the east gate allow; the blossom shrub that touched the mat's west edge (Studio 2026-11-13) is removed from the world mesh
Park.Equipment=table.freeze({
	-- Top bar along X, 5.6 high; two swings 2.8 apart swing along Z, facing the lawn (-Z).
	swing=equipment("swing",swingCenter,SOUTH,4,{barHeight=5.6,seatHeight=1.5}),
	-- Ladder at +Z, chute runs -Z to the lawn: top deck 3.6 high.
	slide=equipment("slide",slideBase,SOUTH,2,{deckHeight=3.6,chuteEnd=slideEnd}),
	-- Beam along X on a 1.1-high pivot; seats 2.6 each side.
	seesaw=equipment("seesaw",seesawCenter,NORTH,3.6,{pivotHeight=1.1,arm=2.6,maxTilt=.26}),
	-- 5 x 5 sand box with a 0.35 rim; sand top 0.25 above the lawn; one castle in the middle.
	sandbox=equipment("sandbox",sandCenter,NORTH,3.6,{size=Vector2.new(5,5),sandHeight=.25}),
	-- One ball on a small mat; two spots 4 studs apart along X.
	ball=equipment("ball",ballCenter,NORTH,3,{}),
})

-- Slots: one pet each. approach = the ground point the pet walks to and stays on during play
-- (the server path); yaw = the pet heading while playing; pose = the client pet root CFrame
-- parts (seat or play spot). Extra named points are ground points the play timeline moves to.
local function slot(id,equipmentId,approach,yaw,pose,extra)
	local entry={id=id,equipment=equipmentId,approach=approach,yaw=yaw,pose=table.freeze(pose)}
	for key,value in pairs(extra or {})do entry[key]=value end
	return table.freeze(entry)
end
local function swingSlot(id,dx)
	local base=Vector3.new(swingCenter.X+dx,ground(swingCenter.X+dx,swingCenter.Z),swingCenter.Z)
	return slot(id,"swing",base,SOUTH,{position=lift(base,1.5),yaw=SOUTH},
		{pivot=lift(base,5.6),rope=4.1,axis="X",amplitude=.5}) -- pendulum about the bar (X axis), arcs along Z
end
local function seesawSlot(id,side)
	local base=Vector3.new(seesawCenter.X+side*2.6,ground(seesawCenter.X+side*2.6,seesawCenter.Z),seesawCenter.Z)
	-- Seat 1 (west) faces east, seat 2 (east) faces west: the pets face each other.
	return slot(id,"seesaw",base,if side<0 then EAST else WEST,{position=lift(base,1.25),yaw=if side<0 then EAST else WEST},
		{pivot=lift(seesawCenter,1.1),arm=2.6*side})
end
local function sandSlot(id,side)
	local base=Vector3.new(sandCenter.X+side*1.6,ground(sandCenter.X+side*1.6,sandCenter.Z),sandCenter.Z)
	return slot(id,"sandbox",base,if side<0 then EAST else WEST,{position=lift(base,.25),yaw=if side<0 then EAST else WEST},
		{castle=lift(sandCenter,.25)})
end
local function ballSlot(id,side)
	local base=Vector3.new(ballCenter.X+side*2,ground(ballCenter.X+side*2,ballCenter.Z),ballCenter.Z)
	return slot(id,"ball",base,if side<0 then EAST else WEST,{position=base,yaw=if side<0 then EAST else WEST},
		{ball=lift(ballCenter,.45)}) -- ball rest centre (radius ~.45)
end
local ladder=Vector3.new(slideBase.X,ground(slideBase.X,slideBase.Z+1.2),slideBase.Z+1.2) -- ladder foot (54, 74.2)
Park.Slots=table.freeze({
	swing1=swingSlot("swing1",-1.4),
	swing2=swingSlot("swing2",1.4),
	-- The pet waits at the ladder foot (facing +Z, the ladder), climbs to the deck, sits at the
	-- chute top facing -Z, slides to chuteEnd, tumbles, and walks back for a second go.
	slide=slot("slide","slide",ladder,NORTH,{position=lift(slideBase,3.6),yaw=SOUTH},
		{ladderTop=lift(Vector3.new(ladder.X,ladder.Y,ladder.Z-.6),3.6),chuteTop=lift(slideBase+Vector3.new(0,0,-.8),3.6),chuteEnd=slideEnd}),
	seesaw1=seesawSlot("seesaw1",-1),
	seesaw2=seesawSlot("seesaw2",1),
	sand1=sandSlot("sand1",-1),
	sand2=sandSlot("sand2",1),
	ball1=ballSlot("ball1",-1),
	ball2=ballSlot("ball2",1),
})
Park.SlotOrder=table.freeze({"swing1","swing2","slide","seesaw1","seesaw2","sand1","sand2","ball1","ball2"})

-- Benches with Roblox Seats (K2). Inside the kerb so a seated owner keeps their pet in the park.
-- yaw faces the sitter toward the lawn. [RAYCAST in Studio]
Park.Benches=table.freeze({
	table.freeze({id="south",position=at(0,-8.4),yaw=NORTH,seats=2}),
	table.freeze({id="west",position=at(-13.2,3),yaw=EAST,seats=2}),
	table.freeze({id="northeast",position=at(13.5,3.5),yaw=WEST,seats=2}),
})

-- Pet-free circles for mingle targets: every equipment keepout plus each bench.
local keepout={}
for _,entry in pairs(Park.Equipment)do table.insert(keepout,table.freeze({center=Vector2.new(entry.position.X,entry.position.Z),radius=entry.keepout}))end
table.insert(keepout,table.freeze({center=Vector2.new(slideEnd.X,slideEnd.Z),radius=1.6}))
table.insert(keepout,table.freeze({center=Vector2.new(slideBase.X,(slideBase.Z+slideEnd.Z)*.5),radius=1.6}))
for _,bench in ipairs(Park.Benches)do table.insert(keepout,table.freeze({center=Vector2.new(bench.position.X,bench.position.Z),radius=1.8}))end
-- No tree keepout: the tree inside the kerb by the sandbox (trunk at (30, 59.5)) and the two pink blossom
-- shrubs inside the kerb were removed from the world mesh (Spencer 2026-11-13, scripts/build_world_v7_declutter.py).
table.sort(keepout,function(a,b)return if a.center.X==b.center.X then a.center.Y<b.center.Y else a.center.X<b.center.X end)
Park.Keepout=table.freeze(keepout)

-- Normalised ellipse radius of a point (1 = on the kerb centre-line), with the radii grown by
-- `outset` studs (negative shrinks). Approximate stud distance for small outsets.
function Park.normalized(position,outset)
	local rx,rz=Park.Radius.X+(outset or 0),Park.Radius.Y+(outset or 0)
	local dx,dz=(position.X-CX)/rx,(position.Z-CZ)/rz
	return math.sqrt(dx*dx+dz*dz)
end
function Park.inside(position,outset)return Park.normalized(position,outset)<=1 end
-- Owner membership with hysteresis: members stay until 1.5 studs outside; others join 0.5 inside.
function Park.member(position,wasMember)
	if typeof(position)~="Vector3"then return false end
	if wasMember then return Park.inside(position,Park.LeaveOutset)end
	return Park.inside(position,-Park.EnterInset)
end
-- The point at normalised radius `scale` on the ray from the centre through `position`.
function Park.toward(position,scale)
	local dx,dz=position.X-CX,position.Z-CZ
	local n=math.sqrt((dx/Park.Radius.X)^2+(dz/Park.Radius.Y)^2)
	if n<1e-6 then return Park.Center end
	local x,z=CX+dx/n*scale,CZ+dz/n*scale
	return Vector3.new(x,ground(x,z),z)
end
function Park.clearOfKeepout(position,margin)
	for _,zone in ipairs(Park.Keepout)do
		if Vector2.new(position.X-zone.center.X,position.Z-zone.center.Y).Magnitude<zone.radius+(margin or 0)then return false end
	end
	return true
end
function Park.ground(x,z)return ground(x,z)end
-- Client helper: pose CFrame (position + yaw).
function Park.cframe(position,yaw)return CFrame.new(position)*CFrame.Angles(0,yaw or 0,0)end

return table.freeze(Park)
