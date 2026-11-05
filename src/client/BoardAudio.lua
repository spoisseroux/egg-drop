local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Audio = {}
Audio.__index = Audio

-- Only IDs for the original WAVs in assets/audio belong here.
local assetIds = {}
local cues = {
	"aim", "drop", "land", "bank", "merge_bubble", "merge_jelly", "merge_chain",
	"charge", "hatch_rise", "hatch", "pet", "puddle", "wick", "orbit", "overflow", "retry", "menu",
}

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
	group.Parent = SoundService
	local self = setmetatable({ voices = {}, indices = {}, group = group }, Audio)
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
		else
			table.insert(missing, cue)
		end
	end
	if #missing > 0 then
		warn("Egg Drop has no audio asset IDs for " .. table.concat(missing, ", "))
	end
	if #warmup > 0 then
		task.spawn(function()
			local failed = {}
			ContentProvider:PreloadAsync(warmup, function(id, status)
				if status ~= Enum.AssetFetchStatus.Success then
					table.insert(failed, id)
				end
			end)
			if #failed > 0 then
				warn("Egg Drop could not load audio " .. table.concat(failed, ", "))
			end
		end)
	end
	return self
end

function Audio:play(name, speed, volume)
	local voices = self.voices[name]
	if not voices or self.group.Volume == 0 then
		return
	end
	local index = (self.indices[name] or 0) % #voices + 1
	self.indices[name] = index
	local voice = voices[index]
	voice.PlaybackSpeed = speed or 1
	voice.Volume = volume or 0.72
	voice.TimePosition = 0
	voice:Play()
end

function Audio:setVolume(volume)
	self.group.Volume = volume
	if volume == 0 then
		self:stop()
	end
end

function Audio:stop()
	for _, voices in pairs(self.voices) do
		for _, voice in ipairs(voices) do
			voice:Stop()
		end
	end
end

return Audio
