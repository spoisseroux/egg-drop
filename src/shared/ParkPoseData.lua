-- Pet Park equipment data and pure motion (BUILD-PLAN 2026-11-13, slice K3). Shared by the server
-- mount (ParkMount: static meshes, colliders, seats) and the client (ParkClient: local moving parts;
-- ParkPetPose: pets on the equipment). Nothing here reads a clock or touches instances.
--
-- Mesh data is copied from assets/park/park-manifest.json + park-import.json (K2). Units are studs.
-- A mesh's world frame is groupRoot * CFrame.new(offset) * motion * CFrame.new(-pivotFromCenter)
-- * ImportTurn (the manifest's PivotOffset rule written without PivotTo). ImportTurn (QA Q4,
-- 2026-11-13): the Open Cloud FBX import turns every mesh by pi about Y (the same turn the world
-- v7 meshes carry, scripts/build_world_v7_assets.py), so without it each park mesh rendered back
-- to front: the slide's chute stood where the pets climb (pets went UP the chute and DOWN the
-- ladder) and the benches faced out of the park. Anchors, seats and colliders are group-frame
-- data and never take the turn. Group roots come from ParkLayout
-- (authoritative positions, yaw = heading of the group's +Z front). The slide is the one exception:
-- its root is shifted so the mesh's ladder foot lands on the slide slot's approach point, which also
-- puts the chute end within 0.15 studs of ParkLayout's chuteEnd.
--
-- Motion is a pure function of a park slot entry ({session, activity, ownerId, startTime, ...}) and
-- a server time, so every viewer (late joiners included) sees the same swing beat, tilt and castle.
local Park=require(script.Parent.ParkLayout)
local Catalog=require(script.Parent.ParkActivities)
local Data={}
Data.Delay=.12 -- the shared presentation delay PetFollow.activity samples with
Data.Texture="rbxassetid://132276058524122"
Data.ModelAsset="136546082248550"

local function v(x,y,z)return Vector3.new(x,y,z)end
local IDENTITY=CFrame.identity
local TAU=math.pi*2

local meshes={}
local function mesh(name,id,size,offset,pivot,extra)
	local entry={name=name,id=id,size=size,offset=offset,pivot=pivot}
	for key,value in pairs(extra or {})do entry[key]=value end
	meshes[name]=table.freeze(entry)
end
mesh("Park_SwingFrame","rbxassetid://114085020332908",v(7.36,4.5,3.32),v(0,0,0),v(0,-2.25,0))
mesh("Park_SwingA","rbxassetid://105819369643770",v(1.2,3.24,.62),v(-1.35,4.2,0),v(0,1.67,0),{seat=v(0,-3.09,0)})
mesh("Park_SwingB","rbxassetid://71740952243869",v(1.2,3.24,.62),v(1.35,4.2,0),v(0,1.67,0),{seat=v(0,-3.09,0)})
mesh("Park_Slide","rbxassetid://92757352124252",v(2.348,5.379,8.185),v(0,0,0),v(0,-2.661,-2.007))
mesh("Park_SeeSawBase","rbxassetid://117918989950947",v(1.3,1.285,1.527),v(0,0,0),v(0,-.642,0))
mesh("Park_SeeSawBeam","rbxassetid://96724875357045",v(6.2,.9,.66),v(0,1,0),v(0,-.39,0))
mesh("Park_SandboxFrame","rbxassetid://134924919972387",v(4.8,.88,4.8),v(0,0,0),v(0,-.44,0))
mesh("Park_Castle1","rbxassetid://75899482719665",v(1.44,.586,1.44),v(0,.32,0),v(0,-.293,0),{stage=1})
mesh("Park_Castle2","rbxassetid://86022655775582",v(1.56,1.14,1.56),v(0,.32,0),v(0,-.57,0),{stage=2})
mesh("Park_Castle3","rbxassetid://98786143794115",v(1.9,1.95,1.9),v(0,.32,0),v(0,-.975,0),{stage=3})
mesh("Park_SandToys","rbxassetid://121619517232554",v(.814,.519,.691),v(1.15,.32,-1.2),v(-.151,-.26,.083))
mesh("Park_BallMat","rbxassetid://90179910494479",v(4.387,.15,4.5),v(0,0,0),v(0,-.075,0))
mesh("Park_BallA","rbxassetid://74693775529293",v(.84,.84,.84),v(-.75,.57,0),v(0,0,0),{radius=.42})
mesh("Park_BallB","rbxassetid://81950708061275",v(.84,.84,.84),v(.75,.57,0),v(0,0,0),{radius=.42})
mesh("Park_KerbSegment","rbxassetid://72927644457663",v(3.479,.652,.9),v(0,0,0),v(0,-.326,0))
mesh("Park_GatePost","rbxassetid://106763533108528",v(1.072,3.1,1.072),v(0,0,0),v(0,-1.55,0))
mesh("Park_GateStarOrb","rbxassetid://90515653581302",v(1.16,1.104,.72),v(0,3.6,0),v(0,-.058,0))
mesh("Park_Bench","rbxassetid://105345988261448",v(4.5,3.42,1.39),v(0,0,0),v(0,-1.71,.005))
-- QA Q4 five-seat bench (assets/park/park-bench-long.fbx). id nil until the coordinator uploads it:
-- the mount stands two Park_Bench meshes end to end in its place (same five seats and colliders).
mesh("Park_BenchLong","rbxassetid://130406059426481",v(9.57,3.42,1.39),v(0,0,0),v(0,-1.71,.005))
Data.Meshes=table.freeze(meshes)
-- Client-animated meshes (never mounted by the server).
Data.Moving=table.freeze({"Park_SwingA","Park_SwingB","Park_SeeSawBeam","Park_BallA","Park_BallB","Park_Castle1","Park_Castle2","Park_Castle3"})

Data.ImportTurn=CFrame.Angles(0,math.pi,0)
local IMPORT_TURN=Data.ImportTurn
-- World frame of a mesh in a group. `scale` (Vector3, optional) scales about the mesh pivot.
function Data.frame(name,root,motion,scale)
	local m=meshes[name]
	local pivot=if scale then m.pivot*scale else m.pivot
	return root*CFrame.new(m.offset)*(motion or IDENTITY)*CFrame.new(-pivot)*IMPORT_TURN
end
-- MeshPart.PivotOffset that puts the part's pivot on the group pivot (with the group's axes).
function Data.pivotOffset(name)
	return IMPORT_TURN*CFrame.new(meshes[name].pivot)
end

-- Group roots ------------------------------------------------------------------------------------
local E=Park.Equipment
local roots={
	SwingSet=Park.cframe(E.swing.position,E.swing.yaw),
	SeeSaw=Park.cframe(E.seesaw.position,E.seesaw.yaw),
	Sandbox=Park.cframe(E.sandbox.position,E.sandbox.yaw),
	BallCorner=Park.cframe(E.ball.position,E.ball.yaw),
}
local LADDER_BOTTOM=v(0,0,-2.55)
do
	local approach=Park.Slots.slide.approach
	local turn=CFrame.Angles(0,E.slide.yaw,0)
	local at=approach-turn:VectorToWorldSpace(LADDER_BOTTOM)
	roots.Slide=CFrame.new(at.X,approach.Y,at.Z)*turn
end
Data.Roots=table.freeze(roots)

-- Swings: each swing slot drives the mesh whose pivot is nearest its slot pivot. The swing turns
-- about its own X axis (the bar), so a seated pet facing the group front just pitches with it.
local swings={}
for _,id in ipairs({"swing1","swing2"})do
	local slot=Park.Slots[id]
	local best,bestGap
	for _,name in ipairs({"Park_SwingA","Park_SwingB"})do
		local pivot=roots.SwingSet*CFrame.new(meshes[name].offset)
		local gap=Vector2.new(pivot.X-slot.pivot.X,pivot.Z-slot.pivot.Z).Magnitude
		if not bestGap or gap<bestGap then best,bestGap=name,gap end
	end
	swings[id]=table.freeze({mesh=best,pivot=roots.SwingSet*CFrame.new(meshes[best].offset),seat=meshes[best].seat,
		amplitude=slot.amplitude or .5,period=Catalog.ById.swing.period})
end
Data.Swings=table.freeze(swings)
Data.SwingSettle=table.freeze({share=.45,decay=1.6,stop=8})

-- See-saw: the beam turns about the fulcrum's Z axis; positive tilt lowers seat A (seesaw1, west).
Data.SeeSaw=table.freeze({
	pivot=roots.SeeSaw*CFrame.new(meshes.Park_SeeSawBeam.offset),
	seats=table.freeze({seesaw1=v(-2.62,.41,0),seesaw2=v(2.62,.41,0)}),
	max=E.seesaw.maxTilt,rest=E.seesaw.maxTilt,period=Catalog.ById.seesaw.period,
})

-- Slide: world points along the ladder (approach -> rungs -> deck) and down the chute.
local function slidePoint(p)return roots.Slide:PointToWorldSpace(p)end
local ladder={Park.Slots.slide.approach}
for _,p in ipairs({v(0,0,-2.55),v(0,.417,-1.83),v(0,.833,-1.66),v(0,1.25,-1.49),v(0,1.667,-1.32),v(0,2.083,-1.15),v(0,2.51,-.55),v(0,2.51,0)})do
	table.insert(ladder,slidePoint(p))
end
local chute={}
for _,p in ipairs({v(0,2.51,.95),v(0,2.457,1.455),v(0,2.303,1.96),v(0,2.063,2.465),v(0,1.76,2.97),v(0,1.425,3.475),
	v(0,1.09,3.98),v(0,.787,4.485),v(0,.547,4.99),v(0,.393,5.495),v(0,.34,6)})do
	table.insert(chute,slidePoint(p))
end
local _,slideYaw=roots.Slide:ToEulerAnglesYXZ()
Data.Slide=table.freeze({
	root=roots.Slide,yaw=slideYaw,ladder=table.freeze(ladder),chute=table.freeze(chute),
	platform=slidePoint(v(0,2.51,0)),chuteTop=slidePoint(v(0,2.51,.95)),landing=Park.Slots.slide.chuteEnd,
})

Data.Sand=table.freeze({castle=roots.Sandbox*CFrame.new(0,.32,0),height=.32})
Data.Ball=table.freeze({
	homeA=roots.BallCorner:PointToWorldSpace(meshes.Park_BallA.offset),
	homeB=roots.BallCorner:PointToWorldSpace(meshes.Park_BallB.offset),
	matTop=.13,radius=.42,period=Catalog.ById.ball.period,
})
-- Surface lift (studs above the slot's ground point) for pets playing on a mat or in the sand.
Data.Lift=table.freeze({sandbox=.32,ball=.13})

-- Static layout: kerb segments, gate posts + orbs, benches, colliders and bench seats -----------
local KERB_CHORD,POST_RADIUS=3.3,.54
local function kerbLayout()
	local cx,cz,rx,rz=Park.Center.X,Park.Center.Z,Park.Radius.X,Park.Radius.Y
	local steps=1440
	local cumulative,points={[0]=0},{}
	for i=0,steps do
		local theta=TAU*i/steps
		points[i]=Vector2.new(cx+rx*math.cos(theta),cz+rz*math.sin(theta))
		if i>0 then cumulative[i]=cumulative[i-1]+(points[i]-points[i-1]).Magnitude end
	end
	local total=cumulative[steps]
	local function arcAt(theta)
		theta%=TAU
		local f=theta/TAU*steps;local i=math.floor(f)
		if i>=steps then return total end
		return cumulative[i]+(cumulative[i+1]-cumulative[i])*(f-i)
	end
	local function pointAt(s)
		s%=total
		local lo,hi=0,steps
		while hi-lo>1 do local mid=(lo+hi)//2;if cumulative[mid]<=s then lo=mid else hi=mid end end
		local span=cumulative[hi]-cumulative[lo]
		local u=if span>0 then(s-cumulative[lo])/span else 0
		local p=points[lo]:Lerp(points[hi],u)
		return Vector3.new(p.X,Park.ground(p.X,p.Y),p.Y)
	end
	local gates={}
	for _,gate in ipairs(Park.Gateways)do table.insert(gates,{s=arcAt(gate.angle),half=gate.width*.5})end
	table.sort(gates,function(a,b)return a.s<b.s end)
	local segments,posts={},{}
	for index,gate in ipairs(gates)do
		for _,side in ipairs({-1,1})do table.insert(posts,pointAt(gate.s+side*(gate.half+POST_RADIUS)))end
		local nextGate=gates[index%#gates+1]
		local from=gate.s+gate.half+POST_RADIUS*2
		local to=nextGate.s-nextGate.half-POST_RADIUS*2
		if to<=from then to+=total end
		local count=math.max(1,math.floor((to-from)/KERB_CHORD+.5))
		for k=0,count-1 do
			local a,b=pointAt(from+(to-from)*k/count),pointAt(from+(to-from)*(k+1)/count)
			local d=Vector3.new(b.X-a.X,0,b.Z-a.Z)
			local mid=(a+b)*.5
			table.insert(segments,{position=Vector3.new(mid.X,Park.ground(mid.X,mid.Z),mid.Z),yaw=math.atan2(-d.Z,d.X),chord=d.Magnitude})
		end
	end
	return segments,posts
end

local BENCH_SEATS={
	Park_Bench={{center=v(-1,1.7,0),size=v(1.8,.2,1.2)},{center=v(1,1.7,0),size=v(1.8,.2,1.2)}},
	Park_BenchLong={},
}
for i=1,5 do table.insert(BENCH_SEATS.Park_BenchLong,{center=v((i-3)*1.75,1.7,0),size=v(1.6,.2,1.2)})end
-- Until Park_BenchLong is uploaded: two Park_Bench meshes end to end (local X offsets).
local LONG_STAND_IN={-2.3,2.3}
-- Manifest colliders (group frame). pitchDeg is negated: the manifest's sign follows Blender, and
-- the chute planks must descend toward the group's +Z like the chute path does.
local COLLIDERS={
	SwingSet={{v(-2.95,2.1,0),v(.5,4.2,2.9),0},{v(2.95,2.1,0),v(.5,4.2,2.9),0}},
	Slide={{v(0,1.5,0),v(2,3,2),0},{v(0,2.377,1.371),v(1.44,.17,.854),-9.8},{v(0,2.106,2.213),v(1.44,.17,.931),-25.26},
		{v(0,1.636,3.054),v(1.44,.17,1.001),-32.8},{v(0,1.094,3.896),v(1.44,.17,1.001),-32.8},
		{v(0,.624,4.738),v(1.44,.17,.931),-25.26},{v(0,.353,5.579),v(1.44,.17,.854),-9.8}},
	SeeSaw={{v(0,.55,0),v(1.3,1.1,1.5),0}},
	Sandbox={{v(0,.25,2.14),v(4.6,.5,.32),0},{v(-2.14,.25,0),v(.32,.5,4.6),0},{v(0,.25,-2.14),v(4.6,.5,.32),0},{v(2.14,.25,0),v(.32,.5,4.6),0}},
	Bench={{v(0,.9,0),v(4.4,1.8,1.3),0},{v(0,2.42,-.56),v(4.4,1.4,.3),0}},
	BenchLong={{v(0,.9,0),v(9.47,1.8,1.3),0},{v(0,2.42,-.56),v(9.47,1.4,.3),0}},
}

-- Everything the server mounts. Built once on first use (pure; safe on both sides).
local layout
function Data.layout()
	if layout then return layout end
	local static,colliders,seats={},{},{}
	local function put(group,name,cframe,size)
		table.insert(static,table.freeze({group=group,mesh=name,cframe=cframe,size=size or meshes[name].size}))
	end
	put("SwingSet","Park_SwingFrame",Data.frame("Park_SwingFrame",roots.SwingSet))
	put("Slide","Park_Slide",Data.frame("Park_Slide",roots.Slide))
	put("SeeSaw","Park_SeeSawBase",Data.frame("Park_SeeSawBase",roots.SeeSaw))
	put("Sandbox","Park_SandboxFrame",Data.frame("Park_SandboxFrame",roots.Sandbox))
	put("Sandbox","Park_SandToys",Data.frame("Park_SandToys",roots.Sandbox))
	put("BallCorner","Park_BallMat",Data.frame("Park_BallMat",roots.BallCorner))
	local segments,posts=kerbLayout()
	local kerb=meshes.Park_KerbSegment
	for _,segment in ipairs(segments)do
		-- The mesh's rounded ends overlap at the authored 3.3 stud chord; stretch to the actual chord.
		local stretch=segment.chord/KERB_CHORD
		local root=Park.cframe(segment.position,0)*CFrame.Angles(0,segment.yaw,0)
		put("Kerb","Park_KerbSegment",Data.frame("Park_KerbSegment",root),Vector3.new(kerb.size.X*stretch,kerb.size.Y,kerb.size.Z))
	end
	for _,post in ipairs(posts)do
		local root=Park.cframe(post,math.atan2(Park.Center.X-post.X,Park.Center.Z-post.Z))
		put("Kerb","Park_GatePost",Data.frame("Park_GatePost",root))
		put("Kerb","Park_GateStarOrb",Data.frame("Park_GateStarOrb",root))
	end
	for _,bench in ipairs(Park.Benches)do
		local root=Park.cframe(bench.position,bench.yaw)
		local name=bench.mesh or "Park_Bench"
		if name=="Park_BenchLong"and not meshes.Park_BenchLong.id then
			for _,dx in ipairs(LONG_STAND_IN)do put("Bench","Park_Bench",Data.frame("Park_Bench",root*CFrame.new(dx,0,0)))end
		else
			put("Bench",name,Data.frame(name,root))
		end
		for _,box in ipairs(if name=="Park_BenchLong"then COLLIDERS.BenchLong else COLLIDERS.Bench)do
			table.insert(colliders,table.freeze({group="Bench",cframe=root*CFrame.new(box[1])*CFrame.Angles(-math.rad(box[3]),0,0),size=box[2]}))
		end
		-- A Seat sits facing its LookVector (-Z): turn it to face the bench front (+Z).
		for index,seat in ipairs(BENCH_SEATS[name])do
			table.insert(seats,table.freeze({bench=bench.id,index=index,cframe=root*CFrame.new(seat.center)*CFrame.Angles(0,math.pi,0),size=seat.size}))
		end
	end
	for group,boxes in pairs(COLLIDERS)do
		if group=="Bench"or group=="BenchLong"then continue end
		for _,box in ipairs(boxes)do
			table.insert(colliders,table.freeze({group=group,cframe=roots[group]*CFrame.new(box[1])*CFrame.Angles(-math.rad(box[3]),0,0),size=box[2]}))
		end
	end
	table.sort(colliders,function(a,b)
		if a.group~=b.group then return a.group<b.group end
		local p,q=a.cframe.Position,b.cframe.Position
		return if p.X~=q.X then p.X<q.X elseif p.Y~=q.Y then p.Y<q.Y else p.Z<q.Z
	end)
	-- Anchor frames the client animates from (also written as model attributes by the mount).
	local anchors={
		SwingPivot_swing1=swings.swing1.pivot,SwingPivot_swing2=swings.swing2.pivot,
		SeeSawPivot=Data.SeeSaw.pivot,BallHomeA=CFrame.new(Data.Ball.homeA),BallHomeB=CFrame.new(Data.Ball.homeB),
		CastleBase=Data.Sand.castle,SlideRoot=roots.Slide,
	}
	layout=table.freeze({static=table.freeze(static),colliders=table.freeze(colliders),seats=table.freeze(seats),
		anchors=table.freeze(anchors),kerbSegments=#segments,gatePosts=#posts})
	return layout
end

-- Motion from server times -------------------------------------------------------------------------
-- Allocation-free ParkActivities.phaseAt: index, phase entry, elapsed, t (0..1), beat (0..1 in the
-- phase period, 0 without one). nil before the start and after the end.
function Data.phase(activity,startTime,t)
	if not activity or type(startTime)~="number"or type(t)~="number"then return nil end
	local time=t-startTime
	if time<0 or time>=activity.duration then return nil end
	local phases=activity.phases;local offset=0
	for index,step in ipairs(phases)do
		if time<offset+step.duration or index==#phases then
			local elapsed=time-offset
			local beat=0
			if step.period then local beats=elapsed/step.period;beat=beats-math.floor(beats)end
			return index,step,elapsed,math.clamp(elapsed/step.duration,0,1),beat
		end
		offset+=step.duration
	end
	return nil
end
local phaseOf=Data.phase
-- Allocation-free ParkActivities.stageAt (same values).
function Data.stage(activity,startTime,t)
	if not activity or not activity.castle then return 0,0 end
	local index,step,_,u=phaseOf(activity,startTime,t)
	if not index then return 0,0 end
	local done=0
	for i=1,index-1 do local previous=activity.phases[i];if previous.stage then done=math.max(done,previous.stage)end end
	if step.crumble then return 4,u end
	if step.stage then return done,u end
	return done,1
end
local function activityOf(entry,equipment)
	local activity=entry and Catalog.ById[entry.activity]
	if activity and activity.equipment==equipment and type(entry.startTime)=="number"then return activity end
	return nil
end
Data.activityOf=activityOf

-- The swing's settle after a ride: starts at 0 when the hop begins, decays to rest.
function Data.swingSettle(slotId,hopAt,t)
	if type(hopAt)~="number"or t<hopAt then return 0 end
	local swing=swings[slotId];local settle=Data.SwingSettle
	local age=t-hopAt
	if age>=settle.stop then return 0 end
	return swing.amplitude*settle.share*math.exp(-age/settle.decay)*math.sin(TAU*age/swing.period)
end
-- Time the swing's hop starts for a swing session entry (nil for other entries).
function Data.swingHopAt(entry)
	local activity=activityOf(entry,"swing")
	if not activity then return nil end
	return entry.startTime+Catalog.phaseStart(activity,"hop")
end
-- Swing angle (radians about the bar) for a swing slot at server time t. `entry` may be nil (no
-- session); `lastHop` is the latest hop start seen for this swing (the idle settle).
function Data.swingAngle(slotId,entry,t,lastHop)
	local activity=activityOf(entry,"swing")
	local swing=swings[slotId]
	if not activity then return Data.swingSettle(slotId,lastHop,t)end
	local index,step,elapsed,_,beat=phaseOf(activity,entry.startTime,t)
	if index and step.name=="swing"then
		local ramp=math.min(1,elapsed/swing.period)
		return swing.amplitude*ramp*math.sin(TAU*beat)
	end
	if t<entry.startTime then return Data.swingSettle(slotId,lastHop,t)end
	if index and step.name=="mount"then return 0 end
	return Data.swingSettle(slotId,Data.swingHopAt(entry),t)
end
function Data.swingMotion(angle)return CFrame.Angles(angle,0,0)end
-- World frame of the seat top (the pet's sole point) for a swing slot at `angle`.
function Data.swingSeat(slotId,angle)
	local swing=swings[slotId]
	return swing.pivot*CFrame.Angles(angle,0,0)*CFrame.new(swing.seat)
end

-- See-saw tilt at t: resting with seat A down; bobbing as cos so the bob starts and ends at rest.
function Data.seesawTilt(entry,t)
	local activity=activityOf(entry,"seesaw")
	local seesaw=Data.SeeSaw
	if not activity then return seesaw.rest end
	local index,step,_,_,beat=phaseOf(activity,entry.startTime,t)
	if index and step.name=="bob"then return seesaw.max*math.cos(TAU*beat)end
	return seesaw.rest
end
function Data.seesawMotion(tilt)return CFrame.Angles(0,0,tilt)end
function Data.seesawSeat(slotId,tilt)
	local seesaw=Data.SeeSaw
	return seesaw.pivot*CFrame.Angles(0,0,tilt)*CFrame.new(seesaw.seats[slotId])
end

-- Castle at t: which stage mesh shows (0 = none) and its Y scale / XZ scale / sink below the sand.
-- Each dig phase raises the next stage out of the sand over its second half (the first half keeps
-- the previous stage); admire holds stage 3; crumble squashes it flat and wide into the sand.
function Data.castle(entry,t)
	local activity=entry and Catalog.ById[entry.activity]
	if not activity or not activity.castle or type(entry.startTime)~="number"then return 0,1,1,0 end
	local index,step=phaseOf(activity,entry.startTime,t)
	if not index then return 0,1,1,0 end
	local stage,progress=Data.stage(activity,entry.startTime,t)
	if stage==4 then
		local u=progress*progress
		return 3,math.max(.08,1-.92*u),1+.35*u,.25*u
	end
	if step.stage then
		if progress<.35 then return stage,1,1,0 end
		local u=(progress-.35)/.65;u=u*u*(3-2*u)
		return step.stage,.35+.65*u,.8+.2*u,0
	end
	return stage,1,1,0
end

-- The slot's play spot for ball/sand pets: ground point + surface lift.
function Data.spot(slotId)
	local slot=Park.Slots[slotId]
	return slot.approach+Vector3.new(0,Data.Lift[slot.equipment]or 0,0)
end
local function facing(yaw)return Vector3.new(math.sin(yaw),0,math.cos(yaw))end
Data.facing=facing
-- Where a ball sits in front of the pet on a ball slot (centre of the ball).
function Data.ballFront(slotId)
	local slot=Park.Slots[slotId]
	return Data.spot(slotId)+facing(slot.yaw)*.75+Vector3.new(0,Data.Ball.radius,0)
end

Data.BallPickup=.35
-- Ball corner at t: positions and spin (radians about the travel's side axis) for BallA and BallB.
-- Solo: the slot's own ball (A on ball1, B on ball2) is batted out along the pet's facing and comes
-- back bouncing twice per period. Duo: ball A arcs between the two pets each half period.
-- Before the play and after the session: at home. Cheer: rolls home.
-- Returns posA, spinA, posB, spinB, active ("A", "B" or nil) and the beat (0..1) of the play.
function Data.balls(entry1,entry2,t)
	local ball=Data.Ball
	local entry=entry1 or entry2
	local activity=entry and activityOf(entry,"ball")
	local homeA,homeB=ball.homeA,ball.homeB
	if not activity then return homeA,0,homeB,0,nil,0 end
	local index,step,elapsed,phaseT,beat=phaseOf(activity,entry.startTime,t)
	if not index then return homeA,0,homeB,0,nil,0 end
	local duo=activity.kind=="duo"and entry1~=nil and entry2~=nil and entry1.session==entry2.session
	local slotId=if entry==entry1 then "ball1"else "ball2"
	local useA=duo or slotId=="ball1"
	local home=if useA then homeA else homeB
	local position,spin
	if step.name=="play"then
		if duo then
			local a,b=Data.ballFront("ball1"),Data.ballFront("ball2")
			local u,from,to=beat*2,a,b
			if beat>=.5 then u,from,to=(beat-.5)*2,b,a end
			position=from:Lerp(to,u)+Vector3.new(0,1.4*math.sin(math.pi*u),0)
			local travelled=u*(b-a).Magnitude
			if beat>=.5 then travelled=(1-u)*(b-a).Magnitude end
			spin=travelled/ball.radius
		else
			local near=Data.ballFront(slotId);local dir=facing(Park.Slots[slotId].yaw)
			local reach=math.sin(math.pi*beat)*2
			position=near+dir*reach+Vector3.new(0,1.0*math.abs(math.sin(TAU*beat))*(1-.4*beat),0)
			spin=reach/ball.radius
		end
		if index==1 and elapsed<Data.BallPickup then
			-- The first moment of play rolls the ball from its home to the pet.
			local u=elapsed/Data.BallPickup;u=u*u*(3-2*u)
			position=home:Lerp(position,u)
		end
	else
		-- Roll home from where the play left it (beat 0 = in front of the first pet).
		local from=Data.ballFront(if duo then "ball1"else slotId)
		local u=phaseT*phaseT*(3-2*phaseT)
		position=from:Lerp(home,u)
		spin=(from-home).Magnitude*(1-u)/ball.radius
	end
	if useA then return position,spin,homeB,0,"A",beat end
	return homeA,0,position,spin,"B",beat
end

-- Pitch (radians, positive = nose down) a pet at `yaw` takes when an equipment pivot frame turns by
-- `motion` (in the pivot's own axes). The pet sits square to that axis on swings and see-saws.
function Data.pitchFor(pivot,motion,yaw)
	local turn=pivot.Rotation
	local tilt=turn*motion.Rotation*turn:Inverse()
	local rel=CFrame.Angles(0,-yaw,0)*tilt*CFrame.Angles(0,yaw,0)
	local x=rel:ToEulerAnglesYXZ()
	return x
end

return table.freeze(Data)
