-- The garden fruit's daily cap on the save (GARDEN-PLAY-BRIEF-2 section 5). One optional, additive field on the hatching
-- save (no version bump), the FindsState pattern, written only inside HatchProgress.transact (Hatching.fruitClaim):
--   fruit = {day, count, op, receipt={op, petId, xp}}
--   day, count   the day ("20000") fruit was last counted for, and how many paid that day (0..DailyLimit)
--   op           the last claim written: the proof it committed (exactly once under retry, replay and two sessions)
--   receipt      what that claim paid
--   recent       the ops written before it, newest last (at most Recent): a late replay of one of them is still
--                AlreadySaved, never a second payment (review B36)
-- Never part of HatchProgress.valid; load never touches it. Every read is tolerant: a good day with a malformed count
-- reads as the day's limit used (fail closed, the next day starts again); a malformed day as no field (at most one
-- day's 24 Heart XP at stake, never Stars); a malformed receipt as none.
-- The XP is plain Heart XP (GardenFruit.XP a fruit): never the daily Bonus XP and no Stat Snack boost (noBonus).
local Shared=game:GetService("ReplicatedStorage").Shared
local Fruit=require(Shared.GardenFruit)
local Pets=require(Shared.PetCatalog)
local Eggs=require(Shared.EggCatalog)
local StatState=require(script.Parent.StatState)

local State={}
State.DailyLimit=Fruit.DailyLimit
State.Recent=8

local function integer(value,low,high)
	return type(value)=="number"and value==value and value%1==0 and value>=low and value<=high
end
local function canonicalDay(value)
	local number=if type(value)=="string"then tonumber(value)else nil
	return number~=nil and number==math.floor(number)and math.abs(number)<=1000000000 and tostring(number)==value
end
local function op(value)return type(value)=="string"and #value>=1 and #value<=100 end
local function pet(value)return type(value)=="string"and #value>=1 and #value<=40 end
local function receiptOf(value)
	if type(value)~="table"or not op(value.op)or not pet(value.petId)or not integer(value.xp,0,1000000)then return nil end
	return{op=value.op,petId=value.petId,xp=value.xp}
end

-- A repaired copy of the field; never errors.
function State.read(state)
	local raw=type(state)=="table"and state.fruit
	local out={count=0}
	if type(raw)=="table"and canonicalDay(raw.day)then
		out.day=raw.day
		out.count=if integer(raw.count,0,State.DailyLimit)then raw.count else State.DailyLimit
	end
	local source=if type(raw)=="table"then raw else{}
	if op(source.op)then out.op=source.op end
	out.receipt=receiptOf(source.receipt)
	out.recent={}
	if type(source.recent)=="table"then
		for _,id in ipairs(source.recent)do if op(id)and #out.recent<State.Recent then table.insert(out.recent,id)end end
	end
	return out
end
-- The count as of `today`: a later saved day is kept (clock rollback), an earlier one starts again.
local function roll(entry,today)
	if entry.day==nil or tonumber(entry.day)<tonumber(today)then entry.day,entry.count=today,0 end
	return entry
end
-- How many more fruit pay today. A malformed day is 0.
function State.left(state,today)
	if not canonicalDay(today)then return 0 end
	return State.DailyLimit-roll(State.read(state),today).count
end

-- candidate = {id, petId, day}: one fruit eaten by the pet that is out. The count's day is read inside the write (a
-- claim that commits after midnight counts on the new day); the XP day is the candidate's. Refuses (writes nothing)
-- at the day's limit or without the pet. The caller's transaction makes it exactly once.
function State.apply(state,candidate,today)
	if type(state)~="table"or type(candidate)~="table"or not op(candidate.id)or not pet(candidate.petId)or not canonicalDay(today)then
		return false,"InvalidFruit"end
	local entry=roll(State.read(state),today)
	if entry.count>=State.DailyLimit then return false,"DailyLimit"end
	if Pets.byId[candidate.petId]==nil or not Eggs.isOwned(state.inventoryMask or 0,candidate.petId)then return false,"NoPet"end
	-- A pet at the most Heart XP still uses up the fruit (0 XP). noBonus: plain XP, no Bonus XP, no boosts.
	local xp=StatState.grant(state,candidate.petId,Fruit.Stat,Fruit.XP,if canonicalDay(candidate.day)then candidate.day else today,true)
	entry.count+=1
	if entry.op then
		table.insert(entry.recent,entry.op)
		while #entry.recent>State.Recent do table.remove(entry.recent,1)end
	end
	entry.op=candidate.id
	entry.receipt={op=candidate.id,petId=candidate.petId,xp=xp}
	state.fruit={day=entry.day,count=entry.count,op=entry.op,receipt=entry.receipt,recent=entry.recent}
	return true
end
function State.committed(state,operationId)
	if not op(operationId)or type(state)~="table"or type(state.fruit)~="table"then return false end
	if state.fruit.op==operationId then return true end
	return table.find(State.read(state).recent,operationId)~=nil
end
function State.receipt(state,operationId)
	local proof=if State.committed(state,operationId)then receiptOf(state.fruit.receipt)else nil
	return if proof and proof.op==operationId then proof else nil
end

return State
