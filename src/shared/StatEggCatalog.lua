-- Stat Eggs (v2, V2-SCOPE-2026-11-19 section 5 revision 2; V2-PET-AND-SNACKS-SCOPE-2026-11-19 part 2).
-- Pure data and rules; the server rolls (StatEggState), the client only displays.
--
-- A Stat Egg hatches one Stat Snack (scope 5's Boost Treat): a stat (each stat of the pet that is
-- out below 99, equally likely) and a size. Fed to a pet, it queues a boost on that stat: the next
-- `xp` XP earned by playing counts `mult` times. No XP of its own, no timer.
--
-- Saved-data rules (as LookEggCatalog):
--  * Stored bounds are frozen constants (the *Limit / *Stored values). Tunable values (Price,
--    DailyBuys, FreeLimit, PouchSize, QueueRoom, PityAt, Sizes, Cycle) never validate a save.
--  * Retuning Sizes, PityAt or Cycle is a new PoolVersion (append it to PoolVersions).
--  * Prices only grows: a stored receipt keeps the price it was charged.
--  * Size ids and the stat ids (StatCatalog.Order) are frozen: append only.
local Shared=script.Parent
local Stats=require(Shared.StatCatalog)

local Catalog={
	Enabled=true,
	PoolVersion=1,
	PoolVersions=table.freeze({[1]=true}),
	Price=15, -- [PLACEHOLDER] Stars (scope 5.4)
	Prices=table.freeze({[15]=true}),
	DailyBuys=3, -- [PLACEHOLDER] bought eggs a day from the nest's stock
	FreeLimit=10, -- free eggs kept until opened
	PouchSize=12, -- [PLACEHOLDER] snacks held (pet-and-snacks 2.2)
	QueueRoom=3, -- [PLACEHOLDER] boosts queued per stat (pet-and-snacks 2.4 check 4)
	PityAt=8, -- [PLACEHOLDER] a Feast within 8 eggs: after 7 without one, the 8th is a Feast
	MaxMult=3, -- the most any XP can count (Feast); Bonus XP and a boost never multiply together
	FeedCooldown=1.5, -- seconds between accepted feeds (host)
	-- Frozen stored bounds.
	MissesLimit=63,
	CycleLimit=63,
	CursorLimit=15,
	FreeStored=63,
	BoughtLimit=1000,
	PouchStored=64,
	ReceiptStored=64,
	ReceiptKeep=32, -- tunable: receipts kept (the quote key carries `serial`, so an old op id can never charge twice)
	SerialLimit=2147483647,
	IdLength=40,
	SizeOrder=table.freeze({"nibble","snack","feast"}),
	-- [PLACEHOLDER] boosts and odds (scope 5.1; pet-and-snacks 2.1 looks).
	Sizes=table.freeze({
		nibble=table.freeze({id="nibble",name="Nibble",mult=2,xp=50,weight=60,bites=2,layers=1,width=.2}),
		snack=table.freeze({id="snack",name="Snack",mult=2,xp=120,weight=30,bites=3,layers=2,width=.25}),
		feast=table.freeze({id="feast",name="Feast",mult=3,xp=120,weight=10,bites=4,layers=3,width=.3}),
	}),
	-- Restricted accounts (no roll, scope 5.5): sizes in this disclosed ten-egg cycle (6 Nibble,
	-- 3 Snack, 1 Feast: the same average), stats in panel order.
	Cycle=table.freeze({"nibble","nibble","snack","nibble","snack","nibble","nibble","snack","nibble","feast"}),
}
local total=0
for _,id in ipairs(Catalog.SizeOrder)do
	local size=Catalog.Sizes[id]
	assert(size and size.mult>=1 and size.mult<=Catalog.MaxMult and size.xp>=1,"StatEggCatalog: size "..id)
	total+=size.weight
end
assert(total==100,"StatEggCatalog: size weights sum to "..total)
assert(#Catalog.Cycle<=Catalog.CycleLimit+1,"StatEggCatalog: cycle too long")
assert(#Stats.Order<=Catalog.CursorLimit+1,"StatEggCatalog: cursor bound")

local function integer(n,maximum)return type(n)=="number"and n==n and n%1==0 and n>=0 and n<=maximum end
Catalog.integer=integer

function Catalog.size(id)return if type(id)=="string"then Catalog.Sizes[id]else nil end
function Catalog.selectionMode(restricted)return if restricted==false then "random"else "fixed"end

-- Stats of one pet below 99, in panel order. `levels` maps stat id -> level.
function Catalog.eligible(levels)
	local result={}
	for _,id in ipairs(Stats.Order)do
		local level=if type(levels)=="table"then levels[id]else nil
		if not(type(level)=="number"and level>=Stats.MaxLevel)then table.insert(result,id)end
	end
	return result
end
function Catalog.mask(eligible)
	local mask=0
	for index,id in ipairs(Stats.Order)do if table.find(eligible,id)then mask=bit32.bor(mask,bit32.lshift(1,index-1))end end
	return mask
end

function Catalog.pityDue(misses)return integer(misses,Catalog.MissesLimit)and misses>=Catalog.PityAt-1 end
-- Eggs until a Feast is promised (1 = the next egg).
function Catalog.pityLeft(misses)
	return math.max(1,Catalog.PityAt-(if integer(misses,Catalog.MissesLimit)then misses else 0))
end
-- The size odds for the next random egg, in SizeOrder: {id, percent}. A due promise is Feast 100%.
function Catalog.sizeOdds(misses)
	local due=Catalog.pityDue(misses)
	local rows={}
	for _,id in ipairs(Catalog.SizeOrder)do
		table.insert(rows,{id=id,percent=if due then(if id=="feast"then 100 else 0)else Catalog.Sizes[id].weight})
	end
	return rows
end

-- Server roll: units in [0,1). The stat is uniform over `eligible`; the size follows sizeOdds.
function Catalog.roll(unitStat,unitSize,eligible,misses)
	local function unit(u)return type(u)=="number"and u==u and u>=0 and u<1 end
	if not unit(unitStat)or not unit(unitSize)or type(eligible)~="table"or #eligible==0 then return nil end
	local stat=eligible[math.min(#eligible,math.floor(unitStat*#eligible)+1)]
	local target,cumulative,size=unitSize*100,0,nil
	for _,row in ipairs(Catalog.sizeOdds(misses))do
		cumulative+=row.percent
		if row.percent>0 and target<cumulative then size=row.id;break end
	end
	if not size then -- floating-point endpoint: the last size with a chance
		for _,row in ipairs(Catalog.sizeOdds(misses))do if row.percent>0 then size=row.id end end
	end
	return stat,size
end

-- Restricted accounts: the next fixed snack. Size from the cycle; stat = the first eligible stat at
-- or after `statCursor` in panel order (wrapping). Returns stat, size, nextCycle, nextCursor.
function Catalog.fixedNext(eligible,cycleIndex,statCursor)
	if type(eligible)~="table"or #eligible==0 then return nil end
	cycleIndex=if integer(cycleIndex,Catalog.CycleLimit)then cycleIndex else 0
	statCursor=if integer(statCursor,Catalog.CursorLimit)then statCursor else 0
	local n=#Stats.Order
	local size=Catalog.Cycle[(cycleIndex%#Catalog.Cycle)+1]
	for step=0,n-1 do
		local index=((statCursor+step)%n)+1
		local id=Stats.Order[index]
		if table.find(eligible,id)then return id,size,(cycleIndex+1)%#Catalog.Cycle,index%n end
	end
	return nil
end

-- Binds a buy to the odds the player saw: pool, price, mode, the eligible stats, the promise
-- counter, the restricted position and the snack serial (so each quote is used once).
function Catalog.quoteKey(mode,eligible,misses,cycleIndex,statCursor,serial)
	return string.format("%d|%d|%s|%d|%d|%d|%d|%d",Catalog.PoolVersion,Catalog.Price,if mode=="random"then "r"else "f",
		Catalog.mask(eligible),if integer(misses,Catalog.MissesLimit)then misses else 0,
		if integer(cycleIndex,Catalog.CycleLimit)then cycleIndex else 0,
		if integer(statCursor,Catalog.CursorLimit)then statCursor else 0,
		if integer(serial,Catalog.SerialLimit)then serial else 0)
end

return table.freeze(Catalog)
