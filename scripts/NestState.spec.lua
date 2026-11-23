-- The Sleepy Nest on the save (ONBOARDING-V3-PLAN-2026-11-23, slice C): NestState through the real HatchProgress
-- transactions. Land, claim exactly once (n == captured n, ready inside the write, op proof, receipt), not ready, clock
-- rollback, malformed fails closed, the welcome week to seven then after-week Stars, the toy Busy rule, the per-pet
-- gift, the charm rule, and the snapshot only while on. Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.NestState)(ServerScriptService.Server)
-- Offline: DASH_SPECS="NestState" python scripts/run_dash_server_specs.py <luau.exe>
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Http=game:GetService("HttpService")
	local Nest=require(Shared.Nest)
	local Onboard=require(Shared.Onboard)
	local Eggs=require(Shared.EggCatalog)
	local Toys=require(Shared.ToyCatalog)
	local H=require(server.HatchProgress)
	local State=require(server.NestState)
	local Wearables=require(server.WearableState)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function keys(t)local out={};for k in pairs(t)do table.insert(out,tostring(k))end;table.sort(out);return table.concat(out," ")end
	local ON={flags={OnboardingV3=true},studio=true}
	local START=1700000000
	local function fixture(pets,start)
		local db,c={},{now=start or START,serial=0,writes=0}
		local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,random=function()return .1 end,wait=function()end,
			update=function(key,transform)
				if c.down then error("down")end
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value);c.writes+=1 end
				if c.failAfter then c.failAfter=false;error("after commit")end
				return copy(value)
			end}
		H.load(1,{rank=1},adapter)
		db.player_1.hatching.inventoryMask=Eggs.mask(pets or {"pip"});db.player_1.hatching.nectar=500;db.player_1.hatching.lease={token="",expiresAt=0}
		local h=H.load(1,{rank=1},adapter)
		assert(h.status=="Ready",h.status)
		-- The clock moves on with the lease kept alive (as Hatching.renew does every 20 s in the game).
		c.advance=function(seconds)c.now+=seconds;db.player_1.hatching.lease.expiresAt=c.now+H.LeaseSeconds end
		c.reload=function(field)
			db.player_1.hatching.nest=copy(field);db.player_1.hatching.lease={token="",expiresAt=0}
			h=H.load(1,{rank=1},adapter);assert(h.status=="Ready","a nest field never fails a load")
			return h
		end
		return h,db,c
	end
	local function saved(db)return db.player_1.hatching end
	local function ready(c)c.advance(Nest.Seconds)end
	local ok,problem=pcall(function()
		Onboard.inject(ON)
		test("land: the first egg lands now for the pet, with its gift stored; a second land is Growing and writes nothing",function()
			local h,db,c=fixture()
			assert(H.public(h).nest==nil,"no key until the first egg lands")
			local good,why=H.nestLand(h,"l1","pip");assert(good and why=="Saved",why)
			local nest=saved(db).nest
			assert(nest.at==c.now and nest.n==0 and nest.pet=="pip"and nest.tucked==false,Http:JSONEncode(nest))
			assert(nest.gift==State.wardrobePick("hat","pip").id and nest.gift=="beanie","the Bear's cheapest common Hat")
			local public=H.public(h).nest
			for key,kind in pairs(Nest.PublicShape)do
				local value=public[key]
				assert(if kind=="integer"then type(value)=="number"and value%1==0 else type(value)==kind,key)
			end
			assert(public.readyAt==c.now+Nest.Seconds and public.left==Nest.Seconds and public.ready==false and public.egg==1 and not public.week)
			assert(public.gift.kind=="hat"and public.gift.item=="beanie"and public.gift.stars==10)
			local writes=c.writes
			good,why=H.nestLand(h,"l2","pip");assert(not good and why=="Growing"and c.writes==writes)
			for _,args in ipairs({{nil,"pip"},{"","pip"},{string.rep("x",81),"pip"},{"l",nil},{"l",""},{5,"pip"}})do
				assert(select(2,H.nestLand(h,args[1],args[2]))=="InvalidNest")
			end
			assert(c.writes==writes)
		end)
		test("not ready writes nothing; ready pays exactly once (proof, receipt, replay AlreadySaved) and lands the next egg",function()
			local h,db,c=fixture()
			assert(H.nestLand(h,"l1","pip"))
			c.advance(Nest.Seconds-1)
			local writes,stars=c.writes,saved(db).nectar
			local good,why=H.nestClaim(h,"c1","pip");assert(not good and why=="NotReady"and c.writes==writes and h.pending==nil)
			c.advance(1)
			good,why=H.nestClaim(h,"c1","pip");assert(good and why=="Saved",why)
			local s=saved(db)
			assert(s.nectar==stars+10 and Wearables.owns(s,"pip","beanie")and Wearables.equipped(s,"pip").Hat=="beanie","the hat goes on at once")
			assert(s.nest.n==1 and s.nest.at==c.now and s.nest.gift==15 and s.nest.op=="c1"and s.nest.tucked==false)
			local receipt=H.nestReceipt(h,"c1");assert(receipt.egg==1 and receipt.kind=="hat"and receipt.item=="beanie"and receipt.stars==10 and receipt.pet=="pip")
			assert(H.nestCommitted(h,"c1")and not H.nestCommitted(h,"c2")and H.nestReceipt(h,"c2")==nil)
			writes=c.writes
			good,why=H.nestClaim(h,"c1","pip");assert(good and why=="AlreadySaved"and c.writes==writes and saved(db).nectar==stars+10)
			good,why=H.nestClaim(h,"c2","pip");assert(not good and why=="NotReady","the next egg grows from now")
		end)
		test("the claim checks n == captured n inside the write; an ambiguous write resumes its frozen candidate and pays once",function()
			local h,db,c=fixture()
			assert(H.nestLand(h,"l1","pip"));ready(c)
			local writes=c.writes
			assert(select(2,H.nestClaim(h,"c0","pip",3))=="Changed"and c.writes==writes,"another egg than the one seen")
			assert(select(2,H.nestClaim(h,"c0","pip",-1))=="InvalidNest")
			c.failAfter=true
			local good,why=H.nestClaim(h,"c1","pip",0);assert(not good and why=="Retrying"and h.pending and h.pending.signature=="nestClaim:c1")
			local stars=saved(db).nectar;assert(saved(db).nest.n==1,"landed, unproven")
			assert(select(2,H.nestClaim(h,"c2","pip",0))=="Pending","another claim waits")
			assert(select(2,H.nestLand(h,"l2","pip"))=="Pending","a land waits too (transact refuses while another write is pending)")
			good,why=H.nestClaim(h,"c1","pip",0);assert(good and why=="Saved",why)
			assert(saved(db).nectar==stars and saved(db).nest.n==1 and H.retry(h)==false)
			-- A second session that saw egg 1 cannot pay egg 2 with its own op: n moved on.
			ready(c)
			assert(select(2,H.nestClaim(h,"other","pip",0))=="Changed"and saved(db).nest.n==1)
			c.down=true;assert(select(2,H.nestClaim(h,"c3","pip"))=="Retrying")
			c.down=false;assert(H.retry(h)and saved(db).nest.n==2 and H.nestCommitted(h,"c3"))
		end)
		test("clock rollback: a slightly future egg is just landed and waits; one past the slack lands again, keeping n",function()
			local h,db,c=fixture()
			assert(H.nestLand(h,"l1","pip"))
			h=c.reload({at=c.now+3600,n=2,gift=15,tucked=true,pet="pip"})
			local public=H.public(h).nest;assert(public.left==Nest.Seconds and not public.ready and public.n==2 and public.tucked)
			assert(select(2,H.nestClaim(h,"c1","pip"))=="NotReady")
			assert(select(2,H.nestLand(h,"l2","pip"))=="Growing")
			h=c.reload({at=c.now+Nest.FutureSlack+1,n=2,gift=15,pet="pip"})
			assert(H.public(h).nest==nil,"no egg until a land")
			assert(select(2,H.nestClaim(h,"c2","pip"))=="NoEgg")
			assert(H.nestLand(h,"l3","pip"));local nest=saved(db).nest
			assert(nest.at==c.now,"landed now")
			assert(nest.n==2 and nest.gift=="ball",Http:JSONEncode(nest))
		end)
		test("malformed fails closed: never a failed load, a bad n is a finished week (4 Stars, never the charm), a bad gift its row's Stars",function()
			local h,db,c=fixture()
			local k=0
			for _,odd in ipairs({"x",5,true,{n="many",at=START},{n=-1,at=START},{n=1.5,at=START},{n=0/0,at=START},{n=math.huge,at=START}})do
				h=c.reload(odd)
				local entry=State.read(saved(db),c.now)
				assert(entry.n==Nest.WeekLength,tostring(odd))
				assert(not State.charmEarned(saved(db)),"never the charm from a bad count")
			end
			h=c.reload({n="many",at=c.now-Nest.Seconds,gift="beanie",pet="pip"})
			local stars=saved(db).nectar
			assert(H.nestClaim(h,"c1","pip"));assert(saved(db).nectar==stars+Nest.AfterWeekStars and saved(db).nest.n==8)
			assert(not Wearables.owns(saved(db),"pip","beanie"),"no week gift from a bad count")
			for _,bad in ipairs({{at="soon",n=1},{at=0/0,n=1},{at={},n=1}})do
				h=c.reload(bad);assert(H.public(h).nest==nil and State.read(saved(db),c.now).n==1)
				k+=1;assert(H.nestLand(h,"land"..k,"pip")and saved(db).nest.n==1,"a fresh land keeps n")
			end
			for _,gift in ipairs({{},"nope",999,-4,"ring"})do
				h=c.reload({n=0,at=c.now-Nest.Seconds,gift=gift,pet="pip"})
				stars=saved(db).nectar
				k+=1;assert(H.nestClaim(h,"g"..k,"pip"));assert(saved(db).nectar==stars+10 and not Wearables.owns(saved(db),"pip","beanie"))
			end
			h=c.reload({n=0,at=c.now-Nest.Seconds,gift="beanie",pet="nobody"})
			stars=saved(db).nectar
			assert(H.nestClaim(h,"np","pip"));assert(saved(db).nectar==stars+10,"a bad stored pet pays the row's Stars")
			h=c.reload({n=0,at=c.now,gift=10,receipt={op=5},op={}})
			assert(State.read(saved(db),c.now).receipt==nil and State.read(saved(db),c.now).op==nil and H.nestReceipt(h,"x")==nil)
		end)
		test("the welcome week: seven fixed gifts (100 Stars, hat, toy, neck piece, charm), then 4 Stars an egg; the charm is n >= 7",function()
			local h,db,c=fixture()
			assert(H.nestLand(h,"l1","pip"))
			local start=saved(db).nectar
			local kinds={}
			for egg=1,9 do
				assert(not State.charmEarned(saved(db))==(egg<=7),egg)
				ready(c)
				local good,why=H.nestClaim(h,"week"..egg,"pip");assert(good,why)
				local receipt=H.nestReceipt(h,"week"..egg);assert(receipt.egg==egg)
				table.insert(kinds,receipt.kind..(if receipt.item then ":"..receipt.item else "")..":"..receipt.stars)
			end
			assert(table.concat(kinds," ")=="hat:beanie:10 stars:15 toy:ball:5 stars:15 neck:beads:10 stars:20 charm:nest:25 stars:4 stars:4",table.concat(kinds," "))
			local s=saved(db)
			assert(s.nectar==start+100+8 and Toys.owns(s.toyUnlocks,"ball")and s.petToys.pip=="ball"and Wearables.owns(s,"pip","beads"))
			assert(State.charmEarned(s)and H.public(h).nest.week and H.public(h).nest.gift.stars==Nest.AfterWeekStars)
		end)
		test("an item already owned shows and pays its Stars (at land, and when bought before the claim); every toy owned is 20",function()
			local h,db,c=fixture()
			local s=saved(db)
			s.petWearables={pip={owned={"beanie"},equipped={}}};h=c.reload(nil)
			assert(H.nestLand(h,"l1","pip")and saved(db).nest.gift==10+20,"owned at land: 10 + min(40, 20)")
			assert(H.public(h).nest.gift.kind=="stars"and H.public(h).nest.gift.stars==30)
			local h2,db2,c2=fixture()
			assert(H.nestLand(h2,"l1","pip"));assert(H.buyWearable(h2,"buy1","pip","beanie",40,false))
			assert(H.public(h2).nest.gift.kind=="stars"and H.public(h2).nest.gift.stars==30,"the label follows ownership")
			local stars=saved(db2).nectar;ready(c2)
			assert(H.nestClaim(h2,"c1","pip"));assert(saved(db2).nectar==stars+30 and #saved(db2).petWearables.pip.owned==1,"never a second copy")
			local h3,db3,c3=fixture()
			local all={};for _,id in ipairs(Toys.Pools[Toys.PoolVersion])do all[id]=true end
			saved(db3).toyUnlocks=all;saved(db3).nest={at=c3.now,n=2,gift="x",pet="pip"};h3=c3.reload(saved(db3).nest)
			assert(H.nestLand(h3,"l1","pip")==false)
			h3=c3.reload({at=c3.now+Nest.FutureSlack*2,n=2})
			assert(H.nestLand(h3,"l2","pip")and saved(db3).nest.gift==5+Nest.ToyOwnedStars)
		end)
		test("the toy gift refuses Busy while a toy purchase is reserved or its result waits, and never grants then",function()
			local h,db,c=fixture()
			assert(H.nestLand(h,"l1","pip"))
			for egg=1,2 do ready(c);assert(H.nestClaim(h,"c"..egg,"pip"))end
			assert(saved(db).nest.gift=="ball")
			ready(c)
			for _,field in ipairs({"toyReservation","pendingToyResult"})do
				local state=copy(saved(db));state[field]={id="x"}
				local before=Http:JSONEncode(state)
				local good,why=State.claim(state,{id="t1",n=2,petId="pip"},c.now)
				assert(not good and why=="Busy"and Http:JSONEncode(state)==before,field)
				h.state[field]={id="x"}
				local writes=c.writes
				assert(select(2,H.nestClaim(h,"t"..field,"pip"))=="Busy"and c.writes==writes)
				h.state[field]=nil
			end
			assert(H.nestClaim(h,"t3","pip")and Toys.owns(saved(db).toyUnlocks,"ball"))
		end)
		test("hat and neck gifts are per pet: stored at land, given to that pet; a rig with none pays Stars; the next egg is the companion's",function()
			local h,db,c=fixture({"pip","puddle"})
			local none=State.wardrobePick("hat","puddle")
			assert(H.nestLand(h,"l1","puddle"))
			if none==nil then assert(saved(db).nest.gift==10+Nest.OwnedCap,"no rig item: 10 + OwnedCap")
			else assert(saved(db).nest.gift==none.id)end
			assert(saved(db).nest.pet=="puddle")
			ready(c)
			assert(H.nestClaim(h,"c1","pip"))
			assert(not Wearables.owns(saved(db),"pip","beanie"),"the hat was the stored pet's, not the companion's")
			assert(saved(db).nest.pet=="pip","the next egg lands for the companion at the claim")
			-- The stored pet is gone at claim time: its piece swaps to Stars, never to another pet.
			local h2,db2,c2=fixture({"pip","puddle"})
			assert(H.nestLand(h2,"l1","pip"))
			saved(db2).inventoryMask=Eggs.mask({"puddle"});saved(db2).petWearables={};h2=c2.reload(saved(db2).nest)
			local stars=saved(db2).nectar;ready(c2)
			assert(H.nestClaim(h2,"c1","puddle"));assert(saved(db2).nectar==stars+30 and saved(db2).nest.pet=="puddle")
		end)
		test("tuck: once per egg, keeps the claim proof; a claim lands the next egg untucked",function()
			local h,db,c=fixture()
			assert(H.nestLand(h,"l1","pip"))
			assert(H.nestTuck(h,"t1",0)and saved(db).nest.tucked==true and H.public(h).nest.tucked)
			local writes=c.writes
			assert(select(2,H.nestTuck(h,"t2",0))=="Tucked"and select(2,H.nestTuck(h,"t3",4))=="Changed"and c.writes==writes)
			ready(c);assert(H.nestClaim(h,"c1","pip"))
			assert(saved(db).nest.tucked==false and H.nestTuck(h,"t4",1)and H.nestCommitted(h,"c1"),"tuck keeps op")
		end)
		test("the snapshot carries nest only while on; off is the snapshot and the save of the build before",function()
			Onboard.inject({flags={OnboardingV3=false},studio=true})
			local h,db,c=fixture();local off=H.public(h);assert(off.nest==nil)
			local before=keys(off)
			Onboard.inject({flags={OnboardingV3=true},studio=true,nest=false});assert(H.public(h).nest==nil and keys(H.public(h))==before)
			assert(H.parkPlay(h,"p1",1,"pip")and saved(db).nest==nil,"other writes never add the field")
			Onboard.inject(ON)
			assert(H.public(h).nest==nil,"on, no egg yet: no key")
			assert(H.nestLand(h,"l1","pip"))
			local public=H.public(h);assert(public.nest and public.nest.n==0)
			public.nest=nil;assert(keys(public)==before)
			Onboard.inject({flags={OnboardingV3=true},studio=true,things=false})
			local kept=Http:JSONEncode(saved(db).nest)
			assert(H.public(h).nest==nil and H.parkPlay(h,"p2",1,"pip")and Http:JSONEncode(saved(db).nest)==kept,"off keeps the field as it is")
		end)
	end)
	Onboard.inject(nil)
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
