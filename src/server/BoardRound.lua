local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)

local Round = {}
Round.__index = Round

function Round.new()
	return setmetatable({ score = 0, maxClears = 0, over = false, overflowTime = 0 }, Round)
end

function Round:step(eggs, dt)
	if self.over then
		return
	end
	local overflowing = false
	for _, egg in ipairs(eggs) do
		egg.roundAge = (egg.roundAge or 0) + dt
		local top = egg.position.Y + egg.radius
		egg.enteredTray = egg.enteredTray or top < Config.OverflowY
		if top >= Config.OverflowY and (egg.enteredTray or egg.roundAge >= 1.4) then
			overflowing = true
		end
	end
	self.overflowTime = if overflowing then self.overflowTime + dt else 0
	self.over = self.overflowTime >= Config.OverflowGrace or #eggs >= Config.MaxEggs
end

return Round
