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
	test("twelve continuous server seconds produce one roll and exact live Saved receipt",function()
		local b,c=fixture();begin(b,c);c:pulseUntil(11.5);assert(c.rolls==0 and c.awards==0)
		c:pulseUntil(12);assert(c.rolls==1 and c.awards==1 and c:saved()==1)
		for _=1,5 do b:reconcile()end;assert(c:saved()==1)
		local packet=c.packets[#c.packets]
		assert(packet.leaseId==c.leaseId and packet.requestGeneration==1 and packet.petId=="pip"and packet.receipt.id==c.candidate.id)
	end)
	test("negative outcome consumes opportunity without storage or a promised award",function()
		local b,c=fixture();c.roll=.9;begin(b,c);c:pulseUntil(12)
		assert(c.rolls==1 and c.awards==0 and c:saved()==0)
		c:pulseUntil(23.5);assert(c.rolls==1);c:pulseUntil(24);assert(c.rolls==2 and c.awards==0)
	end)
	test("idle focus stationary timeout and a tap cannot earn",function()
		local b,c=fixture();begin(b,c);c.now=12;b:update()
		assert(not b.lease and c.rolls==0 and c.awards==0)
		b,c=fixture();begin(b,c);b:finish(c.leaseId);c.now=12;b:pulse(c.leaseId)
		assert(c.rolls==0 and c.awards==0)
	end)
	test("interrupted windows and rapid new contacts never carry elapsed time or reroll",function()
		local b,c=fixture();begin(b,c);c:pulseUntil(11.5);b:finish(c.leaseId)
		c.now=12;assert(c:begin(2));c.leaseId=b.lease.id
		c:pulseUntil(23.5);assert(c.rolls==0 and c.awards==0)
		c:pulseUntil(24);assert(c.rolls==1 and c.awards==1)
	end)
	test("restarting after a missed opportunity still requires a new full twelve seconds",function()
		local b,c=fixture();c.roll=.9;begin(b,c);c:pulseUntil(12);assert(c.rolls==1)
		b:finish(c.leaseId);c.now=12.5;assert(c:begin(2));c.leaseId=b.lease.id
		c:pulseUntil(24);assert(c.rolls==1);c:pulseUntil(24.5);assert(c.rolls==2)
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
			local b,c,s=fixture();begin(b,c);c:pulseUntil(5);mutate(s);b:update()
			assert(not b.lease and c.rolls==0 and c.awards==0)
		end
	end)
	test("forged payload and unreachable anchor do no RNG or storage work",function()
		local b,c=fixture()
		assert(not b:begin({requestGeneration=1,petId="pip",amount=1})and not c:begin(1,"wick"))
		c.now=1;c.anchor=Vector3.new(8,7,0);assert(not c:begin(2)and c.awards==0 and c.rolls==0)
	end)
	test("same held context may receive retry or renew proof once but cannot draw while saving",function()
		local b,c=fixture();c.pending=true;begin(b,c);c:pulseUntil(12)
		assert(c.awards==1 and c:saved()==0 and b.issued)
		c:pulseUntil(14);assert(c.rolls==1 and c.awards==1);c:complete();assert(c:saved()==1)
		c:pulseUntil(25.5);assert(c.rolls==1);c:pulseUntil(26);assert(c.rolls==2)
	end)
	test("end or replacement while a commit is pending prevents any later glyph",function()
		for _,replace in ipairs({false,true})do
			local b,c,s=fixture();c.pending=true;begin(b,c);c:pulseUntil(12)
			b:finish(c.leaseId);c.now=12.5
			if replace then s.petId="wick"end
			c:complete();b:reconcile();assert(c:saved()==0 and not b.issued and c.awards==1)
		end
	end)
	test("proved noncommit expiry clears broker ownership without a stranded retry or immediate reroll",function()
		local b,c,s=fixture();c.pending=true;begin(b,c);c:pulseUntil(12);c:pulseUntil(13)
		s.pendingId=nil;s.ready=true;s.status="Ready";b:reconcile()
		assert(not b.issued and c:saved()==0);c:pulseUntil(24.5);assert(c.rolls==1)
	end)
	test("cap mute and reduced effects are independent and capped draws stop",function()
		local b,c,s=fixture();s.muted=true;s.reduced=true;begin(b,c);c:pulseUntil(12)
		assert(c:saved()==1);s.capReached=true;c:pulseUntil(12.5)
		assert(not b.lease and c.rolls==1 and c.awards==1)
	end)
	test("destroy cancels display and future work while retained ledger work belongs elsewhere",function()
		local b,c=fixture();c.pending=true;begin(b,c);c:pulseUntil(12);b:destroy();c:complete()
		assert(c:saved()==0 and not b:begin({requestGeneration=2,petId="pip"})and not b:pulse(c.leaseId))
	end)
	test("wrong ids and early-rate pulses are rejected before any state read or reconciliation",function()
		local b,c=fixture();begin(b,c);local reads=c.reads;c.now=.1
		assert(not b:pulse("wrong-player-id")and not b:pulse(c.leaseId)and c.reads==reads)
		c.now=.5;assert(b:pulse(c.leaseId)and c.reads>reads)
	end)
	test("unrelated pending or busy operations cannot preserve contact or emit a Saved popup",function()
		for _,otherPending in ipairs({false,true})do
			local b,c,s=fixture();c.pending=true;begin(b,c);c:pulseUntil(12)
			s.lastPetAward={id=c.candidate.id,sequence=c.candidate.sequence,day="20",petId="pip"}
			s.pendingId=if otherPending then "different-operation"else nil;s.busy=true;s.ready=false
			b:reconcile();assert(c:saved()==0);b:update();assert(not b.lease)
			s.busy=false;s.pendingId=nil;s.ready=true;b:reconcile();assert(c:saved()==0)
		end
	end)
	return{passed=#cases,cases=cases,persistentWrites=false,evidence="pure server contact continuity and live receipt broker; not proof of human touch"}
end
