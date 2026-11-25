-- Pets go up (artifacts/qa-2026-11-26-beta21/WORLD-FINISH-LOOK.md section 5, slice A; architect review applied): the
-- switch; the floors (zone: the terrace by height, the path's tread, a pet-blocked footprint low on the path); the lane
-- and the terrace less 3; the flight's hops; catch-up's route gap and landing; the rest and find spots up there; the pet
-- floor test; and the probe acceptance that can be checked without Studio (probe 4 on the centre-line data): GardenState
-- driven at its own 2 Hz behind owners walking up and down the path, with reversals, sampled at 30 Hz: every pet point on
-- the path within .8 of the tread and the middle 3 studs, never past the lip, hops only on the flight, the pet on the
-- terrace within 6 s of its owner, no stall over 2 s. The Studio half is scripts/probe_tier_pets.luau.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.TierPets)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Tier=require(Shared.Tier)
	local Pets=require(Shared.TierPets)
	local Floors=require(Shared.PetFloors)
	local Activity=require(Shared.GardenActivity)
	local Catchup=require(Shared.PetCatchup)
	local Finds=require(Shared.Finds)
	local Spots=Finds.Spots
	local V7=require(Shared.HollowWorldLayout).V7
	local Garden=require(server.GardenState)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local P=assert(Tier.path(),"CliffDenData's path")
	local U=P.u[#P.u]
	local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
	local LIVE=96451847774961

	test("the switch: the build ceiling with Tier's (beta or Studio), missing = on, an override wins; live never",function()
		local on={flags={Tier=true,TierPets=true},place=Tier.PlaceId,studio=false}
		assert(Pets.ceiling(on)and Pets.ceiling({flags={Tier=true,TierPets=true},place=1,studio=true}))
		assert(not Pets.ceiling({flags={Tier=true,TierPets=true},place=LIVE,studio=false}),"live")
		assert(not Pets.ceiling({flags={Tier=true,TierPets=false},place=Tier.PlaceId,studio=true}),"the flag off")
		assert(not Pets.ceiling({flags={Tier=false,TierPets=true},place=Tier.PlaceId,studio=true}),"Tier's flag off")
		assert(Pets.resolve(nil,nil,true)==true and Pets.resolve("x",nil,true)==true and Pets.resolve(false,nil,true)==false)
		assert(Pets.resolve(false,true,true)==true and Pets.resolve(true,false,true)==false and Pets.resolve(true,true,false)==false)
		assert(Pets.Key=="garden_tier_pets"and Pets.Attribute=="TierPets_on")
		-- The server needs its own value and the attribute both: the attribute alone is a real kill path (Studio probes
		-- drive instance state only, never this module's copy).
		if Pets.ceiling()then
			local was=workspace:GetAttribute(Pets.Attribute)
			Pets.setSwitch(true);workspace:SetAttribute(Pets.Attribute,true);assert(Pets.on()==true)
			workspace:SetAttribute(Pets.Attribute,false);assert(Pets.on()==false,"the attribute off closes it")
			workspace:SetAttribute(Pets.Attribute,true);Pets.setSwitch(false);assert(Pets.on()==false,"the server's own value off closes it")
			workspace:SetAttribute(Pets.Attribute,was)
		end
		local Config=require(server.TierPetsConfig)
		assert(Config.parse("/tierpets on").value==true and Config.parse(" /TierPets OFF ").value==false and Config.parse("/tierpets clear").value==nil)
		assert(Config.parse("/tier on")==nil and Config.parse("/tierpets")==nil and Config.parse("/tierpets maybe")==nil)
	end)

	test("the path data: u rises along the line, one flight of hops at the top, the turn before it",function()
		for i=2,#P.u do assert(P.u[i]>P.u[i-1],"u at "..i)end
		local flights=Pets.flights(P)
		assert(#flights==1,"one flight")
		local f=flights[1]
		assert(f.i1==#P.points and f.i1-f.i0>=5 and f.i1-f.i0<=12,"the flight runs into the arrival: "..f.i0.."-"..f.i1)
		for i=f.i0,f.i1-1 do
			local rise=P.points[i+1].Y-P.points[i].Y
			assert(rise>0 and rise<1.2,"a hop rises "..rise)
		end
		local turn=Pets.turnU(P)
		assert(turn and turn<f.u0 and turn>U*.6,"the turn sits below the flight")
	end)

	test("zones: the terrace by its height, the tread off the lawn, a footprint low on the path; the den and the lawn",function()
		assert(Pets.zone(Tier.T(0,0,Tier.FloorY+Pets.Sole))=="terrace")
		assert(Pets.zone(Tier.T(0,0,4.6))=="lawn","under the terrace's plan at lawn height (the den's sliver)")
		assert(Pets.zone(Vector3.new(-20,4.2,-103))=="lawn","the den's floor")
		assert(Pets.zone(Vector3.new(-6,4.6,-87))=="lawn","the den's doorstep")
		assert(Pets.zone(Tier.Evacuation.at)=="lawn","the evacuation spot")
		local mid=Pets.pointAt(U*.5,0,P)
		assert(Pets.zone(mid)=="path"and Pets.zone(mid+Vector3.new(0,3,0))=="path","the tread and a root on it")
		assert(Pets.zone(mid+Vector3.new(0,-10,0))=="lawn","far under the tread")
		assert(Pets.zone(Pets.pointAt(0,0,P))=="lawn","the foot")
		-- Architect B1: inside the first pet-blocked footprint, at lawn height, low on the path, is the path for routing.
		local start=Pets.blockStart(P)
		assert(start<U*.2,"the footprints start low")
		local low=Pets.pointAt(start+1,0,P)
		assert(Pets.zone(Vector3.new(low.X,4.6,low.Z))=="path")
		for _,spot in ipairs(Spots)do
			local at=Vector3.new(spot.x/100,spot.y/100+Pets.Sole,spot.z/100)
			assert((Pets.zone(at)~="lawn")==(spot.lawn=="tier"),"find spot "..spot.lawn)
		end
	end)

	test("the lane and the terrace: snaps keep the middle 3 studs and 3 inside the edge; the anchor follows the owner's floor",function()
		for k=0,40 do
			local u=U*k/40
			for _,side in ipairs({-3,-1,0,1,3})do
				local p=Pets.pointAt(u,side,P)
				local snapped=Pets.snap(p,"path",P)
				local hit=Pets.project(snapped,P)
				assert(math.abs(hit.lateral)<=Pets.Lane+1e-3 and math.abs(snapped.Y-hit.tread-Pets.Sole)<1e-3)
			end
		end
		local edge=Pets.snap(Tier.T(40,30,Tier.FloorY+3),"terrace",P)
		assert(Pets.terraceSafe(edge.X,edge.Z)and math.abs(edge.Y-Tier.FloorY-Pets.Sole)<1e-6)
		assert(Pets.terraceSafe(Tier.T(34.9,18.9).X,Tier.T(34.9,18.9).Z)and not Pets.terraceSafe(Tier.T(36,0).X,Tier.T(36,0).Z))
		assert(not Pets.terraceSafe(Tier.T(0,19.5).X,Tier.T(0,19.5).Z))
		-- An owner on the path: an offset point off the tread still lands in the lane.
		local root=Pets.pointAt(U*.4,0,P)+Vector3.new(0,3,0)
		local anchor=Pets.anchor(root,root+Vector3.new(6,0,0),P)
		assert(anchor and Pets.zone(anchor,P)=="path"and math.abs(Pets.project(anchor,P).lateral)<=Pets.Lane+1e-3)
		assert(Pets.anchor(Vector3.new(0,7,0),Vector3.new(1,7,1),P)==nil,"on the lawn: not ours")
		-- Rays on the path start at most 6 over the tread.
		local hit=Pets.project(root,P)
		assert(Pets.rayTop(root,root.Y+8,P)<=hit.tread+Pets.RayAbove+1e-6 and Pets.rayTop(Vector3.new(0,7,0),15,P)==15)
	end)

	test("the pet floor: open, the terrace less 3 and the path; closed or off, today's line exactly",function()
		local floor={CFrame=CFrame.new(V7.FloorCenterX,V7.FloorTop-.5,V7.FloorCenterZ),Size=Vector3.new(V7.Width,1,V7.Depth)}
		local mid=Pets.pointAt(U*.5,0,P)
		local up=Tier.T(5,5,Tier.FloorY+Pets.Sole)
		assert(Floors.ok(floor,up,false,true,nil,true)and Floors.ok(floor,mid,false,true,nil,true))
		assert(not Floors.ok(floor,Tier.T(37,0,Tier.FloorY+Pets.Sole),false,true,nil,true),"the terrace's edge")
		for _,p in ipairs({up,mid})do
			for _,args in ipairs({{true,nil},{true,false},{false,true},{nil,true}})do
				assert(Floors.ok(floor,p,false,args[1],nil,args[2])==Floors.ok(floor,p,false,args[1],nil),"today's line")
			end
			assert(not Floors.ok(floor,p,false,true,nil,false),"pets off: the tier is not pet floor")
		end
	end)

	test("catch-up: the route gap; RouteFar or RouteBehind; the landing 4 behind on the pet's side, never on the flight",function()
		local a,b=Pets.pointAt(U*.3,0,P),Pets.pointAt(U*.7,0,P)
		assert(math.abs(Pets.routeDistance(a,b,P)-U*.4)<1e-3 and math.abs(Pets.routeDistance(b,a,P)-U*.4)<1e-3)
		assert(Pets.routeDistance(Vector3.new(0,4.6,0),Vector3.new(3,4.6,3),P)==nil,"lawn to lawn")
		assert(Pets.routeDistance(Tier.T(0,0),Tier.T(5,5),P)==nil,"terrace to terrace")
		local lawnToTop=Pets.routeDistance(Pets.pointAt(0,0,P),Tier.T(30,19,Tier.FloorY),P)
		assert(lawnToTop>U and lawnToTop<U+5)
		-- PetCatchup's route rules.
		local t={}
		assert(Catchup.step(t,0,Catchup.RouteFar+1,a,true,true)==nil and Catchup.step(t,Catchup.FarHold,Catchup.RouteFar+1,a,true,true)=="far")
		local s={}
		assert(Catchup.step(s,0,Catchup.StuckNear+1,a,false,true,true)==nil)
		for k=1,9 do assert(Catchup.step(s,k*.5,Catchup.StuckNear+1,a+Vector3.new(k,0,0),false,true,true)==nil,"behind "..k*.5)end
		assert(Catchup.step(s,5,Catchup.StuckNear+1,a+Vector3.new(10,0,0),false,true,true)=="far","5 s behind a stopped owner")
		local walking={}
		for k=0,20 do assert(Catchup.step(walking,k*.5,Catchup.StuckNear+1,a+Vector3.new(k,0,0),false,true,false)==nil,"trailing a walking owner")end
		local lawn={}
		assert(Catchup.step(lawn,0,Catchup.RouteFar+1,a,false)==nil and Catchup.step(lawn,5,Catchup.RouteFar+1,a,false)==nil,"the lawn's Far is today's")
		-- Landings.
		local f=Pets.flights(P)[1]
		for k=1,30 do
			local ua=U*.15+(U-U*.15)*k/30
			local anchor=Pets.pointAt(ua,1,P)
			if Pets.zone(anchor,P)~="path"then continue end
			for _,pet in ipairs({Pets.pointAt(0,0,P),Tier.T(10,10,Tier.FloorY+Pets.Sole)})do
				local spot=Pets.landing(anchor,pet,P)
				assert(spot,"a landing")
				local z=Pets.zone(spot,P)
				if z=="path"then
					local u=Pets.project(spot,P).u
					assert(not Pets.onFlight(u,P),"never on the flight")
					assert(math.abs(Pets.project(spot,P).lateral)<1e-3,"on the centre line")
					local below=pet.Y<anchor.Y
					assert(if below then u<ua else u>ua,"on the pet's side")
					if not(ua>f.u0-Pets.LandBehind and ua<f.u1+1)then assert(math.abs(math.abs(u-ua)-Pets.LandBehind)<1e-3,"4 behind")end
				else
					assert(z=="terrace"and Pets.terraceSafe(spot.X,spot.Z),"past the arrival: the terrace just inside")
				end
			end
		end
		assert(Pets.landing(Vector3.new(0,4.6,0),a,P)==nil,"not on the path: the lawn's rings")
	end)

	test("rest and find spots up there: two rests and two finds on the terrace less 3, one each at the turn; clear of each other",function()
		local rests=Pets.rests(P)
		assert(#rests==3)
		local K=Tier.T(0,5)
		for _,r in ipairs(rests)do
			local z=Pets.zone(r.position,P)
			assert(not r.exclusive,"never exclusive (architect)")
			if r.id=="tier_turn"then
				assert(z=="path"and Pets.restAt(r.position,P)and Pets.targetOk(r.position,P)==true)
				assert(not Pets.onFlight(Pets.project(r.position,P).u,P))
			else
				assert(z=="terrace"and Pets.terraceSafe(r.position.X,r.position.Z)and Pets.targetOk(r.position,P)==true)
				assert(flat(r.position,K)>=13+3,"clear of the Top Lawn's circle")
			end
		end
		local tier=0
		for _,spot in ipairs(Spots)do
			if spot.lawn~="tier"then continue end
			tier+=1
			local at=Vector3.new(spot.x/100,spot.y/100+Pets.Sole,spot.z/100)
			local z=Pets.zone(at,P)
			assert(z=="terrace"and Pets.terraceSafe(at.X,at.Z)and flat(at,K)>=13+3 or z=="path",spot.x)
			if z=="path"then assert(math.abs(Pets.project(at,P).tread+Pets.Sole-at.Y)<.1,"the turn find on the tread")end
			for _,r in ipairs(rests)do assert(flat(at,r.position)>=3,"a find on a rest spot")end
		end
		assert(tier==3)
		-- The finds up there: after the lawns (every lawn index is FindSpots'), not in FindSpots (its readers on live see
		-- today's list), picked only with the gate open.
		local lawn=require(Shared.FindSpots)
		assert(#Spots==#lawn+3 and Finds.isUp(#lawn+1)and not Finds.isUp(#lawn))
		for i,s in ipairs(lawn)do assert(Spots[i]==s and s.lawn~="tier")end
		local random=Random.new(5)
		local all={};for i=1,#lawn do all[i]=i end
		assert(Finds.pick(random,{},all)==nil,"closed: nothing up there")
		local up=Finds.pick(random,{},all,nil,true)
		assert(up and Finds.isUp(up),"open: up there")
		for _=1,200 do assert(not Finds.isUp(Finds.pick(random,{},{})),"never up there with the gate closed")end
		-- Transit only: no wander or focus on the path but the rest spot.
		assert(Pets.targetOk(Pets.pointAt(U*.5,0,P),P)==false and Pets.targetOk(Vector3.new(0,4.6,0),P)==nil)
	end)

	-- Planned legs, sampled.
	local function sampleLegs(path,step)
		local out={}
		for _,leg in ipairs(path)do
			local actor={from=leg.from,to=leg.to,startTime=0,endTime=leg.duration,path={leg},yaw=leg.yaw,behavior="follow"}
			local n=math.max(2,math.ceil(leg.duration/step))
			for k=0,n do table.insert(out,{at=Activity.sample(actor,leg.duration*k/n).position,leg=leg})end
		end
		return out
	end
	local function isHop(leg)return leg.hop==true end
	-- Probe 4's tread rules for one sampled point (true when it is not on the path).
	local function onTread(at,label)
		if Pets.zone(at,P)~="path"then
			if at.Y>Tier.RegionY and Tier.inPiece(Tier.Pieces[1],at.X,at.Z,.05)then return end
			-- Off the path and off the terrace: the lawn by the foot only.
			assert(at.Y<Tier.FootY+Tier.PathLift+1,label.." in the air at "..tostring(at))
			return
		end
		local hit=Pets.project(at,P)
		assert(math.abs(hit.lateral)<=Pets.Lane+.15,label.." off the lane "..hit.lateral)
		assert(math.abs(hit.lateral)<=hit.half-.5,label.." on the lip")
		local over=at.Y-hit.tread-Pets.Sole
		assert(over>=-.8 and over<=.8,label.." "..over.." off the tread")
	end
	local function lawnPlan(a,b,v,s,m,y,i,t)return Activity.plan(a,b,v,s,m,y,i,t)end

	test("planned climbs and descents: continuous legs on the tread and in the lane; hops of .25 s on the flight only",function()
		local f=Pets.flights(P)[1]
		local ends={Vector3.new(-12,4.625,-84),Tier.T(20,12,Tier.FloorY+Pets.Sole),Pets.pointAt(U*.3,1,P),Pets.pointAt(U*.8,-1,P),Tier.T(-20,-15,Tier.FloorY+Pets.Sole)}
		for i,a in ipairs(ends)do
			for j,b in ipairs(ends)do
				if i==j then continue end
				local path,seconds=Pets.plan(a,b,Vector3.zero,9,0,0,lawnPlan,P)
				local za,zb=Pets.zone(a,P),Pets.zone(b,P)
				if za==zb and za~="path"then assert(path==nil);continue end
				assert(path and #path>0 and seconds>0,i.."->"..j)
				local at=a
				local hops,total=0,0
				for _,leg in ipairs(path)do
					assert((Activity.vector(leg.from)-at).Magnitude<1e-3,"legs join "..i.."->"..j)
					at=Activity.vector(leg.to);total+=leg.duration
					if isHop(leg)then
						hops+=1
						assert(leg.duration>=Pets.HopFast-1e-6 and leg.duration<=Pets.Hop+1e-6,"a hop takes .2 to .25 s")
						local u1,u2=Pets.project(Activity.vector(leg.from),P).u,Pets.project(Activity.vector(leg.to),P).u
						assert(math.min(u1,u2)>=f.u0-1e-3 and math.max(u1,u2)<=f.u1+1e-3,"a hop off the flight")
					end
				end
				assert(math.abs(total-seconds)<1e-6 and (at-b).Magnitude<.6,"ends at the target "..i.."->"..j)
				local crosses=(za=="terrace"or zb=="terrace")and not(za=="terrace"and zb=="terrace")
				if crosses then assert(hops==f.i1-f.i0,"every step hopped: "..hops)end
				for k,s in ipairs(sampleLegs(path,1/30))do onTread(s.at,i.."->"..j.." #"..k)end
			end
		end
		-- A rest in place on the path keeps its length (the turn's nook rest is 6 s; code review 3), and a route is never
		-- shorter than asked.
		local rest=Pets.rests(P)[3].position
		local legs,held=Pets.plan(rest,rest,Vector3.zero,4,6,0,lawnPlan,P)
		assert(legs and math.abs(held-6)<1e-6,"a rest on the path lasts 6 s, not "..tostring(held))
		local _,slow=Pets.plan(Pets.pointAt(U*.5,0,P),Pets.pointAt(U*.5+1,0,P),Vector3.zero,9,5,0,lawnPlan,P)
		assert(slow>=5-1e-6,"never shorter than the minimum")
		-- A pet standing on the tread low by the foot walks on up, never back to the foot first (code review 4).
		local low=Pets.pointAt(3,0,P)
		assert(Pets.zone(low,P)=="lawn"and Pets.planZone(low,P)=="path")
		local up=Pets.plan(low,Tier.T(20,12,Tier.FloorY+Pets.Sole),Vector3.zero,9,0,0,lawnPlan,P)
		local firstTo=Activity.vector(up[1].to)
		assert(Pets.project(firstTo,P).u>=3-1e-3,"the first step is up the path")
		-- A replan from mid-hop (in the air, moving up) drops straight to its step: never over the arc.
		local mid=P.points[f.i0+2]:Lerp(P.points[f.i0+3],.5)+Vector3.new(0,.3+Pets.Sole,0)
		local path=Pets.plan(mid,Pets.pointAt(U*.5,0,P),Vector3.new(3,5,-3),9,0,0,lawnPlan,P)
		assert(path and not isHop(path[1])and path[1].v0[2]==0,"the first leg drops, no lift")
		for _,s in ipairs(sampleLegs(path,1/30))do onTread(s.at,"mid-hop replan")end
	end)

	-- GardenState at its own cadence behind owners on the path: the planner, target resolver, catch-up and route gap the
	-- server passes (init.server), with the ground taken as the data (no Studio rays).
	local function rig(count)
		local c={now=0,inputs={},pets={}}
		local function resolve(target,from,base)
			local zone=Pets.zone(if typeof(base)=="Vector3"then base else target,P)
			if zone=="lawn"then return target,false end
			return Pets.snap(target,zone,P),true
		end
		c.garden=Garden.new({now=function()return c.now end,publish=function()end,sharedToyEnabled=false,
			validFocus=function()return false end,
			planPath=function(from,to,v,s,m,y,via,t)
				local path,seconds=Pets.plan(from,to,v,s,m,y,lawnPlan,P)
				if path then return path,seconds end
				return Activity.plan(from,to,v,s,m,y,via,t)
			end,
			resolveTarget=resolve,catchup=function()return true end,
			landing=function(input,_,pet)
				local zone=Pets.zone(input.anchor,P)
				if zone=="path"then return Pets.landing(input.anchor,pet,P)end
				return input.anchor
			end,
			routeGap=function(pet,anchor)return Pets.routeDistance(pet,anchor,P)end,
			canSettle=function(p)return Pets.zone(p,P)~="path"end,
			canMeet=function(a,b)local za,zb=Pets.zone(a,P),Pets.zone(b,P);return za==zb and za~="path"end})
		c.garden.Catchup=Catchup
		return c
	end
	-- An owner walking a list of legs {to = Vector3 root ground point, speed} from `start`; root = ground + 3.
	local LAWN=Vector3.new(-12,4.625,-84)
	local TOP=Tier.T(20,12,Tier.FloorY+Pets.Sole)
	local function ownerAt(route,t)
		local at=route.start
		for _,step in ipairs(route)do
			local seconds=if step.wait then step.wait else(step.to-at).Magnitude/step.speed
			if t<=seconds then
				if step.wait then return at,Vector3.zero end
				return at:Lerp(step.to,t/seconds),(step.to-at).Unit
			end
			t-=seconds;at=step.to or at
		end
		return at,Vector3.zero
	end
	local function lineTo(list,a,b,speed)
		-- Along the centre line between u a and u b (or the lawn / terrace ends), vertex by vertex.
		local ua,ub=a,b
		local dir=if ub>ua then 1 else -1
		for i=(if dir>0 then 1 else #P.u),(if dir>0 then #P.u else 1),dir do
			local u=P.u[i]
			if(dir>0 and u>ua and u<ub)or(dir<0 and u<ua and u>ub)then table.insert(list,{to=Pets.pointAt(u,0,P),speed=speed})end
		end
		table.insert(list,{to=Pets.pointAt(ub,0,P),speed=speed})
	end
	local function climb(speed,turnAt)
		local route={start=LAWN}
		table.insert(route,{to=Pets.pointAt(0,0,P),speed=speed})
		if turnAt then
			lineTo(route,0,turnAt,speed);lineTo(route,turnAt,turnAt*.4,speed);lineTo(route,turnAt*.4,U,speed)
		else lineTo(route,0,U,speed)end
		table.insert(route,{to=TOP,speed=speed})
		table.insert(route,{wait=6})
		table.insert(route,{to=Pets.pointAt(U,0,P),speed=speed})
		lineTo(route,U,0,speed)
		table.insert(route,{to=LAWN,speed=speed})
		table.insert(route,{wait=6})
		return route
	end
	local function drive(routes,label)
		local c=rig(#routes)
		local starts={}
		for id,route in ipairs(routes)do starts[id]=route.delay or 0 end
		local function input(id,t)
			local route=routes[id]
			local ground,look=ownerAt(route,math.max(0,t-starts[id]))
			local root=ground+Vector3.new(0,3,0)
			local right=Vector3.new(-look.Z,0,look.X)
			local offset=root-look*3+right*2.6
			local anchor=Pets.anchor(root,offset,P)or Vector3.new(offset.X,ground.Y,offset.Z)
			return {petId="pip",owned=true,alive=true,characterId=1,mode="Room",position=root,anchor=anchor,
				yaw=math.atan2(look.X,look.Z),charmVisible=true}
		end
		local stats={hops=0,terraceLag={},stall=0}
		local reachedTop,petTop={}, {}
		local last,lastMove={}, {}
		local duration=0
		for id,route in ipairs(routes)do
			local total=starts[id]
			local at=route.start
			for _,step in ipairs(route)do total+=if step.wait then step.wait else(step.to-at).Magnitude/step.speed;if step.to then at=step.to end end
			duration=math.max(duration,total)
		end
		local frame=1/30
		local seq={}
		while c.now<duration+4 do
			if math.floor(c.now/.5+1e-6)~=math.floor((c.now-frame)/.5+1e-6)or c.now==0 then
				for id=1,#routes do c.inputs[id]=input(id,c.now)end
				c.garden:step(.5,c.inputs)
			end
			for id=1,#routes do
				local actor=c.garden.actors[id]
				local owner=c.inputs[id]
				if actor and owner then
					local sample=Activity.sample(actor,c.now)
					local at=sample.position
					local tag=label.." pet "..id.." t "..string.format("%.2f",c.now)
					local hopSeq=actor.hop and actor.hop.seq or 0
					if hopSeq~=(seq[id]or 0)then
						seq[id]=hopSeq;stats.hops+=1
						local from=Activity.vector(actor.hop.from)
						local function v(p)return string.format("(%.1f, %.1f, %.1f) %s u %.1f",p.X,p.Y,p.Z,Pets.zone(p,P),Pets.project(p,P).u)end
						stats.why=string.format("%s at t %.1f from %s to %s, owner %s",tostring(actor.hop.why),c.now,v(from),v(at),v(owner.position))
						local z=Pets.zone(at,P)
						if z=="path"then assert(not Pets.onFlight(Pets.project(at,P).u,P),tag.." landed on the flight")end
					end
					onTread(at,tag)
					-- The pet on the terrace within 6 s of its owner.
					local ownerUp=Pets.zone(owner.position,P)=="terrace"and Tier.inPiece(Tier.Pieces[1],owner.position.X,owner.position.Z,-3)
					if ownerUp and not reachedTop[id]then reachedTop[id]=c.now end
					if not ownerUp then reachedTop[id]=nil;petTop[id]=nil end
					if reachedTop[id]and not petTop[id]and Pets.zone(at,P)=="terrace"then
						petTop[id]=true;table.insert(stats.terraceLag,c.now-reachedTop[id])
					end
					if reachedTop[id]and not petTop[id]then assert(c.now-reachedTop[id]<=6,tag.." not on the terrace 6 s after its owner")end
					-- No stall over 2 s while the owner is more than StuckNear away along the route.
					local gap=Pets.routeDistance(at,owner.anchor,P)or flat(at,owner.anchor)
					if last[id]and(at-last[id]).Magnitude>.02 then lastMove[id]=c.now end
					lastMove[id]=lastMove[id]or c.now
					if gap>Catchup.StuckNear+2 and Pets.zone(at,P)=="path"then
						assert(c.now-lastMove[id]<=2,tag.." stalled on the path "..string.format("%.1f",c.now-lastMove[id]).." s")
					end
					last[id]=at
				end
			end
			c.now+=frame
		end
		return stats
	end

	test("probe 4 offline: 10 climbs and 10 descents with one pet behind a walking owner, at 2 Hz decides",function()
		local lags,worst=0,0
		for k=1,10 do
			local speed=({8,10,12,14,16})[(k-1)%5+1]
			local stats=drive({climb(speed)},"climb "..k)
			lags+=#stats.terraceLag
			for _,lag in ipairs(stats.terraceLag)do worst=math.max(worst,lag)end
			-- A strolling owner (8 studs/s) is followed on foot; a faster one may be caught up with (18 studs behind, by design).
			if speed<=8 then assert(stats.hops==0,"climb "..k.." needed "..stats.hops.." catch-up hops: "..tostring(stats.why))end
		end
		assert(lags==10,"every climb ends with the pet on the terrace")
		assert(worst<=6,"worst terrace lag "..worst)
	end)

	test("probe 4 offline: three pets at once, and owners who turn back half way",function()
		local stats=drive({climb(16),(function()local r=climb(12);r.delay=1;return r end)(),(function()local r=climb(16,U*.6);r.delay=2;return r end)()},"three")
		assert(#stats.terraceLag==3)
		drive({climb(16,U*.85)},"turn back on the flight")
		drive({climb(9,U*.3)},"turn back low")
	end)

	test("GardenState hooks: the rest spots join while asked, no greeting across floors, carry leaves the park first",function()
		local Layout=require(Shared.GardenLayout)
		assert(Garden.tierRests==nil and #Garden.restAnchors()==#Layout.RestAnchors,"live: today's rest anchors")
		Garden.tierRests=function()return Pets.rests(P)end
		local all=Garden.restAnchors()
		assert(#all==#Layout.RestAnchors+3 and all[#all].id=="tier_turn")
		Garden.tierRests=nil
		-- Two pets 6 studs apart in plan, one on the path, one on the lawn under it: never a greeting.
		local c=rig(2)
		local up=Pets.pointAt(U*.5,0,P)
		local below=Vector3.new(up.X+4,4.625,up.Z+4)
		for id,at in ipairs({up,below})do
			c.inputs[id]={petId="pip",owned=true,alive=true,characterId=1,mode="Room",position=at+Vector3.new(0,3,0),anchor=at,yaw=0,charmVisible=true}
		end
		for _=1,60 do c.now+=.5;c.garden:step(.5,c.inputs);for _,a in pairs(c.garden.actors)do assert(a.action~="greet","a greeting across floors")end end
		-- The control: the same two, both on the lawn 6 studs apart, do greet.
		local g=rig(2)
		for id,at in ipairs({Vector3.new(-12,4.625,-80),Vector3.new(-8,4.625,-76)})do
			g.inputs[id]={petId="pip",owned=true,alive=true,characterId=1,mode="Room",position=at+Vector3.new(0,3,0),anchor=at,yaw=0,charmVisible=true}
		end
		local greeted=false
		for _=1,60 do g.now+=.5;g.garden:step(.5,g.inputs);for _,a in pairs(g.garden.actors)do greeted=greeted or a.action=="greet"end end
		assert(greeted,"the control pair greets on one floor")
		-- carry: refused in the park unless leavePark; then the director's leave runs first.
		local left={}
		c.garden.park={leave=function(_,actor)left[actor.ownerId]=true;actor.park=nil end,release=function()end,schedule=function()end,
			snapshot=function()return nil end,tick=function()end}
		c.garden.actors[1].park={parkId="grove"}
		assert(not c.garden:carry(1,Tier.Evacuation.at),"in the park: refused as before")
		assert(c.garden:carry(1,Tier.Evacuation.at,true)and left[1]and c.garden.actors[1].park==nil)
		c.garden.park=nil
	end)

	return{passed=#cases,cases=cases}
end
