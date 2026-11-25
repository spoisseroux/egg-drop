-- The Play Den, step A (PLAY-DEN-BUILD-PLAN.md, architect verdict applied): the gate (missing = off; clients follow
-- Den_open); the pocket layout inside the floor Studio R5 measured; the prompts 7+ apart; the waiting area across the apron
-- and never the cliff top; the pets' floor reaching the home Floor; safe cells off the furniture; step B's CliffDenData
-- (schema, every field, a mismatch is no layout); the greybox under budget with four lights; the pet floor chain equal to
-- today's line with the den closed; Garden Dash's den anchor. Reads the live world data: rerun after any re-export.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.PlayDen)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Den=require(Shared.PlayDen)
	local Layout=require(Shared.DenLayout)
	local Greybox=require(Shared.DenGreybox)
	local Anchor=require(Shared.DashAnchor)
	local Floors=require(Shared.PetFloors)
	local Hush=require(Shared.Hush)
	local Tier=require(Shared.Tier)
	local Data=require(Shared.WorldV7Data)
	local V7=require(Shared.HollowWorldLayout).V7
	local Bounds=require(Shared.IslandBounds)
	local Course=require(Shared.DashCourse)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local LIVE=96451847774961
	local P=Layout.Pocket

	test("gate: the flag and the beta place or Studio; missing or malformed is on (2026-11-25); clients follow Den_open only",function()
		assert(Den.ceiling({flags={PlayDen=true},studio=false,place=Den.PlaceId}))
		assert(not Den.ceiling({flags={PlayDen=true},studio=false,place=LIVE}))
		assert(not Den.ceiling({flags={},studio=true}))
		assert(Den.resolve(nil,nil,true)==true and Den.resolve("yes",nil,true)==true and Den.resolve(true,nil,true)==true and Den.resolve(false,nil,true)==false)
		assert(Den.resolve(true,nil,false)==false and Den.resolve(false,true,true)==true and Den.resolve(true,false,true)==false)
		Den.inject({flags={PlayDen=true},studio=true,open=true});assert(Den.isOpen())
		Den.inject({flags={PlayDen=true},studio=true});assert(not Den.isOpen(),"missing Den_open is closed")
		Den.inject({flags={PlayDen=true},studio=false,place=LIVE,open=true});assert(not Den.isOpen()and not Den.on())
		Den.inject(nil)
		assert(Den.Key=="play_den"and Den.Attribute=="Den_on"and Den.OpenAttribute=="Den_open"and Den.Blocker=="CaveBlocker")
	end)

	test("the pocket: every bay, lantern and the sign inside the measured floor and roof; the flat floor under each bay",function()
		assert(P.variant=="pocket"and P.floorY==4 and #P.bays==3)
		for _,bay in ipairs(P.bays)do
			local at=bay.frame.Position
			assert(at.X>=-11 and at.X<=-3.5 and at.Z<=-101 and at.Z>=-113,bay.id)
			assert(math.abs(V7.groundY(at.X,at.Z)-4)<.3,bay.id.." on the flat: "..V7.groundY(at.X,at.Z))
			-- Every corner of its footprint (before Grow) stays off the back rock (z -114.2) and the side slopes.
			local f=Layout.Kinds[bay.kind].foot
			for _,c in ipairs({{f[1],f[2]},{f[3],f[2]},{f[1],f[4]},{f[3],f[4]}})do
				local w=bay.frame*Vector3.new(c[1],0,c[2])
				assert(w.Z>-114.2 and w.X>-12.6 and w.X<-1.1,bay.id.." corner "..tostring(w))
			end
		end
		assert(P.sign.Position.Y+1.1<=10.2 and P.sign.LookVector.Z>.99,"under the lintel trim, facing the lawn")
		for _,l in ipairs(P.lanterns)do assert(l.at.Y<P.roofY,"under the roof")end
		assert(#P.lanterns==4)
		local board=P.board.Position
		assert(board.Y>3.5 and board.Y<6 and board.X>P.mouth.x2 and board.Z>-97,"the board on the apron by the right jamb")
	end)

	test("one prompt at a time: the gate and the table 7+ apart, the board far from both; prompts within reach of the floor",function()
		local s=Layout.prompts(P)
		assert(s.gate and s.deck and s.board)
		assert((s.gate-s.deck).Magnitude>=7,"gate to table "..(s.gate-s.deck).Magnitude)
		assert((s.board-s.gate).Magnitude>12 and (s.board-s.deck).Magnitude>12)
		for _,at in pairs(s)do assert(at.Y-P.floorY<4,"reachable from the floor")end
	end)

	test("the waiting area: the room and the apron out to z -97; floorY - 2 up to the roof; cliff-top roots never count",function()
		assert(Layout.inWait(P,Vector3.new(-7,7,-106))and Layout.inWait(P,Vector3.new(-6,7,-97.2)))
		assert(Layout.inWait(P,Vector3.new(-14,7,-98))and Layout.inWait(P,Vector3.new(2.5,7,-98)))
		assert(not Layout.inWait(P,Vector3.new(-6,7,-96)),"past the apron")
		assert(not Layout.inWait(P,Vector3.new(-7,31,-106)),"on the cliff top")
		assert(not Layout.inWait(P,Vector3.new(-7,1,-106)),"under the floor")
		assert(Layout.inWait(P,Vector3.new(-6,7,-96),1),"slack in plan")
		assert(Layout.inRoom(P,Vector3.new(-7,7,-106))and not Layout.inRoom(P,Vector3.new(-6,7,-98))and not Layout.inRoom(P,Vector3.new(-7,20,-106)))
		-- The area holds eight waiting players a stud and a half apart.
		local w=P.wait
		assert((w.max.X-w.min.X)*(w.max.Z-w.min.Z)>8*1.5*1.5*4)
	end)

	test("the pets' floor: only while open; the room's flat floor and the apron to the home Floor (overlapping it)",function()
		local FLOOR={CFrame=CFrame.new(V7.FloorCenterX,V7.FloorTop-.5,V7.FloorCenterZ),Size=Vector3.new(V7.Width,1,V7.Depth)}
		assert(not Layout.petFloor(P,Vector3.new(-7,4,-106),false)and not Layout.petFloor(P,Vector3.new(-7,4,-106),nil))
		assert(Layout.petFloor(P,Vector3.new(-7,4,-106),true)and Layout.petFloor(P,Vector3.new(-6,4.5,-95),true))
		assert(not Layout.petFloor(P,Vector3.new(-7,4,-117),true)and not Layout.petFloor(P,Vector3.new(-13,4,-106),true))
		-- Walking out: every step from the back of the room to the lawn is on a pet floor.
		for z=-112,-80,.5 do
			local p=Vector3.new(-6,4.3,z)
			assert(Floors.ok(FLOOR,p,false,false,P),"step at z "..z)
		end
		assert(not Floors.ok(FLOOR,Vector3.new(-6,4.3,-105),false,false,nil),"closed: not a floor")
	end)

	test("the pet floor chain with the den closed is today's line exactly, every Hush and tier flag, a 4-stud grid",function()
		local FLOOR={CFrame=CFrame.new(V7.FloorCenterX,V7.FloorTop-.5,V7.FloorCenterZ),Size=Vector3.new(V7.Width,1,V7.Depth)}
		local n=0
		for _,h in ipairs({false,true})do for _,t in ipairs({false,true})do
			for x=-120,124,4 do for z=-130,94,4 do
				local p=Vector3.new(x,V7.groundY(x,z)+.03,z)
				local old=Hush.onPetFloor(FLOOR,p,h)and not Tier.covers(p,t)
				assert(Floors.ok(FLOOR,p,h,t,nil)==old,"at "..x..","..z)
				n+=1
			end end
		end end
		assert(n>10000)
	end)

	test("safe cells for catch-up: on the pets' floor, never on furniture grown 1.5; the island ring keeps the den inside",function()
		assert(Layout.safeCell(P,-7,-104)and Layout.safeCell(P,-6,-93))
		for _,f in ipairs(Layout.feet(P,0))do
			local mid=f.frame*Vector3.new((f.x1+f.x2)/2,0,(f.z1+f.z2)/2)
			assert(not Layout.safeCell(P,mid.X,mid.Z),f.name)
		end
		assert(not Layout.safeCell(P,0/0,-104)and not Layout.safeCell(nil,-7,-104))
		-- Inside the ring, so the bounds never call the den gone; its region only adds safe ground.
		for _,p in ipairs({Vector3.new(-12,4,-114),Vector3.new(-2,4,-114),Vector3.new(-7,4,-106)})do
			assert(not Bounds.gone(p,nil),tostring(p))
		end
		local regions=Layout.boundsRegions(P)
		assert(#regions==1 and regions[1].fallY==P.floorY-Layout.FallDepth and Bounds.regionSafe(regions,Vector3.new(-7,4,-104)))
		assert(not Bounds.gone(Vector3.new(-7,-1,-106),regions)and not Bounds.gone(Vector3.new(-7,30,-106),regions))
	end)

	test("the doorstep and pin: on the lawn inside the home Floor, clear of the race course and pad",function()
		local e=P.doorstep
		assert(e.at.Z>-89 and e.landing.Z>-89 and Bounds.safeCell(e.at.X,e.at.Z)and Bounds.safeCell(e.landing.X,e.landing.Z))
		local pad=Vector3.new(Course.Pad.x/100,0,Course.Pad.z/100)
		assert((Vector3.new(e.at.X,0,e.at.Z)-pad).Magnitude>40)
		assert(Layout.inWait(P,P.pin,1)or P.pin.Z>P.mouth.z,"the trail ends at the mouth")
	end)

	test("the blocker in the world data spans the pocket's mouth and sits on its line",function()
		local b=Data.caveBlocker
		local cx,cz,sx=b.center[1],b.center[3],b.size[1]
		assert(math.abs(cz-P.mouth.z)<=3 and cx-sx/2<=P.mouth.x1+.5 and cx+sx/2>=P.mouth.x2-.5)
	end)

	test("the greybox: under 60 parts, four lights (range 14, no shadows), W7D_ names, only posts and the stump collide in the pocket",function()
		local rows=Greybox.rows(P)
		assert(#rows<=Greybox.MaxParts,#rows)
		local lights,solid=0,{}
		for _,row in ipairs(rows)do
			assert(string.sub(row.name,1,4)=="W7D_",row.name)
			if row.light then lights+=1;assert(row.light.range==14 and row.light.brightness>0)end
			if row.collide then table.insert(solid,row.name)end
		end
		assert(lights==4,lights)
		for _,name in ipairs(solid)do assert(string.find(name,"Post")or string.find(name,"Stump"),name)end
	end)

	local function cliff()
		return{schema=1,den={floorY=4.2,roofY=11,room={min={-22,3,-119},max={6,20,-100}},mouth={x1=-15,x2=1,z=-100,top=11},
			sign={at={-7,9,-99.6},facing={-7,9,-80}},board={at={3,4.5,-96},facing={3,4.5,-80}},pin={-7,4.6,-96},
			doorstep={at={-7,4.6,-87},facing={-7,4.6,-70},landing={-7,4.625,-84}},
			lanterns={{at={-15.5,4.4,-98},post=true},{at={1.5,4.4,-98},post=true},{at={-16,9,-118}},{at={2,9,-118}}},
			bays={{at={-18,4.2,-110},facing={-7,4.2,-106}},{at={-12,4.2,-116},facing={-12,4.2,-100}},{at={-7,4.2,-117},facing={-7,4.2,-100}},
				{at={-2,4.2,-116},facing={-2,4.2,-100}},{at={4,4.2,-110},facing={-7,4.2,-106}}}}}
	end
	test("step B: CliffDenData schema 1 gives the room: five bays by Fable's kinds, four lanterns, the apron in the waiting area",function()
		local L=assert(Layout.fromData(cliff()))
		assert(L.variant=="room"and #L.bays==5 and L.bays[1].kind=="dash"and L.bays[3].kind=="deck"and L.bays[5].kind=="niche")
		assert(Layout.inWait(L,Vector3.new(-7,7,-97.5))and Layout.inWait(L,Vector3.new(-20,7,-115))and not Layout.inWait(L,Vector3.new(-7,25,-110)))
		assert(Layout.petFloor(L,Vector3.new(-7,4.3,-90),true)and Layout.petFloor(L,Vector3.new(-10,4.3,-110),true))
		local s=Layout.prompts(L);assert((s.gate-s.deck).Magnitude>=7)
		assert(#Greybox.rows(L)<=Greybox.MaxParts)
		-- Fable cliff-den review: warm dim lamps with caps and bases, the timber frame over the mouth (no lantern posts),
		-- the sign on the beam, the mat, the apron (colliding, top 4.65, skipping the mouth's own floor).
		local byName={}
		for _,r in ipairs(Greybox.rows(L))do byName[r.name]=r end
		assert(Layout.Light.color=="#FFB870"and Layout.Light.brightness==.9 and Greybox.Look.lamp=="#D98A3A")
		assert(byName.W7D_FrameLintel and byName.W7D_FrameJamb1 and byName.W7D_FrameThreshold and byName.W7D_Mat and byName.W7D_MatInner)
		assert(byName.W7D_LanternPost1==nil and byName.W7D_LanternPost2==nil and byName.W7D_Lantern1Cap and byName.W7D_Lantern3Base)
		local beam=byName.W7D_FrameLintel
		assert(math.abs(byName.W7D_Sign.cframe.Position.Y-beam.cframe.Position.Y)<1e-6 and byName.W7D_Sign.cframe.Position.Z>beam.cframe.Position.Z)
		for _,n in ipairs({"W7D_ApronFront","W7D_ApronWest","W7D_ApronEast"})do
			local r=byName[n];assert(r and r.collide and math.abs(r.cframe.Position.Y+r.size.Y/2-Greybox.Apron.top)<1e-6,n)
			local lo,hi=r.cframe.Position-r.size/2,r.cframe.Position+r.size/2
			assert(hi.X<=L.mouth.x1 or lo.X>=L.mouth.x2 or lo.Z>=L.mouth.z+7.3-1e-6,n.." covers the mouth's floor")
		end
		-- Studio R2: ground rays in the room start under its collision ceiling (12.2); elsewhere +8 exactly.
		assert(Layout.groundRayTop(L,Vector3.new(-7,7.6,-110),8)==L.floorY+Layout.CeilingRay and L.floorY+Layout.CeilingRay<12.2)
		assert(Layout.groundRayTop(L,Vector3.new(-7,4.2,-98),8)==L.floorY+Layout.CeilingRay)
		assert(Layout.groundRayTop(L,Vector3.new(40,7,50),8)==15 and Layout.groundRayTop(nil,Vector3.new(-7,7.6,-110),8)==15.6)
		-- current(): only with CliffDen; the pocket is retired (2026-11-25): no room otherwise, and a reason.
		local none,why=Layout.current({cliffDen=false});assert(none==nil and type(why)=="string")
		assert(Layout.current({cliffDen=true,data=cliff()}).variant=="room")
	end)

	test("step B: a schema mismatch or any missing field is no layout and a reason (the den stays closed), never the pocket",function()
		local bad=cliff();bad.schema=2
		local L,why=Layout.fromData(bad);assert(L==nil and string.find(why,"schema"))
		for _,field in ipairs({"floorY","roofY","room","mouth","sign","board","pin","doorstep","lanterns","bays"})do
			local d=cliff();d.den[field]=nil
			local got,reason=Layout.fromData(d);assert(got==nil and type(reason)=="string",field)
		end
		local short=cliff();table.remove(short.den.bays);assert(Layout.fromData(short)==nil)
		local flipped=cliff();flipped.den.mouth.x2=-20;assert(Layout.fromData(flipped)==nil)
		local L2,why2=Layout.current({cliffDen=true,data=nil});assert(L2==nil and why2)
	end)

	test("Garden Dash's den anchor: picked only while open and in the waiting area; reach; a stray after 2 s; closed",function()
		assert(Anchor.pick(Vector3.new(-7,7,-106),P)=="den"and Anchor.pick(Vector3.new(-7,7,-106),nil)=="meadow")
		assert(Anchor.pick(Vector3.new(-7,7,-90),P)=="meadow"and Anchor.pick(Vector3.new(-7,31,-106),P)=="meadow")
		assert(Anchor.reach(P,Vector3.new(-7,7,-106))and select(2,Anchor.reach(P,Vector3.new(-7,7,-80)))=="Far")
		assert(select(2,Anchor.reach(nil,Vector3.new(-7,7,-106)))=="Closed")
		local rec={}
		assert(Anchor.rule(rec,P,Vector3.new(-7,7,-106),0))
		assert(Anchor.rule(rec,P,Vector3.new(-6,7,-95.5),1),"within Stray of the apron")
		assert(Anchor.rule(rec,P,Vector3.new(-6,7,-90),2))
		assert(Anchor.rule(rec,P,Vector3.new(-6,7,-90),3.9))
		local ok,why=Anchor.rule(rec,P,Vector3.new(-6,7,-90),4);assert(not ok and why=="Strayed")
		local back={};Anchor.rule(back,P,Vector3.new(-6,7,-90),0);assert(Anchor.rule(back,P,Vector3.new(-7,7,-106),1.5)and back.strayAt==nil)
		assert(select(2,Anchor.rule({},nil,Vector3.new(-7,7,-106),0))=="Closed")
	end)
	return{passed=#cases,cases=cases}
end
