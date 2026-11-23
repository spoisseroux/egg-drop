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
-- gap before it closes. The table is chosen once per session, after Board ready (step 1 is the same in both) and once
-- the onboarding config has loaded, so a mid-session flip never mixes them. Call sites name hooks (hit), not numbers; each table maps them.
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
-- Is Onboarding v3 on for this player's session? All three parts (the 11 steps need the Bear, the needs and the nest).
-- The follow part is the per-session capture the tour uses (Onboard.sessionFollow), so the funnel and the tour agree.
function FirstSession.v3On(player)
	return Onboard.sessionFollow(player) and Onboard.on("needs") and Onboard.on("nest")
end
-- The choice waits for the onboarding config to have loaded once (or an owner override), checking every ConfigRetry
-- seconds; after ConfigWait it is made from what the switches say then. Hooks that come meanwhile are held and
-- replayed in order once it is made. With the v3 build ceiling off there is nothing to wait for (the old table).
FirstSession.ConfigRetry = 2
FirstSession.ConfigWait = 60
local function configReady()
	if not Onboard.ceiling() then return true end
	return require(script.Parent.OnboardConfig).loaded()
end

-- options (specs): {force = true} skips the live-server gate; {log = fn(player, kind, ...)}
-- replaces AnalyticsService (kind is "step" or "event"); {analytics = service} is a stand-in
-- AnalyticsService; {defer = fn, delay = fn} replace task.defer / task.delay; {flags = table}
-- replaces FeatureFlags; {players = service} is the Players the player must still be in;
-- {v3 = true|false} picks the table; {ready = fn} replaces the config-loaded check.
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
		defer = options.defer or task.defer, held = {}, forced = options.v3, waiting = {},
		ready = options.ready or configReady, delay = options.delay or task.delay,
	}, FirstSession)
	local ok, problem = pcall(self.delay, FirstSession.FiveMinutes, function()
		self:record("FiveMinutes")
		if not self:queue("afterFive") then self:afterFive() end
	end)
	if not ok then
		warn("Egg Drop could not schedule the first-session timer:", problem)
	end
	return self
end
-- v3 only: the ten-minute step, five minutes after the five (one timer at a time; none for the old table).
function FirstSession:afterFive()
	if not self.v3 then return end
	local ok, problem = pcall(self.delay, FirstSession.TenMinutes - FirstSession.FiveMinutes, function()
		self:record("TenMinutes")
	end)
	if not ok then warn("Egg Drop could not schedule the first-session timer:", problem) end
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

-- Choose the table once (see the header). True when it is chosen.
function FirstSession:decide()
	if self.v3 ~= nil then return true end
	if self.forced ~= nil then
		self.v3 = self.forced == true
		return true
	end
	local okReady, ready = pcall(self.ready)
	if not (okReady and ready == true) and not self.waitedOut then return false end
	local ok, on = pcall(FirstSession.v3On, self.player)
	self.v3 = ok and on == true
	return true
end
function FirstSession:isV3()
	self:decide()
	return self.v3 == true
end
-- Before the choice: hold the call (method name and arguments) and answer true; after it: replay what was held, in
-- order, and answer false (the caller goes on).
function FirstSession:queue(method, ...)
	if self:decide() then
		self:replay()
		return false
	end
	table.insert(self.waiting, table.pack(method, ...))
	if not self.rechecking then
		self.rechecking = true
		self:recheck(0)
	end
	return true
end
function FirstSession:recheck(waited)
	local ok, problem = pcall(self.delay, FirstSession.ConfigRetry, function()
		waited += FirstSession.ConfigRetry
		if waited >= FirstSession.ConfigWait then self.waitedOut = true end
		if self:decide() then
			self.rechecking = false
			self:replay()
		else
			self:recheck(waited)
		end
	end)
	if not ok then
		warn("Egg Drop could not schedule the first-session timer:", problem)
		self.waitedOut, self.rechecking = true, false
		if self:decide() then self:replay() end
	end
end
function FirstSession:replay()
	if self.replaying then return end
	self.replaying = true
	while #self.waiting > 0 do
		local call = table.remove(self.waiting, 1)
		local ok, problem = pcall(self[call[1]], self, table.unpack(call, 2, call.n))
		if not ok then warn("Egg Drop first-session replay:", problem) end
	end
	self.replaying = false
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
	if self:queue("hit", hook, detail) then return false end
	if not self.v3 then
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
	if self:queue("advance", step) then return false end
	if self.v3 then return self:advanceV3(step) end
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
	if self:queue("roundStarted") then return end
	if self.v3 then
		-- v3: a round started after the Bear was met (the custom event SecondRound); its settle is step 9.
		if self.logged[FirstSession.V3Steps.BearMet] then
			self.roundAfterBear = true
			self:record("SecondRound")
		end
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
	if self:queue("roundSettled") then return end
	if self.v3 and self.roundAfterBear then
		self:advanceV3(FirstSession.V3Steps.SecondRoundDone)
	end
end

-- A one-time custom event. In v3, FirstPet, FiveMinutes and TenMinutes are steps too (held until their turn).
function FirstSession:record(name)
	if not self.milestones[name] then
		self.milestones[name] = true
		self:emit("event", name, 1)
	end
	if name == "FirstPet" or name == "FiveMinutes" or name == "TenMinutes" then
		if self:queue("recordStep", name) then return end
		self:recordStep(name)
	end
end
function FirstSession:recordStep(name)
	if self.v3 then self:advanceV3(FirstSession.V3Steps[name]) end
end

return FirstSession
