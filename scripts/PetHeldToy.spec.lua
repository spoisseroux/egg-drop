-- QA v685 R8: pets always hold their equipped toy while idling or walking
-- (PetPlayVisual.renderHeld, PetToyGeometry.Hold). Fixture pets in workspace; no remotes.
-- Needs the PetAssetsReadyFixture helper beside it in ZZSpecs (as PetPersonalPlay does).
-- Run (Client): require(Client.ZZSpecs.PetHeldToy)(Client)
return function(client,parent)
 local fixture=assert(script.Parent:FindFirstChild("PetAssetsReadyFixture"),"Install actual authored readiness helper")
 require(fixture)(client)
 local Factory=require(client.PetFactory);local Play=require(client.PetPlayVisual);local Toys=require(client.PetToyGeometry)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Catalog=require(game.ReplicatedStorage.Shared.ToyCatalog)
 local root=Instance.new("Folder");root.Name="_PetHeldToy";root.Parent=parent or workspace
 local visuals,cases={},{};local function test(name,run)run();table.insert(cases,name)end
 local function appearance(toy,generation)return{charmVisible=false,charmShape="dot",toyId=toy or "none",appearanceGeneration=generation or 1,featureStages={horns=0,claws=0,wings=0}}end
 local function make(toy,scale)
  local v=Factory.new(root,Vector3.new(0,4,0),Pets.collection[1],scale,appearance(toy),{native=true});table.insert(visuals,v)
  v.reducedEffects=true;v.cosmeticTime=0;v:update(0);return v
 end
 local function heldModel(v)
  for _,child in ipairs(v.model:GetChildren())do if child.Name:sub(1,8)=="HeldToy_"then return child end end
  return nil
 end
 local ok,problem=pcall(function()
  test("every toy has a hold: an offset inside one body height and an arm fold",function()
   for _,id in ipairs(Catalog.Order)do
    if id~=Catalog.Default then
     local hold=Toys.Hold[id];assert(hold,"no hold for "..id)
     assert(typeof(hold.offset)=="Vector3"and hold.offset.Magnitude<=.2 and typeof(hold.turn)=="CFrame"and hold.fold>0 and hold.fold<=1,id)
     assert(Toys.hold(id)==hold)
    end
   end
   assert(Toys.hold("no_such_toy")==Toys.DefaultHold)
  end)
  test("a world pet carries its toy in the model, by its hand, with the arm raised",function()
   for _,id in ipairs(Catalog.Order)do
    if id~=Catalog.Default then
     local v=make(id,.72)
     local held=assert(v.heldToy,id.." is not carried");local model=assert(heldModel(v),id.." has no carried model")
     assert(held.model==model and model.Name=="HeldToy_"..id and #held.parts<=Toys.PartLimit)
     for _,p in ipairs(held.parts)do assert(p.Anchored and not p.CanQuery and not p.CanTouch and not p.CanCollide)end
     local seats=Play.seats(v);local hand=seats.right or seats.left
     assert((held.model.PrimaryPart.Position-hand.part.Position).Magnitude<=seats.height*.45,id.." is not by the hand")
     assert(v.toyHoldFold==Toys.hold(id).fold,id.." arm is not raised")
     assert(not v.personalToy and not v.personalToyActive,"carrying is not a play clip")
     if id=="sparkler"then assert(held.emitter.Enabled==false and held.glow.Enabled==false,"a carried sparkler is unlit")end
    end
   end
  end)
  test("it stays in the hand walking, sitting and focused; one prop only",function()
   local v=make("ball",.72);local held=v.heldToy
   for _,case in ipairs({{"gaitWeight",.5},{"focusPose",true},{"gardenFocus",true},{"gardenBehavior","rest"},{"gardenAction","nookRest"}})do
    v[case[1]]=case[2];v.poseDirty=true;v:update(1/30)
    assert(v.heldToy==held and held.model.Parent==v.model,case[1].." dropped the toy")
    v[case[1]]=nil
   end
   local count=0;for _,child in ipairs(v.model:GetChildren())do if child.Name:sub(1,8)=="HeldToy_"then count+=1 end end
   assert(count==1)
  end)
  test("it is put down when carried, in the care machine, on park equipment and for the shared toy",function()
   local v=make("bone",.72)
   -- The shared garden toy (retired, but still a rule): checked on the rule itself.
   for _,action in ipairs({"toyReturn","shove"})do v.gardenAction=action;assert(not Play.holds(v),action);v.gardenAction=nil end
   assert(Play.holds(v))
   for _,case in ipairs({{"careState","Docked"},{"careState","Carried"},{"parkPose",true}})do
    assert(v.heldToy,"not carried before "..case[1])
    v[case[1]]=case[2];v.poseDirty=true;v:update(0)
    assert(not v.heldToy and not heldModel(v)and v.toyHoldFold==0,case[1].."="..tostring(case[2]).." kept the toy")
    v[case[1]]=nil;v.poseDirty=true;v:update(0)
    assert(v.heldToy and heldModel(v),"not picked up again after "..case[1])
   end
  end)
  test("no toy, a toy change and a destroyed pet leave nothing behind",function()
   local v=make("none",.72);assert(not v.heldToy and not heldModel(v)and v.toyHoldFold==0)
   v:applyAppearance(appearance("ball",2));v.poseDirty=true;v:update(0)
   local first=assert(v.heldToy);assert(first.id=="ball")
   v:applyAppearance(appearance("pocket_deck",3));v.poseDirty=true;v:update(0)
   assert(first.destroyed and v.heldToy and v.heldToy.id=="pocket_deck"and heldModel(v).Name=="HeldToy_pocket_deck")
   v:applyAppearance(appearance("none",4));v.poseDirty=true;v:update(0);assert(not v.heldToy and not heldModel(v))
   v:applyAppearance(appearance("ball",5));v.poseDirty=true;v:update(0);local last=assert(v.heldToy)
   v:destroy();assert(last.destroyed)
  end)
  test("a play clip shows its own prop and the carried one steps out, then returns",function()
   local v=make("sparkler",.72);v.reducedEffects=false;v.personalPlayEnabled=true;v.cosmeticSeed=1;v.greeting=2;v.gardenBehavior="follow"
   Play.reset(v);v.cosmeticTime=0;v:update(0);assert(v.heldToy and v.heldToy.model.Parent==v.model)
   v.cosmeticTime=1.0;v.poseDirty=true;v:update(0)
   assert(v.personalToyActive and v.personalToy,"the clip did not begin")
   assert(v.heldToy and v.heldToy.model.Parent==nil,"two props at once")
   v.gaitWeight=.5;v.poseDirty=true;v:update(0)
   assert(not v.personalToy and v.heldToy and v.heldToy.model.Parent==v.model,"the toy did not return to the hand")
  end)
  test("menu and card previews stay bare unless they ask",function()
   local v=make("ball",nil);assert(not v.worldContext and not v.heldToy)
   v.holdToyAlways=true;v.poseDirty=true;v:update(0);assert(v.heldToy,"the inspect card preview shows the toy")
  end)
 end)
 for _,v in ipairs(visuals)do if not v.destroyed then v:destroy()end end;root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
