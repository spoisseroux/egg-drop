-- The local pet reacts to your play on the deck. Presentation only: no server
-- state, no remotes, and nothing visiting players can see. The visual samples
-- this once per frame from its own update; there are no tasks or extra clocks.
local Reactions = {}
Reactions.CheerCooldown = 1.5
Reactions.HopDuration = 0.55
Reactions.CheerFace = 0.9
Reactions.StartledFor = 0.4
Reactions.SleepyFor = 2.2

-- kind: "cheer" (tier III+ merge or a chain of 3+), "win" (double hop), "loss"
-- (startled 0.4 s, then sleepy). Returns true when the pet accepted the beat.
function Reactions.trigger(visual, kind, now)
	if not visual or visual.destroyed then return false end
	local state = visual.playReaction
	if kind == "cheer" then
		if state and now - (state.cheerAt or -math.huge) < Reactions.CheerCooldown then return false end
		-- A round-end beat in progress keeps its own face.
		if state and state.kind ~= "cheer" and now < state.untilTime then return false end
	end
	state = state or {}
	visual.playReaction = state
	state.kind, state.start = kind, now
	if kind == "cheer" then
		state.cheerAt = now
		state.untilTime = now + math.max(Reactions.HopDuration, Reactions.CheerFace)
	elseif kind == "win" then
		state.untilTime = now + Reactions.HopDuration * 2 + 0.6
	else
		state.untilTime = now + Reactions.StartledFor + Reactions.SleepyFor
	end
	return true
end

local function hopAt(age)
	if age < 0 or age >= Reactions.HopDuration then return 0 end
	return math.sin(age / Reactions.HopDuration * math.pi)
end

-- Returns hop amplitude (0..1, greet scale) and an expression override or nil.
function Reactions.sample(visual, now)
	local state = visual.playReaction
	if not state or now >= state.untilTime then return 0, nil end
	local age = now - state.start
	local reduced = visual.reducedEffects == true
	if state.kind == "cheer" then
		return if reduced then 0 else hopAt(age), "pleased"
	elseif state.kind == "win" then
		local hop = math.max(hopAt(age), hopAt(age - Reactions.HopDuration))
		return if reduced then 0 else hop, "pleased"
	end
	return 0, if age < Reactions.StartledFor then "startled" else "sleepy"
end

function Reactions.clear(visual)
	if visual then visual.playReaction = nil end
end

return Reactions
