-- Pure run state: the host observes terminal-tick merges BEFORE calling step.
local FieldRun = {}
FieldRun.__index = FieldRun
FieldRun.Budget = 24
FieldRun.SettleSeconds = 4
FieldRun.ZoneBound = 2.6
FieldRun.MinTier = 3
FieldRun.BonusHeight = 7.5
FieldRun.MasteryTargets = { { side = -1, tier = 3 }, { side = 1, tier = 3 }, { side = -1, tier = 4 }, { side = 1, tier = 4 } }

function FieldRun.simulationOptions(seed)
	return { seed = seed, starter = {}, kick = 6, contactGate = true }
end

function FieldRun.roundOptions()
	return { overflowY = 8.6, grace = 2.4, armAfterDrops = 12, warningMargin = 2 }
end

function FieldRun.new(options)
	options = options or {}
	local minimum = options.minTier or FieldRun.MinTier
	local targets = options.targets or { { side = -1, tier = minimum }, { side = 1, tier = minimum } }
	return setmetatable({ budget = FieldRun.Budget, rootStage = 0, phase = "Playing", settleTime = 0,
		minTier = minimum, targets = targets, goalCount = #targets, zoneBound = FieldRun.ZoneBound }, FieldRun)
end

function FieldRun:target()
	return self.targets[self.rootStage + 1]
end

function FieldRun:canDrop(drops)
	return self.phase == "Playing" and drops < self.budget
end

function FieldRun:observe(merge)
	local target = self:target()
	if self.phase == "Complete" or not target or merge.tier < target.tier then return end
	if merge.position.X * target.side >= self.zoneBound then self.rootStage += 1 end
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
			reward = if success then 6 + (if maxHeight <= FieldRun.BonusHeight then 2 else 0) else 0,
			reason = if overflow then "Overflow" elseif success then "Roots restored" else "Root patches incomplete",
			rootStage = self.rootStage,
			maxHeight = maxHeight,
		}
		return self.outcome
	end
	return nil
end

return FieldRun
