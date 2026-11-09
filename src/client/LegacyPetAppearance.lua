-- Explicit role adapter for the five existing collection silhouettes.
-- Rare petals, flame cores, moons and every face part retain authored identity.
local Shared=game:GetService("ReplicatedStorage").Shared
local Palette=require(Shared.PetPalette)
local Hue=require(Shared.HueCatalog)
local Charms=require(script.Parent.PetCharms)
local Face=require(script.Parent.PetFace)
local Adapter={}
local roles={
 bloom_pip={main={Body=true,Flipper=true},secondary={Slipper=true,SprigStem=true,WideLeaf=true,NewLeaf=true,LeafPixel=true},anchor=Vector3.new(0,3.65,0)},
 wick={main={Body=true,Foot=true},secondary={Flame=true},anchor=Vector3.new(0,3.20,0)},
 orbit={main={Body=true,Foot=true},secondary={OrbitRing=true},anchor=Vector3.new(0,2.48,0)},
 foxfire_wick={main={Body=true,Foot=true},secondary={Foxfire=true},anchor=Vector3.new(0,3.30,0)},
 eclipse_orbit={main={Body=true,Foot=true},secondary={OrbitRing=true},anchor=Vector3.new(0,2.48,0)},
}
function Adapter.attach(visual,pet,appearance)
 local mapping=assert(roles[pet.id],"Missing legacy color role map")
 visual.petId=pet.id;visual.colors=Palette.resolve(pet.id,appearance);visual.secondaryColor=visual.colors.secondary
 visual.model:SetAttribute("HueAdapter",pet.id);visual.model:SetAttribute("RigBackend","LegacyNative")
 for _,entry in ipairs(visual.pieces)do
  local name=entry.part.Name;entry.name=name;entry.color=entry.part.Color;entry.originalColor=entry.part.Color
  entry.colorRole=if mapping.main[name]then "body"elseif mapping.secondary[name]then "secondary"else nil
  entry.faceBaseMaterial=entry.part.Material
 end
 local dot=Instance.new("Part");dot.Name="CharmDot";dot.Shape=Enum.PartType.Ball;dot.Anchored=true;dot.CanCollide=false;dot.CanTouch=false;dot.CanQuery=false;dot.Material=Enum.Material.SmoothPlastic;dot.Parent=visual.model
 local original=Palette.original(pet.id);local size=Vector3.new(.24,.31,.24)
 local entry={part=dot,name="CharmDot",role="charm",colorRole="secondary",size=size,frame=CFrame.new(mapping.anchor),offset=CFrame.new(mapping.anchor),color=original.secondary,originalColor=original.secondary,faceBaseMaterial=dot.Material}
 table.insert(visual.pieces,entry)
 function visual:applyAppearance(value)
  self.appearance=value or {};self.colors=Palette.resolve(pet.id,self.appearance);self.secondaryColor=self.colors.secondary
  for _,item in ipairs(self.pieces)do if item.colorRole then
   local doses=self.appearance[if item.colorRole=="body"then "mainDoses"else "secondaryDoses"]
   local target=doses and Hue.resolveTarget(doses);local strength=doses and Hue.doseStrength(doses)or 0
   item.color=if target then Palette.tint(item.originalColor,target,strength)else item.originalColor
   if item.role=="charm"then item.color=self.secondaryColor end
   item.part.Color=item.color
  end end
  Charms.apply(self,self.appearance);self.poseDirty=true
 end
 local update=visual.update
 function visual:update(dt)
  update(self,dt)
  for _,item in ipairs(self.pieces)do
   if item.colorRole then Face.paintSurface(item,self,Face.daylight())end
   if item.role=="charm"then item.part.Transparency=if self.charmVisible then 0 else 1 end
  end
 end
 visual:applyAppearance(appearance);return visual
end
return Adapter
