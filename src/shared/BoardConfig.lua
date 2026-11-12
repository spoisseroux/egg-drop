local Palette = require(script.Parent.DeckPalette)
-- Tier colours are the PICO-8 body colours (presentation only; radii and marks are the rules).
local Pico8 = require(script.Parent.Pico8)

local Config = {
	Width = 11,
	Height = 19,
	SpawnY = 17.8,
	Gravity = 32,
	LaunchAngleDegrees = 35,
	LaunchSpeed = 10,
	MaxSpeed = 38,
	GuideLength = 1.6,
	PreviewStep = 0.075,
	PreviewCount = 6,
	Bank = 2.2,
	MaxEggs = 32,
	OverflowY = 14.6,
	OverflowGrace = 1.1,
	DropInterval = 0.35,
	ModeSwitchInterval = 0.45,
	ResetInterval = 0.5,
	FixedStep = 1 / 120,
	DefaultPreset = "Springy",
	Presets = {
		Gentle = { bounce = 0.22, kick = 2.5, reach = 4 },
		Springy = { bounce = 0.64, kick = 11, reach = 3.5 },
	},
	Tiers = {
		{ radius = 0.72, color = Pico8[12], mark = "I" },
		{ radius = 1.04, color = Pico8[9], mark = "II" },
		{ radius = 1.43, color = Pico8[11], mark = "III" },
		{ radius = 1.88, color = Pico8[14], mark = "IV" },
		{ radius = 2.35, color = Pico8[10], mark = "V" },
	},
	Starter = {
		{ x = 0, tier = 1 },
		{ x = 1.95, tier = 2 },
		{ x = -3.3, tier = 2 },
		{ x = 4.05, tier = 1 },
	},
	Queue = { 1, 1, 2, 1, 2, 1 },
}

-- Difficulty ("heat"), QUESTS-DIFFICULTY-PLAN section 1. Medium is today's round,
-- byte for byte. `tenths` is the Star multiplier in tenths (HeatPayout), the tidy
-- bonus line moves with the overflow line, and Hard adds a third goal.
Config.HeatOrder = table.freeze({ "easy", "medium", "hard" })
Config.DefaultHeat = "medium"
Config.Heat = table.freeze({
	easy = table.freeze({ key = "easy", index = 1, name = "Easy", nickname = "Breezy", tenths = 8,
		overflowY = 9.6, grace = 3.0, armAfter = 16, bag = table.freeze({ 1, 1, 1, 1, 1, 2 }), bonusHeight = 8.5, goals = 2,
		bullets = table.freeze({ "Calmer egg mix", "Line sits higher", "2 goals" }) }),
	medium = table.freeze({ key = "medium", index = 2, name = "Medium", nickname = "Classic", tenths = 10,
		overflowY = 8.6, grace = 2.4, armAfter = 12, bag = table.freeze({ 1, 1, 1, 1, 2, 2 }), bonusHeight = 7.5, goals = 2,
		bullets = table.freeze({ "Today's rules", "Line as now", "2 goals" }) }),
	hard = table.freeze({ key = "hard", index = 3, name = "Hard", nickname = "Spicy", tenths = 15,
		overflowY = 7.6, grace = 2.0, armAfter = 10, bag = table.freeze({ 1, 1, 1, 2, 2, 3 }), bonusHeight = 6.5, goals = 3,
		bullets = table.freeze({ "Faster egg mix", "Line sits lower", "3 goals" }) }),
})
function Config.validHeat(key)
	return type(key) == "string" and Config.Heat[key] ~= nil
end
function Config.heat(key)
	return Config.Heat[key] or Config.Heat[Config.DefaultHeat]
end

-- Points for one merge. The server adds exactly this to the round score, and the
-- client shows the same number as the merge's "+N" pop.
function Config.mergeScore(tier,chain,cleared)
	return 10 * (tier + math.min(chain - 1, 9)) + (if cleared then 100 else 0)
end
-- The normalized input is an angle; the launch origin never depends on tier.
function Config.validAim(aim)
 return type(aim)=="number" and aim==aim and aim>=0 and aim<=1
end
function Config.aimAngle(aim)
 return (aim*2-1)*math.rad(Config.LaunchAngleDegrees)
end
function Config.launchPosition()
 return Vector2.new(0,Config.SpawnY)
end
function Config.launchVelocity(aim)
 local angle=Config.aimAngle(aim)
 return Vector2.new(math.sin(angle)*Config.LaunchSpeed,-math.cos(angle)*Config.LaunchSpeed)
end
-- Shared force integration keeps the dotted preview on the actual initial
-- flight. Collisions are deliberately outside this short unobstructed preview.
function Config.advanceFlight(position,velocity,dt)
 velocity+=Vector2.new(0,-Config.Gravity*dt)
 if velocity.Magnitude>Config.MaxSpeed then velocity=velocity.Unit*Config.MaxSpeed end
 velocity*=1-dt*.85
 return position+velocity*dt,velocity
end
function Config.flightPoint(aim,seconds)
 local position,velocity=Config.launchPosition(),Config.launchVelocity(aim)
 local steps=math.floor(seconds/Config.FixedStep+.5)
 for _=1,steps do position,velocity=Config.advanceFlight(position,velocity,Config.FixedStep) end
 return position
end
-- Solver policies invert the initial flight rather than treating angle as X.
-- Search the bounded legal controls at the target's current height.
function Config.aimAt(targetX,targetY)
 local best,distance=.5,math.huge
 for index=0,100 do
  local candidate=index/100
  local position,velocity=Config.launchPosition(),Config.launchVelocity(candidate)
  for _=1,240 do
   position,velocity=Config.advanceFlight(position,velocity,Config.FixedStep)
   if position.Y<=targetY then break end
  end
  local delta=math.abs(position.X-targetX)
  if delta<distance then best,distance=candidate,delta end
 end
 return best
end
return Config
