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
	deck_music = 114810234817689,
}
Ambient.OneShots = { "pet_coo_1", "pet_coo_2", "pet_coo_3", "machine_attract" }

-- A3 brook bed: bed = 0.22 + 0.18 * smoothstep(1 - d / 45), sampled at 4 Hz, eased 0.5 s.
Ambient.BedFloor, Ambient.BedPeak, Ambient.BedRange = .22, .40, 45
Ambient.BedSample, Ambient.BedEase = .25, .5
-- A6: round fade out 0.6 s, back over 1.0 s. Deck music voice volume (world music is 0.13).
Ambient.RoundOut, Ambient.RoundIn = .6, 1.0
Ambient.DeckMusicVolume = .2
Ambient.DeckDuck = "deckRound"
-- A4 waterfall emitters. Positions come from WorldV7Data.beams.falls by name.
Ambient.Falls = {
	W7_Water__waterfall_tumble = { anchor = "bottom", lift = 5.8, volume = .70, min = 18, max = 150, speed = .92, offset = 0 },
	W7_Water__waterfall_sky = { anchor = "top", lift = -.75, volume = .50, min = 10, max = 90, speed = 1.08, offset = 3.7 },
}
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

function Ambient.bedGain(distance)
	if type(distance) ~= "number" or distance ~= distance then return Ambient.BedFloor end
	return Ambient.BedFloor + (Ambient.BedPeak - Ambient.BedFloor) * smoothstep(1 - distance / Ambient.BedRange)
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
function Birds:step(now, listener, daylight, perches, active)
	if not active or not listener or not perches or #perches == 0 then
		self:cancel()
		return {}
	end
	local band, name = Ambient.band(daylight)
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
-- options: {world, data, perches, now, daylight, listener, auto=false} (fixtures).
function Ambient.new(audio, options)
	options = options or {}
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local data = options.data or require(Shared:WaitForChild("WorldV7Data"))
	local self = setmetatable({
		audio = audio, level = 1, round = false, mix = 1, deckMix = 0, bed = Ambient.BedFloor, bedTarget = Ambient.BedFloor,
		bedClock = 0, stream = data.beams and data.beams.stream or {}, perches = options.perches or data.perches or require(script.Parent.AmbientPerches),
		birds = Birds.new(options.seed or 1), voices = {}, owners = {}, connections = {},
		now = options.now or os.clock, daylight = options.daylight or require(script.Parent.HollowClock).daylight,
		listenerOf = options.listener, deviceActive = true,
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
			table.insert(self.falls, { voice = voice, spec = spec })
			table.insert(warm, voice)
		end
	end
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
		if name ~= Ambient.DeckDuck then duck = math.min(duck, gain) end
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
	self.deckGroup.Volume = master * device
	local listener = self:listener()
	-- Bed: 4 Hz distance sample, eased.
	self.bedClock += dt
	if self.bedClock >= Ambient.BedSample and listener then
		self.bedClock = 0
		self.bedTarget = Ambient.bedGain(Ambient.streamDistance(listener, self.stream))
	end
	self.bed += (self.bedTarget - self.bed) * math.min(1, dt / Ambient.BedEase)
	local audible = self.ambience.Volume > 0
	if audible then
		self.bedVoice.Volume = self.bed
		startLoop(self.bedVoice, 0)
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
	local events = self.birds:step(self.now(), listener, self.daylight(), self.perches, audible and not self.round and self.mix > .5)
	for _, event in ipairs(events) do self:chirp(event) end
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
	self.folder:Destroy()
	self.group:Destroy(); self.ambience:Destroy(); self.deckGroup:Destroy()
	if Ambient.shared == self then Ambient.shared = nil end
end

return Ambient
