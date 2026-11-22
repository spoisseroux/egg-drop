-- Garden Dash prizes through the real save transaction (V3-DASH-BUILD-PLAN-2026-11-22, S6): exactly once under retry,
-- replay, a second session, midnight, rollback and shutdown; never beside another operation.
-- Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DashPrize)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local S=require(server.DashState)
	local Close=require(server.CloseProgress)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function fixture(db,c)
		db=db or {};c=c or {now=1700000000,serial=0}
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,random=function()return .1 end,wait=function()end,
			update=function(key,transform)
				if c.failBefore then c.failBefore=false;error("fixture before commit")end
				if c.during then local run=c.during;c.during=nil;run()end
				local value=transform(copy(db[key]))
				if c.replay then c.replay=false;value=transform(copy(db[key]))end
				if value then db[key]=copy(value)end
				if c.failAfter then c.failAfter=false;error("fixture after commit")end
				return copy(value)
			end}
		return H.load(1,{rank=1},adapter),db,c
	end
	local function race(place,more)
		local r={kind="race",mode="fun",place=place or 1,us=35000000,inputs=12,seed=7,prize=true}
		for key,value in pairs(more or {})do r[key]=value end
		return r
	end
	local function saved(db)return db.player_1.hatching end
	test("one flight: 2 Stars, the ribbon, the receipt and starsEarned, in one revision",function()
		local h,db=fixture();local wallet,revision=h.state.nectar,h.state.revision;local earned=h.state.stats.starsEarned or 0
		assert(H.dashResults(h,"f1",{race(2)})and saved(db).nectar==wallet+2 and h.state.revision==revision+1)
		assert(saved(db).dash.ribbons.silver==1 and H.dashCommitted(h,"f1")and H.dashReceipt(h,"f1").balance==wallet+2)
		assert((h.state.stats.starsEarned or 0)==earned+2 and H.valid(h.state))
	end)
	test("the 2x pass never counts: a boosted handle still gets 2",function()
		local h=fixture();h.passMultiplier=2;local wallet=h.state.nectar;assert(H.dashResults(h,"f",{race()})and h.state.nectar==wallet+2)
	end)
	test("a replay of a saved flight pays nothing, on this handle and after other saves; another content under its id never pays",function()
		local h,db=fixture();assert(H.dashResults(h,"f",{race()}));local wallet=h.state.nectar
		for _=1,3 do local ok,why=H.dashResults(h,"f",{race()});assert(ok and why=="AlreadySaved")end
		assert(H.parkPlay(h,"p",1,"pip"));H.dashResults(h,"f",{race(2)});assert(saved(db).nectar==wallet and saved(db).dash.paid==1)
	end)
	test("a write that failed before it landed is retried to one payment; one that failed after it landed is found paid",function()
		for _,when in ipairs({"failBefore","failAfter"})do
			local h,db,c=fixture();local wallet=h.state.nectar;c[when]=true
			local ok,why=H.dashResults(h,"f",{race()});assert(not ok and why=="Retrying"and h.pending)
			-- nothing else can write meanwhile, and the same flight resumes rather than starting again
			assert(select(2,H.parkPlay(h,"p",1,"pip"))=="Pending"and select(2,H.dashResults(h,"other",{race()}))=="Pending")
			if when=="failBefore"then assert(H.retry(h))else assert(H.dashResults(h,"f",{race()}))end
			assert(saved(db).nectar==wallet+2 and saved(db).dash.paid==1 and h.pending==nil and h.status=="Ready")
			assert(select(2,H.dashResults(h,"f",{race()}))=="AlreadySaved"and saved(db).nectar==wallet+2)
		end
	end)
	test("the lease renewal finds an ambiguous flight paid",function()
		local h,db,c=fixture();local wallet=h.state.nectar;c.failAfter=true;H.dashResults(h,"f",{race()})
		H.renew(h);assert(h.pending==nil and H.dashCommitted(h,"f")and saved(db).nectar==wallet+2)
	end)
	test("an UpdateAsync callback run twice pays once",function()
		local h,db,c=fixture();local wallet=h.state.nectar;c.replay=true;assert(H.dashResults(h,"f",{race()})and saved(db).nectar==wallet+2)
	end)
	test("the results are copied: changing the host's table mid-write changes nothing",function()
		local h,db,c=fixture();local list={race(1)};c.failBefore=true;H.dashResults(h,"f",list);list[1].place=5;list[2]=race()
		assert(H.retry(h)and saved(db).dash.ribbons.gold==1 and saved(db).dash.paid==1)
	end)
	test("two sessions: the second is locked out; after it takes over, the first can never write, and nothing is paid twice",function()
		local h,db,c=fixture();local wallet=h.state.nectar
		local second=fixture(db,c);assert(second.status=="Locked"and not H.dashResults(second,"f",{race()}))
		c.failBefore=true;H.dashResults(h,"f",{race()})
		c.now+=200;second=fixture(db,c);assert(second.status=="Ready")
		assert(H.dashResults(second,"f",{race()})and saved(db).nectar==wallet+2)
		local ok=H.retry(h);assert(not ok and h.status=="SessionLost"and saved(db).nectar==wallet+2 and saved(db).dash.paid==1)
		assert(not H.dashResults(h,"g",{race()}))
	end)
	test("the cap holds across sessions and servers: ten Stars a day and no more",function()
		local h,db,c=fixture();local wallet=h.state.nectar
		for i=1,3 do assert(H.dashResults(h,"a"..i,{race()}))end;H.release(h);c.now+=1
		h=fixture(db,c);assert(h.status=="Ready");for i=1,6 do assert(H.dashResults(h,"b"..i,{race()}))end
		assert(saved(db).nectar==wallet+10 and saved(db).dash.ribbons.gold==9)
	end)
	test("midnight between the race and the write: it counts on the day it commits; an early clock never starts the day again",function()
		local h,db,c=fixture();for i=1,5 do H.dashResults(h,"a"..i,{race()})end;local wallet=h.state.nectar
		c.failBefore=true;H.dashResults(h,"late",{race()});c.now+=86400;h.state.lease.expiresAt=c.now+60;db.player_1.hatching.lease.expiresAt=c.now+60
		assert(H.retry(h)and h.state.nectar==wallet+2 and h.state.dash.paid==1)
		c.now-=2*86400;db.player_1.hatching.lease.expiresAt=c.now+60;for i=1,6 do H.dashResults(h,"b"..i,{race()})end
		assert(h.state.nectar==wallet+10 and h.state.dash.paid==5)
	end)
	test("malformed save data never fails a load or another write, and pays nothing that day",function()
		for _,bad in ipairs({"x",5,false,{paid=0},{day="x",paid=0},{day="19680",paid=99},{ribbons={gold="x"}}})do
			local _,db,c=fixture();db.player_1.hatching.dash=bad;db.player_1.hatching.lease={token="",expiresAt=0}
			local h=fixture(db,c);assert(h.status=="Ready"and H.parkPlay(h,"p",1,"pip"));local wallet=h.state.nectar
			assert(H.dashResults(h,"f",{race(3)})and h.state.nectar==wallet and h.state.dash.ribbons.bronze>=1)
		end
	end)
	test("a full wallet saves the ribbon and pays 0",function()
		local _,db,c=fixture();db.player_1.hatching.nectar=1000000000;db.player_1.hatching.lease={token="",expiresAt=0}
		local h=fixture(db,c);assert(H.dashResults(h,"f",{race()})and h.state.nectar==1000000000 and H.dashReceipt(h,"f").stars==0)
	end)
	test("refused before any write: bad ids, bad results, a save that is not ours",function()
		local h,db=fixture();local before=copy(saved(db))
		for _,case in ipairs({{"",{race()}},{string.rep("x",81),{race()}},{5,{race()}},{"f",{}},{"f","x"},{"f",{race(9)}}})do assert(select(2,H.dashResults(h,case[1],case[2]))=="InvalidDash")end
		h.status="Temporary";assert(not H.dashResults(h,"f",{race()}))
		assert(saved(db).revision==before.revision and saved(db).dash==nil)
	end)
	test("closing: the drain writes what is left after pending and payout, before the release; it can never hold the lease",function()
		local function options(dash)local clock=0;return{now=function()return clock end,wait=function(dt)clock+=dt end,timeout=20,dash=dash}end
		local h,db=fixture();local wallet=h.state.nectar;local done=false
		assert(Close.drain(H,h,nil,options(function()if not done then done=H.dashResults(h,"f",{race()})end;return done end)))
		assert(saved(db).nectar==wallet+2 and saved(db).lease.expiresAt==0)
		local c;h,db,c=fixture();c.failAfter=true;done=false;local calls=0
		assert(Close.drain(H,h,nil,options(function()calls+=1;if H.dashCommitted(h,"f")then return true end;H.dashResults(h,"f",{race()});return false end)))
		assert(saved(db).dash.paid==1 and saved(db).lease.expiresAt==0 and calls==2)
		h,db=fixture();local ok,why=Close.drain(H,h,nil,options(function()return false end));assert(not ok and why=="CloseTimeout")
		h,db=fixture();assert(Close.drain(H,h,nil,options(nil))and saved(db).lease.expiresAt==0)
	end)
	return{passed=#cases,cases=cases}
end
