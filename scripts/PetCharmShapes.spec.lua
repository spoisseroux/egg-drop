-- No profile writes: retained forms, visibility, pigment and opaque future-ID fallbacks.
return function(client)
 local readyFixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install the real authored-readiness QA helper beside this spec")
 require(readyFixture)(client)
 local Factory=require(client.PetFactory);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Hue=require(game.ReplicatedStorage.Shared.HueCatalog)
 local folder=Instance.new("Folder");folder.Name="_CharmShapes";folder.Parent=workspace;local visuals,cases={},{}
 local ok,err=pcall(function()
  for _,pet in ipairs(Pets.collection)do
   local a={charmVisible=true,charmShape="dot",secondaryDoses=Hue.emptyCounts()};a.secondaryDoses.tide=5
   local v=Factory.new(folder,Vector3.new(0,4,0),pet,.72,a);table.insert(visuals,v);v.reducedEffects=true;v:update(0)
   local original=#v.pieces;local bodySize=v.bodyBoundsSize;local countBy={dot=1,ring=1,pebble=2}
   for _,shape in ipairs({"ring","pebble","dot","future_spiral"})do
    a.charmShape=shape;v:applyAppearance(a);v:update(0);local rendered=if shape=="future_spiral"then "dot"else shape;local live=0
    for _,e in ipairs(v.pieces)do if e.role=="charm"then
     assert(e.color==Hue.ById.tide.color and not e.part.CanQuery)
     if e.charmShape=="ring"then
      if e.charmBackend=="mask"then
       assert(e.decals[1].Face==Enum.NormalId.Top and e.decals[2].Face==Enum.NormalId.Bottom)
       assert(math.abs(e.size.X-e.size.Z)<.000001 and e.size.Y<e.size.X*.25)
      else
       assert(math.abs(e.size.X-e.size.Y)<.000001 and e.size.Z<e.size.X*.25)
       assert(math.abs(e.frame.LookVector.Y)>.99,"torus normal must face up")
      end
     end
     local expected=(e.charmShape or "dot")==rendered
     local visible=if e.charmBackend=="mask"then e.decals[1].Transparency==0 else e.part.Transparency==0
     expected=expected and(e.charmBackend~="mask"or not v.charmRingBound)and(e.charmBackend~="mesh"or v.charmRingBound==true)
     assert(visible==expected,"inactive shape visible "..pet.id)
     if expected then live+=1 else assert(e.part.Parent==v.model,"inactive charm bleeds role fill")end
    end end
    assert(live==countBy[rendered]and v.charmShape==shape and v.bodyBoundsSize==bodySize)
   end
   local count=#v.pieces;assert(count>=original+3 and count<=original+4,"unbounded form cache")
   a.charmVisible=false;v:applyAppearance(a);v:update(0)
   for _,e in ipairs(v.pieces)do if e.role=="charm"then assert(e.part.Transparency==1 and e.part.Parent==v.model)end end
   for _=1,20 do a.charmVisible=true;a.charmShape="ring";v:applyAppearance(a);a.charmShape="pebble";v:applyAppearance(a)end
   assert(#v.pieces>=count and #v.pieces<=original+4)
   table.insert(cases,pet.name.." selected free form, opaque fallback, independent tint/hidden hull and bounded cache")
  end
 end)
 for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,err);return cases
end
