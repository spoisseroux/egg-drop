-- Player scale (artifacts/player-scale-2026-11-26/PLAN.md; Spencer 2026-11-26: "It feels tiny ... And make it easier
-- to tweak?" then "let's scale the player"): the world reads bigger because the avatar is drawn smaller. One number,
-- shared and pure. FeatureFlags.PlayerScale is the build ceiling and it opens only on the beta place or in Studio;
-- outside it the scale is 1 and nothing is touched. Inside it the value comes from, in order: the owner's chat
-- override (`/scale 0.75`, `/scale clear`), ConfigService `player_scale`, else Default. Walk speed, jump and every world
-- coordinate stay as they are. The server publishes the resolved number as the workspace attribute PlayerScale.
local RunService=game:GetService("RunService")
local Flags=require(script.Parent.FeatureFlags)
local Scale={}
Scale.PlaceId=107705084891479 -- Pocket Pals Beta
Scale.Default=.8
Scale.Min,Scale.Max=.6,1.2
Scale.Attribute="PlayerScale"
Scale.AppliedAttribute="AppliedScale" -- on each scaled character (the server writes it after Model:ScaleTo)
Scale.Key="player_scale"
-- Characters whose scale differs from the target by less than this are left alone (float noise from ScaleTo).
Scale.Epsilon=.002

local injected=nil
-- Specs pass env = {flags, place, studio} (or inject it); the game passes nothing.
function Scale.ceiling(env)
	env=env or injected or {}
	if(env.flags or Flags).PlayerScale~=true then return false end
	local studio=env.studio
	if studio==nil then studio=RunService:IsStudio()end
	return(env.place or game.PlaceId)==Scale.PlaceId or studio==true
end
-- Pure: a number in [Min, Max], or nil when `value` is not a usable number.
function Scale.clamp(value)
	if type(value)=="string"then value=tonumber(value)end
	if type(value)~="number"or value~=value or value==math.huge or value==-math.huge then return nil end
	return math.clamp(value,Scale.Min,Scale.Max)
end
-- Pure: the scale. Outside the ceiling always 1; inside: the override, else the config value, else Default.
function Scale.resolve(configValue,override,ceiling)
	if ceiling==nil then ceiling=Scale.ceiling()end
	if not ceiling then return 1 end
	return Scale.clamp(override)or Scale.clamp(configValue)or Scale.Default
end
-- Pure: a chat command. {value=number} for "/scale 0.75", {value=nil, clear=true} for "/scale clear"; nil otherwise.
function Scale.parse(message)
	if type(message)~="string"then return nil end
	local word=string.match(string.lower(message),"^%s*/scale%s+(%S+)%s*$")
	if not word then return nil end
	if word=="clear"or word=="reset"then return{clear=true}end
	local value=Scale.clamp(word)
	if not value then return nil end
	return{value=value}
end
-- The published scale (1 before the server has published, and always 1 outside the ceiling).
function Scale.value()
	if injected then return Scale.resolve(injected.config,injected.override,Scale.ceiling(injected))end
	if not Scale.ceiling()then return 1 end
	local value=workspace:GetAttribute(Scale.Attribute)
	return if type(value)=="number"then value else 1
end
function Scale.changed()return workspace:GetAttributeChangedSignal(Scale.Attribute)end
-- A character's drawn scale: its AppliedScale attribute (architect review: never GetScale on the client), else 1.
function Scale.of(character)
	if typeof(character)~="Instance"then return 1 end
	local value=character:GetAttribute(Scale.AppliedAttribute)
	return if type(value)=="number"and value>0 then value else 1
end
-- Pure: the follow camera's zoom factor for a scale (Fable: a smaller avatar would otherwise shrink on screen twice):
-- half of the scale's change, 0.9 at 0.8, 1 at 1.
function Scale.zoomFactor(s)
	s=Scale.clamp(s)or 1
	return 1-(1-s)*.5
end
-- Pure: a local CFrame with its position scaled by s and its rotation kept (the held deck's pieces).
function Scale.scaleCFrame(cf,s)return CFrame.new(cf.Position*s)*cf.Rotation end
-- Spec seam, refused outside Studio.
function Scale.inject(env)
	if not RunService:IsStudio()then return false end
	injected=if type(env)=="table"then table.clone(env)else nil
	return true
end
return table.freeze(Scale)
