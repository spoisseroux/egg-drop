-- Onboarding v3 slice A: follow the Bear (ONBOARDING-V3-PLAN-2026-11-23 section 3, the architect review). Off is the old
-- tour exactly; on: no tour cards or beats, the switch asked only once the garden step could start, the first trail by
-- itself, station label tips once each with their own bits, the idle hint, and gardenIntro still marked (funnel step 5).
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.FollowBear)(PlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Coach=require(Shared.CoachMarks)
	local Onboard=require(Shared.Onboard)
	local UICopy=require(Shared.UICopy)
	local Cards=require(client.CoachCards)
	local Tips=require(client.ThingsTips)
	local Needs=require(client.BearNeeds)
	local Attract=require(client.StationAttract)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function with(base,t)local c=table.clone(base);for k,v in pairs(t or {})do c[k]=v end;return c end
	local ROOM={mode="Room",canRoam=true,open={},used={},cardOpen=false,windowActive=true,idleFor=5,awayFor=0,owned=1,pet="Bear"}
	-- A coach without its screen: the garden side of step() only (no tour host, so nothing draws).
	local function coach(options)
		local sent={}
		options.send=function(id)table.insert(sent,id)end
		local self=setmetatable({options=options,mask=0,totalWins=0,owned=1,seen={},sent=sent},Cards)
		function self.run(from,to)for t=from,to,.5 do self:step(t,ROOM)end end
		return self
	end

	test("off: the five-card tour opens as before (no follow option, or follow saying no)",function()
		for _,follow in ipairs({false,"none"})do
			local toured=0
			local options={tour=function()toured+=1;return true end}
			if follow~="none"then options.follow=function()return follow end end
			local c=coach(options)
			c.run(0,4)
			assert(toured==1 and c.tourOpen==true,"the tour")
			assert(Cards.stage({owned=1,mask=0,seen={},totalWins=0},false)=="garden")
		end
	end)
	test("on: no tour and no beats, and the switch is asked only once the garden step could start",function()
		local toured,asked=0,0
		local c=coach({tour=function()toured+=1;return true end,follow=function()asked+=1;return true end})
		c:step(0,ROOM);c:step(1,ROOM)
		assert(asked==0,"not before the garden has settled")
		c.run(3,10)
		assert(asked>0 and toured==0 and c.tourOpen==nil and c.beat==nil and c.garden==nil,"no tour card, no beat line")
		assert(Cards.stage({owned=1,mask=0,seen={},totalWins=0},true)=="free","the garden step reads free")
		assert(Cards.stage({owned=0},true)=="welcome"and Cards.stage({owned=1,revealPending=true},true)=="reveal","only the garden step changes")
		assert(not table.find(c.sent,"gardenIntro"),"the tour never marks it; BearNeeds does")
		c:finishGarden();assert(table.find(c.sent,"gardenIntro"),"finishGarden still sends it")
		-- Show tips again still replays the beats.
		local replay=coach({follow=function()return true end})
		replay:replayGarden();assert(replay.replaying)
		assert(Cards.beatMayStart(with(ROOM,{mask=0,seen={},totalWins=0}),5,true),"a replay may start")
	end)
	test("the session switch: Onboard.sessionFollow, captured at the first ask",function()
		assert(Onboard.inject({flags={OnboardingV3=true},studio=true,follow=true}))
		local c=coach({tour=function()return true end,follow=function()return Onboard.sessionFollow()end})
		c.run(0,4)
		assert(c.tourOpen==nil and Onboard.sessionFollow()==true)
		assert(Onboard.inject({flags={OnboardingV3=true},studio=true,follow=false}))
		local off=coach({tour=function()return true end,follow=function()return Onboard.sessionFollow()end})
		off.run(0,4);assert(off.tourOpen==true,"follow off: the tour")
		assert(Onboard.inject({flags={OnboardingV3=false},studio=true}))
		assert(Onboard.sessionFollow()==false,"the build ceiling off")
		Onboard.inject(nil)
	end)

	-- BearNeeds with the bubbles off: the trail, the garden step, the idle hint.
	local function rig(over)
		local r={state={status="Ready",coachMask=0,totalWins=1,nectar=20,stats={rounds=1},petToys={},toyUnlocks={}},owned=1,mask=0,marked={},intro=0,
			trails={},trailUp=false,needsOn=false,follow=true,returning=false,chirps=0,quiet=nil,
			gate={on=true,mode="Room",canRoam=true,idleFor=5,awayFor=0,roomFor=5,windowActive=true,railEmpty=true,parkPending=0,action="idle"}}
		for k,v in pairs(over or {})do r[k]=v end
		local bubble={set=function()end,hop=function()end,step=function()end}
		r.needs=Needs.new({bubble=bubble,state=function()return r.state end,owned=function()return r.owned end,mask=function()return r.mask end,
			mark=function(id)table.insert(r.marked,id)end,finishIntro=function()r.intro+=1;r.mask=Coach.with(r.mask,"gardenIntro")end,
			follow=function()return r.follow end,needs=function()return r.needsOn end,returning=function()return r.returning end,
			gate=function()return r.gate end,greeting=function()return false end,inPark=function()return false end,nest=function()return false end,
			place=function(where)if where=="Eggs"then return Vector3.new(-31,4,-11),"Hatch eggs"end;return nil end,
			trail=function(target,how)table.insert(r.trails,{name=target.name,how=how});r.trailUp=true;return true end,trailActive=function()return r.trailUp end,
			sayHi=function()return true end,playDeck=function()return true end,quiet=function(on)r.quiet=on end,chirp=function()r.chirps+=1 end,react=function()end})
		r.t=0
		function r.run(seconds)for _=1,math.max(1,math.floor(seconds/.25+.5))do r.t+=.25;r.needs:step(r.t,.25)end end
		return r
	end
	test("on, bubbles off: the prints lead to Hatch eggs at once; the trail over marks the garden step",function()
		local r=rig();r.run(.5)
		assert(#r.trails==1 and r.trails[1].name=="Hatch eggs"and r.trails[1].how=="auto","the first trail by itself")
		assert(r.needs:focus()=="Eggs","only Hatch eggs beckons while it leads there")
		assert(r.intro==0 and r.quiet==false,"no bubbles: the pill stays")
		r.run(5);assert(r.intro==0,"still walking")
		r.trailUp=false;r.run(.25)
		assert(r.intro==1,"arrived (or skipped): gardenIntro")
		r.run(10);assert(r.intro==1 and #r.trails==1,"once")
	end)
	test("on: the garden step is marked after 60 s in the garden, whatever else happened",function()
		local r=rig();r.run(Tips.IntroAfter-1);assert(r.intro==0)
		r.run(1.5);assert(r.intro==1)
		local held=rig();held.gate=with(held.gate,{modal=true});held.run(Tips.IntroAfter+5)
		assert(held.intro==0 and #held.trails==0,"a menu stops the clock and holds the trail")
		assert(Tips.followDone({gardenFor=60})and Tips.followDone({needs=true,saidHi=true})and not Tips.followDone({needs=true,trailOver=true})and Tips.followDone({trailOver=true}))
	end)
	test("on: the idle hint replays the prints to the machine, three times, until it is learned",function()
		local r=rig();r.run(.5);r.trailUp=false;r.run(.25)
		r.gate.idleFor=Tips.IdleHint;r.run(Tips.IdleHint*5)
		assert(r.chirps==Tips.IdleHints and #r.trails==1+Tips.IdleHints and r.trails[2].how=="idle")
		local learned=rig({mask=Coach.with(0,"hatch")});learned.run(.5);learned.trailUp=false;learned.run(.25)
		learned.gate.idleFor=Tips.IdleHint;learned.run(Tips.IdleHint*2)
		assert(learned.chirps==0,"Hatch eggs visited: nothing left to follow")
	end)
	test("off or returning: no trail, no garden step from here",function()
		for _,over in ipairs({{follow=false},{returning=true},{state={status="Ready",coachMask=Coach.with(0,"gardenIntro"),totalWins=1,stats={}}}})do
			local r=rig(over);r.run(Tips.IntroAfter+5)
			assert(#r.trails==0 and r.intro==0 and r.chirps==0)
		end
		local early=rig({owned=0});early.run(3);assert(early.needs.ready~=true,"no pet yet: not ready")
	end)

	test("station tips: their own bits, never the first-visit bits, once each, only when following",function()
		local map={Eggs="tipHatch",Customize="tipStyle",Journal="tipCompanions",Park="tipPark",Nest="tipNest"}
		local ctx={follow=true,mask=0,seen={},totalWins=0,owned=1}
		for station,bit in pairs(map)do
			assert(Tips.TipBits[station]==bit and Tips.stationTip(station,ctx)==bit,station)
			assert(Coach.Bits[bit]>=15 and Coach.Bits[bit]<=19,bit)
			local text=UICopy.get(Tips.TipCopy[bit],{pet="Bear"})
			assert(text~=Tips.TipCopy[bit]and not string.find(text,"{",1,true),text)
			assert(Tips.stationTip(station,with(ctx,{mask=Coach.with(0,bit)}))==nil and Tips.stationTip(station,with(ctx,{seen={[bit]=true}}))==nil,station.." once")
			assert(Tips.stationTip(station,with(ctx,{follow=false}))==nil,station.." off")
		end
		for _,first in ipairs({"hatch","style","companions","park"})do
			for _,bit in pairs(map)do assert(bit~=first)end
			assert(Tips.stationTip("Eggs",with(ctx,{mask=Coach.with(0,first)}))=="tipHatch","a first visit does not use up the tip")
		end
		assert(Tips.stationTip("Dash",ctx)==nil)
	end)
	test("the station label carries the tip for its intro time, once, then its own line again",function()
		local shown={}
		local text="Bear found the egg machine!"
		local attract=setmetatable({options={tip=function(id)return if id=="Eggs"then text else nil end,tipShown=function(id)table.insert(shown,id)end},
			introduced={},introShown={}},Attract)
		local entry={id="Eggs",labelLine={Text="Spend Stars on new eggs",Visible=true},label={Enabled=false},introLine="Spend Stars on new eggs",intro=true}
		attract:paintLabel(entry,false,1);assert(#shown==0 and not entry.label.Enabled,"not until the label shows")
		attract:paintLabel(entry,true,.5)
		assert(#shown==1 and entry.labelLine.Text==text and entry.labelLine.Visible and entry.label.Enabled,"the tip on the label")
		attract:paintLabel(entry,false,3);assert(entry.labelLine.Text==text,"walked away: the tip waits")
		attract:paintLabel(entry,true,Attract.Data.IntroSeconds)
		assert(entry.labelLine.Text=="Spend Stars on new eggs"and attract.introduced.Eggs and not entry.labelLine.Visible,"then the name alone")
		attract:paintLabel(entry,true,1);assert(#shown==1,"once")
		-- Off: no tip option, the label is exactly the old one.
		local old=setmetatable({options={},introduced={},introShown={}},Attract)
		local plain={id="Eggs",labelLine={Text="Spend Stars on new eggs",Visible=true},label={Enabled=false},introLine="Spend Stars on new eggs",intro=true}
		old:paintLabel(plain,true,1);assert(plain.labelLine.Text=="Spend Stars on new eggs"and plain.labelLine.Visible and plain.label.Enabled)
		old:paintLabel(plain,true,Attract.Data.IntroSeconds);assert(not plain.labelLine.Visible and old.introduced.Eggs)
	end)
	test("the park line gives way to need 5 while the bubbles are on",function()
		local GATE={on=true,mode="Room",canRoam=true,idleFor=5,awayFor=0,roomFor=5,windowActive=true,railEmpty=true,parkPending=0,action="idle"}
		local CTX={mask=Coach.with(0,"gardenIntro"),seen={},totalWins=1,owned=1,firstEgg=true,dashOn=false,raced=false,playDates=0,returning=false,now=1000,gate=GATE}
		assert(Tips.due(CTX)=="parkInvite"and Tips.due(with(CTX,{needs=false}))=="parkInvite","off: as before")
		assert(Tips.due(with(CTX,{needs=true}))==nil)
	end)
	return{passed=#cases,cases=cases}
end
