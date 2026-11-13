-- W2 pet life (FEEL-ALIVE-DIRECTION-2026-11-13 B): idle weights, the sit, faces,
-- coo cadence and requests, look-at-owner and the two-bounce walk. Pure tables
-- plus native-recipe fixture pets in workspace; no remotes, no saves.
return function(client, parent)
	local Beats = require(client.PetIdleBeats);local Sit = require(client.PetSitPose)
	local Expression = require(client.PetExpression);local Look = require(client.PetLookAt)
	local Coos = require(client.PetCooScheduler);local Follow = require(client.PetFollow)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end

	test("idle beat weights follow the day and night tables and never repeat", function()
		for _, case in ipairs({ { 1, Beats.DayWeights }, { .1, Beats.NightWeights } }) do
			local r = Random.new(5);local counts, total, previous = {}, 0, nil
			for _ = 1, 20000 do
				local kind = Beats.pick(r, case[1], previous, true)
				assert(kind ~= previous, "same beat twice running");previous = kind
				counts[kind] = (counts[kind] or 0) + 1;total += 1
			end
			-- Ranks follow the weights (the no-repeat rule flattens shares a little).
			local weights = case[2]
			local top, topWeight = nil, 0
			for kind, w in pairs(weights) do if w > topWeight then top, topWeight = kind, w end end
			for kind in pairs(weights) do assert(counts[top] >= counts[kind], top .. " is not the most common beat") end
			assert(counts.sneeze / total < .08, "sneeze too common")
		end
		local r = Random.new(1)
		for _ = 1, 2000 do assert(Beats.pick(r, 1, nil, false) ~= "wave", "waved with nobody near") end
	end)

	test("beats start after 5 s idle, at least 7 s apart, with a sit that lasts 6.65 to 14.65 s", function()
		local v = { petId = "pip", cosmeticSeed = 11 };local t, starts, running, sits = 0, {}, false, 0
		for _ = 1, 300 * 30 do
			t += 1 / 30
			local kind = Beats.step(v, 1 / 30, true, true, true, 1)
			if kind and not running then
				table.insert(starts, t)
				if kind == "sit" then
					sits += 1
					local d = v.idleBeat.duration
					assert(d >= Beats.SitIn + Beats.SitHoldMin + Beats.SitOut - 1e-6 and d <= Beats.SitIn + Beats.SitHoldMax + Beats.SitOut + 1e-6, "sit length " .. d)
				end
			end
			running = kind ~= nil
		end
		assert(starts[1] > 5 and starts[1] <= 7.1, "first beat at " .. starts[1])
		for i = 2, #starts do assert(starts[i] - starts[i - 1] >= 7, "beats too close") end
		assert(#starts >= 15 and sits >= 1, "too few beats " .. #starts)
	end)

	test("the sit beat envelope eases in 0.35 s and out 0.3 s; landing asks for a coo half the time", function()
		local s = { kind = "sit", age = .175, duration = 10 }
		assert(math.abs(Beats.sitWeight(s) - .5) < 1e-6)
		s.age = 5;assert(Beats.sitWeight(s) == 1);s.age = 9.85;assert(math.abs(Beats.sitWeight(s) - .5) < 1e-6)
		local asked = 0
		for seed = 1, 400 do
			local v = { idleBeat = { random = Random.new(seed) } };Beats.requestCoo(v, v.idleBeat, "sit")
			if v.pendingCoo then assert(v.pendingCoo == "pet_coo_3");asked += 1 end
		end
		assert(asked > 150 and asked < 250, "sit coo chance " .. asked / 400)
	end)

	test("sits come from settle, nookRest, 4 s+ rests and an owner still within 8 studs for 6 s", function()
		assert(Sit.fromActivity("settle") and Sit.fromActivity("nookRest") and Sit.fromActivity(nil, "rest", 4))
		assert(not Sit.fromActivity(nil, "rest", 3.9) and not Sit.fromActivity("wanderPause", "follow", 10))
		assert(Sit.fromOwner(6, 0) and not Sit.fromOwner(5.9, 0) and not Sit.fromOwner(8, .5))
		local v = {};local w
		for _ = 1, 10 do w = Sit.step(v, .035, true, 0) end
		assert(w == 1 and v.sitLanded, "no landing at 0.35 s")
		for _ = 1, 9 do w = Sit.step(v, 1 / 30, false, 0) end
		assert(w < .01, "sit did not get up in 0.3 s")
		local r = { reducedEffects = true };assert(Sit.step(r, 0, true, 0) == 1 and r.boopAt == nil, "reduced sit is not instant or squashes")
		assert(Sit.face(5) == nil and Sit.face(20.5) == "dozy" and Sit.face(30) == "sleepy")
	end)

	test("rest faces: content under 20 s, then dozy, then sleepy; night and deck play doze sooner", function()
		assert(Expression.garden("sleepy", true, 1.5, 1) == "content", "a short pause is sleepy")
		assert(Expression.garden("sleepy", true, 21, 1) == "dozy" and Expression.garden("sleepy", true, 40, 1) == "sleepy")
		assert(Expression.garden("sleepy", true, 1, .1) == "dozy" and Expression.garden("sleepy", true, 5, .1) == "sleepy")
		assert(Expression.garden("sleepy", true, 5, 1, true) == "sleepy")
		assert(Expression.garden("neutral", false, 50, 1) == "neutral" and Expression.garden("curious", false) == "curious")
		for _, name in ipairs({ "content", "joy", "dozy" }) do assert(Expression.poses[name], name .. " face missing") end
		assert(Expression.name({ joyUntil = 3, time = 1 }) == "joy" and Expression.name({ joyUntil = 3, time = 4, expression = "neutral" }) == "neutral")
	end)

	test("coos wait 14-28 s by day and 40-70 s at night", function()
		local s = Coos.new({})
		for _ = 1, 500 do
			local d, n = s.wait(1), s.wait(.1)
			assert(d >= 14 and d <= 28 and n >= 40 and n <= 70)
		end
	end)

	local function fixture(withVoice)
		local function speaker()
			local a = { group = { Volume = 1 }, deviceActive = true, plays = {}, stops = 0 }
			function a:play(cue, pitch, gain, token) table.insert(self.plays, { cue = cue, pitch = pitch, gain = gain }); return true end
			function a:stopOwner() self.stops += 1 end
			function a:petSpeechBusy() return false end
			function a:has(cue) return withVoice and string.find(cue, "pet_coo") ~= nil end
			return a
		end
		local audio, voice = speaker(), speaker()
		local s = Coos.new(audio, { voice = voice, wait = function() return 20 end })
		local c = { enabled = true, listener = Vector3.zero, identity = {}, daylight = 1 }
		local function pet(id, x) return { petId = id, worldContext = true, model = { Parent = true }, origin = Vector3.new(x or 0, 0, 0), expression = "neutral", greeting = 2, lastGeneration = 1 } end
		return s, audio, voice, c, pet
	end

	test("scheduled coos are audible (0.30) and voiced by mood at one pitch per family", function()
		local s, audio, voice, c, pet = fixture(true)
		local owner = pet("puddle");owner.expression = "content"
		s:step(0, c, owner, {});s:step(20, c, owner, {})
		assert(#voice.plays == 1 and #audio.plays == 0, "coo not on the ambient voice")
		local p = voice.plays[1];assert(p.cue == "pet_coo_2" and p.pitch == .92 and math.abs(p.gain - .30) < 1e-9, p.cue .. " " .. p.pitch .. " " .. p.gain)
		s:destroy()
		local s2, audio2, _, c2, pet2 = fixture(false);local o2 = pet2("pip")
		s2:step(0, c2, o2, {});s2:step(20, c2, o2, {})
		assert(#audio2.plays == 1 and audio2.plays[1].cue == "pet" and audio2.plays[1].pitch == .85, "no BoardAudio fallback")
		s2:destroy()
	end)

	test("requested coos respect 6 s per pet and 2.5 s between any two, and expire after 1.5 s", function()
		local s, _, voice, c, pet = fixture(true)
		local owner, other = pet("pip"), pet("wick", 4);local visitors = { { visual = other } }
		owner.expression = "joy";owner.pendingCoo = "pet_coo_2"
		s:step(0, c, owner, visitors);assert(#voice.plays == 1 and voice.plays[1].cue == "pet_coo_2" and voice.plays[1].pitch == 1)
		s:step(1, c, owner, visitors) -- coo finished
		other.pendingCoo = "pet_coo_1";s:step(1.5, c, owner, visitors);assert(#voice.plays == 1, "two coos inside 2.5 s")
		s:step(2.6, c, owner, visitors);assert(#voice.plays == 2 and voice.plays[2].pitch == 1.12, "visitor request lost")
		s:step(3.5, c, owner, visitors)
		owner.pendingCoo = "pet_coo_1";s:step(5.5, c, owner, visitors);s:step(5.9, c, owner, visitors)
		assert(#voice.plays == 2 and owner.pendingCoo, "owner spoke again inside 6 s")
		s:step(7.2, c, owner, visitors);assert(owner.pendingCoo == nil and #voice.plays == 2, "stale request was not dropped")
		s:destroy()
	end)

	test("look-at-owner turns toward a nearby owner who stops, up to 35 degrees, then relaxes after 3 s", function()
		local v = { origin = Vector3.zero, yaw = 0, time = 0, cosmeticSeed = 2, ownerPosition = Vector3.new(10, 0, 3), ownerMoving = true }
		local yaw
		for _ = 1, 60 do v.time += 1 / 30;yaw = Look.step(v, 1 / 30, true) end
		assert(yaw > math.rad(30) and yaw <= Look.Max + 1e-6, "no turn " .. math.deg(yaw))
		for _ = 1, 150 do v.time += 1 / 30;yaw = Look.step(v, 1 / 30, true) end
		assert(math.abs(yaw) < math.rad(2), "never relaxed")
		v.ownerMoving = false;for _ = 1, 30 do v.time += 1 / 30;yaw = Look.step(v, 1 / 30, true) end
		assert(yaw > math.rad(20), "stopping did not draw a look")
		local far = { origin = Vector3.zero, yaw = 0, time = 0, ownerPosition = Vector3.new(20, 0, 0), ownerMoving = true }
		assert(Look.step(far, 1, true) == 0 and Look.step({ origin = Vector3.zero, yaw = 0, time = 0, ownerPosition = Vector3.new(3, 0, 0), reducedEffects = true }, 1, true) == 0)
	end)

	test("the walk bounces twice per stride and stride grows with speed", function()
		local peaks, last, rising = 0, 0, false
		for i = 0, 200 do
			local v = { gaitPhase = i / 200 * math.pi * 2, gaitWeight = 1, petId = "pip", travelSpeed = 4 }
			local b = Follow.bob(v, false)
			if b < last and rising then peaks += 1 end
			rising = b > last;last = b
			assert(b >= 0 and b <= Follow.Bob + 1e-9)
		end
		assert(peaks == 2, "bounces per stride " .. peaks)
		assert(Follow.bob({ gaitPhase = math.pi / 2, gaitWeight = 1, petId = "pip", travelSpeed = 8 }, false) > Follow.Bob * 1.4, "no scamper")
		assert(Follow.bob({ gaitPhase = 1, gaitWeight = 1 }, true) == 0)
		assert(Follow.stride(3, 1) == 1.5 and Follow.stride(9, 1) == 3.2 and Follow.stride(20, .5) == 1.6)
		for _, speed in ipairs({ 3, 4, 9 }) do
			local cadence = math.min(speed / Follow.stride(speed, .72), Follow.CadenceCap)
			assert(cadence >= 2 and cadence <= 3, "cadence " .. cadence .. " at " .. speed)
		end
	end)

	test("a real Bear sits (body down, feet forward and released), looks at its owner and allocates nothing", function()
		local Factory = require(client.PetFactory);local Pets = require(game.ReplicatedStorage.Shared.PetCatalog)
		local folder = Instance.new("Folder");folder.Name = "_PetLifeTuning";folder.Parent = parent or workspace
		local v = Factory.new(folder, Vector3.new(2300, 4.025, 0), Pets.byId.pip, .72, nil, { native = true })
		local ok, err = pcall(function()
			local function piece(name) for _, p in ipairs(v.pieces) do if p.name == name then return p end end;error(name) end
			v.reducedEffects = false;v.greeting = 2;v.cosmeticSeed = 4;v.poseDirty = true;v:update(0)
			local body, foot, head = piece("Body").part.Position, piece("FootL").part.CFrame, piece("Head").part.CFrame
			local count = #v.model:GetDescendants()
			v.activitySit = true
			for _ = 1, 40 do v.poseDirty = true;v:update(1 / 30) end
			assert(v.sitWeight == 1, "no sit")
			assert(piece("Body").part.Position.Y < body.Y - .1, "body did not lower")
			assert(piece("FootL").part.Position.Z > foot.Position.Z + .05, "feet not forward")
			-- Pets face +Z, so the part LookVector (-Z) points at the heel: toes up tips it down.
			assert(piece("FootL").part.CFrame.LookVector.Y < -.2, "soles not up")
			v.ownerPosition = Vector3.new(2306, 4, 2);v.ownerMoving = false
			for _ = 1, 40 do v.poseDirty = true;v:update(1 / 30) end
			assert((piece("Head").part.CFrame.LookVector - head.LookVector).Magnitude > .2, "head never turned to the owner")
			assert(#v.model:GetDescendants() == count, "sit/look allocated instances")
			v.activitySit = false;v.ownerPosition = nil
			for _ = 1, 60 do v.poseDirty = true;v:update(1 / 30) end
			assert(v.sitWeight == 0 and math.abs(piece("Body").part.Position.Y - body.Y) < .02, "did not stand back up")
		end)
		v:destroy();folder:Destroy();assert(ok, err)
	end)

	return { passed = #cases, cases = cases }
end
