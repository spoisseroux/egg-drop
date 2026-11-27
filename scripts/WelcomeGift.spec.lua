-- The one-time "+5 ★ welcome gift" on "You're all set!" (ONBOARDING-V3-BRIEF section 3; Spencer OK'd it 2026-11-27).
-- The pure rules (WelcomeGift), the save path (HatchProgress.grantStarter marks a new save owed, HatchProgress.welcomeGift
-- pays it) and the request order (WelcomeGiftHost): paid once per save, ever, only when the three guide facts are saved;
-- refused otherwise; a replay, a retry after a store error, a lost reply, a rejoin or a second server never pays twice;
-- old saves and veterans never get it; a malformed field never fails a load. Isolated adapters only.
-- Offline: scripts/run_dash_server_specs.py. Studio: require(ServerScriptService.Server.ZZSpecs.WelcomeGift)(Server).
return function(server)
	local H=require(server.HatchProgress)
	local Host=require(server.WelcomeGiftHost)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Gift=require(Shared.WelcomeGift)
	local Coach=require(Shared.CoachMarks)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local fixtures=0
	local function adapterFor(db,c)
		return {
			now=function()return c.now end,
			guid=function()c.serial+=1;return c.prefix..c.serial end,
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
	end
	-- A brand-new save (no Bear yet); `owed` is what the Bear's grant is told (the allset2 switch).
	local function fresh(owed)
		fixtures+=1
		local db,c={},{now=1700000000,serial=0,writes=0,prefix="wg"..fixtures.."op"}
		local h=H.load(1,{},adapterFor(db,c));assert(h.status=="Ready","fixture "..tostring(h.status))
		assert(H.grantStarter(h,owed))
		assert(H.command(h,"ack",h.state.lastHatch.id,h.state.revision))
		return h,db,c
	end
	-- Another session on the same save (a rejoin, or another server): the old lease lapses, the save loads again.
	local function rejoin(h,db,c,changes)
		H.release(h)
		c.now+=200
		local saved=db.player_1.hatching
		saved.lease.expiresAt=0
		for k,v in pairs(changes or {})do saved[k]=copy(v)end
		local again=H.load(1,{},adapterFor(db,c));assert(again.status=="Ready","rejoin "..tostring(again.status))
		return again
	end
	local function done(h,db,c,except)
		except=except or {}
		local stats=copy(db.player_1.hatching.stats);stats.rounds=if except.stars then 1 else Gift.Rounds
		return rejoin(h,db,c,{
			coachMask=if except.pet then 0 else Coach.with(0,"needHi"),
			nest=if except.nest then {at=c.now,n=0,tucked=false,pet="pip"}else {at=c.now,n=0,tucked=true,pet="pip"},
			stats=stats})
	end

	test("pure: the numbers, the field's rules and load repair",function()
		assert(Gift.Bonus==5 and Gift.Owed==0 and Gift.Stored==255 and Gift.Rounds==2)
		assert(Gift.valid({})and Gift.valid({welcomeGift=0})and Gift.valid({welcomeGift=5})and Gift.valid({welcomeGift=255}))
		for _,bad in ipairs({-1,1.5,256,"5",true,{},0/0})do
			assert(not Gift.valid({welcomeGift=bad}),"invalid "..tostring(bad))
			assert(Gift.sanitize(bad)==nil,"repaired to not owed: "..tostring(bad))
		end
		assert(Gift.sanitize(0)==0 and Gift.sanitize(5)==5)
		assert(Gift.owed({welcomeGift=0})and not Gift.owed({})and not Gift.owed({welcomeGift=5}))
		assert(Gift.paid({welcomeGift=5})and not Gift.paid({welcomeGift=0})and not Gift.paid({}))
		local s={};assert(Gift.mark(s)and s.welcomeGift==0);s.welcomeGift=5;assert(not Gift.mark(s)and s.welcomeGift==5,"mark never rewinds a paid gift")
	end)

	test("pure: due only when owed, not a veteran, and Pet, Nest and Stars are all done; each reason",function()
		local function save(over)
			local s={welcomeGift=0,totalWins=0,coachMask=Coach.with(0,"needHi"),nest={tucked=true,n=0},stats={rounds=2}}
			for k,v in pairs(over or {})do s[k]=v end
			return s
		end
		assert(Gift.due(save(),true))
		assert(select(2,Gift.due(save({welcomeGift=5}),true))=="AlreadyGranted")
		assert(select(2,Gift.due(save({welcomeGift=false}),true))=="NotOwed"and select(2,Gift.due({},true))=="NotOwed"and select(2,Gift.due(nil,true))=="NotOwed")
		local old=save();old.welcomeGift=nil;assert(select(2,Gift.due(old,true))=="NotOwed","a save from before this build")
		assert(select(2,Gift.due(save({totalWins=Coach.VeteranWins}),true))=="Veteran")
		assert(select(2,Gift.due(save({coachMask=0}),true))=="NotDone","Pet not done")
		assert(Gift.due(save({coachMask=0,lastPetAward={id="p"}}),true),"a paid pet is a greeting")
		assert(Gift.due(save({coachMask=0}),true,Coach.with(0,"needHi")),"the board's queued bit counts")
		assert(select(2,Gift.due(save({nest={tucked=false,n=0}}),true))=="NotDone"and select(2,Gift.due(save({nest=false}),true))=="NotDone","Nest not done")
		assert(Gift.due(save({nest={tucked=false,n=1}}),true),"one hatched")
		assert(Gift.due(save({nest=false}),false),"the nest off in this world: Pet and Stars")
		assert(select(2,Gift.due(save({stats={rounds=1}}),true))=="NotDone"and select(2,Gift.due(save({stats=false}),true))=="NotDone","the Welcome round alone is not a round played")
		local s=save();local nectar=10;s.nectar=nectar;assert(Gift.apply(s)==5 and s.nectar==15 and s.welcomeGift==5)
	end)

	test("the Bear's grant marks a new save owed only with the switch on; the field never fails a load",function()
		local h,db=fresh(true)
		assert(h.state.welcomeGift==0 and db.player_1.hatching.welcomeGift==0,"owed, saved with the Bear")
		local off=fresh(false)
		assert(off.state.welcomeGift==nil,"switch off: never owed")
		local legacy=fresh(nil)
		assert(legacy.state.welcomeGift==nil,"an older caller (no argument): never owed")
		local again,why=H.grantStarter(h,true);assert(again and why=="AlreadyOwned"and h.state.welcomeGift==0)
		-- malformed on disk: repaired to not owed at load, the save still Ready
		local hb,db2,c2=fresh(true)
		local bad=rejoin(hb,db2,c2,{welcomeGift="lots"})
		assert(bad.status=="Ready"and bad.state.welcomeGift==nil)
	end)

	test("paid once: +5 Stars and the field set to 5 in one write; asked again it is AlreadyGranted, nothing paid",function()
		local h,db,c=fresh(true)
		h=done(h,db,c)
		local wallet,rev=h.state.nectar,h.state.revision
		local ok,why=H.welcomeGift(h,{nest=true})
		assert(ok and why=="Saved",tostring(why))
		assert(h.state.nectar==wallet+5 and h.state.welcomeGift==5 and h.state.revision==rev+1)
		assert(db.player_1.hatching.welcomeGift==5 and db.player_1.hatching.nectar==wallet+5)
		local writes=c.writes
		local again,whyAgain=H.welcomeGift(h,{nest=true})
		assert(again and whyAgain=="AlreadyGranted"and h.state.nectar==wallet+5 and c.writes==writes,"a replay: no write, no Stars")
		-- a rejoin or a second server on the same save
		local other=rejoin(h,db,c)
		local w=other.state.nectar
		local third,whyThird=H.welcomeGift(other,{nest=true})
		assert(third and whyThird=="AlreadyGranted"and other.state.nectar==w and other.state.welcomeGift==5)
	end)

	test("a stale session whose copy still says owed is refused inside UpdateAsync: the save already paid",function()
		local h,db,c=fresh(true)
		h=done(h,db,c)
		local stale=copy(h.state)
		assert(H.welcomeGift(h,{nest=true}))
		local paid=db.player_1.hatching.nectar
		-- the other server's view: owed (its copy is old), but the save on disk says 5
		h.state=stale;h.state.revision=db.player_1.hatching.revision
		h.state.operationSeq=db.player_1.hatching.operationSeq
		local ok,why=H.welcomeGift(h,{nest=true})
		assert(ok and why=="AlreadyGranted",tostring(why))
		assert(db.player_1.hatching.nectar==paid and db.player_1.hatching.welcomeGift==5,"never twice")
	end)

	test("a store error before the write and a lost reply after it: the pending gift resumes and pays once",function()
		local h,db,c=fresh(true)
		h=done(h,db,c)
		local wallet=h.state.nectar
		c.failNext="before"
		local ok,why=H.welcomeGift(h,{nest=true});assert(not ok and why=="Retrying"and h.pending)
		assert(db.player_1.hatching.welcomeGift==0,"nothing written")
		local ok2,why2=H.welcomeGift(h,{nest=true});assert(ok2 and why2=="Saved"and h.state.nectar==wallet+5)
		local g,dbg,cg=fresh(true)
		g=done(g,dbg,cg)
		local before=g.state.nectar
		cg.failNext="after"
		local okA,whyA=H.welcomeGift(g,{nest=true});assert(not okA and whyA=="Retrying")
		assert(dbg.player_1.hatching.welcomeGift==5,"it did commit")
		local okB,whyB=H.welcomeGift(g,{nest=true})
		assert(okB and whyB=="Saved"and g.state.nectar==before+5 and dbg.player_1.hatching.nectar==before+5,"proved, not paid again")
	end)

	test("refused, nothing written: not done yet, an old save, a switch-off save, a veteran",function()
		for _,missing in ipairs({"pet","nest","stars"})do
			local h,db,c=fresh(true)
			h=done(h,db,c,{[missing]=true})
			local wallet,writes=h.state.nectar,c.writes
			local ok,why=H.welcomeGift(h,{nest=true})
			assert(not ok and why=="NotDone"and h.state.nectar==wallet and h.state.welcomeGift==0 and c.writes==writes,missing..": "..tostring(why))
			if missing=="nest"then assert(H.welcomeGift(h,{nest=false}),"the nest off in this world")end
			if missing=="pet"then assert(H.welcomeGift(h,{nest=true,mask=Coach.with(0,"needHi")}),"the bit is queued on the board")end
		end
		local off,dbo,co=fresh(false)
		off=done(off,dbo,co)
		local okOff,whyOff=H.welcomeGift(off,{nest=true});assert(not okOff and whyOff=="NotOwed"and off.state.welcomeGift==nil)
		local vet,dbv,cv=fresh(true)
		vet=done(vet,dbv,cv)
		vet=rejoin(vet,dbv,cv,{totalWins=Coach.VeteranWins})
		local okVet,whyVet=H.welcomeGift(vet,{nest=true});assert(not okVet and whyVet=="Veteran"and vet.state.welcomeGift==0)
	end)

	test("code review: never under an open reveal (RevealPending, waited on, nothing written, seq still); paid once it closes",function()
		local Toys=require(Shared.ToyCatalog)
		assert(Gift.Wait.RevealPending and Gift.Wait.InvalidData and Gift.Wait.NotDone,"an owed save's waits are never final")
		local h,db,c=fresh(true)
		h=done(h,db,c)
		h=rejoin(h,db,c,{nectar=100})
		h.restricted=false
		local rev=h.state.revision
		assert(H.toyCommand(h,"toyBuy",{id=rev..":toy-wg",catalogVersion=Toys.CatalogVersion,poolVersion=Toys.PoolVersion,eligible=Toys.remaining(h.state.toyUnlocks)},rev))
		local pending=h.state.pendingToyResult;assert(pending,"the toy's reveal is open")
		local seq,wallet,writes=h.state.operationSeq,h.state.nectar,c.writes
		local ok,why=H.welcomeGift(h,{nest=true})
		assert(not ok and why=="RevealPending"and h.state.operationSeq==seq and h.state.nectar==wallet and c.writes==writes,tostring(why))
		assert(db.player_1.hatching.welcomeGift==0,"still owed")
		assert(H.toyCommand(h,"toyAck",{id=h.state.revision..":toy-wgack",catalogVersion=Toys.CatalogVersion,resultId=pending.id},h.state.revision))
		local ok2,why2=H.welcomeGift(h,{nest=true});assert(ok2 and why2=="Saved"and h.state.welcomeGift==5,tostring(why2))
	end)

	test("code review: the client asks again from the snapshot while owed and done (after the card's own ask), never once paid",function()
		local function snap(over)
			local s={welcomeGift=0,totalWins=0,coachMask=Coach.with(0,"needHi"),nest={tucked=true,n=0},stats={rounds=2}}
			for k,v in pairs(over or {})do s[k]=v end
			return s
		end
		local clock={}
		assert(not Gift.shouldAsk(snap(),true,nil,clock,100),"the card's own ask first")
		assert(not Gift.shouldAsk(snap(),true,nil,clock,100+Gift.AskAfter-1))
		assert(Gift.shouldAsk(snap(),true,nil,clock,100+Gift.AskAfter),"still owed: ask")
		clock.lastAsk=100+Gift.AskAfter
		assert(not Gift.shouldAsk(snap(),true,nil,clock,100+Gift.AskAfter+Gift.AskEvery-1))
		assert(Gift.shouldAsk(snap(),true,nil,clock,100+Gift.AskAfter+Gift.AskEvery),"and again")
		assert(not Gift.shouldAsk(snap({welcomeGift=5}),true,nil,clock,1e6)and clock.doneSince==nil,"paid: never")
		assert(not Gift.shouldAsk(snap({stats={rounds=1}}),true,nil,{},1e6),"not done: never")
		assert(not Gift.shouldAsk(snap({welcomeGift=false}),true,nil,{},1e6),"not owed: never")
	end)

	-- The request order (WelcomeGiftHost).
	local function deps(over)
		local d={log={},grants=0,waits=0,running_=false,replies={}}
		local answers=table.clone(over.answers or {{true,"Saved"}})
		d.paid=function()return over.paid==true end
		d.on=function()return over.on~=false end
		d.running=function()return d.running_ end
		d.setRunning=function(on)d.running_=on end
		d.alive=function()return over.alive~=false end
		d.free=function()return over.free~=false end
		d.grant=function()d.grants+=1;local a=table.remove(answers,1)or {false,"NotDone"};return a[1],a[2]end
		d.wait=function(s)d.waits+=1;assert(s==Gift.Gap)end
		d.publish=function()table.insert(d.log,"publish")end
		d.reply=function(status,reason,stars)table.insert(d.replies,{status=status,reason=reason,stars=stars})end
		return d
	end
	test("host: paid first (before the switch), then the switch, one loop a board, the tries, final refusals at once",function()
		local d=deps({paid=true,on=false})
		assert(Host.request(d)=="AlreadyGranted"and d.grants==0 and d.replies[1].status=="Saved"and d.replies[1].stars==5)
		d=deps({on=false});assert(Host.request(d)=="NotReady"and d.grants==0 and d.replies[1].status=="Rejected")
		d=deps({});assert(Host.request(d)=="Saved"and d.grants==1 and d.replies[1].status=="Saved"and d.replies[1].stars==5 and d.log[1]=="publish"and not d.running_)
		d=deps({});d.running_=true;assert(Host.request(d)=="Running"and d.grants==0 and #d.replies==0,"a second ask while one runs")
		d=deps({answers={{false,"NotDone"},{false,"Busy"},{true,"Saved"}}})
		assert(Host.request(d)=="Saved"and d.grants==3 and d.waits==2 and #d.replies==1,"the facts land: paid on the third try")
		d=deps({answers={}})
		assert(Host.request(d)=="NotDone"and d.grants==Gift.Tries and d.waits==Gift.Tries-1 and d.replies[1].status=="Rejected"and d.replies[1].reason=="NotDone")
		for _,final in ipairs({"NotOwed","Veteran","BalanceLimit","SessionLost"})do
			d=deps({answers={{false,final}}});assert(Host.request(d)==final and d.grants==1 and d.waits==0 and d.replies[1].reason==final and not d.running_)
		end
		d=deps({free=false});assert(Host.request(d)=="Busy"and d.grants==0 and d.replies[1].reason=="Busy","never a write while the save is in use")
		d=deps({alive=false});assert(Host.request(d)=="Gone"and #d.replies==0 and not d.running_)
		d=deps({answers={{true,"AlreadyGranted"}}});assert(Host.request(d)=="AlreadyGranted"and d.replies[1].status=="Saved")
	end)

	return {passed=#cases,cases=cases}
end
