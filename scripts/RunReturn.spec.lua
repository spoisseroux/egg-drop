-- Calls the same server entry/retry API used by the host, with authoritative state.
return function(server)
	local Return = require(server.RunReturn)
	local cases = {}
	local function test(name, run) run(); table.insert(cases,name) end
	local function fixture()
		local board={mode="Room",runSequence=7,field={phase="Complete"},round={over=true},
			sim={preset="Meadow",drops=24,pile={1,2},queue={3,4}},playTime=90,
			nursery={status="Ready",state={lastRunReward={sequence=7,total=8}}},
			earnedPayout={sequence=7,saved=true},initializations=0}
		local function initialize(target,preset)
			assert(target==board and preset=="Meadow")
			target.initializations+=1;target.runSequence+=1
			target.sim={preset=preset,drops=0,pile={},queue={5,6}}
			target.field={phase="Playing"};target.round={over=false};target.earnedPayout=nil
		end
		return board,initialize
	end
	for _,total in ipairs({0,8})do
		test("matching saved "..total.." return initializes once and rejects old retry",function()
			local b,reset=fixture();b.nursery.state.lastRunReward.total=total
			assert(Return.enter(b,true,true,reset));b.mode="Board"
			assert(b.runSequence==8 and b.sim.drops==0 and b.initializations==1)
			assert(b.nursery.state.lastRunReward.sequence==7 and b.nursery.state.lastRunReward.total==total)
			assert(not Return.enter(b,true,true,reset) and not Return.retry(b,true,true,7,reset))
			assert(b.initializations==1)
		end)
	end
	test("live and settling outings retain exact simulation queue pile and elapsed time",function()
		for _,phase in ipairs({"Playing","Settling"})do
			local b,reset=fixture();b.field.phase=phase;b.round.over=false;b.sim.drops=7
			local sim,pile,queue=b.sim,b.sim.pile,b.sim.queue
			assert(not Return.enter(b,true,true,reset));b.mode="Board"
			assert(not Return.retry(b,true,true,7,reset))
			assert(b.sim==sim and b.sim.pile==pile and b.sim.queue==queue and b.playTime==90 and b.runSequence==7)
		end
	end)
	local blocked={
		{"closing",function(b)b.closing=true end},
		{"nursery host busy",function(b)b.nurseryBusy=true end},
		{"handle busy",function(b)b.nursery.busy=true end},
		{"pending write",function(b)b.nursery.pending={id="same-operation"}end},
		{"retrying handle",function(b)b.nursery.status="Retrying"end},
		{"payout pending",function(b)b.payoutPending=true end},
		{"unacked hatch",function(b)b.nursery.state.lastHatch={id="unchanged-hatch"}end},
		{"missing earned receipt",function(b)b.earnedPayout=nil end},
		{"unsaved earned receipt",function(b)b.earnedPayout.saved=false end},
		{"stale earned sequence",function(b)b.earnedPayout.sequence=6 end},
		{"missing durable receipt",function(b)b.nursery.state.lastRunReward=nil end},
		{"stale durable sequence",function(b)b.nursery.state.lastRunReward.sequence=6 end},
	}
	for _,entry in ipairs(blocked)do
		test(entry[1].." preserves state on return and explicit retry",function()
			local b,reset=fixture();entry[2](b);local sim=b.sim
			assert(not Return.enter(b,true,true,reset));b.mode="Board"
			assert(not Return.retry(b,true,true,7,reset))
			assert(b.sim==sim and b.runSequence==7 and b.initializations==0)
		end)
	end
	test("unusable profile cannot start on either route",function()
		local b,reset=fixture();assert(not Return.enter(b,false,true,reset));b.mode="Board"
		assert(not Return.retry(b,false,true,7,reset) and b.initializations==0)
	end)
	test("starter acknowledgment admits first field without a field receipt",function()
		local b,reset=fixture();b.field=nil;b.earnedPayout=nil;b.nursery.state.lastRunReward=nil
		b.nursery.state.lastHatch={id="starter"}
		assert(not Return.enter(b,true,true,reset));b.nursery.state.lastHatch=nil
		assert(Return.enter(b,true,true,reset) and b.initializations==1)
	end)
	test("welcome overflow retry survives without Pip or field receipt",function()
		local b,reset=fixture();b.field=nil;b.earnedPayout=nil;b.nursery.state.lastRunReward=nil
		assert(not Return.enter(b,true,false,reset));b.mode="Board"
		assert(Return.retry(b,true,false,7,reset) and b.initializations==1)
		assert(not Return.retry(b,true,false,7,reset))
	end)
	test("retry requires the sequence captured at intent, rejects malformed and stale packets",function()
		local b,reset=fixture();b.mode="Board"
		for _,seq in ipairs({false,"7",6,8,7.5,0,math.huge,0/0})do
			assert(not Return.retry(b,true,true,seq,reset))
		end
		assert(not Return.retry(b,true,true,nil,reset))
		assert(Return.retry(b,true,true,7,reset));assert(not Return.retry(b,true,true,7,reset))
		assert(b.initializations==1)
	end)
	test("save completes after return without a background reset; next intentional return starts",function()
		local b,reset=fixture();b.payoutPending=true;b.earnedPayout.saved=false
		assert(not Return.enter(b,true,true,reset));b.mode="Board"
		b.payoutPending=false;b.earnedPayout.saved=true
		assert(b.runSequence==7 and b.initializations==0)
		b.mode="Room";assert(Return.enter(b,true,true,reset) and b.initializations==1)
	end)
	test("save-before-return and ack-before-return permit only the current intentional entry",function()
		local b,reset=fixture();b.nursery.state.lastHatch={id="same-result"}
		assert(not Return.enter(b,true,true,reset));b.mode="Board"
		b.nursery.state.lastHatch=nil;assert(b.initializations==0)
		b.mode="Room";assert(Return.enter(b,true,true,reset));b.mode="Board"
		assert(not Return.retry(b,true,true,7,reset) and b.initializations==1)
	end)
	return {passed=#cases,cases=cases,evidence="production server transition API with authoritative state doubles"}
end
