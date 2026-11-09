-- Retired ranks never reserve room above a companion or create status FX.
return function(client)
 local Factory=require(client.PetFactory);local Prestige=require(client.PetPrestige)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Parent=workspace
 local cases={};local board=Instance.new("Folder");board:SetAttribute("MasteryRanks",'{"pip":3,"puddle":2}');board:SetAttribute("MasteryMask",15)
 local ok,problem=pcall(function()
  for _,pet in ipairs(Pets.collection)do
   for rank=0,3 do
    local visual=Factory.create(folder,Vector3.new(2000,4.025,0),pet,15,rank,true)
    local actual,legacy=Prestige.read(board,pet);assert(actual==0 and legacy==false)
    assert(Prestige.crestReserve(visual)==0 and not visual.prestigeBadge and not visual.masteryEmitter)
    Prestige.update(visual,10,false);Prestige.updateBadge(visual,workspace.CurrentCamera)
    for _,node in ipairs(visual.model:GetDescendants())do
     assert(node.Name~="FamilyPrestigeBadge"and node.Name~="FamilyAccentFinish"and node.Name~="FamilyFlourish")
    end
    visual:destroy()
   end
   table.insert(cases,pet.id.." ignores all archived rank and legacy FX inputs")
  end
 end)
 board:Destroy();folder:Destroy();assert(ok,problem);return cases
end
