-- The gift chain on the client (GiftChain; ONBOARDING-FUN-PASS section 2, Onboard "gifts"): the step order from the
-- snapshot, one at a time, never beside another prompt, step 1 straight after the tuck, then 3 minutes clear of the
-- last reveal and two a session; ignored: one nudge then parked; "x": parked, not asked again this session; a parked
-- gift as the chip, the ribbon and the Things row (any of them starts it); veterans get no bubbles; off shows nothing;
-- a refused crank parks again; the first fetch shows the Fetch card once. Onboarding part 2 (ONBOARDING-P2-BRIEF 1,
-- ARCH-REVIEW-P2 2): no chip; at the machine a tap opens the shop on the gift, whose "Hatch free!" is Chain:shopCrank
-- (the same crank); AlreadyGranted never shows a second card; with `teach` gift steps are exempt from the session count.
-- Fake deps and a fake clock only.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(PlayerScripts.Client.ZZSpecs.GiftChain)(PlayerScripts.Client).
return function(client)
	local Chain=require(client.GiftChain)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function snapshot(over)
		local s={nectar=0,totalWins=0,coachMask=0,stats={rounds=0},toyUnlocks={},gifts={owed=true,granted={},ready=nil}}
		for k,v in pairs(over or {})do s[k]=v end
		return s
	end
	local function rig(state)
		local r={state=state,now=0,gate=nil,busy=false,near=false,shown=false,head=nil,hops=0,ribbon=false,row=nil,
			leads={},cranks={},replays={},events={},fetches=0,tips=0,refusals={},shops={},teach=false}
		r.chain=Chain.new({state=function()return r.state end,clock=function()return r.now end,gate=function()return r.gate end,
			busy=function()return r.busy end,near=function()return r.near end,
			bubble={set=function(v,h)r.shown=v==true;if v then r.head=h end end,hop=function()r.hops+=1 end},
			openShop=function(kind)table.insert(r.shops,kind)end,teach=function()return r.teach end,
			ribbon=function(v)r.ribbon=v end,row=function(k)r.row=k end,lead=function(t)table.insert(r.leads,t)end,
			crank=function(kind,done)table.insert(r.cranks,{kind=kind,done=done})end,replay=function(rec)table.insert(r.replays,rec)end,
			refused=function(why)table.insert(r.refusals,why)end,inPark=function()return r.inPark==true end,
			fetchCard=function()r.fetches+=1 end,throwTip=function()r.tips+=1 end,event=function(n)table.insert(r.events,n)end,
			mask=function()return 0 end,park=function()return true end})
		function r.run(seconds,step)
			step=step or .25
			local t=0
			while t<seconds-1e-9 do r.now+=step;t+=step;r.chain:step(r.now)end
		end
		return r
	end

	test("pure: the order from the snapshot; Paint first, an unseen gift before everything, the nest first on a return",function()
		local f=Chain.facts(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		assert(Chain.next(f)=="paint")
		assert(Chain.next(Chain.facts(snapshot({gifts={owed=false,granted={},ready="paint"}})))==nil,"not owed: nothing")
		assert(Chain.next(Chain.facts(snapshot({gifts=nil})))==nil,"off: nothing")
		local unseen=snapshot({gifts={owed=true,granted={paint=true},unseen={kind="paint",item="rose",id="a"}}})
		assert(Chain.next(Chain.facts(unseen))=="unseen"and Chain.giftOf("unseen",Chain.facts(unseen))=="paint")
		local paid=snapshot({nectar=50,gifts={owed=true,granted={paint=true}}})
		assert(Chain.next(Chain.facts(paid))=="pull","Stars cover an egg: their first pull")
		paid.stats={rounds=0,starsSpent=12};assert(Chain.next(Chain.facts(paid))==nil,"pulled: no invite")
		local toy=snapshot({gifts={owed=true,granted={paint=true},ready="toy"}})
		assert(Chain.next(Chain.facts(toy))=="toy")
		local park=snapshot({gifts={owed=true,granted={paint=true,toy=true}}})
		assert(Chain.next(Chain.facts(park))=="park")
		park.stats={rounds=4,fetches=1};park.dash={ribbons={}}
		assert(Chain.next(Chain.facts(park,{returned=false}))==nil and Chain.next(Chain.facts(park,{returned=true}))=="dash","the race in a later session")
		local snack=snapshot({gifts={owed=true,granted={paint=true,toy=true},ready="snack"},stats={fetches=2}})
		assert(Chain.next(Chain.facts(snack))=="snack")
		local nest=snapshot({nest={ready=true},gifts={owed=true,granted={},ready="paint"}})
		assert(Chain.next(Chain.facts(nest,{returned=true}))=="nest"and Chain.next(Chain.facts(nest,{returned=false}))=="paint")
		local all={};for _,id in ipairs(require(game:GetService("ReplicatedStorage").Shared.ToyCatalog).Pools[3])do all[id]=true end
		local skip=snapshot({toyUnlocks=all,gifts={owed=true,granted={paint=true}}})
		assert(Chain.next(Chain.facts(skip))=="park","owning every toy skips step 3")
	end)

	test("pure: may (gap, two a session, closed, veterans) and the parked gift",function()
		local session={closed={},count=0}
		assert(Chain.may(session,"paint",0,{})and Chain.may(session,"unseen",0,{}),"step 1 and an unseen gift: no gap")
		session.lastReveal=100
		assert(not Chain.may(session,"toy",100+Chain.Gap-1,{})and Chain.may(session,"toy",100+Chain.Gap,{}))
		session.count=Chain.PerSession;assert(not Chain.may(session,"toy",1e6,{}),"two a session")
		session.count=0;session.closed.toy=true;assert(not Chain.may(session,"toy",1e6,{}),"x: not asked again this session")
		assert(not Chain.may({closed={},count=0},"paint",0,{veteran=true}),"veterans: no bubbles")
		local f=Chain.facts(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		assert(Chain.parked(f,nil)=="paint"and Chain.parked(f,{gift="paint"})==nil)
		assert(Chain.parked(Chain.facts(snapshot({gifts={owed=true,granted={paint=true},ready=nil}})),nil)==nil)
	end)

	test("step 1: the Paint bubble 1.5 s after it turns ready, never beside another prompt; it holds the garden; a tap leads, at the machine it cranks",function()
		local r=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		r.busy=true;r.run(5)
		assert(not r.shown and not r.chain:holds(),"the need bubble is up: wait")
		r.busy=false;r.run(1)
		assert(not r.shown,"1.5 s after the tuck")
		r.run(1)
		assert(r.shown and r.head=="onbGift.paint"and r.chain:holds()and r.events[1]=="GiftShown")
		assert(not r.ribbon,"the bubble is the gift: no ribbon beside it")
		r.gate="menu";r.run(.5);assert(not r.shown,"hidden under a menu");r.gate=nil;r.run(.25);assert(r.shown)
		r.chain:tap();assert(r.leads[1]=="Eggs"and r.chain:holds())
		r.near=true;r.run(.25);assert(r.shown and r.head=="onbGift.atMachine","at the machine: Tap the machine!")
		r.chain:tap();assert(#r.cranks==0 and r.shops[1]=="paint"and not r.shown,"a tap at the machine opens the shop, never cranks")
		assert(r.chain:offer()=="paint","the shop offers the gift")
		assert(not r.chain:shopCrank("toy"),"only the gift that is ready")
		assert(r.chain:shopCrank("paint")and #r.cranks==1 and r.cranks[1].kind=="paint"and not r.shown,"Hatch free! is the same crank")
		assert(r.chain:offer()==nil and not r.chain:shopCrank("paint")and #r.cranks==1,"latched while it cranks: never a second ask")
		r.cranks[1].done("Saved")
		r.state=snapshot({gifts={owed=true,granted={paint=true},unseen={kind="paint",item="rose",id="g"}}})
		r.run(1);assert(r.chain:holds()and not r.shown,"the card is up")
		r.chain:revealed();assert(not r.chain:holds())
		r.state=snapshot({gifts={owed=true,granted={paint=true}}})
		r.run(5);assert(not r.shown,"nothing more until a step is due")
	end)

	test("ignored: one nudge, then parked as the chip, ribbon and row; a tap on any starts it; x parks at once for the session",function()
		local r=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		r.run(3);assert(r.shown)
		r.run(Chain.NudgeAfter);assert(r.hops==1 and r.shown,"one nudge")
		r.run(Chain.ParkAfter+.5);assert(not r.shown and r.ribbon and r.row=="paint"and not r.chain:holds(),"parked")
		r.run(60);assert(not r.shown,"not asked again this session")
		assert(r.chain:resume()and r.leads[#r.leads]=="Eggs"and r.chain:holds(),"the ribbon / row starts it")
		r.near=true;r.run(.25);r.chain:tap();assert(#r.cranks==0 and #r.shops==1);assert(r.chain:shopCrank("paint")and #r.cranks==1)
		r.cranks[1].done("Rejected","Busy");assert(not r.chain:holds()and r.refusals[1]=="Busy","refused: parked again")
		r.run(.5);assert(r.ribbon and r.row=="paint","still waiting: it never expires")
		local x=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		x.run(3);x.chain:close();assert(not x.shown and not x.chain:holds())
		x.run(.5);assert(x.ribbon and x.row=="paint");x.run(300);assert(not x.shown)
	end)

	test("after step 1: 3 minutes clear of the last reveal and at most two a session; invites lead and close",function()
		local r=rig(snapshot({nectar=50,gifts={owed=true,granted={paint=true}}}))
		r.chain.session.lastReveal=0
		r.run(Chain.Gap-2);assert(not r.shown,"the gap")
		r.run(4);assert(r.shown and r.head=="onbGift.pull")
		r.chain:tap();assert(r.leads[1]=="Eggs"and not r.shown and not r.chain:holds(),"an invite: the lead is the step")
		r.state=snapshot({nectar=50,stats={rounds=0,starsSpent=12},gifts={owed=true,granted={paint=true},ready="toy"}})
		r.run(3);assert(r.shown and r.head=="onbGift.toy","the second invite this session")
		r.chain:close()
		r.state=snapshot({stats={rounds=4,starsSpent=12},gifts={owed=true,granted={paint=true,toy=true}}})
		r.run(400);assert(not r.shown,"two a session: the park waits for the next")
	end)

	test("veterans: no bubbles, only the chip, ribbon and row; off: nothing at all; an unseen gift replays through the machine",function()
		local v=rig(snapshot({totalWins=50,gifts={owed=true,granted={},ready="paint"}}))
		v.run(10);assert(not v.shown and v.ribbon and v.row=="paint")
		local o=rig(snapshot({gifts=nil}));o.run(10);assert(not o.shown and not o.ribbon and o.row==nil and not o.chain:holds())
		local u=rig(snapshot({gifts={owed=true,granted={paint=true},unseen={kind="paint",item="tide",id="u"}}}))
		u.run(2);assert(u.shown and u.head=="onbGift.waiting")
		u.near=true;u.chain:tap();assert(#u.cranks==0 and u.replays[1].item=="tide","no new ask: the same gift again")
		-- switch off while a bubble shows: it goes
		local s=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		s.run(3);assert(s.shown);s.state=snapshot({gifts=nil});s.run(.25);assert(not s.shown and not s.chain:holds()and not s.ribbon)
	end)

	test("the park: Throw it! there once, and the first fetch shows the Fetch card once",function()
		local r=rig(snapshot({gifts={owed=true,granted={paint=true,toy=true}},stats={rounds=4,starsSpent=1}}))
		r.chain.session.lastReveal=0;r.run(Chain.Gap+3);assert(r.shown and r.head=="onbGift.park",tostring(r.shown).." "..tostring(r.head).." "..tostring(r.chain.active and r.chain.active.step))
		r.chain:tap();assert(r.leads[1]=="Park")
		r.inPark=true;r.run(1);assert(r.tips==1);r.run(5);assert(r.tips==1)
		r.state=snapshot({gifts={owed=true,granted={paint=true,toy=true}},stats={rounds=4,starsSpent=1,fetches=1}})
		r.run(1);assert(r.fetches==1);r.run(5);assert(r.fetches==1)
	end)

	test("code review: a tapped gift's lead never holds the Bear's prompts for long (no step closer, walking away, idle at the machine)",function()
		local function leading()
			local r=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
			r.dist=80
			r.chain.d.distance=function()return r.dist end
			r.run(3);r.chain:tap();assert(r.chain:holds()and r.chain.active.phase=="leading")
			return r
		end
		local r=leading()
		r.run(Chain.LeadPark-1);assert(r.chain:holds())
		r.run(1.5);assert(not r.chain:holds()and r.ribbon and r.row=="paint","no step closer for LeadPark s: parked, the guide resumes")
		local w=leading()
		for _=1,30 do w.dist-=1;w.run(1)end
		assert(w.chain:holds(),"heading there: still leading after 30 s")
		w.dist+=Chain.Away+1;w.run(.25);assert(not w.chain:holds()and w.ribbon,"walking away: parked")
		local m=leading()
		m.near=true;m.run(.25);assert(m.shown and m.head=="onbGift.atMachine")
		m.run(Chain.NudgeAfter+Chain.ParkAfter+.5);assert(not m.chain:holds()and not m.shown and m.ribbon,"idle at the machine: parked")
	end)

	test("code review: the client asks again on a busy save; giftSeen also on Pending and RevealPending, a few times",function()
		assert(Chain.retryAsk("Rejected","Busy",0)and Chain.retryAsk("Rejected","Throttled",0)and Chain.retryAsk("Retrying",nil,0))
		assert(not Chain.retryAsk("Rejected","NotDue",0)and not Chain.retryAsk("Saved",nil,0)and not Chain.retryAsk("Rejected","Busy",Chain.AskTries))
		for _,why in ipairs({"Busy","Throttled","Pending","RevealPending","Retrying"})do assert(Chain.retrySeen("Rejected",why,0),why)end
		assert(not Chain.retrySeen("Rejected","NoGift",0)and not Chain.retrySeen("Saved","Saved",0)and not Chain.retrySeen("Rejected","Pending",Chain.SeenTries))
	end)

	test("part 2: the shop's latch (a Menu shop builds its step; latched while it cranks or shows; refused: offered again)",function()
		local f=Chain.facts(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		assert(Chain.shopGift(f,nil)=="paint"and Chain.shopGift(f,{phase="cranking"})==nil and Chain.shopGift(f,{phase="reveal"})==nil)
		assert(Chain.shopGift(Chain.facts(snapshot({gifts={owed=true,granted={paint=true},ready="paint"}})),nil)==nil,"given: the paid egg is back")
		assert(Chain.shopGift(Chain.facts(snapshot({gifts={owed=true,granted={paint=true},ready="toy",unseen={kind="paint",item="rose"}}})),nil)==nil,
			"an unseen card first: it replays, no Hatch free!")
		assert(Chain.shopGift(Chain.facts(snapshot({gifts=nil})),nil)==nil,"off: no gift mode")
		-- a shop opened from the Menu: no step is active; the press builds one, then the same crank
		local r=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		r.chain.session.closed.paint=true -- "x" earlier this session
		assert(r.chain.active==nil and r.chain:shopCrank("paint")and #r.cranks==1 and r.chain:holds())
		r.cranks[1].done("Rejected","PetNotOut")
		assert(not r.chain:holds()and r.refusals[1]=="PetNotOut"and r.chain:offer()=="paint","refused: the tile stays lit")
		-- the Snack gift's reveal (not GiftReveal): once seen open, its close ends the step
		local s=rig(snapshot({stats={rounds=4,starsSpent=1},gifts={owed=true,granted={paint=true,toy=true},ready="snack"}}))
		local open=false
		s.chain.d.revealOpen=function()return open end
		assert(s.chain:shopCrank("snack")and s.cranks[1].kind=="snack");s.cranks[1].done("Saved")
		s.run(.5);assert(s.chain:holds(),"before the reveal opens")
		open=true;s.run(.5);assert(s.chain:holds());open=false;s.run(.5)
		assert(not s.chain:holds()and s.chain.session.lastReveal~=nil,"the reveal closed: done, the gap starts")
		-- an unseen gift from the Menu's shop: replayed, never asked again
		local u=rig(snapshot({gifts={owed=true,granted={paint=true},unseen={kind="paint",item="tide",id="u"}}}))
		assert(u.chain:replayUnseen()and u.replays[1].item=="tide"and #u.cranks==0)
		assert(not rig(snapshot({gifts={owed=true,granted={}}})).chain:replayUnseen(),"nothing unseen: the shop opens")
	end)

	test("part 2: AlreadyGranted never shows a second card",function()
		local rec={kind="paint",item="rose",id="g1"}
		assert(Chain.showCard({status="Saved",reason="Saved",gift=rec},{},false),"a fresh grant shows")
		local presented={[Chain.recordKey(rec)]=true}
		assert(not Chain.showCard({status="Saved",reason="AlreadyGranted",gift=rec},presented,false),"a second ask: no second card")
		assert(not Chain.showCard({status="Saved",reason="AlreadyGranted",gift=rec},{},true),"a card is up: no second card")
		assert(Chain.showCard({status="Saved",reason="AlreadyGranted",gift=rec},{},false),"never shown this session (a rejoin): it shows")
		assert(not Chain.showCard({status="Rejected",reason="Busy"},{},false)and not Chain.showCard({status="Saved"},{},false))
		assert(Chain.recordKey({kind="toy",item="ball"})=="toy:ball")
	end)

	test("part 2 (teach): gift steps never count toward the session; invites three a session, 90 s apart; the Dash invite the same session",function()
		local session={closed={},count=0,lastReveal=100}
		assert(Chain.may(session,"toy",101,{},true)and Chain.may(session,"snack",101,{},true),"gift steps exempt")
		assert(not Chain.may(session,"pull",100+89,{},true)and Chain.may(session,"pull",100+90,{},true),"90 s clear")
		session.count=2;assert(Chain.may(session,"pull",1e6,{},true),"a third");session.count=3;assert(not Chain.may(session,"pull",1e6,{},true))
		assert(not Chain.may({closed={},count=0,lastReveal=100},"toy",101,{}),"teach off: as before")
		local dash=snapshot({stats={rounds=4,starsSpent=1,fetches=1},dash={ribbons={}},gifts={owed=true,granted={paint=true,toy=true}}})
		assert(Chain.next(Chain.facts(dash,{returned=false}))==nil,"off: a later session")
		assert(Chain.next(Chain.facts(dash,{returned=false,teach=true}))=="dash","teach: the same session")
	end)

	-- Beta 42 note 5 (DIAGNOSIS A5): the gift's reveal is the regular full-screen stage (GiftStage). Its callbacks are
	-- the card's: the chain holds through it and its close ends the step; while it is up a second ask shows nothing.
	test("beta 42: the reveal through the stage holds the chain until its close; AlreadyGranted shows no second card",function()
		local Stage=require(client.GiftStage)
		local r=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		local up=false
		r.chain.d.revealOpen=function()return up end
		assert(r.chain:shopCrank("paint"));r.cranks[1].done("Saved")
		local rec={kind="paint",item="rose",id="g9"}
		local presented={[Chain.recordKey(rec)]=true}
		-- what init's present() hands the stage: closed() is the chain's revealed() (and the machine's camera)
		local log={}
		local flow=Stage.flow(rec,{act=function()table.insert(log,"act")end,seen=function()table.insert(log,"seen")end,
			closed=function()table.insert(log,"closed");r.chain:revealed()end},function()end)
		up=true;r.run(1)
		assert(r.chain:holds()and r.chain.active.phase=="reveal","the stage is up: the garden's prompts wait")
		assert(not Chain.showCard({status="Saved",reason="AlreadyGranted",gift=rec},presented,up),"a second ask: no second card")
		assert(not Chain.showCard({status="Saved",reason="AlreadyGranted",gift=rec},{},up),"never shown here, but one is up: none")
		assert(flow.choose(true)and log[1]=="act")
		up=false;flow.finish()
		assert(not r.chain:holds()and r.chain.session.lastReveal==r.now and table.concat(log,",")=="act,seen,closed","closed: the step is done")
		r.run(1);assert(not r.chain:holds())
		-- a stage lost before a choice: closed still ends the step (never held to the stuck timeout)
		local l=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		l.chain:shopCrank("paint");l.cranks[1].done("Saved")
		Stage.flow(rec,{closed=function()l.chain:revealed()end},function()end).finish("lost")
		assert(not l.chain:holds())
	end)

	-- Beta 41 code review.
	test("beta 41 review: a Saved answer whose card is suppressed ends the step at once, never held to the stuck timeout",function()
		local r=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		assert(r.chain:shopCrank("paint")and r.chain:holds())
		r.cranks[1].done("Saved",nil,true)
		assert(not r.chain:holds()and r.chain.active==nil,"no reveal phase: the garden's prompts go on")
		assert(r.chain.session.lastReveal==r.now and table.find(r.events,"GiftDone"),"done: the gap starts now")
		-- a card that does show: held until it closes, as before
		local c=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		c.chain:shopCrank("paint");c.cranks[1].done("Saved")
		assert(c.chain:holds()and c.chain.active.phase=="reveal")
		c.chain:revealed();assert(not c.chain:holds())
	end)
	test("beta 41 review: an unseen gift replays once a session; then the shop opens as usual and no bubble asks again",function()
		local u=rig(snapshot({gifts={owed=true,granted={paint=true},unseen={kind="paint",item="tide",id="u"}}}))
		assert(u.chain:replayUnseen()and #u.replays==1)
		u.chain:revealed()
		-- the server never recorded it seen (giftSeen gave up): still unseen in the snapshot
		assert(not u.chain:replayUnseen()and #u.replays==1,"the second shop open opens the shop")
		u.run(10);assert(not u.shown and not u.chain:holds(),"no bubble for it again this session")
		assert(not u.chain:replayUnseen(),"and never again this session")
		-- another unseen gift: its own one replay
		u.state=snapshot({gifts={owed=true,granted={paint=true,toy=true},unseen={kind="toy",item="ball",id="w"}}})
		assert(u.chain:replayUnseen()and #u.replays==2)
		-- the bubble's replay at the machine counts too
		local b=rig(snapshot({gifts={owed=true,granted={paint=true},unseen={kind="paint",item="tide",id="u"}}}))
		b.run(2);b.near=true;b.chain:tap();assert(#b.replays==1)
		b.chain:revealed();assert(not b.chain:replayUnseen(),"then the shop opens")
	end)

	return {passed=#cases,cases=cases}
end
