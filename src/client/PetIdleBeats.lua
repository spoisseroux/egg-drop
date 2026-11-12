-- Idle personality beats (C3/C4): after more than 8 s idle the pet yawns,
-- stretches, sneezes, looks around or waves (wave only when its owner has stood
-- still within 6 studs). At most one beat per 10 s. The sequence comes from a
-- per-pet seed, so the same pet behaves the same way across a rejoin. Local
-- presentation only; the visual advances this with its own dt.
local Beats = {}
Beats.IdleAfter = 8
Beats.Gap = 10
Beats.Kinds = { "yawn", "stretch", "sneeze", "look", "wave" }
Beats.Durations = { yawn = 2.2, stretch = 1.8, sneeze = 1.4, look = 2.4, wave = 1.8 }

local function seedFor(visual)
	local text = tostring(visual.petId or "")
	local hash = 0
	for i = 1, #text do hash = (hash * 31 + string.byte(text, i)) % 1000003 end
	return (math.abs(math.floor(visual.cosmeticSeed or 0)) + hash) % 2147483647
end

-- Advance the scheduler. Returns the running beat kind and its 0..1 phase, or nil.
-- eligible: not carried, cared for, petted, playing with a toy or focused (the idle
-- clock runs through ordinary wandering). stationary: a beat only starts, and only
-- continues, while the pet stands still.
function Beats.step(visual, dt, eligible, ownerNearStill, stationary)
	stationary = stationary ~= false
	local s = visual.idleBeat
	if not s then
		s = { idle = 0, clock = 0, last = -math.huge }
		visual.idleBeat = s
	end
	dt = math.clamp(dt or 0, 0, .25)
	s.clock += dt
	if not eligible then
		s.idle, s.kind = 0, nil
		return nil
	end
	if s.kind and not stationary then
		-- The pet walked off mid-beat: the beat ends and the spacing still counts.
		s.kind, s.idle, s.last = nil, 0, s.clock
		return nil
	end
	if s.kind then
		s.age += dt
		local duration = Beats.Durations[s.kind]
		if s.age < duration then return s.kind, s.age / duration end
		s.kind, s.idle, s.last = nil, 0, s.clock
		return nil
	end
	s.idle += dt
	if not s.random then
		s.random = Random.new(seedFor(visual))
		s.jitter = s.random:NextNumber(0, 2)
	end
	if stationary and s.idle > Beats.IdleAfter + s.jitter and s.clock - s.last >= Beats.Gap then
		local kind = Beats.Kinds[s.random:NextInteger(1, #Beats.Kinds)]
		if kind == "wave" and not ownerNearStill then kind = "look" end
		s.kind, s.age, s.jitter = kind, 0, s.random:NextNumber(0, 2)
		s.count = (s.count or 0) + 1
		if visual.model then visual.model:SetAttribute("IdleBeat", kind) end
		return kind, 0
	end
	return nil
end

-- Pose offsets for a running beat. All are additive levers GardenPetVisual already
-- has: head pitch/yaw, hand folds (L, R), body stretch, eye scale, an open mouth
-- and an expression override.
function Beats.pose(kind, phase)
	local env = math.sin(math.clamp(phase, 0, 1) * math.pi)
	if kind == "yawn" then
		return -.16 * env, 0, .25 * env, .25 * env, .03 * env, 1 - .7 * env, env > .25, "sleepy"
	elseif kind == "stretch" then
		return -.06 * env, 0, 1.1 * env, 1.1 * env, .07 * env, 1, false, "pleased"
	elseif kind == "sneeze" then
		-- Build up (head back, eyes squeeze), then a quick snap forward at 70%.
		local build = math.clamp(phase / .7, 0, 1)
		local snap = if phase > .7 then math.sin((phase - .7) / .3 * math.pi) else 0
		return -.1 * build * (1 - snap) + .22 * snap, 0, .15 * snap, .15 * snap, 0, 1 - .8 * math.max(build * (1 - snap), snap), phase > .68 and phase < .85, "startled"
	elseif kind == "look" then
		return 0, math.sin(phase * math.pi * 2) * .45 * env, 0, 0, 0, 1, false, "curious"
	elseif kind == "wave" then
		return 0, 0, 0, (1.5 + math.sin(phase * math.pi * 6) * .35) * env, 0, 1, false, "pleased"
	end
	return 0, 0, 0, 0, 0, 1, false, nil
end

return Beats
