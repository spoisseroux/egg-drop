-- The ASMR hatch and the vibration cap (ASMR-AND-SCALE-LOOK.md sections 1 and 2). Pure parts only: the variation
-- picker (never the same variant twice running, speed and gain jitter, the streak's exhale), the beat schedule on the
-- hatch clock (Common, Rare jackpot, Reduced Motion) and Haptics.Gate (6 starts a second, 70 ms apart, 250 ms of motor
-- a second, majors always, a stronger buzz never cut by a weaker one).
-- Usage (Client): require(ZZSpecs.HatchAsmr)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client)
	local Asmr=require(client.HatchAsmr)
	local Haptics=require(client.Haptics)
	local Gate,P=Haptics.Gate,Haptics.Patterns
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function lcg(seed)
		local s=seed
		return function()s=(s*1103515245+12345)%2147483648;return s/2147483648 end
	end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-9)end
	-- The hatch clocks (HatchRarityCue.timing): Common item / pet, Rare item (jackpot), Reduced item, Reduced pet.
	local Common={burst=.98,jackpot=false,reduced=false}
	local Rare={burst=1.72,jackpot=true,reduced=false}
	local Reduced={burst=.30,jackpot=false,reduced=true}
	local ReducedPet={burst=0,jackpot=false,reduced=true}

	test("pick: never the same variant twice running, every variant reached, from any random number",function()
		for _,name in ipairs({"settle","crack1","crack2","creak","creakLong","pop","flake","exhale"})do
			local l=Asmr.Layers[name]
			local random,last,seen=lcg(#name),nil,{}
			for _=1,300 do
				local v=Asmr.pick(name,random(),last)
				assert(table.find(l.variants,v),name.." picked "..tostring(v))
				assert(v~=last,name.." repeated "..v)
				seen[v]=true;last=v
			end
			for _,v in ipairs(l.variants)do assert(seen[v],name.." never picked "..v)end
			assert(Asmr.pick(name,0,nil)==l.variants[1]and Asmr.pick(name,.999999,nil)==l.variants[#l.variants])
		end
		assert(#Asmr.cues()==24,"24 one-shots ("..#Asmr.cues()..")")
	end)
	test("jitter: speed 0.94 to 1.06 times the shell pitch, gain within 1.5 dB",function()
		for _,kind in ipairs({"companion","toy","hue","stat","unknown"})do
			local shell=Asmr.ShellPitch[kind]or 1
			for i=0,20 do
				local u=i/20
				local speed,gain=Asmr.jitter("pop",kind,u,1-u)
				assert(speed>=.94*shell-1e-9 and speed<=1.06*shell+1e-9,kind)
				local db=20*math.log10(gain/Asmr.Layers.pop.gain)
				assert(math.abs(db)<=1.5+1e-9,"gain "..db)
			end
		end
	end)
	test("streak: the exhale on the first hatch, then every third within 20 s; a long gap starts over",function()
		local state={}
		local got={}
		for i,at in ipairs({0,5,10,15,20,25,26})do local n,ex=Asmr.streak(state,at);got[i]=(ex and "x"or ".")..n end
		assert(table.concat(got," ")=="x1 .2 .3 x4 .5 .6 x7",table.concat(got," "))
		local n,ex=Asmr.streak(state,26+20.5);assert(n==1 and ex,"a new streak after 20 s")
	end)
	test("schedule, Common: settle, crack, crack, creak into the pop on the burst, flakes after, every event pre",function()
		for seed=1,60 do
			local state={}
			local events=Asmr.schedule(Common,"companion",lcg(seed),state,seed*100)
			local by={}
			for i,e in ipairs(events)do
				assert(e.pre==true and e.at>=0 and type(e.cue)=="string"and e.speed>0 and e.gain>0)
				assert(string.match(e.cue,"^"..Asmr.Layers[e.layer].cue.."_%a$"),e.cue)
				if i>1 then assert(events[i-1].at<=e.at,"sorted")end
				by[e.layer]=by[e.layer]or {};table.insert(by[e.layer],e)
			end
			local B=Asmr.Beats
			assert(#by.settle==1 and near(by.settle[1].at,B.settle,.008+1e-9)and by.settle[1].haptic=="settle")
			assert(#by.crack1==1 and near(by.crack1[1].at,B.crack1,.012+1e-9)and by.crack1[1].haptic=="crack1")
			assert(#by.crack2==1 and near(by.crack2[1].at,B.crack2,.012+1e-9)and by.crack2[1].haptic=="crack2")
			assert(#by.pop==1 and by.pop[1].at==.98 and by.pop[1].haptic=="pop","the pop is the burst")
			local main
			for _,e in ipairs(by.creak)do
				if e.haptic=="creak"then assert(not main);main=e else assert(e.haptic==nil and near(e.at,B.crack2+.03))end
			end
			assert(main and near(main.at,.98-B.creak),"the creak ends on the pop")
			assert(not by.creakLong)
			-- Flakes: 2 to 4 after the pop (plus maybe one crumb after crack 1), 30 ms apart, sound only.
			local after={}
			for _,e in ipairs(by.flake)do
				assert(e.haptic==nil)
				if e.at>.98 then table.insert(after,e.at)else assert(e.at>B.crack1 and e.at<B.crack2,"the crumb")end
			end
			assert(#after>=2 and #after<=4,#after)
			for i=2,#after do assert(after[i]-after[i-1]>=.03-1e-9)end
			assert(after[#after]<=.98+B.flakeTo+B.flakeGap)
			assert(#by.exhale==1 and near(by.exhale[1].at,.98+B.exhaleAfter),"the first hatch of a streak exhales")
			-- The pop is the last buzz: nothing after the release.
			for _,e in ipairs(events)do if e.at>.98 then assert(e.haptic==nil)end end
		end
	end)
	test("schedule: no layer repeats its variant from one hatch to the next; a streak's 2nd and 3rd hatch do not exhale",function()
		local state,prev={},nil
		for n=1,9 do
			local events=Asmr.schedule(Common,"toy",lcg(n*7),state,n*3)
			local now={}
			for _,e in ipairs(events)do if e.layer~="flake"and e.layer~="creak"then now[e.layer]=e.cue end end
			if prev then for layer,cue in pairs(now)do if layer~="exhale"then assert(prev[layer]~=cue,layer.." repeated across hatches")end end end
			local exhaled=now.exhale~=nil
			assert(exhaled==((n-1)%3==0),"exhale on hatch "..n)
			prev=now
		end
	end)
	test("schedule, Rare jackpot: the long creak ends on the freeze, the jackpot buzz on the burst",function()
		local events=Asmr.schedule(Rare,"material",lcg(3),{},0)
		local long,pop
		for _,e in ipairs(events)do
			if e.layer=="creakLong"then long=e end
			if e.layer=="pop"then pop=e end
			assert(not(e.layer=="creak"and e.haptic=="creak"),"no short creak on a jackpot")
		end
		assert(long and near(long.at+Asmr.Beats.creakLong,1.60)and long.haptic=="creak_long")
		assert(pop and pop.at==1.72 and pop.haptic=="jackpot")
	end)
	test("schedule, Reduced Motion: the sounds and buzz stay on a short line; a reduced pet gets the pop alone",function()
		local events=Asmr.schedule(Reduced,"hue",lcg(9),{},0)
		local layers={}
		for _,e in ipairs(events)do layers[e.layer]=(layers[e.layer]or 0)+1;if e.layer=="pop"then assert(e.at==.30)end end
		assert(layers.crack1==1 and layers.crack2==1 and layers.pop==1 and not layers.settle and not layers.creak)
		events=Asmr.schedule(ReducedPet,"companion",lcg(9),{},0)
		layers={}
		for _,e in ipairs(events)do layers[e.layer]=(layers[e.layer]or 0)+1;assert(e.at>=0)end
		assert(layers.pop==1 and not layers.crack1 and not layers.crack2)
	end)
	test("every buzz of a hatch passes the cap (100 hatches, each kind of clock)",function()
		for seed=1,100 do
			for _,timing in ipairs({Common,Rare,Reduced,ReducedPet})do
				local gate=Gate.new()
				for _,e in ipairs(Asmr.schedule(timing,"companion",lcg(seed),{},0))do
					if e.haptic then
						local ok,why=gate:try(P[e.haptic],e.at)
						assert(ok,e.haptic.." at "..e.at.." capped: "..tostring(why))
					end
				end
			end
		end
	end)
	test("patterns: keys rise in time, end at 0, and give the authored length and on-time",function()
		for name,p in pairs(P)do
			local keys=Haptics.keys(p)
			assert(keys[1][1]==0 and keys[#keys][2]==0,name)
			for i=2,#keys do assert(keys[i][1]>keys[i-1][1],name.." keys share a time")end
			assert(near(keys[#keys][1]/1000,p.length,.001),name)
			for _,k in ipairs(keys)do assert(k[2]>=0 and k[2]<=1)end
		end
		assert(near(P.crack2.length,.09)and near(P.crack2.on,.05))
		assert(P.pop.major and P.clear.major and P.creak.exempt and not P.crack1.exempt)
		assert(P.merge5.length>P.merge4.length and P.merge4.length>P.merge3.length and P.merge3.length>P.merge2.length,"length grows with the tier")
	end)
	test("merge patterns: a chain climbs (strength +0.08 a step to +0.25, +5 ms to +20 ms); a clear is the clear",function()
		assert(Haptics.mergePattern(3,1,false)==P.merge3 and Haptics.mergePattern(5,9,true)==P.clear)
		local c2=Haptics.mergePattern(2,2,false)
		assert(near(c2.peak,.38)and near(c2.length,.030)and c2.priority>P.merge2.priority)
		local c9=Haptics.mergePattern(2,9,false)
		assert(near(c9.peak,.55)and near(c9.length,.045),"capped")
		assert(Haptics.mergePattern(4,3,false)==Haptics.mergePattern(4,3,false),"cached")
		assert(Haptics.mergePattern(9,1,false)==P.merge5 and Haptics.mergePattern(0,1,false)==P.merge2,"tiers clamp")
	end)
	test("gate: 70 ms between starts, at most 6 a second, at most 250 ms of motor a second",function()
		local tick=Haptics.pattern("Small",3,{{.3,.3,12}})
		local g=Gate.new()
		assert(g:try(tick,0));assert(not g:try(tick,.05),"inside 70 ms");assert(g:try(tick,.07))
		-- Ticks offered every 71 ms: never more than six in any second, and the window slides.
		local g2=Gate.new();local times={}
		for i=0,40 do if g2:try(tick,i*.071)then table.insert(times,i*.071)end end
		for i=1,#times do
			local n=0
			for j=1,#times do if times[j]>times[i]-1 and times[j]<=times[i]then n+=1 end end
			assert(n<=6,"over 6 starts in a second")
		end
		local long=Haptics.pattern("Small",3,{{.3,.3,100}})
		g=Gate.new()
		assert(g:try(long,0)and g:try(long,.2));local ok,why=g:try(long,.4);assert(not ok and why=="budget")
		assert(g:try(long,1.01),"the budget slides")
		local ex=Haptics.pattern("Small",3,{{.3,.3,300}},{exempt=true})
		g=Gate.new();assert(g:try(ex,0)and g:try(long,.31),"exempt time is outside the budget")
	end)
	test("gate: majors always play and cut; a stronger buzz playing drops a weaker one; a stronger one cuts a weaker",function()
		local g=Gate.new()
		assert(g:try(P.merge2,0))
		local ok,cut=g:try(P.clear,.01);assert(ok and cut,"the clear cuts the tick")
		ok=g:try(P.merge3,.10);assert(not ok,"never over the clear while it plays")
		assert(g:try(P.merge3,.22),"after it")
		g=Gate.new()
		assert(g:try(P.merge3,0))
		ok,cut=g:try(P.merge4,.02);assert(ok and cut,"a stronger merge of the same chain takes over")
		assert(not g:try(P.merge2,.03),"a weaker one is dropped, not queued")
		g=Gate.new()
		for i=0,9 do g:try(P.merge2,i*.07)end
		assert(g:try(P.pop,.65),"a major passes a full window")
	end)
	test("a busy 60 s deck round never buzzes more than 6 merges in any second (a clear, the major, always plays)",function()
		local g,random,starts,clears=Gate.new(),lcg(77),{},0
		local at=0
		while at<60 do
			at+=.01+random()*.12
			local tier=2+math.floor(random()*4)
			local chain=1+math.floor(random()*4)
			local cleared=random()<.03
			local ok=g:try(Haptics.mergePattern(tier,chain,cleared),at)
			if cleared then assert(ok,"a clear always buzzes");clears+=1 elseif ok then table.insert(starts,at)end
		end
		assert(clears>0)
		assert(#starts>60,"it did buzz ("..#starts..")")
		local j=1
		for i=1,#starts do
			while starts[j]<=starts[i]-1 do j+=1 end
			assert(i-j+1<=6,"over 6 at "..starts[i])
		end
	end)
	return{passed=#cases,cases=cases}
end
