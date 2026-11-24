-- The Sleepy Nest landmark's numbers and states (NestLandmark; NEST-LANDMARK-LOOK, NEST-LANDMARK-BUILD-PLAN): the switch,
-- the template's data, the footprint against the pets' box and the prompt, the pill and pin heights, the blanket, the
-- moon by hour and readiness, the breath, the sway and the unroll. Pure; no Studio.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.NestLandmark)(ServerScriptService.Server); offline in
-- scripts/run_dash_server_specs.py.
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Land=require(Shared.NestLandmark)
	local Nest=require(Shared.Nest)
	local Onboard=require(Shared.Onboard)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end

	test("the switch: its own onboarding v3 part, only at the corner's spot",function()
		assert(table.find(Onboard.Features,"landmark")and Onboard.attribute("landmark")=="Onboard_landmark")
		assert(Land.applies(true,true)and not Land.applies(true,false)and not Land.applies(false,true))
		Onboard.inject({flags={OnboardingV3=false},studio=true});assert(not Land.on(),"live: off")
		Onboard.inject({flags={OnboardingV3=true},studio=true,landmark=false});assert(not Land.on())
		Onboard.inject({flags={OnboardingV3=true},studio=true});assert(Land.on())
		Onboard.inject(nil)
	end)
	test("the template's data (claude/nest-landmark da88bee, version 1): names, pivots, egg, collider",function()
		local d=Land.data()
		assert(d.version==Land.Version and d.egg.base==Land.EggBase and d.egg.size[2]==2.1)
		assert(d.pivots.Moon and d.pivots.Awning and d.pivots.BlanketDraped and d.pivots.BlanketFolded)
		assert(d.collider.radius==2.4 and d.collider.height==2.75)
		for _,name in ipairs({"Body","Awning","Moon","BlanketDraped","BlanketSlipped","BlanketFolded"})do assert(d.parts[name],name)end
		-- Today's egg (1.25 x 1.63 at its ready look) times 1.3 is the landmark's 1.6 x 2.1.
		assert(near(1.25*Land.EggScale,1.625,1e-9)and near(1.63*Land.EggScale,2.119,1e-9))
	end)
	test("footprint: pets keep Block / 2 + .35 off; the prompt stands outside that box and the collider; the Bear on the mat",function()
		assert(Land.Block==5.6 and Land.Front==3.5 and Land.PromptAt==Vector3.new(0,1,-3.5))
		assert(-Land.PromptAt.Z>Land.Block/2+.35-1e-9,"the prompt outside the pets' box")
		assert(-Land.PromptAt.Z>Land.data().collider.radius,"and outside the collider")
		local mat=Land.data().mat
		assert(Land.BearSpot==Vector3.new(mat.centre[1],mat.centre[2],mat.centre[3]),"the Bear curls on the mat")
		assert(Land.Block>Nest.Block and Land.Front>Nest.Front)
	end)
	test("heights: the pill over the moon's top, the peek over the pill, the pin at the top + 1.6",function()
		local d=Land.data()
		assert(Land.PillAt>d.moonTop[2]and Land.PeekAt>Land.PillAt)
		assert(near(Land.PinAt,6.6+1.6,1e-9))
		assert(Land.EggBase+d.egg.size[2]<Land.PillAt,"the ready egg's top under the pill")
	end)
	test("the blanket: folded when empty or untucked, draped when tucked, slipped when ready",function()
		assert(Land.blanket(false,false,false)=="folded"and Land.blanket(false,true,true)=="folded")
		assert(Land.blanket(true,false,false)=="folded"and Land.blanket(true,true,false)=="draped")
		assert(Land.blanket(true,true,true)=="slipped"and Land.blanket(true,false,true)=="slipped")
	end)
	test("the moon: matte by day, lit at dusk and night, gold and pulsing 80 to 100% when ready (any hour)",function()
		assert(Land.moon(false,1)==Land.Moon.day and not Land.Moon.day.lit and Land.Moon.day.brightness==0)
		assert(Land.moon(false,.2)==Land.Moon.night and Land.Moon.night.range==9 and Land.Moon.night.brightness==.6)
		assert(Land.moon(true,1)==Land.Moon.ready and Land.moon(true,0)==Land.Moon.ready and Land.Moon.ready.range==10)
		assert(Land.moon(false,nil)==Land.Moon.day)
		assert(near(Land.pulse(0),1)and near(Land.pulse(1),.8)and Land.pulse(1,true)==1)
	end)
	test("the breath: every 4.5 s, +2.5% tall, -1% wide, .04 up, a .6 s rest; none with Reduced Motion",function()
		local B=Land.Breath
		local peak=(B.period-B.rest)/2
		local tall,wide,rise=Land.breath(peak)
		assert(near(tall,1.025)and near(wide,.99)and near(rise,.04))
		assert(select(3,Land.breath(B.period-.3))==0,"the rest at the bottom")
		local t2,w2,r2=Land.breath(peak,true);assert(t2==1 and w2==1 and r2==0)
		assert(near(select(3,Land.breath(peak+B.period)),.04),"repeats")
	end)
	test("sway: moon 3 at .25 Hz, awning 2 at .3 Hz; ready lifts the awning 6 and holds it under Reduced Motion",function()
		local moonPeak=Land.sway(1)
		assert(near(moonPeak,3,1e-9),"the moon's peak a quarter period in")
		local _,lifted=Land.sway(0,true,true);assert(lifted==6)
		local m,a=Land.sway(0,false,true);assert(m==0 and a==0)
	end)
	test("the unroll: .2 to 1 over .6 s",function()
		assert(near(Land.unroll(0),.2)and near(Land.unroll(Land.Unroll),1)and Land.unroll(5)==1 and Land.unroll(.3)>.6)
	end)
	return{passed=#cases,cases=cases}
end
