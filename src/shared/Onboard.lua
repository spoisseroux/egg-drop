-- Onboarding v3 switches (ONBOARDING-V3-PLAN-2026-11-23, architect review), the Things pattern. Shared and pure:
-- FeatureFlags.OnboardingV3 is the build ceiling, and it opens only on the beta place or in Studio; each part also
-- needs Things to do on (Things.on()) and its own runtime switch. Off is exactly the game before this build: the
-- five-card tour, the beats, the pill, no bubbles, no nest, no `public.nest`, and the new coach ids are refused.
--   Onboard.on("follow")  follow the Bear: the tour and beats off, auto trail, station label tips, idle hint
--   Onboard.on("needs")   the need bubbles over the Bear and the Things to do top row
--   Onboard.on("nest")    the Sleepy Nest: save field, snapshot key, garden egg, chip, strip nest chip
--   Onboard.on("corner")  the egg corner (EGG-CORNER-BUILD-PLAN): the egg machine is station Eggs, the old station's
--                         glass and glow hidden, the nest's "?" card and Peek, no Napping egg row (EggCorner)
--   Onboard.on("capsule")  the egg machine's capsule shot on a buy (EggMachineClient; CAPSULE-AND-HUD-LOOK 1)
--   Onboard.on("landmark") the Sleepy Nest as a landmark (bowl, woven nest, moon lantern) at the corner's spot (NestLandmark)
-- ConfigService keys `onboard_follow`, `onboard_needs`, `onboard_nest` (server OnboardConfig): off until the config has
-- loaded once, then missing or malformed = on. The server publishes `Onboard_<feature>` as its own value AND Things.on()
-- and republishes when Things changes, so the attribute alone is the truth for clients; on() checks Things too, so a
-- Things flip is off at once. The server is on only while its held value and the attribute both say so.
-- Read the tour switch through sessionFollow(): it is captured once per session so a mid-session flip never starts
-- (or cuts) the old tour half way.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Things=require(script.Parent.Things)
local Onboard={}
Onboard.PlaceId=107705084891479 -- Pocket Pals Beta
Onboard.Features=table.freeze({"follow","needs","nest","corner","landmark","capsule"})
Onboard.Attributes=table.freeze({follow="Onboard_follow",needs="Onboard_needs",nest="Onboard_nest",corner="Onboard_corner",landmark="Onboard_landmark",capsule="Onboard_capsule"})
Onboard.Keys=table.freeze({follow="onboard_follow",needs="onboard_needs",nest="onboard_nest",corner="onboard_corner",landmark="onboard_landmark",capsule="onboard_capsule"})
function Onboard.attribute(feature)return Onboard.Attributes[feature]end
function Onboard.key(feature)return Onboard.Keys[feature]end

-- Specs pass env = {flags, place, studio} (or inject it, below); the game passes nothing.
-- The build ceiling only (flag and place): what OnboardConfig starts on. on() also needs Things.on().
local injected=nil
function Onboard.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).OnboardingV3~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Onboard.PlaceId or studio==true
end
-- The ceiling and Things to do on (injected: env.things, default on).
function Onboard.open(env)
	env=env or injected
	if not Onboard.ceiling(env)then return false end
	if env then return env.things~=false end
	return Things.on()
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function Onboard.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Onboard.open()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Server only (OnboardConfig): the resolved values every server check reads. Off until they are set.
local switches={follow=false,needs=false,nest=false,corner=false,landmark=false,capsule=false}
function Onboard.setSwitch(feature,value)
	if not RunService:IsServer()or switches[feature]==nil then return false end
	switches[feature]=value==true
	return true
end
function Onboard.switch(feature)
	if Onboard.Attributes[feature]==nil then return false end
	if RunService:IsServer()and switches[feature]~=true then return false end
	return workspace:GetAttribute(Onboard.Attributes[feature])==true
end
-- Fires when the server republishes a part (its own value or a Things flip both land here).
function Onboard.changed(feature)return workspace:GetAttributeChangedSignal(Onboard.Attributes[feature or"follow"])end

-- Spec seam: every later ceiling(), open(), on() reads `env` (each part on unless env[feature] == false; Things on
-- unless env.things == false) until inject(nil). Also forgets the session captures. Refused outside Studio.
local captured={}
function Onboard.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	table.clear(captured)
	return true
end
-- Is this part on right now? An unknown feature is off.
function Onboard.on(feature)
	if Onboard.Attributes[feature]==nil then return false end
	if injected then return injected[feature]~=false and Onboard.open(injected)end
	return Onboard.open()and Onboard.switch(feature)
end
-- May a coach card that belongs to this part be shown and saved now? (CoachMarks.allows)
function Onboard.allows(part)return Onboard.on(part)end

-- The follow switch for this session: read once, at the first call, then the same answer until the session ends.
-- Call it when the tour would start (garden ready), not at boot: the attribute may not have replicated yet.
-- `who` keys the capture on the server (a Player or UserId); the client passes nothing. forget(who) on leave.
local SELF={}
function Onboard.sessionFollow(who)
	local key=if who==nil then SELF else who
	local value=captured[key]
	if value==nil then
		value=Onboard.on("follow")
		captured[key]=value
	end
	return value
end
function Onboard.forget(who)captured[if who==nil then SELF else who]=nil end
return table.freeze(Onboard)
