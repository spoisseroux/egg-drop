-- Presentation only. This clock never writes a reward or a wallet balance.
-- A receipt is eligible once, after the caller has selected the current Saved run.
-- Celebrations redesign (UI-SPEC-REDESIGN-CELEBRATIONS 2.7): the sample gains the
-- entrance (headline slam, goal stamps, row flips, Star drop), the per-Star pop and
-- the finale (spin, rays, confetti, NEW BEST, come-back strip). The count rule is
-- unchanged: at most 80 ms a Star, every Star counted within 900 ms.
local Feedback = {}
Feedback.__index = Feedback
-- DECK-FEEL-BRIEF 8 (Alive deckfeel): DeckResults hands the clock DeckFeel.recapSpec() (setFeel): the Star lands at .6,
-- the count runs .6 to 1.5 with its pitch rising 1.0 to 1.5, the finale at 1.5, no early bank chips. nil = as before.
local Feel = require(script.Parent.DeckFeel)
Feedback.Duration = 1.1

local function ramp(age, start, duration)
	return math.clamp((age - start) / duration, 0, 1)
end
Feedback.ramp = ramp

-- Stars tick in from 0.6 s (after the Star lands), at most 0.08 s apart and
-- finishing within 0.9 s.
Feedback.CountStart,Feedback.CountSpan,Feedback.CountStep=.6,.9,.08
Feedback.DropAt,Feedback.FinaleDelay,Feedback.FinaleSpan=.45,.08,.5
Feedback.GoalAt,Feedback.GoalGap,Feedback.RowAt,Feedback.RowGap=.15,.09,.30,.12
Feedback.PopSpan,Feedback.FlightSpan=.09,.18
Feedback.BlipCue="count_blip"

-- Count spacing and the last tick for `earned` Stars.
function Feedback.spacingFor(earned)
	earned=math.max(1,earned or 1)
	return math.min(Feedback.CountStep,Feedback.CountSpan/earned)
end
function Feedback.countEndFor(earned)
	earned=math.max(1,earned or 1)
	return Feedback.CountStart+(earned-1)*Feedback.spacingFor(earned)
end
function Feedback.finaleAt(countEnd)return(countEnd or Feedback.CountStart)+Feedback.FinaleDelay end
-- Whole clock for `earned` Stars: finale plus its 500 ms.
function Feedback.durationFor(earned)
	return math.max(Feedback.Duration,Feedback.finaleAt(Feedback.countEndFor(earned))+Feedback.FinaleSpan)
end
-- Per-Star pop: 1 on the tick, back to 0 within 90 ms.
function Feedback.popAt(age,counted,spacing)
	if not counted or counted<1 then return 0 end
	local tick=Feedback.CountStart+(counted-1)*(spacing or Feedback.CountStep)
	return 1-math.clamp((age-tick)/Feedback.PopSpan,0,1)
end
-- Stamp lane for item `index` of a staggered group (goals, rows).
function Feedback.stagger(age,index,start,gap,duration)
	return ramp(age,start+(index-1)*gap,duration)
end

function Feedback.sample(age,countEnd,finaleAt)
	age=math.max(0,age)
	countEnd=countEnd or Feedback.CountStart
	local finale=finaleAt or Feedback.finaleAt(countEnd)
	return {
		stats = { ramp(age, 0, .38), ramp(age, .17, .32), ramp(age, .34, .30) },
		-- Currency is already committed. Only the decoration has a progress lane.
		earned = 1,
		transfer = ramp(age, .45, .43),
		pop=if age<.18 then math.sin(math.pi*age/.18)else 0,
		sources=ramp(age,.18,.10)*(1-ramp(age,.35,.10)),
		settle=ramp(age,.88,.22),age=age,
		-- Celebration lanes (2.7).
		entrance=ramp(age,0,.22),
		drop=ramp(age,Feedback.DropAt,.30),
		finaleAt=finale,
		finale=ramp(age,finale,Feedback.FinaleSpan),
		best=ramp(age,finale+.2,.16),
		strip=ramp(age,finale+.3,.2),
		hints=age>=finale+Feedback.FinaleSpan,
	}
end

function Feedback.new(render, audio, reduceEffects, owns)
	return setmetatable({ render = render, audio = audio, reduceEffects = reduceEffects,
		owns=owns,seen = {}, serial = 0, starts = 0, beats = {} }, Feedback)
end

-- Extra cues the view schedules for one result: {at, cue, pitch, volume,
-- finale=true for an offset from the finale}. Set before observe().
function Feedback:setCountWindow(start,span)
 self.countStart=start;self.countSpan=span
end
function Feedback:setBeats(beats)
	self.beats=beats or {}
end
function Feedback:setFeel(spec)
	self.feelSpec=spec
end
function Feedback:finale()
	return if self.feelSpec then self.feelSpec.finaleAt else Feedback.finaleAt(self.countEnd)
end

function Feedback:reduced()
	return if type(self.reduceEffects) == "function" then self.reduceEffects() == true else self.reduceEffects == true
end

-- `finished` (the clock ran out on its own): the finale's voices (stars_total, the
-- new best / egg ready beats) play to their natural end. Any other cancel (skip,
-- Replay, the results closing or changing) fades them over Feedback.TailFade
-- instead of cutting them (QA 2026-11-13: the final flourish was cut off).
Feedback.TailFade=.35
-- Voices are only cued while active, so an idle cancel (a new result key arriving after
-- the last count-up already released or faded) leaves the audio alone.
function Feedback:cancel(finished)
	local wasActive=self.active
	self.serial += 1
	self.active, self.age = false, nil
	if self.connection then self.connection:Disconnect(); self.connection = nil end
	local audio=self.audio
	if audio and wasActive then
		if finished==true then
			if audio.releaseOwner then audio:releaseOwner(self)end
		elseif audio.fadeOwner then audio:fadeOwner(self,Feedback.TailFade)
		elseif audio.stopOwner then audio:stopOwner(self)end
	end
	self.render(nil)
end

function Feedback:cue(name, pitch, volume)
	-- BoardAudio owns the SoundGroup and suppresses playback while muted.
	if self.audio and self.audio.deviceActive~=false and(not self.owns or self.owns())then return self.audio:play(name, pitch, volume,self)==true end
	return false
end

function Feedback:step(dt)
	if not self.active then return end
	if self:reduced()or(self.owns and not self.owns())or(self.audio and(self.audio.deviceActive==false or self.deviceEpoch~=(self.audio.deviceEpoch or 0)))then self:cancel();return end
	-- Resume on final values, including voices. Missed decorative beats never queue.
	if dt>.25 or dt~=dt then self:cancel();return end
	local before = self.age
	self.age += math.max(0, dt)
	local spec=self.feelSpec
	if not(spec and spec.banks==false)then
		for index,threshold in ipairs({.18,.32})do
			if before<threshold and self.age>=threshold then self:cue("bank",1+(index-1)*.18,.18)end
		end
	end
	local dropAt=if spec then spec.dropAt else Feedback.DropAt
	if before<dropAt and self.age>=dropAt then self:cue("star_land",1,.4)end
	-- Star count-up (batch 2026-11-13): a very short `count_blip` per +1, like rings
	-- counting up. The cue has one voice, so each blip is cut by the next. Several
	-- Stars crossing in one frame share a single blip so voices never stack. Until the
	-- blip's sound is uploaded, the old charge tick stands in.
	local counted=self:countAt(self.age)
	if counted>self.counted then
		self.counted=counted
		local pitch=if spec then Feel.blipPitch(counted,self.earned)else math.min(1.6,1+counted*.02)
		if not self:cue(Feedback.BlipCue,pitch,.22)then self:cue("charge",math.min(2,1+counted*.03),.14)end
	end
	local finale=self:finale()
	if before<finale and self.age>=finale then self:cue("bank",1.36,.14);self:cue("stars_total",1,.5)end
	for _,beat in ipairs(self.beats)do
		local at=beat.at+(if beat.finale then finale else 0)
		if before<at and self.age>=at then self:cue(beat.cue,beat.pitch or 1,beat.volume or .3)end
	end
	if self.age >= self.duration then self:cancel(true) else self:paint(self.age) end
end

function Feedback:countAt(age)
	local start=self.countStart or Feedback.CountStart
	if age<start then return 0 end
	return math.min(self.earned,1+math.floor((age-start)/self.spacing+1e-6))
end
function Feedback:paint(age)
	local sample=Feedback.sample(age,self.countEnd,if self.feelSpec then self.feelSpec.finaleAt else nil);sample.counted=self.counted
	sample.spacing=self.spacing;sample.total=self.earned
	sample.starPop=Feedback.popAt(age,self.counted,self.spacing)
	self.render(sample)
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
	self.spacing=math.min(Feedback.CountStep,(self.countSpan or Feedback.CountSpan)/math.max(1,self.earned))
	self.countEnd=(self.countStart or Feedback.CountStart)+(math.max(1,self.earned)-1)*self.spacing
	self.duration=Feedback.durationFor(self.earned)
	if self.feelSpec then
		-- The count spreads over its whole window (a quarter second a Star at most) and the clock runs past the finale.
		self.spacing=math.min(.25,(self.countSpan or Feedback.CountSpan)/math.max(1,self.earned-1))
		self.countEnd=(self.countStart or Feedback.CountStart)+(math.max(1,self.earned)-1)*self.spacing
		self.duration=math.max(self.duration,self.feelSpec.finaleAt+Feedback.FinaleSpan)
	end
	self.counted=0
	self.active, self.age, self.starts = true, 0, self.starts + 1
	self.deviceEpoch=if self.audio then self.audio.deviceEpoch or 0 else 0
	local serial = self.serial
	self:paint(0)
	if self.serial~=serial or not self.active then return false end
	self.connection = game:GetService("RunService").RenderStepped:Connect(function(dt)
		if serial == self.serial then self:step(dt) end
	end)
	return true
end

return Feedback
