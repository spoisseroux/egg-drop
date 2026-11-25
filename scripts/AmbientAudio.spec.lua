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
		local a = Ambient.new(audio, { auto = false, world = folder, quiet = function() return false end, wind = { on = function() return true end, gust = function() return gust end },
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
		local a = Ambient.new(audio, { auto = false, world = folder, quiet = function() return false end, listener = function() return listener end, daylight = function() return 1 end, now = function() return 0 end })
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

	test("placeholder race song (Spencer 2026-11-25): lead-in from 3 s before GO, the 3..35 loop, the line, the card, off; the world music held out and back; music toggle and focus", function()
		local R = Ambient.Race
		-- Where in the file: the lead-in once, then 3..35 round and round.
		assert(near(Ambient.racePosition(-3), 0) and near(Ambient.racePosition(0), 3) and near(Ambient.racePosition(31.5), 34.5))
		assert(near(Ambient.racePosition(32), 3) and near(Ambient.racePosition(40), 11) and near(Ambient.racePosition(64 + 1), 4))
		assert(R.lead == 3 and R.loopEnd == 35 and R.line == .35 and R.lineFade == .4 and R.cardFade == .15 and R.back == 1.0)
		assert(Ambient.RaceSongId == 100659120200214 and R.volume == Ambient.DeckMusicVolume)
		local refreshed = 0
		local audio = { master = 1, deviceActive = true, ducks = {}, music = true }
		function audio:isMusicEnabled() return self.music end
		function audio:duck() end
		function audio:refreshLoops() refreshed += 1 end
		function audio:petSpeechBusy() return false end
		local folder = Instance.new("Folder");folder.Parent = parent or workspace
		local clock = 100
		local a = Ambient.new(audio, { auto = false, world = folder, quiet = function() return false end, listener = function() return Vector3.zero end, daylight = function() return 1 end, now = function() return clock end })
		local function run(seconds) for _ = 1, math.floor(seconds * 30 + .5) do clock += 1 / 30; a:step(1 / 30) end end
		local ok, err = pcall(function()
			assert(a.raceVoice == nil and not a:setRace("line") and not a:setRace("off"), "no voice and nothing to do until a race asks")
			run(1);assert(audio.ducks[Ambient.RaceDuck] == nil and refreshed == 0, "nothing per frame without a race")
			-- Locked 6 s before GO: silent, the world music still up, until the lead-in.
			assert(a:setRace("play", clock + 6))
			local voice = a.raceVoice
			assert(voice and voice.Looped and voice.SoundGroup == a.deckGroup and voice.SoundId == "rbxassetid://" .. Ambient.RaceSongId)
			assert(a.raceLoop == "region" and voice.PlaybackRegionsEnabled == true and voice.LoopRegion ~= nil, "LoopRegion 3..35")
			run(2);assert(not voice.IsPlaying and audio.ducks[Ambient.RaceDuck] == nil, "before the lead-in")
			run(.8);assert(audio.ducks[Ambient.RaceDuck] ~= nil and audio.ducks[Ambient.RaceDuck] < 1, "the world music fades out just before the lead-in")
			run(.4);assert(voice.IsPlaying, "the lead-in at 3 s to GO");assert(voice.TimePosition < .4, "from the top " .. tostring(voice.TimePosition))
			assert(audio.ducks[Ambient.RaceDuck] == 0, "the world held out " .. tostring(audio.ducks[Ambient.RaceDuck]))
			run(.2);assert(near(voice.Volume, R.volume), "full " .. voice.Volume)
			-- Re-timed by a small lead change: no jump; by a big one: one jump.
			local go = a.race.go
			a:setRace("play", go + .02);assert(a.race.go == go and not a.race.seek)
			a:setRace("play", go - .5);assert(a.race.seek);run(1 / 30);assert(not a.race.seek and voice.IsPlaying)
			-- The music toggle stops it; on again it comes back where the race is.
			audio.music = false;run(.1);assert(not voice.IsPlaying)
			audio.music = true;run(1 / 30);assert(voice.IsPlaying and near(voice.TimePosition, Ambient.racePosition(clock - a.race.go), .05))
			audio.deviceActive = false;run(.1);assert(not voice.IsPlaying, "unfocused");audio.deviceActive = true;run(1 / 30);assert(voice.IsPlaying)
			-- Over the line: .35 in .4 s, still playing; the deck group still follows the master volume.
			assert(a:setRace("line"));run(.2);assert(voice.Volume < R.volume and voice.Volume > R.volume * R.line)
			run(.3);assert(near(voice.Volume, R.volume * R.line) and voice.IsPlaying)
			assert(not a:setRace("play", a.race.go), "never back up once over the line")
			assert(near(a.deckGroup.Volume, 1), "the race duck holds out the world music only")
			-- The card: out in .15 s; the world music stays held out under the card.
			assert(a:setRace("card"));run(.2);assert(voice.Volume == 0 and not voice.IsPlaying and audio.ducks[Ambient.RaceDuck] == 0)
			-- Off: the world music back over 1 s, then the duck gone.
			assert(a:setRace("off"));run(.5);assert(a.race == nil and audio.ducks[Ambient.RaceDuck] > .3 and audio.ducks[Ambient.RaceDuck] < .7, "half way back")
			run(.6);assert(audio.ducks[Ambient.RaceDuck] == nil and a.raceWorld == 1)
			local before = refreshed;run(1);assert(refreshed == before, "nothing per frame once back")
			-- Left mid-race: out in .4 s from full.
			a:setRace("play", clock + .5);run(1);assert(voice.IsPlaying)
			a:setRace("off");run(.2);assert(voice.Volume > 0);run(.3);assert(not voice.IsPlaying and a.race == nil)
			-- Muted: never plays.
			audio.master = 0;a:setRace("play", clock);run(.5);assert(not voice.IsPlaying);a:setRace("off");run(1.5)
		end)
		a:destroy();folder:Destroy();assert(ok, err)
		assert(audio.ducks[Ambient.RaceDuck] == nil, "destroy lets the world music go")
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

	test("LOOK-R4 Q4: the quiet water mix follows its switch: bed silent away from the stream, falls tighter; off is today's", function()
		local audio = { master = 1, deviceActive = true, ducks = {}, music = true }
		function audio:isMusicEnabled() return self.music end
		function audio:duck() end
		function audio:petSpeechBusy() return false end
		local folder = Instance.new("Folder");folder.Parent = parent or workspace
		local quiet = true
		local listener = Vector3.new(96, 4, 66) -- the arrival dais: far from the stream
		local a = Ambient.new(audio, { auto = false, world = folder, quiet = function() return quiet end,
			listener = function() return listener end, daylight = function() return 1 end, now = function() return 0 end })
		local ok, err = pcall(function()
			assert(Ambient.bedGain(0 / 0) == Ambient.BedFloor and Ambient.bedGain(0 / 0, Ambient.Quiet.bed) == Ambient.Quiet.bed.floor)
			assert(Ambient.bedGain(0, Ambient.Quiet.bed) == Ambient.Quiet.bed.peak and Ambient.bedGain(Ambient.Quiet.bed.range, Ambient.Quiet.bed) == Ambient.Quiet.bed.floor)
			-- Eased out over .6 s, then paused after 2 s at silence.
			assert(#a.falls == 2, "both falls have voices")
			for _ = 1, 180 do a:step(1 / 30) end
			assert(Ambient.bedGain(Ambient.Quiet.bed.full, Ambient.Quiet.bed) == Ambient.Quiet.bed.peak, "full within `full` studs")
			assert(a.quietOn == true and a.bed < .002 and not a.bedVoice.IsPlaying, "quiet: the bed is silent away from water " .. a.bed)
			for _, fall in ipairs(a.falls) do
				local over = Ambient.Quiet.falls[fall.name]
				assert(fall.voice.RollOffMaxDistance == over.max and fall.voice.RollOffMinDistance == over.min and near(fall.voice.Volume, over.volume, 1e-4), fall.name)
			end
			listener = Vector3.new(2.5, 7, 21) -- on the bridge, over the stream
			for _ = 1, 60 do a:step(1 / 30) end
			assert(a.bed > Ambient.Quiet.bed.peak * .9 and a.bedVoice.IsPlaying, "quiet: the bed still plays at the stream " .. a.bed)
			quiet = false
			listener = Vector3.new(96, 4, 66)
			for _ = 1, 60 do a:step(1 / 30) end
			assert(a.quietOn == false and a.bed > Ambient.BedFloor * .95 and a.bedVoice.IsPlaying, "off: today's bed floor " .. a.bed)
			for _, fall in ipairs(a.falls) do
				assert(fall.spec == Ambient.Falls[fall.name] and fall.voice.RollOffMaxDistance == fall.spec.max
					and fall.voice.RollOffMinDistance == fall.spec.min and near(fall.voice.Volume, fall.spec.volume, 1e-4), fall.name)
			end
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
			local a = Ambient.new(audio, { auto = false, world = folder, quiet = function() return false end, seed = 5, perches = perches, wind = false,
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

	test("beta 17 1.3 D: the wind bed never restarts per gust: always playing from a random point, volume and speed follow the blow", function()
		assert(near(Ambient.windBedVolume(0), .012, 1e-9) and near(Ambient.windBedVolume(1), .082, 1e-9) and near(Ambient.windBedVolume(.5), .0295, 1e-9))
		assert(near(Ambient.windBedSpeed(0), .92, 1e-9) and near(Ambient.windBedSpeed(1), 1.02, 1e-9) and Ambient.windBedVolume(0 / 0) == .012)
		assert(near(Ambient.windBedSlew(0, 1, 1), .12, 1e-9) and near(Ambient.windBedSlew(1, 0, 1), .95, 1e-9))
		local audio = { master = 1, deviceActive = true, ducks = {} }
		function audio:isMusicEnabled() return true end
		function audio:duck() end
		local folder = Instance.new("Folder");folder.Parent = parent or workspace
		local on, blow, hushed = false, 0, false
		local shared = Ambient.shared
		local a = Ambient.new(audio, { auto = false, world = folder, quiet = function() return false end, wind = false, echo = false,
			windBed = { on = function() return on end, blow = function() return blow end, hushed = function() return hushed end },
			listener = function() return Vector3.zero end, daylight = function() return 1 end, now = function() return 0 end })
		local ok, err = pcall(function()
			a:step(1 / 30)
			assert(a.windBedVoice == nil, "off (the switch's default): no voice at all")
			on = true
			a:step(1 / 30)
			local voice = a.windBedVoice
			assert(voice and voice.Looped and voice:FindFirstChildOfClass("EqualizerSoundEffect").HighGain == -6)
			voice.IsLoaded, voice.TimeLength = true, 14
			a:step(1 / 30)
			assert(voice.IsPlaying and voice.TimePosition >= 0 and voice.TimePosition < 14, "plays from a random point")
			-- It only ever starts from stopped, so playing through every step is never a restart.
			local at = voice.TimePosition
			for k = 1, 600 do
				blow = if (math.floor(k / 60) % 2) == 0 then 1 else 0
				a:step(1 / 30)
				assert(voice.IsPlaying, "gusts never stop or restart it")
			end
			assert(voice.TimePosition == at or voice.TimePosition > at, "never sent back")
			assert(voice.Volume >= .012 - 1e-9 and voice.Volume <= .082 + 1e-9)
			blow = 1;for _ = 1, 30 * 4 do a:step(1 / 30) end
			assert(near(voice.Volume, .082, 1e-6) and near(voice.PlaybackSpeed, 1.02, 1e-9), "full: " .. voice.Volume)
			blow = 0;for _ = 1, 4 do a:step(.25) end;assert(near(voice.Volume, .082 - .05, 1e-6), "down .05 a second")
			a:setRound(true);a:step(1 / 30);assert(not voice.IsPlaying, "a round stops it")
			a:setRound(false);a:step(1 / 30);assert(voice.IsPlaying, "back after")
			hushed = true;a:step(1 / 30);assert(not voice.IsPlaying, "the Hush stops it")
			hushed = false;on = false;a:step(1 / 30);assert(not voice.IsPlaying, "the switch off stops it")
		end)
		a:destroy();folder:Destroy();Ambient.shared = shared;assert(ok, err)
	end)

	test("beta 17 1.3 D: the Den's echo: a reverb on the ambience and SFX groups (never music), wet -14 inside, eased over .6 s, gone outside", function()
		local E = Ambient.Echo
		assert(near(Ambient.echoToward(-60, true, .3), -37, 1e-9) and near(Ambient.echoToward(-60, true, 1), -14, 1e-9))
		assert(near(Ambient.echoToward(-14, false, 1), -60, 1e-9))
		local audio = { master = 1, deviceActive = true, ducks = {} }
		function audio:isMusicEnabled() return true end
		function audio:duck() end
		local folder = Instance.new("Folder");folder.Parent = parent or workspace
		local on, inside = true, false
		local shared = Ambient.shared
		local a = Ambient.new(audio, { auto = false, world = folder, quiet = function() return false end, wind = false, windBed = false,
			echo = { on = function() return on end, camera = function() return Vector3.new(1, 2, 3) end, inside = function() return inside end },
			listener = function() return Vector3.zero end, daylight = function() return 1 end, now = function() return 0 end })
		local ok, err = pcall(function()
			for _ = 1, 30 do a:step(1 / 30) end
			assert(a.echoEffects == nil, "outside: no effect")
			inside = true
			for _ = 1, 9 do a:step(1 / 30) end
			assert(a.echoEffects and #a.echoEffects >= 2, "on the ambience and cue groups")
			for _, reverb in ipairs(a.echoEffects) do
				assert(reverb.Parent ~= a.deckGroup and reverb.Parent.Name ~= "EggDropMusic", "never the music")
				assert(reverb.DecayTime == E.decay and reverb.Density == E.density and reverb.Diffusion == E.diffusion and reverb.DryLevel == 0)
			end
			for _ = 1, 30 do a:step(1 / 30) end
			assert(near(a.echoWet, -14, 1e-6) and near(a.echoEffects[1].WetLevel, -14, .06), "wet " .. a.echoWet)
			inside = false
			for _ = 1, 30 do a:step(1 / 30) end
			assert(a.echoEffects == nil, "eased out and removed")
			inside = true;on = false
			for _ = 1, 30 do a:step(1 / 30) end
			assert(a.echoEffects == nil, "the switch off: none")
		end)
		a:destroy();folder:Destroy();Ambient.shared = shared;assert(ok, err)
	end)

	test("WORLD-FINISH-LOOK slice F: the hill's sound zones: den, path, terrace eased over .6 s; music by its own duck, never timed, never the ambience's", function()
		local Night = require(game.ReplicatedStorage.Shared.HillNight)
		local refreshed = 0
		local audio = { master = 1, deviceActive = true, ducks = {} }
		function audio:isMusicEnabled() return true end
		function audio:duck() error("the zones never use the timed duck") end
		function audio:refreshLoops() refreshed += 1 end
		local folder = Instance.new("Folder");folder.Parent = parent or workspace
		local on, place, h = true, "home", 0
		local shared = Ambient.shared
		local a = Ambient.new(audio, { auto = false, world = folder, quiet = function() return false end, wind = false, windBed = false, echo = false,
			zones = { on = function() return on end, camera = function() return Vector3.new(1, 2, 3) end, zone = function() return place, h end },
			listener = function() return Vector3.zero end, daylight = function() return 1 end, now = function() return 0 end })
		local ok, err = pcall(function()
			local function run(seconds) for _ = 1, math.floor(seconds * 30 + .5) do a:step(1 / 30) end end
			run(1)
			assert(a.zoneGains and near(a.zoneGains.water, 1, 1e-6) and a.zoneGains.room == 0 and audio.ducks[Ambient.ZoneDuck] == nil, "home: today's mix")
			local bedHome = a.bedVoice.Volume
			place = "den"
			run(.4)
			assert(a.zoneGains.water < 1 and a.zoneGains.water > Night.gain(-12), "on its way (sampled at 4 Hz, eased over .6 s)")
			run(.6)
			assert(near(a.zoneGains.water, Night.gain(-12), 1e-6) and near(a.zoneGains.birds, Night.gain(-12), 1e-6), "den: water and birds -12 dB")
			assert(near(audio.ducks[Ambient.ZoneDuck], .5, .01) and refreshed > 0, "den: the world music at 50%")
			assert(near(a.bedVoice.Volume, a.bed * Night.gain(-12), 1e-6) and bedHome > 0, "the bed follows")
			-- The ambience group is never ducked by the zone (master() leaves the zone's duck out).
			local master, _, duck = a:master()
			assert(master == 1 and duck == 1, "the ambience is not ducked by the music's zone duck")
			place, h = "path", .5
			run(1)
			assert(near(a.zoneGains.wind, Night.gain(2), 1e-6) and near(a.zoneGains.water, Night.gain(-3), 1e-6), "half way up: +2 / -3 dB")
			assert(audio.ducks[Ambient.ZoneDuck] == nil, "out of the den: the music's duck gone")
			place = "terrace"
			run(1)
			assert(near(a.zoneGains.wind, Night.gain(4), 1e-6) and near(a.zoneGains.water, Night.gain(-9), 1e-6) and near(a.zoneGains.birds, 1, 1e-6))
			-- The gate off: eased back home, then dropped (no gains, no duck).
			place = "den";run(1);on = false;run(1)
			assert(a.zoneGains == nil and audio.ducks[Ambient.ZoneDuck] == nil, "off: dropped")
			-- The room tone (uploaded 106077128620977): off, no room voice is left playing.
			assert(type(Ambient.RoomToneId) == "number" and a.roomVoice == nil, "off: no room voice")
		end)
		a:destroy();folder:Destroy();Ambient.shared = shared;assert(ok, err)
		-- A fixture that passes no zones and auto = false never reads the camera.
		local b = Ambient.new({ master = 1, deviceActive = true, ducks = {}, isMusicEnabled = function() return true end },
			{ auto = false, world = parent or workspace, wind = false, windBed = false, echo = false, quiet = function() return false end,
				listener = function() return Vector3.zero end, daylight = function() return 1 end, now = function() return 0 end })
		assert(b.zonesOf == nil, "fixtures: no zones")
		b:destroy();Ambient.shared = shared
	end)

	return { passed = #cases, cases = cases }
end
