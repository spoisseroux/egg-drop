-- Lifetime counters, stamp count and collection book claims (hatching v11;
-- PLAY-FOREVER-SCOPE-2026-11-13 section 4). Counters cannot be backfilled, so they
-- start with the v11 bump even though their screens ship later. Written only
-- inside existing fenced transactions (HatchProgress.transact / award).
local Book=require(game:GetService("ReplicatedStorage").Shared.BookCatalog)
local RoundItems=require(game:GetService("ReplicatedStorage").Shared.RoundItems)
local State={}
State.Counters={"rounds","winsEasy","winsMedium","winsHard","tidyWins","merges","bestChain","tierFive",
	"itemsUsed","pets","parkGames","starsEarned","starsSpent"}
State.Cap=2000000000
State.BookLimit=256
State.FoundMask=2^31-1 -- discovery bits 0..30 only (BUILD-PLAN architect change 4)
State.RunMerges=10000 -- per-round bounds, mirrored by the award validator (HatchProgress.award)
State.RunItems=64
-- Optional counters (overnight 2026-11-14, slice D). Known to add/max/bor but NOT in the
-- required `Counters` list: a save without them is valid and reads 0, so no old save fails.
--   weeklyBonuses  weekly bonus quests claimed (slot 0); counts from this build on, no backfill
--   itemWinKinds   OR of the round-item kinds used in won rounds (bits: swap 1, pop 2, bomb 4, magnet 8)
State.Optional={"weeklyBonuses","itemWinKinds"}
State.ItemKindsMask=2^#RoundItems.Order-1
local known={};for _,key in ipairs(State.Counters)do known[key]=true end
for _,key in ipairs(State.Optional)do known[key]=true end
-- The bit of one round item id (0 for an unknown id). Order is RoundItems.Order, append-only.
function State.itemKindBit(id)
	local index=table.find(RoundItems.Order,id)
	return if index then bit32.lshift(1,index-1)else 0
end

local function integer(value,max)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=(max or State.Cap)
end

function State.freshStats()
	local stats={};for _,key in ipairs(State.Counters)do stats[key]=0 end;return stats
end
function State.freshBook()return{claimed={},found=0}end

-- Tolerant: counters added by a later build are kept if they are capped integers.
function State.valid(state)
	local stats,book=state.stats,state.book
	if type(stats)~="table"then return false end
	for key,value in pairs(stats)do if type(key)~="string"or #key>32 or not integer(value)then return false end end
	for _,key in ipairs(State.Counters)do if stats[key]==nil then return false end end
	if not integer(state.stamps)then return false end
	if type(book)~="table"or type(book.claimed)~="table"or not integer(book.found,2^31-1)then return false end
	for key in pairs(book)do if key~="claimed"and key~="found"then return false end end
	local count,seen=0,{}
	for key in pairs(book.claimed)do count+=1;if type(key)~="number"then return false end end
	if count~=#book.claimed or count>State.BookLimit then return false end
	for _,id in ipairs(book.claimed)do
		if type(id)~="string"or #id<1 or #id>40 or seen[id]then return false end;seen[id]=true
	end
	return true
end

function State.add(state,key,amount)
	local stats=state.stats
	if type(stats)~="table"or not known[key]or type(amount)~="number"or amount<=0 then return end
	stats[key]=math.min(State.Cap,(stats[key]or 0)+math.floor(amount))
end
function State.max(state,key,value)
	local stats=state.stats
	if type(stats)~="table"or not known[key]or type(value)~="number"then return end
	stats[key]=math.clamp(math.max(stats[key]or 0,math.floor(value)),0,State.Cap)
end

-- OR `mask` into an optional bit-set counter, clipped to `limit`.
function State.bor(state,key,mask,limit)
	local stats=state.stats
	if type(stats)~="table"or not known[key]or type(mask)~="number"or mask~=mask or mask<0 or mask==math.huge then return end
	limit=limit or State.FoundMask
	local current=if integer(stats[key],limit)then stats[key]else 0
	stats[key]=bit32.band(bit32.bor(current,bit32.band(math.floor(mask),limit)),limit)
end

local function bits(mask)local n=0;while mask>0 do n+=mask%2;mask=math.floor(mask/2)end;return n end
-- After any committed transaction: wallet and pet deltas. Robux grants are not
-- "earned"; every debit is "spent". `now` (the transaction's clock, read inside the
-- UpdateAsync callback) feeds the state-derived Discoveries (slice D).
function State.record(before,after,signature,now)
	if type(after.stats)~="table"then return end
	signature=if type(signature)=="string"then signature else ""
	local delta=after.nectar-before.nectar
	if delta<0 then State.add(after,"starsSpent",-delta)
	elseif delta>0 and string.sub(signature,1,9)~="purchase:"then State.add(after,"starsEarned",delta)end
	local gained=bits(after.inventoryMask or 0)-bits(before.inventoryMask or 0)
	if gained>0 then State.add(after,"pets",gained)end
	-- Weekly bonus quest claimed (signature quest:weekly:<period>:0; slot 0 is the bonus)
	-- and paid: the Star charm counts these. No QuestState change needed.
	if delta>0 and string.match(signature,"^quest:weekly:.+:0$")then State.add(after,"weeklyBonuses",1)end
	-- Discoveries the save itself has earned (BookCatalog.stateBits, Lane K). pet_night belongs
	-- to the pet write alone: its bit is dropped for every other signature, whatever the
	-- catalogue returns.
	if type(Book.stateBits)=="function"then
		local found=Book.stateBits(after,now,signature)
		local night=type(Book.DiscoveryById)=="table"and Book.DiscoveryById.pet_night
		if type(found)=="number"and found==found and found>0 and found~=math.huge then
			found=bit32.band(math.floor(found),State.FoundMask)
			if night and string.sub(signature,1,4)~="pet:"then found=bit32.band(found,bit32.bnot(bit32.lshift(1,night.bit)))end
			State.setFound(after,found)
		end
	end
end
-- One saved round (inside the award transaction).
function State.recordRun(state,run,heat)
	if type(state.stats)~="table"or not run then return end
	State.add(state,"rounds",1)
	if run.success then
		State.add(state,if heat=="easy"then "winsEasy"elseif heat=="hard"then "winsHard"else "winsMedium",1)
		if run.clean then State.add(state,"tidyWins",1)end
	end
	if type(run.chain)=="number"then State.max(state,"bestChain",run.chain)end
	if type(run.merges)=="number"then State.add(state,"merges",math.min(run.merges,State.RunMerges))end
	if type(run.itemsUsed)=="number"then State.add(state,"itemsUsed",math.min(run.itemsUsed,State.RunItems))end
	if run.maxTier==5 then State.add(state,"tierFive",1)end
	-- Item kinds count toward win_each_item only on a win (slice D).
	if run.success and type(run.itemKinds)=="number"then State.bor(state,"itemWinKinds",run.itemKinds,State.ItemKindsMask)end
	State.setFound(state,Book.runBits(run,heat))
end

-- Discoveries: OR bits into book.found, clipped to bits 0..30.
function State.setFound(state,bits)
	local book=state.book
	if type(book)~="table"or type(bits)~="number"or bits~=bits or bits<=0 or bits==math.huge then return end
	local found=if type(book.found)=="number"and book.found==book.found and book.found>=0 then book.found else 0
	book.found=bit32.band(bit32.bor(bit32.band(found,State.FoundMask),bit32.band(math.floor(bits),State.FoundMask)),State.FoundMask)
end
-- Records one milestone claim (copy-on-write list). False when already claimed or full.
function State.claim(state,id)
	local book=state.book
	if type(book)~="table"or type(book.claimed)~="table"or type(id)~="string"or #id<1 or #id>40 then return false end
	if table.find(book.claimed,id)or #book.claimed>=State.BookLimit then return false end
	local claimed=table.clone(book.claimed);table.insert(claimed,id)
	state.book={claimed=claimed,found=book.found}
	return true
end

return State
