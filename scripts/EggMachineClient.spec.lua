-- The egg machine's client (EggMachineClient; EGG-CORNER-LOOK 2, EGG-CORNER-BUILD-PLAN 7 and the architect's review):
-- the open and buy crank schedules, the streaks, a press during a crank merges and a retried send never starts another,
-- the reveal hold (only the reveal the buy started, only until the landing, never past 1 s from the first press), a
-- refused buy drops nothing, the Stat Egg's egg rolls on schedule, the sounds, and the corner off. No world: the room is
-- nil, the clock is fake, the cinematic is a stand-in table with the same two fields.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.EggMachineClient)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py.
return function(client)
	local Machine=require(client.EggMachineClient)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local function rig(options)
		options=options or {}
		local r={now=100,sounds={},buzz={},on=options.on~=false}
		r.cinematic={}
		r.machine=Machine.new({step=false,clock=function()return r.now end,cinematic=r.cinematic,corner=function()return r.on end,
			room=function()return nil end,random=Random.new(7),
			audio={play=function(_,name,speed,volume)table.insert(r.sounds,{name=name,speed=speed,volume=volume,at=r.now});return true end},
			haptic=function(strength)table.insert(r.buzz,strength)end})
		function r.advance(seconds,step)
			step=step or 1/60
			local left=seconds
			while left>1e-9 do
				local dt=math.min(step,left)
				r.now+=dt;left-=dt
				r.machine:step(dt)
			end
		end
		function r.count(name)local n=0;for _,s in ipairs(r.sounds)do if s.name==name then n+=1 end end;return n end
		return r
	end

	test("the buy schedules: full turn .6 s (5 clicks), half .45 (3), quarter .25 (1); clunk at the turn's end, lands .25 later (.85 / .70 / .50)",function()
		local one,two,three=Machine.schedule(1),Machine.schedule(2),Machine.schedule(3)
		assert(one.turn==360 and #one.clicks==5 and near(one.clunk,.6)and near(one.roll,.62)and near(one.land,.85))
		assert(two.turn==180 and #two.clicks==3 and near(two.land,.70))
		assert(three.turn==90 and #three.clicks==1 and near(three.land,.50))
		assert(Machine.schedule(9).turn==90 and Machine.schedule(0).turn==360)
		assert(one.clicks[5]==.44 and two.clicks[2]==.15)
	end)
	test("streaks: Hatch another within 20 s of the last landing; later starts again at 1",function()
		assert(Machine.streak(nil,nil,10)==1 and Machine.streak(1,0,19)==2 and Machine.streak(2,0,20)==3 and Machine.streak(3,0,20.5)==1)
	end)
	test("the dial: open eases to 96 (overshoot 6) by .28 and settles to 90; the buy turn is even after 60 ms and springs back 8 at the clunk",function()
		assert(near(Machine.openAngle(.28),96)and near(Machine.openAngle(1),90)and Machine.openAngle(0)==0)
		local s=Machine.schedule(1)
		assert(Machine.buyAngle(s,.03)<360*.03/.6,"resistance at the start")
		assert(near(Machine.buyAngle(s,.6),360,1e-3))
		assert(near(Machine.buyAngle(s,.6+.075),352,1e-3)and near(Machine.buyAngle(s,1),360))
	end)
	test("the roll: chute top to chute end on the leaf, then into the cup",function()
		local a,b,c=Vector3.new(0,1,0),Vector3.new(1,.5,0),Vector3.new(1.2,.3,0)
		assert(Machine.rollAt(a,b,c,0)==a and(Machine.rollAt(a,b,c,Machine.RollSeconds)-c).Magnitude<1e-6)
	end)
	test("open crank: clicks at 0 / 90 / 180 ms and one knock; a second press inside it is ignored; the corner off does nothing",function()
		local r=rig()
		assert(r.machine:openCrank())
		assert(not r.machine:openCrank(),"a second press inside the crank")
		r.advance(.5)
		assert(r.count("crank_click_1")==1 and r.count("crank_click_2")==1 and r.count("crank_click_3")==1)
		assert(r.count("egg_tok_1")+r.count("egg_tok_2")+r.count("egg_tok_3")==1)
		assert(#r.buzz==3)
		assert(r.machine:openCrank(),"a new crank once the last is over")
		local off=rig({on=false})
		assert(not off.machine:openCrank()and not off.machine:bought("toyBuy","a"))
	end)
	test("a buy: 5 clicks rising 4% each, clunk at .6, roll and the landing thud once at .85, after its reveal started",function()
		local r=rig()
		assert(r.machine:bought("toyBuy","id-1"))
		local reveal={}
		r.advance(.2)
		r.cinematic.onPlay(reveal) -- the result came back
		r.advance(1)
		assert(r.count("crank_click_1")==2 and r.count("crank_click_2")==2 and r.count("crank_click_3")==1)
		local pitches={}
		for _,s in ipairs(r.sounds)do if string.match(s.name,"^crank_click")then table.insert(pitches,s.speed)end end
		assert(near(pitches[5],1.16,1e-6),tostring(pitches[5]))
		assert(r.count("crank_clunk")==1 and r.count("egg_roll")==1 and r.count("land")==1)
		local landAt
		for _,s in ipairs(r.sounds)do if s.name=="land"then landAt=s.at end end
		assert(near(landAt-100,.85,1/60+1e-6),tostring(landAt))
	end)
	test("the hold: only the reveal that started after the press, only until the landing; others never",function()
		local r=rig()
		local before={}
		r.cinematic.onPlay(before) -- an older reveal (Hatch another's stage) asks too
		r.machine:bought("hueBuy","h-1")
		assert(not r.cinematic.gate(before),"nothing is claimed yet")
		r.advance(.1)
		local mine={}
		r.cinematic.onPlay(mine)
		assert(r.cinematic.gate(mine)and not r.cinematic.gate(before))
		r.advance(.6)
		assert(r.cinematic.gate(mine),"held until the landing")
		r.advance(.2)
		assert(not r.cinematic.gate(mine),"released at .85")
	end)
	test("the cap: a late result is never held past 1 s from the first press; a refused buy (no reveal) drops nothing",function()
		local r=rig()
		r.machine:bought("toyBuy","t-1")
		r.advance(.95)
		local late={}
		r.cinematic.onPlay(late)
		assert(r.cinematic.gate(late),"claimed at .95, still under the cap")
		r.advance(.06)
		assert(not r.cinematic.gate(late),"the cap")
		local refused=rig()
		refused.machine:bought("toyBuy","t-2")
		refused.advance(2)
		assert(refused.count("crank_clunk")==1 and refused.count("egg_roll")==0 and refused.count("land")==0)
		assert(refused.machine:bought("toyBuy","t-3"),"the next press starts again")
	end)
	test("a retried send of the same action never starts another crank; a press during a crank merges into it",function()
		local r=rig()
		assert(r.machine:bought("featureBuy","f-1"))
		assert(not r.machine:bought("featureBuy","f-1"),"the retry (FeatureIntent resends p.value)")
		r.advance(.3)
		assert(not r.machine:bought("toyBuy","t-9"),"merged: no second crank or egg")
		local mine={}
		r.cinematic.onPlay(mine)
		r.advance(1)
		assert(r.count("crank_clunk")==1 and r.count("land")==1)
		assert(not r.machine:bought("nameEggBuy","n-1")and not r.machine:bought("wearableBuy","w-1"),"not a machine egg")
	end)
	test("Hatch another within 20 s: a half turn, then a quarter",function()
		local r=rig()
		for index,clicks in ipairs({5,3,1})do
			local before=r.count("crank_click_1")+r.count("crank_click_2")+r.count("crank_click_3")
			assert(r.machine:bought("toyBuy","s-"..index))
			r.cinematic.onPlay({})
			r.advance(8)
			local after=r.count("crank_click_1")+r.count("crank_click_2")+r.count("crank_click_3")
			assert(after-before==clicks,index..": "..(after-before))
		end
		r.advance(25)
		assert(r.machine:bought("toyBuy","s-4")and r.machine.crank.sched.turn==360,"after the window: a full turn again")
	end)
	test("the Stat Egg (its reveal is not the cinematic) rolls on schedule",function()
		local r=rig()
		r.machine:bought("statEggBuy",nil)
		r.advance(1)
		assert(r.count("egg_roll")==1 and r.count("land")==1)
	end)
	test("destroy takes the hold off the cinematic",function()
		local r=rig()
		assert(type(r.cinematic.gate)=="function"and type(r.cinematic.onPlay)=="function")
		r.machine:destroy()
		assert(r.cinematic.gate==nil and r.cinematic.onPlay==nil)
	end)
	return{passed=#cases,cases=cases}
end
