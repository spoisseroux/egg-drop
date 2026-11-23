-- Garden finds on the save (V3-FINDS-BUILD-PLAN-2026-11-22, slice S9). One optional, additive field on the hatching save
-- (no version bump), written only inside HatchProgress.transact (Hatching.findClaim):
--   finds = {day, count, op, receipt={op, petId, n, xp}}
--   day, count   the day ("20000") finds were last counted for, and how many it paid (0..DailyLimit)
--   op           the last claim written: the proof it committed (exactly once under retry, replay and two sessions)
--   receipt      what that claim paid
-- Never part of HatchProgress.valid; load never touches it, so it can never fail a load or an unrelated write, and a
-- build without this file keeps it as it is. Every read is tolerant: a good day with a malformed count reads as "all
-- found that day" (fail closed, and the next day starts again); a malformed day as no field (a find refused writes
-- nothing, so a closed reading with no day to roll from would never open again; at most one day's 96 XP is at
-- stake, never Stars); a malformed receipt as none.
local Shared=game:GetService("ReplicatedStorage").Shared
local Finds=require(Shared.Finds)
local Pets=require(Shared.PetCatalog)
local Eggs=require(Shared.EggCatalog)
local StatState=require(script.Parent.StatState)

local State={}
State.DailyLimit=Finds.DailyLimit
State.MaxBatch=Finds.Waiting

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
	if type(value)~="table"or not op(value.op)or not pet(value.petId)or not integer(value.n,0,State.MaxBatch)
		or not integer(value.xp,0,1000000)then return nil end
	return{op=value.op,petId=value.petId,n=value.n,xp=value.xp}
end

-- A repaired copy of the field; never errors.
function State.read(state)
	local raw=type(state)=="table"and state.finds
	local out={count=0}
	if type(raw)=="table"and canonicalDay(raw.day)then
		out.day=raw.day
		out.count=if integer(raw.count,0,State.DailyLimit)then raw.count else State.DailyLimit
	end
	local source=if type(raw)=="table"then raw else{}
	if op(source.op)then out.op=source.op end
	out.receipt=receiptOf(source.receipt)
	return out
end
-- The count as of `today`: a later saved day is kept (clock rollback), an earlier one starts again.
local function roll(entry,today)
	if entry.day==nil or tonumber(entry.day)<tonumber(today)then entry.day,entry.count=today,0 end
	return entry
end
-- How many more finds pay today. A malformed day is 0.
function State.left(state,today)
	if not canonicalDay(today)then return 0 end
	return State.DailyLimit-roll(State.read(state),today).count
end

-- candidate = {id, petId, n, day}: n finds (1..MaxBatch) claimed for the pet that is out. The day is read inside the write,
-- so a claim that commits after midnight counts on the new day. Pays only what today has left; refuses when nothing
-- would be paid, so a refused claim writes nothing. The caller's transaction makes it exactly once.
function State.apply(state,candidate,today)
	if type(state)~="table"or type(candidate)~="table"or not op(candidate.id)or not pet(candidate.petId)
		or not integer(candidate.n,1,State.MaxBatch)or not canonicalDay(today)then return false,"InvalidFind"end
	local entry=roll(State.read(state),today)
	local paid=math.min(candidate.n,State.DailyLimit-entry.count)
	if paid<=0 then return false,"DailyLimit"end
	if Pets.byId[candidate.petId]==nil or not Eggs.isOwned(state.inventoryMask or 0,candidate.petId)then return false,"NoPet"end
	-- A pet at the most Smarts XP still uses up the finds (0 XP), so the sparkle never sticks.
	-- The XP day is the candidate's (stable across retries, as StatState.grant asks); the count's day is read here.
	local xp=StatState.grant(state,candidate.petId,"smarts",paid*Finds.XP,if canonicalDay(candidate.day)then candidate.day else today)
	entry.count+=paid
	entry.op=candidate.id
	entry.receipt={op=candidate.id,petId=candidate.petId,n=paid,xp=xp}
	state.finds={day=entry.day,count=entry.count,op=entry.op,receipt=entry.receipt}
	return true
end
function State.committed(state,operationId)
	return type(state)=="table"and type(state.finds)=="table"and state.finds.op~=nil and state.finds.op==operationId
end
function State.receipt(state,operationId)
	local proof=if State.committed(state,operationId)then receiptOf(state.finds.receipt)else nil
	return if proof and proof.op==operationId then proof else nil
end
-- What the owner's snapshot carries.
function State.public(state,today)
	local entry=roll(State.read(state),today)
	return{day=today,count=entry.count,limit=State.DailyLimit,xp=Finds.XP}
end

return State
