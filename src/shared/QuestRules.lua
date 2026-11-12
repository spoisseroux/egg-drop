-- Quest progress (QUESTS-DIFFICULTY-PLAN section 2). Pure: reads only facts the
-- server measured for a finished round (the award summary): success, clean,
-- score, chain, drops, heat, maxTier, goalsMet and templateId.
local Shared = script.Parent
local Config = require(Shared.BoardConfig)
local Objectives = require(Shared.FieldObjectives)
local Rules = {}

local function popcount(mask)
	local count = 0
	while mask > 0 do count += mask % 2; mask = mask // 2 end
	return count
end
Rules.popcount = popcount

function Rules.templateBit(id)
	local index = table.find(Objectives.Order, id)
	return if index then bit32.lshift(1, index - 1) else 0
end
function Rules.heatBit(heat)
	local spec = Config.Heat[heat]
	return if spec then bit32.lshift(1, spec.index - 1) else 0
end

-- The largest stored value: sum/max clamp to target; set masks stay inside their field.
function Rules.maxStored(def)
	if def.mode == "set" then
		return if def.metric == "templates" then bit32.lshift(1, #Objectives.Order) - 1 else bit32.lshift(1, #Config.HeatOrder) - 1
	end
	return def.target
end

-- Whether a finished round counts at all for this quest.
function Rules.counts(def, summary)
	if type(summary) ~= "table" or summary.drops ~= 24 then return false end
	if def.heat then
		local need, got = Config.Heat[def.heat], Config.Heat[summary.heat or Config.DefaultHeat]
		if not need or not got or got.index < need.index then return false end
	end
	return true
end

-- What one round measured for this quest.
function Rules.value(def, summary)
	local m = def.metric
	if m == "rounds" then return 1
	elseif m == "wins" then return if summary.success then 1 else 0
	elseif m == "cleanWins" then return if summary.success and summary.clean then 1 else 0
	elseif m == "score" then return summary.score or 0
	elseif m == "chain" then return summary.chain or 0
	elseif m == "tierMade" then return if (summary.maxTier or 0) >= (def.tier or 5) then 1 else 0
	elseif m == "goalsMet" then return summary.goalsMet or 0
	elseif m == "heatsPlayed" then return Rules.heatBit(summary.heat or Config.DefaultHeat)
	elseif m == "templates" then return Rules.templateBit(summary.templateId)
	end
	return 0
end

-- New stored progress after one finished round.
function Rules.progress(def, prev, summary)
	prev = if type(prev) == "number" then prev else 0
	if not Rules.counts(def, summary) then return prev end
	local value = Rules.value(def, summary)
	if def.mode == "set" then return bit32.bor(prev, value) end
	if def.mode == "max" then return math.min(def.target, math.max(prev, value)) end
	return math.min(def.target, prev + value)
end

-- Progress as shown: 0..target.
function Rules.count(def, prog)
	prog = if type(prog) == "number" then prog else 0
	if def.mode == "set" then return math.min(def.target, popcount(prog)) end
	return math.min(def.target, prog)
end

function Rules.complete(def, prog)
	return Rules.count(def, prog) >= def.target
end

function Rules.validProgress(def, prog)
	return type(prog) == "number" and prog == prog and prog % 1 == 0 and prog >= 0 and prog <= Rules.maxStored(def)
end

return table.freeze(Rules)
