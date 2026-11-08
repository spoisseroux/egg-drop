-- Presentation only. This clock never writes a reward or a wallet balance.
-- A receipt is eligible once, after the caller has selected the current Saved run.
local Feedback = {}
Feedback.__index = Feedback
Feedback.Duration = 1.1

local function ramp(age, start, duration)
	return math.clamp((age - start) / duration, 0, 1)
end

function Feedback.sample(age)
	age=math.max(0,age)
	return {
		stats = { ramp(age, 0, .38), ramp(age, .17, .32), ramp(age, .34, .30) },
		-- Currency is already committed. Only the decoration has a progress lane.
		earned = 1,
		transfer = ramp(age, .45, .43),
		pop=if age<.18 then math.sin(math.pi*age/.18)else 0,
		sources=ramp(age,.18,.10)*(1-ramp(age,.35,.10)),
		settle=ramp(age,.88,.22),age=age,
	}
end

function Feedback.new(render, audio, reduceEffects, owns)
	return setmetatable({ render = render, audio = audio, reduceEffects = reduceEffects,
		owns=owns,seen = {}, serial = 0, starts = 0 }, Feedback)
end

function Feedback:reduced()
	return if type(self.reduceEffects) == "function" then self.reduceEffects() == true else self.reduceEffects == true
end

function Feedback:cancel()
	self.serial += 1
	self.active, self.age = false, nil
	if self.connection then self.connection:Disconnect(); self.connection = nil end
	if self.audio and self.audio.stopOwner then self.audio:stopOwner(self)end
	self.render(nil)
end

function Feedback:cue(name, pitch, volume)
	-- BoardAudio owns the SoundGroup and suppresses playback while muted.
	if self.audio and self.audio.deviceActive~=false and(not self.owns or self.owns())then self.audio:play(name, pitch, volume,self)end
end

function Feedback:step(dt)
	if not self.active then return end
	if self:reduced()or(self.owns and not self.owns())or(self.audio and(self.audio.deviceActive==false or self.deviceEpoch~=(self.audio.deviceEpoch or 0)))then self:cancel();return end
	-- Resume on final values, including voices. Missed decorative beats never queue.
	if dt>.25 or dt~=dt then self:cancel();return end
	local before = self.age
	self.age += math.max(0, dt)
	for index,threshold in ipairs({.18,.32})do
		if before<threshold and self.age>=threshold then self:cue("bank",1+(index-1)*.18,.18)end
	end
	for index=1,self.chips do
		local threshold=.45+(index-1)*.08
		if before<threshold and self.age>=threshold then self:cue("charge",1+index*.065,.14)end
	end
	if before<.88 and self.age>=.88 then self:cue("bank",1.36,.14)end
	if self.age >= Feedback.Duration then self:cancel() else self.render(Feedback.sample(self.age)) end
end

function Feedback:observe(result, visible)
	local reward = result.reward
	local eligible = result.status == "Saved" and not result.receiptPending and type(reward) == "table"
		and type(result.sequence) == "number" and reward.sequence == result.sequence
	local key = if eligible then result.sequence else nil
	if key ~= self.key then self:cancel(); self.key = key end
	if not visible or not eligible or(self.owns and not self.owns())then
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
	if self:reduced()or(self.audio and self.audio.deviceActive==false)then self.render(nil);return false end
	self.earned=math.max(0,reward.total or 0)
	self.chips=math.min(5,math.floor(self.earned))
	if self.earned==0 then
		local serial=self.serial;self.render(nil)
		if self.serial==serial and self.key==key then self:cue("bank",.92,.12)end
		return false
	end
	self.active, self.age, self.starts = true, 0, self.starts + 1
	self.deviceEpoch=if self.audio then self.audio.deviceEpoch or 0 else 0
	local serial = self.serial
	self.render(Feedback.sample(0))
	if self.serial~=serial or not self.active then return false end
	self.connection = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if serial == self.serial then self:step(dt) end
	end)
	return true
end

return Feedback
