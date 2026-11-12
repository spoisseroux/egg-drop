-- Round payout per difficulty (QUESTS-DIFFICULTY-PLAN section 1, "Payout").
-- The multiplier applies to the whole round amount (base 6 and the tidy +2),
-- before the 2x pass; Supporter stays a flat +1 after it. Integer, half-up:
--   roundStars = (amount * tenths + 5) // 10
--   total      = roundStars * passMultiplier + supporterBonus
-- Easy 5/6, Medium 6/8, Hard 9/12; with both passes Hard tidy pays 25.
local Config = require(script.Parent.BoardConfig)
local Payout = {}

Payout.Win = 6
Payout.TidyWin = 8

function Payout.roundStars(amount, heat)
	local spec = Config.Heat[heat]
	assert(spec, "Unknown heat")
	assert(type(amount) == "number" and amount >= 0 and amount % 1 == 0, "Invalid round amount")
	return (amount * spec.tenths + 5) // 10
end

-- boost = { multiplier = 1|2, bonus = 0|1 } (StoreCatalog.boost).
function Payout.total(amount, heat, boost)
	boost = type(boost) == "table" and boost or {}
	local multiplier = if boost.multiplier == 2 then 2 else 1
	local bonus = if boost.bonus == 1 then 1 else 0
	return Payout.roundStars(amount, heat) * multiplier + bonus
end

-- What a win pays at this heat for this player: plain and tidy totals.
function Payout.range(heat, boost)
	return Payout.total(Payout.Win, heat, boost), Payout.total(Payout.TidyWin, heat, boost)
end

-- "×0.8", "×1", "×1.5"
function Payout.label(heat)
	local tenths = Config.heat(heat).tenths
	if tenths % 10 == 0 then return "×" .. (tenths // 10) end
	return string.format("×%d.%d", tenths // 10, tenths % 10)
end

-- "9–12"
function Payout.rangeText(heat, boost)
	local low, high = Payout.range(heat, boost)
	return low .. "–" .. high
end

return table.freeze(Payout)
