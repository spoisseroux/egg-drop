-- Studio Client. Garden life, the maths (LifeSim, ALIVE-LIFE-BUILD-PLAN-2026-11-22; round 3, beta 12 QA L1-L3): leaves
-- at their rate under the live cap, their drift reach derived from the real wind, no spawn whose drift reaches a roof;
-- bubbles one every 3 s ahead of the camera and never in the way; butterflies over the patches within reach with one
-- continuous wing angle and glides, handing off to fireflies at dusk; the songbird's eight parts, its land / hop (in
-- pairs) / head snaps / tail flick / bounding flight / stay / leave; caps per budget level; the same garden for the
-- same seed. Pure, no instances.
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

	test("caps per budget level: 28/14/0 leaves (petals the same table), 8/4/0 bubbles, 4/2/0 butterflies, 3/2/0 birds; 30 and 15 Hz, nothing at 2",function()
		for kind,want in pairs({leaves={28,14,0},petals={28,14,0},bubbles={8,4,0},butterflies={4,2,0},birds={3,2,0}})do
			for level=0,2 do assert(Sim.cap(kind,level)==want[level+1],kind.." at "..level)end
		end
		assert(rawequal(Sim.Caps.petals,Sim.Caps.leaves),"petals is leaves under its old name")
		assert(near(Sim.rate(0),1/30)and near(Sim.rate(1),1/15)and Sim.rate(2)==nil)
		assert(Sim.level(nil)==0 and Sim.level(0/0)==0 and Sim.level(7)==2 and Sim.level(-1)==0)
	end)

	-- Falling leaves (beta 12 QA L2; GARDEN-LIFE-NEST-LOOK 2) ------------------------------------------------------
	local L=Sim.Leaf
	test("leaves: the drift reach is derived from real wind: every 12 s life over 3,000 s of gusts (the dial at 1 and 1.5) fits",function()
		-- The look's terminal speeds: a .7 studs a second lean when calm, 3.3 in a full gust, a 1.3 fall.
		local k=L.drag*math.log(2)
		local calm,full=Sim.leafWind(0,0):Dot(Wind.Direction)/k,Sim.leafWind(1,0):Dot(Wind.Direction)/k
		assert(near(calm,.72,.01)and near(full,3.32,.01)and near(-Sim.leafWind(.5,3).Y/k,1.3,.01),calm.." "..full)
		local along,across=0,0
		local position=Vector3.new(-60,20,50)
		local dial=Wind.Strength
		local ok,problem=pcall(function()
			for _,strength in ipairs({1,1.5})do
				Wind.Strength=strength
				for i=0,3999 do
					local a,c=Sim.leafDrift(T0+i*.75,L.life[1][2],position,1/15)
					along=math.max(along,a);across=math.max(across,math.abs(c))
				end
			end
		end)
		Wind.Strength=dial
		assert(ok,problem)
		print(string.format("leaf drift over a 12 s life: along %.2f (reach %d), across %.2f (side %d)",along,L.reach,across,L.side))
		assert(along<=L.reach and across<=L.side,"the drift fits: "..along.." / "..across)
		assert(L.reach-along<2 and L.side-across<2,"and is not padded: "..along.." / "..across)
	end)

	test("leaves: 2.4 / 1.2 a second x (1 + .5 g), at most one a kind a step, the live cap exact, 55 / 30 / 15",function()
		local function run(level,g,seconds,cap,hz)
			local leaves=Sim.Leaves.new(3)
			local n,most,kinds=0,0,{0,0,0}
			hz=hz or 30
			for i=1,seconds*hz do
				local now=i/hz
				local out=leaves:step(now,1/hz,g,cap,level,function(_,r)return Vector3.new(r:NextNumber(),0,0)end)
				local seen={}
				for _,leaf in ipairs(out)do
					assert(not seen[leaf.kind],"one a kind a step");seen[leaf.kind]=true
					kinds[leaf.kind]+=1
				end
				n+=#out
				most=math.max(most,leaves:count(now))
			end
			return n,most,kinds
		end
		local n=run(0,0,100,1000);assert(n>=238 and n<=241,"calm, level 0: "..n)
		n=run(1,0,100,1000,15);assert(n>=118 and n<=121,"calm, level 1: "..n)
		n=run(0,1,100,1000);assert(n>=358 and n<=361,"full gust: "..n)
		assert(run(2,1,10,28)==0,"level 2: none")
		local _,most=run(0,1,120,28);assert(most==28,"the level 0 cap: "..most)
		_,most=run(1,1,120,14,15);assert(most==14,"the level 1 cap: "..most)
		local _,_,kinds=run(0,1,1000,100000)
		local total=kinds[1]+kinds[2]+kinds[3]
		for i,want in ipairs(L.share)do assert(math.abs(kinds[i]/total-want)<.03,"share "..i..": "..kinds[i]/total)end
		-- A refused spot is skipped, not redrawn: nothing counted, and the rate is spent the same.
		local skip=Sim.Leaves.new(3)
		local made=0
		for i=1,3000 do made+=#skip:step(i/30,1/30,0,1000,0,function()return nil end)end
		assert(made==0 and skip:count(100)==0)
		-- At the cap nothing piles up: one emit when room comes back, not a burst.
		local full=Sim.Leaves.new(5)
		local now=0
		for _=1,30*60 do now+=1/30;full:step(now,1/30,1,28,0,function()return Vector3.zero end)end
		local before=full:count(now)
		local burst=#full:step(now+.01,1/30,1,before+5,0,function()return Vector3.zero end)
		assert(burst<=1,"no burst: "..burst)
		assert(L.life[1][2]==12 and L.life[3][2]==10 and L.rate[1]==2.4 and L.rate[2]==1.2)
	end)

	test("leaf spots: in the 72-stud square 10 to 12 over the ground, none off the island, none whose drift reaches a roof",function()
		local r=Random.new(8)
		local flat={ground=function()return 4 end,cover={}}
		for _=1,300 do
			local spot=assert(Sim.leafSpot(r,Vector3.new(10,5,-20),flat))
			assert(math.abs(spot.X-10)<=36 and math.abs(spot.Z+20)<=36 and spot.Y>=14-1e-6 and spot.Y<=16+1e-6,tostring(spot))
		end
		local spot,why=Sim.leafSpot(r,Vector3.zero,{ground=function()return nil end})
		assert(spot==nil and why=="ground")
		-- The Studio probe's roofs (STUDIO-PROBES.md): the rotunda first, at (-60, 50) r 8.2; leaves on the beta now.
		assert(Sim.LeafCoverChecked==true and #Sim.LeafCover==6)
		local roof=Sim.LeafCover[1]
		assert(roof.name=="Rotunda"and roof.x==-60 and roof.z==50 and roof.r==8.2)
		local names={}
		for _,place in ipairs(Sim.LeafCover)do assert(place.r>0 and not names[place.name]);names[place.name]=true end
		assert(names.BridgeArch and names.WestColonnade and names.EastColonnade and names.StationRoof and names.BridgeArchSide)
		-- Stand under the rotunda: every spot that comes back drifts clear of its roof.
		local world={ground=function()return 14 end,cover={roof}}
		local refused=0
		for _=1,2000 do
			local at,reason=Sim.leafSpot(r,Vector3.new(roof.x,14,roof.z),world)
			if at then
				local line={at.X,at.Z,at.X+Wind.Direction.X*L.reach,at.Z+Wind.Direction.Z*L.reach}
				assert(Sim.lineDistance(roof.x,roof.z,line)>=roof.r+L.side,"drifts under the roof: "..tostring(at))
			else assert(reason=="Rotunda",tostring(reason));refused+=1 end
		end
		assert(refused>100 and refused<1900,"some refused, not all: "..refused)
		local function from(d)return roof.x+Wind.Direction.X*d,roof.z+Wind.Direction.Z*d end
		local only={roof}
		local function covered(d)local x,z=from(d);return Sim.leafCovered(x,z,only)end
		assert(covered(0)=="Rotunda","over the roof")
		assert(covered(-(L.reach-1))=="Rotunda","upwind within reach drifts in")
		assert(covered(-(L.reach+roof.r+L.side+1))==nil,"far upwind is fine")
		assert(covered(roof.r+L.side+1)==nil,"downwind of the roof is fine")
		-- The default list: under the bridge arch too.
		assert(Sim.leafCovered(5,20.6)=="BridgeArch")
		-- The cover list is a table: a probe row drops in.
		assert(Sim.leafCovered(0,0,{{name="Cave",x=0,z=0,r=5}})=="Cave")
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
				local parts=Sim.butterflyParts(Sim.butterflyRoot(b,now,0),Sim.butterflyFlap(b,now,0))
				assert(#parts==3)
			end
		end
		for _ in pairs(seen)do rested+=1 end
		assert(rested>0,"they rest on the flowers")
		assert(Sim.Butterfly.speed==.65)
		assert(#flies:step(now,1/30,world,patches,2,false)<=2,"the cap shrinks at once")
		assert(#flies:step(now,1/30,world,patches,4,true)==0,"Reduced Motion: no flight")
		world.camera=Vector3.new(500,10,0)
		for _=1,10 do now+=1;flies:step(now,1,world,patches,4,false)end
		assert(#flies.list==0,"none beyond reach")
		local station=Sim.Butterflies.new(4)
		for _=1,30 do now+=1;station:step(now,1,{camera=Vector3.new(8,10,0),stations={Vector3.new(8,4,0),Vector3.new(16,4,0)}},{patches[1],patches[2]},4,false)end
		assert(#station.list==0,"no patch by a station")
	end)

	test("butterfly wings: one continuous angle, no snap (flap, glides, landings, rests), glides 1.6 to 3.2 s apart for .6 to 1.1 s",function()
		local B=Sim.Butterfly
		local patches={Vector3.new(0,4,-10),Vector3.new(8,4,-12),Vector3.new(-8,4,-14),Vector3.new(4,4,-20)}
		local world={camera=Vector3.new(0,10,10),stations={}}
		for _,run in ipairs({{hz=30,level=0,most=32},{hz=15,level=1,most=50}})do
			local flies=Sim.Butterflies.new(9)
			local last,worst,rests,glidesSeen={},0,0,{}
			local now=0
			for _=1,run.hz*90 do
				now+=1/run.hz
				for _,b in ipairs(flies:step(now,1/run.hz,world,patches,4,false))do
					local phi=math.deg(Sim.butterflyFlap(b,now,run.level))
					assert(phi>=-17-1e-6 and phi<=77+1e-6,"angle "..phi)
					if last[b]then worst=math.max(worst,math.abs(phi-last[b]))end
					last[b]=phi
					if b.mode=="rest"and now-b.switchAt>=B.blend then
						rests+=1;assert(phi>=48-1e-6 and phi<=76+1e-6,"rest "..phi)
					end
					glidesSeen[b.glideAt]=b.glideEnd-b.glideAt
					assert(b.lastGlide==-math.huge or(b.glideAt-b.lastGlide<=3.2+1e-6 and b.glideAt-b.lastGlide>=1.6-1e-6),"glide gap")
				end
			end
			print(string.format("butterfly wing step at %d Hz: worst %.1f degrees (today's swap: 75)",run.hz,worst))
			assert(worst<=run.most,run.hz.." Hz: "..worst)
			assert(rests>0,"some rest")
			local n=0
			for _,length in pairs(glidesSeen)do n+=1;assert(length>=.6-1e-6 and length<=1.1+1e-6,"glide "..length)end
			assert(n>=4,"they glide: "..n)
		end
		-- In a glide the wings hold the shallow V (28) and the root sinks .25; flapping at 3.0 Hz, 22 +- 38.
		local b={mode="fly",phase=0,glideAt=10,glideEnd=11,lastGlide=-math.huge,position=Vector3.zero,heading=Vector3.new(0,0,-1),born=-10}
		assert(near(math.deg(Sim.butterflyFlap(b,10.5,0)),28,1e-6)and Sim.butterflyEnvelope(b,10.5)==0)
		assert(near(Sim.butterflyEnvelope(b,5),1)and near(Sim.butterflyEnvelope(b,11.125),.5))
		assert(near(math.deg(Sim.butterflyFlap(b,1/(4*3.0),0)),60,1e-4),"the top of the flap at 3.0 Hz")
		assert(near(math.deg(Sim.butterflyFlap(b,1/(4*2.2),1)),60,1e-4),"2.2 Hz at level 1")
		local level=table.clone(b);level.glideAt,level.glideEnd=100,101
		local sink=Sim.butterflyRoot(level,10.999,0).Position.Y-Sim.butterflyRoot(b,10.999,0).Position.Y
		assert(sink>.18 and sink<.32,"the glide sinks .25: "..sink)
		-- Each butterfly's glides are its own: the same timetable at 30 and 15 Hz.
		local function timetable(hz)
			local flies=Sim.Butterflies.new(21)
			local out,now={},0
			for _=1,hz*30 do
				now+=1/hz
				local first=flies:step(now,1/hz,world,patches,1,false)[1]
				if first and not out[#out]or(first and out[#out]~=first.glideAt-first.born)then table.insert(out,first.glideAt-first.born)end
			end
			return out
		end
		local a,c=timetable(30),timetable(15)
		assert(#a>=5)
		for i=1,math.min(#a,#c)do assert(near(a[i],c[i],1e-9),"glide "..i)end
	end)

	test("round 3 poses: the songbird's eight parts (head on its own, beads, beak, folded and flying wings, the tail); butterfly wings laid flat",function()
		local function close(a,b)return(a-b).Magnitude<1e-4 end
		local root=CFrame.new(0,0,0)
		local B,S=Sim.Bird,Sim.BirdShape
		local perched=Sim.birdParts(root,"perch",0,0,nil,B.tail,0)
		assert(#perched==8)
		-- QA-R2-LOOK 3: an egg tipped 20 nose-up, a head half its length set forward, a point, a long narrow tail.
		assert(close(perched[1].Position,Vector3.zero)and perched[1].LookVector.Y>.3 and perched[1].LookVector.Y<.36,"the body 20 nose-up")
		assert(close(perched[2].Position,Vector3.new(0,.28,-.30)),"the head")
		assert(close(perched[3].Position,Vector3.new(0,.26,-.57))and close(perched[3].LookVector,Vector3.new(0,0,-1)),"the beak off the head, straight out")
		assert(close(perched[4].Position,Vector3.new(.135,.32,-.42))and close(perched[5].Position,Vector3.new(-.135,.32,-.42)),"two eyes")
		assert(near(S.head/S.body.Z,.49,.02)and near(S.tail.Y/S.body.Z,.75,.02)and S.tail.X<S.body.X/2,"1 : 2 head, 3 : 4 tail, narrow")
		-- Beak tip to tail tip, about 1.59; overall length to height about 2.3 : 1.
		local beakTip=(perched[3]*CFrame.new(0,0,-S.beak.Z/2)).Position
		local tailTip=(perched[8]*CFrame.new(0,-S.tail.Y/2,0)).Position
		assert(near(tailTip.Z-beakTip.Z,1.59,.06),"length "..(tailTip.Z-beakTip.Z))
		local top=perched[2].Position.Y+S.head/2
		assert(near((tailTip.Z-beakTip.Z)/(top+B.lift),2.3,.35),"length : height "..(tailTip.Z-beakTip.Z)/(top+B.lift))
		-- The head turns on its own: eyes and beak go with it, the body does not.
		local turned=Sim.birdParts(root,"perch",0,0,CFrame.Angles(0,math.rad(40),0),B.tail,0)
		assert(close(turned[1].Position,perched[1].Position)and close(turned[2].Position,perched[2].Position))
		assert(turned[3].Position.X<-.1,"the beak swings with the head")
		assert(close(perched[6].Position,Vector3.new(-.25,.03,.11))and close(perched[7].Position,Vector3.new(.25,.03,.11)))
		for i=6,7 do
			local tip=-perched[i].UpVector -- the texture is tip-down
			assert(tip.Y<-.5 and tip.Z>.6,"folded tip back and down: "..tostring(tip))
			local at=(perched[i]*CFrame.new(0,-S.wing.Y/2,0)).Position
			assert(at.Z>S.tailAt.Z-.05 and math.abs(at.X)<.25,"the tips reach across the tail root: "..tostring(at))
		end
		local flicked=Sim.birdParts(root,"perch",1,0,nil,B.tail,0)
		assert(-flicked[6].UpVector.X< -perched[6].UpVector.X and -flicked[7].UpVector.X>-perched[7].UpVector.X,"the flick swings the tips out")
		for _,phi in ipairs({math.rad(65),math.rad(-35)})do
			local flying=Sim.birdParts(root,"fly",0,phi,nil,B.tail,0)
			local left,right=-flying[6].UpVector,-flying[7].UpVector
			assert(left.X<0 and right.X>0,"tips out on both sides")
			assert(near(left.Y,right.Y,1e-4),"the two wings mirror")
			assert((phi>0)==(right.Y>0),"up on the up stroke")
		end
		local bound=Sim.birdParts(root,"fly",0,math.rad(15),nil,B.tail,1)
		assert(close(bound[6].Position,perched[6].Position)and close(bound[7].Position,perched[7].Position),"tucked in the bound")
		local span=(Sim.birdParts(root,"fly",0,0,nil,B.tail,0)[7]*CFrame.new(0,-S.wing.Y/2,0)).Position.X*2
		assert(near(math.abs(span),1.76,.02),"span tip to tip "..span)
		-- The tail: its root at the rump, the tip back and 15 down at rest, in line with the back; the flick goes 5 above level.
		local tail=perched[8]
		local tip=-tail.UpVector
		assert(tip.Z>.9 and near(math.deg(math.asin(-tip.Y)),15,.5),"tip back and 15 down: "..tostring(tip))
		assert(tail.Position.Z>.5 and tail.Position.Y<0,"behind and under the rump")
		local up=-Sim.birdParts(root,"perch",0,0,nil,B.tailUp,0)[8].UpVector
		assert(up.Y>0 and near(math.deg(math.asin(up.Y)),5,.5),"a flick lifts it to 5 above level")
		local wings=Sim.butterflyParts(root,0)
		assert(close(wings[2].Position,Vector3.new(-.133,0,0))and close(wings[3].Position,Vector3.new(.133,0,0)),"span .52 (QA-R2-LOOK 4), from the mid-line")
		assert(math.abs(2*(.133+.24/2)-.52)<.02,"tip to tip about .52")
		assert(close(wings[1].Position,Vector3.new(0,0,-.013)),"the body .013 forward")
		for i=2,3 do
			assert(close(wings[i].UpVector,Vector3.new(0,0,-1)),"image top forward")
			assert(close(wings[i].LookVector,Vector3.new(0,-1,0)),"Front face down, so Back is up")
		end
	end)

	test("birds: a chirp lands one on its perch's crown in .8 s, a repeat chirp hops low (often twice), it stays 8 to 20 s",function()
		local B=Sim.Bird
		local spot=Vector3.new(10,14,10)
		local birds=Sim.Birds.new(7)
		local world={camera=Vector3.new(30,12,30),stations={}}
		assert(birds:chirp(0,5,spot,3,world,false)=="land")
		local bird=birds.list[1]
		assert(bird.colour==5%3 and(bird.from-spot).Magnitude>=9)
		birds:step(.4,world,false,3,0);assert(bird.state=="land"and bird.wings=="fly")
		birds:step(.81,world,false,3,0);assert(bird.state=="sit"and bird.wings=="perch")
		birds:step(.81+.08,world,false,3,0)
		assert(near(bird.tau,B.tailUp,1e-3),"the tail flicks up on landing: "..bird.tau)
		birds:step(1.2,world,false,3,0)
		assert(near(bird.tau,B.tail),"and back")
		assert((bird.root.Position-(spot+Vector3.new(0,Sim.Bird.lift,0))).Magnitude<1e-3,"sits on the crown top")
		local parts=Sim.birdParts(bird.root,bird.wings,bird.flick,bird.phi,bird.turn,bird.tau,bird.tuck)
		assert(#parts==8)
		bird.turnAt=math.huge -- no turn hop in the way
		assert(birds:chirp(1.3,5,spot,3,world,false)=="hop")
		birds:step(1.3+.09,world,false,3,0)
		assert(near(bird.root.Position.Y,spot.Y+Sim.Bird.lift+.16,1e-3),".16 high at the top: "..bird.root.Position.Y-spot.Y)
		assert(bird.flick==1,"wings flick in the first .12 s")
		birds:step(1.3+.18+.12+.09+.12+.2,world,false,3,0);assert(bird.hopAt==nil and bird.flick==0)
		-- 40% of hops come in pairs, .12 s apart.
		local pairs,n=0,0
		for i=1,600 do
			assert(birds:chirp(2+i*.001,5,spot,3,world,false)=="hop")
			n+=1
			if bird.hop2 then pairs+=1;assert(near(bird.hop2-bird.hopAt,B.hopTime+B.pairGap))end
		end
		assert(math.abs(pairs/n-.4)<.06,"pairs: "..pairs/n)
		local stay=bird.stayUntil
		assert(stay>=8 and stay<=20,"stay "..stay)
		local t=3
		while bird.state=="sit"and t<25 do t+=.1;birds:step(t,world,false,3,0)end
		assert(bird.state=="leave"and t>=stay-.11,"leaves when its stay is over")
		t+=.04;birds:step(t,world,false,3,0);assert(bird.wings=="perch","crouches first")
		t+=.2;birds:step(t,world,false,3,0);assert(bird.wings=="fly")
		t+=1.2;birds:step(t,world,false,3,0);assert(#birds.list==0,"gone after the arc")
	end)

	test("birds: the head snaps (.12 s) to a new look every .8 to 2.5 s and holds it; 30% with a cock; turns come with a hop",function()
		local B=Sim.Bird
		local birds=Sim.Birds.new(12)
		local world={camera=Vector3.new(30,12,30),stations={}}
		local spot=Vector3.new(0,14,0)
		assert(birds:chirp(0,3,spot,3,world,false)=="land")
		local bird=birds.list[1]
		bird.stayUntil=math.huge
		local snaps,cocks,lastAt,turns=0,0,nil,0
		local t=0
		while t<1200 do
			t+=1/30
			local turnBefore=bird.turnStart
			birds:step(t,world,false,3,0)
			if bird.turnStart~=turnBefore then turns+=1;assert(bird.hopAt==bird.turnStart,"a turn is a hop")end
			local head=bird.head
			if head.at~=lastAt and head.at>0 then
				if lastAt then
					local gap=head.at-lastAt
					assert(gap>=B.headEveryMin-1/30 and gap<=B.headEveryMax+1/30,"gap "..gap)
				end
				lastAt=head.at
				snaps+=1
				assert(math.abs(head.yaw)>=25 and math.abs(head.yaw)<=50,"yaw "..head.yaw)
				assert(head.roll==0 or math.abs(head.roll)==15)
				if head.roll~=0 then cocks+=1 end
				-- Held: the pose reaches the new look in .12 s and stays.
				local copy=table.clone(bird.head)
				local probe={state="sit",spot=spot,yaw=bird.yaw,landedAt=-math.huge,head=copy}
				Sim.birdPose(probe,head.at+.06,0)
				local mid=probe.turn
				Sim.birdPose(probe,head.at+.12,0)
				local done=probe.turn
				Sim.birdPose(probe,head.at+.5,0)
				assert((done.LookVector-probe.turn.LookVector).Magnitude<1e-6,"held")
				local moved=(mid.LookVector-done.LookVector).Magnitude+(mid.UpVector-done.UpVector).Magnitude
				assert(moved>1e-6 or(math.abs(copy.yaw-copy.fromYaw)<.5 and math.abs(copy.roll-copy.fromRoll)<.5),"still moving at .06 s")
			end
		end
		assert(snaps>600 and turns>200,"snaps "..snaps.." turns "..turns)
		assert(math.abs(cocks/snaps-.3)<.06,"cocks "..cocks/snaps)
	end)

	test("birds fly in bounds: two beats (5.5 Hz, 3.5 at level 1), then .22 s tucked with a .12 dip; no swap",function()
		local B=Sim.Bird
		local phi,tuck,dip=Sim.birdBeat(.07,0)
		assert(tuck==0 and dip==0 and phi>B.beatMid+20,"beating")
		local beating=2/5.5
		phi,tuck,dip=Sim.birdBeat(beating+.11,0)
		assert(tuck==1 and near(dip,.12,1e-6),"tucked, dipping")
		phi,tuck=Sim.birdBeat(beating+.22+.1,0)
		assert(tuck==0,"beating again: one cycle is .584 s")
		local slow=2/3.5
		assert(select(2,Sim.birdBeat(slow-.01,1))>0 and select(2,Sim.birdBeat(.4,1))==0,"level 1: .57 s of beats")
		-- Continuous: the wing tip never jumps between 1/120 s samples (a two-pose swap would move it a stud at once).
		local root=CFrame.new(0,0,0)
		local was
		for i=0,360 do
			local p,k=Sim.birdBeat(i/120,0)
			local frame=Sim.birdParts(root,"fly",0,math.rad(p),nil,20,k)[7].Position
			if was then assert((frame-was).Magnitude<.3,"a jump at "..i)end
			was=frame
		end
		assert(Sim.Bird.lift==.27 and B.hop==.16 and B.hopTime==.18 and B.flick==15)
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
		for t=0,1,.1 do birds:step(t,world,false,3,0)end
		world.player=Vector3.new(20,10,5)
		birds:step(1.1,world,false,3,0)
		local first=birds:find(1)
		assert(first.state=="leave"and first.away.Z<0,"flies away from the player")
		assert(birds:find(2).state=="sit")
		birds:step(1.2,world,false,2,0)
		assert(#birds.list==2,"the cap shrinks at once")
	end)

	test("Reduced Motion: a bird is just there, folded, head straight, tail at rest; no hop, no turns, gone without an arc",function()
		local birds=Sim.Birds.new(3)
		local spot=Vector3.new(0,14,0)
		local world={camera=Vector3.new(0,10,30)}
		assert(birds:chirp(0,3,spot,3,world,true)=="land")
		birds:step(0,world,true,3,0)
		local bird=birds.list[1]
		assert(bird.state=="sit"and bird.wings=="perch"and(bird.root.Position-(spot+Vector3.new(0,Sim.Bird.lift,0))).Magnitude<1e-6)
		assert(bird.still==true and bird.tau==Sim.Bird.tail and(bird.turn.LookVector-Vector3.new(0,0,-1)).Magnitude<1e-6)
		assert(birds:chirp(.5,3,spot,3,world,true)==nil,"no hop")
		local yaw=bird.yaw
		for t=0,7,.1 do birds:step(t,world,true,3,0);assert(bird.head.at==-math.huge,"no head snaps")end
		assert(bird.yaw==yaw,"no turns")
		world.player=spot
		birds:step(7.1,world,true,3,0)
		assert(#birds.list==0,"gone at once")
		-- Perched with its head cocked and mid-hop when Reduced Motion comes on: head straight and still at once.
		local live=Sim.Birds.new(4)
		assert(live:chirp(20,3,spot,3,{},false)=="land")
		local perched=live.list[1]
		perched.stayUntil=math.huge
		local t=20
		while perched.head.at==-math.huge and t<40 do t+=1/30;live:step(t,{},false,3,0)end
		assert(perched.head.at>-math.huge,"a head snap happened")
		perched.head.yaw,perched.head.roll,perched.head.fromYaw,perched.head.fromRoll=40,15,40,15
		assert(live:chirp(t,3,spot,3,{},false)=="hop")
		live:step(t+.05,{},true,3,0)
		assert((perched.turn.LookVector-Vector3.new(0,0,-1)).Magnitude<1e-6 and(perched.turn.UpVector-Vector3.new(0,1,0)).Magnitude<1e-6,"head straight")
		assert(perched.hopAt==nil and perched.tau==Sim.Bird.tail and perched.still==true,"no hop, tail at rest, still")
		assert(math.abs(perched.root.Position.Y-(spot.Y+Sim.Bird.lift))<1e-6,"sitting on the crown")
		-- In flight when Reduced Motion comes on: it sits at once.
		assert(birds:chirp(8,3,spot,3,{},false)=="land")
		birds:step(8.2,{},true,3,0)
		assert(birds.list[1].state=="sit")
	end)

	test("the same seed and the same calls give the same garden",function()
		local function run(seed)
			local out={}
			local birds,flies,bubbles=Sim.Birds.new(seed),Sim.Butterflies.new(seed),Sim.Bubbles.new(seed)
			local leaves=Sim.Leaves.new(seed)
			local patches={Vector3.new(5,4,0),Vector3.new(-5,4,8),Vector3.new(12,4,-6)}
			local world={camera=Vector3.new(0,10,20),stations={}}
			local leafWorld={ground=function()return 4 end,cover={}}
			bubbles:due(0,8,true)
			for i=1,600 do
				local now=i/30
				if i%90==0 then birds:chirp(now,i//90,Vector3.new(i//90*7,14,0),3,world,false)end
				for _,b in ipairs(birds:step(now,world,false,3,0))do table.insert(out,string.format("%.4f",b.root.Position.Y))end
				for _,f in ipairs(flies:step(now,1/30,world,patches,4,false))do table.insert(out,string.format("%.4f %.4f %.4f",f.position.X,f.position.Z,Sim.butterflyFlap(f,now,0)))end
				for _,leaf in ipairs(leaves:step(now,1/30,.3,28,0,function(_,r)return Sim.leafSpot(r,Vector3.zero,leafWorld)end))do
					table.insert(out,string.format("%d %.3f",leaf.kind,leaf.at.X))
				end
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


	-- Garden hour slice D (GARDEN-HOUR-BUILD-PLAN-2026-11-23; GARDEN-HOUR-LOOK 5): bubbles and birds by day only; butterflies
	-- by their own gate (round 3: fireflies at dusk).
	test("the garden hour's gate: day only above .7; nil (the hour off) is day; the hour's own phases",function()
		assert(Sim.DayLife==.7)
		assert(Sim.day(nil)==true and Sim.day(0/0)==true and Sim.day("x")==true,"no number: the hour is off, always day")
		assert(Sim.day(.9)==true and Sim.day(.71)==true and Sim.day(.7)==false and Sim.day(.55)==false and Sim.day(.12)==false)
		local Hour=require(game:GetService("ReplicatedStorage").Shared.GardenHour)
		local want={dawn=false,day=true,golden=false,night=false}
		for name,hold in pairs(Hour.Holds)do assert(Sim.day(hold.Daylight)==want[name],name)end
		-- Through the dawn to day blend the gate opens once, where the daylight passes .7, and stays open.
		local opened
		for s=360,450 do
			local day=Sim.day(Hour.phase(s).daylight)
			if opened then assert(day,"stays open")elseif day then opened=s end
		end
		assert(opened and opened>360 and opened<450,"opens inside the blend")
	end)

	test("butterflies at dusk: under .30 each hands off to a firefly, slot 1 first, 1.5 s apart, gone at 6 s; none spawn under .34",function()
		local B=Sim.Butterfly
		local patches={}
		for i=1,6 do patches[i]=Vector3.new(i*8,4,0)end
		local flies=Sim.Butterflies.new(4)
		local world={camera=Vector3.new(0,10,10),stations={},ground=function()return 4 end}
		local now=0
		for _=1,30*20 do now+=1/30;flies:step(now,1/30,world,patches,4,false,.9)end
		local out=#flies.list
		assert(out>=3,"some by day: "..out)
		assert(B.fly==.30 and B.spawn==.34 and B.handFloor==.24)
		-- Golden light (.55) and dawn (.31): still flying; .31 spawns none.
		for _=1,30*5 do now+=1/30;flies:step(now,1/30,world,patches,4,false,.55)end
		assert(#flies.list==out,"golden light keeps them")
		local before={}
		for _,b in ipairs(flies.list)do before[b]=true end
		flies.list[1]=flies.list[1] -- (no change)
		now+=1/30;flies:step(now,1/30,world,patches,4,false,.28)
		local start=now
		local order={}
		for _,b in ipairs(flies.list)do assert(b.hand,"each one hands off");table.insert(order,b)end
		table.sort(order,function(a,c)return a.colour<c.colour end)
		for i,b in ipairs(order)do assert(near(b.hand,start+(i-1)*1.5,1e-9),"slot order, 1.5 s apart: "..i)end
		local most,seen=0,{}
		local gone
		for i=1,30*14 do
			now+=1/30
			local list=flies:step(now,1/30,world,patches,4,false,.28)
			local glows=0
			for _,b in ipairs(list)do
				assert(before[b],"none new at dusk")
				local look=Sim.butterflyLook(b,now)
				local h=now-b.hand
				if h<0 then assert(look.glow==nil and look.wing<.05,"waits its turn")
				elseif h<B.handFade then
					glows+=1
					assert(look.glow and look.glow.size>=.2-1e-6 and look.glow.size<=.9+1e-6,"the glow comes up")
					assert(near(look.wing,look.body,1e-6)or look.wing>=look.body,"wings fade")
				else
					glows+=1
					assert(look.wing==1 and look.body==1 and b.mode=="glow","a firefly now")
					assert(look.glow.transparency>=.1-1e-6 and look.glow.transparency<=1+1e-6)
					if h<B.handEnd then assert(look.glow.transparency<=.55+1e-6,"pulsing .1 to .55")end
					if h>=B.handEnd-.05 and h<B.handEnd then seen[b]=b.position.Y end
				end
			end
			most=math.max(most,glows)
			if #list==0 then gone=now-start;break end
		end
		assert(most<=4,"at most 4 glows: "..most)
		for _,y in pairs(seen)do assert(y>=4+1.4 and y<=4+2.1,"a firefly 1.5 to 2 studs up: "..y)end
		assert(gone and gone>=1.5*(out-1)+6-.1 and gone<=1.5*(out-1)+6+.1,"the last one gone 6 s after its turn: "..tostring(gone))
		-- Still dusk: none spawn; past .34 they come back, fading their wings in over 1.2 s.
		for _=1,30*5 do now+=1/30;flies:step(now,1/30,world,patches,4,false,.32)end
		assert(#flies.list==0,"none spawn under .34")
		now+=1/30;flies:step(now,1/30,world,patches,4,false,.35)
		local b=flies.list[1]
		assert(b and b.born==now,"spawns over .34")
		assert(Sim.butterflyLook(b,now).wing>.99 and Sim.butterflyLook(b,now+.6).wing>0 and Sim.butterflyLook(b,now+1.2).wing==0,"fades in")
	end)

	test("butterflies at a jump past dusk (under .24): wings fade in .5 s, no glow; level 1's two glows; nil daylight is day",function()
		local patches={Vector3.new(8,4,0),Vector3.new(16,4,0),Vector3.new(24,4,0)}
		local world={camera=Vector3.new(0,10,10),stations={}}
		local flies=Sim.Butterflies.new(5)
		local now=0
		for _=1,30*10 do now+=1/30;flies:step(now,1/30,world,patches,4,false,nil)end
		assert(#flies.list>0,"nil: day")
		now+=1/30;flies:step(now,1/30,world,patches,4,false,.12)
		for _,b in ipairs(flies.list)do
			assert(b.fade and not b.hand,"a fade, no hand-off")
			assert(Sim.butterflyLook(b,now+.25).glow==nil and Sim.butterflyLook(b,now+.5).wing==1)
		end
		for _=1,16 do now+=1/30;flies:step(now,1/30,world,patches,4,false,.12)end
		assert(#flies.list==0,"gone in .5 s")
		-- Level 1: the cap is 2, so at most two glows.
		local two=Sim.Butterflies.new(6)
		now=0
		for _=1,15*10 do now+=1/15;two:step(now,1/15,world,patches,2,false,.9)end
		local most=0
		for _=1,15*10 do
			now+=1/15
			local glows=0
			for _,b in ipairs(two:step(now,1/15,world,patches,2,false,.25))do if Sim.butterflyLook(b,now).glow then glows+=1 end end
			most=math.max(most,glows)
		end
		assert(most>=1 and most<=2,"level 1 glows: "..most)
	end)

	test("birds at night: a chirp lands none; one already sitting hops and sits out its stay; bubbles wait for day",function()
		local spot=Vector3.new(10,14,10)
		local world={camera=Vector3.new(30,12,30),stations={}}
		local birds=Sim.Birds.new(7)
		local result,why=birds:chirp(0,5,spot,3,world,false,false)
		assert(result==nil and why=="night"and #birds.list==0)
		assert(birds:chirp(0,5,spot,3,world,false,nil)=="land","nil: the hour is off")
		local bird=birds.list[1]
		birds:step(1,world,false,3)
		assert(birds:chirp(1.1,5,spot,3,world,false,false)=="hop","the one there still hops")
		assert(select(2,birds:chirp(1.1,6,spot+Vector3.new(4,0,0),3,world,false,false))=="night","but no second lands")
		local t=1.2
		while #birds.list>0 and t<30 do t+=.1;birds:step(t,world,false,3)end
		assert(#birds.list==0 and t>=bird.stayUntil,"left when its stay was over")
		-- Bubbles: GardenLife passes the gate in `allowed`; a night slot is skipped, never saved up.
		local bubbles=Sim.Bubbles.new(3)
		assert(bubbles:due(0,8,false)==false)
		assert(bubbles:due(3,8,Sim.day(.12))==false,"night: skipped")
		assert(bubbles:due(4,8,Sim.day(.9))==false,"not saved up")
		assert(bubbles:due(6,8,Sim.day(.9))==true)
	end)

	return{passed=#cases,cases=cases}
end
