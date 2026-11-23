-- Studio Client. Garden life, the maths (LifeSim, ALIVE-LIFE-BUILD-PLAN-2026-11-22): petals follow the wind under the live
-- cap, bubbles one every 3 s ahead of the camera and never in the way, butterflies over the patches within reach, the
-- bird's land / hop / stay / leave, caps per budget level, and the same garden for the same seed. Pure, no instances.
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
		assert(#perched==5)
		assert(close(perched[2].Position,Vector3.new(0,.14,-.20))and close(perched[3].Position,Vector3.new(0,-.02,-.72)))
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
		assert(#parts==5)
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

	return{passed=#cases,cases=cases}
end
