-- Onboarding v2 (artifacts/qa-2026-11-26-beta35/ONBOARDING-V2.md): the five steps' pure rules. The four switches and
-- their tables, the deck's one line a moment and its pips, the 3D egg's pose, the stork's six seconds, the crack's
-- taps and its time limit, the guide's words, and every instruction 16 characters or fewer with no key names.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.OnboardV2)(PlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Onboard=require(Shared.Onboard)
	local UICopy=require(Shared.UICopy)
	local V2=require(client.OnboardV2)
	local cases={}
	local function test(name,run)
		local ok,problem=pcall(run)
		V2.read=nil
		assert(ok,name..": "..tostring(problem))
		table.insert(cases,name)
	end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	-- No key names in an instruction (Fable: "never a key name").
	local KEYS={"Space","SPACE","Enter","Esc","Shift","Ctrl"," G "," L2","Press "}
	local function instruction(key,vars)
		local text=UICopy.get(key,vars)
		assert(text~=key,"missing copy "..key)
		assert(#text<=16,key.." over 16 characters: "..text)
		for _,word in ipairs(KEYS)do assert(not string.find(" "..text.." ",word,1,true),key.." names a key: "..text)end
		return text
	end

	test("four switches in the Onboard tables (feature, attribute, ConfigService key); all four off is beta (35)",function()
		for _,name in ipairs({"egg3d","stork","safecard","guide"})do
			assert(table.find(Onboard.Features,name),name)
			assert(Onboard.attribute(name)=="Onboard_"..name and Onboard.key(name)=="onboard_"..name,name)
		end
		assert(Onboard.Features[13]=="guide"and #Onboard.Features>=13,"appended, nothing renumbered") -- v3 appends after (deck2)
		V2.read=function()return false end
		for _,name in ipairs({"egg3d","stork","safecard","guide"})do assert(not V2.on(name),name)end
		V2.read=function(name)return name=="guide"end
		assert(V2.on("guide")and not V2.on("stork"))
	end)
	test("the stork needs the opener and the crack (Onboard.storyOn); the one-time events are a closed list",function()
		Onboard.inject({flags={OnboardingV3=true},studio=true})
		assert(Onboard.storyOn(),"all on")
		Onboard.inject({flags={OnboardingV3=true},studio=true,crack=false})
		assert(Onboard.on("stork")and not Onboard.storyOn(),"no crack, no stork story")
		Onboard.inject({flags={OnboardingV3=true},studio=true,opener=false})
		assert(not Onboard.storyOn(),"no opener, no stork story")
		Onboard.inject(nil)
		for _,name in ipairs({"StorkShown","EggSetDown","AllSet","OnboardSkipped_Stork"})do assert(Onboard.Events[name]==true,name)end
		assert(Onboard.Events.FirstPet==nil and Onboard.Events.BearMet==nil and Onboard.Events.EggTapped==nil,"recorded where they happen")
	end)
	test("review B36: one hatch, never two: the modal waits Hold s for the receipt; once let back, a late receipt never starts the stork",function()
		local g={}
		assert(V2.deckHold(g,false,false,0)==false,"no Bear hatching: nothing held")
		assert(V2.deckHold(g,true,false,0)==true and V2.deckHold(g,true,false,V2.Hold-.01)==true,"waiting for the receipt")
		assert(V2.mayClaim(g),"a receipt inside the wait plays as the stork")
		assert(V2.deckHold(g,true,true,V2.Hold+5)==true,"the story running: the modal stays hidden")
		local late={}
		V2.deckHold(late,true,false,0)
		assert(V2.deckHold(late,true,false,V2.Hold)==false,"no receipt in time: the modal shows")
		assert(not V2.mayClaim(late),"a later receipt is the old path's")
		assert(V2.deckHold(late,false,false,10)==false and not V2.mayClaim(late),"for the rest of the session")
		assert(V2.deckHold(late,true,false,11)==false,"the modal is never held again")
		assert(V2.CardTimeout>0)
	end)
	test("step 1: one line a moment, in order; 16 characters or fewer, no key names",function()
		local seen={}
		for _,step in ipairs({{0,0,"Drop a ball!"},{1,0,"Match two!"},{4,1,"2 more!"},{6,2,"1 more!"},{8,3,"It's hatching!"}})do
			local text=instruction(V2.deckLine(step[1],step[2]))
			assert(text==step[3],text)
			seen[text]=true
		end
		assert(V2.deckLine(0,7)=="onb2.deck.hatching"and V2.deckLine(nil,nil)=="onb2.deck.drop","clamped")
		assert(instruction(V2.dropHint("Keyboard"))=="Click to drop"and V2.dropHint("Touch")==nil and V2.dropHint("Gamepad")==nil)
	end)
	test("step 1: three pips fill one a combo with a 1.0 -> 1.3 -> 1.0 pop over 0.2 s; the egg lit a little brighter each time",function()
		for combos=0,3 do
			for i=1,3 do assert(V2.pip(i,combos)==(if i<=combos then "filled"else "empty"))end
			if combos>0 then assert(V2.glow(combos)>V2.glow(combos-1),"brighter")end
		end
		-- beta (36) and Fable: no disc at all, no crack on the deck (the egg cracks in the world), a chime per combo
		assert(V2.Deck.glow==nil and V2.Deck.glowSize==nil and V2.Deck.glowFinal==nil,"no disc")
		assert(V2.seam==nil and V2.Deck.seam==nil and V2.ComboLayers==nil,"no crack seam and no crack sounds on the deck")
		assert(V2.ComboChime.cue=="charge"and #V2.ComboChime.pitches==3 and V2.ComboChime.pitches[3]>V2.ComboChime.pitches[1],"a rising fill chime")
		assert(V2.glow(3)<=V2.Deck.lightFinal and V2.glow(0)==V2.Deck.lightIdle)
		assert(V2.pipScale(nil)==1 and V2.pipScale(0)==1 and V2.pipScale(.2)==1,"at rest")
		assert(near(V2.pipScale(.1),1.3),"the top of the pop")
		assert(V2.Deck.pip==22,"22 px pips")
	end)
	test("step 1: the egg spins 25 degrees a second with a 3 degree bob at 0.5 Hz; a combo hops 10%, wobbles 14 and turns once in 0.6 s",function()
		local yaw,tilt,hop=V2.eggPose(2,nil,false)
		assert(near(yaw,50)and near(tilt,0,1e-9)and hop==0,"idle")
		local _,top=V2.eggPose(.5,nil,false);assert(near(top,3),"the bob's top")
		local _,_,mid=V2.eggPose(0,.2,false);assert(near(mid,.10),"hop at the middle of the wobble")
		local spin=V2.eggPose(0,.3,false);assert(near(spin,180,1e-6),"half the turn at 0.3 s: "..spin)
		local after=V2.eggPose(0,.6,false);assert(near(after,0),"one whole turn by 0.6 s")
		local worst=0
		for i=0,40 do local t=i/100;local _,w=V2.eggPose(0,t,false);worst=math.max(worst,math.abs(w))end
		assert(worst<=14.01,"wobble within 14: "..worst)
		local ry,rt,rh=V2.eggPose(3,.1,true);assert(ry==V2.Deck.reducedYaw and rt==0 and rh==0,"Reduced Motion: still, three-quarter")
		local g0,l0,f0=V2.finale(0,false);local g1,l1,f1=V2.finale(.5,false)
		assert(near(g0,V2.glow(3))and near(g1,V2.Deck.lightFinal)and l0==0 and near(l1,.2)and f0==0 and f1==1,"combo 3: the light rises, lift 20%, fade")
		assert(select(2,V2.finale(.5,true))==0,"no lift under Reduced Motion")
	end)
	test("step 2: six seconds: glide 3, lower to 3.8, let go to 4.3, off by 6; wings 35 degrees, 3 Hz slowing to 1.5",function()
		assert(V2.storkPhase(0)=="glide"and V2.storkPhase(2.99)=="glide"and V2.storkPhase(3.2)=="hover"and V2.storkPhase(4)=="release"
			and V2.storkPhase(5)=="leave"and V2.storkPhase(6)=="gone")
		local peak=0
		for i=0,600 do peak=math.max(peak,math.abs(V2.flap(i/100)))end
		assert(peak<=35+1e-6 and peak>34,"amplitude "..peak)
		-- zero crossings: about 6 per second at the start, 3 per second after the glide
		local function crossings(a,b)
			local n,last=0,V2.flap(a)
			for i=1,200 do local v=V2.flap(a+(b-a)*i/200);if(v>0)~=(last>0)then n+=1 end;last=v end
			return n
		end
		assert(crossings(0,.5)>=2 and crossings(4,5)>=2 and crossings(4,5)<=4,"slower after the glide")
		assert(near(V2.flap(3)-V2.flap(3-1e-6),0,1e-3),"no jump at the end of the glide")
		assert(V2.lower(2)==0 and V2.lower(3.8)==1 and V2.lower(3.4)>0 and V2.lower(3.4)<1)
		assert(V2.rock(-1)==0 and V2.rock(.6)==0 and math.abs(V2.rock(.1))<=6)
		local a,b=Vector3.new(0,0,0),Vector3.new(10,0,0)
		assert(V2.curve(a,b,Vector3.new(0,4,0),0)==a and V2.curve(a,b,Vector3.new(0,4,0),1)==b and V2.curve(a,b,Vector3.new(0,4,0),.5).Y==2)
		assert(V2.Stork.out==40 and V2.Stork.up==18 and V2.Stork.land==6 and V2.Stork.skipAt==1 and V2.Stork.skipH==44 and V2.Stork.fov==55)
		assert(instruction("onb2.stork.delivery")=="A delivery!")
		instruction("onb2.stork.skip")
	end)
	test("step 3: three taps (rock 10, 14, then the creak and pop), the middle 60% of the screen, opens itself within about 22 s",function()
		assert(#V2.Taps==3 and V2.Taps[1].rock==10 and V2.Taps[2].rock==14 and V2.Taps[3].pop==true)
		assert(V2.Taps[1].crumbs==4 and V2.Taps[2].crumbs==6 and V2.Taps[3].crumbs==3 and V2.ReducedFlakes==3)
		assert(V2.Taps[1].haptic=="crack1"and V2.Taps[2].haptic=="crack2"and V2.Taps[3].haptic=="creak_long")
		assert(#V2.Crack.stops==3 and V2.Crack.stops[1]>0,"the first stop is after the start (a beat fires only after its tap)")
		for i=2,3 do assert(V2.Crack.stops[i]>V2.Crack.stops[i-1])end
		assert(V2.Crack.handAfter==3 and V2.Crack.auto==7)
		assert(V2.longest()<=22.5,"untouched it opens by itself: "..V2.longest())
		local size=Vector2.new(1000,500)
		assert(V2.inZone(Vector2.new(500,250),size)and V2.inZone(Vector2.new(200,100),size)and V2.inZone(Vector2.new(800,400),size))
		assert(not V2.inZone(Vector2.new(150,250),size)and not V2.inZone(Vector2.new(500,420),size)and not V2.inZone(nil,size))
		assert(instruction(V2.CrackCopy.Touch)=="Tap the egg!"and instruction(V2.CrackCopy.other)=="Click the egg!")
		assert(instruction(V2.CrackCopy.Gamepad)=="Crack it!")
		assert(V2.Crack.fov==40 and V2.Crack.dist==5 and V2.Crack.tween==.6)
	end)
	-- Beta (36): "the stork flies thru the arch mesh". The arrival arch's tall cells (the world's walk grid,
	-- assets/world/world-v7-beta-walk.json: W7_Architecture over the ground near the arrival dais): x, z, top y.
	local ARCH={{82,46,9.73},{88,52,15.35},{90,52,11.51},{88,54,17.16},{86,56,18.55},{74,58,9.51},{84,58,18.72},{86,58,18.89},
		{82,60,17.72},{84,60,18.32},{80,62,14.52},{82,62,16.4}}
	local GROUND=4.5
	local function boxes(list)
		local out={}
		for _,c in ipairs(list)do table.insert(out,{min=Vector3.new(c[1]-1,GROUND,c[2]-1),max=Vector3.new(c[1]+1,c[3]+.5,c[2]+1)})end
		return out
	end
	local function clearOf(obstacles)
		return function(a,b,r)
			local d=b-a
			local n=math.max(1,math.ceil(d.Magnitude/.25))
			for i=0,n do
				local p=a+d*(i/n)
				for _,o in ipairs(obstacles)do
					if p.X>=o.min.X-r and p.X<=o.max.X+r and p.Y>=o.min.Y-r and p.Y<=o.max.Y+r and p.Z>=o.min.Z-r and p.Z<=o.max.Z+r then return false end
				end
			end
			return true
		end
	end
	local function flight(land,toPlayer)return V2.hover(land,toPlayer)end -- the beak tip over the landing
	local function routeClear(route,land,toPlayer,clear)
		local path=V2.routePath(route.start,flight(land,toPlayer),route.bow)
		for i=1,#path-1 do if not clear(path[i],path[i+1],V2.Route.radius)then return false end end
		return true
	end
	test("beta (36): the stork's flight clears the arrival arch, from the arrival dais and round it",function()
		local arch=boxes(ARCH)
		local clear=clearOf(arch)
		local spawn=Vector3.new(96,GROUND,66)
		local look=(Vector3.new(-30,GROUND,4)-spawn);look=look/look.Magnitude
		local cases=0
		-- the arrival dais facing the hub, and players standing round the arch facing every way
		local spots={{spawn,look}}
		for _,at in ipairs({Vector3.new(92,GROUND,50),Vector3.new(76,GROUND,52),Vector3.new(78,GROUND,68),Vector3.new(90,GROUND,62)})do
			for k=0,7 do local a=k*math.pi/4;table.insert(spots,{at,Vector3.new(math.sin(a),0,math.cos(a))})end
		end
		local rerouted,moved=0,0
		local flat=function(x,z)return Vector3.new(x,GROUND,z)end
		for index,s in ipairs(spots)do
			local land=V2.landing(s[1],s[2],flat,clear)
			if land~=s[1]+s[2]*6 then moved+=1 end
			local toPlayer=Vector3.new(s[1].X-land.X,0,s[1].Z-land.Z);toPlayer=toPlayer/toPlayer.Magnitude
			local route=V2.storkRoute(land,toPlayer,flight(land,toPlayer),clear)
			assert(route.heading~=nil or index>1,"the arrival dais finds a way in")
			assert(routeClear(route,land,toPlayer,clear),"the flight to "..tostring(land.X)..","..tostring(land.Z).." clips the arch")
			if route.heading~=V2.Route.headings[1]or route.height~=V2.Route.heights[1]then rerouted+=1 end
			cases+=1
		end
		assert(cases>=30,"enough landings ("..cases..")")
		assert(rerouted+moved>=1,"the arch moves at least one landing or flight off the first choice")
	end)
	test("beta (36): an arch on the first approach sends the stork round or over it; boxed in, it comes straight down",function()
		local land,toPlayer=Vector3.new(0,0,0),Vector3.new(0,0,1)
		local first=V2.storkRoute(land,toPlayer,flight(land,toPlayer),function()return true end)
		assert(first.heading==V2.Route.headings[1]and first.height==V2.Route.heights[1],"open sky: the first choice")
		-- a wall across the first approach
		local path=V2.routePath(first.start,flight(land,toPlayer),first.bow)
		local mid=path[math.floor(#path/2)]
		local wall={{min=mid-Vector3.new(3,30,3),max=mid+Vector3.new(3,4,3)}}
		local clear=clearOf(wall)
		local route,tried=V2.storkRoute(land,toPlayer,flight(land,toPlayer),clear)
		assert(tried>1 and routeClear(route,land,toPlayer,clear),"another way round")
		local boxed=V2.storkRoute(land,toPlayer,flight(land,toPlayer),function()return false end)
		assert(boxed.heading==nil and boxed.start.Y>=land.Y+V2.Route.drop-1e-6,"straight down from high")
		-- the landing: open sky first; under the arch it moves round the player
		local under=V2.landing(Vector3.new(84,GROUND,50),Vector3.new(0,0,1),function(x,z)return Vector3.new(x,GROUND,z)end,clearOf(boxes(ARCH)))
		assert(clearOf(boxes(ARCH))(under+Vector3.new(0,.6,0),under+Vector3.new(0,V2.Route.sky,0),V2.Route.skyRadius),"open sky over the landing")
		assert(V2.landing(Vector3.new(0,0,0),Vector3.new(0,0,1),function()return nil end,clear)==nil,"no ground: nil (the story takes the spawn pad)")
	end)
	test("code review: the flight's cast budget: coarse first, the first clear wins, never past Route.budget sweeps",function()
		local R=V2.Route
		local land,toPlayer=Vector3.new(0,0,0),Vector3.new(0,0,1)
		local hover=V2.hover(land,toPlayer)
		-- open sky: the first candidate, coarse then fine
		local calls=0
		local route,tried,used=V2.storkRoute(land,toPlayer,hover,function()calls+=1;return true end)
		assert(tried==1 and used==R.coarse+R.samples and calls==used,"one candidate: "..calls.." sweeps")
		-- the worst case: every coarse check passes and every fine one fails at its last leg
		calls=0
		local n=0
		route,tried,used=V2.storkRoute(land,toPlayer,hover,function(a,b)
			calls+=1;n+=1
			return n%(R.coarse+R.samples)~=0
		end)
		assert(calls<=R.budget and used==calls,"within the budget: "..calls)
		assert(route.heading==nil,"out of budget: straight down")
		-- boxed in: one sweep a candidate
		calls=0
		route,tried=V2.storkRoute(land,toPlayer,hover,function()calls+=1;return false end)
		assert(calls==tried and calls<=#R.headings*#R.heights)
		-- and at the frame rate it is spread over: every sweep is at most castsPerSweep casts, framesCasts a frame
		assert(R.budget*R.castsPerSweep/R.framesCasts<=30,"half a second of frames at most")
	end)
	test("Fable B37: the blanket 78% wide and half as thick, pale blue dots, 0.6 studs into the dais; the cream egg base",function()
		assert(math.abs(V2.Blanket.radius-1.2*.78)<1e-9 and math.abs(V2.Blanket.thick-.05)<1e-9 and V2.Blanket.inward==.6)
		local function hex(c)return string.format("%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
		assert(hex(V2.Blanket.dots)=="DCEBFA"and hex(V2.Deck.base)=="FBF6D2")
		assert(V2.Deck.preloadCap==.6 and V2.Deck.fadeIn==.15)
		local dais=Vector3.new(96,4.05,66)
		local moved=V2.onDais(Vector3.new(90,4.5,63),dais)
		local d=Vector3.new(moved.X-90,0,moved.Z-63)
		assert(math.abs(d.Magnitude-.6)<1e-6 and d:Dot(Vector3.new(6,0,3))>0,"0.6 toward the centre")
		assert(V2.onDais(Vector3.new(50,4,50),dais)==Vector3.new(50,4,50),"off the dais: where it was")
		assert(V2.onDais(Vector3.new(90,4,63),nil)==Vector3.new(90,4,63))
	end)
	test("Fable's crack: the 40 ms dip, two and three swings, the 5 to 9 Hz flex to 1.08, the pop's kick and FOV 40 -> 44 -> 42",function()
		assert(V2.Crack.anticipate==.04 and V2.Crack.grow==.09 and V2.Crack.closer==.03)
		local sy,sxz=V2.dip(1,.04);assert(near(sy,.97)and near(sxz,1.02),"tap 1 dips 3%, widens 2%")
		assert(near(V2.dip(2,.04),.96)and near(V2.dip(3,.04),.95),"4% and 5%")
		assert(near(V2.dip(3,1),.95),"tap 3 holds its dip")
		assert(near(V2.dip(1,1),1),"taps 1 and 2 come back")
		assert(V2.tapRock(1,0)==0 and V2.tapRock(1,.4)==0 and V2.tapRock(3,.1)==0,"tap 3 flexes, it does not rock")
		local peak=0;for i=0,40 do peak=math.max(peak,math.abs(V2.tapRock(2,i/100)))end
		assert(peak<=14 and peak>5,"tap 2 within 14 degrees: "..peak)
		assert(V2.flex(0)==1 and near(V2.flex(.25),1.08,.013)and V2.flex(.12)>1,"flex to 1.08 over 250 ms")
		local k0,f0=V2.popCamera(0);local _,fPeak=V2.popCamera(.06);local _,fRest=V2.popCamera(.4)
		assert(k0==0 and f0==40 and near(fPeak,44)and near(fRest,42),"40 -> 44 -> 42")
		local kick=V2.popCamera(.06);assert(near(kick,.15,1e-3),"0.15 stud kick")
		assert(V2.Crack.pop.silence==.08 and V2.Crack.pop.flashAlpha==.35 and V2.Crack.pop.flash==.12 and V2.Crack.pop.hold==.6)
		assert(V2.Crack.pop.pieces[1]==12 and V2.Crack.pop.pieces[2]==16 and V2.Crack.pop.voiced==5)
		assert(V2.Taps[1].takes[1]=="tap_knuckle"and V2.Taps[3].takes[1]=="asmr_crack3"and V2.Taps[2].under.layer=="creak")
		assert(V2.Taps[1].stage==1 and V2.Taps[2].stage==2 and V2.Taps[3].stage==3 and V2.Taps[2].leak and V2.Taps[3].skitter)
		-- the closed egg's map: the uploaded no-seam companion map (beta 37); the zigzag appears only as it opens
		assert(V2.NoSeamId==130682441511149 and V2.closedMap()=="rbxassetid://130682441511149","the no-seam map")
	end)
	test("step 4 and 5: Meet Bear; the guide's three prompts and the end card, each short",function()
		assert(instruction("onb2.card.meet",{pet="Bear"})=="Meet Bear")
		for _,id in ipairs(V2.Guide.order)do instruction(V2.GuideCopy[id],{pet="Bear"})end
		assert(instruction("onb2.guide.allSet")=="You're all set!")
		assert(V2.Guide.ignore==20 and V2.Guide.endCard==2.5 and V2.Guide.far==12)
		assert(V2.ignored(0,20)and not V2.ignored(0,19.9)and not V2.ignored(nil,30))
		assert(V2.arrowLift(.5,false)==6 and V2.arrowLift(0,false)==0 and V2.arrowLift(.5,true)==0,"6 px at 1 Hz, still when reduced")
		assert(UICopy.get("onb2.replay")~="onb2.replay")
		-- beta (37) note 3: never a skip; a nudge from 20 s, at most every 15 s
		assert(V2.Guide.nudge==15 and V2.Guide.shrink==nil)
		assert(V2.nudgeDue(20,nil,0)and not V2.nudgeDue(19,nil,0)and not V2.nudgeDue(40,30,44)and V2.nudgeDue(40,30,45)and not V2.nudgeDue(nil,nil,9))
	end)
	test("beta (37) note 1: the Bear stands where the egg opened a beat, then follows; the swap waits for it to be there",function()
		assert(V2.Stand.beat==1.5 and V2.Stand.wait==2 and V2.Stand.reach>0 and V2.Stand.near>0)
		local land=Vector3.new(96,4.2,60)
		assert(V2.standArrived(land+Vector3.new(.5,0,.5),land),"drawn on the blanket spot")
		assert(not V2.standArrived(land+Vector3.new(3,-1,-2.6),land),"at its follow spot behind the player")
		assert(not V2.standArrived(land+Vector3.new(0,5,0),land)and not V2.standArrived(nil,land)and not V2.standArrived(land,nil))
	end)
	return{passed=#cases,cases=cases}
end
