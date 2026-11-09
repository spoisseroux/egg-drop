-- Authored upperbody weight transfer leaves the smooth root and planted feet alone.
return function(client)
 local Factory=require(client.PetFactory);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_WeightTransfer";folder.Parent=workspace;local visuals={};local cases={}
 local ok,err=pcall(function()
  for _,id in ipairs({"pip","puddle"})do
   local v=Factory.new(folder,Vector3.new(0,4,0),Pets.byId[id],.72);table.insert(visuals,v);v.greeting=2;v.gaitWeight=1
   for _,sample in ipairs({{.04,0},{.29,-1},{.54,0},{.79,1}})do
    v.gaitPhase=sample[1]*math.pi*2;v.poseDirty=true;local root=v.origin;v:update(0)
    assert(v.origin==root and math.abs(v.weightShift)<=.04501 and math.abs(v.weightRoll)<=math.rad(3)+.00001)
    if sample[2]==0 then assert(math.abs(v.weightShift)<.00001,"double support did not recenter")else assert(v.weightShift*sample[2]>.035,"hips did not move over support foot")end
   end
   v.reducedEffects=true;v.poseDirty=true;v:update(0);assert(v.weightShift==0 and v.weightRoll==0)
   table.insert(cases,id.." lateral weight/counter-roll bounded to support foot and suppressed by reduced motion")
  end
 end)
 for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,err);return cases
end
