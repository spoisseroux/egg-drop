-- Client-only factory fixture. No ownership/remotes/rewards/lighting/camera changes.
-- Caller owns the clock and must destroy returned owner. Frozen modules can be injected.
return function(client,options)
 options=options or {};local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_PetAffectionShowcase";folder.Parent=workspace
 local owner={folder=folder,visuals={}};local origin=options.origin or Vector3.new(2000,4.025,0)
 for i,pet in ipairs(Pets.collection)do
  local family=pet.family or pet.id
  local module=if family=="pip"then options.pip or client.PipVisual elseif family=="puddle"then options.puddle or client.PuddleVisual else options.bonus or client.BonusPetVisual
  local at=if options.origins then options.origins[i]else origin+Vector3.new(((i-1)%4)*3,0,math.floor((i-1)/4)*3.5)
  local v=require(module).new(folder,at,pet,.72);v.yaw=options.yaw or 0;v.reducedEffects=options.reduced==true
  if options.rank then require(options.prestige or client.PetPrestige).attach(v,pet,options.rank,false)end
  v:update(0);owner.visuals[i]=v
 end
 function owner:step(dt)
  for _,v in ipairs(self.visuals)do v:update(dt);if options.rank then require(options.prestige or client.PetPrestige).update(v,dt,options.reduced==true)end end
 end
 function owner:destroy()for _,v in ipairs(self.visuals)do v:destroy()end;folder:Destroy()end
 return owner
end
