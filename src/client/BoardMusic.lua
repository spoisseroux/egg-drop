local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Audio = require(script.Parent.BoardAudio)
local Music = {}
Music.__index = Music

function Music.new()
	local self = setmetatable({ tracks = {}, tweens = {}, duckId = 0 }, Music)
	local preload = {}
	for mode, cue in pairs({ Board = "music_board", Room = "music_room" }) do
		local uri = Audio.uri(cue)
		if uri then
			local track = Instance.new("Sound")
			track.Name = "EggDrop_" .. cue
			track.SoundId = uri
			track.Looped = true
			track.Volume = 0
			track.Parent = SoundService
			self.tracks[mode] = track
			table.insert(preload, track)
		end
	end
	if #preload > 0 then
		task.spawn(function()
			ContentProvider:PreloadAsync(preload)
			for _, track in ipairs(preload) do
				track:Play()
			end
		end)
	end
	return self
end

function Music:mix(duration)
	for mode, track in pairs(self.tracks) do
		if self.tweens[mode] then
			self.tweens[mode]:Cancel()
		end
		local volume = if not self.muted and self.mode == mode then 0.25 else 0
		if self.ducked or self.over then
			volume *= 0.32
		end
		local tween = TweenService:Create(track, TweenInfo.new(duration), { Volume = volume })
		self.tweens[mode] = tween
		tween:Play()
	end
end

function Music:setState(mode, over)
	if self.mode == mode and self.over == over then
		return
	end
	self.mode, self.over = mode, over
	self:mix(1.15)
end

function Music:toggle()
	self.muted = not self.muted
	self:mix(0.3)
	return self.muted
end

function Music:duck()
	self.duckId += 1
	local duckId = self.duckId
	self.ducked = true
	self:mix(0.15)
	task.delay(0.78, function()
		if self.duckId == duckId then
			self.ducked = false
			self:mix(0.68)
		end
	end)
end

return Music
