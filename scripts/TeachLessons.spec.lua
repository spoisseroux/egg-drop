-- Onboarding part 2 (TeachLessons, TeachPointer; ONBOARDING-P2-BRIEF section 2, ARCH-REVIEW-P2 sections 1 and 4; Onboard
-- "teach"): each lesson is done only by its saved fact, whoever caused it; never by a timer; one pointer at a time, the
-- first lesson whose button is on screen; "Later" skips Dress up to the deck; "What's next?" asks for the Menu; ignored
-- 12 s: it fades and waits for the next session; a rejoin lets the deck come first; veterans and unowed saves: nothing.
-- The pointer's ring shape, tip, beat, glide, label words and spot. Fake deps and a fake clock only.
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

	test("the pointer (beta 42 notes 1 and 4): a true circle or a concentric ring, the tip and side, the beat, the glide; words with keys; the label's spot",function()
		local function near(a,b)return math.abs(a-b)<1e-6 end
		-- the ring: round or square-ish targets a circle (max + 12); wide tiles 6 px out, corner = theirs + 6 (none: 14)
		local c=Pointer.shape(56,48)
		assert(c.circle and c.w==68 and c.h==68,"the Menu button: a circle")
		assert(Pointer.shape(70,52).circle and not Pointer.shape(70,51).circle,"w/h 1.35 is the line")
		local r=Pointer.shape(600,100,12)
		assert(not r.circle and r.w==612 and r.h==112 and r.corner==18,"a wide tile: concentric")
		assert(Pointer.shape(600,100).corner==14,"no UICorner: 14")
		assert(Pointer.shape(600,100,12,12).w==624 and Pointer.shape(600,100,12,12).corner==24,"the breath grows the pad, never a scale")
		assert(near(Pointer.cornerPx(.5,0,600,100,1),50)and near(Pointer.cornerPx(0,12,600,100,.5),6),"scale radii resolve against min(w, h)")
		assert(Pointer.pad(0)==6 and near(Pointer.pad(.6),12)and near(Pointer.pad(1.2),6)and Pointer.pad(.6,true)==6)
		-- the tip: round centre + .2s, wide (x + .68w, y + .6h), from below-right; near the bottom from above-left, mirrored
		local x,y,rot,side=Pointer.tip({x=100,y=100,w=60,h=60},{w=800,h=600})
		assert(near(x,142)and near(y,142)and rot==150 and side=="belowRight")
		x,y,rot=Pointer.tip({x=100,y=200,w=600,h=100},{w=1280,h=720})
		assert(near(x,508)and near(y,260)and rot==150,"a tile: clear of its title and the FREE badge")
		x,y,rot,side=Pointer.tip({x=700,y=530,w=60,h=60},{w=800,h=600})
		assert(near(x,718)and near(y,548)and rot==-30 and side=="aboveLeft","the Menu button at the bottom: from above-left")
		local ax,ay=Pointer.axis(150);assert(ax>0 and ay>0,"below-right: the hand lies down-right of the tip")
		ax,ay=Pointer.axis(-30);assert(ax<0 and ay<0)
		-- the beat: hover 10 back with a bob, dip to touch, press x .92 with the flash, lift past 10 (3 px), rest; the ripple at .70
		local b=Pointer.beat(0);assert(near(b.back,10)and b.scale==1 and not b.flash and b.ripple==nil)
		assert(Pointer.beat(.1375).back>10 and Pointer.beat(.4125).back<10,"the bob")
		b=Pointer.beat(.70);assert(b.back==0 and b.scale==.92 and b.flash and b.ripple==0,"the press and the tap ripple")
		assert(not Pointer.beat(.79).flash and Pointer.beat(.79).scale==.92)
		local peak=0;for i=0,40 do peak=math.max(peak,Pointer.beat(.8+.2*i/40).back)end
		assert(peak>12.5 and peak<13.5,"the lift overshoots about 3 px")
		assert(near(Pointer.beat(1.1).back,10)and near(Pointer.beat(1.2+.70).ripple,0),"rest, then the next beat")
		b=Pointer.beat(.70,true);assert(b.back==10 and b.scale==1 and b.ripple==nil,"Reduced Motion: no press, no ripple")
		local d,alpha=Pointer.ripple(0);assert(d==28 and near(alpha,.1));d,alpha=Pointer.ripple(1);assert(d==76 and alpha==1)
		-- the glide: .38 s on an arc lifted toward screen-up, x1.08 mid-flight; the rings swap (.12 out, pop at .26)
		local gx,gy,gs,_,done=Pointer.glide(0,100,500,700,300)
		assert(gx==100 and gy==500 and gs==1 and not done)
		gx,gy,gs,_,done=Pointer.glide(.38,100,500,700,300)
		assert(near(gx,700)and near(gy,300)and near(gs,1)and done)
		local mx,my,ms,me=Pointer.glide(.1,100,500,700,300)
		assert(my<500+(300-500)*me-1 and ms>1 and mx>100,"lifted, and larger mid-flight")
		local old,new,pad=Pointer.ringSwap(0);assert(old==1 and new==0)
		old,new=Pointer.ringSwap(.2);assert(old==0 and new==0,"one ring at a time")
		old,new,pad=Pointer.ringSwap(.26);assert(new==0 and pad==20);old,new,pad=Pointer.ringSwap(.44);assert(new==1 and pad==6)
		assert(Pointer.words("Open the Menu!","Keyboard","M","Y")=="Open the Menu!  [M]")
		assert(Pointer.words("Open the Menu!","Gamepad","M","Y")=="Open the Menu!  (Y)")
		assert(Pointer.words("Open the Menu!","Touch","M","Y")=="Open the Menu!","touch: the words only")
		local x,y,side=Pointer.labelSpot({x=100,y=300,w=60,h=44},{w=800,h=600},120)
		assert(side=="above"and y<300 and x==70)
		local _,y2,side2=Pointer.labelSpot({x=100,y=10,w=60,h=44},{w=800,h=600},120)
		assert(side2=="below"and y2>=54,"no room on top: under it")
		local x3=Pointer.labelSpot({x=780,y=300,w=40,h=44},{w=800,h=600},120)
		assert(x3<=800-120-4,"kept on the screen")
		local _,y4=Pointer.labelSpot({x=100,y=300,w=60,h=44},{w=800,h=600},120,nil,48)
		assert(y4==y-48,"the hand from above: the label 48 px higher")
		assert(Lessons.Keys.menu.key=="M"and Lessons.Keys.menu.glyph=="Y"and Lessons.Keys.throw.key=="F"and Lessons.Keys.throw.glyph=="R2"and Lessons.Keys.dress.glyph=="R1")
	end)

	test("the pointer (code review, beta 43): hide() takes the drawing fading out of another ScreenGui with it (never frozen half-visible)",function()
		local gone=0
		local root={Parent=true,Visible=true,Destroy=function()gone+=1 end}
		local p=Pointer.new({})
		p.v={root={Visible=true}}
		p.leaving={v={root=root},at=0}
		p:hide()
		assert(p.leaving==nil and gone==1,"the fading drawing goes with the hide")
		assert(p.v.root.Visible==false and p.target==nil)
		p:hide();assert(gone==1,"twice: nothing more")
	end)

	return {passed=#cases,cases=cases}
end
