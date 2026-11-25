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
--
-- Site specs (WORLD-ALIVE-LOOK section 2, 2026-11-25). makeLayout(spec) builds one site from:
--   id, x, z            the membership centre (world studs)
--   rx, rz              ellipse radii (default 16 x 11, the arrival kerb)
--   gaps                {{id, angle, width, fixed?}}: openings on the rim at a parametric angle (0 = +X, pi/2 = +Z)
--   bench               {x, z}: the long bench, facing the centre
--   pieces              optional {swing|seesaw|slide|sandbox|ball = {x, z, yaw}}: each piece's root and the heading of
--                       its play side. Without it, the pieces stand in the arrival arrangement round the centre.
--   rotation            legacy: turn the whole site about its centre (the old grove; a `fixed` gap does not turn)
--   natural, dressing   the Hollow: no kerb, no star-orb posts, the dressing list instead (ParkMount)
--   floorY              the Top Lawn (WORLD-FINISH-LOOK section 1, slice B): flat ground at floorY (the terrace), and
--                       membership only standing up there (Y >= floorY - 4) while the gate is open (the server's:
--                       setTerraceGate, the TierPets gate; a client reads the switches the server publishes)
--   lawnDressing        the Top Lawn's list (patches under the pieces, gap stones, rim boulders, the flower drift)
-- Each piece moves as a rigid group about its own root: the root, its slots (approach, pose, seat, pivot, ladder,
-- chute, castle, ball points) and its keepout circle turn together. Nothing inside a piece changes (seat heights,
-- arcs, the chute's 7.5 run, SeatStepOut), so the pose data and choreography are untouched. ParkSites.spec pins the
-- arrival's numbers (and the old grove's) as they were before the specs.
local World=require(script.Parent.HollowWorldLayout)
local Flags=require(script.Parent.FeatureFlags)
local Tier=require(script.Parent.Tier)
local RunService=game:GetService("RunService")
-- The Top Lawn's membership gate. The server's is set by init.server (the TierPets gate). A client has none set: it reads
-- the switches the server publishes (code review: the client's ring and chip agree with the server's membership).
-- Specs (no client, no gate set): no gate.
local terraceGate=nil
local function gateOpen()
	if terraceGate~=nil then return terraceGate()==true end
	if RunService:IsClient()then
		return workspace:GetAttribute("CliffDen")==true and workspace:GetAttribute("Tier_on")==true
			and workspace:GetAttribute("TierPets_on")==true and workspace:GetAttribute("Catchup_on")==true
	end
	return true
end
-- The heading of each piece's play side in the arrival arrangement (see the equipment comments below): the swing's
-- seats, the slide's chute and the see-saw's waiting side face -Z; the sand box and ball corner are symmetric and
-- face +Z. A spec yaw is the same heading at the new site, so delta = yaw - Face.
local Face=table.freeze({swing=math.pi,slide=math.pi,seesaw=math.pi,sandbox=0,ball=0})
local Arrangement=table.freeze({36,66}) -- the arrival centre, where the arrangement was surveyed
local function makeLayout(spec)
local CX,CZ,siteId,rotation=spec.x,spec.z,spec.id,spec.rotation or 0
local Park={Id=siteId}
Park.Enabled=World.WorldVersion=="v7"
Park.Version=1

-- Original arrival centre (36,66). -- Studio raycast sweep 2026-11-13: every anchor, the rim and a ring 2 studs outside it land on flat W7C ground (y 4.55); (45,67) clipped a collision hole at x 54-62, z 64-72, and (39,70) put the south-west gate on the trunk at (30,59.5)
local function worldGround(x,z)return World.groundY(x,z)+.025 end -- [RAYCAST in Studio]
-- The site's ground: the lawn under the point, or a flat floor (the Top Lawn's terrace at spec.floorY).
local floorY=spec.floorY
local function ground(x,z)if floorY then return floorY+.025 end return worldGround(x,z)end
local function at(dx,dz)return Vector3.new(CX+dx,ground(CX+dx,CZ+dz),CZ+dz)end
-- The pieces are authored round a centre: this site's, or for a site with `pieces` the arrival lawn (Arrangement),
-- where every point's height over the ground is the arrival's; each piece then moves to its place as a rigid group.
local BX,BZ=if spec.pieces then Arrangement[1]else CX,if spec.pieces then Arrangement[2]else CZ
-- The arrangement's own ground: the arrival lawn's for a site with `pieces` (then re-grounded at the site), else the site's.
local aground=if spec.pieces then worldGround else ground
local function piece(dx,dz)return Vector3.new(BX+dx,aground(BX+dx,BZ+dz),BZ+dz)end
local function lift(position,height)return position+Vector3.new(0,height,0)end
local PI=math.pi
local EAST,WEST,NORTH,SOUTH=PI*.5,-PI*.5,0,PI -- yaw facing +X, -X, +Z, -Z

Park.Center=at(0,0)
if floorY then Park.FloorY=floorY;Park.Terrace=true end
-- Kerb ellipse radii (X, Z): 32 x 22 studs outside, ankle-high. A natural site keeps the radii (membership) but no kerb.
Park.Radius=Vector2.new(spec.rx or 16,spec.rz or 11)
if spec.natural then Park.Natural=true else Park.Kerb=table.freeze({height=.35,width=.6})end -- K2 art guide, not gameplay
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
-- Arrival: east (51.5, 63.2) and southwest (28.1, 56.4), raycast-checked.
do
	local gates={}
	for _,gap in ipairs(spec.gaps)do table.insert(gates,gateway(gap[1],gap[2],gap[3]))end
	Park.Gateways=table.freeze(gates)
end

-- Equipment roots: K2 mounts each model at CFrame(position) * yaw. keepout is a pet-free radius
-- for mingle wandering (visual meshes are non-colliding; players get simple colliders).
local function equipment(id,position,yaw,keepout,extra)
	local entry={id=id,position=position,yaw=yaw,keepout=keepout}
	for key,value in pairs(extra or {})do entry[key]=value end
	return table.freeze(entry)
end
local swingCenter=piece(-8,5)
local seesawCenter=piece(1,7)
local slideBase=piece(9,6)    -- top deck footprint (54, 73)
local slideEnd=piece(9,-1.5)  -- chute foot on the lawn (54, 65.5)
local sandCenter=piece(-10,-2)
local ballCenter=piece(9,-6)   -- (45, 60): furthest east the kerb and the east gate allow; the blossom shrub that touched the mat's west edge (Studio 2026-11-13) is removed from the world mesh
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
-- QA Q4: riders wait IN FRONT of a seat (the hop-off landing point), so a pet hops back onto the
-- seat, rides, hops forward and lands where it started, instead of landing in front and walking back.
Park.SeatStepOut=1.25
local function swingSlot(id,dx)
	local base=Vector3.new(swingCenter.X+dx,aground(swingCenter.X+dx,swingCenter.Z),swingCenter.Z)
	-- Seats face the swing set's front (-Z, toward the lawn); the pet waits 1.25 studs in front.
	local x,z=base.X,base.Z-Park.SeatStepOut
	local approach=Vector3.new(x,aground(x,z),z)
	return slot(id,"swing",approach,SOUTH,{position=lift(base,1.5),yaw=SOUTH},
		{seatGround=base,pivot=lift(base,5.6),rope=4.1,axis="X",amplitude=.5}) -- pendulum about the bar (X axis), arcs along Z
end
local function seesawSlot(id,side)
	local base=Vector3.new(seesawCenter.X+side*2.6,aground(seesawCenter.X+side*2.6,seesawCenter.Z),seesawCenter.Z)
	-- Seat 1 (west) faces east, seat 2 (east) faces west: the pets face each other. Each waits off
	-- the beam's park-centre side (-Z) beside its own seat.
	local x,z=base.X,base.Z-Park.SeatStepOut
	local approach=Vector3.new(x,aground(x,z),z)
	return slot(id,"seesaw",approach,if side<0 then EAST else WEST,{position=lift(base,1.25),yaw=if side<0 then EAST else WEST},
		{seatGround=base,pivot=lift(seesawCenter,1.1),arm=2.6*side})
end
local function sandSlot(id,side)
	local base=Vector3.new(sandCenter.X+side*1.6,aground(sandCenter.X+side*1.6,sandCenter.Z),sandCenter.Z)
	return slot(id,"sandbox",base,if side<0 then EAST else WEST,{position=lift(base,.25),yaw=if side<0 then EAST else WEST},
		{castle=lift(sandCenter,.25)})
end
local function ballSlot(id,side)
	local base=Vector3.new(ballCenter.X+side*2,aground(ballCenter.X+side*2,ballCenter.Z),ballCenter.Z)
	return slot(id,"ball",base,if side<0 then EAST else WEST,{position=base,yaw=if side<0 then EAST else WEST},
		{ball=lift(ballCenter,.45)}) -- ball rest centre (radius ~.45)
end
local ladder=Vector3.new(slideBase.X,aground(slideBase.X,slideBase.Z+1.2),slideBase.Z+1.2) -- ladder foot (54, 74.2)
Park.Slots=table.freeze({
	swing1=swingSlot("swing1",-1.4),
	swing2=swingSlot("swing2",1.4),
	-- The pet waits at the ladder foot facing the ladder and the deck (-Z; QA Q4: was +Z, away from
	-- it), climbs to the deck, sits at the chute top facing -Z, slides to chuteEnd, tumbles, and
	-- walks back for a second go.
	slide=slot("slide","slide",ladder,SOUTH,{position=lift(slideBase,3.6),yaw=SOUTH},
		{ladderTop=lift(Vector3.new(ladder.X,ladder.Y,ladder.Z-.6),3.6),chuteTop=lift(slideBase+Vector3.new(0,0,-.8),3.6),chuteEnd=slideEnd}),
	seesaw1=seesawSlot("seesaw1",-1),
	seesaw2=seesawSlot("seesaw2",1),
	sand1=sandSlot("sand1",-1),
	sand2=sandSlot("sand2",1),
	ball1=ballSlot("ball1",-1),
	ball2=ballSlot("ball2",1),
})
Park.SlotOrder=table.freeze({"swing1","swing2","slide","seesaw1","seesaw2","sand1","sand2","ball1","ball2"})

-- Per-piece placement (a site spec with `pieces`): each piece is a rigid group turned by delta = yaw - Face about its
-- own root and set down at (x, z). Heights are re-grounded: a point keeps its height above the ground under it.
if spec.pieces then
	local equipment,slots={},{}
	for id,entry in pairs(Park.Equipment)do
		local place=spec.pieces[id]
		assert(place,"site "..siteId.." has no place for "..id)
		local root=entry.position
		local delta=place[3]-Face[id]
		local c,s=math.cos(delta),math.sin(delta)
		local function moved(value,key)
			if typeof(value)=="Vector3"then
				local dx,dz=value.X-root.X,value.Z-root.Z
				local x,z=place[1]+dx*c+dz*s,place[2]-dx*s+dz*c
				return Vector3.new(x,ground(x,z)+value.Y-aground(value.X,value.Z),z)
			elseif type(value)=="number"and key=="yaw"then return value+delta
			elseif type(value)=="table"then
				local result={};for k,v in pairs(value)do result[k]=moved(v,k)end;return table.freeze(result)
			end
			return value
		end
		equipment[id]=moved(entry)
		for slotId,slot in pairs(Park.Slots)do if slot.equipment==id then slots[slotId]=moved(slot)end end
	end
	Park.Equipment=table.freeze(equipment)
	Park.Slots=table.freeze(slots)
end

-- Benches with Roblox Seats (K2). Inside the kerb so a seated owner keeps their pet in the park.
-- yaw faces the sitter toward the playground centre. [RAYCAST in Studio]
-- QA Q4 (Spencer 2026-11-13): ONE bench, the one beside the player in the QA shot (south side,
-- between the two gateways, where the arrival walk enters), lengthened to five seats
-- (Park_BenchLong, 9.57 studs). It is the only spot inside the kerb where a 9.6-stud bench clears
-- the kerb, the gateways and every equipment keepout (the east-gate lawn is taken by the slide
-- and the ball mat). The west and northeast benches are gone.
local function facingCenter(position)return math.atan2(CX-position.X,CZ-position.Z)end
-- Arrival: at (.5, -8.4) from the centre (the spec writes 36 + .5, 66 - 8.4, the same doubles).
local entranceBench=Vector3.new(spec.bench[1],ground(spec.bench[1],spec.bench[2]),spec.bench[2])
Park.Benches=table.freeze({
	table.freeze({id="entrance",position=entranceBench,yaw=facingCenter(entranceBench),seats=5,mesh="Park_BenchLong",length=9.57}),
})

-- Pet-free circles for mingle targets: every equipment keepout plus each bench.
local keepout={}
for _,entry in pairs(Park.Equipment)do table.insert(keepout,table.freeze({center=Vector2.new(entry.position.X,entry.position.Z),radius=entry.keepout}))end
do
	-- The chute's foot and its middle (from the placed slide; the arrival's deck and foot share X).
	local base,foot=Park.Equipment.slide.position,Park.Equipment.slide.chuteEnd
	table.insert(keepout,table.freeze({center=Vector2.new(foot.X,foot.Z),radius=1.6}))
	table.insert(keepout,table.freeze({center=Vector2.new((base.X+foot.X)*.5,(base.Z+foot.Z)*.5),radius=1.6}))
end
for _,bench in ipairs(Park.Benches)do
	-- A circle every ~3 studs along the bench's length (the long bench is 9.6 studs).
	local along=Vector2.new(math.cos(bench.yaw),-math.sin(bench.yaw)) -- the bench's +X axis on the ground
	local reach=math.max(0,((bench.length or 4.5)-3.6)*.5)
	local count=math.max(1,math.ceil(reach*2/3)+1)
	for i=0,count-1 do
		local u=if count==1 then 0 else -reach+reach*2*i/(count-1)
		table.insert(keepout,table.freeze({center=Vector2.new(bench.position.X,bench.position.Z)+along*u,radius=1.8}))
	end
end
-- No tree keepout: the tree inside the kerb by the sandbox (trunk at (30, 59.5)) and the two pink blossom
-- shrubs inside the kerb were removed from the world mesh (Spencer 2026-11-13, scripts/build_world_v7_declutter.py).

-- The Hollow's dressing in place of a kerb (WORLD-ALIVE-LOOK section 2, "What you see instead of a kerb"). Pure data;
-- ParkMount builds it (parts and decal plates only). Every y is the lawn top under the point (HollowWorldLayout, the
-- exported grid: probe_park_hollow.luau sweeps the real ground in Studio). The stones, stumps and log keep pets off them
-- (their keepout circles carry dressing = true).
if spec.dressing then
	local D=spec.dressing
	local PX,PZ=D.palm[1],D.palm[2]
	local function lawn(x,z)return World.groundY(x,z)end
	local function heading(x,z,tx,tz)return math.atan2(tx-x,tz-z)end
	-- A point in a placed piece's own frame: +Z its play-side heading, +X to its right.
	local function pieceLocal(id,lx,lz)
		local root,h=Park.Equipment[id].position,spec.pieces[id][3]
		return root.X+lx*math.cos(h)+lz*math.sin(h),root.Z-lx*math.sin(h)+lz*math.cos(h)
	end
	local function rimPoint(angle,r)return CX+r*math.cos(angle),CZ+r*math.sin(angle)end
	local plates,stones,stumps,flowers={},{},{},{}
	local function plate(name,x,z,sx,sz,yaw,art,colour,transparency)
		table.insert(plates,table.freeze({name=name,x=x,y=lawn(x,z),z=z,size=Vector2.new(sx,sz),yaw=yaw,art=art,
			colour=colour,transparency=transparency,lift=.04}))
	end
	-- Toe patches: 6.5 long (pointing at the palm) x 5.5, worn earth; the dig spot's is sand. The slide's sits 1.5 down
	-- the chute so it covers the deck and the top of the run.
	for _,toe in ipairs({{"seesaw",0,0},{"slide",0,1.5},{"sandbox",0,0},{"swing",0,0}})do
		local x,z=pieceLocal(toe[1],toe[2],toe[3])
		local sand=toe[1]=="sandbox"
		plate("HollowToe_"..toe[1],x,z,5.5,6.5,heading(x,z,PX,PZ),"lawnPatchA",if sand then "#D9C29A"else "#9A7B55",.30)
	end
	-- The palm: three overlapping clover plates, the big one on P and two along the cliff line.
	local along=D.cliffLine -- unit (x, z) along the cliff foot
	local palmYaw=math.atan2(along[1],along[2])
	plate("HollowPalm",PX,PZ,8,9,palmYaw,"lawnPatchB","#6FA85A",.45)
	for _,side in ipairs({-1,1})do
		plate("HollowPalm",PX+side*3.5*along[1],PZ+side*3.5*along[2],5,6,palmYaw,"lawnPatchB","#6FA85A",.45)
	end
	-- Stones (the stone builder, section 4): size = (across, height, depth); yaw turns the stone's across axis.
	local GREYS={"#8A8580","#7F847F","#948E84"}
	local function stone(name,x,z,size,yaw,seed,keep)
		table.insert(stones,table.freeze({name=name,x=x,y=lawn(x,z),z=z,size=size,yaw=yaw,seed=seed,colour=GREYS[seed%3+1]}))
		if keep then table.insert(keepout,table.freeze({center=Vector2.new(x,z),radius=size.X*.5+.4,dressing=true}))end
	end
	-- Gap stones: one each side of each gap, their inner faces the gap's width apart; standing, across the rim.
	for g,gap in ipairs(spec.gaps)do
		for k,side in ipairs({-1,1})do
			local angle=gap[2]+side*(gap[3]*.5+.6)/((Park.Radius.X+Park.Radius.Y)*.5)
			local x,z=rimPoint(angle,Park.Radius.X)
			local seed=20261125+g*10+k
			stone("HollowGapStone",x,z,Vector3.new(1.2,1.8,1.0),heading(x,z,CX,CZ)+(k-1.5)*.3,seed,true)
		end
	end
	-- Rim boulders on the east rim between the stumps and the cliff, 2.4 down to .9 across.
	for k,row in ipairs(D.rimBoulders)do
		local x,z=rimPoint(row[1],row[2])
		stone("HollowRimBoulder",x,z,Vector3.new(row[3],row[3]*.55,row[3]*.85),row[1]*1.7+k,20261140+k,true)
	end
	-- Three round the slide's deck, on the cliff side, clear of the ladder foot (local (0, -1.2)).
	for k,row in ipairs(D.deckBoulders)do
		local x,z=pieceLocal("slide",row[1],row[2])
		stone("HollowDeckBoulder",x,z,Vector3.new(row[3],row[3]*.6,row[3]*.85),k*1.3,20261150+k,true)
	end
	-- The stump circle by the path gap.
	do
		local cx,cz=D.stumps[1],D.stumps[2]
		for k,row in ipairs({{.3,.7},{2.4,.9},{4.4,.8}})do
			local x,z=cx+1.1*math.cos(row[1]),cz+1.1*math.sin(row[1])
			table.insert(stumps,table.freeze({x=x,y=lawn(x,z),z=z,diameter=1.2,height=row[2]}))
		end
		table.insert(keepout,table.freeze({center=Vector2.new(cx,cz),radius=2.2,dressing=true}))
	end
	-- The fallen log along the rim: 9 long, 1.4 across, sunk .25; `heading` is the direction of its length.
	local log
	do
		local x,z=D.log[1],D.log[2]
		local h=math.atan2(-(z-CZ),x-CX) -- the rim tangent at the log
		log=table.freeze({x=x,y=lawn(x,z),z=z,length=9,diameter=1.4,sink=.25,heading=h,colour="#6B4E37",cap="#B79A72"})
		for k=-2,2 do
			local s=k*1.8
			table.insert(keepout,table.freeze({center=Vector2.new(x+s*math.sin(h),z+s*math.cos(h)),radius=1.2,dressing=true}))
		end
	end
	-- Flower drift: eight flat flower plates behind the bench, 16 studs along the rim.
	do
		local bench=spec.bench
		local mid=math.atan2(bench[2]-CZ,bench[1]-CX)
		local r=(Park.Radius.X+Park.Radius.Y)*.5
		for k=0,7 do
			local angle=mid+(k-3.5)*(16/7)/r
			local x,z=rimPoint(angle,r-1.4+(k%2)*.8)
			table.insert(flowers,table.freeze({x=x,y=lawn(x,z),z=z,size=2.4+(k%3)*.4,yaw=k*.9,kind=k%5+1}))
		end
	end
	-- The fallen column, half buried along the dig spot's cliff side: marble, leaned 20 degrees, 60% under the sand.
	local column
	do
		local x,z=pieceLocal("sandbox",-.35,-2.25)
		local sand=Park.Equipment.sandbox.position.Y+Park.Equipment.sandbox.sandHeight
		column=table.freeze({x=x,y=sand+.8-.6*1.6,z=z,length=3.2,diameter=1.6,heading=spec.pieces.sandbox[3]+math.pi*.5,
			lean=math.rad(20),colour="#B2B1B3",band="#B8913A",bandWidth=.2,sand=sand})
	end
	Park.Dressing=table.freeze({plates=table.freeze(plates),stones=table.freeze(stones),stumps=table.freeze(stumps),
		flowers=table.freeze(flowers),log=log,column=column,palm=Vector3.new(PX,lawn(PX,PZ),PZ)})
end
-- The Top Lawn's dressing (WORLD-FINISH-LOOK section 1, "Reused dressing"): the same builders and colours as the Hollow,
-- on the terrace's flat floor. Five worn patches under the pieces (earth, the dig spot's sand, the ball's palm green),
-- two gap stones a gap, three rim boulders by the dig spot, the eight-plate flower drift behind the bench. No log,
-- stumps or column (they stay below, in the Paw Glade).
if spec.lawnDressing then
	local D=spec.lawnDressing
	local y=floorY or World.groundY(CX,CZ)
	local function heading(x,z,tx,tz)return math.atan2(tx-x,tz-z)end
	local function pieceLocal(id,lx,lz)
		local root,h=Park.Equipment[id].position,spec.pieces[id][3]
		return root.X+lx*math.cos(h)+lz*math.sin(h),root.Z-lx*math.sin(h)+lz*math.cos(h)
	end
	local function rimPoint(angle,r)return CX+r*math.cos(angle),CZ+r*math.sin(angle)end
	local plates,stones,flowers={},{},{}
	local function plate(name,x,z,sx,sz,yaw,art,colour,transparency)
		table.insert(plates,table.freeze({name=name,x=x,y=y,z=z,size=Vector2.new(sx,sz),yaw=yaw,art=art,
			colour=colour,transparency=transparency,lift=.04}))
	end
	for _,toe in ipairs({{"seesaw",0,0,"#9A7B55"},{"slide",0,1.5,"#9A7B55"},{"swing",0,0,"#9A7B55"},{"sandbox",0,0,"#D9C29A"}})do
		local x,z=pieceLocal(toe[1],toe[2],toe[3])
		plate("TopLawnPatch_"..toe[1],x,z,5.5,6.5,heading(x,z,CX,CZ),"lawnPatchA",toe[4],.30)
	end
	do
		local ball=Park.Equipment.ball.position
		plate("TopLawnPatch_ball",ball.X,ball.Z,6.5,6.5,heading(ball.X,ball.Z,CX,CZ),"lawnPatchB","#6FA85A",.45)
	end
	local GREYS={"#8A8580","#7F847F","#948E84"}
	local function stone(name,x,z,size,yaw,seed)
		table.insert(stones,table.freeze({name=name,x=x,y=y,z=z,size=size,yaw=yaw,seed=seed,colour=GREYS[seed%3+1]}))
		table.insert(keepout,table.freeze({center=Vector2.new(x,z),radius=size.X*.5+.4,dressing=true}))
	end
	for g,gap in ipairs(spec.gaps)do
		for k,side in ipairs({-1,1})do
			local angle=gap[2]+side*(gap[3]*.5+.6)/Park.Radius.X
			local x,z=rimPoint(angle,Park.Radius.X)
			stone("TopLawnGapStone",x,z,Vector3.new(1.2,1.8,1.0),heading(x,z,CX,CZ)+(k-1.5)*.3,20261126+g*10+k)
		end
	end
	-- Rim boulders on the rim behind the dig spot: {angle off the dig spot's own rim angle, radius, across}.
	do
		local sand=Park.Equipment.sandbox.position
		local base=math.atan2(sand.Z-CZ,sand.X-CX)
		for k,row in ipairs(D.rimBoulders)do
			local x,z=rimPoint(base+row[1],row[2])
			stone("TopLawnRimBoulder",x,z,Vector3.new(row[3],row[3]*.55,row[3]*.85),base*1.7+k,20261160+k)
		end
	end
	-- The flower drift: eight plates over 16 studs, just behind the bench (its distance from the centre + driftOut).
	do
		local bench=spec.bench
		local mid=math.atan2(bench[2]-CZ,bench[1]-CX)
		local r=math.sqrt((bench[1]-CX)^2+(bench[2]-CZ)^2)+D.driftOut
		for k=0,7 do
			local angle=mid+(k-3.5)*(16/7)/r
			local x,z=rimPoint(angle,r-.4+(k%2)*.8)
			table.insert(flowers,table.freeze({x=x,y=y,z=z,size=2.4+(k%3)*.4,yaw=k*.9,kind=k%5+1}))
		end
	end
	Park.Dressing=table.freeze({plates=table.freeze(plates),stones=table.freeze(stones),stumps=table.freeze({}),
		flowers=table.freeze(flowers),palm=Vector3.new(CX,y,CZ)})
end
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
	-- The Top Lawn: only standing up there, and only while the server's gate is open.
	if floorY and(position.Y<floorY-4 or not gateOpen())then return false end
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

if rotation~=0 then
	local function moved(value,key)
		if typeof(value)=="Vector3"then
			local dx,dz=value.X-CX,value.Z-CZ
			local x,z=CX+dx*math.cos(rotation)+dz*math.sin(rotation),CZ-dx*math.sin(rotation)+dz*math.cos(rotation)
			return Vector3.new(x,ground(x,z)+value.Y-ground(value.X,value.Z),z)
		elseif typeof(value)=="Vector2"and key=="center"then
			local dx,dz=value.X-CX,value.Y-CZ
			return Vector2.new(CX+dx*math.cos(rotation)+dz*math.sin(rotation),CZ-dx*math.sin(rotation)+dz*math.cos(rotation))
		elseif type(value)=="number"and(key=="yaw"or key=="angle")then return value+rotation
		elseif type(value)=="table"then
			local result={};for k,v in pairs(value)do result[k]=moved(v,k)end;return table.freeze(result)
		end
		return value
	end
	for key,value in pairs(Park)do Park[key]=moved(value,key)end
	-- Choreography/bench rotate toward the hub, while the primary gateway still
	-- opens east onto the measured through-path (a `fixed` gap). Kerb derives from these actual gaps.
	local gates={}
	for index,gap in ipairs(spec.gaps)do gates[index]=if gap.fixed then gateway(gap[1],gap[2],gap[3])else Park.Gateways[index]end
	Park.Gateways=table.freeze(gates)
end
return Park
end

-- Site specs -------------------------------------------------------------------------------------------------------
local Specs={}
-- Location A by the arrival path. Positions as surveyed 2026-11-13 (see the notes at the top).
Specs.arrival=table.freeze({id="arrival",x=36,z=66,rx=16,rz=11,
	gaps=table.freeze({table.freeze({"east",-.26,4}),table.freeze({"southwest",-2.09,4})}),
	bench=table.freeze({36+.5,66-8.4})})
-- The old grove park (2026-11-14): the arrival park turned half a circle on the lawn at (-38, -46). Development site
-- surveyed against precise world ground 2026-11-14; never infer clearances from the exported grid. Live keeps it.
Specs.grove=table.freeze({id="grove",x=-38,z=-46,rx=16,rz=11,rotation=math.pi,
	gaps=table.freeze({table.freeze({"east",-.26,4,fixed=true}),table.freeze({"southwest",-2.09,4})}),
	bench=table.freeze({-38+.5,-46-8.4})})
-- The Hollow (Fable, WORLD-ALIVE-LOOK section 2): a round glade backed toward the cliff, no kerb. The four toes fan
-- round the palm P toward the cliff so that from the cliff path above the worn patches read as a paw print. Same site
-- id as the old grove (sessions, snapshots, the client), so only the look and the numbers change.
-- Re-laid 2026-11-25 (Studio R13/R14): the cliff path pack (CliffDenData: treads, lip, back wall, cliff_rock_1818) runs
-- 3 to 4 studs further onto this lawn than the surface map's cliff foot, over Fable's south rim and the swing and dig
-- spot. The circle shrank 14 -> 12 and moved 3.6 studs out from the path (its rim 3 studs off the path's base, measured
-- by a Studio top-down ray sweep with the pack in); the fan keeps Fable's order and headings round P, 9.2 studs out and
-- about 52 degrees apart (36 no longer fits r 12). Every number checked by probe_park_hollow.luau with the pack in.
Specs.hollow=table.freeze({id="grove",x=-39.8,z=-47.7,rx=12,rz=12,natural=true,
	gaps=table.freeze({table.freeze({"path",-.37,4}),table.freeze({"plaza",2.09,4})}),
	bench=table.freeze({-34.15,-40.55}),
	pieces=table.freeze({
		seesaw=table.freeze({-32.3,-54.1,-.75}),   -- toe 1: beam across the fan, riders wait on the palm side
		slide=table.freeze({-39.85,-56.45,.15}),   -- toe 2: deck; ladder foot toward the cliff, the chute lands in the palm
		sandbox=table.freeze({-46.45,-51.95,1.05}),-- toe 3: the dig spot, nearest the cliff
		swing=table.freeze({-47.0,-44.0,1.95}),    -- toe 4: seats face the palm
		ball=table.freeze({-34.75,-45.8,.6}),      -- in the palm's east half
	}),
	dressing=table.freeze({
		palm=table.freeze({-38.5,-47.4}),
		-- The cliff path's base runs (-69, -45) to (-31, -70): its direction, for the palm plates.
		cliffLine=table.freeze({-38/math.sqrt(38*38+25*25),25/math.sqrt(38*38+25*25)}),
		-- {rim angle, radius from C, across}: on the south-east rim between the stump circle and the slide, off the path.
		rimBoulders=table.freeze({{-1.02,12.6,2.4},{-1.14,12.9,1.9},{-1.26,12.5,1.5},{-1.37,12.8,1.2},{-1.47,12.4,.9}}),
		-- {local x, local z, across} in the slide's frame (+Z down the chute): behind the deck, off the ladder line.
		deckBoulders=table.freeze({{-1.7,-2.5,1.6},{1.6,-2.8,1.3},{-2.4,-.3,1.0}}),
		stumps=table.freeze({-29.4,-57.6}),        -- just past the south-east rim, by the see-saw (the east gap is full)
		log=table.freeze({-50.4,-41.4}),           -- along the west rim
	}),
})
-- The Top Lawn (Fable, WORLD-FINISH-LOOK section 1): the second park on the terrace, in the terrace's frame (Tier.T(s, t):
-- s along the ridge, t toward the garden, the lip at t 22). Same five pieces, nine slots and site id as the Hollow (the
-- grove: sessions, snapshots and the client unchanged); natural (no kerb, no star orbs); flat at Tier.FloorY. The circle
-- K (0, 5) r 13: its rim 4 studs inside the garden lip, so every slot approach keeps 3+ inside the terrace. The tall
-- pieces stand on the lip side so they show on the skyline from the Hub. Yaws (the heading of each piece's play side,
-- Opus from "faces K", 2026-11-25): swing seats face K; the slide's chute runs toward K (lands about (0.2, 6.5));
-- the see-saw's beam lies along the lip with its riders on K's side (-t); the dig spot and the ball face K. The bench
-- (Fable's (0, -7)) is nudged 1 stud toward K to (0, -6) so both its ends sit inside the circle less 1.
do
	local K=Tier.T(0,5)
	local function at(s,t)local p=Tier.T(s,t);return p.X,p.Z end
	local function faces(s,t)local x,z=at(s,t);return math.atan2(K.X-x,K.Z-z)end
	local function rimAngle(s,t)local x,z=at(s,t);return math.atan2(z-K.Z,x-K.X)end
	local function place(s,t,yaw)local x,z=at(s,t);return table.freeze({x,z,yaw})end
	local inward=math.atan2(-Tier.N.X,-Tier.N.Y) -- -t: from the lip toward K
	Specs.topLawn=table.freeze({id="grove",x=K.X,z=K.Z,rx=13,rz=13,natural=true,floorY=Tier.FloorY,
		gaps=table.freeze({table.freeze({"path",rimAngle(13,4),4}),table.freeze({"lookout",rimAngle(-13,5),4})}),
		bench=table.freeze({at(0,-6)}),
		pieces=table.freeze({
			swing=place(-7,12,faces(-7,12)),     -- the bar across the view, seats face K; tallest, nearest the lip
			slide=place(1,14,faces(1,14)),       -- the deck; ladder on the lip side, the chute runs toward K
			seesaw=place(8,11.5,inward),         -- the beam along the lip; pets face each other, riders wait on K's side
			sandbox=place(-9,0,faces(-9,0)),     -- the dig spot, outer side, beside the rim boulders
			ball=place(6,0,faces(6,0)),          -- the open middle; fetch throws go along s
		}),
		-- {angle off the dig spot's rim angle, radius from K, across}: three boulders, the biggest straight behind it.
		lawnDressing=table.freeze({rimBoulders=table.freeze({{0,13.6,2.0},{.14,13.4,1.5},{-.13,13.4,1.1}}),driftOut=1.6}),
	})
end
-- The Hollow is a place gate (FeatureFlags.ParkHollow): the beta place or Studio. Read once at require time on both
-- sides, so the server and every client of one place agree. Live (and the flag off) keeps the old grove exactly.
local HollowPlaceId=107705084891479 -- Pocket Pals Beta
local function hollowOn(env)
	env=env or {}
	if(env.flags or Flags).ParkHollow~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==HollowPlaceId or studio==true
end
-- The Top Lawn is a place gate too (FeatureFlags.ParkTopLawn, WORLD-FINISH-LOOK slice B): the beta place or Studio. It
-- wins over the Hollow; off, the Hollow (or the old grove) exactly as before.
local function topLawnOn(env)
	env=env or {}
	if(env.flags or Flags).ParkTopLawn~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==HollowPlaceId or studio==true
end

-- The Paw Glade (WORLD-FINISH-LOOK section 1): the Hollow's spot once the park has moved up. Its equipment, ball mat,
-- earth patches and circle go; the fallen log (a player collider), the stump circle, the half-buried column, the rim
-- boulders and the flower drift stay where they were; the four toe plates turn to clover (lawn-patch-b #7FB069 at
-- .35) with three flower plates each, the palm stays clover, so from shelf 2 it still reads as a paw; a second long
-- bench at the Hollow's bench spot, turned to look up at the path (mid shelf 2, PathView). No prompts, no park logic.
-- Pure data from the Hollow's own layout; ParkMount builds it (ParkHollowMount.buildGlade).
local PathView=Vector2.new(-53,-61.8) -- CliffDenData's centre line mid shelf 2 (u about 45), fixed: no data read here
local function glade(H)
	local D=H.Dressing
	local plates,flowers,stones={}, {}, {}
	local toes={}
	for _,row in ipairs(D.plates)do
		if string.find(row.name,"^HollowToe_")then
			table.insert(plates,table.freeze({name=string.gsub(row.name,"^HollowToe_","GladeToe_"),x=row.x,y=row.y,z=row.z,
				size=row.size,yaw=row.yaw,art="lawnPatchB",colour="#7FB069",transparency=.35,lift=row.lift}))
			table.insert(toes,row)
		else
			table.insert(plates,table.freeze({name=string.gsub(row.name,"^Hollow","Glade"),x=row.x,y=row.y,z=row.z,
				size=row.size,yaw=row.yaw,art=row.art,colour=row.colour,transparency=row.transparency,lift=row.lift}))
		end
	end
	for _,row in ipairs(D.flowers)do table.insert(flowers,row)end
	-- Three flower plates on each toe, along its length (a toe's length runs along its yaw).
	for t,toe in ipairs(toes)do
		local ax,az=math.sin(toe.yaw),math.cos(toe.yaw)
		for k,along in ipairs({-1.8,0,1.8})do
			local side=(k-2)*.4
			local x,z=toe.x+ax*along+az*side,toe.z+az*along-ax*side
			table.insert(flowers,table.freeze({x=x,y=World.groundY(x,z),z=z,size=2+(k%2)*.4,yaw=t*1.3+k*.8,kind=(t+k)%5+1}))
		end
	end
	for _,row in ipairs(D.stones)do
		if row.name=="HollowRimBoulder"then table.insert(stones,row)end
	end
	local bench=H.Benches[1]
	local position=bench.position
	return table.freeze({
		plates=table.freeze(plates),flowers=table.freeze(flowers),stones=table.freeze(stones),
		-- The column lay 60% under the dig spot's sand (its height over the lawn): with the sand gone it sinks by that much.
		stumps=D.stumps,log=D.log,palm=D.palm,center=H.Center,
		column=table.freeze({x=D.column.x,y=D.column.y-H.Equipment.sandbox.sandHeight,z=D.column.z,length=D.column.length,
			diameter=D.column.diameter,heading=D.column.heading,lean=D.column.lean,colour=D.column.colour,band=D.column.band,
			bandWidth=D.column.bandWidth,sand=D.column.sand-H.Equipment.sandbox.sandHeight}),
		bench=table.freeze({id="glade",position=position,yaw=math.atan2(PathView.X-position.X,PathView.Y-position.Z),
			seats=bench.seats,mesh=bench.mesh,length=bench.length}),
	})
end

local arrival=makeLayout(Specs.arrival)
local HollowOn=hollowOn()
local TopLawnOn=topLawnOn()
local grove=makeLayout(if TopLawnOn then Specs.topLawn elseif HollowOn then Specs.hollow else Specs.grove)
local sites=table.freeze({arrival,grove})
local byId=table.freeze({arrival=arrival,grove=grove})
arrival.Sites=sites;arrival.ById=byId
arrival.Specs=table.freeze(Specs)
arrival.HollowOn=HollowOn
arrival.HollowPlaceId=HollowPlaceId
arrival.hollowOn=hollowOn
arrival.TopLawnOn=TopLawnOn
arrival.topLawnOn=topLawnOn
-- The Paw Glade's data while the Top Lawn is on (else nil: the Hollow, or the old grove, is the second park).
arrival.Glade=if TopLawnOn then glade(makeLayout(Specs.hollow))else nil
arrival.glade=glade
-- Server only: the Top Lawn's membership gate (fn() -> bool). Clients never set it.
arrival.setTerraceGate=function(fn)terraceGate=if type(fn)=="function"then fn else nil end
-- The gate as set (specs save and restore it around their own).
arrival.terraceGate=function()return terraceGate end
-- Specs and the Studio probe build a site from a spec without touching the live sites.
arrival.build=function(spec)return table.freeze(makeLayout(spec))end
function arrival.siteAt(position,currentId)
	local current=byId[currentId]
	if current and current.member(position,true)then return current end
	for _,site in ipairs(sites)do if site.member(position,false)then return site end end
	return nil
end
table.freeze(grove)
return table.freeze(arrival)
