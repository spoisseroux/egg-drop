-- Idle personality beats (C3/C4, retuned by FEEL-ALIVE-DIRECTION-2026-11-13 B2):
-- after about 5 s idle the pet looks around, sits, stretches, wiggles, waves,
-- yawns, sneezes or scratches an ear; a new beat at most every 7 s (plus the
-- seeded 0-2 s jitter), so a standing pet does something about every 9 s. The
-- pick is weighted (day and night tables) and never repeats the last beat. Wave
-- needs the owner standing still within 6 studs (otherwise it becomes a look).
-- The sequence comes from a per-pet seed, so the same pet behaves the same way
-- across a rejoin. Local presentation only; the visual advances this with its own dt.
local Beats = {}
Beats.IdleAfter = 5
Beats.Gap = 7
Beats.Kinds = { "look", "sit", "stretch", "wiggle", "wave", "yawn", "sneeze", "scratch" }
Beats.Durations = { yawn = 2.4, stretch = 2.2, sneeze = 1.4, look = 2.8, wave = 1.8, wiggle = 1.2, scratch = 1.6 }
-- A sit is "in 0.35 s, hold 6 to 14 s, out 0.3 s" (B3); its length is rolled per sit.
Beats.SitIn, Beats.SitOut, Beats.SitHoldMin, Beats.SitHoldMax = .35, .3, 6, 14
Beats.DayWeights = { look = 28, sit = 16, stretch = 14, wiggle = 10, wave = 12, yawn = 10, sneeze = 5, scratch = 5 }
Beats.NightWeights = { yawn = 30, sit = 25, look = 20, stretch = 10, wiggle = 5, sneeze = 4, scratch = 3, wave = 3 }
Beats.Night = .3
-- Coos a beat may ask for when it ends or lands (B2 "Coo triggers"): chance, cue.
Beats.Coos = { sit = { .5, "pet_coo_3" }, stretch = { .35, "pet_coo_2" }, yawn = { .5, "pet_coo_3" } }

local function seedFor(visual)
	local text = tostring(visual.petId or "")
	local hash = 0
	for i = 1, #text do hash = (hash * 31 + string.byte(text, i)) % 1000003 end
	return (math.abs(math.floor(visual.cosmeticSeed or 0)) + hash) % 2147483647
end

function Beats.weights(daylight)
	return if type(daylight) == "number" and daylight < Beats.Night then Beats.NightWeights else Beats.DayWeights
end

-- Weighted pick that never returns `previous`. A wave without the owner standing
-- near gives its weight to look (B2).
function Beats.pick(random, daylight, previous, ownerNearStill)
	local weights = Beats.weights(daylight)
	local total = 0
	local function weightOf(kind)
		if kind == previous then return 0 end
		local w = weights[kind] or 0
		if kind == "wave" and not ownerNearStill then return 0 end
		if kind == "look" and not ownerNearStill and previous ~= "look" then w += weights.wave or 0 end
		return w
	end
	for _, kind in ipairs(Beats.Kinds) do total += weightOf(kind) end
	local roll = random:NextNumber() * total
	for _, kind in ipairs(Beats.Kinds) do
		roll -= weightOf(kind)
		if roll <= 0 and weightOf(kind) > 0 then return kind end
	end
	for _, kind in ipairs(Beats.Kinds) do if weightOf(kind) > 0 then return kind end end
	return "look"
end

-- Advance the scheduler. Returns the running beat kind and its 0..1 phase, or nil.
-- eligible: not carried, cared for, petted, playing with a toy or focused (the idle
-- clock runs through ordinary wandering). stationary: a beat only starts, and only
-- continues, while the pet stands still. daylight picks the day/night weights.
function Beats.step(visual, dt, eligible, ownerNearStill, stationary, daylight)
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
		if s.age < s.duration then
			if s.kind == "sit" and not s.landed and s.age >= Beats.SitIn then
				s.landed = true
				Beats.requestCoo(visual, s, "sit")
			end
			return s.kind, s.age / s.duration
		end
		Beats.requestCoo(visual, s, s.kind ~= "sit" and s.kind or nil)
		s.kind, s.idle, s.last = nil, 0, s.clock
		return nil
	end
	s.idle += dt
	if not s.random then
		s.random = Random.new(seedFor(visual))
		s.jitter = s.random:NextNumber(0, 2)
	end
	if stationary and s.idle > Beats.IdleAfter + s.jitter and s.clock - s.last >= Beats.Gap then
		local kind = Beats.pick(s.random, daylight, s.previous, ownerNearStill)
		s.kind, s.age, s.jitter, s.previous, s.landed = kind, 0, s.random:NextNumber(0, 2), kind, false
		s.duration = if kind == "sit" then Beats.SitIn + s.random:NextNumber(Beats.SitHoldMin, Beats.SitHoldMax) + Beats.SitOut else Beats.Durations[kind]
		s.side = if s.random:NextNumber() < .5 then -1 else 1
		s.count = (s.count or 0) + 1
		if visual.model then visual.model:SetAttribute("IdleBeat", kind) end
		return kind, 0
	end
	return nil
end

-- A beat asks PetCooScheduler for a mood coo by leaving it on the visual.
function Beats.requestCoo(visual, s, kind)
	local rule = kind and Beats.Coos[kind]
	if rule and s.random and s.random:NextNumber() < rule[1] then visual.pendingCoo = rule[2] end
end

-- Sit weight 0..1 for a running sit beat (in 0.35 s, out 0.3 s).
function Beats.sitWeight(s)
	if not s or s.kind ~= "sit" then return 0 end
	local t = s.age or 0
	local w = math.min(1, t / Beats.SitIn, math.max(0, s.duration - t) / Beats.SitOut)
	return math.clamp(w, 0, 1)
end

local function ease(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Pose offsets for a running beat. All are additive levers GardenPetVisual already
-- has: head pitch/yaw, hand folds (L, R), body stretch, eye scale, an open mouth,
-- an expression override, then rise (studs x scale), hip roll (radians) and a
-- tail wag rate boost. side (-1/1) mirrors look and scratch per beat.
function Beats.pose(kind, phase, side)
	phase = math.clamp(phase or 0, 0, 1)
	side = side or 1
	local env = math.sin(phase * math.pi)
	if kind == "yawn" then
		-- Head back 9 degrees, mouth open from 20 % to 80 %, right paw to the mouth.
		local open = phase > .2 and phase < .8
		return -.16 * env, 0, .25 * env, .9 * env, .03 * env, 1 - .7 * env, open, "sleepy", 0, 0, 0
	elseif kind == "stretch" then
		-- Arms up and out, body long, onto the toes; eyes shut in the middle third,
		-- tail up; a small settle squash in the last 7 %.
		local reach = ease(phase / .3) * (1 - ease((phase - .75) / .2))
		local settle = if phase > .93 then -math.sin((phase - .93) / .07 * math.pi) * .05 else 0
		local eye = if phase > .33 and phase < .66 then .15 else 1
		return -.06 * reach, 0, 1.1 * reach, 1.1 * reach, (.07 + .03 * reach) * reach + settle, eye, false, "pleased", .05 * reach, 0, 2
	elseif kind == "sneeze" then
		-- Build up (head back, eyes squeeze), then a quick snap forward at 70%.
		local build = math.clamp(phase / .7, 0, 1)
		local snap = if phase > .7 then math.sin((phase - .7) / .3 * math.pi) else 0
		return -.1 * build * (1 - snap) + .22 * snap, 0, .15 * snap, .15 * snap, 0, 1 - .8 * math.max(build * (1 - snap), snap), phase > .68 and phase < .85, "startled", 0, 0, 0
	elseif kind == "look" then
		-- 2.8 s: turn 30 degrees to one side, hold 0.5 s, swing 22 degrees to the other, back.
		local t = phase * Beats.Durations.look
		local yaw
		if t < .6 then yaw = math.rad(30) * ease(t / .6)
		elseif t < 1.1 then yaw = math.rad(30)
		elseif t < 1.9 then yaw = math.rad(30) + (math.rad(-22) - math.rad(30)) * ease((t - 1.1) / .8)
		elseif t < 2.3 then yaw = math.rad(-22)
		else yaw = math.rad(-22) * (1 - ease((t - 2.3) / .5)) end
		return 0, yaw * side, 0, 0, 0, 1, false, "curious", 0, 0, 0
	elseif kind == "wave" then
		return 0, 0, 0, (1.5 + math.sin(phase * math.pi * 6) * .35) * env, 0, 1, false, "pleased", 0, 0, 0
	elseif kind == "wiggle" then
		-- Hips sway 4 degrees three times, fast tail, pleased.
		return 0, 0, .1 * env, .1 * env, 0, 1, false, "pleased", 0, math.sin(phase * math.pi * 6) * math.rad(4) * env, 3
	elseif kind == "scratch" then
		-- One paw up to the ear, head tilted into it, a quick scratch.
		local scratch = math.sin(phase * math.pi * 10) * .12
		local l = if side < 0 then (1.3 + scratch) * env else 0
		local r = if side > 0 then (1.3 + scratch) * env else 0
		return .04 * env, -side * .12 * env, l, r, 0, .7, false, "content", 0, side * math.rad(3) * env, 0
	elseif kind == "sit" then
		return 0, 0, 0, 0, 0, 1, false, "content", 0, 0, 0
	end
	return 0, 0, 0, 0, 0, 1, false, nil, 0, 0, 0
end

return Beats
