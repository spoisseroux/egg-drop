-- Native geometry and downloaded authored rigs use the same attachment contract.
return function(client,parent)
 local fixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install actual authored readiness helper")
 require(fixture)(client)
 local Factory=require(client.PetFactory);local Play=require(client.PetPlayVisual)
 local Toys=require(client.PetToyGeometry);local Features=require(client.PetFeatureGeometry);local Bounds=require(client.PetRigBounds)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local root=Instance.new("Folder");root.Name="_PersonalPlay";root.Parent=parent or workspace
 local visuals,cases={},{};local function test(name,run)run();table.insert(cases,name)end
 local function appearance(stage,toy,generation)return{charmVisible=true,charmShape="dot",toyId=toy or "none",appearanceGeneration=generation or 1,featureStages={horns=stage,claws=stage,wings=stage}}end
 local function make(pet,native,stage,toy)
  local v=Factory.new(root,Vector3.new(0,4,0),pet,.72,appearance(stage or 0,toy),{native=native});table.insert(visuals,v)
  v.reducedEffects=true;v:update(0);return v
 end
 local ok,problem=pcall(function()
  test("shared hero handles have exact bounded lifetimes without physics queries lights or emitters",function()
   assert(not Toys.create(root,"none")and not Features.create(root,"horns",0))
   for _,id in ipairs({"sparkler","ball","bone"})do
    local h=assert(Toys.create(root,id,1));assert(#h.parts<=8)
    h:pivot(CFrame.new(4,5,6));for _,p in ipairs(h.parts)do assert(p.Anchored and not p.CanQuery and not p.CanTouch and not p.CanCollide)end
    assert(not h.model:FindFirstChildWhichIsA("PointLight",true)and not h.model:FindFirstChildWhichIsA("ParticleEmitter",true))
    h:destroy();h:destroy();assert(not h.model.Parent)
   end
  end)
  for _,native in ipairs({true,false})do for _,pet in ipairs(Pets.collection)do
   test(pet.id..(if native then " native"else " authored").." stages grow from fixed roots and replace idempotently",function()
    local v=make(pet,native);assert(v.backend==(if native then "NativeRecipe"else "AuthoredMesh"))
    local original=#v.pieces;local primary=v.model.PrimaryPart;local beforeHeight=select(2,Bounds.get(v)).Y;local count;local rooted={};local priorHeight=beforeHeight
    for _,stage in ipairs({1,3,5})do
     v:applyAppearance(appearance(stage));v:update(0)
     local features=0
     for _,e in ipairs(v.pieces)do if e.role=="feature"then features+=1;assert(not e.part.CanQuery and e.part.Anchored and e.part.Transparency==0)end end
     assert(features==24 and #v.pieces==original+24 and v.model.PrimaryPart==primary)
     for _,e in ipairs(v.pieces)do if e.name=="Feature_horns1L"or e.name=="Feature_claws1L"or e.name=="Feature_wings1L"then
      if rooted[e.name]then assert((rooted[e.name]-e.frame.Position).Magnitude<.000001,"feature root drifted with stage")end;rooted[e.name]=e.frame.Position
     end end
     local height=select(2,Bounds.get(v)).Y;assert(height>=priorHeight-.00001);priorHeight=height
     local n=#v.model:GetDescendants();for _=1,12 do v:applyAppearance(appearance(stage));v:update(0)end;assert(#v.model:GetDescendants()==n)
     if count then assert(#v.pieces==count)end;count=#v.pieces
    end
    assert(select(2,Bounds.get(v)).Y>=beforeHeight and v.featureHaloLift>=0)
    local featureRevision=v.featureRevision;v:applyAppearance(appearance(0));v:update(0)
    assert(v.featureRevision>featureRevision and #v.pieces==original and v.featureHaloLift==0)
    for _,h in ipairs(v.featureHandles)do assert(false,"zero stage retained a feature handle")end
   end)
  end end
  test("each toy uses one prop and stops on every live interruption including reduced motion",function()
   for _,id in ipairs({"sparkler","ball","bone"})do
    local v=make(Pets.collection[1],true,0,id);v.reducedEffects=false;v.personalPlayEnabled=true;v.cosmeticSeed=1;v.greeting=2;v.gardenBehavior="follow"
    for _,case in ipairs({{"gaitWeight",.5},{"focusPose",true},{"gardenFocus",true},{"careState","Docked"},{"gardenBehavior","rest"},{"gardenAction","greet"},{"personalPlayEnabled",false}})do
     v.gaitWeight=0;v.focusPose=false;v.gardenFocus=false;v.careState=nil;v.gardenBehavior="follow";v.gardenAction=nil;v.personalPlayEnabled=true
     Play.reset(v);v.cosmeticTime=0;v:update(0);v.cosmeticTime=1.0;v:update(0)
     assert(v.personalToy and v.personalToyActive and #v.personalToy.parts<=8,id.." failed to begin")
     if id=="sparkler"then local e=v.personalToy.emitter;assert(e and e:IsA("ParticleEmitter")and e.Parent==v.personalToy.tip and v.personalToy.tip.Material==Enum.Material.Neon)end
     local prop,deadline=v.personalToy,v.personalNextOpportunity
     v[case[1]]=case[2];v:update(0);assert(not v.personalToy and prop.destroyed,case[1].." failed to cancel")
     assert(v.personalNextOpportunity==deadline,case[1].." reset opportunity cooldown")
    end
    v.personalPlayEnabled=true;v.gardenAction=nil;v.gardenBehavior="follow";v.reducedEffects=true;Play.reset(v)
    v.cosmeticTime=0;v:update(0);v.cosmeticTime=1.0;v:update(0);assert(v.personalToyActive and v.personalToyPhase==.43)
    v:applyAppearance(appearance(0,"none",2));assert(not v.personalToy)
   end
  end)
  test("matching owner and visitor seeds share phase without a prop network clock",function()
   local a=make(Pets.collection[1],true,0,"ball");local b=make(Pets.collection[1],true,0,"ball")
   for _,v in ipairs({a,b})do v.personalPlayEnabled=true;v.cosmeticSeed=42;v.greeting=2;v.reducedEffects=false;v.cosmeticTime=100;v:update(0);v.cosmeticTime=103.5;v:update(0)end
   assert(a.personalToyActive and b.personalToyActive and a.personalToyPhase==b.personalToyPhase)
   a.personalActorIdentity="replacement";a:update(0);assert(not a.personalToy and b.personalToy)
  end)
 end)
 for _,v in ipairs(visuals)do v:destroy()end;root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
