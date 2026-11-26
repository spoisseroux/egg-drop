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
		assert(#Onboard.Features==13,"appended, nothing renumbered")
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
	test("step 1: three pips fill one a combo with a 1.0 -> 1.3 -> 1.0 pop over 0.2 s; the seam a third more each time",function()
		for combos=0,3 do
			for i=1,3 do assert(V2.pip(i,combos)==(if i<=combos then "filled"else "empty"))end
			assert(near(V2.seam(combos),combos/3))
		end
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
		assert(near(g0,.2)and near(g1,.6)and l0==0 and near(l1,.2)and f0==0 and f1==1,"combo 3: glow 20 -> 60%, lift 20%, fade")
		assert(select(2,V2.finale(.5,true))==0,"no lift under Reduced Motion")
		assert(table.concat(V2.ComboLayers,",")=="crack1,crack2,creakLong","no pop on the deck")
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
		assert(V2.Taps[1].flakes==4 and V2.Taps[2].flakes==6 and V2.Taps[3].flakes==3 and V2.ReducedFlakes==3)
		assert(V2.Taps[1].haptic=="crack1"and V2.Taps[2].haptic=="crack2"and V2.Taps[3].haptic=="creak_long")
		assert(#V2.Crack.stops==3 and V2.Crack.stops[1]>0,"the first stop is after the start (a beat fires only after its tap)")
		for i=2,3 do assert(V2.Crack.stops[i]>V2.Crack.stops[i-1])end
		assert(V2.Crack.handAfter==3 and V2.Crack.auto==7)
		assert(V2.longest()<=22,"untouched it opens by itself: "..V2.longest())
		local size=Vector2.new(1000,500)
		assert(V2.inZone(Vector2.new(500,250),size)and V2.inZone(Vector2.new(200,100),size)and V2.inZone(Vector2.new(800,400),size))
		assert(not V2.inZone(Vector2.new(150,250),size)and not V2.inZone(Vector2.new(500,420),size)and not V2.inZone(nil,size))
		assert(instruction(V2.CrackCopy.Touch)=="Tap the egg!"and instruction(V2.CrackCopy.other)=="Click the egg!")
		assert(instruction(V2.CrackCopy.Gamepad)=="Crack it!")
		assert(V2.Crack.fov==40 and V2.Crack.dist==5 and V2.Crack.tween==.6)
	end)
	test("step 4 and 5: Meet Bear; the guide's three prompts and the end card, each short",function()
		assert(instruction("onb2.card.meet",{pet="Bear"})=="Meet Bear")
		for _,id in ipairs(V2.Guide.order)do instruction(V2.GuideCopy[id],{pet="Bear"})end
		assert(instruction("onb2.guide.allSet")=="You're all set!")
		assert(V2.Guide.ignore==20 and V2.Guide.endCard==2.5 and V2.Guide.far==12)
		assert(V2.ignored(0,20)and not V2.ignored(0,19.9)and not V2.ignored(nil,30))
		assert(V2.arrowLift(.5,false)==6 and V2.arrowLift(0,false)==0 and V2.arrowLift(.5,true)==0,"6 px at 1 Hz, still when reduced")
		assert(UICopy.get("onb2.replay")~="onb2.replay")
	end)
	return{passed=#cases,cases=cases}
end
