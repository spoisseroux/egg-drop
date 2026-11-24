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

	test("QA-R2 crickets: the bird and cricket curves, the slew, the breathing", function()
		for _, row in ipairs({ { 1, 1 }, { .40, 1 }, { .35, .5 }, { .30, 0 }, { .12, 0 } }) do
			assert(near(Ambient.birdGain(row[1]), row[2], .001), "birds at " .. row[1])
		end
		for _, row in ipairs({ { 1, 0 }, { .45, 0 }, { .325, .5 }, { .20, 1 }, { .12, 1 } }) do
			assert(near(Ambient.cricketGain(row[1]), row[2], .001), "crickets at " .. row[1])
		end
		-- The overlap: between .30 and .40 both are heard (the first birds over the last crickets).
		assert(Ambient.birdGain(.35) > 0 and Ambient.cricketGain(.35) > 0)
		-- A clock jump from day to night still takes 4 s at .25 a second.
		local g, t = 0, 0
		while g < 1 do g = Ambient.slew(g, 1, 1 / 30, Ambient.Crickets.slew); t += 1 / 30 end
		assert(near(t, 4, .05), "slew " .. t)
		assert(near(Ambient.breathe(23 / 4, 23), 1.25) and near(Ambient.breathe(0, 37), 1))
		local C = Ambient.Crickets
		assert(C.bed.id == 9112764558 and C.layer.id == 9112764023 and C.fallback == 9112762451)
		assert(C.bed.volume == .16 and C.layer.volume == .09 and C.lowGain == -18 and C.bed.speed == .97 and C.layer.speed == 1.03)
		for _, cue in pairs(Ambient.Ids) do assert(cue ~= C.bed.id and cue ~= C.layer.id, "never warmed") end
	end)

	test("QA-R2 crickets: the gate open, the night band schedules no bird and dusk chirps fade by birdGain", function()
		local perches = {}
		for i = 1, 10 do perches[i] = Vector3.new(i * 5, 12, 0) end
		for _, daylight in ipairs({ .12, .25 }) do
			local birds = Ambient.Birds.new(7)
			local now = 0
			for _ = 1, 4000 do now += .1; assert(#birds:step(now, Vector3.zero, daylight, perches, true, true) == 0, "a bird at night") end
		end
		local birds, now, heard = Ambient.Birds.new(7), 0, 0
		for _ = 1, 4000 do
			now += .1
			for _, e in ipairs(birds:step(now, Vector3.zero, .35, perches, true, true)) do
				heard += 1;assert(near(e.volume, Ambient.Bands.dusk.volume * .5, .001), "faded " .. e.volume)
			end
		end
		assert(heard >= 4, "dusk keeps its sparse chirps")
		assert(Ambient.Bands.dusk.volume == .50, "the band table itself is untouched")
	end)

	test("QA-R2 near crickets: the three nearest bushes within 40, 6 to 14 s apart, hushed within 6 and for 4 s after", function()
		local bushes = {}
		for i = 1, 8 do bushes[i] = Vector3.new(i * 8, 0, 0) end
		local near3 = Ambient.NearCrickets.new(3)
		local now, last, seen = 0, {}, {}
		for _ = 1, 30 * 120 do
			now += 1 / 30
			for _, e in ipairs(near3:step(now, Vector3.zero, bushes, 1)) do
				assert(e.bush <= 3 and e.slot >= 1 and e.slot <= 3 and e.position == bushes[e.bush], "a far bush " .. e.bush)
				assert(e.pitch >= .94 and e.pitch <= 1.08 and e.length >= 1 and e.length <= 2 and e.start >= 0 and e.start + e.length <= 36)
				assert(near(e.volume, .22))
				if last[e.bush] then local gap = now - last[e.bush];assert(gap >= 6 - .04 and gap <= 14 + .04, "gap " .. gap) end
				last[e.bush] = now;seen[e.bush] = true
			end
		end
		assert(seen[1] and seen[2] and seen[3], "all three sing")
		-- The listener stands at bush 1: it goes quiet, and stays quiet 4 s after they leave.
		local hush = Ambient.NearCrickets.new(5)
		local t, leftAt, after = 0, nil, nil
		for _ = 1, 30 * 60 do
			t += 1 / 30
			local at = if t < 30 then bushes[1] else Vector3.new(0, 0, 30)
			if t >= 30 and not leftAt then leftAt = t end
			for _, e in ipairs(hush:step(t, at, bushes, 1)) do
				if e.bush == 1 then assert(leftAt and t >= leftAt + 4 - .04, "bush 1 sang while hushed at " .. t);after = after or t end
			end
		end
		assert(after, "bush 1 sings again once the listener has gone")
		assert(#Ambient.NearCrickets.new(1):step(10, Vector3.zero, bushes, 0) == 0, "silent at gain 0")
		local far = Ambient.NearCrickets.new(1);for k = 1, 600 do assert(#far:step(k, Vector3.new(0, 0, 500), bushes, 1) == 0) end
	end)

	test("QA-R2 crickets in the mix: no voice made with the gate shut; open, the beds come up and duck; back to today's birds when shut", function()
		local audio = { master = 1, deviceActive = true, ducks = {} }
		function audio:isMusicEnabled() return true end
		function audio:duck() end
		local folder = Instance.new("Folder");folder.Parent = parent or workspace
		local gate, daylight, clock, gust = false, .12, 0, 0
		local shared = Ambient.shared
		local a = Ambient.new(audio, { auto = false, world = folder, wind = { on = function() return true end, gust = function() return gust end },
			listener = function() return Vector3.zero end, daylight = function() return daylight end, now = function() return clock end,
			night = function() return gate end, bushes = { Vector3.new(10, 0, 0), Vector3.new(20, 0, 0) } })
		local ok, err = pcall(function()
			for _ = 1, 300 do clock += 1 / 30; a:step(1 / 30) end
			assert(a.cricketBed == nil and a.crickets == 0, "gate shut: no cricket voice at all")
			gate = true
			for _ = 1, 60 do clock += 1 / 30; a:step(1 / 30) end
			assert(a.cricketBed and near(a.crickets, .5, .02), "eases in: " .. a.crickets)
			for _ = 1, 120 do clock += 1 / 30; a:step(1 / 30) end
			assert(a.crickets == 1 and a.cricketBed.IsPlaying and a.cricketLayer.IsPlaying, "full at night")
			assert(a.cricketBed.Volume <= .16 * 1.25 + 1e-6 and a.cricketBed.Volume >= .16 * .75 - 1e-6, "bed " .. a.cricketBed.Volume)
			local calm = a.cricketBed.Volume
			gust = 1;a:step(0);assert(near(a.cricketBed.Volume, calm * .8, .002), "a full gust ducks 20%")
			gust = 0
			a:setRound(true);a:step(1 / 30);assert(not a.cricketBed.IsPlaying, "a round stops them")
			a:setRound(false);for _ = 1, 40 do clock += 1 / 30; a:step(1 / 30) end
			assert(a.cricketBed.IsPlaying, "and they come back")
			local made = a.cricketBed
			gate = false
			for _ = 1, 150 do clock += 1 / 30; a:step(1 / 30) end
			assert(a.crickets == 0 and not a.cricketBed.IsPlaying, "shut: eased out and stopped")
			gate = true;for _ = 1, 30 do clock += 1 / 30; a:step(1 / 30) end
			assert(a.cricketBed == made, "the voices are made once and reused")
			for _, entry in ipairs(a.cricketPool) do assert(entry.voice.PlaybackRegionsEnabled == true, "trills on their own voices") end
			for _, entry in ipairs(a.birdPool) do assert(entry.voice.PlaybackRegionsEnabled ~= true, "a bird voice never cuts trills") end
		end)
		a:destroy();folder:Destroy();Ambient.shared = shared;assert(ok, err)
	end)

	test("bird gaps stay inside each daylight band and night uses only the hoo-hoo (the cricket gate shut: today)", function()
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

	test("LOOK-R3 3: an added voice falls back once when its asset fails to load, never when it loads or is gone; starts at its share", function()
		local audio = { master = 1, deviceActive = true, ducks = {}, music = true }
		function audio:isMusicEnabled() return self.music end
		function audio:duck() end
		function audio:petSpeechBusy() return false end
		local folder = Instance.new("Folder");folder.Parent = parent or workspace
		local a = Ambient.new(audio, { auto = false, world = folder, listener = function() return Vector3.new(0, 6, 0) end, daylight = function() return 1 end, now = function() return 0 end })
		local preload, length, wait = Ambient.preload, Ambient.length, Ambient.wait
		local slept = 0
		Ambient.wait = function(seconds) slept += seconds;return seconds end
		local ok, err = pcall(function()
			local host = Instance.new("Part");host.Parent = folder
			local spec = { id = 111, speed = 1, volume = .14, min = 5, max = 26, parent = host, start = .5, fallback = { id = 222, speed = 1.25, volume = .16 } }
			local function added()
				for _, entry in ipairs(a.falls) do if entry.voice.Parent == host then return entry end end
			end
			-- Lengths by id: 111 is 32 s, 222 is 20 s; anything else (or a failed load) holds nothing.
			local held = {}
			Ambient.length = function(voice) return held[voice.SoundId] end
			Ambient.preload = function(list, callback) callback(list[1].SoundId, "Failure") end
			held = { ["rbxassetid://222"] = 20 }
			local remove = a:addVoice("fountain", spec)
			local entry = added()
			assert(entry and entry.fellBack == true, "no fallback on a failed load")
			assert(entry.voice.SoundId == "rbxassetid://222" and entry.voice.PlaybackSpeed == 1.25 and entry.spec.volume == .16, "fallback id/speed/volume " .. entry.voice.SoundId)
			assert(math.abs(entry.spec.offset - 9.8) < 1e-6, "fallback starts at its share: " .. entry.spec.offset)
			remove()
			assert(added() == nil, "remover left the voice")
			-- Success that never loaded (a clip the place may not use): falls back too, after the load grace.
			Ambient.preload = function(list, callback) callback(list[1].SoundId, Enum.AssetFetchStatus.Success) end
			held = {};slept = 0
			remove = a:addVoice("fountain", spec)
			assert(added().fellBack == true, "an empty Success kept the silent clip")
			assert(slept >= Ambient.LoadGrace and slept < Ambient.LoadGrace + .5, "waited the grace: " .. slept)
			remove()
			-- Success whose IsLoaded lags: it loads during the grace and keeps the new clip.
			local polls = 0
			Ambient.length = function(voice)
				polls += 1
				return if polls >= 3 and voice.SoundId == "rbxassetid://111" then 32 else nil
			end
			remove = a:addVoice("fountain", spec)
			entry = added()
			assert(entry.fellBack == nil and entry.voice.SoundId == "rbxassetid://111", "a lagging load fell back")
			remove()
			Ambient.length = function(voice) return held[voice.SoundId] end
			held = { ["rbxassetid://111"] = 32 }
			remove = a:addVoice("fountain", spec)
			entry = added()
			assert(entry.fellBack == nil and entry.voice.SoundId == "rbxassetid://111" and entry.voice.PlaybackSpeed == 1, "fell back on a good load")
			assert(math.abs(entry.spec.offset - 15.68) < 1e-6, "start share of 32 s: " .. entry.spec.offset)
			remove()
			-- A load still in flight when the fountain goes (PreloadAsync yields): the late failure must not touch it.
			local later
			Ambient.preload = function(list, callback)
				local thread = coroutine.running()
				later = function() callback(list[1].SoundId, "Failure");coroutine.resume(thread) end
				coroutine.yield()
			end
			remove = a:addVoice("fountain", spec)
			entry = added()
			remove()
			later()
			assert(entry.fellBack == nil and entry.voice.SoundId == "rbxassetid://111", "a removed voice switched")
			Ambient.preload = function() error("offline") end
			remove = a:addVoice("fountain", spec)
			assert(added().fellBack == true, "a preload that throws counts as failed")
			remove()
			remove = a:addVoice("fountain", { id = 111, parent = host })
			entry = added()
			assert(entry.fellBack == nil and entry.spec.offset == 0, "no fallback or start given: nothing to do")
			remove()
		end)
		Ambient.preload, Ambient.length, Ambient.wait = preload, length, wait
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
