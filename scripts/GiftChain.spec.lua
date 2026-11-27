-- The gift chain on the client (GiftChain; ONBOARDING-FUN-PASS section 2, Onboard "gifts"): the step order from the
-- snapshot, one at a time, never beside another prompt, step 1 straight after the tuck, then 3 minutes clear of the
-- last reveal and two a session; ignored: one nudge then parked; "x": parked, not asked again this session; a parked
-- gift as the chip, the ribbon and the Things row (any of them starts it); veterans get no bubbles; off shows nothing;
-- a refused crank parks again; the first fetch shows the Fetch card once. Fake deps and a fake clock only.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(PlayerScripts.Client.ZZSpecs.GiftChain)(PlayerScripts.Client).
return function(client)
	local Chain=require(client.GiftChain)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function snapshot(over)
		local s={nectar=0,totalWins=0,coachMask=0,stats={rounds=1},toyUnlocks={},gifts={owed=true,granted={},ready=nil}}
		for k,v in pairs(over or {})do s[k]=v end
		return s
	end
	local function rig(state)
		local r={state=state,now=0,gate=nil,busy=false,near=false,shown=false,head=nil,hops=0,chip=false,ribbon=false,row=nil,
			leads={},cranks={},replays={},events={},fetches=0,tips=0,refusals={}}
		r.chain=Chain.new({state=function()return r.state end,clock=function()return r.now end,gate=function()return r.gate end,
			busy=function()return r.busy end,near=function()return r.near end,
			bubble={set=function(v,h)r.shown=v==true;if v then r.head=h end end,hop=function()r.hops+=1 end,chip=function(v)r.chip=v end},
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
		paid.stats={rounds=1,starsSpent=12};assert(Chain.next(Chain.facts(paid))==nil,"pulled: no invite")
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
		assert(not r.chip,"the bubble is the gift: no chip beside it")
		r.gate="menu";r.run(.5);assert(not r.shown,"hidden under a menu");r.gate=nil;r.run(.25);assert(r.shown)
		r.chain:tap();assert(r.leads[1]=="Eggs"and r.chain:holds())
		r.near=true;r.run(.25);assert(r.shown and r.head=="onbGift.turn","at the machine: Turn it!")
		r.chain:tap();assert(#r.cranks==1 and r.cranks[1].kind=="paint"and not r.shown)
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
		r.run(Chain.ParkAfter+.5);assert(not r.shown and r.chip and r.ribbon and r.row=="paint"and not r.chain:holds(),"parked")
		r.run(60);assert(not r.shown,"not asked again this session")
		assert(r.chain:resume()and r.leads[#r.leads]=="Eggs"and r.chain:holds(),"the chip / ribbon / row starts it")
		r.near=true;r.run(.25);r.chain:tap();assert(#r.cranks==1)
		r.cranks[1].done("Rejected","Busy");assert(not r.chain:holds()and r.refusals[1]=="Busy","refused: parked again")
		r.run(.5);assert(r.chip and r.row=="paint","still waiting: it never expires")
		local x=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		x.run(3);x.chain:close();assert(not x.shown and not x.chain:holds())
		x.run(.5);assert(x.chip and x.row=="paint");x.run(300);assert(not x.shown)
	end)

	test("after step 1: 3 minutes clear of the last reveal and at most two a session; invites lead and close",function()
		local r=rig(snapshot({nectar=50,gifts={owed=true,granted={paint=true}}}))
		r.chain.session.lastReveal=0
		r.run(Chain.Gap-2);assert(not r.shown,"the gap")
		r.run(4);assert(r.shown and r.head=="onbGift.pull")
		r.chain:tap();assert(r.leads[1]=="Eggs"and not r.shown and not r.chain:holds(),"an invite: the lead is the step")
		r.state=snapshot({nectar=50,stats={rounds=1,starsSpent=12},gifts={owed=true,granted={paint=true},ready="toy"}})
		r.run(3);assert(r.shown and r.head=="onbGift.toy","the second invite this session")
		r.chain:close()
		r.state=snapshot({stats={rounds=4,starsSpent=12},gifts={owed=true,granted={paint=true,toy=true}}})
		r.run(400);assert(not r.shown,"two a session: the park waits for the next")
	end)

	test("veterans: no bubbles, only the chip, ribbon and row; off: nothing at all; an unseen gift replays through the machine",function()
		local v=rig(snapshot({totalWins=50,gifts={owed=true,granted={},ready="paint"}}))
		v.run(10);assert(not v.shown and v.chip and v.row=="paint")
		local o=rig(snapshot({gifts=nil}));o.run(10);assert(not o.shown and not o.chip and o.row==nil and not o.chain:holds())
		local u=rig(snapshot({gifts={owed=true,granted={paint=true},unseen={kind="paint",item="tide",id="u"}}}))
		u.run(2);assert(u.shown and u.head=="onbGift.waiting")
		u.near=true;u.chain:tap();assert(#u.cranks==0 and u.replays[1].item=="tide","no new ask: the same gift again")
		-- switch off while a bubble shows: it goes
		local s=rig(snapshot({gifts={owed=true,granted={},ready="paint"}}))
		s.run(3);assert(s.shown);s.state=snapshot({gifts=nil});s.run(.25);assert(not s.shown and not s.chain:holds()and not s.chip)
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
		r.run(1.5);assert(not r.chain:holds()and r.chip and r.row=="paint","no step closer for LeadPark s: parked, the guide resumes")
		local w=leading()
		for _=1,30 do w.dist-=1;w.run(1)end
		assert(w.chain:holds(),"heading there: still leading after 30 s")
		w.dist+=Chain.Away+1;w.run(.25);assert(not w.chain:holds()and w.chip,"walking away: parked")
		local m=leading()
		m.near=true;m.run(.25);assert(m.shown and m.head=="onbGift.turn")
		m.run(Chain.NudgeAfter+Chain.ParkAfter+.5);assert(not m.chain:holds()and not m.shown and m.chip,"idle at the machine: parked")
	end)

	test("code review: the client asks again on a busy save; giftSeen also on Pending and RevealPending, a few times",function()
		assert(Chain.retryAsk("Rejected","Busy",0)and Chain.retryAsk("Rejected","Throttled",0)and Chain.retryAsk("Retrying",nil,0))
		assert(not Chain.retryAsk("Rejected","NotDue",0)and not Chain.retryAsk("Saved",nil,0)and not Chain.retryAsk("Rejected","Busy",Chain.AskTries))
		for _,why in ipairs({"Busy","Throttled","Pending","RevealPending","Retrying"})do assert(Chain.retrySeen("Rejected",why,0),why)end
		assert(not Chain.retrySeen("Rejected","NoGift",0)and not Chain.retrySeen("Saved","Saved",0)and not Chain.retrySeen("Rejected","Pending",Chain.SeenTries))
	end)

	return {passed=#cases,cases=cases}
end
