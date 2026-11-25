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
	test("Studio check R9, Fable R10: the machine's attract ring is a 194 degree front arc, every sample on the front side",function()
		local Attract=require(client.StationAttract)
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		assert(Corner.RingArc==194 and Corner.Ring==3)
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
				assert(fromFacing<=97.8,string.format("%.2f",fromFacing))
				assert(fromFacing<105,"never in R9's grass sector (105 to 167 from the facing)")
				assert(sample.Magnitude>0)
			end
		end
		assert(near(covered,194,1e-6),"the segments cover 194 degrees: "..covered)
		assert(low>=-97.8 and high<=97.8,low..","..high)
		-- At r 3 the whole arc stays well inside the paving (r 15.5 round (-30, -4)).
		for _,radius in ipairs({3,3.6})do
			local worst=0
			for _,segment in ipairs(Attract.arcSegments(radius,Corner.RingArc,facing))do
				local p=Corner.Spot+segment.offset
				worst=math.max(worst,math.sqrt((p.X+30)^2+(p.Z+4)^2))
			end
			-- At 194 degrees r 3.6 would graze the paving's edge (15.47 of 15.5): the ring stays 3.
			if radius==3 then assert(worst<15.2,worst)else assert(worst>15.4,worst)end
		end
	end)
	test("beta (16) B1: a model seen before its parts is never cached half empty; it binds once whole; found by tag too; one warning",function()
		local now,warned=0,{}
		local lounge=Instance.new("Folder");lounge.Name="EggDropLounge"
		local tagged={}
		local machine=Machine.new({step=false,clock=function()return now end,cinematic={},corner=function()return true end,
			room=function()return lounge end,tagged=function()return tagged end,random=Random.new(3),
			warn=function(text)table.insert(warned,text)end,audio={play=function()return true end}})
		local function step(dt)now+=dt;machine:step(dt)end
		step(.1)
		assert(machine.parts==nil and string.find(machine:status(),"no EggMachine"),tostring(machine:status()))
		local model=Instance.new("Model");model.Name="EggMachine"
		local body=Instance.new("Part");body.Name="Body";body.Position=Vector3.new(-41,4,2);body.Parent=model
		model.Parent=lounge
		step(1)
		assert(machine.parts==nil and string.find(machine:status(),"Dial"),"half there: not cached")
		local dial=Instance.new("Part");dial.Name="Dial";dial.CFrame=CFrame.new(-41,6,4);dial.Parent=model
		local pivot=Instance.new("Attachment");pivot.Name="DialPivot";pivot.WorldCFrame=CFrame.new(-41,6,3.7);pivot.Parent=body
		step(1)
		assert(machine.parts~=nil and machine.parts.dial.part==dial and machine:status()==nil,"whole: bound")
		-- Not in the lounge but tagged (another parent): found by its tag.
		local other=Machine.new({step=false,clock=function()return now end,cinematic={},corner=function()return true end,
			room=function()return Instance.new("Folder")end,tagged=function()return{model}end,warn=function(text)table.insert(warned,text)end})
		other:step(.1)
		assert(other.parts~=nil and other.parts.model==model,"found by tag")
		-- Nothing to animate for WarnAfter seconds: one warning, with the reason, and a Turn says why, once.
		local lonely=Machine.new({step=false,clock=function()return now end,cinematic={},corner=function()return true end,
			room=function()return nil end,tagged=function()return{}end,warn=function(text)table.insert(warned,text)end})
		for _=1,30 do now+=1;lonely:step(1)end
		local count=0
		for _,text in ipairs(warned)do if string.find(text,"no machine to animate")then count+=1 end end
		assert(count==1,"one warning, not one a frame: "..count)
		lonely:openCrank();lonely.crank=nil;lonely:openCrank()
		count=0
		for _,text in ipairs(warned)do if string.find(text,"Turn pressed")then count+=1 end end
		assert(count==1)
		machine:destroy();other:destroy();lonely:destroy()
	end)
	test("beta (16) B3: the reveal's camera aims over the egg, never pulled sideways by the item's flight",function()
		local Aim=require(client.HatchAim)
		assert(Aim.target(Vector3.new(1.7,2.5,-.8),3)==Vector3.new(0,2.5,0))
		assert((Aim.target(nil,3)-Vector3.new(0,1.8,0)).Magnitude<1e-9)
	end)
	-- ── The capsule shot (beta 17 U5; CAPSULE-AND-HUD-LOOK 1) ─────────────────────────────────────────────────────────
	local function capsuleRig(options)
		options=options or {}
		local r={now=100,sounds={},pockets={},hud={},ghost={},on=true,capsule=options.capsule~=false,root=Vector3.new(-41,4.13,8),
			blocked=options.blocked or function()return false end}
		r.cinematic={}
		r.camera={CameraType="Custom",CFrame=CFrame.new(-30,10,20)}
		local lounge=Instance.new("Folder");lounge.Name="EggDropLounge"
		if options.model~=false then
			local model=Instance.new("Model");model.Name="EggMachine"
			local body=Instance.new("Part");body.Name="Body";body.Position=Vector3.new(-41,4.13+3.56,2);body.Size=Vector3.new(4.2,7.12,4.3);body.Parent=model
			local dial=Instance.new("Part");dial.Name="Dial";dial.CFrame=CFrame.new(-41,6,3.7);dial.Parent=model
			local pivot=Instance.new("Attachment");pivot.Name="DialPivot";pivot.WorldCFrame=CFrame.new(-41,6,3.7);pivot.Parent=body
			model.Parent=lounge
		end
		r.machine=Machine.new({step=false,clock=function()return r.now end,cinematic=r.cinematic,corner=function()return r.on end,
			room=function()return lounge end,tagged=function()return{}end,random=Random.new(9),reduced=function()return r.reduced==true end,
			root=function()return r.root end,capsule=function()return r.capsule end,cameraObject=function()return r.camera end,
			hud=function(visible)table.insert(r.hud,visible)end,ghost=function(alpha)table.insert(r.ghost,alpha)end,
			blocked=function(a,b)return r.blocked(a,b)end,pocket=function(kind,sched)table.insert(r.pockets,{kind=kind,sched=sched})end,
			warn=function()end,audio={play=function(_,name)table.insert(r.sounds,{name=name,at=r.now});return true end}})
		function r.advance(seconds,step)
			step=step or 1/60
			local left=seconds
			while left>1e-9 do local dt=math.min(step,left);r.now+=dt;left-=dt;r.machine:step(dt)end
		end
		function r.heard(name)for _,s in ipairs(r.sounds)do if s.name==name then return s.at-r.at end end;return nil end
		function r.buy(id,action)
			r.at=r.now
			assert(r.machine:bought(action or "toyBuy",id))
			local reveal={}
			r.cinematic.onPlay(reveal)
			return reveal
		end
		return r
	end
	test("capsule: the schedules: first 2.0 s (roll .40 s, land 1.35), 2nd 1.30, 3rd .95, pocket 1.0, Reduced Motion on the thud",function()
		local S=Machine.Shots
		assert(S.first.start==2.00 and near(S.first.land,1.35)and near(S.first.rollSeconds,.40)and near(S.first.clunk,.90)and #S.first.clicks==5)
		assert(near(S.first.roll+S.first.rollSeconds,S.first.land)and S.first.shine==1.50 and near(S.first.rise+S.first.riseSeconds,S.first.start))
		assert(S.second.start==1.30 and near(S.second.land,.87)and #S.second.clicks==3)
		assert(S.third.start==.95 and near(S.third.land,.62)and #S.third.clicks==1)
		assert(S.pocket.start==1.00 and near(S.pocket.land,.75)and #S.pocket.clicks==3)
		assert(S.reduced.start==S.reduced.land and near(S.reduced.land,.62))
		for _,s in pairs(S)do assert(near(s.turnFrom+s.seconds,s.clunk),s.mode)end
		assert(Machine.shotSchedule("shot",1)==S.first and Machine.shotSchedule("shot",2)==S.second and Machine.shotSchedule("shot",7)==S.third)
		assert(Machine.shotSchedule("pocket",3)==S.pocket and Machine.shotSchedule("reduced",1)==S.reduced)
	end)
	test("capsule: at the machine: the panel tucks, the camera goes A then B, the reveal is held to 2.0 s (cap 2.2), the thud once",function()
		local r=capsuleRig()
		local reveal=r.buy("c-1")
		local shot=r.machine.shot
		assert(shot and shot.mode=="shot"and shot.frames and r.camera.CameraType~="Custom","Scriptable on the confirmation")
		assert(r.hud[1]==false and r.ghost[1]==1,"the dock hides, the player goes see-through")
		assert(r.cinematic.gate(reveal),"the reveal's clock is held")
		r.advance(.3)
		assert((r.camera.CFrame.Position-shot.frames.A.Position).Magnitude<.05,"Shot A by .30")
		r.advance(1.0)
		assert((r.camera.CFrame.Position-shot.frames.B.Position).Magnitude<.05,"Shot B by 1.30")
		r.advance(.6)
		assert(near(r.heard("land")or -1,1.35,.03)and near(r.heard("crank_clunk")or -1,.90,.03)and r.heard("cup_shine"))
		assert(r.cinematic.gate(reveal),"still held at 1.9")
		r.advance(.12)
		assert(not r.cinematic.gate(reveal),"the reveal starts at 2.0")
		assert(shot.panelBack and r.hud[#r.hud]==true,"the panel and the dock are back")
		local lands=0;for _,s in ipairs(r.sounds)do if s.name=="land"then lands+=1 end end
		assert(lands==1,"one egg, one landing")
		r.advance(3)
		assert(r.camera.CameraType~="Custom","the camera holds at Shot B while the reveal is up")
		r.machine:revealClosed();r.advance(.4)
		assert(r.camera.CameraType=="Custom"and r.machine.shot==nil and r.ghost[#r.ghost]==0,"given back on close")
	end)
	test("capsule: Hatch another starts at Shot B (1.30 s, then .95 s); after the camera went back, a first shot again",function()
		local r=capsuleRig()
		r.buy("h-1");r.advance(2.2)
		local second=r.buy("h-2")
		assert(r.machine.shot.sched==Machine.Shots.second)
		r.advance(1.25);assert(r.cinematic.gate(second));r.advance(.1);assert(not r.cinematic.gate(second))
		r.buy("h-3");assert(r.machine.shot.sched==Machine.Shots.third)
		r.advance(1);r.machine:revealClosed();r.advance(.5)
		r.buy("h-4")
		assert(r.machine.shot.sched==Machine.Shots.first,"the camera had gone back: Shot A again")
	end)
	test("capsule: the pocket version: no model, more than 24 studs off, both line checks blocked, or the Stat Egg",function()
		for _,case in ipairs({{model=false},{far=true},{blocked=function()return true end},{stat=true}})do
			local r=capsuleRig({model=case.model,blocked=case.blocked})
			if case.far then r.root=Vector3.new(-41,4,40)end
			r.at=r.now
			if case.stat then r.machine:bought("statEggBuy",nil);r.machine:confirm(nil)
			else r.buy("p-1","hueBuy")end
			assert(r.machine.shot.mode=="pocket"and r.camera.CameraType=="Custom"and #r.hud==0,"no camera, no tuck")
			if not case.stat then
				assert(r.pockets[1].kind=="hue","the preview well's drop, in the bought type")
				local gate=r.machine.gate
				assert(near(gate.release-r.at,1.0),"the reveal at 1.0 s")
			end
		end
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		local frame=Corner.frame(4.13)
		local mirrored=capsuleRig({blocked=function(_,at)return frame:PointToObjectSpace(at).X>0 end})
		mirrored.buy("m-1")
		assert(mirrored.machine.shot.mode=="shot","the mirrored side is clear: still the shot")
	end)
	test("capsule: Reduced Motion: no tuck, no camera; the static card waits for the thud (.62 s)",function()
		local r=capsuleRig()
		r.reduced=true
		local reveal=r.buy("r-1")
		assert(r.machine.shot.mode=="reduced"and r.camera.CameraType=="Custom"and #r.hud==0)
		r.advance(.6);assert(r.cinematic.gate(reveal));r.advance(.05);assert(not r.cinematic.gate(reveal))
		assert(near(r.heard("land"),.62,.02))
	end)
	test("capsule: skip jumps to the landing (the thud plays, the reveal .12 s later); never the first drop of a type",function()
		local r=capsuleRig()
		local reveal=r.buy("s-1")
		reveal.canSkip=function()return false end
		r.advance(.2)
		assert(r.machine:shotActive()and not r.machine:skipShot(),"the first drop of this type")
		reveal.canSkip=function()return true end
		local before=#r.sounds
		assert(r.machine:skipShot())
		r.advance(.02)
		local clicks=0;for i=before+1,#r.sounds do if string.match(r.sounds[i].name,"^crank_click")then clicks+=1 end end
		assert(clicks==0,"no burst of clicks")
		assert(r.heard("land"),"the thud is never skipped")
		r.advance(.08);assert(r.cinematic.gate(reveal));r.advance(.05);assert(not r.cinematic.gate(reveal),"the reveal .12 s later")
		assert(not r.machine:skipShot(),"once")
		assert(r.cinematic.onGateSkip~=nil,"the reveal's own skip asks the machine")
	end)
	test("capsule: the camera is given back at once when the corner or the capsule switch goes off, or on respawn (returnCamera)",function()
		local r=capsuleRig()
		r.buy("g-1");r.advance(.5)
		r.capsule=false;r.advance(.02)
		assert(r.camera.CameraType=="Custom"and r.machine.shot==nil and r.machine.gate==nil or not r.cinematic.gate({}))
		local again=capsuleRig()
		again.buy("g-2");again.advance(.5);again.machine:returnCamera(true)
		assert(again.camera.CameraType=="Custom")
	end)
	test("capsule off: the crank and its 1 s hold exactly as before",function()
		local r=capsuleRig({capsule=false})
		local reveal=r.buy("o-1")
		assert(r.machine.shot==nil and r.camera.CameraType=="Custom")
		r.advance(.8);assert(r.cinematic.gate(reveal));r.advance(.1);assert(not r.cinematic.gate(reveal),"released at the .85 landing")
	end)
	test("code review of 071d8a6: the camera held at Shot B goes back when the next buy is a pocket one",function()
		local r=capsuleRig()
		r.buy("v-1");r.advance(2.2)
		assert(r.camera.CameraType~="Custom","held at Shot B behind the reveal")
		r.root=Vector3.new(-41,4,60) -- walked off
		r.buy("v-2")
		assert(r.machine.shot.mode=="pocket"and r.camera.CameraType=="Custom"and r.ghost[#r.ghost]==0,"given back at once")
	end)
	test("code review of 071d8a6: a second reveal during the shot waits for the shot's reveal; the skip keys are bound only while it plays",function()
		local r=capsuleRig()
		local bound={}
		r.machine.d.skipInput=function(on)table.insert(bound,on)end
		local first=r.buy("q-1")
		assert(bound[1]==true,"bound with the shot")
		r.advance(.5)
		local second={}
		r.cinematic.onPlay(second)
		assert(r.cinematic.gate(second),"queued behind the shot")
		r.advance(1.4)
		assert(r.cinematic.gate(second)and r.cinematic.gate(first))
		r.advance(.15)
		assert(not r.cinematic.gate(second)and not r.cinematic.gate(first),"both go when the shot's reveal starts")
		assert(bound[#bound]==false,"unbound when the shot is over")
	end)
	test("code review of 071d8a6: the tuck stops at the screen's shade (SafeContent's child), never SafeContent",function()
		local gui=Instance.new("ScreenGui");gui.Name="EggDropOverlays"
		local safe=Instance.new("Frame");safe.Name="SafeContent";safe.Parent=gui
		local shade=Instance.new("Frame");shade.Name="EggHatchView";shade.Parent=safe
		local card=Instance.new("Frame");card.Name="Card";card.Parent=shade
		local frame=Instance.new("Frame");frame.Name="HatchCinematic";frame.Parent=card
		local roots=Machine.panelRoots({frame=frame})
		assert(#roots==1 and roots[1]==shade,tostring(roots[1]and roots[1].Name))
	end)
	return{passed=#cases,cases=cases}
end
