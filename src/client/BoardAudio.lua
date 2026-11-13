local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Audio = {}
Audio.__index = Audio

-- Only IDs for the original WAVs in assets/audio belong here.
local assetIds = {
	aim = 78319039170839,
	drop = 125552140473053,
	land = 114394270790206,
	bank = 137957843347780,
	merge_bubble = 132946666827827,
	merge_jelly = 100118672776397,
	merge_chain = 72145493661024,
	charge = 101582196091552,
	hatch_rise = 108923415809497,
	hatch = 124797289860370,
	pet = 104178433438245,
	puddle = 79464813520035,
	wick = 73790979677763,
	orbit = 105659319683342,
	overflow = 101342613025976,
	retry = 80753325038930,
	menu = 74679010378287,
}
-- PLACEHOLDER sounds (assets/audio/placeholder/, uploaded 2026-11-13). Spencer's own
-- audio replaces these; see assets/audio/placeholder/PLACEHOLDER-AUDIO.md.
local placeholderIds = {
	count_blip = 108647439201867, danger_enter = 71704518273465, danger_clear = 86858776986054, danger_tick = 122357660151659,
	deck_boot = 121880800893112, quest_complete = 112750571745350, bear_boop = 110282522210689,
	reveal_hush = 75961612982659, spot_on = 93433115588030, streak_whoosh = 122156273335998,
	reveal_shimmer = 71554174288583, tag_slam = 90906080983451, name_slam = 131679952336458,
	desc_tick = 75005899109415, spin_whoosh = 88149004355893, shimmer_loop = 120156969856514,
	reveal_out = 88912365203095, goal_tick = 103058048084589, row_flip = 135375361476574,
	star_land = 134977919634272, stars_total = 86488710361812, new_best = 130207329583484,
	egg_ready = 84150737933826, meter_fill = 71482588822934, win = 118201763537475,
	lose = 103783283368544, egg_wobble = 103643084989292, egg_crack_glint = 73765307779351,
	egg_select = 133779589657893,
}
for cue, id in pairs(placeholderIds) do assetIds[cue] = id end
Audio.PlaceholderIds = placeholderIds
local cues = {
	"aim", "drop", "land", "bank", "merge_bubble", "merge_jelly", "merge_chain",
	"charge", "hatch_rise", "hatch", "pet", "puddle", "wick", "orbit", "retry", "menu",
	"deck_boot", "quest_complete",
	-- Round danger (UI-SPEC-REDESIGN-MENUS 6.3): one soft entry cue when the stack
	-- goes over the fill line and a short chime when it clears. They replace the
	-- repeating `overflow` blip.
	"danger_enter", "danger_clear", "danger_tick",
	-- Celebrations (UI-SPEC-REDESIGN-CELEBRATIONS 1.7, 2.9; CelebrationKit.Cues) and the
	-- Hatch eggs preview. Placeholder sounds until Spencer's land.
	"bear_boop", "reveal_hush", "spot_on", "streak_whoosh", "reveal_shimmer", "tag_slam", "name_slam",
	"desc_tick", "spin_whoosh", "shimmer_loop", "reveal_out", "goal_tick", "row_flip", "star_land",
	"stars_total", "new_best", "egg_ready", "meter_fill", "win", "lose",
	"egg_wobble", "egg_crack_glint", "egg_select",
	-- Results count-up: one very short blip per +1 Star, each cut by the next
	-- (batch 2026-11-13 R1). No id yet; the coordinator uploads a placeholder.
	"count_blip",
}
-- Cues named by the UI spec whose sound files are not delivered yet
-- (AUDIO-HANDOFF.md). They have no voice, so play() is a quiet no-op.
Audio.PendingCues = {}
local fieldCues={"aim","drop","land","bank","merge_bubble","merge_jelly","merge_chain"}

function Audio.uri(cue)
	local id = assetIds[cue]
	if id then
		return "rbxassetid://" .. id
	elseif RunService:IsStudio() and game.PlaceId == 0 then
		return "rbxasset://sounds/egg-drop-polish/egg_drop_" .. cue .. ".wav"
	end
	return nil
end

function Audio.new()
	local group = Instance.new("SoundGroup")
	group.Name = "EggDropSFX"
	group.Volume = 0
	group.Parent = SoundService
	local self = setmetatable({ voices = {}, indices = {}, group = group,
		musicEnabled = true, deviceActive = true, ducks = {}, connections = {} }, Audio)
	for name, id in pairs({ Music = 98540058987296, Purr = 80835586668229 }) do
		local loopGroup = Instance.new("SoundGroup")
		loopGroup.Name, loopGroup.Volume, loopGroup.Parent = "EggDrop" .. name, 0, SoundService
		local voice = Instance.new("Sound")
		voice.Name, voice.SoundId = "EggDrop_" .. name, "rbxassetid://" .. id
		voice.Looped, voice.Volume, voice.SoundGroup, voice.Parent = true, 0, loopGroup, SoundService
		self[string.lower(name)] = { voice = voice, group = loopGroup, ready = false }
	end
	table.insert(self.connections, UserInputService.WindowFocusReleased:Connect(function()
		self:setDeviceActive(false)
	end))
	table.insert(self.connections, UserInputService.WindowFocused:Connect(function()
		self:setDeviceActive(true)
	end))
	local warmup = {}
	local missing = {}
	for _, cue in ipairs(cues) do
		local uri = Audio.uri(cue)
		if uri then
			local count = if cue == "merge_bubble" or cue == "merge_jelly" then 3 else 1
			local voices = {}
			for index = 1, count do
				local voice = Instance.new("Sound")
				voice.Name = "EggDrop_" .. cue
				voice.SoundId = uri
				voice.SoundGroup = group
				voice.Parent = SoundService
				voices[index] = voice
			end
			self.voices[cue] = voices
			table.insert(warmup, voices[1])
		elseif not Audio.PendingCues[cue] then
			table.insert(missing, cue)
		end
	end
	if #missing > 0 then
		warn("Egg Drop has no audio asset IDs for " .. table.concat(missing, ", "))
	end
	if #warmup > 0 then
		task.spawn(function()
			local failed = {}
			local ok = pcall(function() ContentProvider:PreloadAsync(warmup, function(id, status)
				if status ~= Enum.AssetFetchStatus.Success then
					table.insert(failed, id)
				end
			end) end)
			if not self.destroyed and (not ok or #failed > 0) then
				warn("Egg Drop could not load audio " .. table.concat(failed, ", "))
			end
		end)
	end
	for _, loop in ipairs({ self.music, self.purr }) do
		task.spawn(function()
			local success = true
			local ok = pcall(function()
				ContentProvider:PreloadAsync({loop.voice}, function(_, status)
					if status ~= Enum.AssetFetchStatus.Success then success = false end
				end)
			end)
			if self.destroyed then return end
			loop.ready = ok and success and loop.voice.IsLoaded
			if not loop.ready then warn("Egg Drop could not load " .. loop.voice.Name) end
			-- Only music is eligible for a deferred start. Purr needs a new gesture.
			self:refreshLoops()
		end)
	end
	return self
end

function Audio:fade(loop, volume, complete)
	loop.epoch = (loop.epoch or 0) + 1
	local epoch = loop.epoch
	if loop.tween then loop.tween:Cancel(); loop.tween = nil end
	if self.tween then
		self.tween(loop.voice, volume, function()
			if not self.destroyed and loop.epoch == epoch and complete then complete() end
		end)
		return
	end
	local tween = TweenService:Create(loop.voice, TweenInfo.new(0.06), {Volume = volume})
	loop.tween = tween
	tween.Completed:Once(function(state)
		if not self.destroyed and loop.epoch == epoch and state == Enum.PlaybackState.Completed then
			loop.tween = nil
			if complete then complete() end
		end
	end)
	tween:Play()
end

function Audio:refreshLoops()
	if self.destroyed or not self.music then return end
	local master = self.master or 0
	local duck = 1
	for _, gain in pairs(self.ducks) do duck = math.min(duck, gain) end
	self.music.group.Volume = master * duck
	self.purr.group.Volume = master
	local music = self.music
	if master > 0 and self.musicEnabled and self.deviceActive and music.ready then
		music.voice.Volume = 0.13
		if not music.voice.IsPlaying then music.voice:Play() end
	else
		music.voice.Volume = 0
		music.voice:Stop()
	end
end

function Audio:isMusicEnabled() return self.musicEnabled == true end
function Audio:setDeviceActive(active)
	if self.destroyed then return end
	if self.deviceActive~=(active==true)then self.deviceEpoch=(self.deviceEpoch or 0)+1 end
	self.deviceActive = active == true
	if not self.deviceActive then
		for voice in pairs(self.voiceOwners or {})do voice:Stop()end
		self.voiceOwners=nil
		self:cancelBoot();self:stopField();self:silencePurr()
	end
	self:refreshLoops()
end
function Audio:setMusicEnabled(enabled)
	if self.destroyed then return end
	self.musicEnabled = enabled == true
	self:refreshLoops()
end

function Audio:setPurr(active)
	local loop = self.purr
	if self.destroyed or not loop then return false end
	if active then
		if loop.active then return true end
		if not loop.ready or (self.master or 0) == 0 or not self.deviceActive then return false end
		loop.active = true
		loop.voice.Volume = 0
		loop.voice.TimePosition = 0
		loop.voice:Play()
		self:fade(loop, 0.24)
		return true
	end
	if not loop.active then return false end
	loop.active = false
	self:fade(loop, 0, function() loop.voice:Stop() end)
	return false
end

function Audio:silencePurr()
	if self.destroyed then return end
	local loop = self.purr
	if not loop then return end
	loop.active, loop.epoch = false, (loop.epoch or 0) + 1
	if loop.tween then loop.tween:Cancel(); loop.tween = nil end
	loop.voice.Volume = 0
	loop.voice:Stop()
end

function Audio:duck(name, duration, gain)
	if not self.music or self.destroyed then return end
	self.duckEpochs = self.duckEpochs or {}
	local epoch = (self.duckEpochs[name] or 0) + 1
	self.duckEpochs[name], self.ducks[name] = epoch, gain
	self:refreshLoops()
	local schedule = self.schedule or task.delay
	schedule(duration, function()
		if self.destroyed or self.duckEpochs[name] ~= epoch then return end
		self.ducks[name] = nil
		self:refreshLoops()
	end)
end

function Audio:play(name, speed, volume, owner)
	local voices = self.voices[name]
	if self.destroyed or not voices or self.group.Volume == 0 or self.deviceActive==false then
		return false
	end
	local index = (self.indices[name] or 0) % #voices + 1
	local voice = voices[index]
	if not voice or voice.IsLoaded==false then return false end
	if name == "hatch_rise" then self:duck("hatch", 1.2, 0.22)
	elseif name == "hatch" then self:duck("hatch", 0.9, 0.22) end
	self.indices[name] = index
	voice.PlaybackSpeed = speed or 1
	voice.Volume = volume or 0.72
	voice.TimePosition = 0
	if owner~=nil then
		self.voiceOwners=self.voiceOwners or {};self.voiceOwners[voice]=owner
	elseif self.voiceOwners then self.voiceOwners[voice]=nil end
	voice:Play()
	return true
end

-- Fade one cue's playing voices out (boot skip: 60 ms). Safe with no voices.
function Audio:fadeCue(name, seconds)
	local voices = self.voices[name]
	if self.destroyed or not voices then return false end
	for _, voice in ipairs(voices) do
		if voice.IsPlaying then
			local tween = TweenService:Create(voice, TweenInfo.new(seconds or 0.06), { Volume = 0 })
			tween.Completed:Connect(function() voice:Stop() end)
			tween:Play()
		end
	end
	return true
end

-- Ownership is attached to an existing pooled voice, never to a new Sound.
-- A later ordinary or owned play replaces the tag before starting that voice.
function Audio:stopOwner(owner)
	local stopped=0
	for voice,token in pairs(self.voiceOwners or {})do
		if token==owner then voice:Stop();self.voiceOwners[voice]=nil;stopped+=1 end
	end
	return stopped
end

function Audio:stopField()
	if self.destroyed then return end
	for _,name in ipairs(fieldCues)do
		for _,voice in ipairs(self.voices[name]or {})do voice:Stop()end
	end
end
function Audio:petSpeechBusy(exceptOwner)
 for _,name in ipairs({"pet","puddle","wick","orbit","hatch","hatch_rise"})do
  for _,voice in ipairs(self.voices[name]or {})do
   if voice.IsPlaying and(not self.voiceOwners or self.voiceOwners[voice]~=exceptOwner)then return true end
  end
 end
 return false
end

-- Only the accepted action owner calls this. The same token may cross widgets,
-- but never hover/layout/server-ack handlers. Muted actions are consumed too.
function Audio:ui(kind,token)
	if self.destroyed then return false end
	local variants={confirm={1.06,.65},tab={1.12,.52},back={.84,.35}}
	local variant=variants[kind]
	local validToken=(type(token)=="string"and #token>0 and #token<=128)
		or(type(token)=="number"and token==token and token%1==0 and token>=0 and token<math.huge)
	if not variant or not validToken then return false end
	self.uiTokens,self.uiRing=self.uiTokens or {},self.uiRing or {}
	if self.uiTokens[token]then return false end
	self.uiCursor=(self.uiCursor or 0)%64+1
	local old=self.uiRing[self.uiCursor];if old~=nil then self.uiTokens[old]=nil end
	self.uiRing[self.uiCursor],self.uiTokens[token]=token,true
	if self.deviceActive==false or self.group.Volume==0 or not self.voices.menu then return false end
	-- Drop unavailable cues now; never replay them when preload later finishes.
	if self.voices.menu[1].IsLoaded==false then return false end
	self:play("menu",variant[1],variant[2])
	return true
end

function Audio:mergePitch(chain,id)
	chain=if type(chain)=="number"and chain==chain and chain<math.huge then math.max(1,math.floor(chain))else 1
	id=if type(id)=="number"and id==id and math.abs(id)<math.huge then math.floor(id)else 0
	local semitones=if chain>=3 then 5 elseif chain==2 then 3 else 0
	return 2^(semitones/12)*(1+(id%5)*.0025)
end

function Audio:setVolume(volume)
	if self.destroyed then return end
	self.master = volume
	self.group.Volume = volume
	if volume == 0 then
		self:stop()
		self:silencePurr()
	end
	self:refreshLoops()
end

function Audio:cancelBoot()
	self.bootEpoch=(self.bootEpoch or 0)+1
	if self.bootVoice then self.bootVoice:Stop();self.bootVoice:Destroy();self.bootVoice=nil end
	if self.ducks then
		self.ducks.boot = nil
		if self.duckEpochs then self.duckEpochs.boot = (self.duckEpochs.boot or 0) + 1 end
		self:refreshLoops()
	end
end
function Audio:boot(owns)
	if self.destroyed or self.deviceActive==false then return end
	self:cancelBoot()
	local token=self.bootEpoch
	local source=self.voices.charge and self.voices.charge[1]
	if not source or source.IsLoaded==false or (owns and not owns()) then return end
	local voice=source:Clone()
	voice.Name,voice.Volume,voice.Parent="EggDrop_Boot",.20,SoundService
	self.bootVoice=voice
	self:duck("boot", 0.65, 0.22)
	local schedule=self.schedule or task.delay
	for index,pitch in ipairs({.88,1.10,1.32}) do
		schedule((index-1)*.09,function()
			if not self.destroyed and self.deviceActive~=false and voice.IsLoaded~=false
				and self.bootEpoch==token and self.group.Parent and (not owns or owns()) and self.group.Volume>0 then
				voice.PlaybackSpeed,voice.TimePosition=pitch,0
				voice:Play()
			end
		end)
	end
end
function Audio:stop()
	if self.destroyed then return end
	self:cancelBoot()
	self:setPurr(false)
	if self.ducks then
		self.ducks.hatch = nil
		if self.duckEpochs then self.duckEpochs.hatch = (self.duckEpochs.hatch or 0) + 1 end
		self:refreshLoops()
	end
	for _, voices in pairs(self.voices) do
		for _, voice in ipairs(voices) do
			voice:Stop()
		end
	end
	self.voiceOwners=nil
end

function Audio:destroy()
	if self.destroyed then return end
	self.destroyed = true
	self.voiceOwners=nil
	self.uiTokens,self.uiRing=nil,nil
	self:cancelBoot()
	for _, connection in ipairs(self.connections or {}) do connection:Disconnect() end
	for _, loop in ipairs({self.music, self.purr}) do
		if loop.tween then loop.tween:Cancel() end
		loop.voice:Stop(); loop.voice:Destroy(); loop.group:Destroy()
	end
	for _, voices in pairs(self.voices) do for _, voice in ipairs(voices) do voice:Stop(); voice:Destroy() end end
	self.group:Destroy()
end

return Audio
