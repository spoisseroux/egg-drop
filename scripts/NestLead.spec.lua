-- The Bear leads you to the nest, the client's half (ONBOARDING-V3-BRIEF.md sections 1 and 3, Onboard "lead" and
-- "allset2"): BearNeeds with the lead on (the two-line prompts, 2 s between, "Play for Stars!" done by a round played),
-- NestLead (2a -> 2b, the nudges, the park and its chip, the pause, no pet out, a refused or lost lead, the tuck's
-- celebration), a session picking an unfinished guide back up, the end card only when all three are truly done, the
-- all-set card's timings, the trail adapter and the bubble's second line. Nothing soft-blocks; nothing times out.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.NestLead)(PlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Coach=require(Shared.CoachMarks)
	local UICopy=require(Shared.UICopy)
	local Lead=require(Shared.PetLead)
	local Needs=require(client.BearNeeds)
	local NestLead=require(client.NestLead)
	local LeadTrail=require(client.LeadTrail)
	local Card=require(client.AllSetCard)
	local Bubble=require(client.NeedBubble)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local function with(base,t)local c=table.clone(base);for k,x in pairs(t or {})do c[k]=x end;return c end
	local function v(x,z)return Vector3.new(x,4,z)end
	local FRESH={status="Ready",coachMask=0,totalWins=1,nectar=20,stats={rounds=1},petToys={},toyUnlocks={},nest={n=0,at=1}}

	-- The controller with the game as fakes, the lead on, and a small fake server for the pet.
	local function rig(over)
		over=over or {}
		local r={state=with(FRESH,over.state or {}),owned=1,mask=over.mask or 0,marked={},trails={},acts={},chirps=0,reacts={},trailUp=false,
			gate={on=true,mode="Room",canRoam=true,idleFor=5,awayFor=0,roomFor=5,windowActive=true,railEmpty=true,parkPending=0,action="idle"},
			root=v(0,0),petAt=v(2,0),model={},nestAt=v(0,60),sent={},events={},toasts={},celebrations=0,beckons=0,hops=0,shows={},leads={},
			server={seq=0,actor=nil},holds={},returning=over.returning==true,leadOn=over.leadOn~=false,allSet2=over.allSet2~=false}
		r.bubble={sets={},hops=0}
		function r.bubble:set(icon,visible,words,sub)
			table.insert(self.sets,{icon=icon,visible=visible,words=words,sub=sub})
			self.icon=if visible then icon else nil;self.words=if visible then words else nil;self.sub=if visible then sub else nil
		end
		function r.bubble:hop()self.hops+=1 end
		function r.bubble:press()end
		function r.bubble:step()end
		function r.bubble:chip(on)self.chipOn=on end
		local trail={}
		function trail:lead(model,target)table.insert(r.leads,target);r.trailUp=true;return true end
		function trail:show(target)table.insert(r.shows,target);r.trailUp=true;return true end
		function trail:active()return r.trailUp end
		function trail:stop()r.trailUp=false;r.trailStops=(r.trailStops or 0)+1 end
		function trail:hold(on)table.insert(r.holds,on)end
		local leadDeps={
			send=function(kind,body)
				table.insert(r.sent,kind)
				if kind=="start"then
					if r.refuse then return end
					r.server.seq+=1
					r.lastRoute=body.route
					r.server.actor={action="leadStart",actionId=r.server.seq,startTime=r.t,lead={seq=r.server.seq,phase="start"}}
				elseif kind=="stop"or kind=="cheer"then r.server.actor=nil end
			end,
			plan=function(from,to,done)done(if r.noRoute then nil else{from,(from+to)/2,to})end,
			actor=function()return r.server.actor end,serverNow=function()return r.t end,
			pet=function()if r.petAt then return r.petAt,r.model end;return nil end,
			root=function()return r.root end,nest=function()return r.nestAt end,trail=trail,targetName=function()return "Nest"end,
			beckon=function()r.beckons+=1 end,hop=function()r.hops+=1 end,chirp=function()r.chirps+=1 end,
			event=function(name)table.insert(r.events,name)end,celebrate=function()r.celebrations+=1 end,toast=function(key)table.insert(r.toasts,key)end}
		r.needs=Needs.new({bubble=r.bubble,state=function()return r.state end,owned=function()return r.owned end,mask=function()return r.mask end,
			mark=function(id)table.insert(r.marked,id);r.mask=Coach.with(r.mask,id)end,finishIntro=function()r.mask=Coach.with(r.mask,"gardenIntro")end,
			follow=function()return true end,needs=function()return true end,returning=function()return r.returning end,
			gate=function()return r.gate end,greeting=function()return false end,inPark=function()return false end,nest=function()return r.nest~=false end,
			place=function(where)return Vector3.new(#where,0,0),where end,
			trail=function(target,how)table.insert(r.trails,{name=target.name,how=how});return true end,trailActive=function()return false end,
			trailTarget=function()return nil end,prompt=function()return r.prompt==true end,
			sayHi=function()table.insert(r.acts,"hi");return true end,playDeck=function()table.insert(r.acts,"deck");return true end,
			quiet=function()end,chirp=function()r.chirps+=1 end,react=function(id)table.insert(r.reacts,id)end,
			guide=function()return true end,words=function(id)return "W:"..id end,far=function()return true end,
			pulseDeck=function(on)r.pulse=on end,allSet=function()r.allSets=(r.allSets or 0)+1 end,firstPet=function()end,
			petShown=function()return r.petAt~=nil end,
			lead=function()return r.leadOn end,allSet2=function()return r.allSet2 end,nestOn=function()return true end,
			copy=function(key)return "C:"..key end,leadDeps=leadDeps})
		r.t=0
		function r.run(seconds,dt)
			dt=dt or .25
			for _=1,math.max(1,math.floor(seconds/dt+.5))do r.t+=dt;r.needs:step(r.t,dt)end
		end
		-- the fake server moves the pet: run / wait as asked
		function r.phase(phase,action)
			if r.server.actor then r.server.actor.lead.phase=phase;r.server.actor.action=action;r.server.actor.startTime=r.t;r.server.actor.actionId=(r.server.actor.actionId or 0)+1 end
		end
		function r.toNest()
			r.run(Needs.Return+.5);r.needs:saidHi();r.run(Lead.Rest+.5)
		end
		return r
	end
	local function has(list,x)return table.find(list,x)~=nil end
	local function count(list,x)local n=0;for _,y in ipairs(list)do if y==x then n+=1 end end;return n end

	test("lead: the three prompts in two lines, 2 s between; Pet, then Follow (paws, the pet leads), then Play for Stars",function()
		local r=rig()
		r.run(Needs.Return+.5)
		assert(r.needs.lead==true and r.bubble.icon=="hand"and r.bubble.words=="C:onbLead.pet"and r.bubble.sub==nil,"Pet {pet}!, one line")
		r.needs:saidHi();r.run(Lead.Rest-.5)
		assert(r.bubble.icon==nil,"2 s of nothing")
		r.run(1)
		assert(r.bubble.icon=="paws"and r.bubble.words=="C:onbLead.follow"and r.bubble.sub=="C:onbLead.followSub","Follow {pet}! / A new egg is waiting")
		assert(r.needs.bubbleOn=="pet")
		assert(has(r.sent,"start")and #r.lastRoute==3,"the lead starts with the trail's route")
		r.state.nest={n=0,at=1,tucked=true};r.run(Lead.Rest+.5)
		assert(r.bubble.icon=="deck"and r.bubble.words=="C:onbLead.deck"and r.bubble.sub=="C:onbLead.deckSub","Play for Stars! / Stars buy eggs and toys")
		r.gate.mode="Board";r.run(5)
		r.gate.mode="Room";r.run(Needs.Return+.5)
		assert(r.bubble.icon=="deck"and r.allSets==nil,"opening the deck is not enough")
		r.state.stats={rounds=2};r.run(.5)
		assert(r.allSets==1,"a round played: all set, once")
		r.run(20);assert(r.allSets==1)
	end)
	test("2a: taken by the server with a chirp; the prints follow the pet; the look back beckons every 2.5 s with the bubble's hop",function()
		local r=rig()
		r.run(Needs.Return+.5);r.needs:saidHi()
		local chirps=r.chirps
		r.run(Lead.Rest+.5)
		assert(r.chirps==chirps+1,"the chirp as it hops twice: "..(r.chirps-chirps))
		assert(#r.leads>=1 and r.leads[1].position==r.nestAt,"the prints lead by the pet")
		r.phase("wait","leadWait");r.run(.25)
		assert(r.beckons==1 and r.hops>=1,"the first beckon")
		r.run(2);assert(r.beckons==1)
		r.run(.5);assert(r.beckons==2,"again 2.5 s later")
	end)
	test("2a closes the moment the player is within 8 of the nest (got there first too); 2b sits on the nest; the tuck celebrates once",function()
		local r=rig()
		r.toNest()
		r.root=r.nestAt+Vector3.new(0,0,-Lead.Reach+.5);r.run(.5)
		assert(r.bubble.icon=="moon"and r.bubble.words=="C:onbLead.tuck"and r.bubble.sub=="C:onbLead.tuckSub","Tuck the egg in! / It hatches tomorrow")
		assert(r.needs.bubbleOn=="nest","on the nest")
		assert(has(r.events,"NestReached"))
		assert(not table.find(r.marked,"needNest"),"never done by being there: the tuck closes it")
		r.run(60);assert(r.bubble.icon=="moon","still asking")
		r.state.nest={n=0,at=1,tucked=true};r.run(.5)
		assert(has(r.sent,"cheer")and r.celebrations==1 and r.toasts[1]==Lead.ToastCopy,"the jump-spin, the hearts and buzz, the toast")
		r.run(10);assert(r.celebrations==1 and count(r.sent,"cheer")==1,"once")
	end)
	test("a nudge holds the pet's prints (leadHold) through the server's run back, or Restart.wait if it never came; reaching the nest ends the trail",function()
		local r=rig()
		r.toNest()
		r.phase("wait","leadWait")
		r.run(Lead.Still+.25)
		assert(count(r.sent,"back")==1 and r.holds[1]==true and #r.holds==1,"held at the nudge")
		r.phase("back","leadBack");r.run(3)
		assert(#r.holds==1,"held while it runs back")
		r.phase("wait","leadWait");r.run(.25)
		assert(r.holds[2]==false,"let go once back is over")
		r.run(Lead.Still+.25)
		assert(count(r.sent,"back")==2 and r.holds[3]==true)
		r.run(Lead.Restart.wait+.25)
		assert(r.holds[4]==false,"never went back: let go after Restart.wait")
		local stops=r.trailStops or 0
		r.root=r.nestAt+Vector3.new(0,0,-Lead.Reach+1);r.run(.25)
		assert(has(r.events,"NestReached")and(r.trailStops or 0)==stops+1 and not r.trailUp,"arrived: the trail (and the pet's prints) end")
		r.run(5);assert(not r.trailUp,"not laid again")
	end)
	test("nudges: still 8 s, the pet comes back with This way! for 2 s; three ignored, the fourth parks it: the chip, the next prompt, the trail lit",function()
		local r=rig()
		r.toNest()
		r.phase("wait","leadWait")
		r.run(Lead.Still+.25)
		assert(count(r.sent,"back")==1 and r.bubble.words=="C:"..Lead.ThisWayCopy,"a nudge: back, and This way!")
		r.run(Lead.ThisWay+.25);assert(r.bubble.words=="C:onbLead.follow","the headline again")
		r.run(Lead.Still*2+1)
		assert(count(r.sent,"back")==3,"three nudges: "..count(r.sent,"back"))
		r.run(Lead.Still+.5)
		assert(r.needs.nestLead.parked and has(r.events,"LeadParked")and has(r.sent,"stop"),"parked: the lead over")
		assert(r.bubble.chipOn==true,"the moon chip over the pet")
		r.run(Lead.Rest+.5)
		assert(r.bubble.icon=="deck","prompt 3 may show")
		assert(#r.shows>=1 and r.shows[#r.shows].position==r.nestAt,"the trail stays lit")
		assert(not table.find(r.marked,"needNest")and r.allSets==nil,"never done by a park")
		-- the chip: the lead again
		assert(r.needs:chipTap())
		r.run(.5)
		assert(r.bubble.icon=="paws"and r.bubble.chipOn==false,"leading again")
		assert(count(r.sent,"start")>=2)
	end)
	test("a park comes back after the deck next closes",function()
		local r=rig()
		r.toNest()
		r.phase("wait","leadWait")
		r.run(Lead.Still*4+4)
		assert(r.needs.nestLead.parked)
		r.gate.mode="Board";r.run(3)
		r.gate.mode="Room";r.run(Needs.Return+.5)
		assert(not r.needs.nestLead.parked and r.bubble.icon=="paws","the nest prompt again")
	end)
	test("paused: a menu or the deck stops the lead (the pet follows); 2.5 s after it closes the lead starts again",function()
		local r=rig()
		r.toNest()
		local starts=count(r.sent,"start")
		r.gate.modal=true;r.run(1)
		assert(has(r.sent,"stop")and r.bubble.icon==nil,"paused")
		r.gate.modal=nil;r.run(Needs.Return-.5)
		assert(count(r.sent,"start")==starts,"not yet")
		r.run(1)
		assert(count(r.sent,"start")==starts+1 and r.bubble.icon=="paws","on again")
		-- a station's prompt in reach only hides the bubble; the lead goes on
		local stops=count(r.sent,"stop")
		r.prompt=true;r.run(1)
		assert(r.bubble.icon==nil and count(r.sent,"stop")==stops,"hidden, still leading")
	end)
	test("no pet out: no leader; 2b's bubble on the nest with today's trail from the player",function()
		local r=rig()
		r.toNest()
		r.petAt=nil;r.run(.5)
		assert(r.bubble.icon=="moon"and r.needs.bubbleOn=="nest","on the nest")
		assert(has(r.sent,"stop"),"the lead is over")
		assert(#r.shows>=1,"today's trail from the player")
		r.petAt=v(3,3);r.run(.5)
		assert(r.bubble.icon=="paws","a pet out again leads")
	end)
	test("refused: asked again with a backoff; after three tries it goes on without a leader (2b on the nest); never done",function()
		local r=rig()
		r.refuse=true
		r.toNest()
		r.run(30)
		assert(count(r.sent,"start")==Lead.Restart.tries,"three tries: "..count(r.sent,"start"))
		assert(r.bubble.icon=="moon"and r.needs.bubbleOn=="nest","leaderless")
		assert(not table.find(r.marked,"needNest"))
		local s=rig();s.noRoute=true;s.toNest();s.run(30)
		assert(count(s.sent,"start")==0 and s.bubble.icon=="moon","no dry way: no start at all, the nest prompt on the nest")
	end)
	test("lost (poofed to the player off the route): a new route from where the pet stands",function()
		local r=rig()
		r.toNest()
		r.run(.25)
		local starts=count(r.sent,"start")
		r.server.actor.lead.lost=true
		r.run(.25)
		assert(count(r.sent,"start")==starts+1,"a new start")
		r.run(3);assert(count(r.sent,"start")==starts+1,"once")
	end)
	test("a session that ends mid-guide resumes from its saved facts; a veteran or a finished guide gets none",function()
		local hi=Coach.with(0,"needHi")
		local r=rig({returning=true,mask=hi,state={coachMask=hi}})
		r.run(Needs.Return+.5)
		assert(r.needs.resumed==true and r.bubble.icon=="paws","picked up at the nest")
		local vet=rig({returning=true,mask=hi,state={coachMask=hi,totalWins=Coach.VeteranWins}})
		vet.run(5);assert(vet.bubble.icon==nil,"a veteran: none")
		local done=Coach.with(Coach.with(hi,"needNest"),"needDeck")
		local fin=rig({returning=true,mask=done,state={coachMask=done,stats={rounds=3},nest={n=1,at=1,tucked=true}}})
		fin.run(5);assert(fin.bubble.icon==nil and fin.allSets==nil,"finished: none")
		local early=rig({returning=true,mask=0,state={coachMask=0}})
		early.run(5);assert(early.bubble.icon==nil,"never started (returning by the old rule): none")
		assert(Needs.resumable({coachMask=hi,totalWins=0,stats={rounds=1}})and not Needs.resumable(nil))
	end)
	test("the end card waits for all three truly done, in the garden with nothing open; never while parked",function()
		local r=rig()
		r.toNest()
		r.phase("wait","leadWait")
		r.run(Lead.Still*4+4)
		assert(r.needs.nestLead.parked)
		r.state.stats={rounds=2};r.run(5)
		assert(r.allSets==nil,"the nest parked: not all set")
		r.state.nest={n=0,at=1,tucked=true};r.gate.modal=true;r.run(1)
		assert(r.allSets==nil,"a menu open: it waits")
		r.gate.modal=nil;r.run(Needs.Return+Lead.Rest+.5)
		assert(r.allSets==1,"then all set")
		assert(Needs.trulyDone(Needs.facts(with(FRESH,{stats={rounds=2},nest={tucked=true,n=0,at=1}}),{saidHi=true}),true))
		assert(not Needs.trulyDone(Needs.facts(with(FRESH,{stats={rounds=2}}),{saidHi=true}),true))
		assert(Needs.trulyDone(Needs.facts(with(FRESH,{stats={rounds=2},nest=nil}),{saidHi=true}),false),"the nest off in this world")
	end)
	test("lead off: today's guide (one line, the deck opening closes Play for Stars)",function()
		local r=rig({leadOn=false,allSet2=false})
		r.run(Needs.Return+.5)
		assert(r.needs.lead==false and r.bubble.words=="W:needHi"and r.bubble.sub==nil)
		assert(r.needs.nestLead==nil)
	end)

	-- NestLead alone: the trail adapter, a refused start's backoff, the finish without a tuck.
	test("the trail adapter: the trail starts as a guide, then leadBy the pet (trail2); refused (off): today's trail; hold; stop ends the lead",function()
		local calls={}
		local function fake(glow)
			local t={}
			function t:start(target)table.insert(calls,"start");self.target=target;return true end
			function t:active()return self.target~=nil end
			function t:stop()table.insert(calls,"stop");self.target=nil;self.leader=nil end
			function t:leadBy(model)
				table.insert(calls,"leadBy:"..(if model==nil then "nil"else "pet"))
				if not glow or not self.target then return false end
				self.leader=model;return true
			end
			function t:leadHold(on)table.insert(calls,"hold:"..tostring(on))end
			return t
		end
		-- trail2 on
		local on=fake(true)
		local a=LeadTrail.new({things=on})
		local target={position=v(0,0),name="Nest"}
		assert(a:lead({},target)and a.mode=="lead"and a:active())
		assert(table.find(calls,"start")<table.find(calls,"leadBy:pet"),"started before leadBy")
		assert(on.target.guide==true and on.target.position==target.position and target.guide==nil,"a guide trail; the caller's target untouched")
		a:hold(true);a:hold(false)
		assert(table.find(calls,"hold:true")and table.find(calls,"hold:false"))
		table.clear(calls);a:stop()
		assert(calls[1]=="leadBy:nil"and calls[2]=="stop"and not a:active(),"leadBy(nil), then stop")
		-- trail2 off: leadBy refuses, the started trail is today's; hold does nothing
		table.clear(calls)
		local off=fake(false)
		local b=LeadTrail.new({things=off})
		assert(b:lead({},target)and b.mode=="show"and b:active())
		b:hold(true);assert(not table.find(calls,"hold:true"),"no hold off")
		table.clear(calls);b:stop();assert(calls[1]=="stop"and #calls==1)
		-- no pet: today's trail from the player; another caller's trail is never stopped
		local c=LeadTrail.new({things=on})
		table.clear(calls)
		assert(c:show(target)and calls[#calls]=="start"and on.target==target)
		on:start({position=v(9,9)})
		assert(not c:active(),"Show me elsewhere took it over");table.clear(calls);c:stop();assert(#calls==0)
		on:stop()
		assert(LeadTrail.leader({{},{leadBy=1},on})==on,"only a method counts")
		assert(LeadTrail.new({things=on}):lead(nil,target)and on.target==target,"no model: today's")
	end)
	test("the all-set card's clock: the pop, three stamps one by one, the punched title, the sub-line and button, 5 s; closes after 0.4 s",function()
		assert(Card.cardScale(.1)==nil and near(Card.cardScale(Card.T.card),.85)and Card.cardScale(1)==1)
		local peak=0
		for i=0,30 do peak=math.max(peak,Card.cardScale(Card.T.card+i*.01)or 0)end
		assert(near(peak,1.05,.01),"0.85 -> 1.05 -> 1.0")
		for i,at in ipairs({.3,.5,.7})do
			assert(Card.stampScale(i,at-.01)==nil and near(Card.stampScale(i,at),1.4)and Card.stampScale(i,at+.12)==1,"stamp "..i)
		end
		assert(Card.titleScale(.89)==nil and near(Card.titleScale(.9),1.45)and Card.titleScale(1.2)==1)
		assert(Card.sweep(1,false)and Card.sweep(1,true)==nil and Card.sweep(2,false)==nil,"one sweep; none under Reduced Motion")
		assert(not Card.closable(.3)and Card.closable(.4)and not Card.over(4.9)and Card.over(5))
		local due=Card.due(Card.Cues,-1,.31)
		assert(#due==2 and due[1].cue=="charge"and due[2].speed==1.12,"charge at 1.0, then 1.12")
		local later=Card.due(Card.Cues,.75,.95)
		assert(#later==1 and later[1].cue=="rarity_common")
		assert(#Card.due(Card.Buzz,-1,1)==5 and Card.Buzz[5].haptic=="pop")
		assert(Card.Bubbles==24 and Card.Dots==16 and #Card.Confetti==4)
		for _,stamp in ipairs(Card.Stamps)do assert(UICopy.get(stamp.key)~=stamp.key,stamp.key)end
		assert(UICopy.get("onbAllSet.title")=="You're all set!"and UICopy.get("onbAllSet.sub",{pet="Bear"})=="Bear loves it here."
			and UICopy.get("onbAllSet.next")=="What's next?")
		for i=1,Card.Bubbles do local x,delay,speed=Card.particle(i,Card.Bubbles,"bubble");assert(x>=0 and x<1 and delay>=0 and speed>0)end
	end)
	test("the bubble's second line: a width for the longer line, and the sub-line shown only with two lines",function()
		assert(Bubble.wordWidth("Follow Bear!",nil,"A new egg is waiting")>Bubble.wordWidth("Follow Bear!",nil))
		local ok,b=pcall(function()return Bubble.new({parent=Instance.new("Folder"),world=Instance.new("Folder"),adornee=function()return nil end})end)
		assert(ok and b,tostring(b))
		b:set("paws",true,"Follow Bear!","A new egg is waiting")
		assert(b.subline.Visible==true and b.subline.Text=="A new egg is waiting")
		b:set("hand",true,"Pet Bear!")
		assert(b.subline.Visible==false,"one line")
		b:chip(true);assert(b.chipOn==true)
		b:destroy()
	end)
	return{passed=#cases,cases=cases}
end
