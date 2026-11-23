-- The catch-up poof (beta (12) QA G1): a pet that hopped to its owner leaves a small puff where it was and lands in one.
-- PetFollow calls play(from, to, reduced) once per new hop seq, for every player's pet. Placeholder look until Fable
-- sets it (soft, eased, no burst: GARDEN-LIFE-NEST-LOOK's rule): a few cream-grey puffs that swell and fade.
-- Reduced Motion: nothing (the pet just appears). Local parts only, gone after Life seconds; nothing replicates.
local Debris=game:GetService("Debris")
local Poof={}
Poof.Count=8
Poof.Life=1.2
Poof.Color=Color3.fromHex("#F4F1EA")
Poof.Texture="rbxasset://textures/particles/smoke_main.dds"
Poof.Folder="EggDropPoofs"

local function folder()
	local found=workspace:FindFirstChild(Poof.Folder)
	if found then return found end
	local made=Instance.new("Folder")
	made.Name=Poof.Folder
	made.Parent=workspace
	return made
end
local function puff(at,count)
	local part=Instance.new("Part")
	part.Name="Poof"
	part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch,part.CastShadow=true,false,false,false,false
	part.Transparency=1
	part.Size=Vector3.new(1.6,.6,1.6)
	part.CFrame=CFrame.new(at+Vector3.new(0,.5,0))
	local e=Instance.new("ParticleEmitter")
	e.Texture=Poof.Texture
	e.Rate=0
	e.Color=ColorSequence.new(Poof.Color)
	e.LightInfluence=0
	e.Lifetime=NumberRange.new(.45,.7)
	e.Speed=NumberRange.new(1.5,3)
	e.SpreadAngle=Vector2.new(180,40)
	e.Drag=4
	e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,1.4)})
	e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(1,1)})
	e.Parent=part
	part.Parent=folder()
	e:Emit(count)
	Debris:AddItem(part,Poof.Life)
end
function Poof.play(from,to,reduced)
	if reduced then return false end
	if typeof(from)=="Vector3"then puff(from,Poof.Count)end
	if typeof(to)=="Vector3"then puff(to,Poof.Count)end
	return true
end
return Poof
