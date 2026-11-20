-- Pet headshots for pet lists (Spencer 2026-11-20: every pet showed the same paw; "maybe just a
-- headshot?"). Astra's spec: artifacts/v2-notifications-2026-11-20/NOTIFICATIONS-SPEC.md section 2.
-- A head-and-shoulders render of the pet in its own ViewportFrame, on a disc of its secondary
-- colour softened toward cream. Built through CardPreviewCache (lazy, visible cards only, at most
-- 8 live, posed once, never animated). A pet you do not own yet is a dark silhouette with a lock.
-- The paw stays in the host until the viewport attaches, and stays for good when the host is
-- under MinSide, the budget is full or the rig cannot be built.
local Shared=game:GetService("ReplicatedStorage").Shared
local Pets=require(Shared.PetCatalog)
local Palette=require(Shared.PetPalette)
local Cache=require(script.Parent.CardPreviewCache)
local Bounds=require(script.Parent.PetRigBounds)
local Shot={}
Shot.MinSide=40
Shot.Live=8
Shot.Cream=Color3.fromHex("#FFF4DC")
Shot.LockedTint=Color3.new(0,0,0)
Shot.LockedTransparency=.35

-- Pure: the backdrop colour for a pet (secondary lerped .55 toward cream).
function Shot.backdrop(petId,appearance)
 local ok,colors=pcall(Palette.resolve,petId,appearance)
 local secondary=ok and type(colors)=="table"and colors.secondary or nil
 if typeof(secondary)=="string"then secondary=Color3.fromHex(secondary)end
 if typeof(secondary)~="Color3"then return Shot.Cream end
 return secondary:Lerp(Shot.Cream,.55)
end
-- Head framing: a little above the eye line, looking at the upper part of the rig, fitting about
-- 62% of its height into the frame (ear and horn tips may crop).
function Shot.frame(camera,visual)
 visual.yaw=-.35;visual.reducedEffects=true;visual.poseDirty=true;visual:update(0)
 local box,size=Bounds.get(visual)
 local half=math.tan(math.rad(camera.FieldOfView/2))
 local target=box.Position+Vector3.new(0,size.Y*.18,0)
 local fit=math.max(size.Y*.62,size.X*.62)
 local distance=fit*.5/half+size.Z*.5
 local lift=math.tan(math.rad(6))*distance
 camera.CFrame=CFrame.lookAt(target+Vector3.new(0,lift,distance),target)
end

function Shot.newCache()return Cache.new({live=Shot.Live,size=Shot.Live+4})end

-- One card for CardPreviewCache:pump. host: the swatch frame; fallback: what hides when the
-- render attaches (the paw); locked: the silhouette look.
function Shot.card(host,petId,appearance,locked,visible)
 local pet=Pets.byId[petId]
 return{holder=host,visible=visible~=false and host.AbsoluteSize.X>=Shot.MinSide,
  key=Cache.key(petId,if locked then "headshot:locked"else "headshot",appearance),
  build=function()
   local entry=Cache.buildPet(pet,appearance,1)
   if not entry then return false end
   entry.head=true
   pcall(Shot.frame,entry.camera,entry.visual)
   entry.rig=entry.visual.rigRevision
   if locked then entry.viewport.ImageColor3=Shot.LockedTint;entry.viewport.ImageTransparency=Shot.LockedTransparency end
   return entry
  end}
end

return Shot
