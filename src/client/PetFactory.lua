-- Common aliases preserve profile identity while selecting the new authored babies.
local Factory={}
function Factory.new(parent,origin,pet,worldScale,appearance)
 if pet.id=="pip"or pet.id=="puddle"then return require(script.Parent.PetPoseSampler).attach(require(script.Parent.GardenPetVisual).new(parent,origin,pet,worldScale,appearance))end
 local family=pet.family or pet.id
 local module=if family=="pip"then script.Parent.PipVisual elseif family=="puddle"then script.Parent.PuddleVisual else script.Parent.BonusPetVisual
 local visual=require(module).new(parent,origin,pet,worldScale)
 return require(script.Parent.PetPoseSampler).attach(require(script.Parent.LegacyPetAppearance).attach(visual,pet,appearance))
end
function Factory.create(parent,origin,pet,masteryMask,rank,legacy,appearance)
 local visual=Factory.new(parent,origin,pet,.72,appearance)
 require(script.Parent.PetPrestige).attach(visual,pet,rank or 0,legacy)
 return visual
end
return Factory
