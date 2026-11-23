-- First-session onboarding funnel (slice A, 2026-11-14; plan artifacts/slice-a-2026-11-14/PLAN.md).
-- Funnel fix (FIRST-SESSION-FUNNEL-PLAN-2026-11-23, revision): step N logs only once step N-1 has
-- logged for this player (Roblox counts a later step as completing the earlier ones, which hid
-- real drop-off); a step that comes early is sent once as the custom event
-- "FunnelOutOfOrder_<StepKey>" instead and can still log later, when it happens again in order.
-- Live servers only, brand-new saves only (profile.newSave: Progress.load found no record, and
-- rank 0), behind FeatureFlags.FirstSessionFunnel. The object lives for the whole session, so a
-- save reload keeps it (init.server keeps the existing one). Every Roblox call is deferred and
-- pcall'd; nothing here yields or throws into join, round, hatch, care or save code.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local FeatureFlags = require(game:GetService("ReplicatedStorage").Shared.FeatureFlags)

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

-- options (specs): {force = true} skips the live-server gate; {log = fn(player, kind, ...)}
-- replaces AnalyticsService (kind is "step" or "event"); {analytics = service} is a stand-in
-- AnalyticsService; {defer = fn, delay = fn} replace task.defer / task.delay; {flags = table}
-- replaces FeatureFlags; {players = service} is the Players the player must still be in.
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
		defer = options.defer or task.defer,
	}, FirstSession)
	local ok, problem = pcall(options.delay or task.delay, FirstSession.FiveMinutes, function()
		self:record("FiveMinutes")
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

function FirstSession:advance(step)
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
	if not self.logged[FirstSession.Steps.BearMet] then
		return
	end
	self.rounds += 1
	if self.rounds >= 1 then
		self:advance(FirstSession.Steps.SecondRound)
	end
end

function FirstSession:record(name)
	if not self.milestones[name] then
		self.milestones[name] = true
		self:emit("event", name, 1)
	end
end

return FirstSession
