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
Ambient.Quiet = table.freeze({
	bed = table.freeze({ floor = 0, peak = .10, full = 6, range = 28, ease = .6, pause = 2 }),
	falls = table.freeze({
		W7_Water__waterfall_tumble = table.freeze({ volume = .18, min = 6, max = 38 }),
		W7_Water__waterfall_sky = table.freeze({ volume = .10, min = 4, max = 26 }),
	}),
})
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

-- The falls' live numbers: today's spec, or its Quiet overrides (volume, min, max). Writes only on a change.
function Ambient:applyQuiet(quiet)
	if self.quietOn == quiet then return end
	self.quietOn = quiet
	for _, fall in ipairs(self.falls) do
		if fall.name then
			local base, over = Ambient.Falls[fall.name], quiet and Ambient.Quiet.falls[fall.name]
			fall.spec = if over then table.freeze({ anchor = base.anchor, lift = base.lift, speed = base.speed, offset = base.offset,
				volume = over.volume, min = over.min, max = over.max }) else base
			fall.voice.RollOffMinDistance, fall.voice.RollOffMaxDistance = fall.spec.min, fall.spec.max
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
-- night=function (the cricket gate), bushes={Vector3}} (fixtures).
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
			local at = beam[spec.anchor]
			local part = emitter(beam.name .. "_Sound", Vector3.new(at[1], at[2] + spec.lift, at[3]))
			local voice = sound("waterfall_loop", Ambient.Ids.waterfall_loop, self.ambience, part, true)
			voice.RollOffMode = Enum.RollOffMode.InverseTapered
			voice.RollOffMinDistance, voice.RollOffMaxDistance = spec.min, spec.max
			voice.PlaybackSpeed = spec.speed
			table.insert(self.falls, { voice = voice, spec = spec, name = beam.name })
			table.insert(warm, voice)
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
	end)
	if options.auto ~= false then
		table.insert(self.connections, RunService.Heartbeat:Connect(function(dt) self:step(dt) end))
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
function Ambient:makeRaceVoice()
	if self.raceVoice then return self.raceVoice end
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
function Ambient:setRace(state, go, fade)
	if self.destroyed then return false end
	local R = Ambient.Race
	local race = self.race
	if state == "play" then
		if type(go) ~= "number" or go ~= go then return false end
		local voice = self:makeRaceVoice()
		if not race or race.state == "off" then
			-- A new race (or one still fading out): from silence, at the new race's place in the song.
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
		local from = if self.raceLoop == "region" then -R.lead else 0
		local wanted = race.gain > 0 and music and master > 0 and active and elapsed >= from
		voice.Volume = R.volume * race.gain
		if wanted then
			-- Started (or back from the music toggle, a lost focus, a mute) at the place the race has reached.
			if not voice.IsPlaying or race.seek then
				voice.TimePosition = Ambient.racePosition(elapsed)
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
function Ambient:addVoice(name, spec)
	local voice = sound(name, spec.id, self.ambience, spec.parent, true)
	voice.RollOffMode = Enum.RollOffMode.InverseTapered
	voice.RollOffMinDistance, voice.RollOffMaxDistance = spec.min or 5, spec.max or 30
	voice.PlaybackSpeed = spec.speed or 1
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
		-- The deck round's and the race song's ducks hold out the world music only, never these groups.
		if name ~= Ambient.DeckDuck and name ~= Ambient.RaceDuck then duck = math.min(duck, gain) end
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
		self.bedVoice.Volume = self.bed
		-- LOOK-R4 Q4: the quiet bed is silent away from the stream: stop it there instead of playing silence.
		if self.bed > .002 then
			self.bedSilent = 0
			startLoop(self.bedVoice, 0)
		else
			self.bedSilent = (self.bedSilent or 0) + dt
			if self.bedSilent >= Ambient.Quiet.bed.pause and self.bedVoice.IsPlaying then self.bedVoice:Stop() end
		end
		for _, fall in ipairs(self.falls) do
			fall.voice.Volume = fall.spec.volume
			startLoop(fall.voice, fall.spec.offset)
		end
	else
		-- Fully faded (round, mute, unfocused): stop the loops instead of playing silence.
		if self.bedVoice.IsPlaying then self.bedVoice:Stop() end
		for _, fall in ipairs(self.falls) do if fall.voice.IsPlaying then fall.voice:Stop() end end
	end
	if self.deckVoice then
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
	free.voice.Volume = event.volume or .5
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

function Ambient:destroy()
	if self.destroyed then return end
	self.destroyed = true
	if self.audio and self.audio.duck and self.deckVoice and self.round then self.audio:duck(Ambient.DeckDuck, 0, 1) end
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	self.bedVoice:Destroy()
	for _, voices in pairs(self.voices) do for _, voice in ipairs(voices) do voice:Destroy() end end
	if self.deckVoice then self.deckVoice:Destroy() end
	if self.raceVoice then self.raceVoice:Destroy(); self.race = nil end
	if self.audio and self.audio.ducks and self.audio.ducks[Ambient.RaceDuck] ~= nil then
		self.audio.ducks[Ambient.RaceDuck] = nil
		if self.audio.refreshLoops then self.audio:refreshLoops() end
	end
	if self.rustleVoice then self.rustleVoice:Destroy() end
	if self.cricketBed then self.cricketBed:Destroy(); self.cricketLayer:Destroy() end
	self.folder:Destroy()
	self.group:Destroy(); self.ambience:Destroy(); self.deckGroup:Destroy()
	if Ambient.shared == self then Ambient.shared = nil end
end

return Ambient
