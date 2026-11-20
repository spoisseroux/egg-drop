-- Stat Eggs and the snack pouch (v2; V2-SCOPE-2026-11-19 section 5, V2-PET-AND-SNACKS-SCOPE part 2,
-- V2-FEEDING-RUNES-ONBOARDING 2.5). Optional, additive fields on the hatching save (v11, no version
-- bump), the BondState / StatState pattern:
--   snackPouch = { {id=int, stat="jump", size="snack"}, ... }   held snacks, oldest first
--   statEgg    = { boughtDay="<day>", boughtCount=n, misses=n, cycleIndex=n, statCursor=n,
--                  free=n, freeDay="<day>", serial=n, receipts={ {op=..., kind=..., digest=...}, ... } }
-- The boosts a fed snack queues live in StatState (`petBoosts`).
--
-- Missing is valid (every save before this build). Every field inside statEgg is optional too.
-- Well-formed unknown stat, size and pet ids and unknown keys are kept (a later build may add
-- them). A malformed part is repaired at load one subfield at a time (sanitize), never a failed
-- load and never the loss of the paid snacks or banked free eggs beside it.
--
-- Architect review (2026-11-19), applied:
--  * Every bound in `valid` is a frozen StatEggCatalog constant, never a tuning value.
--  * Snack ids are unique in the pouch and never above `serial`; sanitize lifts `serial` to the
--    highest id it has seen, so a repaired save never reuses an id.
--  * The bought day never moves backward (a server whose clock is behind refuses with no charge).
--  * A receipt stores the digest of its request: a replay with the same op id is exact proof
--    ("AlreadySaved"), another request reusing the id is "OperationConflict".
--  * The quote key carries `serial`, so a quote is good for one egg only.
--  * grantDaily never makes the save invalid (it would fail the round award): it writes a copy and
--    restores the old value if the result does not validate.
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.StatEggCatalog)
local StatCatalog=require(Shared.StatCatalog)
local Eggs=require(Shared.EggCatalog)
local Stats=require(script.Parent.StatState)
local Guard=require(script.Parent.HatchGuard)

local State={}
local integer=Catalog.integer
local function id(value,length)return type(value)=="string"and #value>=1 and #value<=(length or Catalog.IdLength)end
local function canonicalDay(value)
	local number=if type(value)=="string"then tonumber(value)else nil
	return number~=nil and number==math.floor(number)and math.abs(number)<=1000000000 and tostring(number)==value
end
local function count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end
local function isArray(t)return type(t)=="table"and count(t)==#t end
local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end

local function validSnack(snack)
	return type(snack)=="table"and integer(snack.id,Catalog.SerialLimit)and snack.id>=1 and id(snack.stat)and id(snack.size)
end
-- Code review: only the fields this build reads are checked, so a later build may add receipt
-- fields of any shape without making this build's valid() fail (and the session with it).
local function validReceipt(r)
	if type(r)~="table"or not id(r.op,80)or not id(r.kind,16)then return false end
	if r.digest~=nil and not(type(r.digest)=="string"and #r.digest<=160)then return false end
	return r.snackId==nil or(integer(r.snackId,Catalog.SerialLimit))
end
local statEggChecks={
	boughtDay=canonicalDay,freeDay=canonicalDay,
	boughtCount=function(v)return integer(v,Catalog.BoughtLimit)end,
	misses=function(v)return integer(v,Catalog.MissesLimit)end,
	cycleIndex=function(v)return integer(v,Catalog.CycleLimit)end,
	statCursor=function(v)return integer(v,Catalog.CursorLimit)end,
	free=function(v)return integer(v,Catalog.FreeStored)end,
	serial=function(v)return integer(v,Catalog.SerialLimit)end,
	receipts=function(list)
		if not isArray(list)or #list>Catalog.ReceiptStored then return false end
		for _,r in ipairs(list)do if not validReceipt(r)then return false end end
		return true
	end,
}

-- Tolerant: every field may be missing. Unknown keys inside statEgg are kept untouched.
function State.valid(state)
	local pouch,egg=state.snackPouch,state.statEgg
	local highest=0
	if pouch~=nil then
		if not isArray(pouch)or #pouch>Catalog.PouchStored then return false end
		local seen={}
		for _,snack in ipairs(pouch)do
			if not validSnack(snack)or seen[snack.id]then return false end
			seen[snack.id]=true;highest=math.max(highest,snack.id)
		end
	end
	if egg~=nil then
		if type(egg)~="table"then return false end
		for key,check in pairs(statEggChecks)do if egg[key]~=nil and not check(egg[key])then return false end end
		for _,r in ipairs(egg.receipts or {})do if r.snackId then highest=math.max(highest,r.snackId)end end
	end
	if highest>0 and(egg==nil or not integer(egg.serial,Catalog.SerialLimit)or egg.serial<highest)then return false end
	return true
end

-- Load-time repair, one subfield at a time.
function State.sanitize(state)
	if type(state)~="table"then return end
	local highest=0
	if state.snackPouch~=nil then
		if type(state.snackPouch)~="table"then state.snackPouch=nil
		else
			local kept,seen={},{}
			for _,snack in ipairs(state.snackPouch)do
				if #kept<Catalog.PouchStored and validSnack(snack)and not seen[snack.id]then
					seen[snack.id]=true;highest=math.max(highest,snack.id)
					table.insert(kept,copy(snack))
				end
			end
			state.snackPouch=kept
		end
	end
	if state.statEgg~=nil then
		if type(state.statEgg)~="table"then state.statEgg=nil
		else
			local egg=state.statEgg
			for key,check in pairs(statEggChecks)do
				if key~="receipts"and egg[key]~=nil and not check(egg[key])then
					local v=egg[key]
					-- Numbers out of range clamp; anything else is dropped.
					if type(v)=="number"and v==v and key~="boughtDay"and key~="freeDay"then
						local bound=({boughtCount=Catalog.BoughtLimit,misses=Catalog.MissesLimit,cycleIndex=Catalog.CycleLimit,
							statCursor=Catalog.CursorLimit,free=Catalog.FreeStored,serial=Catalog.SerialLimit})[key]
						egg[key]=if bound and math.abs(v)~=math.huge then math.clamp(math.floor(v),0,bound)else nil
					else egg[key]=nil end
				end
			end
			if egg.receipts~=nil then
				local kept={}
				if type(egg.receipts)=="table"then
					for _,r in ipairs(egg.receipts)do if validReceipt(r)then table.insert(kept,r)end end
				end
				while #kept>Catalog.ReceiptStored do table.remove(kept,1)end
				egg.receipts=kept
			end
		end
	end
	for _,r in ipairs(state.statEgg and state.statEgg.receipts or {})do if r.snackId then highest=math.max(highest,r.snackId)end end
	if highest>0 then
		local egg=state.statEgg or {}
		egg.serial=math.max(if integer(egg.serial,Catalog.SerialLimit)then egg.serial else 0,highest)
		state.statEgg=egg
	end
end

-- Reads (a missing field reads as empty).
local function egg(state)return if type(state.statEgg)=="table"then state.statEgg else {}end
local function field(state,key,default)local v=egg(state)[key];return if statEggChecks[key]and v~=nil and statEggChecks[key](v)then v else default end
function State.pouch(state)return if isArray(state.snackPouch)then state.snackPouch else {}end
function State.free(state)return field(state,"free",0)end
function State.misses(state)return field(state,"misses",0)end
function State.serial(state)return field(state,"serial",0)end
-- Eggs bought on `today` (a clock behind the saved day reads as sold out).
function State.boughtToday(state,today)
	local day=field(state,"boughtDay",nil)
	if not day or not canonicalDay(today)then return 0 end
	if tonumber(today)<tonumber(day)then return Catalog.DailyBuys end
	return if day==today then field(state,"boughtCount",0)else 0
end
function State.receipt(state,op)
	for _,r in ipairs(field(state,"receipts",{}))do if r.op==op then return r end end
	return nil
end
function State.levels(state,petId)
	local levels={}
	for _,stat in ipairs(StatCatalog.Order)do levels[stat]=StatCatalog.levelFor(Stats.xp(state,petId,stat))end
	return levels
end
function State.eligible(state,petId)return Catalog.eligible(State.levels(state,petId))end
function State.quoteKey(state,petId,mode)
	return Catalog.quoteKey(mode,State.eligible(state,petId),State.misses(state),field(state,"cycleIndex",0),field(state,"statCursor",0),State.serial(state))
end

local function writeEgg(state,changes)
	local next=copy(egg(state))
	for key,value in pairs(changes)do next[key]=value end
	state.statEgg=next
end
local function pushReceipt(state,r)
	local list=copy(field(state,"receipts",{}))
	table.insert(list,r)
	while #list>Catalog.ReceiptKeep do table.remove(list,1)end
	writeEgg(state,{receipts=list})
end

-- One Stat Egg, inside the transaction. c = {op, digest, petId, free, day, mode, quoteKey,
-- unitStat, unitSize} (units only in random mode, drawn once at request time and frozen in the
-- pending candidate, so a retried write rolls the same snack). `today` is the callback's clock.
function State.buy(state,c,today)
	if not Catalog.Enabled then return false,"Disabled"end
	local saved=State.receipt(state,c.op)
	if saved then return false,if saved.digest==c.digest then "AlreadySaved"else "OperationConflict"end
	if not Eggs.isOwned(state.inventoryMask or 0,c.petId)then return false,"Unowned"end
	if c.day~=today then return false,"ExpiredDay"end
	local boughtDay=field(state,"boughtDay",nil)
	if boughtDay and tonumber(today)<tonumber(boughtDay)then return false,"ClockRollback"end
	local eligible=State.eligible(state,c.petId)
	if #eligible==0 then return false,"AllMaxed"end
	if #State.pouch(state)>=Catalog.PouchSize then return false,"PouchFull"end
	if State.quoteKey(state,c.petId,c.mode)~=c.quoteKey then return false,"PoolChanged"end
	local bought=State.boughtToday(state,today)
	if c.free then
		if State.free(state)<1 then return false,"NoFreeEgg"end
	else
		if bought>=Catalog.DailyBuys then return false,"SoldOut"end
		if state.nectar<Catalog.Price then return false,"NeedStars"end
	end
	local misses=State.misses(state)
	local stat,size,nextCycle,nextCursor
	if c.mode=="random"then
		stat,size=Catalog.roll(c.unitStat,c.unitSize,eligible,misses)
	else
		stat,size,nextCycle,nextCursor=Catalog.fixedNext(eligible,field(state,"cycleIndex",0),field(state,"statCursor",0))
	end
	if not stat or not size then return false,"InvalidRoll"end
	local serial=State.serial(state)+1
	if serial>Catalog.SerialLimit then return false,"SnackLimit"end
	local pouch=copy(State.pouch(state))
	table.insert(pouch,{id=serial,stat=stat,size=size})
	state.snackPouch=pouch
	local changes={serial=serial,misses=if size=="feast"then 0 else math.min(misses+1,Catalog.MissesLimit)}
	if nextCycle then changes.cycleIndex=nextCycle;changes.statCursor=nextCursor end
	local cost=0
	if c.free then changes.free=State.free(state)-1
	else
		cost=Catalog.Price;state.nectar-=cost
		changes.boughtDay=today;changes.boughtCount=bought+1
	end
	writeEgg(state,changes)
	pushReceipt(state,{op=c.op,kind="buy",digest=c.digest,snackId=serial,stat=stat,size=size,petId=c.petId,free=c.free==true,cost=cost,mode=c.mode,day=today})
	return true
end

-- Feeding one snack, inside the transaction. c = {op, digest, snackId, petId}. The host has
-- already checked the live conditions (the pet is out, no round, park, care or carry).
function State.feed(state,c)
	local saved=State.receipt(state,c.op)
	if saved then return false,if saved.digest==c.digest then "AlreadySaved"else "OperationConflict"end
	if not Eggs.isOwned(state.inventoryMask or 0,c.petId)then return false,"Unowned"end
	if Guard.other(state,"snack")then return false,"RevealPending"end
	local pouch=State.pouch(state)
	local index
	for i,snack in ipairs(pouch)do if snack.id==c.snackId then index=i;break end end
	if not index then return false,"NoSnack"end
	local snack=pouch[index]
	local size=Catalog.size(snack.size)
	if not size or not StatCatalog.ById[snack.stat]then return false,"UnknownSnack"end
	if StatCatalog.levelFor(Stats.xp(state,c.petId,snack.stat))>=StatCatalog.MaxLevel then return false,"StatMaxed"end
	if #Stats.boosts(state,c.petId,snack.stat)>=Catalog.QueueRoom then return false,"QueueFull"end
	if not Stats.queueBoost(state,c.petId,snack.stat,size.mult,size.xp)then return false,"QueueFull"end
	local nextPouch=copy(pouch);table.remove(nextPouch,index);state.snackPouch=nextPouch
	pushReceipt(state,{op=c.op,kind="feed",digest=c.digest,snackId=snack.id,stat=snack.stat,size=snack.size,petId=c.petId,mult=size.mult,left=size.xp})
	return true
end

-- The free daily egg, inside the round award when a round finished (scope 5.4). Once per day; the
-- day never moves backward; a full bank (FreeLimit) spends the day without adding. Never fails the
-- award: returns true when an egg was added.
function State.grantDaily(state,day)
	if not Catalog.Enabled or type(state)~="table"or not canonicalDay(day)then return false end
	if state.statEgg~=nil and type(state.statEgg)~="table"then return false end
	local freeDay=field(state,"freeDay",nil)
	if freeDay and tonumber(day)<=tonumber(freeDay)then return false end
	local before=state.statEgg
	local free=State.free(state)
	local added=free<Catalog.FreeLimit
	writeEgg(state,{freeDay=day,free=if added then free+1 else free})
	if not State.valid(state)then state.statEgg=before;return false end
	return added
end

function State.publicReceipt(r)
	if type(r)~="table"then return nil end
	local result=copy(r);result.digest=nil;return result
end

-- For the client: the pouch, eggs left, the pity counter and, per owned pet, the quote key and
-- the pool (and the fixed next snack for a restricted player).
function State.public(state,today,mode)
	local quotes={}
	for petId in pairs(require(Shared.PetCatalog).byId)do
		if Eggs.isOwned(state.inventoryMask or 0,petId)then
			local eligible=State.eligible(state,petId)
			local entry={key=State.quoteKey(state,petId,mode),eligible=eligible}
			if mode~="random"then
				local stat,size=Catalog.fixedNext(eligible,field(state,"cycleIndex",0),field(state,"statCursor",0))
				entry.next=if stat then {stat=stat,size=size}else nil
			end
			quotes[petId]=entry
		end
	end
	local receipts=field(state,"receipts",{})
	return {
		enabled=Catalog.Enabled,mode=mode,poolVersion=Catalog.PoolVersion,price=Catalog.Price,
		pouch=copy(State.pouch(state)),pouchSize=Catalog.PouchSize,
		free=State.free(state),freeLimit=Catalog.FreeLimit,
		boughtToday=State.boughtToday(state,today),dailyBuys=Catalog.DailyBuys,
		misses=State.misses(state),pityLeft=Catalog.pityLeft(State.misses(state)),
		cycleIndex=field(state,"cycleIndex",0),
		quotes=quotes,last=State.publicReceipt(receipts[#receipts]),
	}
end

return State
