-- v2 pet names (NameCatalog, NameState, HatchProgress.nameEggBuy / setPetName / catchUpNames).
-- Isolated adapters only; no DataStore.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.PetNames)(ServerScriptService.Server)
return function(server)
	local H=require(server.HatchProgress)
	local N=require(server.NameState)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local C=require(Shared.NameCatalog)
	local Stat=require(Shared.StatCatalog)
	local Eggs=require(Shared.EggCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
	local pip=Eggs.bit("pip")
	local function fixture(seed,start)
		local db,c={},{now=start or 1700000000,serial=0,rand={}}
		local adapter={
			now=function()return c.now end,
			guid=function()c.serial+=1;return "op"..c.serial end,
			random=function()return if #c.rand>0 then table.remove(c.rand,1)else .1 end,
			wait=function()end,
			update=function(key,transform)
				local value=transform(copy(db[key]))
				if value then db[key]=copy(value)end
				if c.throwAfter then c.throwAfter=false;error("ambiguous: committed but the reply was lost")end
				return copy(value)
			end,
		}
		if seed then db.player_1=seed end
		return H.load(1,{rank=1},adapter),db,c
	end
	local NONE={}
	local function reseed(db,fields)
		local seed=copy(db.player_1)
		for key,value in pairs(fields)do seed.hatching[key]=if value==NONE then nil else value end
		seed.hatching.lease={token="",expiresAt=0};return seed
	end
	local function ready(fields,nectar)
		local _,db,c=fixture()
		local f={inventoryMask=pip,nectar=nectar or 200}
		for k,v in pairs(fields or {})do f[k]=v end
		c.now+=200
		local h,db2,c2=fixture(reseed(db,f),c.now)
		assert(h.status=="Ready","load "..tostring(h.status))
		return h,db2,c2
	end
	local function owns(h,id)return table.find(N.owned(h.state),id)~=nil end
	local function quote(h)return H.public(h).names.quoteKey end

	-- Frozen at ship: these ids, in this order, must stay a prefix of the catalogue (append only).
	local Golden={"biscuit","puddle","tuesday","parade","button","sprinkle",
		"velvet","sidequest","bureau","mooncrumb","almost","marmalade","teacup","thunderbun","noodle","overture",
		"pocketful","moonboots","crumpet","detour","waffle","stardust","dumpling","keepsake","apricot","afterparty",
		"cuddle","sweetpea","heartsong","bonk","mighty","thunderpaw","fizz","sparky","lightning","boing","hopscotch","moonbounce",
		"zoomies","speedy","rocket","hmm","clever","professor","sprout","bloom","starbloom","champion","dogear","bookworm","footnote","librarian"}
	local GoldenPool={version=1,price=8,count=20}

	test("catalogue: golden ids are a frozen prefix, 52 pieces in five lanes, egg order is the egg lane",function()
		for i,id in ipairs(Golden)do assert(C.Pieces[i]and C.Pieces[i].id==id,"piece "..i.." changed: "..tostring(C.Pieces[i]and C.Pieces[i].id))end
		assert(#C.Pieces==52)
		assert(C.LaneCount.starter==6 and C.LaneCount.egg==20 and C.LaneCount.stat==18 and C.LaneCount.keeper==4 and C.LaneCount.book==4)
		for i=1,20 do assert(C.EggOrder[i]==Golden[6+i])end
		-- A pool change (membership, retirement, price) must bump PoolVersion.
		local active=0;for _,id in ipairs(C.EggOrder)do if not C.ById[id].retired then active+=1 end end
		if active~=GoldenPool.count or C.Price~=GoldenPool.price then assert(C.PoolVersion>GoldenPool.version,"bump PoolVersion")end
		for _,piece in ipairs(C.Pieces)do
			assert(#piece.id<=24 and piece.id:match("^[a-z]+$"),piece.id)
			assert(#piece.text<=10,"pieces stay at 10 letters or fewer: "..piece.text)
		end
	end)

	test("catalogue: display, validChoice, earned rules (best pet total, any pet level, distinct book claims)",function()
		assert(C.display({"biscuit","sprout"},"Bear")=="Biscuit Sprout"and C.display({"velvet"},"Bear")=="Velvet")
		assert(C.display({"biscuit","nope"},"Bear")=="Bear"and C.display({},"Bear")=="Bear"and C.display(nil,"Bear")=="Bear")
		assert(C.validChoice({"biscuit"},{"biscuit"})and C.validChoice({},{}))
		assert(select(2,C.validChoice({"biscuit","biscuit"},{"biscuit"}))=="SamePiece")
		assert(select(2,C.validChoice({"velvet"},{"biscuit"}))=="NotOwned")
		assert(select(2,C.validChoice({"zzz"},{"zzz"}))=="UnknownPiece")
		assert(select(2,C.validChoice({"biscuit","puddle","parade"},{"biscuit","puddle","parade"}))=="InvalidName")
		local function lv(t)local r={};for _,s in ipairs(Stat.Order)do r[s]=t[s]or 1 end;return r end
		-- Two pets at total 40 each: no Sprout (60 is the best pet's total, not a sum).
		local e=C.earnedIds({levels={lv({heart=10,power=10,energy=10,jump=5}),lv({heart=10,power=10,energy=10,jump=5})},claimed=0})
		assert(table.find(e,"cuddle")and table.find(e,"bonk")and table.find(e,"fizz")and not table.find(e,"sprout")and not table.find(e,"boing"))
		e=C.earnedIds({levels={lv({speed=25,heart=20,power=20})},claimed=12})
		assert(table.find(e,"zoomies")and table.find(e,"speedy")and not table.find(e,"rocket")and table.find(e,"sprout"))
		assert(table.find(e,"dogear")and table.find(e,"bookworm")and table.find(e,"footnote")and not table.find(e,"librarian"))
		e=C.earnedIds({levels={lv({jump=99})},claimed=0})
		assert(table.find(e,"champion")and table.find(e,"moonbounce"))
		assert(C.pick({"a","b","c"},"fixed",.9)=="a"and C.pick({"a","b","c"},"random",0)=="a"and C.pick({"a","b","c"},"random",.999999)=="c"and C.pick({"a","b","c"},"random",1)=="c")
	end)

	test("load: an old save gets the six starters once; no pet, no pieces; earned pieces granted at load",function()
		local h=ready()
		for _,id in ipairs(C.starterIds())do assert(owns(h,id),id)end
		assert(h.state.names.starter==1 and #N.owned(h.state)==6)
		local h0=ready({inventoryMask=0,names=NONE})
		assert(#N.owned(h0.state)==0)
		local h2=ready({petStats={pip={speed=Stat.xpFor(25),heart=Stat.xpFor(10)}},statsSeed=1,book={found=0,claimed={"balls.25","toys.25"}}})
		assert(owns(h2,"zoomies")and owns(h2,"speedy")and owns(h2,"cuddle")and not owns(h2,"rocket"))
		assert(owns(h2,"dogear")and not owns(h2,"bookworm"),"two claims: Dogear only")
	end)

	test("transact: a save whose stats rose gets the piece in the same write as any operation",function()
		local h,db=ready()
		assert(not owns(h,"boing"))
		db.player_1.hatching.petStats={pip={jump=Stat.xpFor(10)}}
		h.state.petStats={pip={jump=Stat.xpFor(10)}}
		local ok,why=H.setPetName(h,"pip",{"biscuit"})
		assert(ok,why)
		assert(owns(h,"boing")and table.find(db.player_1.hatching.names.owned,"boing"))
		-- Retuning XP down never takes the piece away.
		db.player_1.hatching.petStats={pip={jump=0}};h.state.petStats={pip={jump=0}}
		assert(H.setPetName(h,"pip",{"puddle"}))
		assert(owns(h,"boing"))
	end)

	test("catchUp: an error is contained (old value restored), an invalid result is restored",function()
		local h=ready()
		local state=copy(h.state)
		local before=copy(state.names)
		state.book={claimed=setmetatable({},{__index=function()error("boom")end,__len=function()error("boom")end})}
		local added=H.catchUpNames(state)
		assert(#added==0 and #state.names.owned==#before.owned)
		local s2=copy(h.state);s2.names.owned={}
		for i=1,N.OwnedStored do s2.names.owned[i]="junk"..i end
		H.catchUpNames(s2)
		assert(#s2.names.owned==N.OwnedStored and N.valid(s2))
	end)

	test("Names Egg (restricted): the fixed next piece, debit, receipt, replay is AlreadySaved, reuse is OperationConflict",function()
		local h=ready(nil,20)
		local pub=H.public(h).names
		assert(pub.mode=="fixed"and pub.next=="velvet"and #pub.remaining==20)
		local ok,why,receipt=H.nameEggBuy(h,"n1",pub.quoteKey)
		assert(ok and why=="Saved"and receipt.piece=="velvet"and receipt.cost==8 and receipt.digest==nil,tostring(why))
		assert(h.state.nectar==12 and owns(h,"velvet"))
		local ok2,why2,r2=H.nameEggBuy(h,"n1",pub.quoteKey)
		assert(ok2 and why2=="AlreadySaved"and r2.piece=="velvet"and h.state.nectar==12)
		assert(select(2,H.nameEggBuy(h,"n1",quote(h)))=="OperationConflict")
		-- A stale quote with a new op is PoolChanged, no charge.
		assert(select(2,H.nameEggBuy(h,"n2",pub.quoteKey))=="PoolChanged"and h.state.nectar==12)
		assert(H.public(h).names.next=="sidequest")
		assert(H.nameEggBuy(h,"n3",quote(h)))
		assert(owns(h,"sidequest")and h.state.nectar==4)
		assert(select(2,H.nameEggBuy(h,"n4",quote(h)))=="NeedStars"and h.state.nectar==4)
	end)

	test("Names Egg (random): one equally likely remaining piece, never a duplicate; all owned refuses",function()
		local h,_,c=ready(nil,1000)
		h.restricted=false
		local pub=H.public(h).names
		assert(pub.mode=="random"and pub.next==nil)
		c.rand={.999}
		local ok,_,receipt=H.nameEggBuy(h,"r1",pub.quoteKey)
		assert(ok and receipt.piece=="afterparty"and receipt.mode=="r")
		-- The quote pins the mode: a policy flip makes the old quote PoolChanged.
		local key=quote(h);h.restricted=true
		assert(select(2,H.nameEggBuy(h,"r2",key))=="PoolChanged")
		h.restricted=false
		for i=1,19 do c.rand={0};assert(H.nameEggBuy(h,"rr"..i,quote(h)))end
		local seen={};for _,id in ipairs(N.owned(h.state))do assert(not seen[id],"duplicate "..id);seen[id]=true end
		for _,id in ipairs(C.EggOrder)do assert(seen[id])end
		assert(#H.public(h).names.remaining==0)
		assert(select(2,H.nameEggBuy(h,"r99",quote(h)))=="AllOwned"and h.state.nectar==1000-160)
	end)

	test("Names Egg: a commit whose reply is lost is Retrying; a new op is Pending; the same op replays, one debit",function()
		local h,db,c=ready(nil,20)
		local key=quote(h)
		c.throwAfter=true
		local ok,why=H.nameEggBuy(h,"t1",key)
		assert(not ok and why=="Retrying",tostring(why))
		assert(db.player_1.hatching.nectar==12,"the write committed")
		assert(select(2,H.nameEggBuy(h,"t2",key))=="Pending")
		local ok2,why2,receipt=H.nameEggBuy(h,"t1",key)
		assert(ok2 and receipt and receipt.piece=="velvet",tostring(why2))
		assert(h.state.nectar==12 and db.player_1.hatching.nectar==12 and #N.owned(h.state)==7)
		local ok3,why3=H.nameEggBuy(h,"t1",key)
		assert(ok3 and why3=="AlreadySaved"and h.state.nectar==12)
		-- A rename whose reply is lost resumes the same write.
		c.throwAfter=true
		assert(select(2,H.setPetName(h,"pip",{"velvet"}))=="Retrying")
		assert(H.setPetName(h,"pip",{"velvet"}))
		assert(N.petName(h.state,"pip")[1]=="velvet")
	end)

	test("rename: owned distinct pieces only, unowned pet refused, same name Unchanged, clear, public ids only",function()
		local h=ready(nil,20)
		assert(select(2,H.setPetName(h,"pip",{"velvet"}))=="NotOwned")
		assert(select(2,H.setPetName(h,"pip",{"biscuit","biscuit"}))=="SamePiece")
		assert(select(2,H.setPetName(h,"pip",{"nope"}))=="UnknownPiece")
		assert(select(2,H.setPetName(h,"pip",{"biscuit","puddle","parade"}))=="InvalidName")
		assert(select(2,H.setPetName(h,"blip",{"biscuit"}))=="Unowned")
		local rev=h.state.revision
		assert(H.setPetName(h,"pip",{"biscuit","parade"}))
		assert(h.state.revision==rev+1)
		local ok,why=H.setPetName(h,"pip",{"biscuit","parade"})
		assert(ok and why=="Unchanged"and h.state.revision==rev+1)
		local public=N.publicNames(h.state)
		assert(public.v==1 and public.pets.pip[1]=="biscuit"and public.pets.pip[2]=="parade")
		assert(H.public(h).names.petNames.pip[2]=="parade")
		assert(H.setPetName(h,"pip",{}))
		assert(h.state.petNames==nil and next(N.publicNames(h.state).pets)==nil)
	end)

	test("tolerant load: unknown ids and fields kept, malformed parts repaired, never a failed load",function()
		local h=ready({names={owned={"biscuit","later_piece","biscuit",7},serial=-3,receipts={{op="x",kind="egg"},"bad"},extra={keep=true}},
			petNames={pip={"biscuit","later_piece"},blip="bad",[5]={"x"}}})
		assert(h.status=="Ready")
		assert(owns(h,"later_piece")and h.state.names.extra.keep==true,"unknown kept")
		local n=0;for _,id in ipairs(h.state.names.owned)do if id=="biscuit"then n+=1 end end
		assert(n==1,"deduped")
		assert(h.state.names.serial==0 and #h.state.names.receipts==1)
		assert(h.state.petNames.pip[2]=="later_piece"and h.state.petNames.blip==nil)
		assert(C.display(h.state.petNames.pip,"Bear")=="Bear","unknown piece shows the species name")
		local h2=ready({names="garbage",petNames=7})
		assert(h2.status=="Ready"and #N.owned(h2.state)==6 and h2.state.petNames==nil)
		-- A later build may store up to 4 ids per pet and longer ids: still valid here.
		assert(N.valid({petNames={pip={"a","b","c","d"}},names={owned={string.rep("a",40)}}}))
		assert(not N.valid({petNames={pip={"a","b","c","d","e"}}}))
	end)

	print(("[PetNames] %d passed: %s"):format(#cases,table.concat(cases," | ")))
	return #cases
end
