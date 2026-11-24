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
			room=function()return nil end,random=Random.new(7),rejected=function(action)return r.rejected~=nil and r.rejected[action]==true end,
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
	test("a buy: the crank turns when its reveal starts: 5 clicks rising 4% each, clunk at .6, the landing thud once .85 later",function()
		local r=rig()
		assert(r.machine:bought("toyBuy","id-1"))
		local reveal={}
		r.advance(.2)
		assert(r.count("crank_click_1")==0,"armed only: nothing turns before the buy is confirmed")
		r.cinematic.onPlay(reveal) -- the result came back
		r.advance(1)
		assert(r.count("crank_click_1")==2 and r.count("crank_click_2")==2 and r.count("crank_click_3")==1)
		local pitches={}
		for _,s in ipairs(r.sounds)do if string.match(s.name,"^crank_click")then table.insert(pitches,s.speed)end end
		assert(near(pitches[5],1.16,1e-6),tostring(pitches[5]))
		assert(r.count("crank_clunk")==1 and r.count("egg_roll")==1 and r.count("land")==1)
		local landAt
		for _,s in ipairs(r.sounds)do if s.name=="land"then landAt=s.at end end
		assert(near(landAt-100.2,.85,1/60+1e-6),tostring(landAt))
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
		r.advance(.8)
		assert(r.cinematic.gate(mine),"held until the landing (.85 after the confirmation)")
		r.advance(.1)
		assert(not r.cinematic.gate(mine),"released at the landing")
	end)
	test("a late result: the crank and the hold start with it (Fable R8), held until its landing; a refused buy drops nothing",function()
		local r=rig()
		r.machine:bought("toyBuy","t-1")
		r.advance(.95)
		local late={}
		r.cinematic.onPlay(late)
		assert(r.cinematic.gate(late)and r.machine.crank.at==r.now,"the crank and the hold start on the result")
		assert(r.machine.gate.cap==r.now+Machine.Cap)
		r.advance(.8)
		assert(r.cinematic.gate(late),"still held: the egg has not landed")
		r.advance(.1)
		assert(not r.cinematic.gate(late),"released at its landing")
		local refused=rig()
		refused.machine:bought("toyBuy","t-2")
		refused.advance(4)
		assert(#refused.sounds==0 and #refused.buzz==0,"a refused buy turns nothing at all (Studio check R8)")
		assert(refused.machine.crank==nil and refused.machine.armed==nil,"the armed press lapsed")
		assert(refused.machine:bought("toyBuy","t-3"),"the next press arms again")
	end)
	test("a retried send of the same action never starts another crank; a press during a crank merges into it",function()
		local r=rig()
		assert(r.machine:bought("featureBuy","f-1"))
		assert(not r.machine:bought("featureBuy","f-1"),"the retry (FeatureIntent resends p.value)")
		local mine={}
		r.cinematic.onPlay(mine)
		r.advance(.3)
		assert(not r.machine:bought("toyBuy","t-9"),"merged: no second crank or egg")
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
		assert(r.machine:bought("toyBuy","s-4"));r.cinematic.onPlay({})
		assert(r.machine.crank.sched.turn==360,"after the window: a full turn again")
	end)
	test("the Stat Egg (its reveal is not the cinematic) turns on its Saved answer (confirm), never on a reveal",function()
		local r=rig()
		r.machine:bought("statEggBuy",nil)
		r.cinematic.onPlay({})
		r.advance(.5)
		assert(r.count("crank_clunk")==0,"a reveal does not confirm the Stat Egg")
		assert(r.machine:confirm(nil))
		r.advance(1)
		assert(r.count("egg_roll")==1 and r.count("land")==1)
	end)
	test("Fable R8: a press the intent says Rejected gets the hello nudge and one click at once: no crank, no streak step",function()
		local r=rig()
		r.machine:bought("toyBuy","n-1");r.cinematic.onPlay({});r.advance(2)
		local before=#r.sounds
		r.machine:bought("toyBuy","n-2")
		r.rejected={toyBuy=true}
		r.advance(.05)
		assert(r.machine.armed==nil and r.machine.crank.landed and r.machine.crank.streak==nil,"no new crank: the last is the first hatch, landed")
		assert(#r.sounds==before+1 and r.sounds[#r.sounds].name=="crank_click_1","one click")
		assert(r.now-r.machine.helloAt<.1,"the hello nudge")
		r.rejected=nil
		r.machine:bought("toyBuy","n-3");r.cinematic.onPlay({})
		assert(r.machine.crank.sched.turn==180,"the refusal did not count: this is the 2nd")
		local stat=rig()
		stat.machine:bought("statEggBuy",nil)
		assert(stat.machine:refuse()and stat.count("crank_click_1")==1 and not stat.machine:confirm(nil))
	end)
	test("Studio check R8: Hatch another refused (no reveal) turns nothing and never uses up a streak step",function()
		local r=rig()
		r.machine:bought("toyBuy","a-1");r.cinematic.onPlay({});r.advance(2) -- the first hatch landed
		local clicks=r.count("crank_click_1")+r.count("crank_click_2")+r.count("crank_click_3")
		r.machine:bought("toyBuy","a-2");r.advance(4)                       -- Hatch another, refused
		assert(r.count("crank_click_1")+r.count("crank_click_2")+r.count("crank_click_3")==clicks and r.count("crank_clunk")==1)
		r.machine:bought("toyBuy","a-3");r.cinematic.onPlay({})             -- the next one that hatches
		assert(r.machine.crank.sched.turn==180,"still the 2nd of the streak: a half turn")
		assert(not r.machine:confirm(nil),"nothing armed any more")
		r.advance(.01)
		r.machine:bought("toyBuy","a-4");r.advance(Machine.ConfirmWindow+.1)
		assert(not r.machine:confirm({}),"an armed press lapses after the confirm window")
	end)
	test("destroy takes the hold off the cinematic",function()
		local r=rig()
		assert(type(r.cinematic.gate)=="function"and type(r.cinematic.onPlay)=="function")
		r.machine:destroy()
		assert(r.cinematic.gate==nil and r.cinematic.onPlay==nil)
	end)
	test("review 1: Turn is refused only while an open crank runs or a buy has not landed; a landed egg never blocks it",function()
		local r=rig()
		r.machine:bought("toyBuy","r1-1")
		r.cinematic.onPlay({})
		r.advance(.3)
		assert(r.machine:busy()and not r.machine:openCrank(),"the buy is still turning: init opens the screen at once instead")
		r.advance(.7)
		assert(r.machine.crank.landed and not r.machine.crank.done,"landed, the egg lingers in the cup")
		assert(not r.machine:busy()and r.machine:openCrank(),"Turn works while the egg lingers")
		assert(r.machine.crank.kind=="open")
		assert(r.machine:busy()and not r.machine:openCrank(),"a second press inside the open crank")
		r.advance(.5)
		assert(not r.machine:busy())
	end)
	test("review 1: the egg in the cup fades 1.5 s after the hatch screen closes (revealClosed), not 6 s after landing",function()
		local r=rig()
		r.machine:bought("toyBuy","r1-2")
		r.cinematic.onPlay({})
		r.advance(1)
		assert(r.machine.crank.landed and not r.machine.crank.done)
		r.machine:revealClosed()
		r.advance(Machine.FadeAfter+.5+.05)
		assert(r.machine.crank.done,"faded and done well before Linger")
		local old=rig()
		old.machine:revealClosed() -- a close before the press never counts
		old.advance(.1)
		old.machine:bought("toyBuy","r1-3");old.cinematic.onPlay({});old.advance(3)
		assert(old.machine.crank.landed and not old.machine.crank.done)
	end)
	test("review 2: a Stat Egg buy makes no gate, so a reveal that plays meanwhile is never held",function()
		local r=rig()
		r.machine:bought("statEggBuy",nil)
		assert(r.machine.gate==nil)
		local other={}
		r.cinematic.onPlay(other)
		assert(not r.cinematic.gate(other),"not caught by the Stat Egg's crank")
		assert(r.machine:confirm(nil),"its Saved answer")
		r.advance(1)
		assert(r.count("land")==1,"its own egg still rolls")
	end)
	test("Studio check R9: the machine's attract ring is a 200 degree front arc, every sample on the front side",function()
		local Attract=require(client.StationAttract)
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		assert(Corner.RingArc==200 and Corner.Ring==3)
		local facing=Corner.facing()
		local want=(Corner.Face-Corner.Spot)
		assert(math.abs(facing:Dot(Vector3.new(want.X,0,want.Z).Unit)-1)<1e-9,"centred on the machine's facing")
		local segments=Attract.arcSegments(Corner.Ring,Corner.RingArc,facing)
		assert(#segments==25,#segments)
		local low,high,covered=math.huge,-math.huge,0
		for _,segment in ipairs(segments)do
			assert(near(segment.offset.Magnitude,Corner.Ring,1e-9)and segment.offset.Y==0)
			-- Both ends of every segment, from the facing: never past +-100 (R9: grass from 105).
			local half=math.deg(segment.length/2/Corner.Ring)
			low=math.min(low,segment.angle-half);high=math.max(high,segment.angle+half)
			local measured=math.deg(math.acos(math.clamp(segment.offset.Unit:Dot(facing),-1,1)))
			assert(near(measured,math.abs(segment.angle),1e-6),"each angle is measured from the facing")
			covered+=math.deg(2*math.asin((segment.length-.04)/2/Corner.Ring))
			-- Every sample along the segment (the R9 probe's 128 rays would land inside these).
			for k=0,8 do
				local a=math.rad(segment.angle)+(k/8-.5)*math.rad(2*half)
				local sample=Vector3.new(math.cos(a),0,math.sin(a))
				local fromFacing=math.deg(math.abs(a))
				assert(fromFacing<=100.8,string.format("%.2f",fromFacing))
				assert(fromFacing<105,"never in R9's grass sector (105 to 167 from the facing)")
				assert(sample.Magnitude>0)
			end
		end
		assert(near(covered,200,1e-6),"the segments cover 200 degrees: "..covered)
		assert(low>=-100.8 and high<=100.8,low..","..high)
		-- At r 3 the whole arc stays inside the paving (r 15.5 round (-30, -4)); 3.6 would not.
		for _,radius in ipairs({3,3.6})do
			local worst=0
			for _,segment in ipairs(Attract.arcSegments(radius,Corner.RingArc,facing))do
				local p=Corner.Spot+segment.offset
				worst=math.max(worst,math.sqrt((p.X+30)^2+(p.Z+4)^2))
			end
			if radius==3 then assert(worst<15.5,worst)else assert(worst>15.5,worst)end
		end
	end)
	return{passed=#cases,cases=cases}
end
