-- Pet Park Play date (BUILD-PLAN 2026-11-13, slice K1, architect change 4): optional additive
-- `playDate` on the v11 hatching save (valid when missing, no version bump, no new
-- Lifetime.Counters name), stats.parkGames += 1 per finished activity, +4 Stars once a day at 3,
-- written through HatchProgress.transact with a day-keyed signature. Isolated adapters only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.PlayDate)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local L=require(server.LifetimeState)
	local P=require(server.PlayDateState)
	local Daily=require(game:GetService("ReplicatedStorage").Shared.DailyContracts)
	local Offset=require(game:GetService("ReplicatedStorage").Shared.EggCatalog).DayOffsetSeconds
	-- 20 s before the 05:00 UTC day roll after 1700000000 (a lease lasts 90 s, so no renew is needed).
	local BeforeRoll=(tonumber(Daily.dayOf(1700000000))+1)*86400-Offset-20
	local cases={}
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function test(name,run)run();table.insert(cases,name)end
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0,writes=0,failNext=nil}
		local adapter={
			now=function()return c.now end,
			guid=function()c.serial+=1;return "op"..c.serial end,
			random=function()return .1 end,
			wait=function()end,
			update=function(key,transform)
				c.writes+=1
				if c.failNext=="before"then c.failNext=nil;error("store down")end
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
				if c.failNext=="after"then c.failNext=nil;error("response lost")end
				return copy(value)
			end,
		}
		if seed then db.player_1=seed end
		local h=H.load(1,{rank=1},adapter)
		return h,db,c
	end
	local function play(h,id,count)return H.parkPlay(h,id,count or 1)end

	test("missing playDate is valid; a malformed one is dropped at load, never a failed load",function()
		local h,db=fixture()
		assert(h.status=="Ready"and h.state.playDate==nil and H.valid(h.state))
		local public=H.public(h).playDate
		assert(public.count==0 and public.target==3 and public.reward==4 and public.done==false and public.day==Daily.dayOf(1700000000))
		assert(table.find(L.Counters,"parkGames")and #L.Counters==13,"no new Lifetime.Counters name")
		local seed=copy(db.player_1);seed.hatching.playDate={day=5,count="x"};seed.hatching.lease={token="",expiresAt=0}
		local again=fixture(seed)
		assert(again.status=="Ready"and again.state.playDate==nil,"malformed playDate sanitised")
		local extra=copy(db.player_1);extra.hatching.playDate={day=Daily.dayOf(1700000000),count=1,later="kept by a newer build"};extra.hatching.lease={token="",expiresAt=0}
		local third=fixture(extra)
		assert(third.status=="Ready"and third.state.playDate.count==1,"valid playDate survives load")
		assert(P.valid({playDate={day="1",count=2,future=true}}),"validator tolerates unknown keys")
		assert(not P.valid({playDate={day="1",count=4}})and not P.valid({playDate={day="01",count=1}})and not P.valid({playDate="x"}))
	end)

	test("three finished activities pay +4 Stars once; parkGames counts every one",function()
		local h,db=fixture()
		local wallet=h.state.nectar
		assert(play(h,"a1"));assert(play(h,"a2"))
		assert(h.state.nectar==wallet and h.state.playDate.count==2 and h.state.stats.parkGames==2)
		assert(play(h,"a3"))
		assert(h.state.nectar==wallet+4 and h.state.playDate.count==3 and H.playDateDone(h))
		assert(h.state.stats.starsEarned>=4,"Play date Stars are earned Stars")
		assert(play(h,"a4"));assert(play(h,"a5",3))
		assert(h.state.nectar==wallet+4,"paid once a day")
		assert(h.state.playDate.count==3 and h.state.stats.parkGames==7)
		assert(db.player_1.hatching.stats.parkGames==7 and db.player_1.hatching.playDate.op=="a5")
		local public=H.public(h)
		assert(public.playDate.count==3 and public.playDate.done and public.stats.parkGames==nil,"public hides parkGames, shows playDate")
	end)

	test("next day resets; a batch that crosses 3 pays once; repeats are idempotent",function()
		local h,_,c=fixture(nil,BeforeRoll)
		local wallet=h.state.nectar
		assert(play(h,"d1",2))
		c.now+=40;assert(H.renew(h))
		assert(H.public(h).playDate.count==0,"a new day shows 0")
		assert(play(h,"d2",5))
		assert(h.state.nectar==wallet+4 and h.state.playDate.count==3 and h.state.stats.parkGames==7)
		local ok,reason=play(h,"d2",5)
		assert(ok and reason=="AlreadySaved"and h.state.stats.parkGames==7,"same op never applies twice")
		local bad=table.pack(H.parkPlay(h,"",1));assert(not bad[1]and bad[2]=="InvalidParkPlay")
		bad=table.pack(H.parkPlay(h,"x",0));assert(not bad[1]and bad[2]=="InvalidParkPlay")
		bad=table.pack(H.parkPlay(h,"x",1.5));assert(not bad[1]and bad[2]=="InvalidParkPlay")
	end)

	test("transact signature is park:<day>; an ambiguous write retries without double counting",function()
		local h,db,c=fixture()
		local day=Daily.dayOf(c.now)
		c.failNext="after" -- the write commits, the response is lost
		local ok,reason=play(h,"amb",3)
		assert(not ok and reason=="Retrying"and h.status=="Retrying")
		assert(h.pending.signature=="park:"..day and h.pending.id=="amb")
		assert(not H.parkCommitted(h,"amb"),"the local state has no proof yet")
		local busy=table.pack(play(h,"other",1));assert(not busy[1]and busy[2]=="Pending","a second park write waits for the pending one")
		assert(H.retry(h))
		assert(H.parkCommitted(h,"amb")and h.state.stats.parkGames==3 and db.player_1.hatching.stats.parkGames==3)
		assert(h.state.playDate.count==3)
		-- A write that failed before reaching the store applies once on retry.
		local h2,db2,c2=fixture()
		c2.failNext="before"
		assert(not play(h2,"lost",1)and h2.pending and h2.pending.signature=="park:"..Daily.dayOf(c2.now))
		assert(H.retry(h2)and H.parkCommitted(h2,"lost")and db2.player_1.hatching.stats.parkGames==1)
	end)

	test("a write that settles after the day rolls counts parkGames but not the new day's Play date",function()
		local h,db,c=fixture(nil,BeforeRoll)
		local wallet=h.state.nectar
		assert(play(h,"y1",2))
		c.failNext="before"
		assert(not play(h,"y2",1))
		c.now+=40
		assert(H.retry(h))
		assert(h.state.stats.parkGames==3 and h.state.nectar==wallet,"no Stars for an expired day")
		assert(h.state.playDate.day==Daily.dayOf(c.now)and h.state.playDate.count==0 and h.state.playDate.op=="y2")
		assert(db.player_1.hatching.playDate.op=="y2"and H.valid(h.state))
	end)

	return {passed=#cases,cases=cases}
end
