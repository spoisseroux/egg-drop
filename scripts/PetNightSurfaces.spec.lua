-- Native role materials/fill ownership; actual color/lighting remains rendered QA.
return function(client)
 local Factory=require(client.PetFactory);local Visual=require(client.GardenPetVisual);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Hue=require(game.ReplicatedStorage.Shared.HueCatalog)
 local Face=require(client.PetFace);local Clock=require(client.HollowClock);local prior=Clock.lastDaylight;local folder=Instance.new("Folder");folder.Name="_NightRoles";folder.Parent=workspace
 local cases={};local visuals={};local ok,err=pcall(function()
  for _,pet in ipairs(Pets.collection)do
   Clock.lastDaylight=0
   local a={mainDoses=Hue.emptyCounts(),secondaryDoses=Hue.emptyCounts(),charmVisible=true};a.mainDoses.rose=5;a.secondaryDoses.tide=5
   local v=Visual.new(folder,Vector3.new(0,4,0),pet,.72,a,{native=true});table.insert(visuals,v);v:update(0)
   local highlights,lights=0,0
   for _,node in ipairs(v.model:GetDescendants())do if node:IsA("Highlight")then highlights+=1;assert(node.DepthMode==Enum.HighlightDepthMode.Occluded and node.OutlineTransparency==1)elseif node:IsA("PointLight")or node:IsA("SpotLight")or node:IsA("SurfaceLight")then lights+=1 end end
   assert(highlights==2 and lights==0,"unbounded role lighting "..pet.id)
   for _,e in ipairs(v.pieces)do if (e.colorRole=="body"or e.colorRole=="secondary")and e.role~="charm"then assert(e.part.Material==Enum.Material.SmoothPlastic,"broad Neon "..pet.id.." "..e.part.Name)else assert(e.part.Parent==v.model,"face/sculpt grouped into pigment fill")end end
   assert(v.nightGroups.body.fill.FillColor==v.colors.body and v.nightGroups.secondary.fill.FillColor==v.colors.secondary)
   assert(math.abs(v.nightGroups.body.fill.FillTransparency-.70)<.00001 and math.abs(v.nightGroups.secondary.fill.FillTransparency-.72)<.00001)
   a.charmVisible=false;v:applyAppearance(a);v:update(0)
   for _,e in ipairs(v.pieces)do if e.role=="charm"then assert(e.part.Parent==v.model and e.part.Transparency==1,"hidden Dot remains in adornment")end end
   Clock.lastDaylight=1;v.poseDirty=true;v:update(0);assert(not v.nightGroups.body.fill.Enabled and not v.nightGroups.secondary.fill.Enabled)
   table.insert(cases,pet.id.." shaded broad surfaces/two bounded fills/protected identity/hidden Dot/day recovery")
  end
 end)
 Clock.lastDaylight=prior;for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,err);return cases
end
