-- QA prerequisite for tests that specifically assert the downloaded authored backend.
-- This uses the real production loader, never injects success or hides a denied mesh.
return function(client,ids,timeout)
 local Factory=require(client.PetFactory);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_AuthoredReadyPrerequisite"
 local visuals={};local ok,problem=pcall(function()
  for _,pet in ipairs(Pets.collection)do
   if not ids or table.find(ids,pet.id)then table.insert(visuals,Factory.new(folder,Vector3.zero,pet,.72,{charmVisible=false}))end
  end
  local deadline=os.clock()+(timeout or 30)
  while true do
   local ready=true
   for _,v in ipairs(visuals)do v:update(0);if v.backend~="AuthoredMesh"then ready=false end end
   if ready then break end
   assert(os.clock()<deadline,"Required authored mesh backend did not become ready within the bounded fixture wait")
   task.wait(.05)
  end
  for _,v in ipairs(visuals)do assert(v.backend=="AuthoredMesh","Authored assertion must not become a fallback assertion")end
 end)
 for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,problem)
 return true
end
