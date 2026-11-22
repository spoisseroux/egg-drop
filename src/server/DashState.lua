-- Garden Dash on the save (V3-DASH-BUILD-PLAN-2026-11-22, slice S6). One optional, additive field on the hatching
-- save (v11, no version bump), written only inside HatchProgress.transact (Hatching.dashResults):
--   dash = {day, paid, week, weekRibbons, ribbons={gold,silver,bronze,green}, cups, best, trials, op,
--           receipt={op,seed,place,us,stars,balance}}
--   day, paid      the day ("20000") Stars were last counted for, and how many races it paid (0..5)
--   week           QuestRotation week of weekRibbons; the "Garden Dasher" title is derived: 5 ribbons this week
--   cups           bitmask 1 bronze, 2 silver, 4 gold (Time Trial pars beaten, ORed, so a repeat adds nothing)
--   best           best Time Trial in microseconds on course 1 (before trials); kept as it is, never read or written
--   trials         best Time Trial per course, {["2"]=us}: the key is DashCourse.Version. Only this course's is read or
--                  improved; the others are kept. An older beta build repairs it away on its next Dash write
--   op             the last flight written: the proof that it committed (exactly once under retry and replay)
--   receipt        what that flight paid; analytics read only this. The seed never leaves the server.
--
-- The field is never part of HatchProgress.valid and load never touches it, so it can never fail a load or an
-- unrelated write; the live build ignores and keeps it. Every read is tolerant (State.read): a malformed
-- subfield is repaired on its own, and a malformed day or paid reads as "all paid today" (fail closed).
local Shared=game:GetService("ReplicatedStorage").Shared
local DashStats=require(Shared.DashStats)
local Course=require(Shared.DashCourse)
local Rotation=require(Shared.QuestRotation)

local State={}
State.Stars=2
State.DailyLimit=5
State.TitleRibbons=5
State.MinInputs=3
State.MaxBatch=8
State.StoredMax=1000000
State.Wallet=1000000000
State.MaxUs=120000000 -- DashSim.MaxTicks
State.CupBits=table.freeze({bronze=1,silver=2,gold=4})
State.CupOrder=table.freeze({"bronze","silver","gold"})
State.Ribbons=table.freeze({"gold","silver","bronze","green"})
State.Course=tostring(Course.Version)
State.MaxCourse=999

local function integer(value,low,high)
	return type(value)=="number"and value==value and value%1==0 and value>=low and value<=high
end
local function canonicalDay(value)
	local number=if type(value)=="string"then tonumber(value)else nil
	return number~=nil and number==math.floor(number)and math.abs(number)<=1000000000 and tostring(number)==value
end
local function op(value)return type(value)=="string"and #value>=1 and #value<=100 end
local function receiptOf(value)
	if type(value)~="table"or not op(value.op)or not integer(value.stars,0,State.Stars*State.DailyLimit)
		or not integer(value.balance,0,State.Wallet)then return nil end
	return{op=value.op,stars=value.stars,balance=value.balance,
		seed=if integer(value.seed,0,4294967295)then value.seed else nil,
		place=if integer(value.place,1,8)then value.place else nil,
		us=if integer(value.us,1,State.MaxUs)then value.us else nil}
end
-- A repaired copy of the field; never errors. `closed`: the day or the count was malformed.
function State.read(state)
	local raw=type(state)=="table"and state.dash
	local out={paid=0,weekRibbons=0,ribbons={},cups=0}
	local source=if type(raw)=="table"then raw else{}
	if raw~=nil then
		if type(raw)=="table"and canonicalDay(raw.day)and integer(raw.paid,0,State.DailyLimit)then out.day,out.paid=raw.day,raw.paid
		else out.closed=true end
	end
	if integer(source.week,-1000000000,1000000000)then
		out.week=source.week
		if integer(source.weekRibbons,0,State.StoredMax)then out.weekRibbons=source.weekRibbons end
	end
	local ribbons=if type(source.ribbons)=="table"then source.ribbons else{}
	for _,id in ipairs(State.Ribbons)do out.ribbons[id]=if integer(ribbons[id],0,State.StoredMax)then ribbons[id]else 0 end
	if integer(source.cups,0,7)then out.cups=source.cups end
	if integer(source.best,1,State.MaxUs)then out.best=source.best end
	if type(source.trials)=="table"then
		for key,us in pairs(source.trials)do
			local version=if type(key)=="string"then tonumber(key)else nil
			if integer(version,1,State.MaxCourse)and tostring(version)==key and integer(us,1,State.MaxUs)then
				out.trials=out.trials or {}
				out.trials[key]=us
			end
		end
	end
	if op(source.op)then out.op=source.op end
	out.receipt=receiptOf(source.receipt)
	return out
end
local function bestOf(entry)return entry.trials and entry.trials[State.Course]end
-- The best Time Trial on this course; a time from another course is not one.
function State.best(state)return bestOf(State.read(state))end
-- The day's count as of `today`: a later saved day is kept (clock rollback), an earlier one starts again.
local function roll(entry,today)
	local now=tonumber(today)
	if entry.closed then entry.day,entry.paid,entry.closed=today,State.DailyLimit,nil
	elseif entry.day==nil or tonumber(entry.day)<now then entry.day,entry.paid=today,0 end
	local week=Rotation.week(now)
	if entry.week==nil or entry.week<week then entry.week,entry.weekRibbons=week,0 end
	return entry
end

-- One result as the host may hand it over: {kind="race"|"trial", mode, band, place, us?, inputs, seed, prize}.
-- `prize` is the prizes switch, frozen when the result was made.
function State.validResult(result)
	if type(result)~="table"or type(result.prize)~="boolean"or not integer(result.place,1,8)
		or not integer(result.inputs,0,State.StoredMax)or not integer(result.seed,0,4294967295)
		or(result.us~=nil and not integer(result.us,1,State.MaxUs))then return false end
	if result.kind=="trial"then return result.mode=="trial"end
	return result.kind=="race"and(result.mode=="fun"or(result.mode=="stats"and integer(result.band,1,#DashStats.Bands)))
end
function State.validResults(results)
	if type(results)~="table"or #results<1 or #results>State.MaxBatch then return false end
	for _,result in ipairs(results)do if not State.validResult(result)then return false end end
	return true
end
-- Binds an operation id to its content: the count and two 32-bit hashes of every field, always 24 characters
-- (lastOperation.digest is at most 120, or the whole save is refused).
local function fnv(text,hash)
	for i=1,#text do
		hash=bit32.bxor(hash,string.byte(text,i))
		hash=(hash%65536*16777619+(hash//65536*403%65536)*65536)%4294967296
	end
	return hash
end
function State.digest(results)
	local out={}
	for index,r in ipairs(results)do
		out[index]=table.concat({r.kind,r.mode,tostring(r.band),r.place,tostring(r.us),r.inputs,r.seed,tostring(r.prize)},",")
	end
	local text=table.concat(out,";")
	return string.format("dash:%02d:%08x%08x",#results,fnv(text,2166136261),fnv(text,3735928559))
end
-- The cups this time earns, as bits (a better par includes the ones below it).
function State.cupBits(us)
	local bits=0
	if type(us)~="number"then return bits end
	local pars=DashStats.pars("trial")
	for _,id in ipairs(State.CupOrder)do if us<=pars[id]*1000 then bits+=State.CupBits[id]end end
	return bits
end
function State.ribbon(result)
	if result.kind~="race"or not result.prize or result.inputs<State.MinInputs then return nil end
	return if result.us and result.place<=3 then State.Ribbons[result.place]else "green"
end
-- Whether the result itself may pay (the daily count is the save's business).
function State.earns(result)
	return result.kind=="race"and result.prize and result.us~=nil and result.inputs>=State.MinInputs
		and result.us<=DashStats.pars(result.mode,result.band).gold*2*1000
end
-- Nothing to write: no ribbon, no new cup, no better time.
function State.pointless(state,result)
	if result.kind=="race"then return State.ribbon(result)==nil and not State.earns(result)end
	if not result.us then return true end
	local entry=State.read(state)
	local best=bestOf(entry)
	if best==nil or result.us<best then return false end
	return not result.prize or bit32.band(State.cupBits(result.us),bit32.bnot(entry.cups))==0
end

-- candidate = {id, results}; today is read inside the write, so a race that crosses midnight counts on the day
-- it commits. All or nothing; the caller's transaction makes it exactly once.
function State.apply(state,candidate,today)
	if type(state)~="table"or type(candidate)~="table"or not op(candidate.id)or not State.validResults(candidate.results)
		or not canonicalDay(today)or not integer(state.nectar,0,State.Wallet)then return false,"InvalidDash"end
	local entry=roll(State.read(state),today)
	local stars,last=0,candidate.results[#candidate.results]
	for _,result in ipairs(candidate.results)do
		if result.kind=="trial"then
			if result.us then
				local best=bestOf(entry)
				if best==nil or result.us<best then
					entry.trials=entry.trials or {}
					entry.trials[State.Course]=result.us
				end
				if result.prize then entry.cups=bit32.bor(entry.cups,State.cupBits(result.us))end
			end
		else
			last=result
			local ribbon=State.ribbon(result)
			if ribbon then
				entry.ribbons[ribbon]=math.min(State.StoredMax,entry.ribbons[ribbon]+1)
				entry.weekRibbons=math.min(State.StoredMax,entry.weekRibbons+1)
			end
			if State.earns(result)and entry.paid<State.DailyLimit then
				entry.paid+=1
				if state.nectar+State.Stars<=State.Wallet then state.nectar+=State.Stars;stars+=State.Stars end
			end
		end
	end
	entry.op=candidate.id
	entry.receipt={op=candidate.id,seed=last.seed,place=last.place,us=last.us,stars=stars,balance=state.nectar}
	state.dash=entry
	return true
end
function State.committed(state,operationId)
	return type(state)=="table"and type(state.dash)=="table"and state.dash.op~=nil and state.dash.op==operationId
end
function State.receipt(state,operationId)
	local proof=if State.committed(state,operationId)then receiptOf(state.dash.receipt)else nil
	return if proof and proof.op==operationId then proof else nil
end
-- What the owner's snapshot carries (never the seed), and what everybody may see on the pet's card.
function State.public(state,today)
	local entry=roll(State.read(state),today)
	local receipt=entry.receipt
	return{day=today,paid=entry.paid,limit=State.DailyLimit,stars=State.Stars,ribbons=entry.ribbons,cups=entry.cups,best=bestOf(entry),
		weekRibbons=entry.weekRibbons,titleAt=State.TitleRibbons,title=entry.weekRibbons>=State.TitleRibbons,
		last=if receipt then{op=receipt.op,place=receipt.place,us=receipt.us,stars=receipt.stars}else nil}
end
function State.marks(state,today)
	local entry=roll(State.read(state),today)
	return{v=1,ribbons=entry.ribbons,cups=entry.cups,title=entry.weekRibbons>=State.TitleRibbons}
end
return State
