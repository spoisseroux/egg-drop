-- Onboarding part 2 (TeachLessons, TeachPointer; ONBOARDING-P2-BRIEF section 2, ARCH-REVIEW-P2 sections 1 and 4; Onboard
-- "teach"): each lesson is done only by its saved fact, whoever caused it; never by a timer; one pointer at a time, the
-- first lesson whose button is on screen; "Later" skips Dress up to the deck; "What's next?" asks for the Menu; ignored
-- 12 s: it fades and waits for the next session; a rejoin lets the deck come first; veterans and unowed saves: nothing.
-- The pointer's pulse, dip, label words and spot. Fake deps and a fake clock only.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(PlayerScripts.Client.ZZSpecs.TeachLessons)(PlayerScripts.Client).
return function(client)
	local Lessons=require(client.TeachLessons)
	local Pointer=require(client.TeachPointer)
	local Coach=require(game:GetService("ReplicatedStorage").Shared.CoachMarks)
	local Teach=require(game:GetService("ReplicatedStorage").Shared.TeachMarks)
	local function latched(...)local m=0;for _,id in ipairs({...})do m=Teach.with(m,id)end;return m end
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function snapshot(over)
		local s={totalWins=0,coachMask=0,stats={rounds=0},toyUnlocks={},petHues={},gifts={owed=true,granted={paint=true}},dash={ribbons={}}}
		for k,v in pairs(over or {})do s[k]=v end
		return s
	end
	local painted={pip={main={rose=1}}}
	local function facts(over,live)return Lessons.facts(snapshot(over),live or {teach=true})end

	test("pure: each lesson's saved fact (painted, a field round, menuSeen, a fetch, a ribbon), never a timer",function()
		local f=facts()
		for _,id in ipairs(Lessons.Order)do assert(not Lessons.done(id,f),id)end
		assert(Lessons.done("dress",facts({petHues=painted})),"a pot used: any pet holds paint")
		assert(not Lessons.done("dress",facts({petHues={pip={main={rose=0}}}})),"cleared (hueClear): shows again")
		assert(Lessons.done("deck",facts({stats={rounds=1}}))and not Lessons.done("deck",facts({stats={rounds=0}})),"one field round; the Welcome round is not counted")
		assert(Lessons.done("menu",facts({coachMask=Coach.bit("menuSeen")})))
		assert(Lessons.done("menu",Lessons.facts(snapshot(),{teach=true,mask=Coach.bit("menuSeen")})),"this session's bit counts at once")
		assert(Lessons.done("park",facts({stats={rounds=0,fetches=1}})))
		assert(Lessons.done("dash",facts({dash={ribbons={fun=1}}}))and not Lessons.done("dash",facts({dash={ribbons={}}})))
	end)

	test("pure: the order and triggers; Later skips to the deck; What's next? asks for the Menu; off, veterans, unowed: nothing",function()
		local s={skipped={},asked={},parked={}}
		assert(Lessons.next(facts(),s)=="dress","the Paint card seen, nothing painted: Dress up")
		assert(Lessons.next(facts({gifts={owed=true,granted={paint=true},unseen={kind="paint"}}}),s)==nil,"the card not closed yet")
		assert(Lessons.next(facts({gifts={owed=true,granted={}}}),s)==nil,"no Paint gift yet: nothing")
		s.skipped.dress=true
		local c=Lessons.candidates(facts(),s)
		assert(c[1]=="dress"and c[2]=="deck","Later: the deck may come (Dress up stays lit on the pet screen)")
		assert(Lessons.next(facts({petHues=painted}),{})=="reset","painted: the colour reset (on the pet screen)")
		assert(Lessons.candidates(facts({petHues=painted}),{})[2]=="deck","and the deck (in the garden: the first one on screen lights)")
		local reset=latched("reset")
		assert(Lessons.next(facts({petHues=painted,teachMask=reset}),{})=="deck","painted: the deck")
		assert(Lessons.next(facts({petHues=painted,teachMask=reset,stats={rounds=1}}),{})=="menu","a field round: the Menu")
		assert(Lessons.candidates(facts({petHues=painted,teachMask=reset}),{asked={menu=true}})[2]=="menu","What's next? asks for it at once")
		local toy={petHues=painted,teachMask=latched("reset","quests"),stats={rounds=2},coachMask=Coach.bit("menuSeen"),gifts={owed=true,granted={paint=true,toy=true}}}
		assert(Lessons.next(facts(toy),{})=="park","the Toy gift given, no fetch: the park")
		assert(Lessons.next(Lessons.facts(snapshot(toy),{teach=true,park=false}),{})==nil,"no Pet Park in this world: none")
		local fetched={petHues=painted,teachMask=latched("reset","quests"),stats={rounds=2,fetches=1},coachMask=Coach.bit("menuSeen"),dash={ribbons={}},gifts={owed=true,granted={paint=true,toy=true}}}
		assert(Lessons.next(facts(fetched),{})=="dash","fetch learned, no ribbon: the Dash")
		fetched.dash={ribbons={fun=1}};assert(Lessons.next(facts(fetched),{})=="stats","raced, nothing in the pouch: Stats unlocks off the Dash")
		assert(Lessons.next(Lessons.facts(snapshot(),{teach=false}),{})==nil,"teach off: nothing lit")
		assert(Lessons.next(facts({totalWins=50}),{})=="dress","teach more 0.1: a save owed the chain is never a veteran for lessons")
		assert(Lessons.next(facts({teachMask=latched("done")}),{})==nil,"graduated: no pointers")
		assert(Lessons.next(facts({gifts={owed=false,granted={paint=true}}}),{})==nil,"a save never owed the chain: nothing")
		assert(Lessons.next(facts({gifts=false}),{})==nil,"gifts off: nothing")
	end)

	test("teach more, pure: every lesson a latch (Back to white keeps Dress up done); a feature off is done; the new triggers",function()
		local cleared={pip={main={rose=0}}}
		assert(Lessons.done("dress",facts({petHues=cleared,teachMask=latched("dress")})),"the latch outlives the fact (reset to white)")
		assert(Lessons.done("dash",facts({dash=false})),"no Garden Dash here: done")
		assert(Lessons.done("park",Lessons.facts(snapshot(),{teach=true,park=false})),"no Pet Park here: done")
		assert(Lessons.done("deckTour",facts({stats={rounds=1}}))and Lessons.done("level",facts({stats={rounds=2}}))and not Lessons.done("level",facts({stats={rounds=1}})))
		assert(Lessons.done("snacks",Lessons.facts(snapshot(),{teach=true,teachMask=latched("snacks")})),"this session's latch counts at once")
		local f=facts({petHues=painted})
		assert(Lessons.ready("reset",f)and not Lessons.ready("reset",Lessons.facts(snapshot({petHues=painted}),{teach=true,wipe=true})),"after the wipe, not during it")
		assert(not Lessons.ready("quests",facts({stats={rounds=1}}))and Lessons.ready("quests",facts({stats={rounds=1},teachMask=latched("level")})),"quests after the level step")
		assert(not Lessons.ready("quests",facts({teachMask=latched("level")})),"never in the first round")
		assert(Lessons.ready("snacks",facts({statEgg={pouch={{id=1}}}}))and not Lessons.ready("snacks",facts()),"a snack in the pouch")
		assert(Lessons.ready("stats",facts({teachMask=latched("snacks")}))and not Lessons.ready("stats",facts()),"after the snack")
		assert(Lessons.ready("stats",facts({dash={ribbons={fun=1}}})),"or off the Dash with an empty pouch: nothing dead-ends")
		local w=facts({teachMask=latched("stats")})
		assert(Lessons.ready("wardrobe",w,{})and not Lessons.ready("wardrobe",Lessons.facts(snapshot({teachMask=latched("stats")}),{teach=true,visit=3}),{statsVisit=3}),"the next pet screen visit")
		local all=latched(table.unpack(Teach.Course))
		assert(Lessons.finished(facts({teachMask=all})),"every course lesson latched: finished")
		assert(not Lessons.finished(facts({teachMask=all-Teach.bit("wardrobe")})),"one left: not yet")
		assert(Lessons.finished(Lessons.facts(snapshot({teachMask=all-Teach.bit("park")-Teach.bit("dash"),dash=false}),{teach=true,park=false})),"Dash and Park off here: done without them")
	end)

	-- the controller with fake targets
	local function rig(state)
		local r={state=state,now=0,shown={},hidden=0,events={},targets={},sent={}}
		r.pointer={show=function(_,target,words)r.at=target;r.words=words;return true end,hide=function()r.at=nil;r.hidden+=1 end,step=function()end}
		r.lessons=Lessons.new({state=function()return r.state end,mask=function()return r.mask end,teach=function()return r.teach~=false end,
			park=function()return true end,clock=function()return r.now end,pointer=r.pointer,text=function(k)return k end,
			event=function(n,id)table.insert(r.events,n..":"..tostring(id))end,send=function(v)table.insert(r.sent,v)end,
			target=function(id)local t=r.targets[id];if t then return t.node,t.words end;return nil end})
		function r.run(seconds)
			local t=0
			while t<seconds-1e-9 do r.now+=.25;t+=.25;r.lessons:step(r.now,.25)end
		end
		return r
	end

	test("controller: the first lesson whose button is up; done by the fact whoever caused it; ignored 12 s: parked",function()
		local r=rig(snapshot())
		r.run(1);assert(r.at==nil,"the pet screen is not open: nothing lit")
		r.targets.dress={node="DressUp",words="dress"}
		r.run(.5);assert(r.at=="DressUp"and r.words=="teach.dress"and r.events[1]=="TeachShown:dress")
		r.targets.dress={node="PaintKey",words="paint"}
		r.run(.5);assert(r.at=="PaintKey"and r.words=="teach.paint","the second tap: Tap Paint!")
		r.state=snapshot({petHues=painted})
		r.run(.5);assert(r.at==nil and r.events[2]=="TeachDone:dress","the pot used: done")
		r.targets.deck={node="Deck",words="deck"}
		r.run(.5);assert(r.at=="Deck"and r.words=="teach.deck")
		r.run(Lessons.Ignore+.5);assert(r.at==nil and r.lessons.session.parked.deck,"untouched 12 s: it fades for this session")
		r.run(60);assert(r.at==nil,"not again this session")
		-- the fact closes it anyway: a field round played (no pointer needed; the Welcome round is not counted)
		r.state=snapshot({petHues=painted,stats={rounds=1}})
		r.targets.menu={node="Menu",words="menu"}
		r.run(.5);assert(r.at=="Menu"and r.words=="teach.menu")
		r.targets.menu={node="ThingsTile",words="things"};r.run(.5);assert(r.at=="ThingsTile"and r.words=="teach.things","in the hub: All the games!")
		r.mask=Coach.bit("menuSeen");r.run(.5);assert(r.at==nil,"the page opened: menuSeen")
	end)

	test("controller: Later and a rejoin let the deck come first; What's next? lights the Menu; off mid-lesson hides it",function()
		local r=rig(snapshot())
		r.targets.deck={node="Deck",words="deck"}
		r.run(.5);assert(r.at=="Deck","a rejoin (the card seen last session): the deck may come first")
		local l=rig(snapshot({gifts={owed=true,granted={paint=true},unseen={kind="paint"}}}))
		l.targets.deck={node="Deck",words="deck"};l.run(.5);assert(l.at==nil,"the card is up this session")
		l.state=snapshot();l.run(.5);assert(l.at==nil,"its card closed this session: Dress up first")
		l.lessons:skip("dress");l.run(.5);assert(l.at=="Deck","Later: the deck")
		local m=rig(snapshot({petHues=painted}))
		assert(m.lessons:ask("menu"))
		m.targets.menu={node="Menu",words="menu"};m.run(.5);assert(m.at=="Menu","What's next?: the Menu button")
		m.teach=false;m.run(.5);assert(m.at==nil,"teach off: nothing lit")
		assert(not m.lessons:ask("menu"),"off: the card opens Things itself")
		local v=rig(snapshot({totalWins=50,teachMask=latched("done")}));v.targets.dress={node="DressUp",words="dress"};v.run(1);assert(v.at==nil,"graduated")
	end)

	test("teach more, controller: ignored sends park:<id> once; the reset is show-only; finished asks done; Skip the tips",function()
		local r=rig(snapshot({petHues=painted,teachMask=latched("reset")}))
		r.targets.deck={node="Deck",words="deck"}
		r.run(Lessons.Ignore+1);assert(r.lessons.session.parked.deck and table.find(r.sent,"park:deck"),"ignored: the server counts the session")
		local n=#r.sent;r.run(30);assert(#r.sent==n,"once a session")
		local z=rig(snapshot({petHues=painted}))
		z.targets.reset={node="White",words="reset"}
		z.run(Lessons.ResetSeen+.5);assert(table.find(z.sent,"reset"),"the ringed card was on screen: saved")
		z.run(1);assert(z.at==nil,"latched at once this session (no wait for the save)")
		local q=rig(snapshot({petHues=painted}));q.targets.reset={node="More",words="more"}
		q.run(Lessons.Ignore+.5);assert(q.lessons.session.parked.reset,"the Dress up ring parks like any other")
		local all=latched(table.unpack(Teach.Course))
		local g=rig(snapshot({teachMask=all}));g.run(.5);assert(table.find(g.sent,"done:finished"),"finished: asked once")
		local k=rig(snapshot());k.targets.dress={node="DressUp",words="dress"};k.run(.5);assert(k.at=="DressUp")
		assert(k.lessons:skipAll()and table.find(k.sent,"done:skipped"));k.run(.5);assert(k.at==nil,"skipped: nothing lit, this session too")
		k.teach=false;assert(not k.lessons:skipAll(),"off: nothing to skip")
	end)

	test("the pointer: pulse 1.0 to 1.12 every 1.2 s, a 6 px dip, still under Reduced Motion; words with keys; the label's spot",function()
		assert(math.abs(Pointer.pulse(0)-1)<1e-9 and math.abs(Pointer.pulse(.6)-1.12)<1e-9 and math.abs(Pointer.pulse(1.2)-1)<1e-9)
		assert(Pointer.pulse(.6,true)==1 and Pointer.dip(.6,true)==0 and math.abs(Pointer.dip(.6)-6)<1e-9)
		assert(Pointer.words("Open the Menu!","Keyboard","M","Y")=="Open the Menu!  [M]")
		assert(Pointer.words("Open the Menu!","Gamepad","M","Y")=="Open the Menu!  (Y)")
		assert(Pointer.words("Open the Menu!","Touch","M","Y")=="Open the Menu!","touch: the words only")
		local x,y,side=Pointer.labelSpot({x=100,y=300,w=60,h=44},{w=800,h=600},120)
		assert(side=="above"and y<300 and x==70)
		local _,y2,side2=Pointer.labelSpot({x=100,y=10,w=60,h=44},{w=800,h=600},120)
		assert(side2=="below"and y2>=54,"no room on top: under it")
		local x3=Pointer.labelSpot({x=780,y=300,w=40,h=44},{w=800,h=600},120)
		assert(x3<=800-120-4,"kept on the screen")
		assert(Lessons.Keys.menu.key=="M"and Lessons.Keys.menu.glyph=="Y"and Lessons.Keys.throw.key=="F"and Lessons.Keys.throw.glyph=="R2"and Lessons.Keys.dress.glyph=="R1")
	end)

	return {passed=#cases,cases=cases}
end
