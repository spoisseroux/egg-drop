local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)

local Round = {}
Round.__index = Round

function Round.new(options)
	options = options or {}
	return setmetatable({ score = 0, maxClears = 0, over = false, overflowTime = 0,
		overflowY = options.overflowY or Config.OverflowY, grace = options.grace or Config.OverflowGrace,
		armAfterDrops = options.armAfterDrops or 0, warningMargin = options.warningMargin or 2,
		danger = 0, settledHeight = 0 }, Round)
end

function Round:step(eggs, dt, drops)
	if self.over then return end
	local overflowing, maximum = false, 0
	for _, egg in ipairs(eggs) do
		egg.roundAge = (egg.roundAge or 0) + dt
		local top = egg.position.Y + egg.radius
		egg.enteredTray = egg.enteredTray or top < self.overflowY
		-- Fresh airborne drops do not start the meter. A continuous grace
		-- interval must elapse; merging below the line fully cancels danger.
		if egg.enteredTray or egg.roundAge >= 1.4 then
			maximum = math.max(maximum, top)
			if top >= self.overflowY then overflowing = true end
		end
	end
	self.settledHeight = maximum
	local armed = (drops or 0) >= self.armAfterDrops or maximum >= Config.SpawnY - 1
	self.overflowTime = if armed and overflowing then self.overflowTime + dt else 0
	self.danger = if not armed then 0 else math.max(self.overflowTime / self.grace,
		math.clamp((maximum - self.overflowY + self.warningMargin) / self.warningMargin, 0, 0.85))
	self.over = self.overflowTime >= self.grace or #eggs >= Config.MaxEggs
end

return Round
