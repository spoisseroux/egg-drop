-- Studio Client. Alive step 4: the gust maths (Wind.lua). Pure, no instances.
-- Usage: require(PlayerScripts.Client.ZZSpecs.Wind)(PlayerScripts.Client)
return function(client)
	local Wind=require(client.Wind)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local T0=1795300000 -- a real server time, so precision is tested where it runs
	local here=Vector3.new(-30,4,4)
	local nan=0/0
	local strength=Wind.Strength
	local ok,err=pcall(function()

	test("0 to 1 everywhere, never still air, and it reaches real gusts and real lulls",function()
		local high,low,quiet=0,1,0
		for i=0,60000 do
			local t=T0+i*.05
			local at,gust=Wind.at(here,t),Wind.gust(here,t)
			assert(at>=.149 and at<=1 and gust>=0 and gust<=1,"at "..at.." gust "..gust)
			assert(at>=gust*.5,"a gust that is not in at()")
			if gust==0 then assert(at<=.2501,"breeze "..at);quiet+=1 end
			high,low=math.max(high,at),math.min(low,at)
		end
		assert(high>.85 and low<.17,"range "..low.." to "..high)
		assert(quiet>30000,"mostly lull: "..quiet)
	end)

	test("deterministic: the same place and time is the same wind, in any order",function()
		local times,first={},{}
		for i=1,400 do times[i]=T0+i*1.37;first[i]=Wind.at(here,times[i])end
		for i=400,1,-1 do assert(Wind.at(here,times[i])==first[i])end
		-- Pinned rolls: a changed hash would silently change the garden between client versions.
		for n=-3,3 do local roll=Wind.hash(n,1);assert(roll>=0 and roll<1 and roll==Wind.hash(n,1))end
		assert(Wind.hash(1,1)~=Wind.hash(1,2)and Wind.hash(1,1)~=Wind.hash(2,1))
	end)

	test("a gust every 9 to 16 s, about 3 in 10 skipped and never two running",function()
		local base=math.floor(T0/Wind.Slot)
		local skipped,last=0,nil
		for n=base,base+20000 do
			local gap=Wind.start(n+1)-Wind.start(n)
			assert(gap>=9-1e-6 and gap<=16+1e-6,"gap "..gap)
			local skip=Wind.skipped(n)
			if skip then skipped+=1;assert(not last,"two lulls in a row")end
			last=skip
			local peak=Wind.peak(n)
			assert(if skip then peak==0 else peak>=Wind.PeakMin and peak<=1,"peak "..peak)
		end
		assert(math.abs(skipped/20001-.3)<.02,"skipped "..skipped/20001)
	end)

	test("rises in .8 s, fades over 2.7 s, smoothly",function()
		assert(Wind.envelope(0)==0 and Wind.envelope(-1)==0 and Wind.envelope(3.5)==0 and Wind.envelope(99)==0)
		assert(Wind.envelope(.8)==1 and math.abs(Wind.envelope(.4)-.5)<1e-9 and math.abs(Wind.envelope(2.15)-.5)<1e-9)
		local last=0
		for i=1,360 do local v=Wind.envelope(i*.01);assert(math.abs(v-last)<=.0191,"jump at "..i*.01);last=v end
	end)

	test("the front travels at 14 studs a second downwind and is level across the wind",function()
		assert(math.abs(Wind.Direction.Magnitude-1)<1e-6 and Wind.Direction.Y==0 and Wind.Direction.X>.9)
		local side=Vector3.new(-Wind.Direction.Z,0,Wind.Direction.X)
		for i=0,600 do
			local t=T0+i*.11
			local at=Wind.at(here,t)
			assert(math.abs(at-Wind.at(here+Wind.Direction*70,t+5))<1e-4,"travel")
			assert(math.abs(at-Wind.at(here+side*80,t))<1e-4,"across")
		end
		-- From the hub toward Tumble Falls (77, -77), not away from it.
		local falls=Vector3.new(77,0,-77)-Vector3.new(-30,0,4)
		assert(falls.Unit:Dot(Wind.Direction)>.9,"toward the falls "..falls.Unit:Dot(Wind.Direction))
	end)

	test("two clients .1 s apart see the same gust",function()
		for i=0,20000 do
			local t=T0+i*.07
			assert(math.abs(Wind.at(here,t)-Wind.at(here,t+.1))<=.19,"at "..i)
		end
	end)

	test("nonsense in is still air out, and the one dial is clamped",function()
		for _,v in ipairs({nan,math.huge,-math.huge})do
			assert(Wind.at(here,v)==0 and Wind.gust(here,v)==0)
			assert(Wind.at(Vector3.new(v,0,0),T0)==0 and Wind.gust(Vector3.new(0,0,v),T0)==0)
		end
		assert(Wind.at(nil,T0)==0 and Wind.at(here,nil)==0 and Wind.gust("x","y")==0)
		for _,t in ipairs({0,-5000,-12.5,12.5})do local v=Wind.at(here,t);assert(v==v and v>=0 and v<=1)end
		local peakAt
		for i=0,4000 do if Wind.gust(here,T0+i*.05)>.8 then peakAt=T0+i*.05;break end end
		assert(peakAt,"no strong gust in 200 s")
		Wind.Strength=0;assert(Wind.at(here,peakAt)==0 and Wind.gust(here,peakAt)==0)
		Wind.Strength=99;assert(Wind.at(here,peakAt)<=1 and Wind.gust(here,peakAt)<=1)
		Wind.Strength=nan;assert(Wind.at(here,peakAt)>0 and Wind.at(here,peakAt)<=1)
		Wind.Strength=strength
	end)

	-- The big breath (beta 14 QA W3 row 1; GARDEN-LIFE-BUILD-PLAN section 4) ---------------------------------------
	test("the big breath: every 240 to 360 s, 2.5 s up, 3 held, 5 down, a front like a gust",function()
		local base=math.floor(T0/Wind.BreathSlot)
		for b=base,base+2000 do
			local gap=Wind.breathStart(b+1)-Wind.breathStart(b)
			assert(gap>=240-1e-6 and gap<=360+1e-6,"breath gap "..gap)
		end
		local E=Wind.breathEnvelope
		assert(E(0)==0 and E(-1)==0 and E(10.5)==0 and E(0/0)==0 and E(2.5)==1 and E(5.4)==1)
		assert(math.abs(E(1.25)-.5)<1e-9 and math.abs(E(8)-.5)<1e-9,"halfway up and down")
		-- One breath, found and walked: it travels at 14 studs a second, and its number is the same everywhere.
		local start=Wind.breathStart(base+1)+here:Dot(Wind.Direction)/Wind.Speed
		local v,b=Wind.breath(here,start+4)
		assert(v==1 and b==base+1,"held at the top: "..tostring(v).." "..tostring(b))
		local far,fb=Wind.breath(here+Wind.Direction*70,start+4+5)
		assert(math.abs(far-v)<1e-9 and fb==b,"the front travels")
		assert(Wind.breath(here,start-1)==0 and select(2,Wind.breath(here,start-1))==nil,"not before")
		assert(Wind.breath(here,0/0)==0 and Wind.breath(nil,T0)==0)
	end)

	test("the breath is opt-in: gust and at never read it; blow and swayAt are never under them",function()
		local base=math.floor(T0/Wind.BreathSlot)
		local start=Wind.breathStart(base+1)+here:Dot(Wind.Direction)/Wind.Speed
		local seen=0
		for i=0,400 do
			local t=start-2+i*.05
			local gust,at,breath=Wind.gust(here,t),Wind.at(here,t),Wind.breath(here,t)
			local blow,sway=Wind.blow(here,t),Wind.swayAt(here,t)
			assert(blow>=gust and blow>=breath and math.abs(blow-math.max(gust,breath))<1e-12,"blow")
			assert(sway>=at-1e-12,"swayAt under at")
			if breath>.99 then seen+=1;assert(gust<.99 or at>.99,"gust follows the gust slots only")end
		end
		assert(seen>10,"walked through a held breath")
		-- Outside every breath, swayAt is Wind.at exactly.
		local quiet=Wind.breathStart(base+1)-60
		for i=0,200 do local t=quiet+i*.1;assert(Wind.swayAt(here,t)==Wind.at(here,t),"swayAt off a breath")end
	end)

	end)
	Wind.Strength=strength
	assert(ok,err)
	return{passed=#cases,cases=cases}
end
