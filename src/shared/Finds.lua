-- Garden finds (V3-FINDS-BUILD-PLAN-2026-11-22, slice S9), the Things pattern. Shared and pure: FeatureFlags.GardenFinds
-- is the build ceiling, and it opens only on the beta place or in Studio, while the runtime switch is on (ConfigService
-- key `garden_finds`, server FindsConfig: off until the config has loaded once, then missing or malformed = on). Clients
-- read the workspace attribute the server writes; a missing one is off. Off is the game before this build.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local StatCatalog=require(script.Parent.StatCatalog)
local Spots=require(script.Parent.FindSpots)
local Finds={}
Finds.PlaceId=107705084891479 -- Pocket Pals Beta
Finds.Attribute="Finds_on"
Finds.Key="garden_finds"
Finds.XP=StatCatalog.XP.find -- Smarts
Finds.Every=240        -- active seconds between new finds
Finds.FirstAfter=60    -- active seconds before the first of a session
Finds.Waiting=3        -- at most this many live at once
Finds.DailyLimit=12    -- paid finds a day (on the save)
Finds.Reach=14         -- the server's claim reach, character root to spot, 3D
Finds.Sniff=8          -- the client sends the claim this near
Finds.Notice=20        -- sparkles twinkle harder, and the tip shows, this near
Finds.Spacing=20       -- a new find is never this near a live one
Finds.Recent=6         -- nor one of the last six used
Finds.Spots=Spots

local injected=nil
-- Specs pass env = {flags, place, studio}; the game passes nothing.
function Finds.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).GardenFinds~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Finds.PlaceId or studio==true
end
-- Pure: a switch value. Anything but a boolean (missing, malformed) is the shipped default, on.
function Finds.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Finds.ceiling()end
	if not ceiling then return false end
	if type(override)=="boolean"then return override end
	if type(configValue)=="boolean"then return configValue end
	return true
end
-- Server only (FindsConfig): the resolved value every server check reads. Off until it is set.
local switch=false
function Finds.setSwitch(value)
	if not RunService:IsServer()then return false end
	switch=value==true
	return true
end
function Finds.on()
	if injected then return injected.on~=false and Finds.ceiling(injected)end
	if not Finds.ceiling()then return false end
	if RunService:IsServer()and not switch then return false end
	return workspace:GetAttribute(Finds.Attribute)==true
end
function Finds.changed()return workspace:GetAttributeChangedSignal(Finds.Attribute)end
-- Spec seam, refused outside Studio.
function Finds.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end

-- A spot as studs.
function Finds.position(index)
	local s=Spots[index]
	return s and Vector3.new(s.x/100,s.y/100,s.z/100)or nil
end
-- Pure: the index of a spot for a new find, or nil. `live` and `recent` are lists of spot indices; `random` is a
-- Random. Never a live spot or a recent one, never within Spacing of a live one; uniform over what is left.
function Finds.pick(random,live,recent)
	local blocked={}
	for _,i in ipairs(live or {})do blocked[i]=true end
	for _,i in ipairs(recent or {})do blocked[i]=true end
	local open={}
	for index,spot in ipairs(Spots)do
		local ok=not blocked[index]
		if ok then
			for _,i in ipairs(live or {})do
				local other=Spots[i]
				if other and math.sqrt((spot.x-other.x)^2+(spot.z-other.z)^2)/100<Finds.Spacing then ok=false;break end
			end
		end
		if ok then open[#open+1]=index end
	end
	if #open==0 then return nil end
	return open[random:NextInteger(1,#open)]
end

return table.freeze(Finds)
