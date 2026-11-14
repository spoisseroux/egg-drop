-- First-session onboarding funnel (slice A, 2026-11-14; plan artifacts/slice-a-2026-11-14/PLAN.md).
-- Each step logs once, when it happens; the Creator dashboard computes conversion. A step that
-- happens before an earlier one still logs (holding it would hide real drop-off). Live servers
-- only, new players only (rank 0 at join); the object lives for the whole session, so a save
-- reload keeps it (init.server keeps the existing one).
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

local function defaultLog(player, method, ...)
	task.defer(function(...)
		if player.Parent ~= Players then
			return
		end
		local ok, problem = pcall(method, AnalyticsService, player, ...)
		if not ok then
			warn("Egg Drop could not log a first-session milestone:", problem)
		end
	end, ...)
end

-- options (specs): {force = true} skips the live-server gate, {log = fn(player, kind, ...)}
-- replaces AnalyticsService (kind is "step" or "event").
function FirstSession.new(player, profile, options)
	options = options or {}
	if not options.force and (RunService:IsStudio() or game.GameId == 0) then
		return nil
	end
	if type(profile) ~= "table" or profile.loadFailed or (profile.rank or 0) > 0 then
		return nil
	end
	return setmetatable({ player = player, logged = {}, milestones = {}, rounds = 0, sink = options.log }, FirstSession)
end

function FirstSession:advance(step)
	local name = FirstSession.StepNames[step]
	if not name or self.logged[step] then
		return false
	end
	self.logged[step] = true
	if self.sink then
		self.sink(self.player, "step", step, name)
	else
		defaultLog(self.player, AnalyticsService.LogOnboardingFunnelStepEvent, step, name)
	end
	return true
end

-- A round began on the board. The Welcome round ends with the Bear, so the first round
-- started after step 4 is the player's second round (step 9).
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
		if self.sink then
			self.sink(self.player, "event", name, 1)
		else
			defaultLog(self.player, AnalyticsService.LogCustomEvent, name, 1)
		end
	end
end

return FirstSession
