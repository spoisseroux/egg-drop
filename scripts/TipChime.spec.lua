-- The new-tip chime (beta 12 QA S2, beta 14 QA Q6): six kalimba variants in a shuffle bag, three pitch steps never
-- twice running, silent without sounds, never twice in 20 s, never in a round, a race or a hatch, quiet.
-- Pure parts with a stand-in audio.
-- Usage (Client): require(ZZSpecs.TipChime)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client)
	local Chime=require(client.TipChime)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local all={1,2,3,4,5,6}

	test("no sounds uploaded: no variant is ready, the pick answers nil and a ring is a quiet no-op",function()
		assert(Chime.Count==6 and Chime.cue(3)=="tip_chime_3")
		assert(#Chime.ready({})==0 and Chime.pick({},{},.1,.2,.3)==nil)
		local audio={play=function()return true end}
		local chime=Chime.new({audio=audio,ids={},now=function()return 5 end,random=function()return .5 end})
		assert(chime.ring()==false and chime.last==nil,"nothing rang, so the gap has not started")
	end)
	test("the bag: all six once before any repeat; a refilled bag never opens on the one just played",function()
		for seed=0,40 do
			local state,seen,last={},{},nil
			for round=1,5 do
				seen={}
				for _=1,6 do
					local v,_,s=Chime.pick(state,all,(seed*7+round)/53%1,.3,.5)
					assert(v~=last,"never the same twice in a row")
					assert(not seen[v],"a repeat inside one bag")
					seen[v]=true;last=v;state=s
				end
			end
		end
	end)
	test("pitch: one of three steps, never the same step twice running, drift within 1.5%",function()
		local state={}
		local prevStep=nil
		for i=1,60 do
			local _,speed,s=Chime.pick(state,all,.4,(i*.37)%1,(i*.61)%1)
			assert(s.step~=prevStep,"the step changed")
			local base=Chime.Steps[s.step]
			assert(math.abs(speed/base-1)<=Chime.Drift+1e-9,"drift")
			prevStep=s.step;state=s
		end
		assert(Chime.Steps[1]==.944 and Chime.Steps[2]==1 and Chime.Steps[3]==1.122)
	end)
	test("only the variants with a sound are picked",function()
		local state={}
		for _=1,10 do
			local v,_,s=Chime.pick(state,{2,5},.7,.1,.5)
			assert(v==2 or v==5);state=s
		end
	end)
	test("once in 20 s; never in a round, a race or a hatch; quieter than the Stars",function()
		local clock,played,busy=0,{},{}
		local audio={play=function(_,cue,speed,volume)table.insert(played,{cue=cue,speed=speed,volume=volume});return true end}
		local chime=Chime.new({audio=audio,ids={11,12,13,14,15,16},now=function()return clock end,random=function()return .99 end,busy=function()return busy end})
		assert(chime.ring()and #played==1 and string.match(played[1].cue,"^tip_chime_%d$")and played[1].volume==.25)
		clock=19;assert(not chime.ring()and #played==1)
		clock=20;assert(chime.ring()and #played==2)
		assert(played[1].cue~=played[2].cue,"no repeat")
		for _,what in ipairs({"round","race","hatch"})do
			clock+=30;busy={[what]=true};assert(not chime.ring(),what)
		end
		busy={};assert(chime.ring())
	end)
	return{passed=#cases,cases=cases}
end
