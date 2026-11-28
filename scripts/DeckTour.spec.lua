-- The first full Pocket Deck round (DeckTour; artifacts/qa-2026-11-27-beta42/TEACH-MORE-BRIEF.md section 1, ARCH-REVIEW-TEACH
-- 6 to 8; Onboard "teach"): the tour only on the first field round's untouched opener, three steps on the deck's own
-- cards (the others dimmed), Next / Skip / the first drop, what each end saves, the round-two opener's level step alone,
-- never the round's own keys, never a timeout; the three tips one at a time, 8 s apart, never with another pill, never
-- after the round. Fake deps and a fake clock only.
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
	local opener={mode="Board",phase="Playing",guided=false,drops=0,over=false,overlay=false}
	local function with(base,over)local t=table.clone(base);for k,v in pairs(over or {})do t[k]=v end;return t end

	test("pure: the tour only on the first field round's untouched opener; the round-two opener's level step; never graduated",function()
		assert(Tour.mode(facts(),opener)=="tour")
		assert(Tour.mode(facts({rounds=1}),opener)=="level","round two: step 3 alone")
		assert(Tour.mode(facts({rounds=1,latched={level=true}}),opener)==nil and Tour.mode(facts({rounds=2}),opener)==nil)
		assert(Tour.mode(facts({latched={deckTour=true}}),opener)==nil,"once")
		for _,bad in ipairs({{phase="Welcome"},{guided=true},{drops=1},{over=true},{overlay=true},{mode="Room"}})do
			assert(Tour.mode(facts(),with(opener,bad))==nil,"not this opener")
		end
		local noField=table.clone(opener);noField.phase=nil
		assert(Tour.mode(facts(),noField)==nil,"not a field round")
		assert(Tour.mode(facts({graduated=true}),opener)==nil and Tour.mode(facts({on=false}),opener)==nil,"graduated, unowed or off: nothing")
		assert(Tour.first("tour")==1 and Tour.first("level")==3)
	end)

	test("pure: Next walks 1, 2, 3 then ends; Skip and a drop end it; what each end saves; the label's count",function()
		assert(Tour.after("tour",1,"next")==2 and Tour.after("tour",2,"next")==3 and Tour.after("tour",3,"next")==nil)
		assert(Tour.after("tour",1,"skip")==nil and Tour.after("tour",2,"drop")==nil and Tour.after("level",3,"next")==nil)
		local function has(list,id)return table.find(list,id)~=nil end
		assert(has(Tour.saves("tour",false),"deckTour")and not has(Tour.saves("tour",false),"level"),"untried: the level step comes back in round two")
		assert(has(Tour.saves("tour",true),"level"),"stepped on step 3: level learned")
		assert(has(Tour.saves("level",false),"level")and not has(Tour.saves("level",false),"deckTour"),"round two saves level whatever they do")
		assert(Tour.label("Tick these to win!","tour",1,"1/3")=="Tick these to win!  1/3")
		assert(Tour.label("Tap to change level!","level",3,"3/3")=="Tap to change level!","the opener's step alone: no count")
		assert(Tour.Steps[1].card=="Goals"and Tour.Steps[2].card=="EggsLeft"and Tour.Steps[3].card=="Difficulty"and Tour.Steps[3].sub=="WinPays")
		for _,id in ipairs(Tour.saves("tour",true))do assert(Teach.validId(id),id)end
	end)

	test("keys: never A, Space, B, Backspace or the d-pad (the round's own); Enter and R1 go on, L1 skips",function()
		assert(Tour.keysSafe())
		for _,name in ipairs({"A","Space","B","Backspace","ButtonA","ButtonB","ButtonX"})do assert(table.find(Tour.Forbidden,name),name)end
		assert(table.find(Tour.KeyNames.next,"Return")and table.find(Tour.KeyNames.next,"ButtonR1")and table.find(Tour.KeyNames.skip,"ButtonL1"))
	end)

	test("pure: the tips, one at a time, 8 s apart, never with another pill, never after the round, each once",function()
		local round={mode="Board",phase="Playing",over=false,drops=1,chain=0,goalsDone=0,now=10,railEmpty=true}
		assert(Tour.tip(facts(),round)=="tipNext","the first drop landed")
		assert(Tour.tip(facts(),with(round,{drops=0}))==nil)
		assert(Tour.tip(facts({latched={tipNext=true}}),with(round,{chain=2}))=="tipChain")
		assert(Tour.tip(facts({latched={tipNext=true}}),with(round,{chain=2,lastTip=5}))==nil,"8 s apart")
		assert(Tour.tip(facts({latched={tipNext=true}}),with(round,{chain=2,lastTip=2}))=="tipChain")
		assert(Tour.tip(facts({latched={tipNext=true,tipChain=true}}),with(round,{goalsDone=1}))=="tipGoal")
		assert(Tour.tip(facts(),with(round,{railEmpty=false}))==nil,"never with the fill line's pill")
		assert(Tour.tip(facts(),with(round,{over=true}))==nil,"none after the round ends")
		assert(Tour.tip(facts(),with(round,{phase="Welcome"}))==nil and Tour.tip(facts(),with(round,{touring=true}))==nil)
		assert(Tour.tip(facts({graduated=true}),round)==nil,"graduated: no lesson tips")
	end)

	-- the controller with fake cards
	local function card(name)
		return {Name=name,Visible=true,Parent=nil,IsA=function(_,class)return class=="GuiObject"end}
	end
	local function rig(f)
		local r={f=f,ctx=table.clone(opener),saved={},rail={},events={},now=0,picked=0}
		local cards={}
		for _,name in ipairs({"Goals","EggsLeft","Difficulty","WinPays","Next","Chain"})do cards[name]=card(name)end
		r.cards=cards
		r.deck={hudRoot={FindFirstChild=function(_,name)return cards[name]end},dimmed=nil}
		function r.deck:teachDim(lit)self.dimmed=lit end
		r.pointer={show=function(_,target,words)r.at=target;r.words=words;return true end,hide=function()r.at=nil end,step=function()end}
		r.tour=Tour.new({facts=function()return r.f end,ctx=function()return r.ctx end,deck=function()return r.deck end,
			latch=function(id)table.insert(r.saved,id);r.f.latched[id]=true end,text=function(k,v)return if v then k..":"..v.n.."/"..v.of else k end,
			pointer=r.pointer,picked=function()return r.picked end,rail=function(id,text)table.insert(r.rail,id);return true end,
			railEmpty=function()return true end,event=function(n)table.insert(r.events,n)end,playerGui=function()return nil end,listen=false})
		function r.run(seconds)local t=0;while t<seconds-1e-9 do r.now+=.25;t+=.25;r.tour:step(r.now,.25)end end
		return r
	end

	test("controller: three steps on the real cards, the rest dimmed; untouched it stays (no timeout); the level stepped ends it",function()
		local r=rig(facts())
		r.run(.5);assert(r.at==r.cards.Goals and r.words=="teach.tour1  teach.count:1/3","step 1 on Goals with 1/3")
		assert(r.deck.dimmed and r.deck.dimmed.Goals and not r.deck.dimmed.Next,"the others dimmed")
		r.run(120);assert(r.at==r.cards.Goals and #r.saved==0,"untouched: it just stays, nothing saved")
		r.tour:act("next");r.run(.25);assert(r.at==r.cards.EggsLeft)
		r.tour:act("next");r.run(.25);assert(r.at==r.cards.Difficulty and r.deck.dimmed.WinPays,"step 3 lights Win pays with it")
		r.picked=1;r.run(.25)
		assert(table.find(r.saved,"deckTour")and table.find(r.saved,"level"),"tried the level: both saved")
		assert(r.at==nil and r.deck.dimmed==nil,"over: no pointer, no dim")
		r.run(5);assert(r.at==nil,"once")
	end)

	test("controller: the first drop ends it on any step (deckTour only); leaving the deck first saves nothing; round two's opener",function()
		local r=rig(facts())
		r.run(.5);r.ctx.drops=1;r.run(.25)
		assert(r.at==nil and #r.saved>=1 and r.saved[1]=="deckTour"and not table.find(r.saved,"level"),"a drop: they are playing")
		assert(table.find(r.saved,"tipNext"),"and the first tip follows the drop")
		local l=rig(facts())
		l.run(.5);l.ctx.mode="Room";l.run(.25);assert(l.at==nil and #l.saved==0,"left before a drop: nothing saved")
		l.ctx.mode="Board";l.run(.25);assert(l.at==l.cards.Goals,"it comes back on the next opener")
		local s=rig(facts());s.run(.5);s.tour:act("skip");assert(s.at==nil and s.saved[1]=="deckTour","Skip: saved, over")
		local two=rig(facts({rounds=1,latched={deckTour=true}}))
		two.run(.5);assert(two.at==two.cards.Difficulty and two.words=="teach.level","round two: the level step alone, no count")
		two.tour:act("next");assert(two.saved[1]=="level"and two.at==nil,"saved whatever they do")
		local g=rig(facts({graduated=true}));g.run(1);assert(g.at==nil and #g.saved==0 and #g.rail==0,"graduated: nothing")
	end)

	test("controller: a step whose card is missing for a moment waits, then moves on (never stuck invisible)",function()
		local r=rig(facts())
		r.cards.EggsLeft.Visible=false
		r.run(.5);r.tour:act("next");r.run(.5);assert(r.at==nil and r.tour.active.step==2,"the HUD rebuilding: it waits")
		r.run(Tour.MissingGrace+.25);assert(r.at==r.cards.Difficulty,"gone for good: on to step 3")
	end)

	return {passed=#cases,cases=cases}
end
