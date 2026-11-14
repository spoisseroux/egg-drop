-- Pure injected server continuity/broker tests, no Players/Workspace/store writes.
return function(server)
	local Contact=require(server.PetContact)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture(label)
		local c={now=0,serial=0,roll=.1,rolls=0,awards=0,packets={},pending=false,reads=0}
		local state={mode="Room",petId="pip",owned=true,alive=true,ready=true,status="Ready",
			character={},root={},epoch=1,position=Vector3.new(0,7,0),capReached=false}
		local function guid()c.serial+=1;return(label or "a")..c.serial end
		local broker
		local function complete(candidate)
			state.lastPetAward={id=candidate.id,sequence=c.awards,day=candidate.day,petId=candidate.petId}
			state.pendingId=nil;state.busy=false;state.ready=true;state.status="Ready"
		end
		broker=Contact.new({now=function()return c.now end,guid=guid,read=function()c.reads+=1;return state end,
			anchor=function()return c.anchor or Vector3.new(2.6,4.025,3)end,
			random=function()c.rolls+=1;return c.roll end,
			candidate=function(lease)return table.freeze({id=guid(),sequence=c.awards+1,day="20",petId=lease.petId,leaseId=lease.id})end,
			award=function(candidate)
				c.awards+=1;c.candidate=candidate
				if c.pending then state.pendingId=candidate.id;state.ready=false;state.status="Retrying"
				else complete(candidate)end
			end,emit=function(packet)table.insert(c.packets,packet)end})
		function c:begin(generation,pet)return broker:begin({requestGeneration=generation or 1,petId=pet or "pip"})end
		function c:pulseUntil(target)
			while self.now+.5<=target do self.now+=.5;broker:pulse(self.leaseId)end
		end
		function c:saved()
			local count=0;for _,p in ipairs(self.packets)do if p.status=="Saved"then count+=1 end end;return count
		end
		function c:complete()complete(self.candidate);broker:reconcile()end
		return broker,c,state
	end
	local function begin(b,c)assert(c:begin());c.leaseId=b.lease.id end
	-- QA 2026-11-13 Q2.7 tuning: W seconds of contact pay, S seconds between awards, chance 1.
	-- QA v2 R5.5: W 4 -> 1.5, S 10 -> 6 (the fixture pulses every 0.5 s, so W stays a multiple of 0.5).
	local W,S=Contact.OpportunitySeconds,Contact.SpacingSeconds
	assert(W==1.5 and S==6 and Contact.AwardChance==1 and W%.5==0 and S>W)
	local function withChance(chance,run)
		local old=Contact.AwardChance;Contact.AwardChance=chance
		local ok,e=pcall(run);Contact.AwardChance=old;assert(ok,e)
	end
	test("a short continuous pet (W s) always pays one exact live Saved receipt",function()
		local b,c=fixture();c.roll=.99;begin(b,c);c:pulseUntil(W-.5);assert(c.rolls==0 and c.awards==0)
		c:pulseUntil(W);assert(c.rolls==1 and c.awards==1 and c:saved()==1,"chance 1 pays even on a high roll")
		for _=1,5 do b:reconcile()end;assert(c:saved()==1)
		local packet=c.packets[#c.packets]
		assert(packet.leaseId==c.leaseId and packet.requestGeneration==1 and packet.petId=="pip"and packet.receipt.id==c.candidate.id)
	end)
	test("a tuned-down chance still consumes the opportunity without storage or a promised award",function()
		withChance(.5,function()
			local b,c=fixture();c.roll=.9;begin(b,c);c:pulseUntil(W)
			assert(c.rolls==1 and c.awards==0 and c:saved()==0)
			c:pulseUntil(W+S-.5);assert(c.rolls==1);c:pulseUntil(W+S);assert(c.rolls==2 and c.awards==0)
		end)
	end)
	test("idle focus stationary timeout and a tap cannot earn",function()
		local b,c=fixture();begin(b,c);c.now=W;b:update()
		assert(not b.lease and c.rolls==0 and c.awards==0)
		b,c=fixture();begin(b,c);b:finish(c.leaseId);c.now=W;b:pulse(c.leaseId)
		assert(c.rolls==0 and c.awards==0)
	end)
	test("interrupted windows and rapid new contacts never carry elapsed time or reroll",function()
		local b,c=fixture();begin(b,c);c:pulseUntil(W-.5);b:finish(c.leaseId)
		c.now=W;assert(c:begin(2));c.leaseId=b.lease.id
		c:pulseUntil(2*W-.5);assert(c.rolls==0 and c.awards==0)
		c:pulseUntil(2*W);assert(c.rolls==1 and c.awards==1)
	end)
	test("restarting after a missed opportunity needs a new full window and the player spacing",function()
		withChance(.5,function()
			local b,c=fixture();c.roll=.9;begin(b,c);c:pulseUntil(W);assert(c.rolls==1)
			b:finish(c.leaseId);c.now=W+.5;assert(c:begin(2));c.leaseId=b.lease.id
			local at=math.max(W+.5+W,W+S)
			c:pulseUntil(at-.5);assert(c.rolls==1);c:pulseUntil(at);assert(c.rolls==2)
		end)
	end)
	test("awards are spaced S seconds apart while contact continues",function()
		local b,c=fixture();begin(b,c);c:pulseUntil(W);assert(c.awards==1 and c:saved()==1)
		c:pulseUntil(W+S-.5);assert(c.awards==1);c:pulseUntil(W+S);assert(c.awards==2 and c:saved()==2)
	end)
	test("stale cross-player and replaced lease ids cannot extend a new contact",function()
		local a,ca=fixture("a");local b,cb=fixture("b");begin(a,ca);begin(b,cb)
		cb.now=.5;assert(not b:pulse(ca.leaseId)and cb.rolls==0)
		local old=cb.leaseId;b:finish(old);cb.now=1;assert(cb:begin(2));cb.leaseId=b.lease.id
		assert(not b:finish(old));cb.now=1.5;assert(not b:pulse(old));cb.now=2.1;b:update();assert(not b.lease)
	end)
	test("duplicate begin reuses grant without refreshing its continuity clock",function()
		local b,c=fixture();begin(b,c);local id=c.leaseId;c.now=.5
		assert(c:begin(1)and b.lease.id==id and b.lease.windowStart==0)
		c.now=1.1;assert(not c:begin(1)and not b.lease and c.rolls==0)
	end)
	test("room ownership pet root generation death movement conflict and epoch invalidate contact",function()
		for _,mutate in ipairs({function(s)s.mode="Board"end,function(s)s.owned=false end,function(s)s.petId="wick"end,
			function(s)s.root={}end,function(s)s.character={}end,function(s)s.alive=false end,function(s)s.epoch=2 end,
			function(s)s.position=Vector3.new(3,7,0)end,function(s)s.position=Vector3.new(0,10,0)end,
			function(s)s.conflict=true end,function(s)s.ready=false;s.status="SessionLost"end})do
			local b,c,s=fixture();begin(b,c);c:pulseUntil(W-1);mutate(s);b:update()
			assert(not b.lease and c.rolls==0 and c.awards==0)
		end
	end)
	test("forged payload and unreachable anchor do no RNG or storage work",function()
		local b,c=fixture()
		assert(not b:begin({requestGeneration=1,petId="pip",amount=1})and not c:begin(1,"wick"))
		c.now=1;c.anchor=Vector3.new(8,7,0);assert(not c:begin(2)and c.awards==0 and c.rolls==0)
	end)
	test("same held context may receive retry or renew proof once but cannot draw while saving",function()
		local b,c=fixture();c.pending=true;begin(b,c);c:pulseUntil(W)
		assert(c.awards==1 and c:saved()==0 and b.issued)
		c:pulseUntil(W+2);assert(c.rolls==1 and c.awards==1);c:complete();assert(c:saved()==1)
		local at=math.max(W+2+W,W+S)
		c:pulseUntil(at-.5);assert(c.rolls==1);c:pulseUntil(at);assert(c.rolls==2)
	end)
	test("QA Q2.7: letting go while the commit lands still shows its glyph once; a replaced pet or a stale end never does",function()
		for _,case in ipairs({"same","replace","stale"})do
			local b,c,s=fixture();c.pending=true;begin(b,c);c:pulseUntil(W)
			b:finish(c.leaseId);c.now=W+.5
			if case=="replace"then s.petId="wick"end
			if case=="stale"then c.now=W+Contact.LateSavedSeconds+.5 end
			c:complete();b:reconcile();b:reconcile()
			local want=if case=="same"then 1 else 0
			assert(c:saved()==want and not b.issued and c.awards==1,case)
			if want==1 then local p=c.packets[#c.packets];assert(p.leaseId==c.leaseId and p.receipt.id==c.candidate.id)end
		end
	end)
	test("proved noncommit expiry clears broker ownership without a stranded retry or immediate reroll",function()
		local b,c,s=fixture();c.pending=true;begin(b,c);c:pulseUntil(W);c:pulseUntil(W+1)
		s.pendingId=nil;s.ready=true;s.status="Ready";b:reconcile()
		assert(not b.issued and c:saved()==0)
		local at=math.max(W+1+W,W+S)
		c:pulseUntil(at-.5);assert(c.rolls==1);c:pulseUntil(at);assert(c.rolls==2)
	end)
	test("cap mute and reduced effects are independent, capped draws stop and the cap is said",function()
		local b,c,s=fixture();s.muted=true;s.reduced=true;begin(b,c);c:pulseUntil(W)
		assert(c:saved()==1);s.capReached=true;c:pulseUntil(W+.5)
		assert(not b.lease and c.rolls==1 and c.awards==1)
		local last=c.packets[#c.packets];assert(last.granted==false and last.reason=="DailyCap")
	end)
	test("destroy cancels display and future work while retained ledger work belongs elsewhere",function()
		local b,c=fixture();c.pending=true;begin(b,c);c:pulseUntil(W);b:destroy();c:complete()
		assert(c:saved()==0 and not b:begin({requestGeneration=2,petId="pip"})and not b:pulse(c.leaseId))
	end)
	test("wrong ids and early-rate pulses are rejected before any state read or reconciliation",function()
		local b,c=fixture();begin(b,c);local reads=c.reads;c.now=.1
		assert(not b:pulse("wrong-player-id")and not b:pulse(c.leaseId)and c.reads==reads)
		c.now=.5;assert(b:pulse(c.leaseId)and c.reads>reads)
	end)
	test("unrelated pending or busy operations cannot preserve contact or emit a Saved popup",function()
		for _,otherPending in ipairs({false,true})do
			local b,c,s=fixture();c.pending=true;begin(b,c);c:pulseUntil(W)
			s.lastPetAward={id=c.candidate.id,sequence=c.candidate.sequence,day="20",petId="pip"}
			s.pendingId=if otherPending then "different-operation"else nil;s.busy=true;s.ready=false
			b:reconcile();assert(c:saved()==0);b:update();assert(not b.lease)
			s.busy=false;s.pendingId=nil;s.ready=true;b:reconcile();assert(c:saved()==0)
		end
	end)
	return{passed=#cases,cases=cases,persistentWrites=false,evidence="pure server contact continuity and live receipt broker; not proof of human touch"}
end
