-- Studio Client. Garden life, the maths (LifeSim, ALIVE-LIFE-BUILD-PLAN-2026-11-22): petals follow the wind under the live
-- cap, bubbles one every 3 s ahead of the camera and never in the way, butterflies over the patches within reach, the
-- bird's land / hop / stay / leave, caps per budget level, and the same garden for the same seed. Pure, no instances.
-- Dewdrops (FRUIT-LOOK): caps, stems, the wind-only trigger, the grove as a pure function of the server time (any
-- window or refresh rhythm gives the same drops), the flight numbers, landing rejection (finds, course, kerb, station,
-- water, too low; never the camera), the pet bat, and drawing (cap, reach, race, near-camera fade) never changing it.
-- Usage: require(PlayerScripts.Client.ZZSpecs.LifeSim)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="LifeSim").
return function(client)
	local Sim=require(client.LifeSim)
	local Wind=require(client.Wind)
	local Spots=require(client.LifeSpots)
	local Perches=require(client.AmbientPerches)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local T0=1795300000

	test("caps per budget level: 40/20/0 petals, 8/4/0 bubbles, 4/2/0 butterflies, 3/2/0 birds; 30 and 15 Hz, nothing at 2",function()
		for kind,want in pairs({petals={40,20,0},bubbles={8,4,0},butterflies={4,2,0},birds={3,2,0}})do
			for level=0,2 do assert(Sim.cap(kind,level)==want[level+1],kind.." at "..level)end
		end
		assert(near(Sim.rate(0),1/30)and near(Sim.rate(1),1/15)and Sim.rate(2)==nil)
		assert(Sim.level(nil)==0 and Sim.level(0/0)==0 and Sim.level(7)==2 and Sim.level(-1)==0)
	end)

	test("petal rate: none in the breeze, 7 a second at a full gust, never more",function()
		assert(Sim.petalRate(0)==0 and Sim.petalRate(.25)==0 and Sim.petalRate(Wind.Breeze)==0)
		assert(near(Sim.petalRate(1),7)and Sim.petalRate(2)==7 and Sim.petalRate(0/0)==0 and Sim.petalRate(nil)==0)
		assert(Sim.petalRate(.625)>3.4 and Sim.petalRate(.625)<3.6)
		assert(Sim.PetalLife==6.5)
		-- Through real gusts at one crown: some petals, and the rate only ever follows Wind.at.
		local crown=Spots.Crowns[1].position
		local petals=Sim.Petals.new()
		local total,most=0,0
		for i=0,6000 do
			local now=T0+i/30
			local n=petals:step(now,1/30,{Wind.at(crown,now),false,false},40)
			total+=n[1];assert(n[2]==0 and n[3]==0,"no emitter, no petals")
			most=math.max(most,petals:count(now))
		end
		assert(total>20,"a gust drops petals: "..total)
		assert(most<=40,"live cap "..most)
	end)

	test("petals: a gust burst of 6 when the wind first passes .6, re-armed below .3, out of the same room",function()
		local petals=Sim.Petals.new()
		local function at(wind,cap)return petals:step(0,0,{wind},cap or 40)[1]end
		assert(at(.5)==0,"under .6: no burst")
		assert(at(.6)==6,"the burst")
		assert(at(.9)==0 and at(.4)==0,"once a gust")
		assert(at(.29)==0 and at(.7)==6,"re-armed below .3")
		local full=Sim.Petals.new()
		assert(full:step(0,0,{.7},4)[1]==4,"the cap cuts a burst")
		assert(full:step(0,0,{.8},40)[1]==0,"and the rest is spent, not saved")
		local slot=Sim.Petals.new()
		slot:step(0,0,{.7},40);slot:step(0,0,{false},40)
		assert(slot:step(0,0,{.7},40)[1]==6,"a new crown on the slot bursts again")
		-- A 4 s full gust: about 28 + 6 off one crown, never over the cap.
		local gust=Sim.Petals.new()
		local total=0
		for i=1,120 do total+=gust:step(i/30,1/30,{1},40)[1]end
		assert(total>=33 and total<=35,"a 4 s gust: "..total)
	end)

	test("petals: the live cap holds across emitters and a lull never ends in a burst",function()
		local petals=Sim.Petals.new()
		local now=0
		local peak=0
		for _=1,600 do
			now+=1/30
			local n=petals:step(now,1/30,{1,1,1},20)
			peak=math.max(peak,petals:count(now))
			for _,k in ipairs(n)do assert(k<=(if now<=1/30+1e-9 then Sim.PetalBurst else 1),"one step emits at most a petal per emitter")end
		end
		assert(peak==20,"level 1 cap "..peak)
		assert(#petals:step(now,1/30,{1,1,1},0)==3 and petals:count(now)<=20)
		local zero=petals:step(now+.1,1/30,{1,1,1},0)
		assert(zero[1]+zero[2]+zero[3]==0,"level 2 emits nothing")
		petals:clear();assert(petals:count(now)==0)
	end)

	test("bubbles: one every 3 s while allowed and under the cap; a skipped slot is not saved up",function()
		local b=Sim.Bubbles.new(5)
		local now,made=0,0
		assert(not b:due(now,8,true),"the first slot starts the clock")
		for _=1,30*60 do
			now+=1/30
			if b:due(now,8,true)then made+=1;local kind=b:emit(now);assert(kind=="small"or kind=="large",tostring(kind))end
		end
		assert(made>=19 and made<=20,"one per 3 s: "..made)
		local roll=Sim.Bubbles.new(9)
		local small=0
		for i=1,1000 do if roll:emit(i)=="small"then small+=1 end end
		assert(small>=550 and small<=650,"60% small: "..small)
		assert(b:count(now)<=8 and b:count(now)>=3,"life 9 s")
		local before=b:count(now)
		for _=1,30*20 do now+=1/30;assert(not b:due(now,8,false),"a menu starts none")end
		assert(b:count(now)==0 and before>0)
		local burst=0
		for _=1,4 do now+=1/30;if b:due(now,8,true)then burst+=1 end end
		assert(burst<=1,"no burst after a menu")
		local full=Sim.Bubbles.new(1);full:due(0,4,true)
		local n=0
		for i=1,200 do if full:due(i*3,4,true)then full:emit(i*3);n+=1 end;assert(full:count(i*3)<=4)end
		assert(n>0)
	end)

	test("bubble spots: 10 to 16 ahead, never near the camera, a station, the pad or a live course",function()
		local r=Random.new(11)
		local camera=CFrame.lookAt(Vector3.new(0,8,0),Vector3.new(0,8,-10))
		for _=1,200 do
			local spot=assert(Sim.bubbleSpot(camera,r,{}))
			local ahead=-(spot.Z-0)
			assert(ahead>=10-1e-6 and ahead<=16+1e-6 and math.abs(spot.X)<=4+1e-6,"ahead "..ahead)
			assert((spot-camera.Position).Magnitude>=6)
		end
		local station={stations={Vector3.new(0,4,-13)}}
		local refused=0
		for _=1,200 do if not Sim.bubbleSpot(camera,r,station)then refused+=1 end end
		assert(refused>150,"a station ahead refuses most spots: "..refused)
		local spot,why=Sim.bubbleSpot(camera,Random.new(1),{stations={Vector3.new(0,4,-13)},pad={x=0,z=-13,r=3}})
		assert(spot==nil and(why=="station"or why=="pad"))
		local line={-50,-13,50,-13}
		local live,idle=0,0
		for _=1,200 do
			if not Sim.bubbleSpot(camera,r,{course=line})then live+=1 end
			if not Sim.bubbleSpot(camera,r,{})then idle+=1 end
		end
		assert(live>40 and idle==0,"the course only while live: "..live.." / "..idle)
		assert(Sim.bubbleSpot(nil,r,{})==nil)
		local _,reason=Sim.clear(Vector3.new(1,8,0),{camera=Vector3.new(0,8,0)})
		assert(reason=="camera")
	end)

	test("butterflies: within 60 studs, at most the cap, one of each colour, rest 2 to 4 s, never too low",function()
		local patches={}
		for i=1,12 do patches[i]=Vector3.new(i*8,4,0)end
		local flies=Sim.Butterflies.new(4)
		local world={camera=Vector3.new(0,10,10),stations={}}
		local now,rested,seen=0,0,{}
		for _=1,30*120 do
			now+=1/30
			local list=flies:step(now,1/30,world,patches,4,false)
			assert(#list<=4)
			local colours={}
			for _,b in ipairs(list)do
				assert(not colours[b.colour],"colour twice");colours[b.colour]=true
				assert((b.patch-world.camera).Magnitude<=60,"patch out of reach")
				assert(b.position.Y>=b.patch.Y+.3-1e-6,"too low "..b.position.Y)
				assert((Vector3.new(b.position.X,0,b.position.Z)-Vector3.new(b.patch.X,0,b.patch.Z)).Magnitude<=3+1e-6,"wandered off")
				if b.mode=="rest"then
					local first=seen[b.restUntil]or now
					seen[b.restUntil]=first
					assert(b.restUntil-first<=4+1e-6 and b.restUntil-first>=2-1/15,"rest "..(b.restUntil-first))
				end
				local parts=Sim.butterflyParts(Sim.butterflyRoot(b,now),Sim.butterflyFlap(b,now,true,false))
				assert(#parts==3)
			end
		end
		for _ in pairs(seen)do rested+=1 end
		assert(rested>0,"they rest on the flowers")
		assert(#flies:step(now,1/30,world,patches,2,false)<=2,"the cap shrinks at once")
		assert(#flies:step(now,1/30,world,patches,4,true)==0,"Reduced Motion: no flight")
		world.camera=Vector3.new(500,10,0)
		for _=1,10 do now+=1;flies:step(now,1,world,patches,4,false)end
		assert(#flies.list==0,"none beyond reach")
		local station=Sim.Butterflies.new(4)
		for _=1,30 do now+=1;station:step(now,1,{camera=Vector3.new(8,10,0),stations={Vector3.new(8,4,0),Vector3.new(16,4,0)}},{patches[1],patches[2]},4,false)end
		assert(#station.list==0,"no patch by a station")
	end)

	test("flap: two poses at 7.5 Hz (+50 / -20 and +60 / -15), held at level 1, a slow sine at rest",function()
		assert(near(Sim.birdFlap(true,false),math.rad(50))and near(Sim.birdFlap(false,false),math.rad(-20))and Sim.birdFlap(true,true)==0)
		local b={mode="fly",phase=0}
		assert(near(Sim.butterflyFlap(b,0,true,false),math.rad(60))and near(Sim.butterflyFlap(b,0,false,false),math.rad(-15)))
		assert(near(Sim.butterflyFlap(b,0,false,true),math.rad(30)))
		b.mode="rest"
		for t=0,4,.1 do local phi=Sim.butterflyFlap(b,t,true,false);assert(phi>=math.rad(20)-1e-6 and phi<=math.rad(70)+1e-6)end
	end)

	test("LOOK-R2 poses: bird eyes, beak and wings (perched back and down, flying tips out); butterfly wings laid flat",function()
		local function close(a,b)return(a-b).Magnitude<1e-4 end
		local root=CFrame.new(0,0,0)
		local perched=Sim.birdParts(root,"perch",0,0)
		assert(#perched==6)
		assert(close(perched[2].Position,Vector3.new(.425,.128,-.357))and close(perched[6].Position,Vector3.new(-.425,.128,-.357)))
		assert(close(perched[3].Position,Vector3.new(0,-.04,-.64)))
		assert(perched[2].RightVector.X>0 and perched[2].RightVector.Z<0 and perched[6].RightVector.X>0 and perched[6].RightVector.Z>0,"each disc's axis runs out and forward (its outer cap: Right on the right eye, Left on the left)")
		assert(close(perched[4].Position,Vector3.new(-.60,-.06,.13))and close(perched[5].Position,Vector3.new(.60,-.06,.13)))
		for i=4,5 do
			local tip=-perched[i].UpVector -- the texture is tip-down
			assert(tip.Y<-.5 and tip.Z>.75,"perched tip back and down: "..tostring(tip))
		end
		local flicked=Sim.birdParts(root,"perch",1,0)
		assert(-flicked[4].UpVector.X< -perched[4].UpVector.X and -flicked[5].UpVector.X>-perched[5].UpVector.X,"the flick swings the tips out")
		for _,phi in ipairs({math.rad(50),math.rad(-20)})do
			local flying=Sim.birdParts(root,"fly",0,phi)
			local left,right=-flying[4].UpVector,-flying[5].UpVector
			assert(left.X<0 and right.X>0,"tips out on both sides")
			assert(near(left.Y,right.Y,1e-4),"the two wings mirror")
			assert((phi>0)==(right.Y>0),"up on the up stroke")
		end
		local wings=Sim.butterflyParts(root,0)
		assert(close(wings[2].Position,Vector3.new(-.40,.03,0))and close(wings[3].Position,Vector3.new(.40,.03,0)))
		for i=2,3 do
			assert(close(wings[i].UpVector,Vector3.new(0,0,-1)),"image top forward")
			assert(close(wings[i].LookVector,Vector3.new(0,-1,0)),"Front face down, so Back is up")
		end
	end)

	test("birds: a chirp lands one on its perch's crown in .8 s, a repeat chirp hops, it stays 8 to 20 s",function()
		local spot=Vector3.new(10,14,10)
		local birds=Sim.Birds.new(7)
		local world={camera=Vector3.new(30,12,30),stations={}}
		assert(birds:chirp(0,5,spot,3,world,false)=="land")
		local bird=birds.list[1]
		assert(bird.colour==5%3 and(bird.from-spot).Magnitude>=9)
		birds:step(.4,world,false,3);assert(bird.state=="land"and bird.wings=="fly")
		birds:step(.81,world,false,3);assert(bird.state=="sit"and bird.wings=="perch")
		birds:step(1.2,world,false,3)
		assert((bird.root.Position-(spot+Vector3.new(0,.56,0))).Magnitude<1e-3,"sits .56 over the crown top")
		local parts=Sim.birdParts(bird.root,bird.wings,bird.flick,0)
		assert(#parts==6)
		assert(birds:chirp(1.3,5,spot,3,world,false)=="hop")
		birds:step(1.3+.11,world,false,3)
		assert(bird.root.Position.Y>spot.Y+.56+.2,"up in the hop")
		assert(bird.flick==1,"wings flick in the first .12 s")
		birds:step(1.3+.5,world,false,3);assert(bird.hopAt==nil and bird.flick==0)
		local stay=bird.stayUntil
		assert(stay>=8 and stay<=20,"stay "..stay)
		local t=1.8
		while bird.state=="sit"and t<25 do t+=.1;birds:step(t,world,false,3)end
		assert(bird.state=="leave"and t>=stay-.11,"leaves when its stay is over")
		t+=.04;birds:step(t,world,false,3);assert(bird.wings=="perch","crouches first")
		t+=.5;birds:step(t,world,false,3);assert(bird.wings=="fly")
		t+=1;birds:step(t,world,false,3);assert(#birds.list==0,"gone after the arc")
	end)

	test("birds: the player within 12 studs sends it off, away from the player; the 4th is refused; stations and the camera too",function()
		local birds=Sim.Birds.new(2)
		local world={camera=Vector3.new(0,20,40),stations={Vector3.new(100,4,100)}}
		for i=1,3 do assert(birds:chirp(0,i,Vector3.new(i*20,14,0),3,world,false)=="land")end
		local result,why=birds:chirp(0,4,Vector3.new(80,14,0),3,world,false)
		assert(result==nil and why=="cap","4th: "..tostring(why))
		assert(birds:chirp(0,9,Vector3.new(100,14,103),9,world,false)==nil,"by a station")
		assert(select(2,birds:chirp(0,9,Vector3.new(0,20,43),9,world,false))=="camera")
		assert(select(2,birds:chirp(0,9,nil,9,world,false))=="spot","a perch with no landing")
		for t=0,1,.1 do birds:step(t,world,false,3)end
		world.player=Vector3.new(20,10,5)
		birds:step(1.1,world,false,3)
		local first=birds:find(1)
		assert(first.state=="leave"and first.away.Z<0,"flies away from the player")
		assert(birds:find(2).state=="sit")
		birds:step(1.2,world,false,2)
		assert(#birds.list==2,"the cap shrinks at once")
	end)

	test("Reduced Motion: a bird is just there, folded; no hop, no turns, gone without an arc",function()
		local birds=Sim.Birds.new(3)
		local spot=Vector3.new(0,14,0)
		local world={camera=Vector3.new(0,10,30)}
		assert(birds:chirp(0,3,spot,3,world,true)=="land")
		birds:step(0,world,true,3)
		local bird=birds.list[1]
		assert(bird.state=="sit"and bird.wings=="perch"and(bird.root.Position-(spot+Vector3.new(0,.56,0))).Magnitude<1e-6)
		assert(birds:chirp(.5,3,spot,3,world,true)==nil,"no hop")
		local yaw=bird.yaw
		for t=0,7,.1 do birds:step(t,world,true,3)end
		assert(bird.yaw==yaw,"no turns")
		world.player=spot
		birds:step(7.1,world,true,3)
		assert(#birds.list==0,"gone at once")
		-- In flight when Reduced Motion comes on: it sits at once.
		assert(birds:chirp(8,3,spot,3,{},false)=="land")
		birds:step(8.2,{},true,3)
		assert(birds.list[1].state=="sit")
	end)

	test("the same seed and the same calls give the same garden",function()
		local function run(seed)
			local out={}
			local birds,flies,bubbles=Sim.Birds.new(seed),Sim.Butterflies.new(seed),Sim.Bubbles.new(seed)
			local patches={Vector3.new(5,4,0),Vector3.new(-5,4,8),Vector3.new(12,4,-6)}
			local world={camera=Vector3.new(0,10,20),stations={}}
			bubbles:due(0,8,true)
			for i=1,600 do
				local now=i/30
				if i%90==0 then birds:chirp(now,i//90,Vector3.new(i//90*7,14,0),3,world,false)end
				for _,b in ipairs(birds:step(now,world,false,3))do table.insert(out,string.format("%.4f",b.root.Position.Y))end
				for _,f in ipairs(flies:step(now,1/30,world,patches,4,false))do table.insert(out,string.format("%.4f %.4f",f.position.X,f.position.Z))end
				if bubbles:due(now,8,true)then local spot=Sim.bubbleSpot(CFrame.new(0,8,0),bubbles.random,world);table.insert(out,tostring(spot and spot.X))end
			end
			return table.concat(out,"|")
		end
		assert(run(42)==run(42),"seeded")
		assert(run(42)~=run(43),"a different seed is a different garden")
	end)

	test("LifeSpots: landings line up with AmbientPerches, sit on crowns away from stations, and the crowns exist",function()
		assert(Spots.Perches==#Perches,"built against "..Spots.Perches.." perches, AmbientPerches has "..#Perches)
		local stations={Vector3.new(-31,4,-11),Vector3.new(-17,4,-15),Vector3.new(-46,4,-9),Vector3.new(-30,4,18.5),Vector3.new(96,4,66)}
		local n=0
		for index,landing in pairs(Spots.Landings)do
			n+=1
			assert(index>=1 and index<=#Perches,"index "..index)
			local perch=Perches[index]
			assert(near(landing.X,perch.X,3)and near(landing.Z,perch.Z,3),"landing "..index.." is on its own tree")
			assert(landing.Y>perch.Y,"on top of the crown, not inside it: "..index)
			for _,s in ipairs(stations)do assert(Sim.flat(landing,s)>=8,"by a station: "..index)end
		end
		assert(n>=25 and n<#Perches,"stale perches dropped: "..n)
		assert(#Spots.Crowns>=8)
		for _,crown in ipairs(Spots.Crowns)do assert(crown.size.X>5 and crown.size.Y>3)end
	end)

	-- Dewdrops (WORLD-PASS-2026-11-22 item 3; FRUIT-LOOK) ----------------------------------------------------------
	local F=Sim.Fruit
	local CROWN={position=Vector3.new(0,12,0),size=Vector3.new(10,6,10)}
	local function flatWorld(extra)
		local world={groundY=function()return 4 end,safe=function()return true end,stations={},finds={},kerbs={}}
		for k,v in pairs(extra or {})do world[k]=v end
		return world
	end

	test("Dewdrops: caps 16/8/0 hanging and 3/2/0 loose; 2 or 3 a crown under the lower skirt, the same every time",function()
		for level=0,2 do
			assert(Sim.cap("fruit",level)==({16,8,0})[level+1]and Sim.cap("loose",level)==({3,2,0})[level+1],"level "..level)
		end
		assert(F.pool==16 and F.reach==90 and F.chance==.35 and F.dropAt==.8)
		local total,twoOrMore=0,0
		for i,crown in ipairs(Spots.Crowns)do
			local stems=Sim.fruitStems(i,crown)
			local again=Sim.fruitStems(i,crown)
			assert(#stems==#again and #stems<=3,"crown "..i)
			total+=#stems
			if #stems>=2 then twoOrMore+=1 end
			local top=crown.position.Y+crown.size.Y/2
			for j,slot in ipairs(stems)do
				assert(slot.stem==again[j].stem and slot.key==Sim.fruitKey(i,slot.k),"seeded")
				assert(near(slot.stem.Y,top-.8*crown.size.Y,1e-4),"just inside the lower skirt")
				assert(near(Sim.flat(slot.stem,crown.position),.36*crown.size.X,1e-3),"out .36 of the width")
				-- Hanging, the image centre .64 under the stem tip; a sway swings it downwind and keeps the tip.
				local still=Sim.fruitHang(slot.stem,0,1)
				assert(near((slot.stem-still).Magnitude,.64,1e-6)and still.Y<slot.stem.Y)
				local swung=Sim.fruitHang(slot.stem,15,1)
				assert(near((slot.stem-swung).Magnitude,.64,1e-6)and(swung-still):Dot(Wind.Direction)>0)
			end
		end
		assert(twoOrMore>=#Spots.Crowns*.6,"2 or 3 on most crowns: "..twoOrMore.." of "..#Spots.Crowns)
		assert(total<=36)
		assert(Sim.fruitStems(1,nil)[1]==nil and #Sim.fruitStems("x",CROWN)==0)
		-- Sway: 3 to 15 degrees, toward the wind; none when still.
		assert(Sim.fruitSway(1,T0,1,true)==0)
		for i=0,200 do
			local a=Sim.fruitSway(2,T0+i/10,1,false)
			assert(math.abs(a)<=15+1e-9)
			assert(math.abs(Sim.fruitSway(2,T0+i/10,0,false))<=3+1e-9)
		end
	end)

	test("Dewdrops: the trigger is the wind alone: a gust whose peak passes .8 lets go the first 1/60 s it does",function()
		local hits,calms=0,0
		local N0=math.floor(T0/Wind.Slot)
		for _,crown in ipairs(Spots.Crowns)do
			local at=crown.position
			for n=N0,N0+40 do
				local t=Sim.fruitTrigger(at,n)
				local start=Wind.start(n)+at:Dot(Wind.Direction)/Wind.Speed
				if t then
					hits+=1
					assert(t>=start-1e-9 and t<=start+Wind.Rise+1e-9,"on the way up")
					assert(Wind.at(at,t)>=.8,"past .8")
					assert(t-start<1e-9 or Wind.at(at,t-1/60)<.8,"the first step that does")
					assert(Sim.fruitTrigger(at,n)==t,"the same every call")
				else
					calms+=1
					assert(Wind.at(at,start+Wind.Rise)<.8 or Wind.peak(n)==0,"a calm gust lets nothing go")
				end
			end
		end
		assert(hits>40 and calms>40,"some gusts do, some do not: "..hits.." / "..calms)
		-- Candidates: the seeded chance, then the trigger, then the seeded slot of all the crown's stems.
		local stems=Sim.fruitStems(1,CROWN)
		local chance,calm,plans=0,0,0
		for n=N0,N0+200 do
			local plan,why=Sim.fruitCandidate(1,CROWN,stems,n,flatWorld())
			if plan then
				plans+=1
				assert(Wind.hash(n*16+1,13)<.35 and plan.start==Sim.fruitTrigger(CROWN.position,n))
				assert(plan.key==stems[math.floor(Wind.hash(n*16+1,14)*#stems)+1].key,"the seeded slot")
				assert(plan.id==plan.key..":"..n and table.isfrozen(plan),"shared and frozen")
			elseif why=="chance"then chance+=1;assert(Wind.hash(n*16+1,13)>=.35)
			elseif why=="calm"then calm+=1 end
		end
		assert(plans>10 and chance>plans and calm>0,plans.." / "..chance.." / "..calm)
		assert(select(2,Sim.fruitCandidate(1,CROWN,{},N0,flatWorld()))=="empty")
	end)

	-- The first gust from N0 on whose candidate passes in this world.
	local function firstCandidate(world)
		local stems=Sim.fruitStems(1,CROWN)
		local N0=math.floor(T0/Wind.Slot)
		for n=N0,N0+400 do
			local plan=Sim.fruitCandidate(1,CROWN,stems,n,world or flatWorld())
			if plan then return plan,n,stems end
		end
		error("no candidate")
	end

	test("Dewdrops: the grove is a pure function of the server time: any window, any refresh rhythm, the same drops",function()
		local world=flatWorld()
		local HOLD=Sim.FruitHold
		assert(HOLD==46.5)
		-- Client A refreshes every second from T0; client B joins 7 minutes late and refreshes every 3 s; C asks once.
		local function record(grove,from,to,every)
			local seen={}
			local now=from
			while now<=to do
				grove:refresh(now)
				for i=1,#grove.crowns do
					for _,drop in ipairs(grove.drops[i])do if drop.start<=now then seen[drop.id]=drop.start end end
				end
				now+=every
			end
			return seen
		end
		local a=record(Sim.Grove.new(Spots.Crowns,world),T0,T0+1500,1)
		local b=record(Sim.Grove.new(Spots.Crowns,world),T0+420,T0+1500,3)
		local c=Sim.Grove.new(Spots.Crowns,world)
		local once={}
		for i=1,#Spots.Crowns do for _,drop in ipairs(c:dropsAt(i,T0+420,T0+1500))do once[drop.id]=drop.start end end
		local n=0
		for id,start in pairs(once)do
			n+=1
			assert(a[id]==start,"A saw "..id)
			assert(b[id]==start,"B (late, slower) saw "..id)
		end
		for id,start in pairs(a)do if start>=T0+420 and start<=T0+1500 then assert(once[id],"nothing extra: "..id)end end
		assert(n>=20,"drops in 18 minutes: "..n)
		-- A slot never falls twice within HOLD; while empty it does not hang; it regrows to 1.12 and settles.
		local byKey={}
		for id,start in pairs(once)do
			local key=tonumber(string.match(id,"^(%d+):"))
			byKey[key]=byKey[key]or {}
			table.insert(byKey[key],start)
		end
		for _,starts in pairs(byKey)do
			table.sort(starts)
			for j=2,#starts do assert(starts[j]-starts[j-1]>=HOLD,"held "..(starts[j]-starts[j-1]))end
		end
		local key,start=next(once)
		key=tonumber(string.match(key,"^(%d+):"))
		c:refresh(start+1)
		assert(c:hanging(key,start+1)==nil,"empty after it falls")
		c:refresh(start+44)
		assert(c:hanging(key,start+44.9)==nil)
		c:refresh(start+45.3)
		local s1=c:hanging(key,start+45.3)
		assert(s1>0 and s1<1.12)
		c:refresh(start+46.05)
		assert(near(c:hanging(key,start+46.05),1.12,1e-6),"the overshoot")
		c:refresh(start+46.4)
		assert(c:hanging(key,start+46.4)>1)
		c:refresh(start+46.6)
		assert(c:hanging(key,start+46.6)==1,"settled")
		-- Islet crowns far over their ground and water never drop (the fruit stays on the tree).
		local low=Sim.Grove.new({{position=Vector3.new(0,30,0),size=Vector3.new(10,6,10)}},world)
		assert(#low:dropsAt(1,T0,T0+600)==0,"too far down")
	end)

	test("Dewdrops: the flight: tug, fall, two bounces with a squash, a roll downwind, 18 s at rest leaning 12, fade, gone",function()
		local plan=firstCandidate()
		local slot={stem=plan.stem}
		local loose=Sim.fruitLoose(plan,Vector3.new(1,0,0))
		assert(loose.plan==plan and loose~=plan and not table.isfrozen(loose),"a drawn copy; the shared plan untouched")
		local dir=Wind.Direction
		assert(near(Sim.flat(plan.release,plan.p1),1.2,1e-6)and(plan.p1-plan.release):Dot(dir)>0,"1.2 downwind in the fall")
		assert(near(Sim.flat(plan.p1,plan.p2),.5,1e-6)and near(Sim.flat(plan.p2,plan.p3),.2,1e-6))
		assert(plan.length>=1.6 and plan.length<=2.4 and near(Sim.flat(plan.p3,plan.p4),plan.length,1e-6),"roll 1.6 to 2.4")
		assert(plan.heading:Dot(dir)>=math.cos(math.rad(25))-1e-9,"within 25 of the wind")
		for _,p in ipairs({plan.p1,plan.p2,plan.p3,plan.p4})do assert(near(p.Y,4.5,1e-9),"centre .5 over the ground")end
		local times={plan.t1-plan.start,plan.t2-plan.t1,plan.t3-plan.t2,plan.t4-plan.t3,plan.t5-plan.t4,plan.t6-plan.t5,plan.gone-plan.t6}
		for i,want in ipairs({.15,.55,.34,.2,.9,18,1.2})do assert(near(times[i],want,1e-6),"phase "..i)end
		local p=Sim.fruitPose(loose,plan.start+.075)
		assert(p.phase=="tug"and near((p.position-slot.stem).Magnitude,.64,1e-6),"the stem still holds it")
		p=Sim.fruitPose(loose,plan.t1+.3)
		assert(p.phase=="fall"and p.position.Y<plan.release.Y and p.position.Y>plan.p1.Y)
		local mid=plan.release.Y+(plan.p1.Y-plan.release.Y)*.25
		assert(near(Sim.fruitPose(loose,plan.t1+.275).position.Y,mid,1e-6),"speeding up")
		p=Sim.fruitPose(loose,plan.t2+.01)
		assert(p.phase=="bounce"and p.w==1.15 and p.h==.85,"the landing squash")
		assert(Sim.fruitPose(loose,plan.t2+.1).w==1,"for .06 s")
		assert(near(Sim.fruitPose(loose,plan.t2+.17).position.Y,4.5+.9,1e-6),"bounce .9")
		assert(near(Sim.fruitPose(loose,plan.t3+.1).position.Y,4.5+.3,1e-6),"then .3")
		assert(Sim.fruitPose(loose,plan.t4+.01).w==1.15,"a squash on each landing")
		p=Sim.fruitPose(loose,plan.t4+.45)
		assert(p.phase=="roll"and Sim.flat(p.position,plan.p3)>plan.length*.5,"ease-out")
		-- The camera's right is +X here, so the roll spins clockwise when it goes +X on screen and rests leaning 12.
		local sr=if plan.heading.X<0 then -1 else 1
		local off=(loose.r4-12*sr)%360
		assert(math.min(off,360-off)<1e-6,"rests leaning 12 the way it went")
		assert(math.abs(loose.r4-(loose.r3+150*plan.length*sr))<=180,"about 150 a stud")
		local calm
		for i=0,180 do
			local now=plan.t5+.1*i
			if Wind.at(plan.p4,now)<=.6 then calm=now;break end
		end
		assert(calm,"a calm moment at rest")
		p=Sim.fruitPose(loose,calm)
		assert(p.phase=="rest"and p.position==plan.p4 and p.rotation==loose.r4 and p.transparency==0)
		p=Sim.fruitPose(loose,plan.t6+.6)
		assert(p.phase=="fade"and near(p.transparency,.5,1e-6)and near(p.w,.85,1e-6))
		assert(Sim.fruitPose(loose,plan.t6+1.2).phase=="gone")
		local again=firstCandidate()
		assert(again.p4==plan.p4 and again.start==plan.start and again.t6==plan.t6,"deterministic")
	end)

	test("Dewdrops: landing rejection: a find spot, the Dash course (idle too), a park kerb, a station, water, too low; never the camera",function()
		local plan,n,stems=firstCandidate()
		local rest=plan.p4
		local slot
		for _,s in ipairs(stems)do if s.key==plan.key then slot=s end end
		local function again(extra)return Sim.fruitPlan(1,CROWN,slot,n,plan.start,flatWorld(extra))end
		local cases={
			find={finds={rest+Vector3.new(2,0,0)}},
			course={course={rest.X-10,rest.Z+3,rest.X+10,rest.Z+3}},
			kerb={kerbs={{x=rest.X+17,z=rest.Z,rx=16,rz=11}}},
			station={stations={rest+Vector3.new(0,0,6)}},
			water={safe=function()return false end},
			low={groundY=function()return 12-15 end},
			ground={groundY=function()return nil end},
		}
		for want,extra in pairs(cases)do
			local got,why=again(extra)
			assert(got==nil and why==want,want..": "..tostring(why))
			assert(select(2,Sim.fruitCandidate(1,CROWN,stems,n,flatWorld(extra)))==want,"the candidate too")
		end
		assert(again({camera=rest+Vector3.new(0,1,0)}),"a camera on top of it changes nothing (shared)")
		assert(again({finds={rest+Vector3.new(3.1,0,0)}}),"3 studs from a find is fine")
		assert(again({course={rest.X-10,rest.Z+4.1,rest.X+10,rest.Z+4.1}}),"4 from the course is fine")
		assert(again({kerbs={{x=rest.X+18.1,z=rest.Z,rx=16,rz=11}}}),"past the kerb grown by 2")
		-- A rejected candidate leaves the fruit on the tree and does not hold the slot.
		local grove=Sim.Grove.new({CROWN},flatWorld({safe=function()return false end}))
		grove:refresh(plan.start+1)
		assert(#grove:active(plan.start+1)==0 and grove:hanging(plan.key,plan.start+1)==1,"still on the tree")
	end)

	-- A Loose drawing one grove's fruit: the shared plans active at `now` (one crown, a flat world).
	local function drawn()
		local grove=Sim.Grove.new({CROWN},flatWorld())
		local stems=Sim.fruitStems(1,CROWN)
		local N0=math.floor(T0/Wind.Slot)
		for n=N0,N0+400 do
			local c=Sim.fruitCandidate(1,CROWN,stems,n,flatWorld())
			if c then
				grove:refresh(c.start)
				for _,plan in ipairs(grove:active(c.start))do if plan.id==c.id then return plan,grove,Sim.Loose.new()end end
			end
		end
		error("no drop")
	end

	test("Dewdrops: a pet within 3 studs bats a drawn resting one once, 1 stud away (straight up when that spot fails), polled every 2 s",function()
		local plan,grove,draw=drawn()
		local world=flatWorld()
		local view={camera=Vector3.new(0,10,40),right=Vector3.new(1,0,0)}
		local rest=plan.p4
		local calls=0
		local pet=rest+Vector3.new(5,0,0)
		local function pets()calls+=1;return{pet}end
		local function step(now)grove:refresh(now);return draw:step(now,grove:active(now),view,world,pets,3,false)end
		step(plan.t5-.5)
		local loose=assert(draw.list[1],"drawn")
		assert(loose.plan==plan and calls==0,"no poll before it rests: the pets are not even asked")
		step(plan.t5)
		assert(calls==1 and not loose.bat,"5 studs: no bat")
		pet=rest+Vector3.new(2,0,0)
		step(plan.t5+1)
		assert(calls==1 and not loose.bat,"the next poll is 2 s on")
		local at=plan.t5+2
		step(at)
		assert(loose.bat and loose.bat.start==at and not loose.bat.straight,"batted")
		assert(near(Sim.flat(loose.rest,rest),1,1e-6)and(loose.rest-rest):Dot(Vector3.new(-1,0,0))>.99,"1 stud straight away from the pet")
		assert(plan.p4==rest and plan.bat==nil,"the shared plan never moves")
		local p=Sim.fruitPose(loose,at+.2)
		assert(p.phase=="bat"and near(p.position.Y,4.5+.7,1e-6),"a .7 hop")
		assert(Sim.fruitPose(loose,at+.41).w==1.15,"the landing squash")
		assert(near(Sim.fruitPose(loose,at+.475).position.Y,4.5+.2,1e-6),"one .2 bounce")
		p=Sim.fruitPose(loose,at+.6)
		assert(p.phase=="rest"and p.position==loose.rest)
		local before=loose.bat
		pet=loose.rest+Vector3.new(0,0,1)
		step(at+4)
		assert(loose.bat==before,"once in its life")
		-- A failed spot: straight up.
		local other=Sim.fruitLoose(plan,view.right)
		local blocked=flatWorld({finds={plan.p4+Vector3.new(-1.5,0,0)}})
		assert(Sim.fruitBat(other,plan.p4+Vector3.new(1,0,0),plan.t5,blocked,view.right))
		assert(other.bat.straight and other.rest==plan.p4,"straight up")
		assert(near(Sim.fruitPose(other,plan.t5+.2).position.Y,4.5+.7,1e-6))
	end)

	test("Dewdrops, drawing only: the loose cap, reach, a live race, the near-camera fade; none of it changes what falls",function()
		local plan,grove,draw=drawn()
		local world=flatWorld()
		local view={camera=Vector3.new(0,10,40),right=Vector3.new(1,0,0)}
		local now=plan.start+1
		draw:step(now,grove:active(now),view,world,nil,0,false)
		assert(#draw.list==0,"cap 0: not drawn")
		draw:step(now,grove:active(now),view,world,nil,3,false)
		assert(#draw.list==1,"room again: drawn mid-flight")
		draw:step(now+.1,grove:active(now+.1),view,world,nil,0,false)
		assert(#draw.list==0,"the cap shrank: trimmed at once")
		local live=Sim.Loose.new()
		live:step(now,grove:active(now),view,world,nil,3,true)
		assert(#live.list==0,"a live race draws none")
		live:step(now+1,grove:active(now+1),view,world,nil,3,false)
		assert(#live.list==0,"and never later")
		local racing=Sim.Loose.new()
		racing:step(now,grove:active(now),view,world,nil,3,false)
		racing:step(now+.5,grove:active(now+.5),view,world,nil,3,true)
		assert(racing.list[1].quick==now+.5,"a race starts: a quick fade")
		racing:step(now+.81,grove:active(now+.81),view,world,nil,3,true)
		racing:step(now+.82,grove:active(now+.82),view,world,nil,3,false)
		assert(#racing.list==0,"gone in .3 s, not drawn again")
		local far=Sim.Loose.new()
		far:step(now,grove:active(now),{camera=Vector3.new(500,0,0),right=view.right},world,nil,3,false)
		assert(#far.list==0,"past 120: not drawn")
		local close=Sim.Loose.new()
		local eye=plan.p4+Vector3.new(0,1,5.5)
		close:step(plan.t5,grove:active(plan.t5),{camera=eye,right=view.right},world,nil,3,false)
		assert(close.list[1].quick==plan.t5,"closer than 6 to the camera: a quick fade")
		-- After all that, the grove is untouched: the same active list and the same hanging.
		assert(#grove:active(now)==1 and grove:active(now)[1]==plan and grove:hanging(plan.key,now)==nil)
		assert(#grove:active(plan.gone+.01)==0,"gone from the grove once faded")
	end)

	return{passed=#cases,cases=cases}
end
