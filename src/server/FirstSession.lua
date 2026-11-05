local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FirstSession = {}
FirstSession.__index = FirstSession
local stepNames = { "Board ready", "First drop", "First merge", "Pip hatched" }

local function log(player, method, ...)
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

function FirstSession.new(player, profile)
	if RunService:IsStudio() or game.GameId == 0 or profile.loadFailed or profile.rank > 0 then
		return nil
	end
	return setmetatable({ player = player, step = 0, milestones = {} }, FirstSession)
end

function FirstSession:advance(step)
	if step == self.step + 1 then
		self.step = step
		log(self.player, AnalyticsService.LogOnboardingFunnelStepEvent, step, stepNames[step])
	end
end

function FirstSession:record(name)
	if not self.milestones[name] then
		self.milestones[name] = true
		log(self.player, AnalyticsService.LogCustomEvent, name, 1)
	end
end

return FirstSession
