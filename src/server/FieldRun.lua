-- Pure run state: the host observes terminal-tick merges BEFORE calling step.
local FieldRun = {}
local Objectives=require(game:GetService("ReplicatedStorage").Shared.FieldObjectives)
local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
FieldRun.__index = FieldRun
FieldRun.Budget = 24
FieldRun.SettleSeconds = 4
FieldRun.ZoneBound = 2.6
FieldRun.MinTier = 3
FieldRun.BonusHeight = 7.5
local zoneEpsilon=1e-6 -- Vector2 coordinates round to float32 at inclusive edges.
FieldRun.MasteryTargets = { { side = -1, tier = 3 }, { side = 1, tier = 3 }, { side = -1, tier = 4 }, { side = 1, tier = 4 } }

function FieldRun.simulationOptions(seed,descriptor,preset)
	if descriptor then return Objectives.simulationOptions(descriptor,preset or "Springy")end
	return { seed = seed, starter = {}, kick = 6, contactGate = true }
end

-- Per heat (BoardConfig.Heat); no argument is Medium, today's round.
function FieldRun.roundOptions(heat)
	local spec = Config.heat(heat)
	return { overflowY = spec.overflowY, grace = spec.grace, armAfterDrops = spec.armAfter, warningMargin = 2 }
end

function FieldRun.new(options)
	options = options or {}
	local minimum = options.minTier or FieldRun.MinTier
	local targets = options.targets or { { side = -1, tier = minimum }, { side = 1, tier = minimum } }
	local descriptor=options.descriptor
	if descriptor then
		descriptor=Objectives.copy(descriptor);targets={}
		for _,goal in ipairs(descriptor.goals)do table.insert(targets,{side=if goal.zone.kind=="left"then -1 elseif goal.zone.kind=="right"then 1 else 0,tier=goal.tier or goal.minTier})end
	else
		local goals={}
		for index,target in ipairs(targets)do table.insert(goals,{id="legacy_"..index,kind="merge",minTier=target.tier,
			zone={kind=if target.side<0 then "left"else "right",min=if target.side<0 then -math.huge else FieldRun.ZoneBound,
				max=if target.side<0 then -FieldRun.ZoneBound else math.huge},target=1})end
		descriptor=Objectives.copy({id="bank_pair",title="Bank pair",seed=options.seed or 1,
			dynamics={id="classic",label="Classic banks",kick=6,bounceScale=1},goals=goals})
	end
	targets=Objectives.copy(targets)
	return setmetatable({ budget = FieldRun.Budget, rootStage = 0, phase = "Playing", settleTime = 0,
		minTier = minimum, targets = targets, goalCount = #targets, zoneBound = FieldRun.ZoneBound,
		descriptor=descriptor,goalProgress=0,lastOrdinal=0,sequence=options.sequence,
		heat=Config.heat(options.heat or descriptor.heat).key,
		-- The tidy +2 line moves with the overflow line (Hard is lower).
		bonusHeight=options.bonusHeight or(if options.heat or descriptor.heat then Config.heat(options.heat or descriptor.heat).bonusHeight else FieldRun.BonusHeight) }, FieldRun)
end

function FieldRun:target()
	return self.targets[self.rootStage + 1]
end

function FieldRun:canDrop(drops)
	return self.phase == "Playing" and drops < self.budget
end

function FieldRun:objective()return self.descriptor.goals[self.rootStage+1]end
function FieldRun:observe(merge,event)
	local goal=self:objective()
	if self.phase=="Complete"or not goal then return false end
	event=event or {ordinal=self.lastOrdinal+1,chain=1}
	if self.sequence and event.sequence~=self.sequence then return false end
	local ordinal=event.ordinal
	if type(ordinal)~="number"or ordinal%1~=0 or ordinal<=self.lastOrdinal then return false end
	self.lastOrdinal=ordinal
	if goal.kind=="merge"then
		if goal.tier and merge.tier~=goal.tier or goal.minTier and merge.tier<goal.minTier then return false end
		local x=merge.position.X;local zone=goal.zone
		if zone.min and x<zone.min-zoneEpsilon or zone.max and x>zone.max+zoneEpsilon then return false end
		self.goalProgress+=1
	elseif goal.kind=="count"then self.goalProgress+=1
	else
		local identity=ordinal-(event.chain or 1)+1
		self.goalProgress=if identity==self.chainIdentity then self.goalProgress+1 else 1
		self.chainIdentity=identity
	end
	if self.goalProgress>=goal.target then self.rootStage+=1;self.goalProgress=0;self.chainIdentity=nil end
	return true
end
function FieldRun:expireChain(playTime,lastMerge)
	local goal=self:objective()
	if goal and goal.kind=="chain"and self.goalProgress>0 and playTime-lastMerge>1.25 then
		self.goalProgress=0;self.chainIdentity=nil;return true
	end
	return false
end
function FieldRun:public(sequence)
	local goal=self:objective()
	return Objectives.copy({sequence=sequence,templateId=self.descriptor.id,title=self.descriptor.title,
		dynamics={id=self.descriptor.dynamics.id,label=self.descriptor.dynamics.label},goals=self.descriptor.goals,
		step=self.rootStage+1,progress=if goal then self.goalProgress else 0,target=if goal then goal.target else 0,complete=goal==nil})
end

local function height(eggs)
	local maximum = 0
	for _, egg in ipairs(eggs) do
		maximum = math.max(maximum, egg.position.Y + egg.radius)
	end
	return maximum
end

function FieldRun:step(eggs, dt, drops, overflow)
	if self.phase == "Complete" then return self.outcome end
	if overflow then
		self.phase = "Complete"
	elseif drops >= self.budget then
		if self.phase ~= "Settling" then
			self.phase = "Settling"
			self.settleTime = 0
		else
			self.settleTime += dt
		end
		if self.settleTime >= FieldRun.SettleSeconds then self.phase = "Complete" end
	end
	if self.phase == "Complete" then
		local maxHeight = height(eggs)
		local success = not overflow and self.rootStage == self.goalCount
		self.outcome = {
			success = success,
			reward = if success then 6 + (if maxHeight <= self.bonusHeight then 2 else 0) else 0,
			reason = if overflow then "Overflow" elseif success then self.descriptor.title.." complete" else self.descriptor.title.." incomplete",
			rootStage = self.rootStage,
			maxHeight = maxHeight,
		}
		return self.outcome
	end
	return nil
end

return FieldRun
