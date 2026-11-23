-- First-session onboarding funnel (slice A, 2026-11-14; plan artifacts/slice-a-2026-11-14/PLAN.md).
-- Funnel fix (FIRST-SESSION-FUNNEL-PLAN-2026-11-23, revision): step N logs only once step N-1 has
-- logged for this player (Roblox counts a later step as completing the earlier ones, which hid
-- real drop-off); a step that comes early is sent once as the custom event
-- "FunnelOutOfOrder_<StepKey>" instead and can still log later, when it happens again in order.
-- Live servers only, brand-new saves only (profile.newSave: Progress.load found no record, and
-- rank 0), behind FeatureFlags.FirstSessionFunnel. The object lives for the whole session, so a
-- save reload keeps it (init.server keeps the existing one). Every Roblox call is deferred and
-- pcall'd; nothing here yields or throws into join, round, hatch, care or save code.
--
-- Onboarding v3 (ONBOARDING-V3-PLAN-2026-11-23 section 5, slice F): while all three v3 parts are on (Onboard.on follow,
-- needs and nest) the session uses the 11-step table V3Steps instead, strictly linear with hold-and-flush: a step that
-- comes early is held (and sent once at once as the custom event "Early_<StepKey>") and logged, in order, as soon as the
-- gap before it closes. The table is chosen once per session at the first hook after Board ready (step 1 is the same
-- in both), so a mid-session flip never mixes them. Call sites name hooks (hit), not numbers; each table maps them.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local FeatureFlags = require(Shared.FeatureFlags)
local Onboard = require(Shared.Onboard)

local FirstSession = {}
FirstSession.__index = FirstSession

-- Step numbers are the funnel's identity on the dashboard: never renumber, only append.
FirstSession.Steps = table.freeze({
	BoardReady = 1,
	FirstDrop = 2,
	FirstMerge = 3,
	BearMet = 4,
	GardenWalkthrough = 5,
	FirstMachine = 6,
	FirstQuest = 7,
	FirstSpend = 8,
	SecondRound = 9,
})
FirstSession.StepNames = table.freeze({
	"Board ready", "First drop", "First merge", "Bear met", "Garden walkthrough done",
	"First machine opened", "First quest claimed", "First Stars spend", "Second round started",
})
local stepKeys = {}
for key, step in pairs(FirstSession.Steps) do stepKeys[step] = key end
FirstSession.StepKeys = table.freeze(stepKeys)
-- Custom events (once per session object): first accepted petting or care, first accepted
-- hatch, five minutes of session time.
FirstSession.FiveMinutes = 300
FirstSession.TenMinutes = 600

-- Onboarding v3: the 11 steps (a new funnel, from the date v3 goes live; never renumber, only append).
FirstSession.V3Steps = table.freeze({
	BoardReady = 1,
	FirstMerge = 2,
	BearMet = 3,
	InGarden = 4,
	FirstPet = 5,
	FollowedBearToMachine = 6,
	ToyGiven = 7,
	NestTucked = 8,
	SecondRoundDone = 9,
	FiveMinutes = 10,
	TenMinutes = 11,
})
FirstSession.V3StepNames = table.freeze({
	"Board ready", "First merge", "Bear met", "In the garden", "First pet", "Followed the Bear to the machine",
	"Toy given", "Nest tucked", "Second round done", "Five minutes", "Ten minutes",
})
local v3Keys = {}
for key, step in pairs(FirstSession.V3Steps) do v3Keys[step] = key end
FirstSession.V3StepKeys = table.freeze(v3Keys)
-- Hooks (hit) that are not a v3 step become a custom event of the same name, once (the plan: First drop is one).
FirstSession.V3Events = table.freeze({ FirstDrop = true, GardenWalkthrough = true, FirstMachine = true, FirstQuest = true,
	FirstSpend = true, SecondRound = true })
-- Is Onboarding v3 on for this session? All three parts (the 11 steps need the Bear, the needs and the nest).
function FirstSession.v3On()
	return Onboard.on("follow") and Onboard.on("needs") and Onboard.on("nest")
end

-- options (specs): {force = true} skips the live-server gate; {log = fn(player, kind, ...)}
-- replaces AnalyticsService (kind is "step" or "event"); {analytics = service} is a stand-in
-- AnalyticsService; {defer = fn, delay = fn} replace task.defer / task.delay; {flags = table}
-- replaces FeatureFlags; {players = service} is the Players the player must still be in;
-- {v3 = true|false} picks the table (default: FirstSession.v3On() at the first hook after Board ready).
function FirstSession.new(player, profile, options)
	options = options or {}
	local flags = options.flags or FeatureFlags
	if flags.FirstSessionFunnel ~= true then
		return nil
	end
	if not options.force and (RunService:IsStudio() or game.GameId == 0) then
		return nil
	end
	if type(profile) ~= "table" or profile.loadFailed or profile.newSave ~= true or (profile.rank or 0) > 0 then
		return nil
	end
	local self = setmetatable({
		player = player, logged = {}, milestones = {}, rounds = 0, sink = options.log,
		analytics = options.analytics or AnalyticsService, players = options.players or Players,
		defer = options.defer or task.defer, held = {}, forced = options.v3,
	}, FirstSession)
	local delay = options.delay or task.delay
	local ok, problem = pcall(delay, FirstSession.FiveMinutes, function()
		self:record("FiveMinutes")
		-- v3 only: the ten-minute step, five minutes later (one timer at a time; none for the old table).
		if self:isV3() then
			local scheduled, failure = pcall(delay, FirstSession.TenMinutes - FirstSession.FiveMinutes, function()
				self:record("TenMinutes")
			end)
			if not scheduled then warn("Egg Drop could not schedule the first-session timer:", failure) end
		end
	end)
	if not ok then
		warn("Egg Drop could not schedule the first-session timer:", problem)
	end
	return self
end

-- Fire and forget: the sink (specs) or a deferred, pcall'd AnalyticsService call. Never throws.
function FirstSession:emit(kind, ...)
	local ok, problem = pcall(function(...)
		if self.sink then
			self.sink(self.player, kind, ...)
			return
		end
		local method = if kind == "step" then "LogOnboardingFunnelStepEvent" else "LogCustomEvent"
		self.defer(function(...)
			if self.player.Parent ~= self.players then
				return
			end
			local logged, failure = pcall(function(...)
				self.analytics[method](self.analytics, self.player, ...)
			end, ...)
			if not logged then
				warn("Egg Drop could not log a first-session milestone:", failure)
			end
		end, ...)
	end, ...)
	if not ok then
		warn("Egg Drop could not log a first-session milestone:", problem)
	end
end

-- The table for this session, fixed at the first call (see the header). True: the v3 table.
function FirstSession:isV3()
	if self.v3 == nil then
		if self.forced ~= nil then
			self.v3 = self.forced == true
		else
			local ok, on = pcall(FirstSession.v3On)
			self.v3 = ok and on == true
		end
	end
	return self.v3
end

-- v3: step N logs only after N-1; an early step is held (and sent once as Early_<StepKey>) and flushed in order
-- when the gap closes.
function FirstSession:advanceV3(step)
	local name = FirstSession.V3StepNames[step]
	if not name or self.logged[step] then
		return false
	end
	if step > 1 and not self.logged[step - 1] then
		if not self.held[step] then
			self.held[step] = true
			self:record("Early_" .. FirstSession.V3StepKeys[step])
		end
		return false
	end
	repeat
		self.held[step] = nil
		self.logged[step] = true
		self:emit("step", step, FirstSession.V3StepNames[step])
		step += 1
	until not self.held[step]
	return true
end

-- A named hook from the game (the call sites). `detail` (FirstMachine): the coach id, since v3 step 6 is the Hatch
-- eggs station only. Old table: the hook's step, exactly as before. v3: its step, or a custom event for the hooks that
-- are not one. Board ready is step 1 in both, so it logs without choosing the table.
function FirstSession:hit(hook, detail)
	if hook == "BoardReady" then return self:advance(1) end
	if not self:isV3() then
		local step = FirstSession.Steps[hook]
		return if step then self:advanceOld(step) else false
	end
	if hook == "FirstMachine" then
		if detail == "hatch" then return self:advanceV3(FirstSession.V3Steps.FollowedBearToMachine) end
		self:record("FirstMachine")
		return false
	end
	local step = FirstSession.V3Steps[hook]
	if step then return self:advanceV3(step) end
	if FirstSession.V3Events[hook] then self:record(hook) end
	return false
end

-- By number, in the session's table (older call sites and the specs).
function FirstSession:advance(step)
	if step == 1 and self.v3 == nil then return self:advanceOld(1) end
	if self:isV3() then return self:advanceV3(step) end
	return self:advanceOld(step)
end

function FirstSession:advanceOld(step)
	local name = FirstSession.StepNames[step]
	if not name or self.logged[step] then
		return false
	end
	if step > 1 and not self.logged[step - 1] then
		self:record("FunnelOutOfOrder_" .. FirstSession.StepKeys[step])
		return false
	end
	self.logged[step] = true
	self:emit("step", step, name)
	return true
end

-- A round began on the board. The Welcome round ends with the Bear, so the first round
-- started after step 4 is the player's second round (step 9; it logs once step 8 has).
function FirstSession:roundStarted()
	if self:isV3() then
		-- v3: a round started after the Bear was met; its settle is step 9 (roundSettled).
		if self.logged[FirstSession.V3Steps.BearMet] then self.roundAfterBear = true end
		return
	end
	if not self.logged[FirstSession.Steps.BearMet] then
		return
	end
	self.rounds += 1
	if self.rounds >= 1 then
		self:advance(FirstSession.Steps.SecondRound)
	end
end

-- A round's reward began to settle. v3 only: the first one started after the Bear is SecondRoundDone.
function FirstSession:roundSettled()
	if self:isV3() and self.roundAfterBear then
		self:advanceV3(FirstSession.V3Steps.SecondRoundDone)
	end
end

-- A one-time custom event. In v3, FirstPet, FiveMinutes and TenMinutes are steps too (held until their turn).
function FirstSession:record(name)
	if not self.milestones[name] then
		self.milestones[name] = true
		self:emit("event", name, 1)
	end
	if (name == "FirstPet" or name == "FiveMinutes" or name == "TenMinutes") and self:isV3() then
		self:advanceV3(FirstSession.V3Steps[name])
	end
end

return FirstSession
