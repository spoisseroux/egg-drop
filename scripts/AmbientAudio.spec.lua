-- W2 feel alive: brook bed gain vs distance, deck-round mute, bird scheduler bounds.
-- Pure checks plus one AmbientAudio instance with a fake BoardAudio (no Heartbeat,
-- no listener of its own). No remotes, no saves.
return function(client, parent)
	local Ambient = require(client.AmbientAudio)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function near(a, b, eps) return math.abs(a - b) <= (eps or .005) end

	test("bed gain follows the A3 table and never goes silent", function()
		-- The A3 curve's shape (share of the floor-to-peak swing); the levels came down 2026-11-21
		-- ("wind too loud": floor .12, peak .24).
		assert(near(Ambient.BedFloor, .12) and near(Ambient.BedPeak, .24))
		local swing = Ambient.BedPeak - Ambient.BedFloor
		for _, row in ipairs({ { 0, 1 }, { 10, .89 }, { 20, .56 }, { 30, .28 }, { 45, 0 }, { 200, 0 } }) do
			local want = Ambient.BedFloor + swing * row[2]
			assert(near(Ambient.bedGain(row[1]), want, .011), "bed at " .. row[1] .. " = " .. Ambient.bedGain(row[1]))
		end
		local last = math.huge
		for d = 0, 60, 2 do local g = Ambient.bedGain(d); assert(g <= last + 1e-9 and g >= Ambient.BedFloor); last = g end
		assert(Ambient.bedGain(0 / 0) == Ambient.BedFloor)
	end)

	test("stream distance tests segments, not just points, and subtracts the half width", function()
		local stream = { { 0, 3, 0, 4 }, { 20, 3, 0, 4 } }
		assert(near(Ambient.streamDistance(Vector3.new(10, 9, 10), stream), 8), "mid-segment")
		assert(near(Ambient.streamDistance(Vector3.new(10, 0, 1), stream), 0), "on the bank")
		assert(near(Ambient.streamDistance(Vector3.new(-6, 0, 0), stream), 4), "past the end")
		local World = require(game.ReplicatedStorage.Shared.WorldV7Data)
		local onBridge = Ambient.streamDistance(Vector3.new(2.5, 7, 21), World.beams.stream)
		assert(onBridge < 2 and Ambient.bedGain(onBridge) > Ambient.BedPeak - .01, "bridge is on the stream")
		assert(Ambient.bedGain(Ambient.streamDistance(Vector3.new(96, 4, 66), World.beams.stream)) < Ambient.BedFloor + .03, "arrival dais is far")
	end)

	test("QA v775: each waterfall is silent from the spawn lawn and at its own max", function()
		local World = require(game.ReplicatedStorage.Shared.WorldV7Data)
		local seen = 0
		for _, beam in ipairs(World.beams.falls) do
			local spec = Ambient.Falls[beam.name]
			if spec then
				seen += 1
				local at = beam[spec.anchor]
				local lawn = (Vector3.new(at[1], at[2] + spec.lift, at[3]) - Vector3.new(0, 6, 0)).Magnitude
				-- v834: halved and tightened again (Spencer: still too loud).
				assert(spec.min <= 6 and spec.max <= 44, beam.name .. " carries too far: " .. spec.min .. " / " .. spec.max)
				assert(spec.max < lawn - 15, beam.name .. " is heard from the lawn (" .. math.floor(lawn) .. " studs, max " .. spec.max .. ")")
				assert(spec.volume <= .3, beam.name .. " volume")
			end
		end
		assert(seen == 2, "both falls have emitters")
	end)

	test("round mix fades out over 0.6 s and back over 1.0 s", function()
		local mix = 1
		for _ = 1, 18 do mix = Ambient.mixToward(mix, true, 1 / 30) end
		assert(near(mix, 0, 1e-6), "not out after 0.6 s")
		for _ = 1, 15 do mix = Ambient.mixToward(mix, false, 1 / 30) end
		assert(near(mix, .5, .02), "half way back after 0.5 s")
		for _ = 1, 30 do mix = Ambient.mixToward(mix, false, 1 / 30) end
		assert(mix == 1)
	end)

	test("bird gaps stay inside each daylight band and night uses only the hoo-hoo", function()
		local perches = {}
		for i = 1, 10 do perches[i] = Vector3.new(i * 5, 12, 0) end
		for _, case in ipairs({ { 1, 6, 14 }, { .45, 12, 24 }, { .1, 25, 50 } }) do
			local birds = Ambient.Birds.new(7)
			local now, firsts = 0, {}
			birds:step(now, Vector3.zero, case[1], perches, true)
			local scheduled = birds.nextAt
			assert(scheduled - now >= case[2] and scheduled - now <= case[3], "first gap")
			for _ = 1, 4000 do
				now += .1
				local before = birds.nextAt
				for _, e in ipairs(birds:step(now, Vector3.zero, case[1], perches, true)) do
					table.insert(firsts, e)
					if case[1] < .3 then assert(e.cue == "bird_chirp_6" and e.volume == .35, "night cue " .. e.cue) end
					if case[1] >= .3 and case[1] <= .6 then assert(e.cue == "bird_chirp_3" or e.cue == "bird_chirp_6", "dusk cue " .. e.cue) end
					assert(e.pitch >= .92 and e.pitch <= 1.12 and e.position == perches[e.perch])
				end
				if birds.nextAt ~= before then
					local gap = birds.nextAt - before
					assert(gap >= case[2] - .11 and gap <= case[3] + .11, "gap " .. gap)
				end
			end
			assert(#firsts >= 4, "too few chirps " .. #firsts)
		end
	end)

	test("birds pick among the 6 nearest perches within 70 studs and never the same tree twice running", function()
		local perches = {}
		for i = 1, 12 do perches[i] = Vector3.new(i * 8, 12, 0) end
		local birds = Ambient.Birds.new(3)
		local now, seen, picks, previous = 0, {}, 0, nil
		for _ = 1, 20000 do
			now += .1
			for _, e in ipairs(birds:step(now, Vector3.zero, 1, perches, true)) do
				seen[e.perch] = true
				assert((perches[e.perch] - Vector3.zero).Magnitude <= 70, "perch out of reach")
			end
			if birds.last ~= previous then picks += 1;previous = birds.last end
		end
		assert(picks > 50, "too few picks")
		for index in pairs(seen) do assert(index <= 7, "picked beyond the 6 nearest (+1 reply/avoid): " .. index) end
		-- Repeated picks: the scheduler's own `last` guard.
		local b = Ambient.Birds.new(9);local previous
		for _ = 1, 200 do
			local index = b:choose(Vector3.zero, perches, previous)
			assert(index ~= previous, "same tree twice");previous = index
		end
	end)

	test("an inactive scheduler (deck round) cancels pending chirps and queues nothing", function()
		local perches = { Vector3.new(5, 12, 0), Vector3.new(10, 12, 0) }
		local birds = Ambient.Birds.new(1)
		birds:step(0, Vector3.zero, 1, perches, true)
		assert(#birds:step(500, Vector3.zero, 1, perches, false) == 0 and birds.nextAt == nil and #birds.pending == 0)
		local events = birds:step(501, Vector3.zero, 1, perches, true)
		assert(#events == 0 and birds.nextAt and birds.nextAt >= 507, "a round left a burst behind")
	end)

	test("a deck round mutes every ambient layer, cues and birds; leaving brings them back", function()
		local ducks = {}
		local audio = { master = 1, deviceActive = true, ducks = {}, music = true }
		function audio:isMusicEnabled() return self.music end
		function audio:duck(name, duration, gain) table.insert(ducks, { name, duration, gain }) end
		function audio:petSpeechBusy() return false end
		local folder = Instance.new("Folder");folder.Parent = parent or workspace
		local listener = Vector3.new(2.5, 7, 21)
		local a = Ambient.new(audio, { auto = false, world = folder, listener = function() return listener end, daylight = function() return 1 end, now = function() return 0 end })
		local ok, err = pcall(function()
			a:setRound(false);for _ = 1, 30 do a:step(1 / 30) end
			assert(a.ambience.Volume > .99 and a.group.Volume == 1, "garden not audible")
			assert(a.bed > Ambient.BedFloor + (Ambient.BedPeak - Ambient.BedFloor) * .5, "bridge bed too quiet " .. a.bed)
			a:setRound(true)
			for _ = 1, 30 do a:step(1 / 30) end
			assert(a.ambience.Volume == 0 and a.mix == 0, "ambience still up in the round")
			assert(not a.bedVoice.IsPlaying, "bed loop kept running")
			for _, fall in ipairs(a.falls) do assert(not fall.voice.IsPlaying, "falls kept running") end
			assert(not a:play("pet_coo_1", 1, .3, {}), "a coo spoke during the round")
			assert(a.deckMix > .99 or Ambient.Ids.deck_music == nil, "deck music did not come up " .. a.deckMix)
			if a.deckVoice then assert(ducks[#ducks][1] == Ambient.DeckDuck and ducks[#ducks][3] == 0, "world music not ducked") end
			audio.music = false;for _ = 1, 30 do a:step(1 / 30) end
			assert(a.deckMix == 0, "music toggle ignored by deck music")
			a:setRound(false);for _ = 1, 40 do a:step(1 / 30) end
			assert(a.mix == 1 and a.ambience.Volume > .99, "garden did not come back")
			if a.deckVoice then assert(ducks[#ducks][3] == 1, "world music never released") end
			audio.deviceActive = false;a:step(1 / 30)
			assert(a.ambience.Volume == 0 and a.group.Volume == 0, "unfocused window still audible")
		end)
		a:destroy();folder:Destroy();assert(ok, err)
	end)

	test("garden life's onChirp: called once per chirp that played, with its perch; nil or a throwing hook changes nothing; a throw warns once", function()
		local perches = {}
		for i = 1, 8 do perches[i] = Vector3.new(i * 6, 12, 0) end
		local shared = Ambient.shared -- the game's own, put back after each run
		local function run(hook)
			local audio = { master = 1, deviceActive = true, ducks = {} }
			function audio:isMusicEnabled() return true end
			function audio:duck() end
			local folder = Instance.new("Folder");folder.Parent = parent or workspace
			local clock = 0
			local warned = {}
			local a = Ambient.new(audio, { auto = false, world = folder, seed = 5, perches = perches, wind = false,
				listener = function() return Vector3.zero end, daylight = function() return 1 end, now = function() return clock end,
				warn = function(text) table.insert(warned, text) end })
			local played, calls = {}, {}
			local chirp = a.chirp
			a.chirp = function(self, event)
				local ok = chirp(self, event)
				if ok then table.insert(played, event.perch .. " " .. event.cue) end
				return ok
			end
			if hook == "throw" then
				a.onChirp = function(perch) table.insert(calls, perch); error("hook broke") end
			elseif hook then
				a.onChirp = function(perch, position, cue)
					assert(position == perches[perch] and type(cue) == "string")
					table.insert(calls, perch)
				end
			end
			local ok, err = pcall(function()
				for _ = 1, 30 * 240 do
					clock += 1 / 30
					a:step(1 / 30)
					-- Free the three voices again, so later chirps can play (a chirp is short).
					if #played % 2 == 0 then for _, entry in ipairs(a.birdPool) do entry.voice:Stop() end end
				end
			end)
			local hookAfter = a.onChirp
			a:destroy();folder:Destroy();Ambient.shared = shared;assert(ok, err)
			return played, calls, hookAfter, warned
		end
		local plain, _, _, quiet = run(nil)
		local played, calls, kept, fine = run(true)
		assert(#quiet == 0 and #fine == 0, "no warning without a throw")
		assert(#played >= 6, "chirps played " .. #played)
		assert(#calls == #played, "one call per played chirp: " .. #calls .. " / " .. #played)
		assert(table.concat(plain, ",") == table.concat(played, ","), "the hook changes no chirp")
		assert(type(kept) == "function")
		local broke, thrown, after, warned = run("throw")
		assert(#thrown == 1 and after == nil, "a hook that throws is dropped")
		assert(#warned == 1 and string.find(warned[1], "[Life] chirp hook: ", 1, true) == 1 and string.find(warned[1], "hook broke", 1, true),
			"said once: " .. tostring(warned[1]))
		assert(table.concat(broke, ",") == table.concat(plain, ","), "and the birds sound the same")
	end)

	return { passed = #cases, cases = cases }
end
