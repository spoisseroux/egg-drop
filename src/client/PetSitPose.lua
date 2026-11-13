-- The cute sit (FEEL-ALIVE-DIRECTION-2026-11-13 B3). A relative overlay sampled by
-- GardenPetVisual: no root motion, no sound, no clock of its own.
-- Triggers: the `sit` idle beat; settle, nookRest and any rest of 4 s or more
-- (derived from replicated actions, so everyone sees the same pet sit); the owner
-- standing still within 8 studs for 6 s. In 0.35 s, out 0.3 s; Reduced Effects
-- snaps straight to the pose. 20 s into a sit with nothing happening the pet goes
-- dozy, then sleepy.
local Sit = {}
Sit.In, Sit.Out = .35, .3
Sit.Lower, Sit.Pitch = .22, math.rad(6)
Sit.FootForward, Sit.ToeUp, Sit.Splay = .16, math.rad(20), math.rad(15)
Sit.HandFold, Sit.HeadUp, Sit.HeadTilt, Sit.EarPerk = .35, math.rad(5), math.rad(8), math.rad(6)
Sit.OwnerRange, Sit.OwnerStill, Sit.RestLength = 8, 6, 4
Sit.DozyAfter, Sit.SleepyAfter = 20, 23

local quietActions = { settle = true, nookRest = true }

-- Whether a garden action (with its replicated length) is a sit.
function Sit.fromActivity(action, behavior, length)
	if quietActions[action] then return true end
	return (behavior == "rest" or action == "rest") and type(length) == "number" and length >= Sit.RestLength
end

function Sit.fromOwner(stillNearFor, gait)
	return type(stillNearFor) == "number" and stillNearFor >= Sit.OwnerStill and (gait or 0) < .03
end

-- Escalation face for a long sit (nil keeps the current face).
function Sit.face(age)
	if type(age) ~= "number" then return nil end
	if age >= Sit.SleepyAfter then return "sleepy" end
	if age >= Sit.DozyAfter then return "dozy" end
	return nil
end

-- Advance the sit blend toward target (0/1). beatWeight is the idle beat's own
-- envelope and wins when larger. Returns the 0..1 weight; landing starts the
-- boop squash once per sit.
function Sit.step(visual, dt, target, beatWeight)
	dt = math.clamp(dt or 0, 0, .25)
	local w = visual.sitBlend or 0
	if visual.reducedEffects then
		w = if target then 1 else 0
	elseif target then
		w = math.min(1, w + dt / Sit.In)
	else
		w = math.max(0, w - dt / Sit.Out)
	end
	visual.sitBlend = w
	local weight = math.max(w, beatWeight or 0)
	if weight >= 1 and not visual.sitLanded then
		visual.sitLanded = true
		if not visual.reducedEffects then visual.boopAt = os.clock() end
	elseif weight <= 0 then
		visual.sitLanded = false
	end
	if weight > 0 then visual.sitAge = (visual.sitAge or 0) + dt else visual.sitAge = nil end
	visual.sitWeight = weight
	return weight
end

-- Per-pet seeded side for the head tilt.
function Sit.side(visual)
	local seed = math.floor(math.abs(visual.cosmeticSeed or 0))
	return if seed % 2 == 0 then 1 else -1
end

-- Foot transform in root space for one side (-1 left, 1 right) at weight w.
function Sit.foot(entryFrame, side, w, scale)
	if w <= 0 then return CFrame.new() end
	local pivot = entryFrame.Position
	return CFrame.new(0, 0, Sit.FootForward * scale * w)
		* CFrame.new(pivot) * CFrame.Angles(-Sit.ToeUp * w, side * Sit.Splay * w, 0) * CFrame.new(-pivot)
end

return Sit
