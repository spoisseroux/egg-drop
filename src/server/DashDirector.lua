-- Garden Dash director (V3-DASH-BUILD-PLAN-2026-11-22, slice S6): phases, seats, the line, pals, Time Trials and the
-- one live DashSim per race. Pure: clock, ids, seeds and every effect are injected, so specs run it on a fake clock.
--   idle -> gather (20 s, at least 8 s after a join) -> countdown (3.5 s, locked: seed and plan drawn, levels
--   frozen, GO known) -> race -> results (6 s). One race a server, eight seats; everyone else waits in line.
-- The race here is the result: it is stepped LagTicks behind the clock, at most StepTicks a frame (so after a hitch
-- the inputs that queued up land before they are passed), and only accepted inputs change it.
-- An error ends that race unpaid and frees its pets; MaxErrors of them turn Dash off on this server.
--
-- options: now(), guid(), seed() (1..2^32-1), day(), prizes(),
--   check(userId, stage) -> ok, reason   stage "join", "queue" (in line), "countdown", "seat" (cheap, twice a second)
--   levels(userId) -> {speed,energy,jump} from the save; pet(userId) -> petId
--   tag(userId, raceId|nil), event(userId, packet), state(userId|nil for everyone, raceId, race),
--   finished(userId, result) (DashState.validResult shape), publish(roster), warn(text)
local Shared=game:GetService("ReplicatedStorage").Shared
local Sim=require(Shared.DashSim)
local Stats=require(Shared.DashStats)
local Wire=require(Shared.DashWire)

local Director={};Director.__index=Director
Director.GatherSeconds=20
Director.JoinSeconds=8
Director.GatherMax=60 -- joins and leaves can never hold a race back longer than this [P]
Director.CountdownSeconds=3.5
Director.ResultSeconds=6
Director.MaxSeats=Sim.MaxRunners
Director.MinRunners=4
Director.MaxQueue=24
Director.StepTicks=10
Director.StateEvery=.1
Director.CheckEvery=.5
Director.MaxBad=30
Director.MaxErrors=3
Director.History=5
-- Garden pals: fixed looks and name pieces (NameCatalog ids), never dressed as players. The tint is the client's.
Director.Pals=table.freeze({
	table.freeze({petId="pip",name=table.freeze({"noodle"}),tint=1}),table.freeze({petId="blip",name=table.freeze({"crumpet"}),tint=2}),
	table.freeze({petId="pip",name=table.freeze({"waffle"}),tint=3}),table.freeze({petId="blip",name=table.freeze({"teacup"}),tint=4}),
	table.freeze({petId="pip",name=table.freeze({"dumpling"}),tint=5}),table.freeze({petId="blip",name=table.freeze({"detour"}),tint=6}),
})

function Director.new(options)
	return setmetatable({options=options,heat=nil,trials={},queue={},history={},errors=0,off=false,dirty=true,palAt=0,
		checkAt=-math.huge,best=nil},Director)
end
-- A host callback that throws never reaches the race.
function Director:call(name,...)
	local ok,a,b=pcall(self.options[name],...)
	if ok then return a,b end
	pcall(self.options.warn,"[Dash] "..name..": "..tostring(a))
	return nil,"Error"
end
function Director:check(userId,stage)
	local ok,reason=self:call("check",userId,stage)
	return ok==true,if ok==true then nil else reason or"Unavailable"
end
function Director:levels(userId)
	local levels=self:call("levels",userId)
	levels=if type(levels)=="table"then levels else{}
	return{speed=Stats.level(levels.speed),energy=Stats.level(levels.energy),jump=Stats.level(levels.jump)}
end
local function find(list,userId)
	for index,record in ipairs(list)do if record.userId==userId then return record,index end end
	return nil
end
-- The player's live seat: record, run (the heat or their trial); nil for anyone else.
function Director:runner(userId)
	local trial=self.trials[userId]
	if trial then return trial.seats[1],trial end
	local heat=self.heat
	local record=heat and heat.phase~="results"and find(heat.seats,userId)or nil
	if record then return record,heat end
	return nil
end

-- Joining ------------------------------------------------------------------------------------------------------
function Director:seat(heat,userId,now)
	table.insert(heat.seats,{userId=userId,petId=self:call("pet",userId),n=0,bad=0})
	self:call("tag",userId,heat.id)
	heat.endsAt=math.min(math.max(heat.endsAt,now+Director.JoinSeconds),heat.startedAt+Director.GatherMax)
	self.dirty=true
	self:call("event",userId,{kind="joined",raceId=heat.id,seat=#heat.seats,mode=heat.mode})
end
function Director:gather(userId,mode,now)
	local heat={id=self.options.guid(),phase="gather",mode=mode,seats={},startedAt=now,endsAt=now+Director.GatherSeconds}
	if mode=="stats"then heat.band=Stats.band(self:levels(userId))end
	self.heat=heat
	self:seat(heat,userId,now)
	return heat
end
function Director:fits(heat,userId)
	return heat.mode~="stats"or Stats.band(self:levels(userId))==heat.band
end
-- Returns ok, reason, raceId. ok with "Queued" or "WrongBand" means waiting in line for the next race.
function Director:join(userId,mode)
	if self.off then return false,"Off"end
	if self:runner(userId)then return false,"AlreadySeated"end
	local ok,reason=self:check(userId,"join")
	if not ok then return false,reason end
	local now,heat=self.options.now(),self.heat
	local queued=find(self.queue,userId)
	if not heat and(#self.queue==0 or self.queue[1]==queued)then
		self:unqueue(userId)
		return true,nil,self:gather(userId,mode,now).id
	end
	local why="Queued"
	if heat and heat.phase=="gather"and #heat.seats<Director.MaxSeats then
		if self:fits(heat,userId)then
			self:unqueue(userId);self:seat(heat,userId,now)
			return true,nil,heat.id
		end
		why="WrongBand"
	end
	if queued then queued.mode=mode;return true,why end
	if #self.queue>=Director.MaxQueue then return false,"Full"end
	table.insert(self.queue,{userId=userId,mode=mode})
	self.dirty=true
	return true,why
end
function Director:unqueue(userId)
	local _,index=find(self.queue,userId)
	if index then table.remove(self.queue,index);self.dirty=true end
	return index~=nil
end
-- The first player alone at the gate may change what the race is.
function Director:mode(userId,mode)
	local heat=self.heat
	if self.off then return false,"Off"end
	if not heat or heat.phase~="gather"or #heat.seats~=1 or heat.seats[1].userId~=userId then return false,"Locked"end
	heat.mode,heat.band=mode,if mode=="stats"then Stats.band(self:levels(userId))else nil
	self.dirty=true
	return true,nil,heat.id
end
function Director:trial(userId)
	if self.off then return false,"Off"end
	if self:runner(userId)then return false,"AlreadySeated"end
	local ok,reason=self:check(userId,"join")
	if not ok then return false,reason end
	self:unqueue(userId)
	local now=self.options.now()
	local seed=self.options.seed()
	local race=Sim.new({seed=seed,mode="trial",runners={{}}})
	local record={userId=userId,petId=self:call("pet",userId),n=0,bad=0,seat=1}
	local trial={id=self.options.guid(),trial=true,phase="countdown",mode="trial",seats={record},seed=seed,race=race,goAt=now+Director.CountdownSeconds,stateAt=0}
	self.trials[userId]=trial
	self:call("tag",userId,trial.id)
	self:call("event",userId,{kind="joined",raceId=trial.id,seat=1,mode="trial",trial=true})
	self:call("event",userId,{kind="locked",raceId=trial.id,seat=1,mode="trial",goAt=trial.goAt,plan=Sim.publicPlan(race.plan),trial=true})
	return true,nil,trial.id
end

-- Leaving ------------------------------------------------------------------------------------------------------
-- Every way out: the Leave key, a disconnect, the Deck, another pet. Never refused, never blocks anything.
-- In a race the pet stays as a pal and wins nothing; the last player out ends it unpaid.
function Director:leave(userId,reason)
	local was=self:unqueue(userId)
	local trial=self.trials[userId]
	if trial then
		self.trials[userId]=nil
		self:call("tag",userId,nil)
		return true
	end
	local heat=self.heat
	local record,index=nil,nil
	if heat then record,index=find(heat.seats,userId)end
	if not record or heat.phase=="results"then return was end
	table.remove(heat.seats,index)
	self:call("tag",userId,nil)
	self.dirty=true
	if reason then self:call("event",userId,{kind="refused",raceId=heat.id,reason=reason})end
	if heat.phase~="gather"then
		local place=heat.lineup[record.seat]
		place.userId,place.pal,place.left=nil,true,true
		Sim.toBot(heat.race,record.seat)
		table.insert(heat.log,{at=heat.race.tick,seat=record.seat,k="left"})
	end
	if #heat.seats==0 then self:abort("Empty")end
	return true
end
-- Ends the race with nothing paid and every pet free.
function Director:abort(reason)
	local heat=self.heat
	if not heat then return end
	self.heat,self.dirty=nil,true
	for _,record in ipairs(heat.seats)do
		if self.trials[record.userId]then continue end -- already racing alone (only after the results)
		self:call("tag",record.userId,nil)
		if heat.phase~="results"then self:call("event",record.userId,{kind="aborted",r=heat.id,reason=reason})end
	end
end
function Director:abortTrial(userId,reason)
	local trial=self.trials[userId]
	if not trial then return end
	self.trials[userId]=nil
	self:call("tag",userId,nil)
	self:call("event",userId,{kind="aborted",r=trial.id,reason=reason})
end
function Director:shutdown(reason)
	self:abort(reason)
	for userId in pairs(table.clone(self.trials))do self:abortTrial(userId,reason)end
	for _,entry in ipairs(self.queue)do self:call("event",entry.userId,{kind="refused",reason=reason})end
	table.clear(self.queue)
	self.dirty=true
end
function Director:failed(problem)
	self.errors+=1
	pcall(self.options.warn,"[Dash] race stopped ("..self.errors.."): "..tostring(problem))
	if self.errors>=Director.MaxErrors then
		self.off=true
		self:shutdown("Off")
	end
end

-- Inputs -------------------------------------------------------------------------------------------------------
-- `packet` is Wire.input's copy, or nil for one that was malformed or over the rate. Answers nil, or the
-- refusal to send back. After MaxBad bad packets the player is ignored for the rest of that race.
function Director:input(userId,packet)
	local record,run=self:runner(userId)
	if not record or record.bad>=Director.MaxBad then return nil end
	if not packet then record.bad+=1;return nil end
	local function refuse(reason)return{kind="refusedInput",r=packet.r,n=packet.n,reason=reason}end
	if packet.r~=run.id then record.bad+=1;return refuse("race")end
	if packet.n<=record.n then record.bad+=1;return nil end -- a duplicate: the first one's answer stands
	record.n=packet.n
	if run.phase~="race"then return refuse("closed")end
	local ok,why=Sim.push(run.race,record.seat,packet.t,packet.k)
	if ok then
		if run.log then table.insert(run.log,{at=run.race.tick,seat=record.seat,t=packet.t,k=packet.k})end
		return nil
	end
	if why=="bad"or why=="flood"then record.bad+=1 end
	return refuse(why)
end

-- The clock ----------------------------------------------------------------------------------------------------
-- The gate closes: everyone is rechecked, then levels are frozen and the seed, lanes and luck are drawn.
function Director:lock(now)
	local heat=self.heat
	local kept={}
	for _,record in ipairs(heat.seats)do
		local ok,reason=self:check(record.userId,"countdown")
		if ok then record.levels=self:levels(record.userId)end
		local band=ok and Stats.band(record.levels)
		if ok and heat.mode=="stats"then
			if #kept==0 then heat.band=band
			elseif band~=heat.band then ok,reason=false,"WrongBand"end
		end
		if ok then table.insert(kept,record)
		else
			self:call("tag",record.userId,nil)
			self:call("event",record.userId,{kind="refused",raceId=heat.id,reason=reason})
		end
	end
	heat.seats=kept
	self.dirty=true
	if #kept==0 then self.heat=nil;return end
	local stats=heat.mode=="stats"
	local middle=if stats then Stats.bandMiddle(heat.band)else Stats.FunLevel
	heat.lineup,heat.specs,heat.log={},{},{}
	for seat,record in ipairs(kept)do
		record.seat=seat
		heat.lineup[seat]={seat=seat,userId=record.userId,petId=self:call("pet",record.userId)or record.petId}
		heat.specs[seat]=record.levels
	end
	for seat=#kept+1,Director.MinRunners do
		self.palAt+=1
		local pal=Director.Pals[(self.palAt-1)%#Director.Pals+1]
		heat.lineup[seat]={seat=seat,pal=true,petId=pal.petId,name=pal.name,tint=pal.tint}
		heat.specs[seat]={speed=middle,energy=middle,jump=middle,bot=true}
	end
	heat.seed=self.options.seed()
	heat.race=Sim.new({seed=heat.seed,mode=heat.mode,runners=heat.specs})
	heat.goAt,heat.endsAt,heat.phase,heat.stateAt=now+Director.CountdownSeconds,nil,"countdown",0
	local plan=Sim.publicPlan(heat.race.plan)
	for _,record in ipairs(kept)do
		self:call("event",record.userId,{kind="locked",raceId=heat.id,seat=record.seat,mode=heat.mode,goAt=heat.goAt,plan=plan,
			levels=if stats then record.levels else nil})
	end
end
-- What just happened to the players' own pets, for their screens.
local function notice(self,run)
	local race=run.race
	for _,record in ipairs(run.seats)do
		local r=race.runners[record.seat]
		if r.lastTick==race.tick then
			self:call("event",record.userId,{kind="judged",r=run.id,jump=r.next-1,result=r.lastKind,tick=race.tick})
		end
		if r.zoomTick==race.tick then self:call("event",record.userId,{kind="zoom",r=run.id,tick=race.tick})end
	end
end
-- Steps one race toward the clock. True when it is over.
function Director:advance(run,now)
	if run.phase=="countdown"then
		if now<run.goAt then return false end
		run.phase="race"
		if not run.trial then self.dirty=true end
	end
	local race=run.race
	local target=math.floor((now-run.goAt)*Stats.TicksPerSecond)-Sim.LagTicks
	local stepped=0
	while race.tick<target and stepped<Director.StepTicks and not race.over do
		Sim.step(race)
		stepped+=1
		notice(self,run)
	end
	if stepped>0 and(now-run.stateAt>=Director.StateEvery or race.over)then
		run.stateAt=now
		self:call("state",if run.trial then run.seats[1].userId else nil,run.id,race)
	end
	return race.over
end
local function standings(race)
	local out,places={},{}
	for place,seat in ipairs(Sim.placings(race))do
		out[place]={seat=seat,place=place,us=race.runners[seat].finishUs}
		places[seat]=place
	end
	return out,places
end
function Director:result(run,record,seats,place,prize)
	local r=run.race.runners[record.seat]
	self:call("tag",record.userId,nil)
	self:call("finished",record.userId,{kind=if run.trial then"trial"else"race",mode=run.mode,band=run.band,place=place,us=r.finishUs,
		inputs=r.inputs,seed=run.seed,prize=prize})
	self:call("event",record.userId,{kind="result",r=run.id,trial=run.trial,mode=run.mode,band=run.band,seats=seats,seat=record.seat,place=place,
		us=r.finishUs,medal=Stats.medal(run.mode,run.band,r.finishUs)})
end
function Director:finishHeat(now)
	local heat=self.heat
	local seats,places=standings(heat.race)
	heat.phase,heat.endsAt,heat.standings="results",now+Director.ResultSeconds,seats
	self.dirty=true
	table.insert(self.history,{id=heat.id,seed=heat.seed,mode=heat.mode,band=heat.band,specs=heat.specs,log=heat.log,standings=seats})
	while #self.history>Director.History do table.remove(self.history,1)end
	local prize=self:call("prizes")==true
	for _,record in ipairs(heat.seats)do self:result(heat,record,seats,places[record.seat],prize)end
end
function Director:finishTrial(userId,trial)
	self.trials[userId]=nil
	local us=trial.race.runners[1].finishUs
	if us then
		local day=self:call("day")
		if not self.best or self.best.day~=day or us<self.best.us then
			self.best={day=day,userId=userId,us=us}
			self.dirty=true
		end
	end
	self:result(trial,trial.seats[1],(standings(trial.race)),1,self:call("prizes")==true)
end
-- Nobody is racing: the line forms the next race, in order.
function Director:promote(now)
	local line=table.clone(self.queue)
	for _,entry in ipairs(line)do
		local heat=self.heat
		if heat and(#heat.seats>=Director.MaxSeats or entry.mode~=heat.mode or not self:fits(heat,entry.userId))then continue end
		local ok,reason=self:check(entry.userId,"queue")
		self:unqueue(entry.userId)
		if not ok then self:call("event",entry.userId,{kind="refused",reason=reason})
		elseif heat then self:seat(heat,entry.userId,now)
		else self:gather(entry.userId,entry.mode,now)end
	end
end
function Director:checkAll(now)
	if now-self.checkAt<Director.CheckEvery then return end
	self.checkAt=now
	for _,entry in ipairs(table.clone(self.queue))do
		local ok,reason=self:check(entry.userId,"queue")
		if not ok then
			self:unqueue(entry.userId)
			self:call("event",entry.userId,{kind="refused",reason=reason})
		end
	end
	local function seated(userId)
		local ok,reason=self:check(userId,"seat")
		if not ok then self:leave(userId,reason)end
	end
	if self.heat and self.heat.phase~="results"then for _,record in ipairs(table.clone(self.heat.seats))do seated(record.userId)end end
	for userId in pairs(table.clone(self.trials))do seated(userId)end
end
function Director:stepHeat(now)
	local heat=self.heat
	if not heat then
		if #self.queue>0 then self:promote(now)end
	elseif heat.phase=="gather"then
		if now>=heat.endsAt then self:lock(now)end
	elseif heat.phase=="results"then
		if now>=heat.endsAt then self.heat=nil;self.dirty=true end
	elseif self:advance(heat,now)then self:finishHeat(now)end
end
function Director:stepTrial(userId,trial,now)
	if self:advance(trial,now)then self:finishTrial(userId,trial)end
end
-- Every frame.
function Director:step()
	if not self.off then
		local now=self.options.now()
		local ok,problem=pcall(self.checkAll,self,now)
		if not ok then self:failed(problem)end
		ok,problem=pcall(self.stepHeat,self,now)
		if not ok then self:abort("Error");self:failed(problem)end
		if next(self.trials)then
			for userId,trial in pairs(table.clone(self.trials))do
				if self.trials[userId]~=trial then continue end
				ok,problem=pcall(self.stepTrial,self,userId,trial,now)
				if not ok then self:abortTrial(userId,"Error");self:failed(problem)end
			end
		end
	end
	self:flush()
end
function Director:flush()
	if not self.dirty then return end
	self.dirty=false
	self:call("publish",self:roster())
end

-- What everyone may see: no seed, no zoomies moments, no levels.
function Director:roster()
	local heat=self.heat
	local out={v=Wire.Version,phase="idle",seats={},queue={}}
	for index,entry in ipairs(self.queue)do out.queue[index]=entry.userId end
	if self.best then out.best={userId=self.best.userId,us=self.best.us}end
	if not heat then return out end
	out.phase,out.raceId,out.mode,out.band,out.endsAt,out.goAt,out.standings=heat.phase,heat.id,heat.mode,heat.band,heat.endsAt,heat.goAt,heat.standings
	if heat.lineup then
		out.seats=heat.lineup
		out.plan=Sim.publicPlan(heat.race.plan)
	else
		for seat,record in ipairs(heat.seats)do out.seats[seat]={seat=seat,userId=record.userId,petId=record.petId}end
	end
	return out
end

-- The same race again from its seed and inputs (the last History races are kept in memory): standings, for a check.
function Director.replay(entry)
	local race=Sim.new({seed=entry.seed,mode=entry.mode,runners=entry.specs})
	local head=1
	repeat
		while entry.log[head]and entry.log[head].at<=race.tick do
			local event=entry.log[head]
			head+=1
			if event.k=="left"then Sim.toBot(race,event.seat)
			else Sim.push(race,event.seat,event.t,event.k)end
		end
	until not Sim.step(race)
	return(standings(race))
end
return Director
