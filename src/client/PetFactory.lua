-- Common aliases preserve profile identity while selecting the new authored babies.
local Factory={}
function Factory.new(parent,origin,pet,worldScale,appearance)
 return require(script.Parent.PetPoseSampler).attach(require(script.Parent.GardenPetVisual).new(parent,origin,pet,worldScale,appearance))

end
function Factory.create(parent,origin,pet,masteryMask,rank,legacy,appearance)
 local visual=Factory.new(parent,origin,pet,.72,appearance)
 require(script.Parent.PetPrestige).attach(visual,pet,rank or 0,legacy)
 return visual
end
return Factory
