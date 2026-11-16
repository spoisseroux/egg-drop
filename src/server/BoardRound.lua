local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)

local Round = {}
Round.__index = Round

function Round.new(options)
	options = options or {}
	return setmetatable({ score = 0, maxClears = 0, over = false, overflowTime = 0,
		overflowY = options.overflowY or Config.OverflowY, grace = options.grace or Config.OverflowGrace,
		armAfterDrops = options.armAfterDrops or 0, warningMargin = options.warningMargin or 2,
		danger = 0, settledHeight = 0, graceLeft = 0, safe = options.safe == true }, Round)
end

function Round:step(eggs, dt, drops)
	if self.over then return end
	local overflowing, maximum, resting = false, 0, 0
	for _, egg in ipairs(eggs) do
		egg.roundAge = (egg.roundAge or 0) + dt
		local top = egg.position.Y + egg.radius
		egg.enteredTray = egg.enteredTray or top < self.overflowY
		-- Fresh airborne drops do not start the meter. A continuous grace
		-- interval must elapse; merging below the line fully cancels danger.
		if egg.enteredTray or egg.roundAge >= 1.4 then
			maximum = math.max(maximum, top)
			if top >= self.overflowY then overflowing = true end
			-- QA v735 D3: the near-line warning is about the pile. A ball that is still
			-- falling passes through the warning band on every drop, so it only counts
			-- once it has touched the tray or another ball (or has been in play 1.4 s).
			if egg.hasContact or egg.roundAge >= 1.4 then resting = math.max(resting, top) end
		end
	end
	self.settledHeight = maximum
	local armed = (drops or 0) >= self.armAfterDrops or maximum >= Config.SpawnY - 1
	self.overflowTime = if armed and overflowing then self.overflowTime + dt else 0
	self.danger = if not armed then 0 else math.max(self.overflowTime / self.grace,
		math.clamp((resting - self.overflowY + self.warningMargin) / self.warningMargin, 0, 0.85))
	-- Welcome cannot lose. Simulation still enforces its resource cap; the host
	-- refreshes a full/blocked Welcome tray with charge/run/demo state retained.
	if self.safe then self.overflowTime, self.danger = 0, 0 end
	self.over = not self.safe and(self.overflowTime >= self.grace or #eggs >= Config.MaxEggs)
	-- Presentation only (published as OverflowGraceLeft): seconds of grace left
	-- while the stack is over the line, 0 when it is not. Rules are unchanged.
	self.graceLeft = if self.overflowTime > 0 and not self.over then math.max(0, self.grace - self.overflowTime) else 0
end

return Round
