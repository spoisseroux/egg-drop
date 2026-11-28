-- The deck tour (DeckTour; beta 44: artifacts/qa-2026-11-28-beta44/ONBOARD-SIMPLIFY-BRIEF.md section 2, ARCH-REVIEW-SIMPLIFY
-- 2 to 4; Onboard "teach"): only once the deck is ready (a boot finished or skipped since it opened, its screen gone, then
-- 0.4 s; never before a boot starts), six steps on the deck's own cards (a card this layout lacks is left out and the
-- count is the real number), every drop and item held while it runs, Next by a tap anywhere, Enter, Space, A or R1,
-- Skip by the pill, B or L1, never the aim, menu or leave keys; untouched it stays; past step 6 it latches deckTour,
-- level and quests and closes the deck by itself, asking again while the garden switch is busy; Skip leaves the deck
-- open and the hold lets go; leaving early saves nothing. Fake deps and a fake clock only.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(PlayerScripts.Client.ZZSpecs.DeckTour)(PlayerScripts.Client).
return function(client)
	local Tour=require(client.DeckTour)
	local Teach=require(game:GetService("ReplicatedStorage").Shared.TeachMarks)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function facts(over)
		local f={on=true,graduated=false,latched={},rounds=0}
		for k,v in pairs(over or {})do f[k]=v end
		return f
	end
	local opener={mode="Board",phase="Playing",guided=false,drops=0,over=false,overlay=false,ready=true}
	local function with(base,over)local t=table.clone(base);for k,v in pairs(over or {})do t[k]=v end;return t end

	test("pure: wants the untouched field opener of a save still owed the tour, only when the deck is ready",function()
		assert(Tour.wants(facts(),opener))
		assert(not Tour.wants(facts(),with(opener,{ready=false})),"the deck still booting: nothing drawn")
		assert(Tour.wants(facts(),with(opener,{guided=true})),"the guided first round gets the tour")
		assert(not Tour.wants(facts({latched={deckTour=true}}),opener),"once")
		assert(not Tour.wants(facts({rounds=1}),opener),"a field round played: the deck is learned")
		for _,bad in ipairs({{phase="Welcome"},{drops=1},{over=true},{overlay=true},{mode="Room"},{phase=false}})do
			local ctx=with(opener,bad);if ctx.phase==false then ctx.phase=nil end
			assert(not Tour.wants(facts(),ctx),"not this opener")
		end
		assert(not Tour.wants(facts({graduated=true}),opener)and not Tour.wants(facts({on=false}),opener),"graduated, unowed or off: nothing")
	end)

	test("pure (ARCH-REVIEW-SIMPLIFY 3): the ready gate needs a boot ended since this deck opened; no boot at all: NoBoot s",function()
		local g={openedAt=10,mark=3,finishes=3,playing=false,showing=false}
		assert(not Tour.bootDone(g,10.5),"before the boot starts, playing is false too: not ready")
		g.playing=true;assert(not Tour.bootDone(g,11))
		g.playing=false;g.finishes=4;g.showing=true;assert(not Tour.bootDone(g,12),"its fade still up")
		g.showing=false;assert(Tour.bootDone(g,12),"ended (played out or skipped) and gone")
		local none={openedAt=10,mark=3,finishes=3}
		assert(not Tour.bootDone(none,10+Tour.NoBoot-.1)and Tour.bootDone(none,10+Tour.NoBoot),"never stuck waiting")
		assert(not Tour.bootDone(nil,99))
	end)

	test("pure: six steps, the cards a layout has, the real count; Next walks, Skip ends; the label",function()
		assert(#Tour.Steps==6)
		local ids={};for _,s in ipairs(Tour.Steps)do table.insert(ids,s.id)end
		assert(table.concat(ids,",")=="goals,balls,pays,score,chain,quests")
		assert(Tour.Steps[3].cards[1]=="WinPays"and Tour.Steps[3].also=="Difficulty"and Tour.Steps[3].sub=="Difficulty")
		assert(Tour.Steps[4].words=="teach.tourScore","note 9: what score does")
		assert(Tour.Steps[6].cards[1]=="QuestHandle"and Tour.Steps[6].cards[2]=="DailyQuests","note 8: the quests")
		local all=Tour.plan(function()return true end);assert(#all==6)
		local noChain=Tour.plan(function(name)return name~="Chain"and name~="QuestHandle"end)
		assert(#noChain==5 and noChain[5]==6,"no Chain card (it sits in the Goals header): left out; Daily quests stands in")
		assert(Tour.after(1,6,"next")==2 and Tour.after(6,6,"next")==nil and Tour.after(2,6,"skip")==nil)
		assert(Tour.label("Do these to win!","1/6")=="Do these to win!  1/6")
		assert(Tour.subOn(Tour.Steps[3],false)and not Tour.subOn(Tour.Steps[3],true)and not Tour.subOn(Tour.Steps[1],false),"Harder pays more: unguided only")
		for _,id in ipairs(Tour.Saves)do assert(Teach.validId(id),id)end
		assert(table.find(Tour.Saves,"deckTour")and table.find(Tour.Saves,"level")and table.find(Tour.Saves,"quests"))
	end)

	test("keys (ARCH-REVIEW-SIMPLIFY 2): Enter, Space, A, R1 go on; B and L1 skip; never the aim, the menu or leaving",function()
		assert(Tour.keysSafe())
		for _,name in ipairs({"Return","KeypadEnter","Space","ButtonA","ButtonR1"})do assert(Tour.keyAction(name)=="next",name)end
		for _,name in ipairs({"ButtonB","ButtonL1"})do assert(Tour.keyAction(name)=="skip",name)end
		for _,name in ipairs({"Left","Right","A","D","M","Escape","Backspace","ButtonY","ButtonX"})do
			assert(Tour.keyAction(name)==nil and table.find(Tour.Forbidden,name),name)
		end
	end)

	-- the controller with fake cards, a fake boot and a fake clock
	local function card(name)
		return {Name=name,Visible=true,Parent=nil,IsA=function(_,class)return class=="GuiObject"end}
	end
	local function rig(f,names)
		local r={f=f,ctx=table.clone(opener),saved={},events={},now=0,closes=0,closeOk=true}
		r.ctx.ready=nil
		local cards={}
		for _,name in ipairs(names or {"Goals","EggsLeft","WinPays","Difficulty","Score","Chain","QuestHandle","Next"})do cards[name]=card(name)end
		r.cards=cards
		r.deck={hudRoot={FindFirstChild=function(_,name)return cards[name]end},dimmed=nil,visible=true,tourHold=false,
			boot={playing=false,finishes=0},bootHost={Visible=false}}
		function r.deck:teachDim(lit)self.dimmed=lit end
		r.pointer={show=function(_,target,words)r.at=target;r.words=words;return true end,hide=function()r.at=nil end,step=function()end}
		r.tour=Tour.new({facts=function()return r.f end,ctx=function()return table.clone(r.ctx)end,deck=function()return r.deck end,
			latch=function(id)table.insert(r.saved,id);r.f.latched[id]=true end,text=function(k,v)return if v then k..":"..v.n.."/"..v.of else k end,
			pointer=r.pointer,hold=function(on)r.deck.tourHold=on end,
			close=function()r.closes+=1;if r.closeOk then r.ctx.mode="Room"end;return r.closeOk end,
			event=function(n)table.insert(r.events,n)end,playerGui=function()return nil end,listen=false})
		function r.run(seconds)local t=0;while t<seconds-1e-9 do r.now+=.25;t+=.25;r.tour:step(r.now,.25)end end
		-- the deck opens: its boot plays, then ends
		function r.boot()
			r.deck.boot.playing=true;r.deck.bootHost.Visible=true;r.run(.5)
			r.deck.boot.playing=false;r.deck.boot.finishes+=1;r.deck.bootHost.Visible=false
		end
		return r
	end

	test("controller (note 6): nothing drawn until the boot ends and 0.4 s pass; then step 1 with drops held",function()
		local r=rig(facts())
		r.run(.25);assert(r.at==nil and not r.deck.tourHold,"opened, the boot not started yet: nothing")
		r.boot();assert(r.at==nil,"booting: nothing")
		r.run(.5);assert(r.at==nil,"under 0.4 s after the boot: not yet")
		r.run(.25);assert(r.at==r.cards.Goals and r.words=="teach.tour1  teach.count:1/6","step 1 on Goals, 1/6")
		assert(r.deck.tourHold==true,"every drop and item held")
		assert(r.deck.dimmed and r.deck.dimmed.Goals and not r.deck.dimmed.Next,"the others dimmed")
		r.run(120);assert(r.at==r.cards.Goals and #r.saved==0,"untouched: it just stays, nothing saved")
	end)

	test("controller (notes 8 to 10): six Nexts, then the latches, the deck closes itself (asked again while busy), the hold lets go",function()
		local r=rig(facts())
		r.boot();r.run(.75)
		local seen={}
		for i=1,6 do
			table.insert(seen,r.at.Name)
			if i==3 then assert(r.deck.dimmed.WinPays and r.deck.dimmed.Difficulty,"Win pays with Difficulty lit")end
			r.tour:act("next");r.run(.25)
		end
		assert(table.concat(seen,",")=="Goals,EggsLeft,WinPays,Score,Chain,QuestHandle")
		assert(table.find(r.saved,"deckTour")and table.find(r.saved,"level")and table.find(r.saved,"quests"),"latched")
		assert(r.at==nil and r.deck.dimmed==nil and r.deck.tourHold==true,"the pointer goes; drops still held until the deck has closed")
		r.closeOk=false;r.run(Tour.CloseAfter+.25)
		assert(r.closes>=1 and r.ctx.mode=="Board","the garden switch busy: Back refused")
		local asked=r.closes;r.run(1);assert(r.closes>asked,"asked again")
		r.closeOk=true;r.run(.5)
		assert(r.ctx.mode=="Room"and not r.deck.tourHold and table.find(r.events,"TourClosed"),"closed; the hold let go")
		assert(r.tour:busy()==false)
		r.ctx.mode="Board";r.boot();r.run(1);assert(r.at==nil,"once")
	end)

	test("controller: Skip ends it with the deck open; the hold lets go once the tap is over; leaving early saves nothing",function()
		local s=rig(facts())
		s.boot();s.run(.75);s.tour:act("next");s.tour:act("skip")
		assert(s.at==nil and table.find(s.saved,"deckTour")and table.find(s.events,"TourSkipped"),"Skip: saved, over")
		assert(s.deck.tourHold==true,"the skip tap's own release never drops");s.run(Tour.SkipGrace+.25)
		assert(s.deck.tourHold==false and s.closes==0 and s.ctx.mode=="Board","the round is theirs: deck open, drops back")
		local l=rig(facts())
		l.boot();l.run(.75);l.tour:act("next");l.ctx.mode="Room";l.run(.25)
		assert(l.at==nil and #l.saved==0 and not l.deck.tourHold,"left before the end: nothing saved, nothing held")
		l.ctx.mode="Board";l.run(.5);assert(l.at==nil,"back on the deck: the ready gate again")
		l.boot();l.run(.75);assert(l.at==l.cards.Goals,"from step 1 once ready")
		local m=rig(facts());m.boot();m.run(.75)
		m.ctx.overlay=true;m.run(.5);assert(m.at==nil and m.tour.active~=nil and m.deck.tourHold,"a menu over it: it waits under it")
		m.ctx.overlay=false;m.run(.25);assert(m.at==m.cards.Goals)
		local g=rig(facts({graduated=true}));g.boot();g.run(1);assert(g.at==nil and #g.saved==0 and not g.deck.tourHold,"graduated: nothing")
	end)

	test("controller: a layout without Chain and the clipboard: five steps on what is there, 1/5",function()
		local r=rig(facts(),{"Goals","EggsLeft","WinPays","Difficulty","Score","DailyQuests"})
		r.boot();r.run(.75);assert(r.words=="teach.tour1  teach.count:1/5")
		for _=1,4 do r.tour:act("next")end;r.run(.25);assert(r.at==r.cards.DailyQuests,"Daily quests stands in for the clipboard")
	end)

	test("controller: a step whose card is missing for a moment waits, then moves on (never stuck invisible); no keys meanwhile",function()
		local r=rig(facts())
		r.boot();r.run(.75);assert(r.tour.keysOn==true)
		r.cards.EggsLeft.Visible=false
		r.tour:act("next");r.run(.5);assert(r.at==nil and r.tour.active.at==2 and r.tour.keysOn==false,"the HUD rebuilding: it waits")
		r.run(Tour.MissingGrace+.25);assert(r.at==r.cards.WinPays,"gone for good: on to step 3")
	end)

	test("the Skip pill (code review, beta 43): an Active button, so its tap is consumed; the Harder pays more line lets taps through",function()
		assert(Tour.Pills.skipPill.class=="TextButton"and Tour.Pills.skipPill.active==true)
		assert(Tour.Pills.subPill.class=="TextLabel"and Tour.Pills.subPill.active==false)
	end)

	return {passed=#cases,cases=cases}
end
