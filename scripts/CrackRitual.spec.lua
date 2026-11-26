-- The First Hatch (Onboard "crack", artifacts/onboarding-2026-11-26/PLAN.md): the player cracks the Bear's egg. The
-- stops come from the ASMR schedule (crack 1, crack 2, the creak before the pop); the clock holds at each until a tap
-- or Auto; an early tap is never lost; the first tap reports once; no tap left once all are spent.
-- Usage (Client): require(ZZSpecs.CrackRitual)(StarterPlayerScripts.Client)
return function(client)
	local Ritual=require(client.CrackRitual)
	local Asmr=require(client.HatchAsmr)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function lcg(seed)
		local s=seed
		return function()s=(s*1103515245+12345)%2147483648;return s/2147483648 end
	end
	local function clock()local c={t=0};return c,function()return c.t end end

	test("stops: crack 1, crack 2 and the creak before the pop, three, in order, for every Common pet schedule",function()
		for seed=1,40 do
			local events=Asmr.schedule({burst=.98,jackpot=false,reduced=false},"companion",lcg(seed),{},seed*100)
			local stops=Ritual.stopsFrom(events)
			assert(#stops==3,"three stops ("..#stops..", seed "..seed..")")
			local at={}
			for _,e in ipairs(events)do at[e.layer]=at[e.layer]or e.at end
			assert(stops[1]==at.crack1 and stops[2]==at.crack2,"the two cracks")
			assert(stops[3]>stops[2]+.05 and stops[3]<at.pop,"the creak, before the pop")
		end
		assert(#Ritual.stopsFrom(nil)==0 and Ritual.new({})==nil and Ritual.new(nil)==nil,"nothing to hold on")
		local close=Ritual.stopsFrom({{layer="crack1",at=.3},{layer="crack2",at=.6},{layer="creak",at=.62},{layer="pop",at=.98}})
		assert(#close==2,"a creak under crack 2 is not its own stop")
	end)
	test("hold: runs to just before a stop, holds there, and lets go by itself after Auto",function()
		local c,now=clock()
		local r=Ritual.new({.36,.65,.80},now)
		assert(r:hold(.2)==false and not r:waiting(),"before the first stop")
		assert(r:hold(.36-Ritual.Lead)==true and r:waiting(),"held at crack 1")
		c.t=Ritual.Auto-.01;assert(r:hold(.36-Ritual.Lead)==true,"still held")
		c.t=Ritual.Auto+.01;assert(r:hold(.36-Ritual.Lead)==false,"auto release")
		assert(r:hold(.5)==false,"runs on")
		assert(r:hold(.65)==true,"held at crack 2")
		c.t=c.t+Ritual.Auto+.01;assert(r:hold(.65)==false)
		assert(r:hold(.80)==true);c.t=c.t+Ritual.Auto+.01;assert(r:hold(.80)==false)
		assert(r:done()and r:hold(.9)==false and not r:waiting(),"all spent: never held again")
	end)
	test("tap: releases the stop the clock is at or running to; mashing releases nothing more; false once done",function()
		local c,now=clock()
		local r=Ritual.new({.36,.65,.80},now)
		assert(r:hold(.35)==true)
		assert(r:tap()==true);assert(r:tap()==true and r:tap()==true,"mashing is taken")
		assert(r:hold(.35)==false,"released by the tap")
		assert(r:hold(.65)==true,"mashing did not release crack 2: held there")
		assert(r:tap()==true and r:hold(.65)==false)
		assert(r:tap()==true,"early tap, running to the creak")
		assert(r:hold(.80)==false,"the creak already released: no hold")
		assert(r:done()and r:tap()==false,"nothing left")
		assert(c.t==0,"no time passed: taps alone open it")
	end)
	test("cap: at any frame length the clock stops at each crack before playing it; untouched, it opens by itself",function()
		for _,dt in ipairs({1/60,1/30,.1,.25})do
			local c,now=clock()
			local stops={.36,.65,.80}
			local r=Ritual.new(stops,now)
			local age,frames,heldAt=0,0,{}
			while age<1 and frames<2000 do
				frames+=1;c.t+=dt
				if r:hold(age)then heldAt[r.index]=heldAt[r.index]or age
				else
					local step=r:cap(age,dt)
					assert(step>=0 and step<=dt)
					for i,at in ipairs(stops)do assert(not(age<at and age+step>=at and not heldAt[i]),"frame "..dt..": crack "..i.." played before its stop")end
					age+=step
				end
			end
			assert(age>=1 and r:done(),"opens by itself at dt "..dt)
			for i,at in ipairs(stops)do assert(heldAt[i]and math.abs(heldAt[i]-(at-Ritual.Lead))<1e-9,"held exactly before crack "..i)end
		end
		local r=Ritual.new({.36},os.clock)
		assert(math.abs(r:cap(.30,.1)-(.36-Ritual.Lead-.30))<1e-9 and r:cap(.1,.1)==.1)
		r:tap();assert(r:cap(.30,.1)==.1,"a released stop does not cap")
	end)
	test("onFirstTap: called once per ritual, on the first accepted tap only; a failing hook never breaks the tap",function()
		local calls=0
		local saved=Ritual.onFirstTap
		Ritual.onFirstTap=function()calls+=1 end
		local _,now=clock()
		local r=Ritual.new({.36,.65,.80},now)
		r:hold(.36);r:tap();r:tap();r:tap();r:tap()
		assert(calls==1,"once ("..calls..")")
		local untouched=Ritual.new({.36},now)
		untouched:hold(.36)
		assert(calls==1,"no tap, no call")
		Ritual.onFirstTap=function()error("boom")end
		local again=Ritual.new({.36},now)
		assert(again:tap()==true,"the tap still lands")
		Ritual.onFirstTap=saved
	end)
	return{passed=#cases,cases=cases}
end
