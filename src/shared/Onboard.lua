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
-- The First Hatch (artifacts/onboarding-2026-11-26/PLAN.md; Spencer: "three combos and the egg hatches"):
--   Onboard.on("opener")    the Welcome round: a seeded opener (a chain on drop two) and the egg hatching on 3 combos
--   Onboard.on("crack")     the Bear's hatch: three taps crack the egg (it opens by itself untouched)
--   Onboard.on("nestfirst") the nest bubble straight after the first hello (needs `needs` and `nest` on)
-- Onboarding v2 (artifacts/qa-2026-11-26-beta35/ONBOARDING-V2.md; Spencer: "the new onboarding doesnt help?"):
--   Onboard.on("egg3d")     step 1: the Welcome deck's 3D spinning egg, one instruction a step and three shell pips
--   Onboard.on("stork")     steps 2 and 3: a stork brings the egg into the garden and three taps crack it there; no
--                           deck hatch modal (needs `opener` and `crack`: Onboard.storyOn)
--   Onboard.on("safecard")  step 4: every pet reveal card (RevealStage) inside the CoreUISafeInsets rect
--   Onboard.on("guide")     step 5: one worded bubble at a time (Pet, Tuck the egg in, Play for Stars) and the end card
-- All four off is exactly beta (35).
-- Onboarding v3 (artifacts/qa-2026-11-27-beta37/ONBOARDING-V3-BRIEF.md; Spencer: "a cuter Welcome deck"):
--   Onboard.on("deck2")     section 5: the cuter Welcome deck inside the two existing cards (glass sky card, looping step
--                           pictures, the egg on its grass knocking from inside, egg pips, the combo moment). Presentation
--                           only; it dresses the egg3d deck, so it needs `egg3d` on too. Off is exactly beta (37).
-- Onboarding v3 brief (artifacts/qa-2026-11-27-beta37/ONBOARDING-V3-BRIEF.md):
--   Onboard.on("trail2")    section 2, glow steps: every trail (PetTrail, ThingsTrail) draws glowing paws with a wave
--                           toward a gold target ring, guide trails stay while their prompt is open, and a leading pet
--                           lays its own prints (Shared.TrailGlow, client GlowSteps). Off is the trails as before.
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
Onboard.Features=table.freeze({"follow","needs","nest","corner","landmark","capsule","opener","crack","nestfirst","egg3d","stork","safecard","guide","deck2","trail2"})
Onboard.Attributes=table.freeze({follow="Onboard_follow",needs="Onboard_needs",nest="Onboard_nest",corner="Onboard_corner",landmark="Onboard_landmark",capsule="Onboard_capsule",opener="Onboard_opener",crack="Onboard_crack",nestfirst="Onboard_nestfirst",
	egg3d="Onboard_egg3d",stork="Onboard_stork",safecard="Onboard_safecard",guide="Onboard_guide",deck2="Onboard_deck2",trail2="Onboard_trail2"})
Onboard.Keys=table.freeze({follow="onboard_follow",needs="onboard_needs",nest="onboard_nest",corner="onboard_corner",landmark="onboard_landmark",capsule="onboard_capsule",opener="onboard_opener",crack="onboard_crack",nestfirst="onboard_nestfirst",
	egg3d="onboard_egg3d",stork="onboard_stork",safecard="onboard_safecard",guide="onboard_guide",deck2="onboard_deck2",trail2="onboard_trail2"})
-- Onboarding v2's one-time events the client reports (the server records each name once, FirstSession:record, and only
-- for a save that owns a pet). EggTapped, BearMet, FirstPet and NestTucked are already recorded where they happen.
Onboard.Events=table.freeze({StorkShown=true,EggSetDown=true,AllSet=true,OnboardSkipped_Stork=true})
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
local switches={follow=false,needs=false,nest=false,corner=false,landmark=false,capsule=false,opener=false,crack=false,nestfirst=false,
	egg3d=false,stork=false,safecard=false,guide=false,deck2=false,trail2=false}
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
-- Onboarding v2 steps 2 and 3 need the Welcome opener (the egg hatches on 3 combos) and the crack (three taps).
function Onboard.storyOn()return Onboard.on("stork")and Onboard.on("opener")and Onboard.on("crack")end
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
