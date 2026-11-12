-- All-seven palette/blink/shape integration; this is binding and pose proof, not GPU QA.
return function(client)
 local Materials=require(client.PetMaterials);assert(Materials.start()=="AuthoredPackAvailable","Authored pack missing")
 local readyFixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"));require(readyFixture)(client)
 local Factory=require(client.PetFactory);local Clock=require(client.HollowClock);local prior=Clock.lastDaylight
 local Shared=game.ReplicatedStorage.Shared;local Pets=require(Shared.PetCatalog);local Hue=require(Shared.HueCatalog);local Palette=require(Shared.PetPalette)
 local folder=Instance.new("Folder");folder.Name="_MaterialExpressions";folder.Parent=workspace
 -- BasePart stores byte-quantized Color, unlike the logical saved Color3.
 -- Use an independently assigned native Part as the exact readback control;
 -- a broad epsilon could accidentally permit a wrong pigment or treatment.
 local colorControl=Instance.new("Part");colorControl.Name="ByteColorControl";colorControl.Anchored=true;colorControl.Transparency=1;colorControl.CanCollide=false;colorControl.CanQuery=false;colorControl.Parent=folder
 local cases,visuals={},{}
 local ok,problem=pcall(function()
  Clock.lastDaylight=0
  for _,pet in ipairs(Pets.collection)do
   local a={mainDoses=Hue.emptyCounts(),secondaryDoses=Hue.emptyCounts(),charmVisible=true,charmShape="dot"}
   a.mainDoses.rose=3;a.mainDoses.citrus=2;a.secondaryDoses.tide=5
   local v=Factory.new(folder,Vector3.new(2000,4,0),pet,.72,a);table.insert(visuals,v);v.reducedEffects=true;v:update(0)
   local count=#v.pieces;local expected=Palette.resolve(pet.id,a)
   -- Two-tone rigs (v1 Bear): body parts keep Main on the part and carry Secondary on the surface tint.
   local function checkBody(e,palette,why)
    if v.twoTone and e.colorRole=="body"then
     colorControl.Color=palette.body
     assert(e.materialSurface.Color==palette.secondary,why.." (two-tone surface must carry Secondary)")
     assert(e.part.Color==colorControl.Color,why.." (two-tone part must carry Main)")
    else assert(e.materialSurface.Color==palette[e.colorRole],why)end
   end
   for _,e in ipairs(v.pieces)do
    if e.colorRole=="body"or e.colorRole=="secondary"then checkBody(e,expected,"mixed material tint differs from saved palette")end
   end
   v.expression="affectionate";v:update(0)
   for _,e in ipairs(v.pieces)do if e.faceRole=="spark"then assert(e.part.Transparency==1,"catchlight floats over closed eye")end end
   v.expression="neutral";v:update(0)
   for _,e in ipairs(v.pieces)do
    if e.faceRole=="spark"then assert(e.part.Transparency==0 and e.part.Color==e.faceBaseColor and e.materialSurface.Color==e.faceBaseColor,"authored pale catchlight dimmed")end
    if e.name=="EyeL"or e.name=="EyeR"then
     -- A textured authored eye (v1 Bear) keeps its own texture and gets no finish surface.
     if e.part:IsA("MeshPart")and e.part.TextureID~=""then assert(e.materialSurface==nil and e.part.Material~=Enum.Material.Neon,"textured eye got a finish surface or glows")
     else assert(e.materialSurface.EmissiveStrength==0 and e.materialSurface.Color==e.color,"eye identity/emission changed")end
    end
   end
   for _,shape in ipairs({"ring","pebble","dot"})do
    a.charmShape=shape;v:applyAppearance(a);v:update(0)
    for _,e in ipairs(v.pieces)do if e.role=="charm"then
     local selected=require(client.PetCharms).isVisible(v,e)
     local visible=if e.decals then e.decals[1].Transparency==0 else e.part.Transparency==0
     assert(visible==selected and e.part.Parent==v.model)
     if selected and shape=="pebble"then
      assert(not e.materialSurface and e.part.Material==Enum.Material.Neon,"primitive shape falsely claims PBR")
      local c=expected.secondary;local requested=Color3.new(c.R*.40,c.G*.40,c.B*.40);colorControl.Color=requested
      assert(e.color==c,"fallback changed logical saved Secondary")
      assert(e.part.Color==colorControl.Color,string.format("%s/%s fallback byte color differs: requested=%s control=%s actual=%s",pet.id,e.name,tostring(requested),tostring(colorControl.Color),tostring(e.part.Color)))
     end
     if not selected then assert(e.part.Material~=Enum.Material.Neon and(not e.materialSurface or e.materialSurface.EmissiveStrength==0),"inactive charm emits")end
    end end
   end
   assert(#v.pieces>=count+3 and #v.pieces<=count+4,"unbounded charm retention")
   a.charmVisible=false;v:applyAppearance(a)
   for _,e in ipairs(v.pieces)do if e.role=="charm"then assert(e.part.Transparency==1 and e.part.Material~=Enum.Material.Neon and(not e.materialSurface or e.materialSurface.EmissiveStrength==0))end end
   a.mainDoses=Hue.emptyCounts();v:applyAppearance(a)
   local reset=Palette.resolve(pet.id,a);assert(reset.body==Palette.original(pet.id).body)
   for _,e in ipairs(v.pieces)do if e.colorRole=="body"then checkBody(e,reset,"Main reset did not restore the original body")end end
   local preview=Factory.new(folder,Vector3.zero,pet,nil,a);table.insert(visuals,preview)
   assert(not preview.worldContext and not preview.model:FindFirstChildWhichIsA("Highlight",true))
   local previewPalette=Palette.resolve(pet.id,a)
   for _,e in ipairs(preview.pieces)do if e.materialSurface then
    -- Two-tone body surfaces carry the logical Secondary; every other surface carries its own logical color.
    local want=if preview.twoTone and e.colorRole=="body"then previewPalette.secondary else e.color
    assert(e.materialSurface.Color==want,"preview logical palette mismatch")
   end end
   table.insert(cases,pet.name.." mixed tint/reset, closed/open catchlight, shape glow/hide and preview logical parity")
  end
 end)
 Clock.lastDaylight=prior;for _,v in ipairs(visuals)do v:destroy()end;folder:Destroy();assert(ok,problem);return cases
end
