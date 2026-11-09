local Palette = require(script.Parent.DeckPalette)

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
		{ radius = 0.72, color = Color3.fromHex("#52ADF2"), mark = "I" },
		{ radius = 1.04, color = Color3.fromHex("#F39749"), mark = "II" },
		{ radius = 1.43, color = Color3.fromHex("#A8D34C"), mark = "III" },
		{ radius = 1.88, color = Color3.fromHex("#EF78A4"), mark = "IV" },
		{ radius = 2.35, color = Color3.fromHex("#AB8CF2"), mark = "V" },
	},
	Starter = {
		{ x = 0, tier = 1 },
		{ x = 1.95, tier = 2 },
		{ x = -3.3, tier = 2 },
		{ x = 4.05, tier = 1 },
	},
	Queue = { 1, 1, 2, 1, 2, 1 },
}

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
