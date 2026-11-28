-- Garden ambience and Pocket Deck round music (FEEL-ALIVE-DIRECTION-2026-11-13 A).
-- A 2D brook bed that swells near the stream, two positional waterfall loops,
-- pooled bird chirps from the tree canopies and the deck's own round music. All
-- world ambience is OFF during a Pocket Deck round (Spencer, 2026-11-13); the
-- deck music plays only then and the world music is ducked out under it.
-- It also voices the pet coos and the station attract ping (pet_coo_1..3,
-- machine_attract) so they follow the master Sound setting like any SFX.
-- One owner: the client entry creates it next to BoardAudio and tells it when a
-- round starts and ends (setRound). No server traffic, no saves.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Wind = require(script.Parent.Wind)
local MusicTracks = require(script.Parent.MusicTracks)

local Ambient = {}
Ambient.__index = Ambient

-- PLACEHOLDER sounds (assets/audio/placeholder/, uploaded 2026-11-13). Spencer's own
-- audio replaces these; see PLACEHOLDER-AUDIO.md and AUDIO-HANDOFF.md. A cue without
-- an id stays silent (deck_music: until the coordinator uploads it, the world music
-- simply keeps playing through rounds).
Ambient.Ids = {
	water_bed_loop = 71747963121003, waterfall_loop = 110993560996896,
	bird_chirp_1 = 137226970817959, bird_chirp_2 = 71904536727966, bird_chirp_3 = 89108953015660,
	bird_chirp_4 = 139852680764636, bird_chirp_5 = 107104950878309, bird_chirp_6 = 85365315991550,
	pet_coo_1 = 133263306024551, pet_coo_2 = 95664039612347, pet_coo_3 = 136397644383191,
	machine_attract = 75991665557379,
	-- Spencer's original Pocket Deck loop (assets/audio/music/pocket-deck-loop.wav, 2026-11-16).
	deck_music = 107339572876342,
}
-- Alive step 4: leaves in the gust (assets/audio/custom/egg_drop_wind_rustle.wav, 14 s loop). Not in
-- Ids and never in `warm`: the voice is made the first time the wind is on, and nil means no voice.
-- OFF since beta (12) QA S1 (Spencer 2026-11-23): restarting the loop on every gust read as an intermittent
-- "toilet flush". The id was 131058187750745; the code path stays, so a replacement is one id here.
Ambient.RustleId = nil
-- Volume at a full gust, the most it may change per second (over a gust's own .19, so a clock jump
-- never clicks), and how long it stays silent before the loop stops.
Ambient.RustlePeak, Ambient.RustleSlew, Ambient.RustleHold = .10, .4, 1.5
-- Beta 17 (WORLD-ALIVE-LOOK 1.3 D), behind its own Alive switch `windbed` (missing = OFF, for Spencer to hear first): one
-- wind loop that plays all the time from mount at a random offset and never restarts per gust (the "toilet flush" was
-- the old rustle's restart). Volume floor + gain x blow^2 (blow: the gust or the big breath at the camera), slewed up
-- .12 a second and down .05; PlaybackSpeed .92 + .10 x blow; an equalizer's HighGain -6 so it is air, not hiss. It
-- stops only in a deck round or the Hush. The id is the old rustle's, a placeholder.
Ambient.WindBedId = 131058187750745
Ambient.WindBed = table.freeze({ floor = .012, gain = .07, up = .12, down = .05, speed = .92, speedGain = .10, highGain = -6 })
-- The Den's echo (1.3 D, the `scene` switch): a ReverbSoundEffect on the ambience and SFX groups (never the music),
-- its WetLevel eased from Off to Wet over Ease seconds while the camera is inside the Play Den (DenLayout).
Ambient.Echo = table.freeze({ decay = 1.6, density = .8, diffusion = .8, dry = 0, wet = -14, off = -60, ease = .6, sample = .25,
	groups = { "EggDropAmbience", "EggDropAmbientCues", "EggDropSFX" } })
-- The hill's sound zones (WORLD-FINISH-LOOK section 5, slice F; HillNight holds the numbers): by the camera, eased over
-- .6 s, the water (bed and falls), the birds and the wind bed scaled, the world music held to 50% in the den by its own
-- duck (ZoneDuck, written straight into BoardAudio's ducks as the race song's is, never timed, gone at full), and the
-- den's room tone (RoomToneId: 0 until the coordinator uploads assets/audio/custom/egg_drop_den_room_tone.wav, silent
-- until then). The `scene` switch and the island's sculpt gate it (live: the ceiling is closed, nothing runs).
Ambient.ZoneDuck = "hillZone"
Ambient.RoomToneId = 106077128620977
Ambient.RoomToneVolume = .08
function Ambient.windBedVolume(blow)
	if type(blow) ~= "number" or blow ~= blow then blow = 0 end
	blow = math.clamp(blow, 0, 1)
	return Ambient.WindBed.floor + Ambient.WindBed.gain * blow * blow
end
function Ambient.windBedSpeed(blow)
	if type(blow) ~= "number" or blow ~= blow then blow = 0 end
	return Ambient.WindBed.speed + Ambient.WindBed.speedGain * math.clamp(blow, 0, 1)
end
-- The bed's volume one step on: toward `goal`, never faster than up / down a second.
function Ambient.windBedSlew(level, goal, dt)
	local W = Ambient.WindBed
	return level + math.clamp(goal - level, -W.down * dt, W.up * dt)
end
-- The echo's WetLevel one step on (dB, linear: Off to Wet in Ease seconds).
function Ambient.echoToward(wet, inside, dt)
	local E = Ambient.Echo
	local goal = if inside then E.wet else E.off
	local most = (E.wet - E.off) / E.ease * dt
	return wet + math.clamp(goal - wet, -most, most)
end
Ambient.OneShots = { "pet_coo_1", "pet_coo_2", "pet_coo_3", "machine_attract" }

-- A3 brook bed: bed = floor + (peak - floor) * smoothstep(1 - d / 45), sampled at 4 Hz, eased 0.5 s.
-- Spencer 2026-11-21 (beta, phone): "The wind sound is too loud". The always-on brook hiss is
-- what reads as wind: .22 / .40 -> .12 / .24 (about -5 dB).
Ambient.BedFloor, Ambient.BedPeak, Ambient.BedRange = .12, .24, 45
Ambient.BedSample, Ambient.BedEase = .25, .5
-- A6: round fade out 0.6 s, back over 1.0 s. Deck music voice volume (world music is
-- BoardAudio.MusicVolume, 0.07). Was .2 for the v3 texture; Spencer's loop is hotter.
Ambient.RoundOut, Ambient.RoundIn = .6, 1.0
-- v890 QA (2026-11-17): "turn down the game drop music a bit": .15 -> .105 (about -3 dB).
Ambient.DeckMusicVolume = .105
Ambient.DeckDuck = "deckRound"
-- Garden Dash race song "Hop to It" (RACE-AND-MUSIC-LOOK 2.1; Spencer 2026-11-25 "put a placeholder for race music"). A
-- PLACEHOLDER: original synthesis (scripts/synth_race_music.py, assets/audio/custom/egg_drop_race_song.wav), uploaded
-- 2026-11-25, not heard by Spencer yet. One file, 120 bpm: a 3 s lead-in (the 3, 2, 1 on beats 1, 3, 5) and a 32 s loop
-- from 3 to 35 s. Only DashClient (behind the Dash ceiling: the beta place and Studio) calls setRace, and the voice is
-- made on that first call, so the live game never has it. It sits in the deck music's group (master, focus, the other
-- ducks) and follows the music toggle; the world music is held out by its own duck from the lead-in until the race is
-- put away, and comes back over `back` seconds.
--   volume  the voice at full (DeckMusicVolume's level: both tracks are -19 LUFS)
--   line    its share once the pet is over the line (it keeps playing while the others finish), reached in lineFade s
--   inFade  the lead-in's fade up; out: the world music's fade out before the lead-in; back: the world music's return
Ambient.RaceSongId = 100659120200214
Ambient.Race = table.freeze({ lead = 3, loopEnd = 35, volume = .105, line = .35, lineFade = .4, cardFade = .15, leaveFade = .4,
	inFade = .05, out = .4, back = 1.0, resync = .05 })
Ambient.RaceDuck = "dashRace"
-- Beta 44 note 25 ("use the new pocket deck song for the garden dash too, only for those participating"): with Alive
-- music2 on and MusicTracks.Ids.deck uploaded, the race plays the Pocket Deck song instead of the placeholder: the
-- whole clip (121.9 s) looped, from 0 at the lead-in (Race.lead s before GO), at DeckMusicVolume. The same states,
-- fades and world-music hold as the placeholder; it is still only DashClient's own race. Off, id 0, or a clip that
-- will not load (said once; the race carries on with the placeholder where it has reached): today's placeholder.
-- Pure: {kind = "deck" | "placeholder", id, volume}.
function Ambient.raceSong(on, ids, failed)
	ids = ids or MusicTracks.Ids
	if on == true and not failed and MusicTracks.uploaded(ids.deck) then
		return { kind = "deck", id = ids.deck, volume = Ambient.DeckMusicVolume }
	end
	return { kind = "placeholder", id = Ambient.RaceSongId, volume = Ambient.Race.volume }
end
-- Where in the deck song a moment `elapsed` s after GO falls: 0 at the lead-in, then round the whole clip. Pure.
function Ambient.deckRacePosition(elapsed, length)
	length = if type(length) == "number" and length > 0 then length else MusicTracks.Lengths.deck
	return math.max(0, Ambient.Race.lead + elapsed) % length
end
-- A4 waterfall emitters. Positions come from WorldV7Data.beams.falls by name.
Ambient.Falls = {
	-- QA v775 note 6: the falls carried across the whole garden (tumble min 18 / max 150 was
	-- still a sixth of full volume at the spawn lawn, 110 studs off). InverseTapered now halves
	-- by 2x min and is silent at max, so each fall is heard only on its own bank.
	-- v834 phone notes: still too loud. Volume halved (.60 / .42 -> .30 / .21) and the
	-- rolloff tightened about a third (min 9 / 6 -> 6 / 4, max 64 / 42 -> 44 / 30).
	-- 2026-11-21 ("wind too loud"): .30 / .21 -> .22 / .15 (about -3 dB).
	W7_Water__waterfall_tumble = { anchor = "bottom", lift = 5.8, volume = .22, min = 6, max = 44, speed = .92, offset = 0 },
	W7_Water__waterfall_sky = { anchor = "top", lift = -.75, volume = .15, min = 4, max = 30, speed = 1.08, offset = 3.7 },
}
-- LOOK-R4 Q4 (Spencer, beta 14: "the constant water ambience is too loud and annoying"): the beta's quieter water
-- mix, only while the Aero look is on (Aero.on(): the beta place or Studio, and the /aero switch); live and /aero off
-- keep the numbers above. bed: the brook bed's floor, peak and range; falls: each fall's volume and rolloff.
-- LOOK-R4 (Fable): the bed is full within `full` studs of the stream, smoothstep to silent at `range`, eased over `ease` s,
-- and paused after `pause` s at 0.
-- Beta 35 (Spencer 2026-11-26: "the waterfall barely makes any sound"): with the camera 15 to 25 studs off and one
-- point at .18 / min 6 / max 38, a player at Tumble's pool heard it at about -30 dB. Now each fall is several emitters
-- spread down the water (Ambient.fallPoint: `at` 0 top .. 1 foot, `out` studs toward the island's middle, `lift`), heard
-- from the player's head (AudioListener) and loudest at the pool. Each emitter its own speed and start, so the copies
-- of one loop never comb. Every emitter is silent at the spawn lawn (spec'd with Ambient.rolloff).
Ambient.Quiet = table.freeze({
	bed = table.freeze({ floor = 0, peak = .10, full = 6, range = 28, ease = .6, pause = 2 }),
	falls = table.freeze({
		W7_Water__waterfall_tumble = table.freeze({
			table.freeze({ at = 1, out = 8, lift = 2.5, volume = .40, min = 10, max = 72, speed = .94, offset = 0 }), -- the pool
			table.freeze({ at = .6, out = 0, lift = 1, volume = .24, min = 7, max = 50, speed = 1.0, offset = 4.1 }), -- the ledge
			table.freeze({ at = .06, out = -3, lift = 0, volume = .14, min = 5, max = 36, speed = 1.07, offset = 7.3 }), -- the lip
		}),
		W7_Water__waterfall_sky = table.freeze({
			table.freeze({ at = 0, out = 0, lift = -.75, volume = .30, min = 8, max = 52, speed = 1.06, offset = 3.7 }), -- the lip
			table.freeze({ at = .3, out = 0, lift = 0, volume = .26, min = 12, max = 64, speed = .96, offset = 8.2 }), -- the drop
		}),
	}),
})
-- PLACEHOLDER water loops (beta 35, 2026-11-26). Original synthesis: scripts/synth_water.py writes both files (no
-- samples, no AI audio; report in artifacts/water-audio-2026-11-26/). Spencer uploads the .ogg and puts its asset id in
-- `id`. While an id is 0 the stand-in plays: the best library water we already have, through an EqualizerSoundEffect
-- that takes the crackly highs out (gains in dB; `from`..`to` is the mid band, Hz). Once an id is filled the stand-in
-- stays as the fallback if the new asset will not load. The new files are mastered to the waterfall stand-in's loudness
-- (-26.2 LUFS), so `volume` is 1 for them and the game's volumes keep their meaning; the brook bed is 4 dB quieter (1.6).
Ambient.WaterLoops = table.freeze({
	-- Fountain trickle, 10 s loop: assets/audio/custom/egg_drop_fountain_trickle.ogg
	fountain = table.freeze({ id = 93904545634789 --[[ egg_drop_fountain_trickle (uploaded 2026-11-26) ]], speed = 1, volume = 1,
		standIn = table.freeze({ id = 71747963121003 --[[ water_bed_loop ]], speed = 1, volume = 1.6,
			eq = table.freeze({ low = 1, mid = -2, high = -16, from = 300, to = 2400 }) }) }),
	-- Waterfall roar, 12 s loop: assets/audio/custom/egg_drop_waterfall_roar.ogg
	waterfall = table.freeze({ id = 115042771381451 --[[ egg_drop_waterfall_roar (uploaded 2026-11-26) ]], speed = 1, volume = 1,
		standIn = table.freeze({ id = 110993560996896 --[[ waterfall_loop ]], speed = 1, volume = 1,
			eq = table.freeze({ low = 3, mid = -1, high = -10, from = 400, to = 3000 }) }) }),
})
-- Which clip a water voice plays: the new loop once its id is in (the stand-in as its fallback), else the stand-in with
-- its EQ. failed: the new loop would not load. Returns {id, speed, volume, eq, fallback} or nil for an unknown kind.
function Ambient.waterSource(kind, failed)
	local loop = Ambient.WaterLoops[kind]
	if not loop then return nil end
	local stand = loop.standIn
	local standIn = { id = stand.id, speed = stand.speed or 1, volume = stand.volume or 1, eq = stand.eq }
	if type(loop.id) == "number" and loop.id > 0 and loop.id ~= stand.id and failed ~= true then
		return { id = loop.id, speed = loop.speed or 1, volume = loop.volume or 1, eq = loop.eq, fallback = standIn }
	end
	return standIn
end
-- Pure, for specs: Roblox's InverseTapered rolloff as its docs describe it (Inverse near the min distance, LinearSquare
-- near the max), taken as the lower of the two. Full volume within `min`, silent from `max`.
function Ambient.rolloff(distance, min, max)
	if type(distance) ~= "number" or distance ~= distance then return 0 end
	if distance <= min then return 1 end
	if distance >= max then return 0 end
	local inverse = min / distance
	local square = (1 - (distance - min) / (max - min)) ^ 2
	return math.min(inverse, square)
end
-- A fall emitter's point. beam: WorldV7Data.beams.falls row {top, bottom}; e: {at, out, lift}.
function Ambient.fallPoint(beam, e)
	local top, bottom = beam.top, beam.bottom
	local s = math.clamp(e.at or 0, 0, 1)
	local x = top[1] + (bottom[1] - top[1]) * s
	local y = top[2] + (bottom[2] - top[2]) * s + (e.lift or 0)
	local z = top[3] + (bottom[3] - top[3]) * s
	local out = e.out or 0
	local across = math.sqrt(x * x + z * z)
	if out ~= 0 and across > 1e-6 then x, z = x - x / across * out, z - z / across * out end
	return Vector3.new(x, y, z)
end
-- A5 birds.
Ambient.BirdVoices, Ambient.BirdReach, Ambient.BirdChoices = 3, 70, 6
Ambient.BirdMin, Ambient.BirdMax = 12, 85
Ambient.Bands = {
	day = { min = 6, max = 14, cues = { 1, 2, 3, 4, 5 }, phrase = .25, reply = .15, volume = .50 },
	dusk = { min = 12, max = 24, cues = { 3, 6 }, phrase = .10, reply = 0, volume = .50 },
	night = { min = 25, max = 50, cues = { 6 }, phrase = 0, reply = 0, volume = .35 },
}

local function smoothstep(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Crickets at night (QA-R2-LOOK 2, Spencer R2.3). Only while the garden hour runs AND Alive life is on (Ambient.new's
-- `night`); otherwise everything here is skipped and the birds are exactly as before. Not in Ids and never in `warm`:
-- the voices are made the first time the night gate is open, then reused across toggles, and stopped only when silent.
-- Ids are Roblox library recordings (Pro Sound Effects), picked by Fable from their descriptions; Spencer's ears decide.
Ambient.Crickets = {
	bed = { id = 9112764558, volume = .16, speed = .97, breathe = 23 },   -- Crickets Night 2, 36 s loop
	layer = { id = 9112764023, volume = .09, speed = 1.03, breathe = 37 }, -- Crickets Canyon 2, 46.2 s loop
	fallback = 9112762451,                                                -- Crickets And Cicadas 1 (at .10, if A + B are thin)
	breath = .25, slew = .25, from = .45, span = .25, lowGain = -18, gust = .20,
	near = { voices = 3, reach = 40, gapMin = 6, gapMax = 14, pitchMin = .94, pitchMax = 1.08, volume = .22, min = 6, max = 40,
		hush = 6, hold = 4, lengthMin = 1, lengthMax = 2, source = 36 },
}
-- Birds full while daylight >= .40, nothing at .30 (with the night gate open).
function Ambient.birdGain(daylight)
	if type(daylight) ~= "number" or daylight ~= daylight then return 1 end
	return smoothstep((daylight - .30) / .10)
end
-- Crickets silent at daylight >= .45, full at <= .20.
function Ambient.cricketGain(daylight)
	if type(daylight) ~= "number" or daylight ~= daylight then return 0 end
	local C = Ambient.Crickets
	return smoothstep((C.from - daylight) / C.span)
end
-- `value` toward `goal`, at most `rate` a second.
function Ambient.slew(value, goal, dt, rate)
	local most = rate * dt
	return value + math.clamp(goal - value, -most, most)
end
-- One layer's slow breathing: 1 +- breath on its own sine of `period` seconds.
function Ambient.breathe(t, period)
	return 1 + Ambient.Crickets.breath * math.sin(2 * math.pi * t / period)
end

-- Distance on the ground plane from a point to the stream polyline (segments,
-- not just points), less the local half width. Stream rows are {x, y, z, width}.
function Ambient.streamDistance(point, stream)
	local best = math.huge
	if not stream or #stream == 0 then return best end
	local px, pz = point.X, point.Z
	for i = 1, math.max(1, #stream - 1) do
		local a, b = stream[i], stream[math.min(i + 1, #stream)]
		local ax, az, bx, bz = a[1], a[3], b[1], b[3]
		local dx, dz = bx - ax, bz - az
		local length = dx * dx + dz * dz
		local t = if length > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / length, 0, 1) else 0
		local cx, cz = ax + dx * t, az + dz * t
		local half = ((a[4] or 0) + ((b[4] or 0) - (a[4] or 0)) * t) * .5
		local d = math.max(0, math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2) - half)
		if d < best then best = d end
	end
	return best
end

-- quiet: nil for today's bed, or Ambient.Quiet.bed {floor, peak, range}.
function Ambient.bedGain(distance, quiet)
	local floor = if quiet then quiet.floor else Ambient.BedFloor
	local peak = if quiet then quiet.peak else Ambient.BedPeak
	local range = if quiet then quiet.range else Ambient.BedRange
	if type(distance) ~= "number" or distance ~= distance then return floor end
	local full = if quiet then quiet.full or 0 else 0
	return floor + (peak - floor) * smoothstep(1 - math.max(0, distance - full) / (range - full))
end

-- A water voice's equalizer (Ambient.WaterLoops eq): made on first use, switched off when the clip needs none.
function Ambient.applyEq(voice, eq)
	local node = voice:FindFirstChild("WaterEq")
	if not eq then
		if node then node.Enabled = false end
		return node
	end
	if not node then
		node = Instance.new("EqualizerSoundEffect")
		node.Name = "WaterEq"
		node.Parent = voice
	end
	node.LowGain, node.MidGain, node.HighGain = eq.low or 0, eq.mid or 0, eq.high or 0
	node.MidRange = NumberRange.new(eq.from or 400, eq.to or 4000)
	node.Enabled = true
	return node
end

-- The falls' live numbers: today's one point per fall, or the Quiet emitters down each fall with the water source
-- (Ambient.waterSource) and its EQ. Emitters past today's first are silent (volume 0, stopped) with quiet off.
-- Writes only on a change (force: rewrite anyway, after the new waterfall loop failed to load).
function Ambient:applyQuiet(quiet, force)
	if self.quietOn == quiet and not force then return end
	self.quietOn = quiet
	local source = Ambient.waterSource("waterfall", self.waterfallFailed)
	for _, fall in ipairs(self.falls) do
		if fall.name then
			local base, list = Ambient.Falls[fall.name], quiet and Ambient.Quiet.falls[fall.name]
			local over = list and list[fall.index or 1]
			local id, eq, position
			if over then
				fall.spec = table.freeze({ volume = over.volume * source.volume, min = over.min, max = over.max,
					speed = over.speed * source.speed, offset = over.offset })
				id, eq, position = source.id, source.eq, Ambient.fallPoint(fall.beam, over)
			elseif (fall.index or 1) == 1 then
				fall.spec, id = base, Ambient.Ids.waterfall_loop
				local at = fall.beam[base.anchor]
				position = Vector3.new(at[1], at[2] + base.lift, at[3])
			else
				fall.spec = table.freeze({ volume = 0, min = base.min, max = base.max, speed = base.speed, offset = 0 })
				id = Ambient.Ids.waterfall_loop
			end
			local content = "rbxassetid://" .. id
			if fall.voice.SoundId ~= content then
				if fall.voice.IsPlaying then fall.voice:Stop() end
				fall.voice.SoundId = content
			end
			fall.voice.RollOffMinDistance, fall.voice.RollOffMaxDistance = fall.spec.min, fall.spec.max
			fall.voice.PlaybackSpeed = fall.spec.speed
			if position and fall.part then fall.part.Position = position end
			Ambient.applyEq(fall.voice, eq)
		end
	end
end

function Ambient.band(daylight)
	daylight = if type(daylight) == "number" then daylight else 1
	if daylight > .6 then return Ambient.Bands.day, "day" end
	if daylight >= .3 then return Ambient.Bands.dusk, "dusk" end
	return Ambient.Bands.night, "night"
end

-- Pure bird scheduler: no instances, no clock of its own. step() returns the
-- chirps due now as {perch, position, cue, pitch, volume}. Inactive (a deck
-- round, no listener) cancels everything pending; nothing queues up.
local Birds = {}
Birds.__index = Birds
Ambient.Birds = Birds
function Birds.new(seed)
	return setmetatable({ random = Random.new(seed or 1), pending = {}, trees = {} }, Birds)
end
function Birds:tree(index)
	local tree = self.trees[index]
	if not tree then
		local r = Random.new(index * 7919 + 17)
		local a = r:NextInteger(1, 5)
		local b = (a + r:NextInteger(0, 3)) % 5 + 1
		tree = { pitch = .92 + r:NextNumber() * .2, favourites = { a, b } }
		self.trees[index] = tree
	end
	return tree
end
function Birds:choose(listener, perches, avoid)
	local near = {}
	for index, perch in ipairs(perches) do
		local d = (perch - listener).Magnitude
		if d <= Ambient.BirdReach and index ~= avoid then table.insert(near, { index = index, d = d }) end
	end
	if #near == 0 then return nil end
	table.sort(near, function(a, b) return a.d < b.d end)
	local count = math.min(Ambient.BirdChoices, #near)
	local total = 0
	for rank = 1, count do total += 1 / rank end
	local roll = self.random:NextNumber() * total
	for rank = 1, count do
		roll -= 1 / rank
		if roll <= 0 then return near[rank].index end
	end
	return near[count].index
end
function Birds:cue(index, band, name)
	local tree = self:tree(index)
	local pick
	if name == "day" then
		-- Each tree favours two of the day cues; one time in four it uses any day cue.
		pick = if self.random:NextNumber() < .75 then tree.favourites[self.random:NextInteger(1, 2)] else band.cues[self.random:NextInteger(1, #band.cues)]
	else
		pick = band.cues[self.random:NextInteger(1, #band.cues)]
	end
	return "bird_chirp_" .. pick, tree.pitch
end
function Birds:cancel()
	table.clear(self.pending)
	self.nextAt = nil
end
-- night: the cricket gate (garden hour and Alive life). Open, the night band schedules no bird at all and every chirp
-- fades with Ambient.birdGain; shut, the bands are as they always were.
function Birds:step(now, listener, daylight, perches, active, night)
	if not active or not listener or not perches or #perches == 0 then
		self:cancel()
		return {}
	end
	local band, name = Ambient.band(daylight)
	if night == true then
		local gain = Ambient.birdGain(daylight)
		if name == "night" or gain <= 0 then
			self:cancel()
			return {}
		end
		if gain < 1 then band = table.clone(band); band.volume *= gain end
	end
	local due = {}
	if not self.nextAt then
		self.nextAt = now + self.random:NextNumber(band.min, band.max)
	elseif now >= self.nextAt then
		self.nextAt = now + self.random:NextNumber(band.min, band.max)
		local index = self:choose(listener, perches, self.last)
		if index then
			self.last = index
			local cue, pitch = self:cue(index, band, name)
			table.insert(self.pending, { at = now, perch = index, cue = cue, pitch = pitch, volume = band.volume })
			if self.random:NextNumber() < band.phrase then
				local at = now
				for _ = 1, self.random:NextInteger(1, 2) do
					at += self.random:NextNumber(.35, .9)
					local extra = self:cue(index, band, name)
					table.insert(self.pending, { at = at, perch = index, cue = extra, pitch = pitch, volume = band.volume })
				end
			end
			if band.reply > 0 and self.random:NextNumber() < band.reply then
				local other = self:choose(listener, perches, index)
				if other then
					local replyCue, replyPitch = self:cue(other, band, name)
					table.insert(self.pending, { at = now + self.random:NextNumber(.8, 1.6), perch = other, cue = replyCue, pitch = replyPitch, volume = band.volume })
				end
			end
		end
	end
	for i = #self.pending, 1, -1 do
		local event = self.pending[i]
		if now >= event.at then
			table.remove(self.pending, i)
			event.position = perches[event.perch]
			table.insert(due, 1, event)
		end
	end
	return due
end

-- Near crickets (QA-R2-LOOK 2): pure, like Birds. At night three positional crickets sit in the three nearest bushes
-- within reach; each trills (a 1-2 s cut of the bed's own recording) every 6 to 14 s. A cricket whose bush is within
-- `hush` of the listener goes quiet and stays quiet `hold` seconds after they leave. step() answers the trills due now
-- as {slot, bush, position, pitch, start, length, volume}; slot 1..3 is the nearest-first rank (its own voice).
local NearCrickets = {}
NearCrickets.__index = NearCrickets
Ambient.NearCrickets = NearCrickets
function NearCrickets.new(seed)
	return setmetatable({ random = Random.new(seed or 4), nextAt = {}, hushUntil = {} }, NearCrickets)
end
function NearCrickets:cancel()
	table.clear(self.nextAt)
end
function NearCrickets:step(now, listener, bushes, gain)
	local N = Ambient.Crickets.near
	if not listener or not bushes or #bushes == 0 or not gain or gain <= .02 then
		self:cancel()
		return {}
	end
	local near = {}
	for index, bush in ipairs(bushes) do
		local d = (bush - listener).Magnitude
		if d <= N.hush then self.hushUntil[index] = now + N.hold end
		if d <= N.reach then table.insert(near, { index = index, d = d }) end
	end
	table.sort(near, function(a, b) return a.d < b.d end)
	local due, chosen = {}, {}
	for slot = 1, math.min(N.voices, #near) do
		local index = near[slot].index
		chosen[index] = true
		local at = self.nextAt[index]
		if not at then
			self.nextAt[index] = now + self.random:NextNumber(0, N.gapMax)
		elseif now >= at then
			self.nextAt[index] = now + self.random:NextNumber(N.gapMin, N.gapMax)
			if now >= (self.hushUntil[index] or -math.huge) then
				local length = self.random:NextNumber(N.lengthMin, N.lengthMax)
				table.insert(due, { slot = slot, bush = index, position = bushes[index], length = length,
					pitch = self.random:NextNumber(N.pitchMin, N.pitchMax), start = self.random:NextNumber(0, N.source - length),
					volume = N.volume * gain })
			end
		end
	end
	-- A bush that left the three nearest starts afresh when it comes back.
	for index in pairs(self.nextAt) do if not chosen[index] then self.nextAt[index] = nil end end
	return due
end

-- Round mix: 1 in the garden, 0 in a Pocket Deck round. Linear, rate by direction.
function Ambient.mixToward(mix, round, dt)
	if round then return math.max(0, mix - dt / Ambient.RoundOut) end
	return math.min(1, mix + dt / Ambient.RoundIn)
end

local function sound(name, id, group, parent, looped)
	local voice = Instance.new("Sound")
	voice.Name = "EggDropAmbient_" .. name
	voice.SoundId = "rbxassetid://" .. id
	voice.Looped = looped == true
	voice.Volume = 0
	voice.SoundGroup = group
	voice.Parent = parent
	return voice
end

local function group(name)
	local node = Instance.new("SoundGroup")
	node.Name = name
	node.Volume = 0
	node.Parent = SoundService
	return node
end

-- audio: the BoardAudio instance (master volume, focus, music toggle, ducks).
-- options: {world, data, perches, now, daylight, listener, auto=false, wind={on, gust} or false, warn,
-- night=function (the cricket gate), bushes={Vector3}, music2={on, hourOn, weight} or false} (fixtures).
-- The cricket gate: the garden hour on (HollowClock.hourOn) and Alive life on. Off the beta place (the ceiling) it is a
-- constant false, so the live game never asks.
function Ambient.nightGate(Shared, clock)
	local Alive = require(Shared:WaitForChild("Alive"))
	if not Alive.ceiling("life") then return function() return false end end
	return function()
		local Clock = clock or require(script.Parent.HollowClock)
		return Clock.hourOn() == true and Alive.on("life") == true
	end
end
function Ambient.new(audio, options)
	options = options or {}
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local data = options.data or require(Shared:WaitForChild("WorldV7Data"))
	local self = setmetatable({
		audio = audio, level = 1, round = false, mix = 1, deckMix = 0, bed = Ambient.BedFloor, bedTarget = Ambient.BedFloor,
		bedClock = 0, stream = data.beams and data.beams.stream or {}, perches = options.perches or data.perches or require(script.Parent.AmbientPerches),
		birds = Birds.new(options.seed or 1), voices = {}, owners = {}, connections = {},
		now = options.now or os.clock, daylight = options.daylight or require(script.Parent.HollowClock).daylight,
		listenerOf = options.listener, deviceActive = true, rustle = 0, rustleQuiet = 0, warn = options.warn or warn,
		night = options.night or Ambient.nightGate(Shared), bushes = options.bushes, crickets = 0, nearCrickets = NearCrickets.new((options.seed or 1) + 11),
	}, Ambient)
	self.group = group("EggDropAmbientCues")
	self.ambience = group("EggDropAmbience")
	self.deckGroup = group("EggDropDeckMusic")
	local folder = Instance.new("Folder")
	folder.Name = "EggDropAmbientAudio"
	folder.Parent = options.world or workspace
	self.folder = folder
	local function emitter(name, position)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.Transparency, part.Size, part.CastShadow = 1, Vector3.new(.2, .2, .2), false
		part.Position = position
		part.Parent = folder
		return part
	end
	self.emitter = emitter
	local warm = {}
	self.bedVoice = sound("water_bed_loop", Ambient.Ids.water_bed_loop, self.ambience, SoundService, true)
	table.insert(warm, self.bedVoice)
	self.falls = {}
	for _, beam in ipairs(data.beams and data.beams.falls or {}) do
		local spec = Ambient.Falls[beam.name]
		if spec then
			-- Beta 35: one voice per Quiet emitter (the first is today's point); applyQuiet places and tunes them.
			local count = math.max(1, #(Ambient.Quiet.falls[beam.name] or {}))
			for index = 1, count do
				local at = beam[spec.anchor]
				local part = emitter(beam.name .. "_Sound" .. (if index > 1 then index else ""), Vector3.new(at[1], at[2] + spec.lift, at[3]))
				local voice = sound("waterfall_loop", Ambient.Ids.waterfall_loop, self.ambience, part, true)
				voice.RollOffMode = Enum.RollOffMode.InverseTapered
				voice.RollOffMinDistance, voice.RollOffMaxDistance = spec.min, spec.max
				voice.PlaybackSpeed = spec.speed
				table.insert(self.falls, { voice = voice, spec = spec, name = beam.name, index = index, beam = beam, part = part })
				if index == 1 then table.insert(warm, voice) end
			end
		end
	end
	-- LOOK-R4 Q4: the quiet mix follows the Aero look (options.quiet: a function for specs).
	self.quiet = options.quiet or function()
		local ok, on = pcall(function() return require(Shared:WaitForChild("Aero")).on() end)
		return ok and on == true
	end
	self:applyQuiet(self.quiet() == true)
	self.birdPool = {}
	for index = 1, Ambient.BirdVoices do
		local part = emitter("BirdPerch" .. index, Vector3.new(0, -500, 0))
		local voice = sound("bird", Ambient.Ids.bird_chirp_1, self.ambience, part, false)
		voice.RollOffMode = Enum.RollOffMode.InverseTapered
		voice.RollOffMinDistance, voice.RollOffMaxDistance = Ambient.BirdMin, Ambient.BirdMax
		self.birdPool[index] = { part = part, voice = voice }
	end
	for index = 1, 6 do
		local probe = sound("bird_chirp_" .. index, Ambient.Ids["bird_chirp_" .. index], self.ambience, folder, false)
		table.insert(warm, probe)
		self.voices["bird_chirp_" .. index] = { probe }
	end
	for _, cue in ipairs(Ambient.OneShots) do
		local id = Ambient.Ids[cue]
		if id then
			local voice = sound(cue, id, self.group, SoundService, false)
			self.voices[cue] = { voice }
			table.insert(warm, voice)
		end
	end
	if Ambient.Ids.deck_music then
		self.deckVoice = sound("deck_music", Ambient.Ids.deck_music, self.deckGroup, SoundService, true)
		table.insert(warm, self.deckVoice)
	end
	-- MUSIC-BRIEF 3 and 4 (Alive music2): the v2 garden pair (in BoardAudio) and deck pair (here). Not on this place at
	-- all (the live game): nothing runs per frame. While MusicTracks.Ids are 0 it makes no voice: today's music.
	-- options.music2 (specs): {on(), hourOn(), weight()} or false. By default only for the game's own instance (auto).
	if options.music2 ~= nil then
		self.music2Of = options.music2 or nil
	elseif options.auto ~= false then
		task.spawn(function()
			local Alive = require(Shared:WaitForChild("Alive"))
			if not Alive.ceiling(MusicTracks.Feature) then return end
			local Clock = require(script.Parent.HollowClock)
			self.music2Of = {
				on = function() return Alive.on(MusicTracks.Feature) end,
				hourOn = function() return Clock.hourOn() == true end,
				weight = function() return MusicTracks.nightWeight(Clock.Hour.phase(Clock.Hour.time())) end,
			}
		end)
	end
	if options.wind ~= nil then
		self.wind = options.wind or nil
	else
		task.spawn(function()
			local Alive = require(Shared:WaitForChild("Alive"))
			-- Not on this place at all (the live game): nothing runs per frame.
			if not Alive.ceiling("wind") then return end
			self.wind = {
				on = function() return Alive.on("wind") end,
				gust = function()
					local camera = workspace.CurrentCamera
					return if camera then Wind.gust(camera.CFrame.Position, workspace:GetServerTimeNow()) else 0
				end,
			}
		end)
	end
	-- Beta 17 1.3 D: the wind bed (its own switch, off when missing) and the Den's echo (the `scene` switch). Not on this
	-- place at all (the live game): nothing runs per frame. options.windBed / options.echo (specs): tables or false.
	self.bedRandom = Random.new((options.seed or 1) + 23)
	if options.windBed ~= nil then self.windBedOf = options.windBed or nil end
	if options.echo ~= nil then self.echoOf = options.echo or nil end
	-- Slice F: the hill's sound zones. options.zones (specs): {on(), camera(), zone(point) -> zone, h} or false. By
	-- default only for the game's own instance (auto), so fixtures never read the real camera.
	if options.zones ~= nil then
		self.zonesOf = options.zones or nil
	elseif options.auto ~= false then
		task.spawn(function()
			local Alive = require(Shared:WaitForChild("Alive"))
			if not Alive.ceiling("scene") then return end
			local Night = require(Shared:WaitForChild("HillNight"))
			local Layout = require(Shared:WaitForChild("DenLayout"))
			self.zonesOf = {
				on = function() return Alive.on("scene") == true and workspace:GetAttribute("CliffDen") == true end,
				camera = function()
					local current = workspace.CurrentCamera
					return current and current.CFrame.Position
				end,
				zone = function(point) return Night.zone(point, Layout.current(), nil, Layout) end,
			}
		end)
	end
	if options.windBed == nil or options.echo == nil then
		task.spawn(function()
			local Alive = require(Shared:WaitForChild("Alive"))
			local function camera()
				local current = workspace.CurrentCamera
				return current and current.CFrame.Position
			end
			if options.windBed == nil and Alive.ceiling("windbed") then
				self.windBedOf = {
					on = function() return Alive.on("windbed") end,
					blow = function()
						local at = camera()
						return if at then Wind.blow(at, workspace:GetServerTimeNow()) else 0
					end,
					hushed = function()
						local Hush = require(Shared:WaitForChild("Hush"))
						local at = self:listener()
						return Hush.on() == true and at ~= nil and Hush.regionAt(at) == "hush"
					end,
				}
			end
			if options.echo == nil and Alive.ceiling("scene") then
				self.echoOf = {
					on = function() return Alive.on("scene") end,
					camera = camera,
					inside = function(point)
						local Layout = require(Shared:WaitForChild("DenLayout"))
						local den = Layout.current()
						return den ~= nil and Layout.inRoom(den, point) == true
					end,
				}
			end
		end)
	end
	task.spawn(function()
		local failed = {}
		local ok = pcall(function()
			ContentProvider:PreloadAsync(warm, function(id, status)
				if status ~= Enum.AssetFetchStatus.Success then table.insert(failed, id) end
			end)
		end)
		if not self.destroyed and (not ok or #failed > 0) then
			warn("Egg Drop could not load ambient audio " .. table.concat(failed, ", "))
		end
		-- The new waterfall loop (once its id is filled) would not load: the falls go back to the stand-in.
		local loop = Ambient.WaterLoops.waterfall
		if not self.destroyed and loop and loop.id > 0 and table.find(failed, "rbxassetid://" .. loop.id) then
			self.waterfallFailed = true
			if self.quietOn then self:applyQuiet(true, true) end
		end
	end)
	if options.auto ~= false then
		table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:step(dt) end))
		-- Beta 35: hear the world from the player's head while the beta's water mix is on (AudioListener).
		local ok, ears = pcall(function()
			return require(script.Parent.AudioListener).start({ on = function() return self.quietOn == true end })
		end)
		if ok then self.ears = ears else warn("[Ambient] listener: " .. tostring(ears)) end
	end
	Ambient.shared = self
	return self
end

-- Ambience: On 1, Soft 0.5, Off 0 (A7). Off also silences coos and the station ping.
function Ambient:setLevel(level)
	self.level = math.clamp(tonumber(level) or 1, 0, 1)
end

-- The deck round owns the soundscape: the world fades out and the deck music in.
function Ambient:setRound(active)
	if self.destroyed then return end
	active = active == true
	if self.round == active and self.roundKnown then return end
	self.round, self.roundKnown = active, true
	if active then
		self.birds:cancel()
		for _, entry in ipairs(self.birdPool) do entry.voice:Stop() end
		if self.cricketBed then self:stopCrickets(true) end
		for _, voices in pairs(self.voices) do
			for _, voice in ipairs(voices) do
				if string.find(voice.Name, "pet_coo") then voice:Stop() end
			end
		end
		self.owners = {}
	end
	if self.audio and self.audio.duck and self.deckVoice then
		-- The world music sits under BoardAudio's duck table; a long duck holds it out
		-- for the whole round and a zero-length one releases it.
		if active then self.audio:duck(Ambient.DeckDuck, 1e6, 0) else self.audio:duck(Ambient.DeckDuck, 0, 1) end
	end
end

-- The race song (Ambient.Race). Where in the file a moment `elapsed` seconds after GO falls (negative: the count-in):
-- the lead-in plays once, then 3..35 loops. Pure.
function Ambient.racePosition(elapsed)
	local R = Ambient.Race
	local t = R.lead + elapsed
	if t < R.loopEnd then return t end
	local span = R.loopEnd - R.lead
	return R.lead + (t - R.lead) % span
end
-- The voice, made on the first setRace. Sound.LoopRegion loops 3..35 after a lead-in that plays once (raceLoop
-- "region"); where the engine refuses it, the plain loop of 3..35 from GO with no lead-in (raceLoop "section").
-- song: Ambient.raceSong (nil: the placeholder). A voice of another kind is replaced (only ever at a new race).
function Ambient:makeRaceVoice(song)
	song = song or Ambient.raceSong(false)
	if self.raceVoice and self.raceSongKind == song.kind then return self.raceVoice end
	if self.raceVoice then self.raceVoice:Destroy(); self.raceVoice = nil end
	self.raceSongKind, self.raceVolume = song.kind, song.volume
	if song.kind == "deck" then
		-- The whole clip, plain Looped: no regions.
		local deck = sound("race_song_deck", song.id, self.deckGroup, SoundService, true)
		self.raceLoop, self.raceVoice = "whole", deck
		task.spawn(function()
			local fine = true
			local ok = pcall(Ambient.preload, { deck }, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then fine = false end
			end)
			if self.destroyed or self.raceVoice ~= deck or (ok and fine) then return end
			-- Never a silent race: the placeholder for the session, from where this race has reached.
			self.warn("Egg Drop could not load the deck song for the race; the race song plays")
			self.raceDeckFailed = true
			self:makeRaceVoice(Ambient.raceSong(false))
			if self.race then self.race.seek = true end
		end)
		return deck
	end
	local R = Ambient.Race
	local voice = sound("race_song", Ambient.RaceSongId, self.deckGroup, SoundService, true)
	local ok = pcall(function()
		voice.PlaybackRegionsEnabled = true
		voice.LoopRegion = NumberRange.new(R.lead, R.loopEnd)
	end)
	if not ok and not pcall(function() voice.PlaybackRegion = NumberRange.new(R.lead, R.loopEnd) end) then
		pcall(function() voice.PlaybackRegionsEnabled = false end)
	end
	self.raceLoop = if ok then "region" else "section"
	self.raceVoice = voice
	task.spawn(function() pcall(Ambient.preload, { voice }, function() end) end)
	return voice
end
-- DashClient, for this player's own race only. state:
--   "play" go  the lead-in and the loop, timed so `go` (on self.now's clock) is the downbeat of bar 1. Asked again with
--              a new go, it re-times only past `resync` seconds (one jump, never a drift)
--   "line"     over the line: down to `line` in lineFade s, still looping (the wait for the others is not silent)
--   "card"     the results card opens: out in cardFade s; the world music stays held out under the card
--   "off"      the race is put away (Done, Race again, left, aborted): out in `fade` s, the world music back over `back`
-- Answers whether it took the state.
function Ambient:raceSongNow()
	local of, on = self.music2Of, false
	if of then
		local ok, value = pcall(of.on)
		on = ok and value == true
	end
	return Ambient.raceSong(on, MusicTracks.Ids, self.raceDeckFailed or self.deck2Failed)
end
function Ambient:setRace(state, go, fade)
	if self.destroyed then return false end
	local R = Ambient.Race
	local race = self.race
	if state == "play" then
		if type(go) ~= "number" or go ~= go then return false end
		if not race or race.state == "off" then
			-- A new race (or one still fading out): from silence, at the new race's place in the song, the song chosen
			-- now (the deck song or the placeholder, beta 44 note 25) and kept to the end of this race.
			local voice = self:makeRaceVoice(self:raceSongNow())
			if voice.IsPlaying then voice:Stop() end
			race = { gain = 0, go = go }
			self.race = race
		elseif race.state == "line" or race.state == "card" then return false -- never back up once over the line
		elseif math.abs(go - race.go) > R.resync then race.go, race.seek = go, true end
		race.state, race.target, race.fade = "play", 1, R.inFade
	elseif not race then return false
	elseif state == "line" then
		if race.state ~= "play" then return false end
		race.state, race.target, race.fade = "line", R.line, R.lineFade
	elseif state == "card" then
		if race.state == "off" then return false end
		race.state, race.target, race.fade = "card", 0, R.cardFade
	elseif state == "off" then
		race.state, race.target, race.fade = "off", 0, if type(fade) == "number" and fade >= 0 then fade else R.leaveFade
	else return false end
	race.rate = math.abs(race.target - race.gain) / math.max(race.fade, 1e-3)
	return true
end
function Ambient:stepRace(dt, master, active, music)
	local R, race, voice = Ambient.Race, self.race, self.raceVoice
	local elapsed = 0
	if race and voice then
		if race.gain < race.target then race.gain = math.min(race.target, race.gain + race.rate * dt)
		elseif race.gain > race.target then race.gain = math.max(race.target, race.gain - race.rate * dt) end
		elapsed = self.now() - race.go
		local from = if self.raceLoop == "section" then 0 else -R.lead
		local wanted = race.gain > 0 and music and master > 0 and active and elapsed >= from
		voice.Volume = (self.raceVolume or R.volume) * race.gain
		if wanted then
			-- Started (or back from the music toggle, a lost focus, a mute) at the place the race has reached.
			if not voice.IsPlaying or race.seek then
				voice.TimePosition = if self.raceLoop == "whole" then Ambient.deckRacePosition(elapsed, Ambient.length(voice))
					else Ambient.racePosition(elapsed)
				if not voice.IsPlaying then voice:Play() end
				race.seek = nil
			end
		elseif voice.IsPlaying then voice:Stop() end
		if race.state == "off" and race.gain <= 0 then
			self.race = nil
			if voice.IsPlaying then voice:Stop() end
		end
	end
	-- The world music: held out from `out` seconds before the lead-in until the race is put away, then back over `back`.
	race = self.race
	local hold = race ~= nil and race.state ~= "off" and (race.state ~= "play" or elapsed >= -(R.lead + R.out))
	local world = self.raceWorld or 1
	world = if hold then math.max(0, world - dt / R.out) else math.min(1, world + dt / R.back)
	self.raceWorld = world
	local audio = self.audio
	if audio and audio.ducks then
		local gain = if world < 1 then world else nil
		if audio.ducks[Ambient.RaceDuck] ~= gain then
			audio.ducks[Ambient.RaceDuck] = gain
			if audio.refreshLoops then audio:refreshLoops() end
		end
	end
end

-- Another looped world voice (the Aero fountain, LOOK-R2 3), mixed exactly like the falls: in the ambience group (master,
-- Ambience level, ducks, the deck round's fade, device focus) and stopped with them. spec: {id, parent, volume, speed,
-- min, max, start = 0..1 share of the clip, fallback = {id, speed, volume}}. Returns a remover; calling it twice is nothing.
-- fallback (LOOK-R3 3): if the asset does not load (moderation, deleted, offline), the voice switches to the fallback id
-- and speed once, so a new loop can never leave the place silent where the stand-in played.
Ambient.preload = function(instances, callback)
	ContentProvider:PreloadAsync(instances, callback)
end
Ambient.LoadGrace = 4
Ambient.wait = function(seconds)
	return task.wait(seconds)
end
-- The clip's length once a Sound really holds audio, else nil (specs replace both).
Ambient.length = function(voice)
	local seconds = if voice.IsLoaded == true then tonumber(voice.TimeLength) or 0 else 0
	return if seconds > 0 then seconds else nil
end
-- spec.eq / fallback.eq (beta 35): an Ambient.WaterLoops equalizer for that clip (nil: none).
function Ambient:addVoice(name, spec)
	local voice = sound(name, spec.id, self.ambience, spec.parent, true)
	voice.RollOffMode = Enum.RollOffMode.InverseTapered
	voice.RollOffMinDistance, voice.RollOffMaxDistance = spec.min or 5, spec.max or 30
	voice.PlaybackSpeed = spec.speed or 1
	if spec.eq then Ambient.applyEq(voice, spec.eq) end
	local entry = { voice = voice, spec = { volume = spec.volume or .2, offset = 0 } }
	table.insert(self.falls, entry)
	local removed = false
	local fallback = spec.fallback
	local function startAt()
		-- spec.start: where in the clip to begin, as a share of its length (only known once it has loaded).
		local seconds = spec.start and Ambient.length(voice)
		if seconds then
			entry.spec.offset = spec.start * seconds * .98
			-- Already started from 0 while it loaded: one jump now, while it has barely begun.
			if voice.IsPlaying then voice.TimePosition = entry.spec.offset end
		end
	end
	if (fallback and fallback.id and fallback.id ~= spec.id) or spec.start then
		task.spawn(function()
			local failed = false
			local ok = pcall(Ambient.preload, { voice }, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then failed = true end
			end)
			if removed or self.destroyed then return end
			-- Architect r3: a clip the place may not use can report Success and still never load; trust the Sound too.
			-- Code review r3: IsLoaded can lag a Success by a moment; give it LoadGrace seconds before falling back.
			if ok and not failed then
				local waited = 0
				while Ambient.length(voice) == nil and waited < Ambient.LoadGrace do
					waited += Ambient.wait(.25)
					if removed or self.destroyed then return end
				end
			end
			local loaded = ok and not failed and Ambient.length(voice) ~= nil
			if loaded or not (fallback and fallback.id and fallback.id ~= spec.id) then
				if loaded then startAt() end
				return
			end
			pcall(function()
				if voice.IsPlaying then voice:Stop() end
				voice.SoundId = "rbxassetid://" .. fallback.id
				voice.PlaybackSpeed = fallback.speed or 1
				if fallback.volume then entry.spec.volume = fallback.volume end
				if fallback.eq or spec.eq then Ambient.applyEq(voice, fallback.eq) end
			end)
			entry.fellBack = true
			entry.spec.offset = 0
			-- The stand-in's own length: start it at the same share once it is in.
			pcall(Ambient.preload, { voice }, function() end)
			if not removed and not self.destroyed then startAt() end
		end)
	end
	return function()
		removed = true
		local at = table.find(self.falls, entry)
		if at then table.remove(self.falls, at) end
		pcall(function() voice:Destroy() end)
	end
end

-- A water voice (beta 35): addVoice with its clip from Ambient.WaterLoops (the new loop with the stand-in as its
-- fallback, or the stand-in and its EQ). spec: {parent, volume, speed, min, max, start}; volume and speed are the
-- voice's own and scale the clip's.
function Ambient:addWaterVoice(kind, spec)
	local source = assert(Ambient.waterSource(kind), "no water loop " .. tostring(kind))
	local volume, speed = spec.volume or .2, spec.speed or 1
	local fallback = source.fallback
	return self:addVoice(kind, { id = source.id, parent = spec.parent, volume = volume * source.volume, speed = speed * source.speed,
		min = spec.min, max = spec.max, start = spec.start, eq = source.eq,
		fallback = fallback and { id = fallback.id, speed = speed * fallback.speed, volume = volume * fallback.volume, eq = fallback.eq } })
end

function Ambient:listener()
	if self.listenerOf then return self.listenerOf() end
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then return root.Position end
	local camera = workspace.CurrentCamera
	return camera and camera.CFrame.Position or nil
end

function Ambient:master()
	local audio = self.audio
	if not audio then return 1, true, 1, true end
	local duck = 1
	for name, gain in pairs(audio.ducks or {}) do
		-- The deck round's, the race song's and the hill zones' ducks hold the world music only, never these groups.
		if name ~= Ambient.DeckDuck and name ~= Ambient.RaceDuck and name ~= Ambient.ZoneDuck then duck = math.min(duck, gain) end
	end
	local music = if audio.isMusicEnabled then audio:isMusicEnabled() else true
	return audio.master or 0, audio.deviceActive ~= false, duck, music
end

local function startLoop(voice, offset)
	if not voice.IsPlaying then
		voice.TimePosition = offset or 0
		voice:Play()
	end
end

function Ambient:step(dt)
	if self.destroyed then return end
	dt = math.clamp(dt or 0, 0, .25)
	local master, active, duck, music = self:master()
	self.deviceActive = active
	local device = if active then 1 else 0
	self.mix = Ambient.mixToward(self.mix, self.round, dt)
	local deckTarget = if self.round and music then 1 else 0
	self.deckMix = if deckTarget > self.deckMix then math.min(1, self.deckMix + dt / Ambient.RoundIn) else math.max(0, self.deckMix - dt / Ambient.RoundOut)
	self.group.Volume = master * device * (if self.level > 0 then 1 else 0)
	self.ambience.Volume = master * device * self.level * duck * self.mix
	self.deckGroup.Volume = master * device * duck
	local listener = self:listener()
	if self.zonesOf then
		local ok, problem = pcall(self.stepZones, self, dt)
		if not ok then
			self.warn("[Ambient] hill zones: " .. tostring(problem))
			self.zonesOf = nil
			pcall(self.dropZones, self)
		end
	end
	local zone = self.zoneGains
	local water = if zone then zone.water else 1
	-- Bed: 4 Hz distance sample, eased.
	self.bedClock += dt
	if self.bedClock >= Ambient.BedSample and listener then
		self.bedClock = 0
		self:applyQuiet(self.quiet() == true)
		self.bedTarget = Ambient.bedGain(Ambient.streamDistance(listener, self.stream), if self.quietOn then Ambient.Quiet.bed else nil)
	end
	self.bed += (self.bedTarget - self.bed) * math.min(1, dt / (if self.quietOn then Ambient.Quiet.bed.ease else Ambient.BedEase))
	local audible = self.ambience.Volume > 0
	if audible then
		self.bedVoice.Volume = self.bed * water
		-- LOOK-R4 Q4: the quiet bed is silent away from the stream: stop it there instead of playing silence.
		if self.bed * water > .002 then
			self.bedSilent = 0
			startLoop(self.bedVoice, 0)
		else
			self.bedSilent = (self.bedSilent or 0) + dt
			if self.bedSilent >= Ambient.Quiet.bed.pause and self.bedVoice.IsPlaying then self.bedVoice:Stop() end
		end
		for _, fall in ipairs(self.falls) do
			fall.voice.Volume = fall.spec.volume * water
			-- A spare emitter with quiet off (volume 0) stays stopped instead of playing silence.
			if fall.spec.volume > 0 then startLoop(fall.voice, fall.spec.offset)
			elseif fall.voice.IsPlaying then fall.voice:Stop() end
		end
	else
		-- Fully faded (round, mute, unfocused): stop the loops instead of playing silence.
		if self.bedVoice.IsPlaying then self.bedVoice:Stop() end
		for _, fall in ipairs(self.falls) do if fall.voice.IsPlaying then fall.voice:Stop() end end
	end
	if self.music2Of then
		local ok, problem = pcall(self.stepMusic2, self, dt, master, active)
		if not ok then
			self.warn("[Ambient] music2: " .. tostring(problem))
			self.music2Of = nil
			pcall(self.dropMusic2, self)
		end
	end
	local deck2 = self.deck2
	if deck2 and deck2.ready then
		-- MUSIC-BRIEF 4: the v2 pair plays in today's deck loop's place.
		if self.deckVoice and self.deckVoice.IsPlaying then self.deckVoice.Volume = 0; self.deckVoice:Stop() end
	elseif self.deckVoice then
		self.deckVoice.Volume = Ambient.DeckMusicVolume * self.deckMix
		if self.deckMix > 0 and master > 0 and active then startLoop(self.deckVoice, 0)
		elseif self.deckVoice.IsPlaying and self.deckMix == 0 then self.deckVoice:Stop() end
	end
	-- Nothing per frame unless a race song has ever been asked for (the beta's Dash only).
	if self.race or (self.raceWorld or 1) < 1 then self:stepRace(dt, master, active, music) end
	local night = self.night() == true
	local daylight = self.daylight()
	local events = self.birds:step(self.now(), listener, daylight, self.perches, audible and not self.round and self.mix > .5, night)
	for _, event in ipairs(events) do
		-- Garden life (GardenLife) sets onChirp while it is on: a bird appears on the perch that was heard. Only for a
		-- chirp that really played; a hook that throws is dropped (said once) and the sound goes on as before.
		if self:chirp(event) and self.onChirp then
			local ok, problem = pcall(self.onChirp, event.perch, event.position, event.cue)
			if not ok then
				self.warn("[Life] chirp hook: " .. tostring(problem))
				self.onChirp = nil
			end
		end
	end
	if self.wind and not pcall(self.stepRustle, self, dt, audible) then
		self.wind = nil
		self:stopRustle()
	end
	if self.windBedOf then
		local ok, problem = pcall(self.stepWindBed, self, dt)
		if not ok then
			self.warn("[Ambient] wind bed: " .. tostring(problem))
			self.windBedOf = nil
			pcall(self.stopWindBed, self)
		end
	end
	if self.echoOf then
		local ok, problem = pcall(self.stepEcho, self, dt)
		if not ok then
			self.warn("[Ambient] den echo: " .. tostring(problem))
			self.echoOf = nil
			pcall(self.dropEcho, self)
		end
	end
	if night or self.cricketBed then
		local ok, problem = pcall(self.stepCrickets, self, dt, audible and not self.round, night, daylight, listener)
		if not ok then
			self.warn("[Ambient] crickets: " .. tostring(problem))
			self.night = function() return false end
			self:stopCrickets()
		end
	end
end

-- The bushes the near crickets sit in: WorldDressing.Bushes ({x, base y, z, ...}), half a stud over the base.
function Ambient:bushPoints()
	if not self.bushes then
		local ok, Dressing = pcall(function() return require(game:GetService("ReplicatedStorage").Shared.WorldDressing) end)
		local list = {}
		if ok and type(Dressing) == "table" and type(Dressing.Bushes) == "table" then
			for _, row in ipairs(Dressing.Bushes) do table.insert(list, Vector3.new(row[1], row[2] + .5, row[3])) end
		end
		self.bushes = list
	end
	return self.bushes
end
-- Made once, the first time the gate opens; reused after.
function Ambient:makeCrickets()
	local C = Ambient.Crickets
	local function loop(name, spec)
		local voice = sound(name, spec.id, self.ambience, SoundService, true)
		voice.PlaybackSpeed = spec.speed
		local eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "LowCut"
		eq.LowGain, eq.MidGain, eq.HighGain = C.lowGain, 0, 0
		eq.Parent = voice
		return voice
	end
	self.cricketBed = loop("crickets_bed", C.bed)
	self.cricketLayer = loop("crickets_layer", C.layer)
	self.cricketPool = {}
	for index = 1, C.near.voices do
		local part = self.emitter("CricketBush" .. index, Vector3.new(0, -500, 0))
		local voice = sound("cricket", C.bed.id, self.ambience, part, false)
		voice.RollOffMode = Enum.RollOffMode.InverseTapered
		voice.RollOffMinDistance, voice.RollOffMaxDistance = C.near.min, C.near.max
		voice.PlaybackRegionsEnabled = true
		self.cricketPool[index] = { part = part, voice = voice }
	end
	local voices = { self.cricketBed, self.cricketLayer }
	task.spawn(function() pcall(function() ContentProvider:PreloadAsync(voices) end) end)
end
-- One writer per voice per step; the gain eases at most Crickets.slew a second (a clock jump still takes 4 s).
function Ambient:stepCrickets(dt, audible, night, daylight, listener)
	local C = Ambient.Crickets
	local goal = if night then Ambient.cricketGain(daylight) else 0
	self.crickets = Ambient.slew(self.crickets, goal, dt, C.slew)
	if not self.cricketBed then
		if self.crickets <= 0 then return end
		self:makeCrickets()
	end
	local gain = self.crickets
	if not audible or gain <= 0 then
		self:stopCrickets(true)
		return
	end
	local t = self.now()
	local gust = 0
	if self.wind and self.wind.gust then
		local ok, value = pcall(self.wind.gust)
		if ok and type(value) == "number" and value == value then gust = math.clamp(value, 0, 1) end
	end
	local duck = 1 - C.gust * gust
	for _, layer in ipairs({ { self.cricketBed, C.bed, 0 }, { self.cricketLayer, C.layer, 11 } }) do
		local voice, spec = layer[1], layer[2]
		voice.Volume = spec.volume * gain * Ambient.breathe(t, spec.breathe) * duck
		if voice.IsLoaded ~= false then startLoop(voice, layer[3]) end
	end
	for _, trill in ipairs(self.nearCrickets:step(t, listener, self:bushPoints(), gain)) do
		local entry = self.cricketPool[trill.slot]
		if entry and not entry.voice.IsPlaying then
			entry.part.Position = trill.position
			entry.voice.PlaybackRegion = NumberRange.new(trill.start, trill.start + trill.length)
			entry.voice.PlaybackSpeed = trill.pitch
			entry.voice.Volume = trill.volume * duck
			entry.voice.TimePosition = trill.start
			entry.voice:Play()
		end
	end
end
-- Silent: the loops and trills stop (never playing 0). keepGain: a round or mute, the night itself goes on.
function Ambient:stopCrickets(keepGain)
	if not keepGain then self.crickets = 0 end
	self.nearCrickets:cancel()
	for _, voice in ipairs({ self.cricketBed, self.cricketLayer }) do
		if voice and voice.IsPlaying then voice:Stop() end
	end
	for _, entry in ipairs(self.cricketPool or {}) do
		if entry.voice.IsPlaying then entry.voice:Stop() end
	end
end

-- The rustle follows the gust where the camera is. The gust comes in over .8 s and leaves over 2.7 s by
-- itself; the ambience group (Ambience setting, master, ducks, round fade) sits on top. Reduced Motion
-- does not change it. Silent for a while, off, muted or in a round: the loop is stopped, not playing 0.
function Ambient:stepRustle(dt, audible)
	if not audible or Ambient.RustleId == nil or self.wind.on() ~= true then
		self:stopRustle()
		return
	end
	local voice = self.rustleVoice
	if not voice then
		voice = sound("wind_rustle", Ambient.RustleId, self.ambience, SoundService, true)
		self.rustleVoice = voice
		task.spawn(function() pcall(function() ContentProvider:PreloadAsync({ voice }) end) end)
	end
	local gust = self.wind.gust()
	if type(gust) ~= "number" or gust ~= gust then gust = 0 end
	local goal, most = Ambient.RustlePeak * math.clamp(gust, 0, 1), Ambient.RustleSlew * dt
	self.rustle += math.clamp(goal - self.rustle, -most, most)
	voice.Volume = self.rustle
	if self.rustle > 0 then
		self.rustleQuiet = 0
		-- A missing, refused or still loading asset never plays.
		if voice.IsLoaded then startLoop(voice, 0) end
	elseif voice.IsPlaying then
		self.rustleQuiet += dt
		if self.rustleQuiet >= Ambient.RustleHold then voice:Stop() end
	end
end

function Ambient:stopRustle()
	self.rustle, self.rustleQuiet = 0, 0
	local voice = self.rustleVoice
	if voice and (voice.IsPlaying or voice.Volume > 0) then
		voice:Stop()
		voice.Volume = 0
	end
end

-- The wind bed (1.3 D). Off (the switch) or in a deck round or the Hush: stopped. Otherwise it plays, once loaded, from
-- a random point of the loop, and only its volume and speed follow the wind.
function Ambient:stepWindBed(dt)
	local bed = self.windBedOf
	local hushed = bed.hushed ~= nil and bed.hushed() == true
	if bed.on() ~= true or self.round or hushed then
		self:stopWindBed()
		return
	end
	local voice = self.windBedVoice
	if not voice then
		voice = sound("wind_bed", Ambient.WindBedId, self.ambience, SoundService, true)
		local eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "Air"
		eq.HighGain, eq.MidGain, eq.LowGain = Ambient.WindBed.highGain, 0, 0
		eq.Parent = voice
		self.windBedVoice, self.windBedLevel = voice, 0
		task.spawn(function() pcall(function() ContentProvider:PreloadAsync({ voice }) end) end)
	end
	local blow = bed.blow()
	if type(blow) ~= "number" or blow ~= blow then blow = 0 end
	self.windBedLevel = Ambient.windBedSlew(self.windBedLevel or 0, Ambient.windBedVolume(blow), dt)
	voice.Volume = self.windBedLevel * (if self.zoneGains then self.zoneGains.wind else 1)
	voice.PlaybackSpeed = Ambient.windBedSpeed(blow)
	if not voice.IsPlaying and voice.IsLoaded then
		local length = tonumber(voice.TimeLength) or 0
		voice.TimePosition = if length > 0 then self.bedRandom:NextNumber() * length else 0
		voice:Play()
	end
end
function Ambient:stopWindBed()
	self.windBedLevel = 0
	local voice = self.windBedVoice
	if voice and (voice.IsPlaying or voice.Volume > 0) then
		voice:Stop()
		voice.Volume = 0
	end
end
-- The Den's echo (1.3 D): the camera sampled every Echo.sample s; the effects exist only while the echo is wet.
function Ambient:stepEcho(dt)
	local echo = self.echoOf
	local E = Ambient.Echo
	local on = echo.on() == true
	self.echoClock = (self.echoClock or E.sample) + dt
	if not on then
		self.echoInside = false
	elseif self.echoClock >= E.sample then
		self.echoClock = 0
		local at = echo.camera and echo.camera()
		self.echoInside = typeof(at) == "Vector3" and echo.inside(at) == true
	end
	local inside = on and self.echoInside == true
	self.echoWet = Ambient.echoToward(self.echoWet or E.off, inside, dt)
	if not inside and self.echoWet <= E.off + 1e-6 then
		self:dropEcho()
		return
	end
	if not self.echoEffects then
		self.echoEffects = {}
		local mine = { EggDropAmbience = self.ambience, EggDropAmbientCues = self.group }
		for _, name in ipairs(E.groups) do
			local group = mine[name] or SoundService:FindFirstChild(name)
			if group and group:IsA("SoundGroup") then
				local reverb = Instance.new("ReverbSoundEffect")
				reverb.Name = "DenEcho"
				reverb.DecayTime, reverb.Density, reverb.Diffusion, reverb.DryLevel = E.decay, E.density, E.diffusion, E.dry
				reverb.WetLevel = self.echoWet
				reverb.Parent = group
				table.insert(self.echoEffects, reverb)
			end
		end
	end
	for _, reverb in ipairs(self.echoEffects) do
		if math.abs(reverb.WetLevel - self.echoWet) > .05 then reverb.WetLevel = self.echoWet end
	end
end
-- The hill's sound zones (slice F): the camera sampled every HillNight.Sample s, the dB mix eased toward its place's.
-- At home with the gate off and everything back at 0 dB the zones drop out entirely (no duck, no room tone, gains nil).
function Ambient:stepZones(dt)
	local Night = self.night_ or require(game:GetService("ReplicatedStorage").Shared.HillNight)
	self.night_ = Night
	local zones = self.zonesOf
	-- The gate and the camera at the sample rate only (code review: nothing per frame once settled or dropped).
	self.zoneClock = (self.zoneClock or Night.Sample) + dt
	local sample = self.zoneClock >= Night.Sample or self.zoneOn == nil
	if sample then
		self.zoneClock = 0
		self.zoneOn = zones.on() == true
	end
	local on = self.zoneOn
	if not on and self.zoneDb == nil then return end
	local goal = self.zoneGoal
	if sample or not goal then
		local place, h = "home", 0
		if on then
			local at = zones.camera and zones.camera()
			if typeof(at) == "Vector3" then place, h = zones.zone(at) end
			if type(h) ~= "number" or h ~= h then h = 0 end
		end
		-- For Studio probes (their own module cache): the place on this client's ambience folder, written on change.
		if place ~= self.zone and self.folder then self.folder:SetAttribute("HillZone", place) end
		self.zone = place
		goal = Night.mix(place or "home", h)
	end
	-- A new goal: the blend starts again from where the mix is now, Ease seconds the whole way.
	local fresh = not self.zoneGoal or not Night.same(goal, self.zoneGoal)
	if fresh then
		self.zoneGoal, self.zoneFrom, self.zoneT = goal, self.zoneDb or Night.mix("home", 0), 0
	elseif (self.zoneT or 0) >= Night.Ease and self.zoneGains then
		return -- settled on its goal: the gains, the duck and the room tone stand as they are
	end
	self.zoneT = (self.zoneT or 0) + dt
	self.zoneDb = Night.ease(self.zoneFrom, self.zoneGoal, self.zoneT)
	if not on and Night.same(self.zoneDb, Night.Mix.home) then
		self:dropZones()
		return
	end
	local gains = Night.gains(self.zoneDb)
	self.zoneGains = gains
	-- The world music: BoardAudio's own duck, written straight in (never timed), refreshed only on a real change.
	local audio = self.audio
	if audio and audio.ducks then
		local want = if gains.music < .995 then gains.music else nil
		local have = audio.ducks[Ambient.ZoneDuck]
		if (want == nil) ~= (have == nil) or (want and have and math.abs(want - have) > .005) then
			audio.ducks[Ambient.ZoneDuck] = want
			if audio.refreshLoops then audio:refreshLoops() end
		end
	end
	-- The den's room tone: a voice only with an id, playing only while it is heard.
	if Ambient.RoomToneId and Ambient.RoomToneId ~= 0 and gains.room > 0 and not self.round then
		if not self.roomVoice then
			self.roomVoice = sound("den_room_tone", Ambient.RoomToneId, self.ambience, SoundService, true)
		end
		self.roomVoice.Volume = Ambient.RoomToneVolume * gains.room
		if not self.roomVoice.IsPlaying and self.roomVoice.IsLoaded then self.roomVoice:Play() end
	elseif self.roomVoice and self.roomVoice.IsPlaying then
		self.roomVoice:Stop()
		self.roomVoice.Volume = 0
	end
end
function Ambient:dropZones()
	self.zoneGains, self.zoneDb, self.zoneGoal, self.zone, self.zoneFrom, self.zoneT = nil, nil, nil, nil, nil, nil
	if self.folder and self.folder:GetAttribute("HillZone") ~= nil then self.folder:SetAttribute("HillZone", nil) end
	local audio = self.audio
	if audio and audio.ducks and audio.ducks[Ambient.ZoneDuck] ~= nil then
		audio.ducks[Ambient.ZoneDuck] = nil
		if audio.refreshLoops then audio:refreshLoops() end
	end
	if self.roomVoice then self.roomVoice:Stop(); self.roomVoice.Volume = 0 end
end
function Ambient:dropEcho()
	for _, reverb in ipairs(self.echoEffects or {}) do reverb:Destroy() end
	self.echoEffects = nil
	self.echoWet = Ambient.Echo.off
end

function Ambient:chirp(event)
	local id = Ambient.Ids[event.cue]
	if not id or not event.position then return false end
	local free
	for _, entry in ipairs(self.birdPool) do
		if not entry.voice.IsPlaying then free = entry; break end
	end
	if not free then return false end -- A6 cap: at most three bird voices.
	free.part.Position = event.position
	free.voice.SoundId = "rbxassetid://" .. id
	free.voice.PlaybackSpeed = event.pitch or 1
	free.voice.Volume = (event.volume or .5) * (if self.zoneGains then self.zoneGains.birds else 1)
	free.voice.TimePosition = 0
	free.voice:Play()
	return true
end

-- PetCooScheduler / StationAttract voice contract (mirrors BoardAudio:play).
function Ambient:has(cue)
	local voices = self.voices[cue]
	return voices ~= nil and voices[1] ~= nil
end
function Ambient:play(cue, speed, volume, owner)
	local voices = self.voices[cue]
	if self.destroyed or not voices or self.group.Volume == 0 or not self.deviceActive or self.round then return false end
	local voice = voices[1]
	if voice.IsLoaded == false then return false end
	voice.PlaybackSpeed = speed or 1
	voice.Volume = volume or .3
	voice.TimePosition = 0
	self.owners[voice] = owner
	voice:Play()
	return true
end
function Ambient:stopOwner(owner)
	local stopped = 0
	for voice, token in pairs(self.owners) do
		if token == owner then voice:Stop(); self.owners[voice] = nil; stopped += 1 end
	end
	return stopped
end
function Ambient:petSpeechBusy(exceptOwner)
	if self.audio and self.audio.petSpeechBusy and self.audio:petSpeechBusy(exceptOwner) then return true end
	for _, cue in ipairs({ "pet_coo_1", "pet_coo_2", "pet_coo_3" }) do
		for _, voice in ipairs(self.voices[cue] or {}) do
			if voice.IsPlaying and self.owners[voice] ~= exceptOwner then return true end
		end
	end
	return false
end

-- MUSIC-BRIEF 3 and 4 (Alive music2). Which pairs are in use (the switch and MusicTracks.Ids), then the garden pair's
-- night weight and hour handed to BoardAudio, and the deck pair stepped here.
function Ambient:stepMusic2(dt, master, active)
	local of = self.music2Of
	local use = MusicTracks.active(of.on() == true, MusicTracks.Ids)
	local audio = self.audio
	if audio and audio.setGarden2 then
		local want = use.garden and not audio.garden2Failed
		if want ~= (audio.garden2 ~= nil) then
			audio:setGarden2(if want then { day = MusicTracks.Ids.garden_day, night = MusicTracks.Ids.garden_night } else nil)
			self.music2Clock = nil
		end
		if audio.garden2 then
			-- The weight moves over 90-120 s: read at 10 Hz, and at once on the first step (joining at night).
			self.music2Clock = (self.music2Clock or MusicTracks.WeightEvery) + dt
			if self.music2Clock >= MusicTracks.WeightEvery then
				self.music2Clock = 0
				self.music2Hour = of.hourOn() == true
				self.music2W = if self.music2Hour then of.weight() else 0
			end
			audio:stepGarden2(dt, self.music2W, self.music2Hour)
		end
	end
	local want = use.deck and not self.deck2Failed
	if want ~= (self.deck2 ~= nil) then
		if want then self:makeDeck2(if use.lite then MusicTracks.Ids.deck_lite else nil) else self:dropDeck2() end
	end
	if self.deck2 and self.deck2.ready then self:stepDeck2(dt, master, active) end
end
-- The deck pair: the round track and, when uploaded, its lite variant (the results card, a finished round, a menu over
-- the deck: self.deckLite, set by the client entry). Both run in step whenever the deck music plays (the lite one on
-- the deck's grid at 2:1, MusicTracks.target), crossed in DeckFade seconds, equal power. In the deck music's group like
-- today's loop, so the master, focus and the ducks reach both.
function Ambient:makeDeck2(liteId)
	local deck = { main = sound("deck_v2", MusicTracks.Ids.deck, self.deckGroup, SoundService, true), w = 0, check = 0, ready = false }
	if liteId then deck.lite = sound("deck_lite_v2", liteId, self.deckGroup, SoundService, true) end
	self.deck2 = deck
	task.spawn(function()
		local fine = true
		local ok = pcall(Ambient.preload, { deck.main, deck.lite }, function(_, status)
			if status ~= Enum.AssetFetchStatus.Success then fine = false end
		end)
		if self.destroyed or self.deck2 ~= deck then return end
		if ok and fine then
			deck.ready = true
			return
		end
		-- Never silent: a pair that will not load gives the deck back to today's loop for the session.
		self.warn("Egg Drop could not load the v2 deck music; today's loop plays")
		self.deck2Failed = true
		self:dropDeck2()
	end)
	return deck
end
function Ambient:dropDeck2()
	local deck = self.deck2
	if not deck then return end
	self.deck2 = nil
	deck.main:Destroy()
	if deck.lite then deck.lite:Destroy() end
end
function Ambient:dropMusic2()
	self:dropDeck2()
	if self.audio and self.audio.garden2 and self.audio.setGarden2 then self.audio:setGarden2(nil) end
end
function Ambient:stepDeck2(dt, master, active)
	local deck = self.deck2
	local main, lite = deck.main, deck.lite
	local wantLite = false
	if lite and self.deckLite then
		local ok, on = pcall(self.deckLite)
		wantLite = ok and on == true
	end
	deck.w = MusicTracks.slew(deck.w, if wantLite then 1 else 0, dt, MusicTracks.DeckFade)
	local mainGain, liteGain = MusicTracks.gains(deck.w, 1)
	main.Volume = Ambient.DeckMusicVolume * self.deckMix * mainGain
	if lite then lite.Volume = Ambient.DeckMusicVolume * MusicTracks.LiteLevel * self.deckMix * liteGain end
	if self.deckMix > 0 and master > 0 and active then
		if not main.IsPlaying then
			-- Together, from the top, as today's loop starts each round.
			main.TimePosition = 0
			main:Play()
			if lite then lite.TimePosition = 0; lite:Play() end
			deck.check = 0
		elseif lite and not lite.IsPlaying then
			lite.TimePosition = MusicTracks.target(main.TimePosition, MusicTracks.Lengths.deck, 0, MusicTracks.Lengths.deck_lite) or 0
			lite:Play()
			deck.check = 0
		end
	elseif self.deckMix == 0 then
		if main.IsPlaying then main:Stop() end
		if lite and lite.IsPlaying then lite:Stop() end
	end
	deck.check -= dt
	if lite and deck.check <= 0 then
		deck.check = MusicTracks.CheckEvery
		MusicTracks.sync(main, lite, mainGain, liteGain, MusicTracks.Drift, Ambient.length)
	end
end

function Ambient:destroy()
	if self.destroyed then return end
	self.destroyed = true
	if self.audio and self.audio.duck and self.deckVoice and self.round then self.audio:duck(Ambient.DeckDuck, 0, 1) end
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	if self.ears then self.ears.stop();self.ears = nil end
	self.bedVoice:Destroy()
	for _, voices in pairs(self.voices) do for _, voice in ipairs(voices) do voice:Destroy() end end
	if self.deckVoice then self.deckVoice:Destroy() end
	self:dropDeck2()
	if self.raceVoice then self.raceVoice:Destroy(); self.race = nil end
	if self.audio and self.audio.ducks and self.audio.ducks[Ambient.RaceDuck] ~= nil then
		self.audio.ducks[Ambient.RaceDuck] = nil
		if self.audio.refreshLoops then self.audio:refreshLoops() end
	end
	if self.rustleVoice then self.rustleVoice:Destroy() end
	if self.windBedVoice then self.windBedVoice:Destroy() end
	self:dropEcho()
	self:dropZones()
	if self.roomVoice then self.roomVoice:Destroy(); self.roomVoice = nil end
	if self.cricketBed then self.cricketBed:Destroy(); self.cricketLayer:Destroy() end
	self.folder:Destroy()
	self.group:Destroy(); self.ambience:Destroy(); self.deckGroup:Destroy()
	if Ambient.shared == self then Ambient.shared = nil end
end

return Ambient
