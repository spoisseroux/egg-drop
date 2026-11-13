-- Lifetime counters, stamp count and collection book claims (hatching v11;
-- PLAY-FOREVER-SCOPE-2026-11-13 section 4). Counters cannot be backfilled, so they
-- start with the v11 bump even though their screens ship later. Written only
-- inside existing fenced transactions (HatchProgress.transact / award).
local State={}
State.Counters={"rounds","winsEasy","winsMedium","winsHard","tidyWins","merges","bestChain","tierFive",
	"itemsUsed","pets","parkGames","starsEarned","starsSpent"}
State.Cap=2000000000
State.BookLimit=256
local known={};for _,key in ipairs(State.Counters)do known[key]=true end

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

local function bits(mask)local n=0;while mask>0 do n+=mask%2;mask=math.floor(mask/2)end;return n end
-- After any committed transaction: wallet and pet deltas. Robux grants are not
-- "earned"; every debit is "spent".
function State.record(before,after,signature)
	if type(after.stats)~="table"then return end
	local delta=after.nectar-before.nectar
	if delta<0 then State.add(after,"starsSpent",-delta)
	elseif delta>0 and string.sub(signature or "",1,9)~="purchase:"then State.add(after,"starsEarned",delta)end
	local gained=bits(after.inventoryMask or 0)-bits(before.inventoryMask or 0)
	if gained>0 then State.add(after,"pets",gained)end
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
	if type(run.merges)=="number"then State.add(state,"merges",run.merges)end
	if run.maxTier==5 then State.add(state,"tierFive",1)end
end

return State
