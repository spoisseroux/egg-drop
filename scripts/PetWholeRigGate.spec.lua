-- Injected mesh outcomes prove lifetime/whole-swap logic; actual native asset download is separate.
return function(client)
 local Factory=require(client.PetFactory);local Readiness=require(client.PetAssetReadiness);local Affection=require(client.PetAffection);local Charms=require(client.PetCharms)
 local Shot=require(client.PetGreetingShot);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local folder=Instance.new("Folder");folder.Name="_WholeRigGate";folder.Parent=workspace
 local views,cases={},{};local function test(name,run)run();table.insert(cases,name)end
 local function make(id)
  local jobs={};local q=Readiness.new({load=function(parts,complete)table.insert(jobs,{parts=parts,complete=complete})end})
  local v=Factory.new(folder,Vector3.new(2000,4.025,0),Pets.byId[id],.72,{charmVisible=false},{readiness=q})
  table.insert(views,v);return v,jobs,q
 end
 local function has(v,name)for _,e in ipairs(v.pieces)do if e.name==name then return e end end end
 local ok,problem=pcall(function()
  test("synchronous Factory exposes complete faithful native head body limbs face and hidden charm until ready",function()
   local v,jobs=make("pip");assert(v.backend=="NativeRecipe"and #jobs==1)
   for _,name in ipairs({"Head","Body","HandL","HandR","FootL","FootR","EyeL","EyeR","MouthSmile","CharmDot"})do assert(has(v,name),name.." missing from whole fallback")end
   assert(has(v,"CharmDot").part.Transparency==1)
   jobs[1].complete(false,"DelayedHead");v:update(0);assert(v.backend=="NativeRecipe"and has(v,"Head").part.Parent)
  end)
  test("whole swap preserves visual/model pose and petting identity while atomically rebinding prompts and Saved adornment",function()
   local v,jobs=make("pip");local model,old=v.model,v.model.PrimaryPart
   local prompt=Instance.new("ProximityPrompt");prompt.Parent=old;local click=Instance.new("ClickDetector");click.Parent=old
   v.focusPose=true;v.petting=true;v.cosmeticSeed=42;v.cosmeticTime=123.45;v.time=3.25;v.greeting=.45;v.yaw=.6;v:update(0)
   local affection=Affection.new(folder);affection:setPet(v);affection:showSaved(true)
   local remaining=affection.awardUntil;local origin=v.origin;local changed=0
   v.onRigChanged=function(_,body)changed+=1;assert(old.Parent and body.Parent);affection:rebind(v)end
   Shot.captureFocusedSubject(v);local previousCache=v.focusEnvelopeCache
   jobs[1].complete(true);v:update(0)
   assert(v.backend=="AuthoredMesh"and v.model==model and old.Parent==nil and v.rigRevision==1 and changed==1)
   assert(prompt.Parent==model.PrimaryPart and click.Parent==model.PrimaryPart and affection.award.Adornee==model.PrimaryPart)
   assert(affection.award.Enabled and affection.awardUntil==remaining,"Saved cue restarted or retired")
   assert(v.petting and v.focusPose and v.origin==origin and v.yaw==.6 and v.time==3.25 and v.greeting==.45 and v.cosmeticSeed==42 and v.cosmeticTime==123.45)
   assert(v.poseSlots[1].entry==v.pieces[1]and v.focusEnvelopeCache~=previousCache)
   assert(has(v,"CharmDot").part.Transparency==1);affection:destroy()
  end)
  test("destroying or equipping away before a delayed completion cannot resurrect geometry",function()
   local v,jobs=make("puddle");local model=v.model;v:destroy();jobs[1].complete(true)
   assert(model.Parent==nil and v.destroyed and not v.assetReady)
   local nextPet=make("wick");assert(nextPet.petId=="wick"and has(nextPet,"Head"))
  end)
  test("template revision changing during load keeps whole fallback until the new exact template succeeds",function()
   local v,jobs=make("puddle");local source=v.assetSource;local old=source:GetAttribute("TemplateRevision")
   local success,why=pcall(function()
    source:SetAttribute("TemplateRevision",(old or 0)+1);jobs[1].complete(true);v:update(0)
    assert(v.backend=="NativeRecipe"and #jobs==2 and has(v,"Head"))
    jobs[2].complete(true);v:update(0);assert(v.backend=="AuthoredMesh"and v.rigRevision==1)
   end)
   source:SetAttribute("TemplateRevision",old);assert(success,why)
  end)
  test("lazy charm forms prepare against the new piece set after a whole swap, hidden and visible",function()
   local v,jobs=make("wick")
   for _,shape in ipairs({"dot","ring","pebble","dot"})do v:applyAppearance({charmVisible=true,charmShape=shape})end
   local slots=v.poseSlots;local frame=slots[1].entry.part.CFrame
   jobs[1].complete(true);v:update(0);assert(v.backend=="AuthoredMesh"and v.poseSlots~=slots)
   assert(slots[1].entry.part.Parent==nil,"old sampler entry survived")
   for _,visible in ipairs({true,false,true})do for _,shape in ipairs({"dot","ring","pebble","dot"})do
    v:applyAppearance({charmVisible=visible,charmShape=shape});local count=0
    for _,e in ipairs(v.pieces)do if e.role=="charm"then
     local showing=Charms.isVisible(v,e)
     if showing then
      count+=1;assert((e.charmShape or "dot")==shape and e.part:IsDescendantOf(v.model),"prepared flag refers to old geometry")
      if e.decals then assert(#e.decals==2 and e.decals[1].Transparency==0 and e.decals[2].Transparency==0,"ring fallback lost a face")else assert(e.part.Transparency==0,"selected charm lost visible geometry")end
     else
      assert(e.part.Transparency==1,"inactive geometry survived whole swap")
      for _,decal in ipairs(e.decals or {})do assert(decal.Transparency==1,"inactive alpha geometry survived whole swap")end
     end
    end end
    assert(count==(if not visible then 0 elseif shape=="pebble"then 2 else 1),"prepared flag refers to old geometry")
   end end
  end)
 end)
 for _,v in ipairs(views)do v:destroy()end;folder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
