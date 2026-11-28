-- The v2 music (artifacts/qa-2026-11-28-music/MUSIC-BRIEF.md 3, 4 and 6; RACE-AND-MUSIC-LOOK 3.3). Pure parts and one
-- AmbientAudio instance with a fake BoardAudio:
--   switch   Alive "music2": the flag, beta and Studio only, never the live place; missing = on.
--   ids      every id 0 until uploaded; a pair plays v2 only with all its ids in (lite needs the deck).
--   weight   the night weight from GardenHour's own blend: 0 by day, up over 2880-3000 s, 1 at night, down over 0-90 s.
--   gains    equal power (day^2 + night^2 = 1), exact ends, the brief's 1.5 fallback exponent.
--   sync     wrapped drift, the one-grid rule (same length or a whole multiple), the follower's target, the louder
--            voice leading, the 40 ms limit, the seam, the runtime pair.
--   deck     the lite rule and its slew; the deck pair in AmbientAudio (nothing made while the ids are 0, both voices
--            from the top together, today's loop stopped, the cross to lite and back, the garden pair handed w and the hour).
-- Usage (Client): require(ZZSpecs.MusicTracks)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client, parent)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Alive = require(Shared.Alive)
	local Flags = require(Shared.FeatureFlags)
	local Hour = require(Shared.GardenHour)
	local Tracks = require(client.MusicTracks)
	local Ambient = require(client.AmbientAudio)
	local cases = {}
	local function test(name, run) run(); table.insert(cases, name) end
	local function near(a, b, e) return math.abs(a - b) <= (e or 1e-6) end

	test("switch: Alive music2 (beta and Studio only, never live); missing = on", function()
		assert(Tracks.Feature == "music2" and table.find(Alive.Features, "music2") and Flags.AliveMusic2 == true)
		assert(Alive.ceiling("music2", { AliveMusic2 = true }, 107705084891479, false))
		assert(Alive.ceiling("music2", { AliveMusic2 = true }, 96451847774961, true), "Studio")
		assert(not Alive.ceiling("music2", { AliveMusic2 = true }, 96451847774961, false), "never on the live place")
		assert(not Alive.ceiling("music2", {}, 107705084891479, true), "not without its flag")
		assert(Alive.resolve("music2", nil, nil, true) == true, "missing = on")
	end)

	test("ids: a pair needs every id (0 = not uploaded = today's music); lite needs the deck", function()
		for _, key in ipairs({ "garden_day", "garden_night", "deck", "deck_lite" }) do
			assert(type(Tracks.Ids[key]) == "number" and Tracks.Ids[key] >= 0, key .. " is an id or 0")
		end
		local none = Tracks.active(true, { garden_day = 0, garden_night = 0, deck = 0, deck_lite = 0 })
		assert(not none.garden and not none.deck and not none.lite, "ids 0: nothing")
		local half = Tracks.active(true, { garden_day = 1, garden_night = 0, deck = 0, deck_lite = 0 })
		assert(not half.garden, "garden needs both day and night")
		local all = { garden_day = 1, garden_night = 2, deck = 3, deck_lite = 4 }
		local off = Tracks.active(false, all)
		assert(not off.garden and not off.deck and not off.lite, "switch off: nothing")
		local on = Tracks.active(true, all)
		assert(on.garden and on.deck and on.lite)
		assert(not Tracks.active(true, { garden_day = 1, deck = 3 }).garden, "a day without its night is not a pair")
		local deckOnly = Tracks.active(true, { deck = 3 })
		assert(deckOnly.deck and not deckOnly.lite, "the deck without lite: the deck alone")
		assert(not Tracks.active(true, { deck_lite = 4 }).lite, "lite without the deck: nothing")
		for _, odd in ipairs({ -1, .5, 0 / 0, math.huge }) do
			assert(not Tracks.active(true, { deck = odd }).deck, "malformed id " .. tostring(odd))
		end
	end)

	test("weight: the Hour's own smoothstepped blend (night 120 s from 2880, dawn 90 s from 0), continuous", function()
		local function w(s) return Tracks.nightWeight(Hour.phase(s)) end
		for _, row in ipairs({ { 1000, 0 }, { 2400, 0 }, { 2879.9, 0 }, { 2880, 0 }, { 2940, .5 }, { 3000, 1 }, { 3300, 1 },
			{ 3599.9, 1 }, { 0, 1 }, { 45, .5 }, { 90, 0 }, { 200, 0 }, { 360, 0 } }) do
			assert(near(w(row[1]), row[2], 1e-3), "w at " .. row[1] .. " = " .. w(row[1]))
		end
		assert(near(w(2910), 3 * .25 ^ 2 - 2 * .25 ^ 3, 1e-6), "smoothstep, as the sky")
		local last = w(0)
		for s = .5, 3600, .5 do
			local now = w(s % 3600)
			assert(now >= 0 and now <= 1 and math.abs(now - last) < .02, "no jump at " .. s)
			last = now
		end
		assert(Tracks.nightWeight(nil) == 0 and Tracks.nightWeight({ phase = "golden", k = 1 }) == 0)
		assert(Tracks.nightWeight({ phase = "dawn", k = 1 }) == 0, "the dawn hold is day")
	end)

	test("gains: equal power with exact ends; the 1.5 fallback; the exponent and levels shipped", function()
		assert(select(1, Tracks.gains(0)) == 1 and select(2, Tracks.gains(0)) == 0)
		assert(select(1, Tracks.gains(1)) == 0 and select(2, Tracks.gains(1)) == 1)
		local lastDay, lastNight = 1, 0
		for i = 0, 100 do
			local day, night = Tracks.gains(i / 100, 1)
			assert(near(day * day + night * night, 1, 1e-9), "equal power at " .. i)
			assert(day <= lastDay + 1e-12 and night >= lastNight - 1e-12, "monotonic")
			lastDay, lastNight = day, night
		end
		local day, night = Tracks.gains(.5, 1.5)
		assert(near(day, math.sqrt(.5) ^ 1.5) and near(night, day), "the fallback's midpoint")
		assert(Tracks.gains(-1) == 1 and Tracks.gains(0 / 0) == 1, "malformed w is day")
		assert(Tracks.Exponent == 1 or Tracks.Exponent == 1.5, "the brief's two curves")
		assert(Tracks.NightLevel == 1 and Tracks.LiteLevel == 1, "the 3 LU are mastered into the files")
		assert(near(Tracks.Drift, .04) and Tracks.CheckEvery <= 2, "brief 3: 40 ms")
	end)

	test("sync: wrapped drift, one grid, the follower's target, the louder voice leads, the 40 ms limit, the seam", function()
		local G, D, L = Tracks.Lengths.garden, Tracks.Lengths.deck, Tracks.Lengths.deck_lite
		assert(near(G, 131.28, .01) and near(D, 121.90, .01) and near(L, 60.95, .01) and near(D, 2 * L, .001), "deck v5: 2:1")
		assert(near(Tracks.drift(10, 10.03, G), .03) and near(Tracks.drift(10.03, 10, G), -.03))
		assert(near(Tracks.drift(G - .01, .02, G), .03, 1e-9), "across the seam")
		assert(Tracks.ratio(G, G) == 1 and Tracks.ratio(D, L) == 2 and Tracks.ratio(L, D) == 2)
		assert(Tracks.ratio(G, G + .2) == nil and Tracks.ratio(65, 30) == nil, "not one grid")
		-- Same length: the same second. Shorter: modulo. Longer: the nearest of the leader's cycles.
		assert(near(Tracks.target(50, G, 49, G), 50))
		assert(near(Tracks.target(L + 10, D, 0, L), 10, 1e-9), "shorter: modulo")
		assert(near(Tracks.target(5, L, 5 + L + .08, D), 5 + L, 1e-9) and near(Tracks.target(5, L, 5.1, D), 5, 1e-9))
		assert(Tracks.target(5, 65, 5, 30) == nil)
		-- The louder voice leads; the follower moves only past the limit.
		assert(Tracks.align(50, 50.03, 1, 0, G, G) == nil, "30 ms is in step")
		local move, to = Tracks.align(50, 50.05, 1, .2, G, G)
		assert(move == "b" and near(to, 50), "day loud: night follows")
		move, to = Tracks.align(50, 50.05, .2, 1, G, G)
		assert(move == "a" and near(to, 50.05), "night loud: day follows")
		move = Tracks.align(50, 50.05, .7, .7, G, G)
		assert(move == "b", "a tie: the day voice leads")
		assert(Tracks.align(G - .01, .02, 1, 0, G, G) == nil, "30 ms across the seam is in step")
		move, to = Tracks.align(L + 10, .5, 1, 0, D, L)
		assert(move == "b" and near(to, 10, 1e-9), "lite follows the deck on its grid")
		assert(Tracks.align(5, 80, 1, 0, 65, 30) == nil, "lengths off the grid: never re-aligned")
	end)

	test("sync, runtime: only two playing, loaded voices; the quieter one is seeked", function()
		local function voice(at, playing) return { TimePosition = at, IsPlaying = playing, IsLoaded = true, TimeLength = Tracks.Lengths.garden } end
		local day, night = voice(20, true), voice(20.2, true)
		assert(Tracks.sync(day, night, .9, .1) == night and near(night.TimePosition, 20) and day.TimePosition == 20)
		day, night = voice(20, true), voice(20.2, true)
		assert(Tracks.sync(day, night, .1, .9) == day and near(day.TimePosition, 20.2))
		day, night = voice(20, true), voice(20.2, false)
		assert(Tracks.sync(day, night, 1, 0) == nil and night.TimePosition == 20.2, "a stopped voice is left alone")
		day, night = voice(20, true), voice(20.2, true);night.IsLoaded = false
		assert(Tracks.sync(day, night, 1, 0) == nil, "no length yet: nothing")
		day, night = voice(20, true), voice(20.01, true)
		assert(Tracks.sync(day, night, 1, 0) == nil and night.TimePosition == 20.01, "in step: no seek")
	end)

	test("deck lite: results, a finished round or a menu, only inside the deck; the slew crosses in DeckFade", function()
		assert(not Tracks.deckLite(nil) and not Tracks.deckLite({ open = false, results = true }))
		assert(not Tracks.deckLite({ open = true }), "playing: the deck track")
		assert(Tracks.deckLite({ open = true, results = true }) and Tracks.deckLite({ open = true, over = true })
			and Tracks.deckLite({ open = true, menu = true }))
		local w, steps = 0, 0
		while w < 1 do w = Tracks.slew(w, 1, 1 / 60, Tracks.DeckFade); steps += 1 end
		assert(math.abs(steps / 60 - Tracks.DeckFade) < .03, "end to end in DeckFade: " .. steps / 60)
		assert(Tracks.slew(.5, .5, 1, 1) == .5 and Tracks.slew(1, 0, 10, 1) == 0)
	end)

	test("AmbientAudio: ids 0 make nothing (today's deck loop); ids in: the deck pair, the cross, the garden handed w", function()
		local audio = { master = 1, deviceActive = true, ducks = {}, garden = {} }
		function audio:isMusicEnabled() return true end
		function audio:duck() end
		function audio:setGarden2(spec)
			table.insert(self.garden, spec or false)
			self.garden2 = if spec then { spec = spec } else nil
			return true
		end
		function audio:stepGarden2(dt, w, hour) self.last = { w = w, hour = hour } end
		local folder = Instance.new("Folder");folder.Parent = parent or workspace
		local on, lite, hour, weight = true, false, true, .25
		local ids, preload = table.clone(Tracks.Ids), Ambient.preload
		local shared = Ambient.shared
		local a = Ambient.new(audio, { auto = false, world = folder, quiet = function() return false end, listener = function() return Vector3.zero end,
			daylight = function() return 1 end, now = function() return 0 end,
			music2 = { on = function() return on end, hourOn = function() return hour end, weight = function() return weight end } })
		a.deckLite = function() return lite end
		-- the shipped ids may be real now (garden v4 uploaded): this case starts from all 0 and restores them after
		Tracks.Ids.garden_day, Tracks.Ids.garden_night, Tracks.Ids.deck, Tracks.Ids.deck_lite = 0, 0, 0, 0
		local ok, err = pcall(function()
			Ambient.preload = function(list, callback) for _, voice in ipairs(list) do callback(voice.SoundId, Enum.AssetFetchStatus.Success) end end
			a:setRound(true)
			for _ = 1, 60 do a:step(1 / 30) end
			assert(a.deck2 == nil and #audio.garden == 0, "ids 0: no v2 voice at all")
			if a.deckVoice then assert(a.deckVoice.IsPlaying, "today's deck loop plays") end
			Tracks.Ids.garden_day, Tracks.Ids.garden_night, Tracks.Ids.deck, Tracks.Ids.deck_lite = 11, 12, 13, 14
			a:step(1 / 30)
			assert(audio.garden[1] and audio.garden[1].day == 11 and audio.garden[1].night == 12, "the garden pair asked for")
			assert(audio.last and audio.last.w == .25 and audio.last.hour == true, "w and the hour read at once")
			hour = false;for _ = 1, 4 do a:step(1 / 30) end
			assert(audio.last.w == 0 and audio.last.hour == false, "the hour off: day only")
			local deck = assert(a.deck2, "the deck pair")
			assert(deck.ready and deck.main.SoundId == "rbxassetid://13" and deck.lite.SoundId == "rbxassetid://14")
			a:step(1 / 30)
			assert(deck.main.IsPlaying and deck.lite.IsPlaying, "both from the top together")
			if a.deckVoice then assert(not a.deckVoice.IsPlaying, "today's loop gave way") end
			assert(near(deck.main.Volume, Ambient.DeckMusicVolume * a.deckMix, 1e-6) and deck.lite.Volume == 0, "playing: the deck track")
			lite = true
			for _ = 1, math.ceil(Tracks.DeckFade * 30) + 2 do a:step(1 / 30) end
			assert(deck.w == 1 and deck.main.Volume == 0 and near(deck.lite.Volume, Ambient.DeckMusicVolume * a.deckMix, 1e-6), "results: lite")
			assert(deck.main.IsPlaying, "the deck track runs on under lite, in step")
			lite = false;for _ = 1, 3 do a:step(1 / 30) end
			local main, other = Tracks.gains(deck.w, 1)
			assert(deck.w > 0 and deck.w < 1 and near(main * main + other * other, 1, 1e-9), "back over the fade, equal power")
			a:setRound(false);for _ = 1, 60 do a:step(1 / 30) end
			assert(not deck.main.IsPlaying and not deck.lite.IsPlaying, "the round over: both stop")
			on = false;a:step(1 / 30)
			assert(a.deck2 == nil and audio.garden[#audio.garden] == false and audio.garden2 == nil, "switch off: today's music")
		end)
		Tracks.Ids.garden_day, Tracks.Ids.garden_night, Tracks.Ids.deck, Tracks.Ids.deck_lite = ids.garden_day, ids.garden_night, ids.deck, ids.deck_lite
		Ambient.preload = preload
		a:destroy();folder:Destroy();Ambient.shared = shared;assert(ok, err)
	end)

	return { passed = #cases, cases = cases }
end
