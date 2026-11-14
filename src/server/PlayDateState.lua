-- Pet Park "Play date" (BUILD-PLAN 2026-11-13, slice K1, architect change 4). An optional,
-- additive field on the hatching save; no version bump and no new Lifetime.Counters name:
--   playDate = {day = "<day>", count = 0..Target, op = "<last park operation id>"}
-- Missing is valid (every save before the park). count is today's finished park activities,
-- capped at Target; crossing Target pays Reward Stars once for that day. `op` proves which park
-- write committed, so the host never counts the same finished activities twice after a retry.
-- Every finished activity also adds to stats.parkGames (the existing lifetime counter).
-- Written only inside HatchProgress.transact (Hatching.parkPlay).
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.ParkActivities)
local Lifetime=require(script.Parent.LifetimeState)
local State={Target=Catalog.PlayDate.Target,Reward=Catalog.PlayDate.Reward,MaxBatch=1000}

local function canonicalDay(value)
	local number=if type(value)=="string"then tonumber(value)else nil
	return number~=nil and number==math.floor(number)and math.abs(number)<=1000000000 and tostring(number)==value
end
local function integer(value,maximum)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=maximum
end
local function validCompletion(value)
	return value==nil or(type(value)=="table"and type(value.op)=="string"and #value.op>=1 and #value.op<=100
		and(value.amount==0 or value.amount==State.Reward)and integer(value.balance,1000000000))
end
local function validOp(value)return value==nil or(type(value)=="string"and #value>=1 and #value<=100)end

-- Tolerant: nil is valid; unknown extra keys are ignored (a later build may add some).
function State.valid(state)
	local entry=state.playDate
	if entry==nil then return true end
	return type(entry)=="table"and canonicalDay(entry.day)and integer(entry.count,State.Target)and validOp(entry.op)and validCompletion(entry.completion)
end
-- Load-time repair: a malformed field becomes nil (never a failed load); known fields only.
function State.sanitize(entry)
	if type(entry)~="table"or not canonicalDay(entry.day)or not integer(entry.count,State.Target)or not validOp(entry.op)then return nil end
	local completion=if validCompletion(entry.completion)and entry.completion then {op=entry.completion.op,amount=entry.completion.amount,balance=entry.completion.balance}else nil
	return {day=entry.day,count=entry.count,op=entry.op,completion=completion}
end
-- Durable completion receipt belongs to the crossing transaction, not the latest batch.
function State.completion(state,operationId)
	local entry=state and state.playDate
	local proof=entry and entry.completion
	return if validCompletion(proof)and proof and proof.op==operationId then proof else nil
end
function State.committed(state,operationId)
	local entry=state and state.playDate
	return type(entry)=="table"and entry.op~=nil and entry.op==operationId
end

-- candidate = {id, day, count}; today = the current day string at apply time.
-- An expired candidate (day changed before it saved) still counts parkGames but not Play date.
function State.apply(state,candidate,today)
	if type(state.stats)~="table"then return false,"InvalidData"end
	if type(candidate)~="table"or type(candidate.id)~="string"or not canonicalDay(candidate.day)or not integer(candidate.count,State.MaxBatch)or candidate.count<1 then
		return false,"InvalidParkPlay"
	end
	Lifetime.add(state,"parkGames",candidate.count)
	local current=State.sanitize(state.playDate)
	if current and tonumber(current.day)>tonumber(today)then
		-- Clock rollback: leave the newer day alone; only record the proof.
		state.playDate={day=current.day,count=current.count,op=candidate.id,completion=current.completion}
		return true
	end
	if candidate.day~=today then
		local kept=if current and current.day==today then current.count else 0
		state.playDate={day=today,count=kept,op=candidate.id,completion=if current and current.day==today then current.completion else nil}
		return true
	end
	local before=if current and current.day==today then current.count else 0
	local after=math.min(State.Target,before+candidate.count)
	local completion=if current and current.day==today then current.completion else nil
	if before<State.Target and after>=State.Target then
		local amount=if state.nectar+State.Reward<=1000000000 then State.Reward else 0
		state.nectar+=amount
		completion={op=candidate.id,amount=amount,balance=state.nectar}
	end
	state.playDate={day=today,count=after,op=candidate.id,completion=completion}
	return true
end

function State.public(state,today)
	local entry=State.sanitize(state.playDate)
	local count=if entry and entry.day==today then entry.count else 0
	return {day=today,count=count,target=State.Target,reward=State.Reward,done=count>=State.Target}
end
function State.done(state,today)
	local entry=State.sanitize(state.playDate)
	return entry~=nil and entry.day==today and entry.count>=State.Target
end

return State
