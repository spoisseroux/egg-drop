-- Presentation only. This clock never writes a reward or a wallet balance.
-- A receipt is eligible once, after the caller has selected the current Saved run.
local Feedback = {}
Feedback.__index = Feedback
Feedback.Duration = 1.48

local function ramp(age, start, duration)
	return math.clamp((age - start) / duration, 0, 1)
end

function Feedback.sample(age)
	return {
		stats = { ramp(age, 0, .38), ramp(age, .17, .32), ramp(age, .34, .30) },
		earned = ramp(age, .58, .42),
		transfer = ramp(age, .76, .66),
	}
end

function Feedback.new(render, audio, reduceEffects)
	return setmetatable({ render = render, audio = audio, reduceEffects = reduceEffects,
		seen = {}, serial = 0, starts = 0 }, Feedback)
end

function Feedback:reduced()
	return if type(self.reduceEffects) == "function" then self.reduceEffects() == true else self.reduceEffects == true
end

function Feedback:cancel()
	self.serial += 1
	self.active, self.age = false, nil
	if self.connection then self.connection:Disconnect(); self.connection = nil end
	self.render(nil)
end

function Feedback:cue(name, pitch, volume)
	-- BoardAudio owns the SoundGroup and suppresses playback while muted.
	if self.audio then self.audio:play(name, pitch, volume) end
end

function Feedback:step(dt)
	if not self.active then return end
	if self:reduced() then self:cancel(); return end
	local before = self.age
	self.age += math.max(0, dt)
	-- A resumed/backgrounded frame lands on final values without dumping all
	-- missed cues into one loud burst.
	if dt <= .25 then
		for index, threshold in ipairs({ .38, .49, .64 }) do
			if before < threshold and self.age >= threshold then self:cue("bank", 1 + index * .12, .22) end
		end
		if self.earned > 0 then
			for index = 1, self.chips do
				local threshold = 1.16 + (index - 1) * .048
				if before < threshold and self.age >= threshold then self:cue("charge", 1 + index * .065, .26) end
			end
		end
	end
	if self.age >= Feedback.Duration then self:cancel() else self.render(Feedback.sample(self.age)) end
end

function Feedback:observe(result, visible)
	local reward = result.reward
	local eligible = result.status == "Saved" and not result.receiptPending and type(reward) == "table"
		and type(result.sequence) == "number" and reward.sequence == result.sequence
	local key = if eligible then result.sequence else nil
	if key ~= self.key then self:cancel(); self.key = key end
	if not visible or not eligible then
		if self.active then self:cancel() end
		return false
	end
	if self.seen[key] then return false end
	self.seen[key] = true
	-- Keep a bounded history while retaining normal close/reopen suppression.
	if self.lastKey and key > self.lastKey then
		for old in pairs(self.seen) do if old < key - 32 then self.seen[old] = nil end end
	end
	self.lastKey = key
	if self:reduced() then self.render(nil); return false end
	self.earned, self.chips = math.max(0, reward.total or 0), math.min(6, math.max(0, reward.total or 0))
	self.active, self.age, self.starts = true, 0, self.starts + 1
	self.render(Feedback.sample(0))
	self:cue("merge_chain", 1.16, .30)
	local serial = self.serial
	self.connection = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if serial == self.serial then self:step(dt) end
	end)
	return true
end

return Feedback
