-- Garden Dash prediction (V3-DASH-BUILD-PLAN-2026-11-22, slice S7). Pure: the owner's pet, run by the same DashSim
-- the server runs, with only what the server sent (its public plan, the owner's own frozen levels). One runner,
-- fixed ticks, so the same accepted inputs and zoomies give the same pet, bit for bit.
--   * the clock is the server's plus one fixed lead for the whole race (Predict.lead), so an honest input always
--     reaches the server before its tick is stepped;
--   * a refused input or the server's zoomies edit the log; the next step runs the race again from tick 0, once for
--     however many came: nothing is replayed on screen, the drawn pet eases to the new place (EaseSeconds) or snaps when it is SnapCs away;
--   * the server's 10 Hz states are checked against what was drawn for that tick; two that still disagree after
--     ConfirmTicks (so a correction on its way has landed) and the race is drawn from the server's states alone.
-- The result only ever comes from the server.
local Shared=game:GetService("ReplicatedStorage").Shared
local Sim=require(Shared.DashSim)
local Course=require(Shared.DashCourse)
local Stats=require(Shared.DashStats)
local Predict={};Predict.__index=Predict
Predict.InputsPerSecond=8 -- the server takes 10: a held Dash can always be let go
Predict.MaxStep=120 -- ticks a frame, after a hitch
Predict.EaseSeconds=.25
Predict.SnapCs=600
Predict.ConfirmTicks=60
Predict.MaxMismatches=2
local UNIT=Stats.UnitsPerCs

-- Seconds the race clock runs ahead of the server's, from the round trip. Nothing for a near player.
function Predict.lead(rtt)
	if type(rtt)~="number"or rtt~=rtt then return 0 end
	return math.clamp(rtt/2+.03-Sim.LagTicks/Stats.TicksPerSecond,0,.3)
end
-- options: raceId, seat, plan (Sim.publicPlan), levels (Stats On), goAt, lead. nil when the plan is not one.
function Predict.new(options)
	local plan=options.plan
	if type(plan)~="table"or type(plan.lanes)~="table"or type(plan.clovers)~="table"or type(options.goAt)~="number"or not Course.Layouts[plan.layout]then return nil end
	local lane=plan.lanes[options.seat]
	if type(lane)~="number"then return nil end
	local self=setmetatable({raceId=options.raceId,goAt=options.goAt,lead=options.lead or 0,
		plan={mode=plan.mode,count=1,layout=plan.layout,lanes={lane},clovers=plan.clovers,cloverHurdle=plan.cloverHurdle,zoomies={}},
		levels=if type(options.levels)=="table"then options.levels else{},
		log={},n=0,zooms={},history=buffer.create(2*(Sim.MaxTicks+2)),
		target=-1,fraction=0,ease=0,easeLeft=0,mismatches=0,pending=nil,serverRender=false,dirty=false,rebuilds=0,
		seenTick=0,seenClover=0,seenPuffs=0},Predict)
	self:fresh()
	return self
end
function Predict:fresh()
	self.race=Sim.new({plan=self.plan,runners={self.levels}})
	self.runner=self.race.runners[1]
end
local function tick(self)
	local race=self.race
	Sim.step(race)
	if self.zooms[race.tick]then Sim.zoom(race,1)end
	buffer.writeu16(self.history,race.tick*2,math.min(self.runner.pos//UNIT,65535))
end
-- Brings the race to the clock. Call once a frame; presses made between frames land on the next tick.
function Predict:step(now,dt)
	if self.dirty then self:rebuild()end
	local clock=(now-self.goAt+self.lead)*Stats.TicksPerSecond
	local target=math.floor(clock)
	self.target=target
	local race,steps=self.race,0
	while race.tick<target and steps<Predict.MaxStep and not race.over do
		tick(self)
		steps+=1
	end
	self.fraction=if race.tick==target then clock-target else 0
	if self.easeLeft>0 then self.easeLeft=math.max(0,self.easeLeft-dt)end
	local pending=self.pending
	if pending and target>=pending.due then
		self.pending=nil
		if buffer.readu16(self.history,pending.tick*2)~=pending.cs then
			self.mismatches+=1
			if self.mismatches>=Predict.MaxMismatches then self.serverRender=true end
		end
	end
end
function Predict:started()return self.target>=0 end
function Predict:finished()return self.runner.finishUs~=nil end

-- Whether another input may go out now. Letting Dash go is never refused.
function Predict:paced(kind)
	if kind=="dashUp"then return true end
	local log,count=self.log,0
	for i=#log,1,-1 do
		if self.race.tick+1-log[i].t>=Stats.TicksPerSecond then break end
		count+=1
	end
	return count<Predict.InputsPerSecond
end
-- A button event now. Returns the packet to send, or nil when it does not count.
function Predict:press(kind)
	if not self:started()or self:finished()or self.race.over or not self:paced(kind)then return nil end
	local at=self.race.tick+1
	if not Sim.push(self.race,1,at,kind)then return nil end
	self.n+=1
	table.insert(self.log,{n=self.n,t=at,k=kind})
	return{r=self.raceId,n=self.n,t=at,k=kind}
end

-- Corrections ------------------------------------------------------------------------------------------------
function Predict:rebuild()
	self.dirty=false
	local upTo,before=self.race.tick,self:cs()
	local finished=self.runner.finishUs
	self:fresh()
	local race,log,at=self.race,self.log,1
	while race.tick<upTo and not race.over do
		while log[at]and log[at].t<=race.tick+1 do
			Sim.push(race,1,log[at].t,log[at].k)
			at+=1
		end
		tick(self)
	end
	-- Presses already stamped for the tick after this one.
	while log[at]do Sim.push(race,1,log[at].t,log[at].k);at+=1 end
	self.rebuilds+=1
	-- Quiet: what the new run says already happened is not shown again.
	local r=self.runner
	self.seenTick,self.seenClover,self.seenPuffs=r.lastTick,r.cloverTick,r.puffs
	self.easeLeft=0
	local off=before-self:cs()
	if math.abs(off)<=Predict.SnapCs and not finished then self.ease,self.easeLeft=off,Predict.EaseSeconds end
end
-- The server did not count input n.
function Predict:refused(n)
	for i=#self.log,1,-1 do
		if self.log[i].n==n then
			table.remove(self.log,i)
			self.dirty=true
			return true
		end
	end
	return false
end
-- The server gave this pet zoomies on that tick.
function Predict:zoom(at)
	if type(at)~="number"or at%1~=0 or at<1 or at>Sim.MaxTicks or self.zooms[at]then return false end
	self.zooms[at]=true
	if at<=self.race.tick then self.dirty=true end
	return true
end
-- A server state for this pet: remembered when it disagrees, judged ConfirmTicks later.
function Predict:observe(at,cs)
	if self.serverRender or self.pending or at<1 or at>self.race.tick then return end
	if buffer.readu16(self.history,at*2)~=cs then self.pending={tick=at,cs=cs,due=self.target+Predict.ConfirmTicks}end
end

-- Drawing ----------------------------------------------------------------------------------------------------
-- The runner's own distance in cs, between ticks, with a correction still easing in.
function Predict:cs()
	local r=self.runner
	local pos=r.pos
	if not r.finishUs and r.tumble==0 and self.race.tick>0 and not self.race.over then pos=math.min(r.total,pos+r.step*self.fraction)end
	local cs=pos/UNIT
	if self.easeLeft>0 then cs+=self.ease*(self.easeLeft/Predict.EaseSeconds)end
	return cs
end
-- What just happened to this pet and has not been shown: "perfect"/"clear"/"trip", then "clover", then "puff".
function Predict:news()
	local r=self.runner
	if r.lastTick~=self.seenTick then
		self.seenTick=r.lastTick
		return if r.lastKind==Sim.Result.Perfect then "perfect"elseif r.lastKind==Sim.Result.Clear then "clear"elseif r.lastKind==Sim.Result.Trip then "trip"else nil
	end
	if r.cloverTick~=self.seenClover then self.seenClover=r.cloverTick;return "clover"end
	if r.puffs~=self.seenPuffs then self.seenPuffs=r.puffs;return "puff"end
	return nil
end
return Predict
