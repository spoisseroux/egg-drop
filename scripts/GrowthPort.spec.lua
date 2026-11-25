-- The live growth cuts on the beta (artifacts/growth-2026-11-26/PORT-TO-BETA.md): where onboarding v3 owns a moment,
-- one of the two shows, never both. Follow the Bear on: no say-hi line (and no tour); off: the say-hi line, as live.
-- The paw prints to the pet: with the say-hi line, or with follow on and the need bubbles (once, as the step would
-- open), never from BearNeeds' finishGarden. The Sleepy Nest on: no live TOMORROW strip or Tomorrow line.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.GrowthPort)(PlayerScripts.Client)
return function(client)
	local Cards=require(client.CoachCards)
	local Chips=require(client.TomorrowChips)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Coach=require(Shared.CoachMarks)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local ROOM={mode="Room",canRoam=true,open={},used={},cardOpen=false,windowActive=true,idleFor=5,awayFor=0,owned=1,pet="Bear",input="Touch"}
	-- A coach without its screen: the garden side of step() only; shown lines are recorded, not drawn.
	local function coach(flags,options)
		options=options or {}
		options.send=function()end
		local self=setmetatable({options=options,flags=flags,mask=0,totalWins=0,owned=1,seen={},shown={},
			gardenView={bar={},root={Visible=false,SetAttribute=function()end}}},Cards)
		function self:showGarden(id,kind)
			table.insert(self.shown,id)
			self.garden={id=id,kind=kind,elapsed=0,duration=if kind=="sayHi"then Cards.SayHiSeconds else 3.86}
		end
		function self.run(from,to)for t=from,to,.5 do self:step(t,ROOM)end end
		return self
	end
	local function yes()return true end
	local function no()return false end

	test("the live TOMORROW strip and line apply only while the Sleepy Nest is off",function()
		assert(Chips.live({flags={TomorrowStrip=true},nest=false})==true)
		assert(Chips.live({flags={TomorrowStrip=true},nest=true})==false,"nest on: the v3 Coming up strip")
		assert(Chips.live({flags={TomorrowStrip=false},nest=false})==false,"switch off: neither")
		local c=coach({TomorrowStrip=true},{v3Tomorrow=yes})
		assert(c:v3Tomorrow()==true)
		assert(coach({TomorrowStrip=true},{}):v3Tomorrow()==false,"no option (live): the line applies")
	end)

	test("follow the Bear off: the say-hi line replaces the tour (as live)",function()
		local toured=0
		local c=coach({GardenTourCut=true},{follow=no,tour=function()toured+=1;return true end})
		c.run(0,Coach.GardenSettle+2)
		assert(c.shown[1]=="sayHi"and toured==0,"say-hi, no tour")
		assert(c.gardenDone==true)
	end)

	test("follow the Bear on: neither the say-hi line nor the tour (the need bubbles say hi)",function()
		local toured=0
		local c=coach({GardenTourCut=true,PetTrail=true},{follow=yes,followTrail=no,tour=function()toured+=1;return true end})
		c.run(0,Coach.GardenSettle+4)
		assert(#c.shown==0 and toured==0,"nothing on the rail")
		assert(not c.trailDue,"follow on without the bubbles: v3's own prints only")
		c:finishGarden()
		assert(not c.trailDue,"BearNeeds ending the step never lays the prints to the pet")
	end)

	test("follow the Bear on with the need bubbles: the prints to the pet, once, as the step would open",function()
		local c=coach({GardenTourCut=true,PetTrail=true},{follow=yes,followTrail=yes,tour=function()return true end})
		c.run(0,Coach.GardenSettle-1)
		assert(not c.trailDue,"after the garden settles")
		c.run(Coach.GardenSettle,Coach.GardenSettle+1)
		assert(c.trailDue==true and #c.shown==0)
		c.trailDue=false
		c.run(Coach.GardenSettle+1.5,Coach.GardenSettle+6)
		assert(not c.trailDue,"once a session")
		local off=coach({GardenTourCut=true,PetTrail=false},{follow=yes,followTrail=yes})
		off.run(0,Coach.GardenSettle+2)
		assert(not off.trailDue,"PetTrail off")
	end)

	test("the say-hi line still lays the prints; a tour closing without follow does too (as live)",function()
		local c=coach({GardenTourCut=false},{follow=no})
		c:finishGarden()
		assert(c.trailDue==true)
		local replay=coach({},{follow=no})
		replay.replaying=true
		replay:finishGarden()
		assert(not replay.trailDue,"never on Show tips again")
	end)

	test("a coach built without Cards.new reads every growth switch off (the older specs)",function()
		local toured=0
		local c=coach(nil,{follow=no,tour=function()toured+=1;return true end})
		c.run(0,Coach.GardenSettle+2)
		assert(toured==1 and #c.shown==0,"the tour, as before the growth cuts")
	end)

	test("economy: the live one-time Stars beside the beta's welcome week stay a fixed, small sum",function()
		-- Each grant is once per save behind its own saved field (starterRounds, firstHello, nest.n), none multiplied.
		-- The first session can only hold the Welcome bonus and the first hello (the nest's first egg takes Nest.Seconds);
		-- the whole of week one is the nest's face value on top. A tripwire: change a number, revisit PORT-TO-BETA.md.
		local Bonus=require(Shared.StarterBonus)
		local Hello=require(Shared.FirstHello)
		local Nest=require(Shared.Nest)
		assert(Bonus.Cap==20 and Bonus.amount(0)+Bonus.amount(1)+Bonus.amount(2)==Bonus.Cap and Bonus.amount(3)==0)
		assert(Hello.Bonus==2)
		local week=0
		for _,gift in ipairs(Nest.Gifts)do week+=gift.stars end
		assert(week==100,"the welcome week's Stars (plan: 100)")
		assert(Nest.Seconds>=8*3600,"no nest egg pays in the first session")
		assert(Bonus.Cap+Hello.Bonus<=22,"first session: at most 22 one-time Stars from the live cuts")
		assert(week+Bonus.Cap+Hello.Bonus<=125,"week one: at most 125 one-time Stars (a casual week is about 200)")
	end)

	return {passed=#cases,cases=cases}
end
