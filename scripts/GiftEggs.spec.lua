-- The gift chain's three free eggs (ONBOARDING-FUN-PASS section 2, Onboard "gifts"; GIFT-CHAIN-PLAN and its architect
-- review). The pure rules (GiftEggs), the save path (HatchProgress.grantStarter marks a new save owed, giftEgg gives the
-- Paint and Toy Eggs, giftSeen, statEggBuy with `gift` gives the Snack Egg), the request order (GiftEggHost):
--   once per save, only when its trigger is in the save; a replay, a retry after a store error, a lost reply, a rejoin
--   or a second server never gives twice; the Snack gift never falls back to the player's own banked or medal egg and a
--   plain buy never touches the gift; no veteran check on an owed save; a malformed field fails closed (every kind reads
--   as granted, nothing written over it); nothing is written under another open reservation or reveal; an undeliverable
--   Snack is never advertised. Isolated adapters only.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(ServerScriptService.Server.ZZSpecs.GiftEggs)(Server).
return function(server)
	local H=require(server.HatchProgress)
	local Host=require(server.GiftEggHost)
	local StatEggs=require(server.StatEggState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Gifts=require(Shared.GiftEggs)
	local Coach=require(Shared.CoachMarks)
	local Toys=require(Shared.ToyCatalog)
	local StatCatalog=require(Shared.StatEggCatalog)
	local Daily=require(Shared.DailyContracts)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local function same(a,b)
		if type(a)~=type(b)then return false end
		if type(a)~="table"then return a==b end
		for k,v in pairs(a)do if not same(v,b[k])then return false end end
		for k in pairs(b)do if a[k]==nil then return false end end
		return true
	end
	local fixtures=0
	local function adapterFor(db,c)
		return {
			now=function()return c.now end,
			guid=function()c.serial+=1;return c.prefix..c.serial end,
			random=function()return c.unit or .9 end,
			wait=function()end,
			update=function(key,transform)
				c.writes+=1
				if c.failNext=="before"or(c.failAt and c.writes==c.failAt)then c.failNext=nil;c.failAt=nil;error("store down")end
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
				if c.failNext=="after"then c.failNext=nil;error("response lost")end
				return copy(value)
			end,
		}
	end
	-- A brand-new save; `chain` is what the Bear's grant is told (the gifts switch). Ready, the Bear acked, random rolls.
	local function fresh(chain,keepReveal)
		fixtures+=1
		local db,c={},{now=1700000000,serial=0,writes=0,prefix="ge"..fixtures.."op"}
		local h=H.load(1,{},adapterFor(db,c));assert(h.status=="Ready","fixture "..tostring(h.status))
		assert(H.grantStarter(h,false,chain))
		if not keepReveal then assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))end
		h.restricted=false
		return h,db,c
	end
	local function rejoin(h,db,c,changes,later)
		H.release(h)
		c.now+=later or 200
		local saved=db.player_1.hatching
		saved.lease.expiresAt=0
		for k,v in pairs(changes or {})do saved[k]=copy(v)end
		local again=H.load(1,{},adapterFor(db,c));assert(again.status=="Ready","rejoin "..tostring(again.status))
		again.restricted=h.restricted
		return again
	end
	local function today(c)return Daily.dayOf(c.now)end
	local function tucked(c)return {nest={at=c.now,n=0,tucked=true,pet="pip"}}end
	local function withRounds(db,n)local stats=copy(db.player_1.hatching.stats);stats.rounds=n;return stats end
	-- A save with the Paint gift given (random: iris at .9).
	local function painted(chain)
		local h,db,c=fresh(chain~=false)
		h=rejoin(h,db,c,tucked(c))
		local ok,why,r=H.giftEgg(h,"paint",{nest=true})
		assert(ok and why=="Saved",tostring(why))
		return h,db,c,r
	end
	local function snackKey(h)return StatEggs.quoteKey(h.state,"pip",StatCatalog.selectionMode(h.restricted))end
	local function raced(h,db,c,extra)
		local changes={dash={ribbons={gold=0,silver=0,bronze=1,green=0}}}
		for k,v in pairs(extra or {})do changes[k]=v end
		return rejoin(h,db,c,changes)
	end

	-- Pure ---------------------------------------------------------------------------------------------------------------
	test("pure: the tolerant read, owed and mark; a malformed part closes every kind",function()
		assert(not Gifts.owed({})and not Gifts.granted({},"paint"),"an old save: not owed, nothing granted")
		local s={};assert(Gifts.mark(s)and s.gifts.v==1 and Gifts.owed(s))
		s.gifts.paint={op="a",item="rose",day="20000"}
		assert(not Gifts.mark(s)and s.gifts.paint.item=="rose","mark never rewrites a field")
		assert(Gifts.granted(s,"paint")and not Gifts.granted(s,"toy")and Gifts.record(s,"paint").item=="rose")
		s.gifts.later={x=1};s.gifts.paint.extra=true
		assert(Gifts.owed(s)and Gifts.record(s,"paint"),"unknown keys are newer data, kept and read past")
		for label,bad in pairs({table="junk",v={paint=nil},vZero={v=0},vText={v="1"},op={v=1,paint={item="rose",day="20000"}},
			item={v=1,toy={op="a",day="20000"}},day={v=1,paint={op="a",item="rose",day=20000}},seen={v=1,paint={op="a",item="rose",day="20000",seen="yes"}},
			snackId={v=1,snack={op="a",day="20000",snackId=-1}},fetch={v=1,fetch="yes"},record={v=1,snack=true}})do
			local state={gifts=bad,inventoryMask=1,nest={tucked=true}}
			for _,kind in ipairs(Gifts.Kinds)do
				assert(Gifts.granted(state,kind),label..": "..kind.." reads as granted")
				assert(select(2,Gifts.due(state,kind,"20000",{}))=="AlreadyGranted",label..": "..kind.." never due")
			end
			assert(not Gifts.owed(state)and Gifts.record(state,"paint")==nil and Gifts.unseen(state)==nil,label)
		end
	end)

	test("pure: due per kind, each reason; no veteran check on an owed save",function()
		local function save(over)
			local s={gifts={v=1},inventoryMask=1,totalWins=0,coachMask=0,nest={tucked=true,n=0},stats={rounds=0},toyUnlocks={}}
			for k,v in pairs(over or {})do s[k]=v end
			return s
		end
		assert(Gifts.due(save(),"paint","20000",{}))
		assert(select(2,Gifts.due(save({nest={tucked=false,n=0}}),"paint","20000",{}))=="NotDue")
		assert(Gifts.due(save({nest={tucked=false,n=2}}),"paint","20000",{}),"one hatched counts")
		assert(select(2,Gifts.due(save({nest=false}),"paint","20000",{nest=false}))=="NotDue","the nest off: the first hello")
		assert(Gifts.due(save({nest=false,coachMask=Coach.with(0,"needHi")}),"paint","20000",{nest=false}))
		local old=save();old.gifts=nil
		assert(select(2,Gifts.due(old,"paint","20000",{}))=="NotOwed","a save from before this build")
		assert(select(2,Gifts.due(save({inventoryMask=0}),"paint","20000",{}))=="MeetPipFirst")
		assert(select(2,Gifts.due(save(),"bow","20000",{}))=="InvalidGift"and select(2,Gifts.due(nil,"paint","20000",{}))=="NotOwed")
		assert(Gifts.due(save({totalWins=Coach.VeteranWins*10}),"paint","20000",{}),"a few wins never cancel an owed gift")
		local p={op="p",item="rose",day="20000"}
		assert(select(2,Gifts.due(save(),"toy","20000",{}))=="NotDue"and select(2,Gifts.due(save(),"snack","20000",{}))=="NotDue","Paint first")
		assert(select(2,Gifts.due(save({gifts={v=1,paint=p}}),"toy","20000",{}))=="NotDue","the same day, the Welcome round only (not counted)")
		assert(select(2,Gifts.due(save({gifts={v=1,paint=p},stats={rounds=Gifts.ToyRounds-1}}),"toy","20000",{}))=="NotDue","the same day, one field round")
		assert(Gifts.due(save({gifts={v=1,paint=p},stats={rounds=Gifts.ToyRounds}}),"toy","20000",{}),"two field rounds after the Bear (the Welcome round is not counted)")
		assert(Gifts.due(save({gifts={v=1,paint=p}}),"toy","20001",{}),"a later server day")
		local all={};for _,id in ipairs(Toys.Pools[Toys.PoolVersion])do all[id]=true end
		assert(select(2,Gifts.due(save({gifts={v=1,paint=p},stats={rounds=9},toyUnlocks=all}),"toy","20000",{}))=="AllOwned")
		assert(Gifts.due(save({gifts={v=1,paint=p},stats={rounds=9},totalWins=50}),"toy","20000",{}),"veteran wins: still given")
		assert(select(2,Gifts.due(save({gifts={v=1,paint=p}}),"snack","20000",{}))=="NotDue","no race finished")
		assert(Gifts.due(save({gifts={v=1,paint=p},dash={ribbons={green=1}}}),"snack","20000",{}),"any place")
		assert(select(2,Gifts.due(save({gifts={v=1,paint=p,snack={op="s",day="20000"}},dash={ribbons={green=1}}}),"snack","20000",{}))=="AlreadyGranted")
	end)

	test("pure: the pots-only pool (25% each), the roll and the fixed pick; toy odds over what is left",function()
		local rows=Gifts.odds("paint");assert(#rows==4)
		local total=0;for _,r in ipairs(rows)do assert(r.percent==25);total+=r.percent end;assert(total==100)
		assert(Gifts.draw({},{kind="paint",unit=0})=="rose"and Gifts.draw({},{kind="paint",unit=.99})=="iris")
		assert(Gifts.draw({},{kind="paint",unit=1})==nil and Gifts.draw({},{kind="paint"})==nil)
		assert(Gifts.draw({hueInventory={rose=2,tide=0,citrus=1,iris=3,reset=0}},{kind="paint",fixed=true})=="tide","restricted: the pot held fewest")
		local left=Toys.remaining({ball=true})
		assert(#Gifts.odds("toy",{toyUnlocks={ball=true}})==#left)
		assert(Gifts.draw({toyUnlocks={ball=true}},{kind="toy",fixed=true})==Toys.fixedNext(left))
		assert(table.find(left,Gifts.draw({toyUnlocks={ball=true}},{kind="toy",unit=.5})))
	end)

	-- The save path ------------------------------------------------------------------------------------------------------
	test("the Bear's grant marks a new save owed only with the switch on; old callers and off never",function()
		local h,db=fresh(true)
		assert(h.state.gifts and h.state.gifts.v==1 and db.player_1.hatching.gifts.v==1,"owed, saved with the Bear")
		assert(fresh(false).state.gifts==nil and fresh(nil).state.gifts==nil)
		local again,why=H.grantStarter(h,false,true);assert(again and why=="AlreadyOwned")
	end)

	test("Paint: once, after the tuck; one pot (pots only) and its found bit in one write; asked again: AlreadyGranted, no write",function()
		local h,db,c=fresh(true)
		local ok,why=H.giftEgg(h,"paint",{nest=true});assert(not ok and why=="NotDue","before the tuck: "..tostring(why))
		h=rejoin(h,db,c,tucked(c))
		local inv,rev,stars=copy(h.state.hueInventory),h.state.revision,h.state.nectar
		local ok2,why2,r=H.giftEgg(h,"paint",{nest=true})
		assert(ok2 and why2=="Saved"and r.kind=="paint"and r.item=="iris"and r.seen==false,tostring(why2))
		assert(h.state.hueInventory.iris==inv.iris+1 and h.state.revision==rev+1 and h.state.nectar==stars,"a pot, no Stars")
		assert(bit32.band(h.state.lookFound or 0,require(Shared.LookEggCatalog).bit("iris"))~=0)
		assert(db.player_1.hatching.gifts.paint.item=="iris"and db.player_1.hatching.hueInventory.iris==inv.iris+1)
		assert(h.state.lastOperation.digest=="gift:paint:"..r.id and h.state.lastOperation.id==r.id,"an exact digest")
		local writes=c.writes
		local again,whyAgain,r2=H.giftEgg(h,"paint",{nest=true})
		assert(again and whyAgain=="AlreadyGranted"and r2.item=="iris"and c.writes==writes and h.state.hueInventory.iris==inv.iris+1)
		local other=rejoin(h,db,c)
		local third,whyThird,r3=H.giftEgg(other,"paint",{nest=true})
		assert(third and whyThird=="AlreadyGranted"and r3.item=="iris"and other.state.hueInventory.iris==inv.iris+1,"a rejoin or a second server")
		assert(select(2,H.giftEgg(other,"snack",{}))=="InvalidGift","the Snack is a statEggBuy")
	end)

	test("Paint: a restricted account gets the fixed next pot; the nest off reads the first hello",function()
		local h,db,c=fresh(true);h.restricted=true
		h=rejoin(h,db,c,tucked(c))
		local ok,_,r=H.giftEgg(h,"paint",{nest=true});assert(ok and r.item=="rose","fixed: the pot held fewest (ties in order)")
		local g,dbg,cg=fresh(true)
		assert(select(2,H.giftEgg(g,"paint",{nest=false}))=="NotDue")
		g=rejoin(g,dbg,cg,{coachMask=Coach.with(0,"needHi")})
		assert(H.giftEgg(g,"paint",{nest=false}))
	end)

	test("a stale session whose copy has no record is refused inside UpdateAsync, and answers the record already saved",function()
		local h,db,c=fresh(true)
		h=rejoin(h,db,c,tucked(c))
		local stale=copy(h.state)
		local _,_,r=H.giftEgg(h,"paint",{nest=true})
		local inv=db.player_1.hatching.hueInventory.iris
		h.state=stale;h.state.revision=db.player_1.hatching.revision;h.state.operationSeq=db.player_1.hatching.operationSeq
		c.unit=.1 -- another roll would be rose
		local ok,why,again=H.giftEgg(h,"paint",{nest=true})
		assert(ok and why=="AlreadyGranted"and again.item==r.item and again.id==r.id,tostring(why))
		assert(db.player_1.hatching.hueInventory.iris==inv and(db.player_1.hatching.hueInventory.rose or 0)==0,"never twice")
	end)

	test("a store error before the write and a lost reply after it: the frozen candidate resumes and gives one pot once",function()
		local h,db,c=fresh(true)
		h=rejoin(h,db,c,tucked(c))
		c.failNext="before"
		local ok,why=H.giftEgg(h,"paint",{nest=true});assert(not ok and why=="Retrying"and h.pending)
		assert(db.player_1.hatching.gifts.paint==nil,"nothing written")
		c.unit=.1 -- a fresh roll would differ: the resumed candidate keeps its own
		local ok2,why2,r=H.giftEgg(h,"paint",{nest=true});assert(ok2 and why2=="Saved"and r.item=="iris")
		local g,dbg,cg=fresh(true)
		g=rejoin(g,dbg,cg,tucked(cg))
		local before=copy(g.state.hueInventory)
		cg.failNext="after"
		local okA,whyA=H.giftEgg(g,"paint",{nest=true});assert(not okA and whyA=="Retrying")
		assert(dbg.player_1.hatching.gifts.paint~=nil,"it did commit")
		local okB,whyB,rB=H.giftEgg(g,"paint",{nest=true})
		assert(okB and whyB=="Saved"and rB.item=="iris"and dbg.player_1.hatching.hueInventory.iris==before.iris+1,"proved, not given again")
	end)

	test("guard: no gift write under an open reveal or reservation; operationSeq never moves (RevealPending, the host waits)",function()
		-- the Bear's own reveal still open
		local h,db,c=fresh(true,true)
		h=rejoin(h,db,c,tucked(c))
		local seq,writes=h.state.operationSeq,c.writes
		local ok,why=H.giftEgg(h,"paint",{nest=true})
		assert(not ok and why=="RevealPending"and h.state.operationSeq==seq and c.writes==writes,tostring(why))
		assert(Gifts.Wait[why],"the host waits on it")
		-- a Toy Egg bought and its reveal not acked yet: no Paint gift, no giftSeen, no Snack gift
		local g,dbg,cg=painted()
		assert(H.giftSeen(g,"paint")) -- seen first, so giftSeen below is the guard's to refuse
		g=rejoin(g,dbg,cg,{nectar=100,stats=withRounds(dbg,0),dash={ribbons={gold=1}}})
		local rev=g.state.revision
		local okBuy,whyBuy=H.toyCommand(g,"toyBuy",{id=rev..":toy-guard",catalogVersion=Toys.CatalogVersion,poolVersion=Toys.PoolVersion,eligible=Toys.remaining(g.state.toyUnlocks)},rev)
		assert(okBuy,tostring(whyBuy));assert(g.state.pendingToyResult,"the toy's reveal is open")
		local seqG=g.state.operationSeq
		g.state.gifts.paint=nil -- this session's copy only: the guard must refuse before any rule
		local okP,whyP=H.giftEgg(g,"paint",{nest=true})
		assert(not okP and(whyP=="RevealPending"or whyP=="AlreadyGranted"),tostring(whyP))
		local okS,whyS=H.statEggBuy(g,"snack-guard","pip",true,snackKey(g),true)
		assert(not okS and whyS=="RevealPending"and g.state.operationSeq==seqG,tostring(whyS))
		assert(dbg.player_1.hatching.gifts.snack==nil)
		-- a saved Toy Egg reservation (the store failed between the reserve and the settle): no gift write, no seq move
		local t,dbt,ct=fresh(true)
		t=rejoin(t,dbt,ct,{nectar=100,nest={at=ct.now,n=0,tucked=true,pet="pip"}})
		t.restricted=false
		local revT=t.state.revision
		ct.failAt=ct.writes+2
		local okR,whyR=H.toyCommand(t,"toyBuy",{id=revT..":toy-held",catalogVersion=Toys.CatalogVersion,poolVersion=Toys.PoolVersion,eligible=Toys.remaining(t.state.toyUnlocks)},revT)
		assert(not okR and whyR=="Retrying"and dbt.player_1.hatching.toyReservation,"a reservation saved: "..tostring(whyR))
		assert(t.state.toyReservation,"this session holds it")
		local seqT,revNow,writesT=t.state.operationSeq,t.state.revision,ct.writes
		local okP2,whyP2=H.giftEgg(t,"paint",{nest=true})
		assert(not okP2 and whyP2=="Pending"and ct.writes==writesT,"the toy settles first: "..tostring(whyP2))
		-- even with the pending operation dropped, the guard refuses inside the write (the reservation is in the save)
		t.pending=nil;t.status="Ready"
		local okT,whyT=H.giftEgg(t,"paint",{nest=true})
		assert(not okT and whyT=="RevealPending"and t.state.operationSeq==seqT and t.state.revision==revNow,tostring(whyT))
		assert(dbt.player_1.hatching.gifts.paint==nil and dbt.player_1.hatching.operationSeq==seqT and dbt.player_1.hatching.toyReservation)
	end)

	test("giftSeen: once, OR-only; never without a record; the unseen reveal is published until then",function()
		local h,db,c=painted()
		assert(Gifts.unseen(h.state)=="paint")
		assert(select(2,H.giftSeen(h,"toy"))=="NoGift")
		local ok,why=H.giftSeen(h,"paint");assert(ok and why=="Saved"and db.player_1.hatching.gifts.paint.seen==true)
		assert(Gifts.unseen(h.state)==nil)
		local writes=c.writes
		local again,whyAgain=H.giftSeen(h,"paint");assert(again and whyAgain=="AlreadySaved"and c.writes==writes)
		assert(H.giftEgg(h,"paint",{nest=true}),"still AlreadyGranted")
		assert(db.player_1.hatching.gifts.paint.seen==true and db.player_1.hatching.gifts.paint.item=="iris")
	end)

	test("Toy: after the Paint gift and two rounds (or a later day); a toy not owned; veterans too; all owned skips it",function()
		local h,db,c=painted()
		local ok,why=H.giftEgg(h,"toy",{nest=true});assert(not ok and why=="NotDue",tostring(why))
		h=rejoin(h,db,c,{stats=withRounds(db,Gifts.ToyRounds),totalWins=Coach.VeteranWins+3})
		local before=copy(h.state.toyUnlocks)
		local ok2,why2,r=H.giftEgg(h,"toy",{nest=true})
		assert(ok2 and why2=="Saved"and r.kind=="toy"and not before[r.item]and h.state.toyUnlocks[r.item]==true,tostring(why2))
		assert(db.player_1.hatching.toyUnlocks[r.item]==true and db.player_1.hatching.gifts.toy.item==r.item)
		assert(h.state.pendingToyResult==nil and h.state.toyReservation==nil,"no paid receipt, no reveal field")
		local d,dbd,cd=painted()
		d=rejoin(d,dbd,cd,nil,86400)
		assert(H.giftEgg(d,"toy",{nest=true}),"a later server day")
		local all={};for _,id in ipairs(Toys.Pools[Toys.PoolVersion])do all[id]=true end
		local a,dba,ca=painted()
		a=rejoin(a,dba,ca,{toyUnlocks=all,stats=withRounds(dba,9)})
		local writes=ca.writes
		local okAll,whyAll=H.giftEgg(a,"toy",{nest=true})
		assert(not okAll and whyAll=="AllOwned"and ca.writes<=writes+1 and a.state.gifts.toy==nil,"skipped: nothing given")
	end)

	test("Snack: an explicit gift buy after a Dash finish; never the bank or a medal egg; a plain buy never touches it",function()
		local h,db,c=painted()
		h=rejoin(h,db,c,{statEgg={free=2}})
		local okNo,whyNo=H.statEggBuy(h,"s-early","pip",true,snackKey(h),true)
		assert(not okNo and whyNo=="NotDue"and StatEggs.free(h.state)==2,"no race finished: refused, the bank untouched")
		-- a plain free buy spends the bank, never the gift
		local okPlain=H.statEggBuy(h,"s-plain","pip",true,snackKey(h))
		assert(okPlain and StatEggs.free(h.state)==1 and h.state.gifts.snack==nil)
		h=raced(h,db,c)
		local pouch=#StatEggs.pouch(h.state)
		local key=snackKey(h)
		local ok,why,receipt=H.statEggBuy(h,"s-gift","pip",true,key,true)
		assert(ok and why=="Saved"and receipt.source=="gift"and receipt.cost==0,tostring(why))
		assert(StatEggs.free(h.state)==1,"the bank is untouched")
		assert(#StatEggs.pouch(h.state)==pouch+1 and h.state.gifts.snack.op=="s-gift"and h.state.gifts.snack.snackId==receipt.snackId)
		-- a second gift: AlreadyGranted, no fall-back, even with a banked egg
		local okTwo,whyTwo=H.statEggBuy(h,"s-again","pip",true,snackKey(h),true)
		assert(not okTwo and whyTwo=="AlreadyGranted"and StatEggs.free(h.state)==1 and #StatEggs.pouch(h.state)==pouch+1,tostring(whyTwo))
		-- the same op again: the replay
		local okRe,whyRe,r=H.statEggBuy(h,"s-gift","pip",true,key,true) -- the replay sends what the press sent
		assert(okRe and whyRe=="AlreadySaved"and r.snackId==receipt.snackId,tostring(okRe).." "..tostring(whyRe))
		assert(select(2,H.statEggBuy(h,"s-bad","pip",false,snackKey(h),true))=="InvalidStatEgg","a gift is always free")
		assert(select(2,H.statEggBuy(h,"s-bad2","pip",true,snackKey(h),"yes"))=="InvalidStatEgg")
	end)

	test("Snack: its replay reads gifts.snack once the Stat Egg receipt has left the ring",function()
		local h,db,c=painted()
		h=raced(h,db,c)
		local _,_,receipt=H.statEggBuy(h,"s-ring","pip",true,snackKey(h),true)
		local egg=copy(db.player_1.hatching.statEgg);egg.receipts={}
		h=rejoin(h,db,c,{statEgg=egg})
		assert(StatEggs.receipt(h.state,"s-ring")==nil)
		local ok,why,r=H.statEggBuy(h,"s-ring","pip",true,snackKey(h),true)
		assert(ok and why=="AlreadySaved"and r.source=="gift"and r.snackId==receipt.snackId and r.stat==receipt.stat,tostring(why))
		assert(#StatEggs.pouch(h.state)==#StatEggs.pouch(db.player_1.hatching),"nothing written")
	end)

	test("undeliverable: a full pouch is never advertised, and the gift buy is refused with no fall-back",function()
		local h,db,c=painted()
		local snacks={};for i=1,StatCatalog.PouchSize do snacks[i]={id=i,stat="jump",size="snack"}end
		h=raced(h,db,c,{snackPouch=snacks,statEgg={serial=StatCatalog.PouchSize,free=1}})
		assert(H.giftSeen(h,"paint"))
		assert(H.giftReady(h,{nest=true})==nil,"no Snack ready while the pouch is full (the Toy is not due yet)")
		local ok,why=H.statEggBuy(h,"s-full","pip",true,snackKey(h),true)
		assert(not ok and why=="PouchFull"and StatEggs.free(h.state)==1 and h.state.gifts.snack==nil,tostring(why))
		h=rejoin(h,db,c,{snackPouch={}})
		assert(H.giftReady(h,{nest=true})=="snack","room again: ready")
		assert(H.giftReady(h,{nest=true,petId="blip"})==nil,"the pet that is out must own it")
	end)

	test("malformed on disk: every kind reads granted, nothing is given or written over it; load repairs nothing",function()
		for _,bad in ipairs({"junk",{v=1,paint={op=5}},{v=1,toy={op="t",item="ball",day="x"}},{v=0},{v=1,fetch=1}})do
			local h,db,c=fresh(true)
			h=rejoin(h,db,c,{gifts=bad,nest={at=c.now,n=0,tucked=true,pet="pip"},dash={ribbons={gold=1}},stats=withRounds(db,9)})
			assert(same(h.state.gifts,bad),"load keeps it as it is")
			local inv=copy(h.state.hueInventory)
			for _,kind in ipairs({"paint","toy"})do
				local ok,why,r=H.giftEgg(h,kind,{nest=true})
				assert(ok and why=="AlreadyGranted"and r==nil,kind..": "..tostring(why))
			end
			assert(not H.statEggBuy(h,"s-m","pip",true,snackKey(h),true),"no Snack")
			assert(H.giftReady(h,{nest=true})==nil)
			assert(same(h.state.hueInventory,inv))
			assert(H.grantPurchase(h,"fund-m",3,false),"another write")
			assert(same(db.player_1.hatching.gifts,bad),"kept untouched")
		end
	end)

	-- The request order (GiftEggHost) ------------------------------------------------------------------------------------
	local function deps(over)
		local d={log={},grants=0,waits=0,running_=false,replies={}}
		local answers=table.clone(over.answers or {{true,"Saved",{kind="paint",item="rose"}}})
		d.saved=function()return over.saved end
		d.on=function()return over.on~=false end
		d.running=function()return d.running_ end
		d.setRunning=function(on)d.running_=on end
		d.alive=function()return over.alive~=false end
		d.free=function()return over.free~=false end
		d.grant=function()d.grants+=1;local a=table.remove(answers,1)or {false,"RevealPending"};return a[1],a[2],a[3]end
		d.wait=function(s)d.waits+=1;assert(s==Gifts.Gap)end
		d.publish=function()table.insert(d.log,"publish")end
		d.reply=function(status,reason,record)table.insert(d.replies,{status=status,reason=reason,record=record})end
		return d
	end
	test("host: a saved record first (before the switch), the switch, one loop a board, the waits, final refusals at once",function()
		local d=deps({saved={kind="paint",item="tide"},on=false})
		assert(Host.request(d)=="AlreadyGranted"and d.grants==0 and d.replies[1].status=="Saved"and d.replies[1].record.item=="tide")
		d=deps({on=false});assert(Host.request(d)=="NotReady"and d.grants==0 and d.replies[1].status=="Rejected")
		d=deps({});assert(Host.request(d)=="Saved"and d.grants==1 and d.replies[1].record.item=="rose"and d.log[1]=="publish"and not d.running_)
		d=deps({});d.running_=true
		assert(Host.request(d)=="Running"and d.grants==0 and #d.replies==1 and d.replies[1].status=="Rejected"and d.replies[1].reason=="Busy",
			"code review: a second ask while one runs is answered Busy, so the client asks again")
		assert(d.running_==true,"the first loop still runs")
		d=deps({answers={{false,"RevealPending"},{false,"Busy"},{true,"Saved",{kind="toy",item="ball"}}}})
		assert(Host.request(d)=="Saved"and d.grants==3 and d.waits==2 and d.replies[1].record.item=="ball")
		d=deps({answers={}})
		assert(Host.request(d)=="RevealPending"and d.grants==Gifts.Tries and d.waits==Gifts.Tries-1 and d.replies[1].reason=="RevealPending")
		for _,final in ipairs({"NotDue","AllOwned","NotOwed","InvalidGift","SessionLost"})do
			d=deps({answers={{false,final}}});assert(Host.request(d)==final and d.grants==1 and d.waits==0 and d.replies[1].reason==final and not d.running_)
		end
		d=deps({free=false});assert(Host.request(d)=="Busy"and d.grants==0)
		d=deps({alive=false});assert(Host.request(d)=="Gone"and #d.replies==0 and not d.running_)
	end)

	return {passed=#cases,cases=cases}
end
