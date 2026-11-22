-- Medal Stat Eggs (V3-LEVELS-BUILD-PLAN-2026-11-22, S4). One optional, additive field on the hatching
-- save (v11, no version bump):
--   medalEggsUsed = n      medal eggs opened so far (whole, 0..StoredMax); missing = 0
-- The credit is derived, never granted: left = max(0, medals earned by the saved XP - medalEggsUsed).
-- Writing the XP is the grant, so a crossing, a replayed write, a shutdown or a seeded save cannot pay
-- twice, and XP lost to a repair cannot pay again on the way back. The only write is the spend, inside
-- StatEggState.buy's transaction (which bumps the egg serial and stores the receipt with it).
--
-- The field sits beside statEgg, not in it, because load may drop statEgg as a whole. The live build
-- ignores and keeps it. A malformed value fails closed: it reads as "all used" everywhere, and load
-- writes the number earned (sanitize). It is never part of HatchProgress.valid, so it can never fail a
-- load or an unrelated write.
local Shared=game:GetService("ReplicatedStorage").Shared
local Gate=require(Shared.LevelGate)
local Levels=require(Shared.Levels)
local Medals=require(Shared.Medals)
local Stats=require(script.Parent.StatState)

local State={}
State.StoredMax=1000000 -- frozen storage bound

local function integer(value)
	return type(value)=="number"and value==value and value%1==0 and value>=0 and value<=State.StoredMax
end
-- Medals of every owned pet, from the save's XP.
function State.earned(state)
	if type(state)~="table"then return 0 end
	return Medals.earned(Gate.levels(Stats.publicLevels(state).pets))
end
-- Eggs opened, or nil when the field is malformed.
function State.used(state)
	local value=type(state)=="table"and state.medalEggsUsed
	if value==nil then return 0 end
	return if integer(value)then value else nil
end
function State.left(state)
	if type(state)~="table"then return 0 end
	local used=State.used(state)
	if used==nil then return 0 end
	return math.max(0,State.earned(state)-used)
end
-- Spends one, inside the buy's transaction. False (nothing written) when none is left.
function State.spend(state)
	if State.left(state)<1 then return false end
	local used=State.used(state)+1
	if used>State.StoredMax then return false end
	state.medalEggsUsed=used
	return true
end
-- Load-time repair, after the stats seed (the seed may earn medals): a malformed count becomes the
-- number earned, so a broken field can never hand out eggs. Off: nothing is written.
function State.sanitize(state)
	if type(state)~="table"or not Levels.on("medals")then return end
	if State.used(state)==nil then state.medalEggsUsed=math.min(State.earned(state),State.StoredMax)end
end
return State
