-- Onboarding v3 slice B: the need bubbles over the Bear (BearNeeds, ONBOARDING-V3-PLAN-2026-11-23 section 4). The order,
-- closing from saved facts (a later one done first is skipped), each one tap away, the rest between two, never over
-- anything that must not be interrupted, the pill's place, returning saves, the nest waiting for the nest, the bits.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.BearNeeds)(PlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Coach=require(Shared.CoachMarks)
	local UICopy=require(Shared.UICopy)
	local Toys=require(Shared.ToyCatalog)
	local Needs=require(client.BearNeeds)
	local Tips=require(client.ThingsTips)
	local Guide=require(client.FirstSpendGuide)
	local Bubble=require(client.NeedBubble)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function with(base,t)local c=table.clone(base);for k,v in pairs(t or {})do c[k]=v end;return c end
	local FRESH={status="Ready",coachMask=0,totalWins=1,nectar=20,stats={rounds=1},petToys={},toyUnlocks={}}
	local function facts(state,live)return Needs.facts(with(FRESH,state),live)end

	test("five needs, in order, each its own appended bit, its icon and whole-sentence words",function()
		assert(table.concat(Needs.Order,",")=="needHi,needToy,needDeck,needNest,needPark")
		local icons={needHi="hand",needToy="ball",needDeck="deck",needNest="moon",needPark="paws"}
		for _,id in ipairs(Needs.Order)do
			assert(Coach.Bits[id]~=nil and Coach.Bits[id]>=20 and Coach.Bits[id]<=24,id)
			assert(Needs.Icon[id]==icons[id],id)
			local text=UICopy.get(Needs.Copy[id],{pet="Bear"})
			assert(text~=Needs.Copy[id]and string.find(text,"Bear",1,true)and string.sub(text,-1)=="."and not string.find(text,"{",1,true),text)
		end
		assert(Coach.Gated.needNest=="nest"and Coach.Gated.needHi=="needs"and Coach.Gated.needPark=="needs")
	end)
	test("the order: the first open one; a later one done first is skipped, never replayed",function()
		local on={on=true,owned=1}
		assert(Needs.current(facts(),on)=="needHi")
		assert(Needs.current(facts({coachMask=Coach.with(0,"needHi")}),on)=="needToy")
		assert(Needs.current(facts({},{saidHi=true}),on)=="needToy","said hi this session: closed without the bit yet")
		local played=facts({},{saidHi=true,deckDone=true})
		assert(Needs.current(played,on)=="needToy","the round came first: the toy is still asked for")
		local toy=facts({petToys={pip="ball"},toyUnlocks={ball=true}},{saidHi=true,deckDone=true})
		assert(Needs.current(toy,on)=="needPark","toy and round done: the deck is skipped, the nest waits, the park")
		assert(Needs.current(facts({petToys={pip="ball"}},{saidHi=true}),on)=="needDeck")
		local all=0;for _,id in ipairs(Needs.Order)do all=Coach.with(all,id)end
		assert(Needs.current(facts({coachMask=all}),on)==nil,"all done")
	end)
	test("needs close from saved facts",function()
		assert(Needs.closed("needToy",facts({petToys={pip="bone"}})),"a toy given")
		assert(not Needs.closed("needToy",facts({petToys={pip=Toys.Default}})),"the default toy is not a toy")
		assert(not Needs.closed("needToy",facts({toyUnlocks={ball=true}})),"bought but not given yet")
		assert(Needs.closed("needDeck",facts({stats={rounds=Needs.Rounds}}))and not Needs.closed("needDeck",facts({stats={rounds=1}})),"a round after the Welcome round")
		assert(Needs.closed("needPark",facts({playDate={count=1}}))and Needs.closed("needPark",facts({coachMask=Coach.with(0,"park")})),"a play date, the park's first visit")
		assert(Needs.closed("needPark",facts({},{inPark=true}))and not Needs.closed("needPark",facts()),"walked in")
		assert(Needs.closed("needNest",facts({nest={n=1}}))and Needs.closed("needNest",facts({nest={n=0,tucked=true}}))and not Needs.closed("needNest",facts({nest={n=0}})))
		for _,id in ipairs(Needs.Order)do assert(Needs.closed(id,facts({coachMask=Coach.with(0,id)})),id.." its bit")end
		assert(Needs.closed("needHi",facts({stats="junk",petToys="junk",playDate=7,nest="junk"},{saidHi=true})),"junk is tolerated")
	end)
	test("the nest waits for the nest: no `nest` in the snapshot, or none in the garden, and need 4 is skipped",function()
		local on={on=true,owned=1}
		local live={saidHi=true,deckDone=true}
		local base={petToys={pip="ball"},toyUnlocks={ball=true}}
		assert(Needs.current(facts(base,live),on)=="needPark","no nest field")
		assert(Needs.current(facts(with(base,{nest={n=0,at=1}}),live),on)=="needPark","a nest saved, not drawn yet")
		assert(Needs.current(facts(with(base,{nest={n=0,at=1}}),with(live,{nest=true})),on)=="needNest","drawn: the moon")
		assert(Needs.current(facts(base,with(live,{park=false})),on)==nil,"no Pet Park in this world: need 5 is skipped too")
		assert(Needs.target("needNest")=="Nest"and Needs.target("needPark")=="Park"and Needs.target("needToy",facts())=="Eggs"and Needs.target("needHi")==nil)
	end)
	test("no bubbles: switch off, a returning or veteran save, no pet yet",function()
		assert(Needs.current(facts(),{on=false,owned=1})==nil)
		assert(Needs.current(facts(),{on=true,owned=1,returning=true})==nil)
		assert(Needs.current(facts({totalWins=Coach.VeteranWins}),{on=true,owned=1})==nil)
		assert(Needs.current(facts(),{on=true,owned=0})==nil)
	end)
	test("need 2 with fewer Stars than a Toy Egg: the deck first, then the ball",function()
		assert(Needs.icon("needToy",facts({nectar=Toys.Cost}))=="ball")
		assert(Needs.icon("needToy",facts({nectar=Toys.Cost-1}))=="deck"and Needs.target("needToy",facts({nectar=3}))==nil)
		assert(Needs.icon("needToy",facts({nectar=0,toyUnlocks={ball=true}}))=="ball","already bought: give it")
	end)

	-- The controller, with the game as fakes.
	local function rig(over)
		local r={state=with(FRESH,over and over.state or {}),owned=1,mask=0,marked={},intro=0,trails={},acts={},quiet=nil,
			follow=true,returning=false,greeting=false,inPark=false,nest=false,chirps=0,reacts={},trailUp=false,
			gate={on=true,mode="Room",canRoam=true,idleFor=5,awayFor=0,roomFor=5,windowActive=true,railEmpty=true,parkPending=0,action="idle"}}
		for k,v in pairs(over or {})do if k~="state"then r[k]=v end end
		r.bubble={sets={},hops=0}
		function r.bubble:set(icon,visible)table.insert(self.sets,{icon=icon,visible=visible});self.icon=if visible then icon else nil end
		function r.bubble:hop()self.hops+=1 end
		function r.bubble:press()self.presses=(self.presses or 0)+1 end
		function r.bubble:step()end
		r.needs=Needs.new({bubble=r.bubble,state=function()return r.state end,owned=function()return r.owned end,mask=function()return r.mask end,
			mark=function(id)table.insert(r.marked,id);r.mask=Coach.with(r.mask,id)end,finishIntro=function()r.intro+=1;r.mask=Coach.with(r.mask,"gardenIntro")end,
			follow=function()return r.follow end,needs=function()return r.needsOn~=false end,returning=function()return r.returning end,
			gate=function()return r.gate end,greeting=function()return r.greeting end,inPark=function()return r.inPark end,nest=function()return r.nest end,
			place=function(where)return Vector3.new(#where,0,0),where end,
			trail=function(target,how)table.insert(r.trails,{name=target.name,how=how});r.trailUp=true;r.trailOn=target;return true end,trailActive=function()return r.trailUp end,
			trailTarget=function()return r.trailOn end,prompt=function()return r.prompt==true end,
			sayHi=function()table.insert(r.acts,"hi");return true end,playDeck=function()table.insert(r.acts,"deck");return true end,
			quiet=function(on)r.quiet=on end,chirp=function()r.chirps+=1 end,react=function(id)table.insert(r.reacts,id)end})
		r.t=0
		function r.run(seconds,dt)
			dt=dt or .25
			for _=1,math.max(1,math.floor(seconds/dt+.5))do r.t+=dt;r.needs:step(r.t,dt)end
		end
		return r
	end

	test("the first bubble waits for the garden to settle, then asks to say hi; a tap says hi; the greeting closes it",function()
		local r=rig({gate={on=true,mode="Room",canRoam=true,idleFor=5,awayFor=0,roomFor=0,windowActive=true,railEmpty=true,parkPending=0,action="idle"}})
		r.run(1);assert(r.bubble.icon==nil and not r.needs.ready,"settling")
		assert(r.quiet==true,"the pill is quiet from the first frame")
		r.gate.roomFor=5;r.run(.25)
		assert(r.needs.ready and r.needs.follow==true)
		r.run(Needs.Return);assert(r.bubble.icon=="hand","the hand bubble")
		assert(r.needs:tap()and r.acts[1]=="hi")
		r.greeting=true;r.gate.greeting=true;r.run(.5)
		assert(r.bubble.icon==nil,"hidden during the greeting shot")
		assert(table.find(r.marked,"needHi"),"closed and saved")
		assert(r.intro==1,"follow the Bear: Say hi done marks the garden step")
		r.greeting=false;r.gate.greeting=nil
		r.run(Needs.Rest-1);assert(r.bubble.icon==nil,"4 s of nothing")
		r.run(2);assert(r.bubble.icon=="ball","then the ball")
		assert(r.reacts[1]=="needHi")
		assert(#r.trails==1 and r.trails[1].name=="Eggs"and r.trails[1].how=="auto","the first trail starts by itself after Say hi")
		assert(r.needs:focus()=="Eggs","only Hatch eggs beckons")
	end)
	test("beta 14 B3a: the first Meet's greeting shot, before the bubbles are ready, never closes need 1",function()
		local r=rig({gate={on=true,mode="Room",canRoam=true,idleFor=5,awayFor=0,roomFor=0,windowActive=true,railEmpty=true,parkPending=0,action="idle"}})
		r.greeting=true;r.gate.greeting=true;r.run(1)
		assert(not r.needs.ready and not r.needs.live.saidHi,"the automatic greeting does not count")
		r.greeting=false;r.gate.greeting=nil;r.gate.roomFor=5;r.run(.25+Needs.Return)
		assert(r.bubble.icon=="hand"and not table.find(r.marked,"needHi"),"the hand bubble still asks")
		r.greeting=true;r.gate.greeting=true;r.run(.5)
		assert(r.needs.live.saidHi and table.find(r.marked,"needHi"),"a greeting once it has shown closes it")
	end)
	test("beta 14 B3a: bubbles off or a returning save: any greeting counts, as before",function()
		local off=rig({needsOn=false});off.greeting=true;off.run(.5)
		assert(off.needs.live.saidHi==true,"bubbles off")
		local back=rig({returning=true});back.greeting=true;back.run(.5)
		assert(back.needs.live.saidHi==true,"returning")
	end)
	test("beta 14 B3b: one action a tap (three handlers in one frame), a squash each, a repeated trail hops and chirps",function()
		local r=rig({state={coachMask=Coach.with(0,"needHi")}})
		r.run(4);assert(r.bubble.icon=="ball"and #r.trails==1 and r.trails[1].how=="auto")
		local hops,chirps=r.bubble.hops,r.chirps
		assert(r.needs:tap()and r.needs:tap()and r.needs:petTap("tap"),"all three report taken")
		assert(#r.trails==2 and r.trails[2].how=="tap"and r.bubble.presses==1,"one action and one squash")
		assert(r.bubble.hops==hops+1 and r.chirps==chirps+1,"the same trail again: a hop and a chirp")
		r.run(.25);assert(r.needs:tap()and #r.trails==3 and r.bubble.presses==2,"the next frame is a new tap")
		local timed=rig({state={coachMask=Coach.with(0,"needHi")}});local now=0
		timed.needs.d.clock=function()return now end
		timed.run(4);assert(timed.needs:tap());timed.run(.25);now=.1
		assert(timed.needs:tap()and #timed.trails==2,"within TapGap: still the one tap")
		now=.5;timed.run(.25);assert(timed.needs:tap()and #timed.trails==3)
	end)
	test("beta 14 B3b: the hand bubble: one physical tap is one greeting, whichever handler goes first",function()
		local a=rig();a.run(4);assert(a.bubble.icon=="hand")
		assert(a.needs:tap()and a.needs:petTap("tap")and #a.acts==1,"bubble first: the Bear's tap is swallowed")
		local b=rig();b.run(4)
		assert(not b.needs:petTap("tap")and b.needs:tap()and #b.acts==0,"the Bear first: it greets, the bubble's echo does nothing")
		b.run(.25);assert(b.needs:tap()and #b.acts==1,"the next frame is a new tap")
	end)
	test("beta 14 B3b: the bubble's screen hit area and its press squash",function()
		local c=Vector2.new(400,200)
		assert(Bubble.hits(c+Vector2.new(Bubble.HitSize*.5-1,0),c)and not Bubble.hits(c+Vector2.new(Bubble.HitSize*.5+1,0),c))
		assert(not Bubble.hits(nil,c)and not Bubble.hits(c,nil))
		assert(Bubble.pressScale(0)==1 and math.abs(Bubble.pressScale(Bubble.Press.down)-Bubble.Press.low)<1e-6)
		assert(Bubble.pressScale(-1)==nil and Bubble.pressScale(Bubble.Press.down+.7)==nil,"settled")
		local low=1;for t=0,.6,.01 do low=math.min(low,Bubble.pressScale(t)or 1)end
		assert(low>=Bubble.Press.low-1e-6,"never below the squash")
	end)
	test("each one tap away: the ball lays the prints, the deck opens a round",function()
		local r=rig({state={coachMask=Coach.with(0,"needHi")}})
		r.run(4);assert(r.bubble.icon=="ball")
		r.trails={};assert(r.needs:tap()and r.trails[1].name=="Eggs"and r.trails[1].how=="tap")
		r.state=with(r.state,{petToys={pip="ball"},toyUnlocks={ball=true}});r.run(Needs.Rest+Needs.Return)
		assert(r.bubble.icon=="deck"and table.find(r.marked,"needToy"),"toy given: the deck bubble")
		assert(r.needs:tap()and r.acts[1]=="deck")
		r.state=with(r.state,{stats={rounds=2}});r.run(Needs.Rest+Needs.Return)
		assert(table.find(r.marked,"needDeck")and r.bubble.icon=="paws","a round settled: the park (no nest yet)")
		r.trails={};assert(r.needs:tap()and r.trails[1].name=="Park")
		assert(r.needs:focus()=="Park")
		r.inPark=true;r.run(.5)
		assert(table.find(r.marked,"needPark")and r.bubble.icon==nil and r.needs.open==nil,"walked in: done")
	end)
	test("few Stars: the toy bubble is the deck, and a tap plays",function()
		local r=rig({state={coachMask=Coach.with(0,"needHi"),nectar=4}})
		r.run(4);assert(r.bubble.icon=="deck"and r.needs.open=="needToy")
		assert(r.needs:tap()and r.acts[1]=="deck")
		assert(#r.trails==0,"no trail to a machine they cannot pay at")
		r.state=with(r.state,{nectar=24,stats={rounds=2}});r.run(1)
		assert(r.bubble.icon=="ball"and r.needs.open=="needToy","the round paid: now the ball")
	end)
	test("never interrupts: every blocking case hides it, and it comes back after 2.5 s free",function()
		for reason,change in pairs({menu={modal=true},hatch={hatch=true},card={card=true},greeting={greeting=true},race={engaged=true},
			playDate={action="parkSwing"},petting={petting=true},purchase={purchase=true},reveal={revealPending=true},roam={mode="Board"},care={care=true}})do
			local r=rig();r.run(4);assert(r.bubble.icon=="hand",reason)
			local free=r.gate
			r.gate=with(free,change);r.run(.25);assert(r.bubble.icon==nil,reason.." hides it")
			assert(r.needs:tap()==false,reason.." no tap while hidden")
			r.gate=free;r.run(Needs.Return-.5);assert(r.bubble.icon==nil,reason.." not at once")
			r.run(1);assert(r.bubble.icon=="hand",reason.." back")
		end
		local r=rig();r.run(4)
		r.gate=with(r.gate,{idleFor=0,railEmpty=false});r.run(1);assert(r.bubble.icon=="hand","walking and a rail line do not hide it")
	end)
	test("the idle hint: standing still 20 s, the Bear chirps, the bubble hops, the prints replay; three times, then quiet",function()
		local r=rig({state={coachMask=Coach.with(0,"needHi")}})
		r.gate.idleFor=0;r.run(4);r.trails={}
		local start=r.chirps
		r.gate.idleFor=Tips.IdleHint;r.run(.25)
		assert(r.chirps==start+1 and r.bubble.hops>=1 and #r.trails==1 and r.trails[1].how=="idle")
		r.run(Tips.IdleHint-1);assert(r.chirps==start+1,"not again at once")
		r.run(Tips.IdleHint*4);assert(r.chirps==start+Tips.IdleHints,"three at most")
		r.gate=with(r.gate,{modal=true});r.run(Tips.IdleHint*2);assert(r.chirps==start+Tips.IdleHints)
		local track={}
		assert(not Tips.idleDue(track,nil,99,0)and not Tips.idleDue(track,"needHi",19,0)and Tips.idleDue(track,"needHi",20,0))
		assert(not Tips.idleDue(track,"needHi",40,10)and Tips.idleDue(track,"needHi",40,20)and Tips.idleDue(track,"needToy",20,21),"a new need counts again")
	end)
	test("returning and veteran saves: no bubbles, and the pill keeps its place",function()
		for _,over in ipairs({{returning=true},{state={coachMask=Coach.with(0,"gardenIntro")}},{state={totalWins=Coach.VeteranWins}}})do
			local r=rig(over);r.run(6)
			assert(r.bubble.icon==nil and r.needs.open==nil and r.quiet==false and #r.marked==0 and r.intro==0)
		end
		local r=rig({needsOn=false});r.run(6)
		assert(r.bubble.icon==nil and r.quiet==false,"switch off: no bubble, the pill as before")
	end)
	test("a quiet guide hides the pill (stage quiet) and still opens Hatch eggs from the bubble",function()
		local opened=0
		local guide=Guide.new({openEggs=function(kind)opened+=1;return kind=="toy"end,intent={}})
		local state={revision=1,inventoryMask=1,nectar=Toys.Cost,status="Ready",toyUnlocks={},petToys={}}
		guide:update(state,{eligible=true})
		assert(guide.stage=="purchase","off: the pill's stage, exactly as before")
		guide:setQuiet(true)
		assert(guide.stage=="quiet"and guide:openEggs()and opened==1)
		guide:update(state,{eligible=true});assert(guide.stage=="quiet","stays quiet across snapshots")
		guide:setQuiet(false);assert(guide.stage=="purchase")
		assert(Guide.shown("purchase",true)=="quiet"and Guide.shown("purchase",false)=="purchase"and Guide.shown("receipt",true)=="receipt"and Guide.shown("done",true)=="done")
	end)
	test("review 1: with the Things tips switch off the Bear still starts and the garden step is still marked",function()
		local tipsOff=rig();tipsOff.gate=with(tipsOff.gate,{on=false});tipsOff.run(Tips.IntroAfter+5)
		assert(not tipsOff.needs.ready and tipsOff.intro==0,"the tips gate as it was: held back for good")
		local r=rig();r.gate=Needs.gate(with(r.gate,{on=false}),true);r.run(Tips.IntroAfter+5)
		assert(r.needs.ready and r.bubble.icon=="hand"and r.intro==1,"Things on: the bubble, and gardenIntro after 60 s")
		assert(Needs.gate(nil,false).on==false and Needs.gate({on=true,mode="Room"},false).on==false and Needs.gate({on=false},true).mode==nil)
	end)
	test("review 2: giving up marks the garden step, brings the pill back and hides the bubble, once",function()
		local r=rig();r.run(4);assert(r.bubble.icon=="hand"and r.quiet==true and r.intro==0)
		r.needs:abandon()
		assert(r.intro==1 and r.quiet==false and r.bubble.icon==nil and r.needs.dead==true)
		r.needs:abandon();r.run(5);assert(r.intro==1 and r.bubble.icon==nil and r.quiet==false,"once, and nothing after")
		local done=rig({state={coachMask=Coach.with(0,"gardenIntro")}});done.run(4);done.needs:abandon()
		assert(done.intro==0,"a returning save: nothing to mark")
		local early=rig({owned=0});early.run(1);early.needs:abandon();assert(early.intro==0,"not ready: the tour was never skipped")
	end)
	test("review 4: the park line gives way only for a new player this session, once ready",function()
		local r=rig();assert(not r.needs:replacesParkLine(),"not ready yet")
		r.run(1);assert(r.needs:replacesParkLine())
		local back=rig({returning=true});back.run(1);assert(not back.needs:replacesParkLine(),"returning: the park line as before")
		local off=rig({needsOn=false});off.run(1);assert(not off.needs:replacesParkLine())
		r.needs:abandon();assert(not r.needs:replacesParkLine(),"given up")
		-- The tour (follow off) marks gardenIntro this session before the Bear is ready: still a new player.
		local toured=rig({follow=false,mask=Coach.with(0,"gardenIntro")});toured.run(4)
		assert(not toured.needs.returning and toured.needs:replacesParkLine()and toured.bubble.icon=="hand")
	end)
	test("never over a machine's prompt",function()
		local r=rig();r.run(4);assert(r.bubble.icon=="hand")
		r.prompt=true;r.run(.25);assert(r.bubble.icon==nil)
		r.prompt=false;r.run(.25);assert(r.bubble.icon=="hand")
	end)
	test("QA 1: a hit area of at least 96 px round the same 72 px bubble, and a steady place over a shuttling Bear",function()
		assert(Bubble.HitSize>=96 and Bubble.Size==72 and Bubble.HitSize>Bubble.Size)
		local spot={}
		local home=Vector3.new(0,6,0)
		assert(Bubble.follow(spot,home,.016)==home,"the first frame: over the Bear")
		-- The Bear's idle shuttle in its first minute: about 1.5 studs either way, every few seconds.
		for i=1,200 do
			local bear=home+Vector3.new(if math.floor(i/40)%2==0 then 1.5 else -1.5,0,0)
			assert(Bubble.follow(spot,bear,.016)==home,"a move under Dead studs is ignored")
		end
		-- A real walk: chased smoothly (no frame jumps more than a stud), then settled on the target.
		local far=home+Vector3.new(8,0,0)
		local last=spot.at
		for _=1,240 do
			local at=Bubble.follow(spot,far,.016)
			assert((at-last).Magnitude<1,"no jump");last=at
		end
		assert((last-far).Magnitude<=Bubble.Settle and not spot.chasing,"there, and still")
		local jump=far+Vector3.new(0,0,Bubble.Snap+1)
		assert(Bubble.follow(spot,jump,.016)==jump,"a teleport snaps")
		assert(Bubble.follow({at=home},home+Vector3.new(3,0,0),.016,true)==home+Vector3.new(3,0,0),"Reduced Motion: no glide")
		assert(Bubble.follow({at=home},home+Vector3.new(1,0,0),.016,true)==home,"Reduced Motion keeps the dead zone")
		assert(Bubble.follow({at=home},nil,.016)==home)
	end)
	test("QA 2: a tap on the Bear does the open need's action; the greeting stays the greeting; its key keeps petting",function()
		local r=rig({state={coachMask=Coach.with(0,"needHi")}});r.run(4);assert(r.bubble.icon=="ball")
		assert(not r.needs:petTap("key"),"E / ButtonX on the Bear: petting as before")
		r.trails={};assert(r.needs:petTap("tap")and r.trails[1]and r.trails[1].name=="Eggs","a tap on the Bear: the prints")
		r.state=with(r.state,{petToys={pip="ball"},toyUnlocks={ball=true}});r.run(Needs.Rest+Needs.Return)
		assert(r.bubble.icon=="deck"and r.needs:petTap("tap")and r.acts[#r.acts]=="deck","need 3 from the Bear: a round")
		r.state=with(r.state,{stats={rounds=2}});r.run(Needs.Rest+Needs.Return)
		r.trails={};assert(r.bubble.icon=="paws"and r.needs:petTap("tap")and r.trails[1].name=="Park","need 5 from the Bear: to the park")
		local hi=rig();hi.run(4);assert(hi.bubble.icon=="hand"and not hi.needs:petTap("tap"),"need 1: the greeting itself does it")
		local hidden=rig({state={coachMask=Coach.with(0,"needHi")}});hidden.run(4);hidden.gate=with(hidden.gate,{modal=true});hidden.run(.25)
		assert(not hidden.needs:petTap("tap"),"no bubble shown: the Bear's tap is the greeting")
		hidden.needs:abandon();assert(not hidden.needs:petTap("tap"))
	end)
	test("QA 3: the bubble's own key does its action while it shows, and is passed on otherwise",function()
		assert(Needs.Keys.Keyboard=="G"and Needs.Keys.Gamepad=="L2"and Needs.keyHint("Keyboard")=="G"and Needs.keyHint("Gamepad")=="L2"and Needs.keyHint("Touch")==nil)
		local r=rig();r.run(4);assert(r.bubble.icon=="hand")
		assert(r.needs:key()and r.acts[1]=="hi","need 1 on the key: Say hi")
		local toy=rig({state={coachMask=Coach.with(0,"needHi")}});toy.run(4);toy.trails={}
		assert(toy.needs:key()and toy.trails[1].name=="Eggs")
		toy.gate=with(toy.gate,{modal=true});toy.run(.25);assert(not toy.needs:key(),"hidden: the key passes")
		local off=rig({needsOn=false});off.run(4);assert(not off.needs:key())
	end)
	return{passed=#cases,cases=cases}
end
