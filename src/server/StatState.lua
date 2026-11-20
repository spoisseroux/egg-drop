-- Pet stats XP (v2 slice S1, V2-SCOPE-2026-11-19 sections 3 and 10). Optional, additive fields on
-- the hatching save (v11, no version bump), the BondState pattern:
--   petStats  = { [petId] = { [statId] = xp } }       per pet, XP only (levels come from StatCatalog)
--   statBonus = { day = "<day>", left = { [statId] = n } }   player-wide Bonus XP still to double
--   statsSeed = 1                                       the seed version that credited past play once
-- Missing is valid (every save before this build). A malformed field is repaired at load
-- (sanitize), never a failed load. XP is written only inside transactions that already exist,
-- through `grant`, which never fails.
--
-- Architect review (2026-11-19):
--  * Storage limits in `valid` are hard-coded constants, never the tuning values, so lowering a
--    tuning value can never make an older or newer save invalid on another server.
--  * Well-formed unknown pet and stat ids are kept (a later build may add them), under a count limit.
--  * The seed runs once: a save counts as seeded when statsSeed >= 1 or petStats exists. It reads
--    only the snapshot (no clock), so a retried load callback seeds identically.
--  * The bonus day never moves backward (servers' clocks differ).
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.StatCatalog)
local Eggs=require(Shared.EggCatalog)
local Pets=require(Shared.PetCatalog)
local EggRules=require(Shared.StatEggCatalog)

local State={}
-- Frozen storage bounds (never tie these to tuning values).
State.StoredMaxXP=2000000000
State.StoredMaxLeft=100000
State.PetLimit=32 -- frozen: the bit32 inventory mask allows 32 pets (code review)
State.StatLimit=16
State.IdLength=40
State.SeedVersion=1
State.SeedPet="pip" -- the only pet before stats; past play is credited to it

local function integer(value,maximum)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=maximum
end
local function id(value)return type(value)=="string"and #value>=1 and #value<=State.IdLength end
local function canonicalDay(value)
	local number=if type(value)=="string"then tonumber(value)else nil
	return number~=nil and number==math.floor(number)and math.abs(number)<=1000000000 and tostring(number)==value
end
local function count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end

local function validStats(stats)
	if type(stats)~="table"or count(stats)>State.StatLimit then return false end
	for stat,xp in pairs(stats)do if not id(stat)or not integer(xp,State.StoredMaxXP)then return false end end
	return true
end

-- Tolerant: every field may be missing.
function State.valid(state)
	local petStats=state.petStats
	if petStats~=nil then
		if type(petStats)~="table"or count(petStats)>State.PetLimit then return false end
		for pet,stats in pairs(petStats)do if not id(pet)or not validStats(stats)then return false end end
	end
	local bonus=state.statBonus
	if bonus~=nil then
		if type(bonus)~="table"or not canonicalDay(bonus.day)or type(bonus.left)~="table"or count(bonus.left)>State.StatLimit then return false end
		for stat,n in pairs(bonus.left)do if not id(stat)or not integer(n,State.StoredMaxLeft)then return false end end
	end
	if state.statsSeed~=nil and not integer(state.statsSeed,1000)then return false end
	return true
end

-- Load-time repair: keep well-formed entries (XP clamped to the stored bound), drop the rest.
-- Known ids first (catalogue order), then unknown well-formed ones, so the result is stable.
-- Known ids first (catalogue order), then unknown ones sorted (code review: sanitize must not
-- drop known pets or stats in favour of unknown ones).
local knownRank={}
for i,pet in ipairs(Pets.collection)do knownRank[pet.id]=i end
for i,stat in ipairs(Catalog.Order)do knownRank[stat]=knownRank[stat]or i end
local function sortedKeys(t)
	local keys={};for k in pairs(t)do if type(k)=="string"then table.insert(keys,k)end end
	table.sort(keys,function(a,b)
		local ra,rb=knownRank[a],knownRank[b]
		if ra and rb then return ra<rb end
		if ra or rb then return ra~=nil end
		return a<b
	end)
	return keys
end
local function cleanStats(value)
	if type(value)~="table"then return nil end
	local result,n={},0
	for _,stat in ipairs(sortedKeys(value))do
		local xp=value[stat]
		if n<State.StatLimit and id(stat)and type(xp)=="number"and xp==xp and xp>=0 and xp~=math.huge then
			result[stat]=math.min(math.floor(xp),State.StoredMaxXP);n+=1
		end
	end
	return result
end
function State.sanitizePetStats(value)
	if type(value)~="table"then return nil end
	local result,n={},0
	for _,pet in ipairs(sortedKeys(value))do
		local stats=id(pet)and cleanStats(value[pet])
		if stats and n<State.PetLimit then result[pet]=stats;n+=1 end
	end
	return result
end
function State.sanitizeBonus(value)
	if type(value)~="table"or not canonicalDay(value.day)or type(value.left)~="table"then return nil end
	local left,n={},0
	for _,stat in ipairs(sortedKeys(value.left))do
		local v=value.left[stat]
		if n<State.StatLimit and id(stat)and type(v)=="number"and v==v and v>=0 and v~=math.huge then
			left[stat]=math.min(math.floor(v),State.StoredMaxLeft);n+=1
		end
	end
	return {day=value.day,left=left}
end
function State.sanitize(state)
	if type(state)~="table"then return end
	if state.petStats~=nil then state.petStats=State.sanitizePetStats(state.petStats)end
	if state.statBonus~=nil then state.statBonus=State.sanitizeBonus(state.statBonus)end
	if state.statsSeed~=nil and not integer(state.statsSeed,1000)then state.statsSeed=nil end
	if state.petBoosts~=nil then
		state.petBoosts=State.sanitizeBoosts(state.petBoosts)
		if state.petBoosts~=nil and next(state.petBoosts)==nil then state.petBoosts=nil end
	end
end

-- Stat Snack boosts (v2 Stat Eggs; V2-SCOPE 5.1). Optional, additive, its own valid/sanitize so a
-- bad boost field never drops petStats (architect review 2026-11-19):
--   petBoosts = { [petId] = { [statId] = { {mult=2, left=50}, ... } } }   a queue per stat, head first
-- Frozen stored bounds: queue 16, mult 1..10 (use is capped at StatEggCatalog.MaxMult), left 0..StoredMaxLeft.
State.BoostQueueStored=16
State.BoostMultStored=10
local function validQueue(queue)
	if type(queue)~="table"or #queue>State.BoostQueueStored or count(queue)~=#queue then return false end
	for _,boost in ipairs(queue)do
		if type(boost)~="table"or not integer(boost.mult,State.BoostMultStored)or boost.mult<1 or not integer(boost.left,State.StoredMaxLeft)then return false end
	end
	return true
end
function State.validBoosts(state)
	local boosts=state.petBoosts
	if boosts==nil then return true end
	if type(boosts)~="table"or count(boosts)>State.PetLimit then return false end
	for pet,stats in pairs(boosts)do
		if not id(pet)or type(stats)~="table"or count(stats)>State.StatLimit then return false end
		for stat,queue in pairs(stats)do if not id(stat)or not validQueue(queue)then return false end end
	end
	return true
end
function State.sanitizeBoosts(value)
	if type(value)~="table"then return nil end
	local result,pets={},0
	for _,pet in ipairs(sortedKeys(value))do
		local stats=value[pet]
		if pets<State.PetLimit and id(pet)and type(stats)=="table"then
			local clean,n={},0
			for _,stat in ipairs(sortedKeys(stats))do
				local queue=stats[stat]
				if n<State.StatLimit and id(stat)and type(queue)=="table"then
					local kept={}
					for _,boost in ipairs(queue)do
						if #kept<State.BoostQueueStored and type(boost)=="table"and type(boost.mult)=="number"and type(boost.left)=="number"
							and boost.mult==boost.mult and boost.left==boost.left and boost.mult>=1 and boost.left>=1 and boost.left~=math.huge then
							table.insert(kept,{mult=math.min(math.floor(boost.mult),State.BoostMultStored),left=math.min(math.floor(boost.left),State.StoredMaxLeft)})
						end
					end
					if #kept>0 then clean[stat]=kept;n+=1 end
				end
			end
			if n>0 then result[pet]=clean;pets+=1 end
		end
	end
	return result
end
-- The queue for one pet and stat (a copy; empty when none).
function State.boosts(state,petId,statId)
	local all=type(state)=="table"and State.sanitizeBoosts(state.petBoosts)or {}
	return(all[petId]and all[petId][statId])or {}
end
-- Queues one boost. Copy-on-write; false (nothing written) when it would pass a stored bound.
function State.queueBoost(state,petId,statId,mult,left)
	if type(state)~="table"or not id(petId)or not id(statId)or not integer(mult,State.BoostMultStored)or mult<1
		or not integer(left,State.StoredMaxLeft)or left<1 then return false end
	local all=State.sanitizeBoosts(state.petBoosts)or {}
	if all[petId]==nil and count(all)>=State.PetLimit then return false end
	local stats=all[petId]or {}
	if stats[statId]==nil and count(stats)>=State.StatLimit then return false end
	local queue=stats[statId]or {}
	if #queue>=State.BoostQueueStored then return false end
	table.insert(queue,{mult=mult,left=left})
	stats[statId]=queue;all[petId]=stats;state.petBoosts=all
	return true
end
-- The boost XP `rest` plain XP earns from `queue` (consumed head first, one multiplier per XP,
-- capped at MaxMult). Returns the extra XP and the queue left.
local function applyBoosts(queue,rest)
	local extra,kept=0,{}
	for _,boost in ipairs(queue)do
		if rest>0 then
			local take=math.min(rest,boost.left)
			extra+=take*(math.min(boost.mult,EggRules.MaxMult)-1)
			rest-=take
			if boost.left-take>0 then table.insert(kept,{mult=boost.mult,left=boost.left-take})end
		else
			table.insert(kept,boost)
		end
	end
	return extra,kept
end

function State.xp(state,petId,statId)
	local stats=type(state)=="table"and type(state.petStats)=="table"and state.petStats[petId]
	local xp=type(stats)=="table"and stats[statId]
	return if integer(xp,State.StoredMaxXP)then xp else 0
end

-- Bonus XP still to double for `stat` on `today`: refills Daily per elapsed day, banked to
-- BonusMax. Never moves backward when `today` is before the saved day.
local function bonusLeft(bonus,stat,today)
	local daily,max=Catalog.Bonus.Daily,Catalog.BonusMax
	if not bonus then return daily end
	local saved=if type(bonus.left)=="table"and integer(bonus.left[stat],State.StoredMaxLeft)then bonus.left[stat]else nil
	local elapsed=tonumber(today)-tonumber(bonus.day)
	if saved==nil then return daily end -- a stat not seen yet: today's share
	if elapsed<=0 then return math.min(saved,max)end
	return math.min(max,saved+daily*elapsed)
end

-- The favourite-stat extra for one grant: PetCatalog `favouriteStat` names the species' stat; it
-- earns FavouriteBonus (10%) more of the base amount, rounded half up. Pure; 0 for anything else.
State.FavouriteBonus=.1
function State.favouriteExtra(petId,statId,amount)
	local pet=type(petId)=="string"and Pets.byId[petId]or nil
	if not pet or pet.favouriteStat==nil or pet.favouriteStat~=statId then return 0 end
	if type(amount)~="number"or amount~=amount or amount<=0 or amount==math.huge then return 0 end
	return math.floor(math.floor(amount)*State.FavouriteBonus+.5)
end

-- Adds XP for an owned pet: `amount` plus Bonus XP (the first `left` XP today count double)
-- unless `noBonus`, then Stat Snack boosts on the XP the bonus did not double (so the most any XP
-- counts is MaxMult, the Feast's 3x). Copy-on-write; clamped to MaxXP (reaching it clears that
-- stat's boosts). Never fails; returns the XP added (0 on a no-op) and the part of it a boost
-- added. `today` must come from the transaction's candidate (stable across retries).
function State.grant(state,petId,statId,amount,today,noBonus)
	if type(state)~="table"or type(petId)~="string"or Pets.byId[petId]==nil or Catalog.ById[statId]==nil then return 0 end
	if type(amount)~="number"or amount~=amount or amount<=0 or amount==math.huge then return 0 end
	if not Eggs.isOwned(state.inventoryMask or 0,petId)then return 0 end
	amount=math.floor(amount);if amount<=0 then return 0 end
	-- Code review: never grow past the storage limits (a 33rd pet or 17th stat would make the save
	-- invalid and fail the whole transaction), and never lower XP above MaxXP.
	local current=State.sanitizePetStats(state.petStats)or {}
	if current[petId]==nil and count(current)>=State.PetLimit then return 0 end
	if current[petId]~=nil and current[petId][statId]==nil and count(current[petId])>=State.StatLimit then return 0 end
	if(current[petId]and current[petId][statId]or 0)>=Catalog.MaxXP then return 0 end
	local gained,doubledUsed=amount,0
	if not noBonus and canonicalDay(today)then
		local bonus=State.sanitizeBonus(state.statBonus)
		if bonus and tonumber(today)<tonumber(bonus.day)then
			-- Clock rollback: no bonus, and the saved day stays.
		else
			local left=bonusLeft(bonus,statId,today)
			local doubled=math.min(left,amount)
			gained+=doubled
			local nextLeft=if bonus then table.clone(bonus.left)else {}
			-- Roll every known stat's bank to today so the day can move forward.
			if bonus and bonus.day~=today then
				for _,stat in ipairs(Catalog.Order)do nextLeft[stat]=bonusLeft(bonus,stat,today)end
			end
			nextLeft[statId]=left-doubled
			if count(nextLeft)<=State.StatLimit then state.statBonus={day=today,left=nextLeft};doubledUsed=doubled else gained-=doubled end
		end
	end
	-- Boosts (architect review): only the XP the bonus did not actually double earns a boost.
	local boostExtra,keptQueue,queue=0,nil,nil
	if not noBonus then
		queue=State.boosts(state,petId,statId)
		if #queue>0 then boostExtra,keptQueue=applyBoosts(queue,amount-doubledUsed);gained+=boostExtra end
	end
	-- Favourite stat (v2 Bunny: Jump): +10% of the base amount, rounded half up, added after the
	-- Bonus XP and boost maths so it never spends the daily bank or a snack boost faster and never
	-- multiplies with them (architect review 2026-11-19). Grants of 4 XP or less round to +0.
	gained+=State.favouriteExtra(petId,statId,amount)
	local petStats=current
	local stats=petStats[petId]or {}
	local before=stats[statId]or 0
	stats[statId]=math.max(before,math.min(Catalog.MaxXP,before+gained))
	petStats[petId]=stats
	state.petStats=petStats
	local added=stats[statId]-before
	if keptQueue or(queue and #queue>0 and stats[statId]>=Catalog.MaxXP)then
		-- Use up boosts only for XP actually added: a clamp at MaxXP clears the stat's queue.
		if stats[statId]>=Catalog.MaxXP then keptQueue={}end
		local all=State.sanitizeBoosts(state.petBoosts)or {}
		local row=all[petId]or {}
		row[statId]=if #keptQueue>0 then keptQueue else nil
		all[petId]=if next(row)then row else nil
		state.petBoosts=if next(all)then all else nil
	end
	return added,math.min(boostExtra,added)
end

local function bits(mask)
	local n=0
	mask=if type(mask)=="number"and mask==mask and mask>=0 and mask~=math.huge then math.floor(mask)else 0
	while mask>0 do n+=mask%2;mask=math.floor(mask/2)end
	return n
end
-- One-time credit for play before stats (section 10.3), to the Bear if owned. Reads only the
-- snapshot. No Bonus XP. Marks the save seeded either way.
function State.seededAlready(state)
	return (type(state.statsSeed)=="number"and state.statsSeed>=1)or state.petStats~=nil
end
function State.seedAmounts(state)
	local s=type(state.stats)=="table"and state.stats or {}
	local function n(key)local v=s[key];return if type(v)=="number"and v==v and v>=0 and v~=math.huge then math.floor(v)else 0 end
	local book=type(state.book)=="table"and state.book or {}
	local claimed=type(book.claimed)=="table"and #book.claimed or 0
	local bond=type(state.bond)=="table"and type(state.bond[State.SeedPet])=="number"and state.bond[State.SeedPet]or 0
	local stamps=if type(state.stamps)=="number"and state.stamps==state.stamps and state.stamps>=0 then math.floor(state.stamps)else 0
	local XP=Catalog.XP
	local amounts={
		power=n("merges")*XP.merge+n("tierFive")*XP.topTier,
		energy=n("rounds")*XP.round+n("winsEasy")*XP.winEasy+n("winsMedium")*XP.winMedium+n("winsHard")*XP.winHard+n("tidyWins")*XP.tidy,
		heart=math.max(0,math.floor(bond))*4,
		jump=math.max(0,n("parkGames")-n("fetches"))*XP.park,
		speed=n("fetches")*XP.fetch,
		smarts=n("questsDaily")*XP.questDaily+n("questsWeekly")*XP.questWeekly+stamps*XP.stamp+bits(book.found)*XP.discovery+claimed*XP.milestone,
	}
	for stat,v in pairs(amounts)do amounts[stat]=math.clamp(v,0,Catalog.MaxXP)end
	return amounts
end
function State.seed(state)
	if type(state)~="table"or State.seededAlready(state)then return false end
	if Eggs.isOwned(state.inventoryMask or 0,State.SeedPet)then
		local stats={}
		for stat,v in pairs(State.seedAmounts(state))do if v>0 then stats[stat]=v end end
		state.petStats={[State.SeedPet]=stats}
	end
	state.statsSeed=State.SeedVersion
	return true
end

-- For the client: per owned pet, XP and level per stat and the total level; Bonus XP left today.
function State.public(state,today)
	local result={pets={},bonus={}}
	local petStats=type(state)=="table"and State.sanitizePetStats(state.petStats)or {}
	local allBoosts=type(state)=="table"and State.sanitizeBoosts(state.petBoosts)or {}
	for _,pet in ipairs(Pets.collection)do
		if Eggs.isOwned(state.inventoryMask or 0,pet.id)then
			local stats=petStats[pet.id]or {}
			-- boosts[stat] = {mult, left} of the head boost, plus the XP and count queued in all.
			local entry={xp={},level={},total=0,boosts={}}
			for _,stat in ipairs(Catalog.Order)do
				local xp=stats[stat]or 0
				entry.xp[stat]=xp;entry.level[stat]=Catalog.levelFor(xp);entry.total+=entry.level[stat]
				local queue=allBoosts[pet.id]and allBoosts[pet.id][stat]
				if queue and #queue>0 then
					local queued=0;for _,boost in ipairs(queue)do queued+=boost.left end
					entry.boosts[stat]={mult=math.min(queue[1].mult,EggRules.MaxMult),left=queue[1].left,queued=queued,count=#queue}
				end
			end
			result.pets[pet.id]=entry
		end
	end
	local bonus=type(state)=="table"and State.sanitizeBonus(state.statBonus)or nil
	for _,stat in ipairs(Catalog.Order)do
		result.bonus[stat]=if canonicalDay(today)and(not bonus or tonumber(today)>=tonumber(bonus.day))then bonusLeft(bonus,stat,today)elseif bonus then(bonus.left[stat]or 0)else Catalog.Bonus.Daily
	end
	return result
end

-- For other players (v2 S4, section 6): the board attribute Catalog.PublicAttribute. Per owned
-- pet, the six levels, the total level and the Keeper tier word. Levels only: no XP, no Bonus
-- XP, no wallet, nothing else from the save. Derived from the save on every publish; the server
-- never reads it back.
function State.publicLevels(state)
	local pets={}
	if type(state)~="table"then return {v=1,pets=pets}end
	local petStats=State.sanitizePetStats(state.petStats)or {}
	for _,pet in ipairs(Pets.collection)do
		if Eggs.isOwned(state.inventoryMask or 0,pet.id)then
			local stats=petStats[pet.id]or {}
			local levels,total={},0
			for _,stat in ipairs(Catalog.Order)do
				local level=Catalog.levelFor(stats[stat]or 0)
				levels[stat]=level;total+=level
			end
			pets[pet.id]={levels=levels,total=total,keeper=Catalog.keeperTier(total)}
		end
	end
	return {v=1,pets=pets}
end

return State
