-- Garden finds in the save transaction (V3-FINDS-BUILD-PLAN-2026-11-22, S9): Hatching.findClaim pays exactly once under
-- retry, replay and an ambiguous write; AlreadySaved; DailyLimit and NoPet write nothing; the snapshot carries `finds`
-- only while the switch is on. Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.FindsClaim)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Http=game:GetService("HttpService")
	local Finds=require(Shared.Finds)
	local Daily=require(Shared.DailyContracts)
	local Eggs=require(Shared.EggCatalog)
	local H=require(server.HatchProgress)
	local Stat=require(server.StatState)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function keys(t)local out={};for k in pairs(t)do table.insert(out,tostring(k))end;table.sort(out);return table.concat(out," ")end
	local ON={flags={GardenFinds=true},studio=true}
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0,writes=0}
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,random=function()return .1 end,wait=function()end,
			update=function(key,transform)
				if c.down then error("down")end
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value);c.writes+=1 end
				if c.failAfter then c.failAfter=false;error("after commit")end
				return copy(value)
			end}
		if seed then db.player_1=seed end
		local h=H.load(1,{rank=1},adapter)
		if not seed then
			db.player_1.hatching.inventoryMask=Eggs.bit("pip");db.player_1.hatching.lease={token="",expiresAt=0}
			h=H.load(1,{rank=1},adapter)
		end
		assert(h.status=="Ready")
		return h,db,c
	end
	local function smarts(db)return Stat.xp(db.player_1.hatching,"pip","smarts")end
	local ok,problem=pcall(function()
		Finds.inject(ON)
		test("one find: Smarts XP once, the count, the proof and the receipt; a replay is AlreadySaved and writes nothing",function()
			local h,db,c=fixture()
			local good,why=H.findClaim(h,"f1","pip");assert(good and why=="Saved",why)
			local saved=db.player_1.hatching.finds;assert(saved.count==1 and saved.op=="f1")
			local xp=smarts(db);assert(xp>=Finds.XP and H.findCommitted(h,"f1")and H.findReceipt(h,"f1").xp==xp)
			local writes=c.writes
			good,why=H.findClaim(h,"f1","pip");assert(good and why=="AlreadySaved"and c.writes==writes and smarts(db)==xp)
			good,why=H.findClaim(h,"f1","blip");assert(good and why=="AlreadySaved"and smarts(db)==xp,"a replay with another pet")
			assert(not H.findCommitted(h,"f2")and H.findReceipt(h,"f2")==nil)
		end)
		test("an ambiguous write is resumed with the same frozen candidate and pays once, across midnight",function()
			local start=1700000000
			while Daily.dayOf(start)==Daily.dayOf(start+60)do start+=30 end
			local h,db,c=fixture(nil,start)
			c.failAfter=true
			local good,why=H.findClaim(h,"f1","pip");assert(not good and why=="Retrying"and h.pending and h.pending.signature=="find:f1")
			local xp=smarts(db);assert(db.player_1.hatching.finds.count==1,"landed, unproven")
			assert(select(2,H.findClaim(h,"f2","pip"))=="Pending","another find waits")
			c.now+=60;assert(Daily.dayOf(c.now)~=Daily.dayOf(start)) -- the retry comes after midnight: the frozen candidate keeps its day
			good,why=H.findClaim(h,"f1","blip");assert(good and why=="Saved",why)
			assert(smarts(db)==xp and db.player_1.hatching.finds.count==1 and H.findReceipt(h,"f1").petId=="pip")
			assert(H.retry(h)==false,"nothing left pending")
		end)
		test("a store that is down: Retrying, then Nursery.retry pays once",function()
			local h,db,c=fixture()
			c.down=true;assert(select(2,H.findClaim(h,"f1","pip"))=="Retrying"and db.player_1.hatching.finds==nil)
			c.down=false;assert(H.retry(h));assert(db.player_1.hatching.finds.count==1 and H.findCommitted(h,"f1"))
			assert(select(2,H.findClaim(h,"f1","pip"))=="AlreadySaved")
		end)
		test("twelve a day; the thirteenth is DailyLimit and writes nothing; the next day pays again",function()
			local start=1700000000
			while Daily.dayOf(start)==Daily.dayOf(start+60)do start+=30 end
			local h,db,c=fixture(nil,start)
			for i=1,12 do assert(H.findClaim(h,"f"..i,"pip"),i)end
			local xp,writes,revision=smarts(db),c.writes,db.player_1.hatching.revision
			local good,why=H.findClaim(h,"f13","pip")
			assert(not good and why=="DailyLimit"and c.writes==writes and db.player_1.hatching.revision==revision and smarts(db)==xp and h.pending==nil)
			c.now+=60;assert(H.findClaim(h,"f14","pip")and db.player_1.hatching.finds.count==1)
		end)
		test("a pet not owned is NoPet and writes nothing; bad arguments are InvalidFind",function()
			local h,db,c=fixture()
			local writes=c.writes
			assert(select(2,H.findClaim(h,"f1","blip"))=="NoPet"and c.writes==writes and db.player_1.hatching.finds==nil)
			for _,args in ipairs({{nil,"pip"},{"","pip"},{string.rep("x",81),"pip"},{"f",nil},{"f",""},{"f",5},{5,"pip"}})do
				assert(select(2,H.findClaim(h,args[1],args[2]))=="InvalidFind")
			end
			assert(c.writes==writes)
		end)
		test("the digest is short and binds the day and pet; a reused id with other content is OperationConflict",function()
			local h,db=fixture()
			assert(H.findClaim(h,"f1","pip"))
			local last=db.player_1.hatching.lastOperation;assert(last.id=="f1"and #last.digest<120 and string.find(last.digest,"find:",1,true)==1)
			-- another kind of write under the same id: the find must not pay against it
			assert(H.parkPlay(h,"p1",1,"pip"))
			assert(select(2,H.findClaim(h,"p1","pip"))=="OperationConflict"and db.player_1.hatching.finds.op=="f1")
		end)
		test("the snapshot carries finds only while on; off is the snapshot and the save of the build before",function()
			Finds.inject({flags={GardenFinds=false},studio=true})
			local h,db=fixture();local off=H.public(h);assert(off.finds==nil)
			local before=keys(off)
			Finds.inject({flags={GardenFinds=true},studio=true,on=false});assert(H.public(h).finds==nil and keys(H.public(h))==before)
			assert(H.parkPlay(h,"p1",1,"pip")and db.player_1.hatching.finds==nil,"other writes never add the field")
			Finds.inject(ON)
			local public=H.public(h);assert(public.finds and public.finds.count==0 and public.finds.limit==12 and public.finds.xp==Finds.XP)
			public.finds=nil;assert(keys(public)==before)
			assert(H.findClaim(h,"f1","pip")and H.public(h).finds.count==1)
			Finds.inject({flags={GardenFinds=false},studio=true})
			local saved=Http:JSONEncode(db.player_1.hatching.finds)
			assert(H.public(h).finds==nil and H.parkPlay(h,"p2",1,"pip")and Http:JSONEncode(db.player_1.hatching.finds)==saved,"off keeps the field as it is")
		end)
		test("a malformed saved field never fails a load and reads closed or as none",function()
			Finds.inject(ON)
			for _,odd in ipairs({"x",5,{day={}},{day="19680",count="many"},{day="nope",count=3}})do
				local _,db,c=fixture();db.player_1.hatching.finds=copy(odd);db.player_1.hatching.lease={token="",expiresAt=0}
				local h=fixture(db.player_1,c.now+200);assert(h.status=="Ready")
				local public=H.public(h);assert(public.finds and public.finds.count>=0 and public.finds.count<=12)
			end
		end)
	end)
	Finds.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
