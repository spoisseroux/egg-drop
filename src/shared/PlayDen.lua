-- The Play Den (artifacts/qa-2026-11-24-beta16/PLAY-DEN-BUILD-PLAN.md; the room, step B, CLIFF-DEN-BUILD.md, architect verdict applied; look:
-- CLIFF-PATH-AND-ARCADE-CAVE-LOOK.md section 2): the north cave as a walk-in room with one object per game. Shared and
-- pure, the Tier pattern: FeatureFlags.PlayDen is the build ceiling and opens only on the beta place or in Studio; the
-- server's switch (DenConfig, ConfigService `play_den`: off until the config has loaded once, then missing or malformed =
-- on, Spencer 2026-11-25: "lets build out the play den") reaches clients as `Den_on`. DenHost writes `Den_open` only once the room is really open (built, the cave
-- blocker off) and clears it before it closes: clients follow `Den_open`, never `Den_on`, so a den that failed to open
-- leaves every player on today's flow (the meadow's "Race" picker). Off is the game before this build.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Den={}
Den.PlaceId=107705084891479 -- Pocket Pals Beta
Den.Attribute="Den_on"      -- the switch (DenConfig)
Den.OpenAttribute="Den_open" -- the room is open (DenHost); what clients read
Den.Key="play_den"
Den.Model="PlayDen"          -- EggDropLounge.PlayDen, the built greybox
Den.Blocked="DenPetBlock"    -- EggDropLounge.PetRegions.DenPetBlock*, the pet-blocked footprints
Den.Blocker="CaveBlocker"    -- EggDropLounge.CaveBlocker (LoungeWorldV7Art)
Den.MaxErrors=3
Den.Tick=.1

local injected=nil
-- Specs pass env = {flags, place, studio, on}; the game passes nothing.
function Den.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).PlayDen~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Den.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on (Spencer 2026-11-25: the
-- real room through the cave is in on the beta); `/den off` or the key closes it. The room itself needs the island's
-- sculpt (DenLayout.current): with no WorldBeta pack the den stays closed whatever the switch says.
function Den.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Den.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Server only (DenConfig): the resolved value DenHost reads. Off until it is set.
local switch=false
function Den.setSwitch(value)
	if not RunService:IsServer()then return false end
	switch=value==true
	return true
end
-- The switch (server: its own value and the attribute both).
function Den.on()
	if injected then return injected.on~=false and Den.ceiling(injected)end
	if not Den.ceiling()then return false end
	if RunService:IsServer()and not switch then return false end
	return workspace:GetAttribute(Den.Attribute)==true
end
-- Clients: is the room open right now? (DenHost's own attribute; missing = closed.)
function Den.isOpen()
	if injected then return injected.open==true and Den.ceiling(injected)end
	return Den.ceiling()and workspace:GetAttribute(Den.OpenAttribute)==true
end
function Den.changed()return workspace:GetAttributeChangedSignal(Den.OpenAttribute)end
-- Spec seam, refused outside Studio.
function Den.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end
return table.freeze(Den)
