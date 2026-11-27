-- Glow steps (artifacts/qa-2026-11-27-beta37/ONBOARDING-V3-BRIEF.md section 2, switch Onboard "trail2"): the pure rules
-- in Shared.TrailGlow. The brief's numbers, the pulse wave (its timing per print, its bounds, that it runs toward the
-- target), the target ring's ripple and the chip's pulse landing with it, Reduced Motion's breath, the pop in and pop
-- away, a guide trail's ends, the switch, and the "when a pet leads" prints (laid every step, toes along the way, the
-- `pat` spacing, the walked-over pop with sparkles, the passed ones, the cap of 12 nearest the player, hold, and a
-- fixed pool: no tables made per frame).
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.TrailGlow)(ServerScriptService.Server)
-- Offline: python scripts/run_dash_server_specs.py
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Glow=require(Shared.TrailGlow)
	local Onboard=require(Shared.Onboard)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
	local function hexOf(c)return string.format("#%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end

	test("the brief's numbers: a 1.3 stud paw, cream core, gold ring at 1.6x at 50%, see-through .30, LightInfluence 0",function()
		assert(Glow.Size==1.3 and Glow.Halo==1.6 and Glow.HaloSee==.5 and Glow.See==.30 and Glow.LightInfluence==0)
		assert(hexOf(Glow.Core)=="#FFF4DC"and hexOf(Glow.Gold)=="#FFD86B"and hexOf(Glow.SparkleColor)=="#FFD86B")
		assert(Glow.Period==1.2 and Glow.Gap==.10 and Glow.Pulse==.30 and Glow.Swell==1.35 and Glow.PulseSee==.05)
		assert(Glow.Ripple==.4 and Glow.RippleTo==2.2 and Glow.Canvas>=Glow.RippleTo,"the part spans the widest ripple")
		assert(Glow.TargetRadius==2.2 and Glow.ChipPulse==1.15 and Glow.BreatheHz==.5 and Glow.BreatheLow==.15)
		assert(Glow.PopIn==.15 and Glow.PopPeak==1.2 and Glow.Sparkles==2 and Glow.LeadMax==12 and Glow.PatGap==.18)
		assert(Glow.PatCue.gain==.12 and type(Glow.PatCue.name)=="string"and Glow.PatCue.name~="pat","pat is a stand-in until it is uploaded")
		assert(Glow.Feature=="trail2")
	end)

	test("the wave: each print swells 1 to 1.35 and clears .30 to .05 over 0.30 s, 0.10 s after the one before, every 1.2 s",function()
		local s,see=Glow.wave(Glow.Pulse/2,1,false)
		assert(near(s,1.35)and near(see,.05),"print 1 at its peak")
		s,see=Glow.wave(.1+Glow.Pulse/2,2,false);assert(near(s,1.35)and near(see,.05),"print 2 a gap later")
		s=Glow.wave(.05,2,false);assert(s==1,"print 2 waits its gap")
		s=Glow.wave(1.2+Glow.Pulse/2,1,false);assert(near(s,1.35),"again every 1.2 s")
		s,see=Glow.wave(Glow.Pulse+.01,1,false);assert(s==1 and see==Glow.See,"rest after the swell")
		for t=0,4.8,.01 do
			for i=1,40 do
				local scale,clear,ripple,rippleSee=Glow.wave(t,i,false)
				assert(scale>=1 and scale<=1.35+1e-9 and clear>=.05-1e-9 and clear<=.30+1e-9)
				assert(ripple>=1.6-1e-9 and ripple<=2.2+1e-9 and rippleSee>=.5-1e-9 and rippleSee<=1)
				-- Nothing moves outside the window, so the view writes nothing there.
				if not Glow.moving(t,i,false)then assert(scale==1 and clear==Glow.See and rippleSee==1)end
			end
		end
		-- Toward the target: a later print peaks later in the same wave.
		local function peak(i)local best,at=0,0;for t=0,1.19,.001 do local v=Glow.wave(t,i,false);if v>best then best,at=v,t end end;return at end
		assert(peak(1)<peak(2)and peak(2)<peak(5)and peak(5)<peak(9),"the wave runs from the player toward the target")
	end)

	test("the ring ripples out from 1.6x to 2.2x and fades from .5 over 0.4 s, with the swell",function()
		local _,_,r0,a0=Glow.wave(0,1,false);assert(near(r0,1.6)and near(a0,.5))
		local _,_,r1,a1=Glow.wave(.2,1,false);assert(near(r1,1.9)and near(a1,.75))
		local _,_,r2,a2=Glow.wave(.41,1,false);assert(r2==1.6 and a2==1,"hidden after 0.4 s")
		local _,_,r3=Glow.wave(.1+.2,2,false);assert(near(r3,1.9),"print 2 a gap later")
	end)

	test("the target ring ripples every 1.2 s as the wave lands; the chip pulses 1 to 1.15 with it",function()
		for _,count in ipairs({0,1,6,12,40})do
			local land=count*Glow.Gap
			local scale,see=Glow.target(land,count,false)
			assert(near(scale,1)and near(see,.2),"starts as the wave lands, "..count)
			scale,see=Glow.target(land+Glow.TargetRipple/2,count,false)
			assert(near(scale,1+(Glow.TargetRippleTo-1)/2)and near(see,.6))
			assert(select(2,Glow.target(land+Glow.TargetRipple+.01,count,false))==1,"then hidden")
			assert(near(Glow.target(land+1.2,count,false),1)and near(select(2,Glow.target(land+1.2,count,false)),.2),"every 1.2 s")
			assert(near(Glow.chip(land+Glow.Pulse/2,count,false),1.15)and Glow.chip(land+Glow.Pulse+.01,count,false)==1)
		end
		for t=0,3,.01 do local c=Glow.chip(t,6,false);assert(c>=1 and c<=1.15+1e-9)end
	end)

	test("Reduced Motion: no swell, ripple or chip pulse; see-through breathes .30 to .15 at 0.5 Hz",function()
		for t=0,4,.05 do
			local s,see,_,rippleSee=Glow.wave(t,3,true)
			assert(s==1 and rippleSee==1 and see<=.30+1e-9 and see>=.15-1e-9)
			assert(select(2,Glow.target(t,5,true))==1 and Glow.chip(t,5,true)==1 and not Glow.moving(t,3,true))
		end
		assert(near(Glow.breathe(0),.30)and near(Glow.breathe(1),.15)and near(Glow.breathe(2),.30),"one breath every 2 s")
	end)

	test("a lead print pops in 0 to 1.2 to 1.0 in 0.15 s; a walked-over one pops away",function()
		assert(Glow.popIn(0,false)==0 and Glow.popIn(Glow.PopIn,false)==1 and Glow.popIn(1,false)==1)
		local top=0
		for age=0,Glow.PopIn,.001 do top=math.max(top,Glow.popIn(age,false))end
		assert(near(top,1.2,1e-3),"overshoots to 1.2")
		assert(Glow.popIn(.03,false)<Glow.popIn(.07,false),"grows first")
		assert(Glow.popIn(0,true)==1,"Reduced Motion: there at once")
		local s0,a0=Glow.popAway(0,false);local s1,a1=Glow.popAway(Glow.PopAway,false)
		assert(s0==1 and near(a0,Glow.See)and near(s1,1.3)and a1==1)
		assert(Glow.popAway(.1,true)==1,"Reduced Motion: fades without the swell")
	end)

	test("a guide trail: no time end, a menu or the deck or a trip out hides it, the hello still ends it",function()
		assert(Glow.guideEnd("time",true)==nil and Glow.guideEnd("menu",true)=="hide"and Glow.guideEnd("deck",true)=="hide")
		assert(Glow.guideEnd("left",true)=="hide"and Glow.guideEnd("hello",true)=="hello"and Glow.guideEnd("arrived",true)=="arrived")
		assert(Glow.guideEnd(nil,true)==nil)
		for _,reason in ipairs({"time","menu","deck","left","hello"})do assert(Glow.guideEnd(reason,false)==reason,"not a guide: as before")end
	end)

	test("the switch: Onboard trail2 (feature, attribute, ConfigService key), on with the ceiling, off when set off",function()
		assert(table.find(Onboard.Features,"trail2")and Onboard.attribute("trail2")=="Onboard_trail2"and Onboard.key("trail2")=="onboard_trail2")
		local at=table.find(Onboard.Features,"trail2")
		assert(at>13 and Onboard.Features[13]=="guide","appended after the v2 switches")
		assert(Glow.on(function(name)return name=="trail2"end)and not Glow.on(function()return false end))
		assert(not Glow.on(function()error("no attribute yet")end),"a read that throws is off")
		Onboard.inject({flags={OnboardingV3=true},studio=true})
		assert(Glow.on(),"on in Studio with the ceiling open")
		Onboard.inject({flags={OnboardingV3=true},studio=true,trail2=false})
		assert(not Glow.on(),"set off")
		Onboard.inject({flags={OnboardingV3=false},studio=true})
		assert(not Glow.on(),"no ceiling (the live game): off")
		Onboard.inject(nil)
	end)

	-- A pet running along +X from the origin, the player standing behind it.
	local function V(x,z)return Vector3.new(x,0,z)end
	test("a leading pet lays a print every 2.2 studs, left and right of its way, toes along it, with a pat at most every 0.18 s",function()
		local lead=Glow.lead()
		local player=V(-6,0)
		lead:step(0,V(0,0),player);assert(lead.laid==0,"the first step only marks where it is")
		lead:step(.1,V(1,0),player);assert(lead.laid==0,"under a step: nothing")
		lead:step(.2,V(2.3,0),player);assert(lead.laid>0 and lead.pat,"a step: a print and a pat")
		local first=lead.slots[lead.laid]
		assert(near(first.x,2.3)and near(math.abs(first.z),Glow.LeadSide),"beside the way")
		local look=CFrame.Angles(0,first.yaw,0).LookVector
		assert(near(look.X,1,1e-6)and near(look.Z,0,1e-6),"toes along the way (the part's -Z)")
		lead:step(.25,V(4.6,0),player);assert(lead.laid>0 and not lead.pat,"0.05 s later: a print, no pat")
		local second=lead.slots[lead.laid]
		assert(second.side==-first.side and(second.z>0)~=(first.z>0),"left, then right")
		lead:step(.5,V(6.9,0),player);assert(lead.laid>0 and lead.pat,"0.25 s on: a pat again")
		assert(lead:count()==3)
		-- Oldest first: the wave runs from the player's end to the pet's.
		local oldest=lead:oldest()
		assert(first.seq-oldest+1==1 and lead.slots[lead.laid].seq-oldest+1==3)
	end)

	test("the player's steps pop prints with sparkles; prints the player has passed go quietly; none under the player's feet",function()
		local lead=Glow.lead()
		local x=0
		lead:step(0,V(0,0),V(-6,0))
		for i=1,8 do x+=2.3;lead:step(i*.2,V(x,0),V(-6,0))end
		assert(lead:count()==8)
		local target=nil
		for i,slot in ipairs(lead.slots)do if slot.on and near(slot.x,2.3)then target=i end end
		lead:step(2,V(x,0),Vector3.new(lead.slots[target].x,0,lead.slots[target].z))
		assert(#lead.popped==1 and lead.popped[1]==target and lead.slots[target].sparkle==true and lead.slots[target].gone==2)
		assert(lead:count()==7,"popping is not live")
		lead:step(2+Glow.PopAway,V(x,0),V(-6,0))
		assert(not lead.slots[target].on,"gone once popped")
		-- The player walks past the rest off to the side: the passed ones go without sparkles.
		lead:step(3,V(x,0),V(x-1,3))
		assert(#lead.popped==0,"no sparkles for prints the player never stepped on")
		local quiet,kept=0,0
		for _,slot in ipairs(lead.slots)do
			if slot.on and slot.gone~=nil then assert(slot.sparkle==false);quiet+=1 elseif slot.on then kept+=1 end
		end
		assert(quiet==3 and kept==4,"the three passed prints go, the four by the pet stay: "..quiet..","..kept)
		-- The pet beside the player: no print where it would pop at once.
		local close=Glow.lead()
		close:step(0,V(0,0),V(2.5,0));close:step(.5,V(2.3,0),V(2.5,0))
		assert(close.laid==0)
	end)

	test("at most 12: the 12 nearest the player stay, the newest always shows; hold lays nothing; one fixed pool",function()
		local lead=Glow.lead()
		local slots=lead.slots
		local ids={}
		for i,slot in ipairs(slots)do ids[i]=slot end
		local player=V(-200,0)
		lead:step(0,V(0,0),player)
		local x=0
		for i=1,30 do
			x+=2.3
			lead:step(i*.2,V(x,0),player)
			assert(lead.laid>0 and slots[lead.laid].seq==lead.seq,"the newest shows")
			assert(lead:count()<=Glow.LeadMax)
		end
		assert(lead:count()==Glow.LeadMax)
		-- Kept: the newest and the 11 nearest the player (the earliest laid, for a player far behind).
		local kept={}
		for _,slot in ipairs(slots)do if slot.on then table.insert(kept,slot.seq)end end
		table.sort(kept)
		assert(kept[#kept]==30 and kept[1]==1 and kept[11]==11,"nearest the player: "..table.concat(kept,","))
		assert(#slots==Glow.LeadMax)
		for i,slot in ipairs(slots)do assert(ids[i]==slot,"the same slot tables, reused")end
		lead:hold(true)
		local before=lead.seq
		for i=31,40 do x+=2.3;lead:step(i*.2,V(x,0),player)end
		assert(lead.seq==before and lead.laid==0,"held: nothing new")
		lead:hold(false);x+=2.3;lead:step(9,V(x,0),player);assert(lead.laid>0)
		lead:clear();assert(lead:count()==0 and lead:oldest()==0)
		-- Glow.evict: a free slot first, then one already popping, then the farthest from the player.
		local list={{on=true,x=0,z=0},{on=false,x=0,z=0}}
		assert(Glow.evict(list,0,0)==2)
		list={{on=true,x=1,z=0},{on=true,x=9,z=0,gone=1},{on=true,x=5,z=0}}
		assert(Glow.evict(list,0,0)==2)
		list={{on=true,x=1,z=0},{on=true,x=9,z=0},{on=true,x=5,z=0}}
		assert(Glow.evict(list,0,0)==2)
	end)

	return{passed=#cases,cases=cases}
end
