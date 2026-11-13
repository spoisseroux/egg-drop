-- A forgiving click/tap target for the local player's own garden pet (Spencer
-- 2026-11-13: "make it easier to click the pet"). One invisible box around the
-- whole rig (its pose bounds x Margin, at least MinSize studs a side) carries the
-- pet's ClickDetector with a longer reach than the ProximityPrompt. The box lives
-- inside the pet's model, so it goes when the pet goes; it is anchored and moved
-- with the pose bounds (writes only on change), never collides or touches, and
-- every garden/path raycast either excludes the pet model or respects CanCollide.
-- The pose bounds come from the rig pieces only, so the box never feeds back into
-- framing. Only RoomView's own pet gets one: visitor pets are never pettable.
local Bounds=require(script.Parent.PetRigBounds)
local Target={}
Target.Name="PetClickTarget"
Target.Margin=1.3
Target.MinSize=3
Target.Reach=16
Target.Quantum=.05 -- studs: smaller moves are not written

function Target.attach(pet)
 local part=Instance.new("Part")
 part.Name=Target.Name;part.Transparency=1;part.CastShadow=false
 part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=true;part.Massless=true
 part.Locked=true;part.Material=Enum.Material.SmoothPlastic
 part:SetAttribute("PetClickTarget",true)
 local click=Instance.new("ClickDetector")
 click.Name="PetClick";click.MaxActivationDistance=0;click.Parent=part
 local handle={part=part,click=click,pet=pet}
 Target.sync(handle)
 part.Parent=pet.model
 return handle
end

local function snap(value)return math.floor(value/Target.Quantum+.5)*Target.Quantum end
-- Pure: the box size for rig bounds of `size`.
function Target.boxSize(size)
 return Vector3.new(math.max(Target.MinSize,size.X*Target.Margin),math.max(Target.MinSize,size.Y*Target.Margin),math.max(Target.MinSize,size.Z*Target.Margin))
end
-- Follows the pet's current pose bounds; writes CFrame/Size only when they changed.
function Target.sync(handle)
 local pet=handle.pet
 if not pet or pet.destroyed or not handle.part.Parent and handle.synced then return end
 local frame,size=Bounds.get(pet)
 if not frame or not size then return end
 local p=frame.Position
 local x,y,z=snap(p.X),snap(p.Y),snap(p.Z)
 local sx,sy,sz=snap(size.X),snap(size.Y),snap(size.Z)
 if handle.x~=x or handle.y~=y or handle.z~=z then
  handle.x,handle.y,handle.z=x,y,z
  handle.part.CFrame=CFrame.new(x,y,z)
 end
 if handle.sx~=sx or handle.sy~=sy or handle.sz~=sz then
  handle.sx,handle.sy,handle.sz=sx,sy,sz
  handle.part.Size=Target.boxSize(Vector3.new(sx,sy,sz))
 end
 handle.synced=true
end
function Target.destroy(handle)
 if handle and handle.part then handle.part:Destroy()end
end
return Target
