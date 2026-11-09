-- Two independent replication orders; the cosmetic seam never supplies intent identity.
return function(client)
 local Garden=require(client.GardenClient);local Follow=require(client.PetFollow);local Factory=require(client.PetFactory)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local L=require(game.ReplicatedStorage.Shared.GardenCareLayout)
 local cases={};local owners={};local folder=Instance.new("Folder");folder.Parent=workspace
 local function test(name,run)run();table.insert(cases,name)end
 local function actor(id,generation)
  return {ownerId=123,petId=id,characterId=4,petGeneration=generation,generation=9,mode="Docked",behavior="rest",action="dock",actionId=10,
   from={L.Dock.X,L.Dock.Y,L.Dock.Z},to={L.Dock.X,L.Dock.Y,L.Dock.Z},startTime=0,endTime=1,yaw=0,care={state="Docked",holderId=123,characterId=4,claimId="bay-A"}}
 end
 local function fixture(boardPet,boardGeneration,snapshotPet,snapshotGeneration)
  local boards=Instance.new("Folder");boards.Parent=folder;local board=Instance.new("Folder");board.Name="123";board.Parent=boards
  board:SetAttribute("Mode","Room");board:SetAttribute("CompanionId",boardPet);board:SetAttribute("CompanionGeneration",boardGeneration)
  local character=Instance.new("Model");character:SetAttribute("GardenCharacterId",4);character.Parent=folder
  local state=Instance.new("Folder");state.Name="GardenState";state.Parent=folder
  local g=Garden.new(boards,{playerId=123,folder=state});table.insert(owners,g)
  g.snapshot={version=1,revision=1,toy={},actors={['123']=actor(snapshotPet,snapshotGeneration)},careBay={id="bay-A",ownerId=123,characterId=4,petId=snapshotPet,petGeneration=snapshotGeneration}}
  return g,board,character
 end
 local ok,problem=pcall(function()
  test("board-first saved equip has a fixed bay pose while strict intent identity remains unavailable",function()
   local g,_,character=fixture("puddle",2,"pip",1)
   assert(g:get(123,"puddle",character)==nil)
   local render=g:renderActor(123,"puddle",character)
   assert(render and render.cosmeticCareGap and render.petId=="puddle"and render.care.claimId=="bay-A")
   assert(g.snapshot.actors['123'].petId=="pip"and g.snapshot.actors['123'].petGeneration==1,"render normalization mutated authority")
  end)
  test("snapshot-first saved equip retains old visible identity at same bay until board arrives",function()
   local g,_,character=fixture("pip",1,"puddle",2)
   assert(g:get(123,"pip",character)==nil)
   local render=g:renderActor(123,"pip",character)
   assert(render and render.cosmeticCareGap and render.petId=="pip"and render.petGeneration==1)
   assert(g.snapshot.actors['123'].petId=="puddle"and g.snapshot.actors['123'].petGeneration==2)
  end)
  test("actual fresh visitor factory starts at Dock before normal-motion first frame in either order",function()
   for _,order in ipairs({{"puddle",2,"pip",1},{"pip",1,"puddle",2}})do
    local g,_,character=fixture(table.unpack(order))
    local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.Position=Vector3.new(30,7,30);root.Parent=character
    local humanoid=Instance.new("Humanoid");humanoid.Parent=character
    local player={UserId=123,Character=character};local captured,created
    local companions=require(client.RoomCompanions).new(g.boards,function(_,position,pet,_,_,_,appearance)
     captured=position;created=Factory.new(folder,position,pet,.72,appearance,{native=true});return created
    end,function()return false end,{players=function()return{player}end,localRoot=function()return root end,garden=g})
    table.insert(owners,{destroy=function()companions:clear()end})
    companions:update(1/60,1)
    assert(captured==L.Dock and created and created.careFrom==L.Dock,"fresh visitor factory used avatar follow origin")
    assert((created.origin-L.Dock).Magnitude<.0001 and created.careState=="Docked"and created.gaitWeight==0 and not created.reducedEffects)
   end
  end)
  test("actual owner showPet factory seeds saved dock identity before normal first draw",function()
   local Room=require(client.RoomView)
   for _,order in ipairs({{"puddle",2,"pip",1},{"pip",1,"puddle",2}})do
    local g,board,character=fixture(table.unpack(order));board:SetAttribute("InventoryMask",127)
    local heading=Instance.new("TextLabel");heading.Parent=folder;local captured
    local owner={progress=board,heading=heading,garden={renderActor=function()return g:renderActor(123,order[1],character)end,appearance=function()return{charmVisible=true}end},
     reduceEffects=function()return false end,setPetContact=function()end,refreshPetAppearance=function()end,updateControls=function()end,
     createPet=function(_,position,pet,_,_,_,appearance)captured=position;return Factory.new(folder,position,pet,.72,appearance,{native=true})end}
    Room.showPet(owner,Pets.byId[order[1]]);table.insert(owners,owner.pet)
    assert(captured==L.Dock and owner.pet.origin==L.Dock and owner.pet.careFrom==L.Dock and owner.pet.careState=="Docked"and owner.pet.greeting>=1.2)
   end
  end)
  test("character replacement and another owner's claim cannot reuse a cached dock pose",function()
   local g,_,character=fixture("puddle",2,"pip",1)
   character:SetAttribute("GardenCharacterId",5);assert(not g:renderActor(123,"puddle",character))
   character:SetAttribute("GardenCharacterId",4);g.snapshot.careBay={id="bay-B",ownerId=456,characterId=4}
   assert(not g:renderActor(123,"puddle",character))
  end)
  test("converged equipment uses the exact actor and actual bay retirement removes normalization",function()
   local g,board,character=fixture("puddle",2,"pip",1)
   local exact=actor("puddle",2);g.snapshot.actors['123']=exact;g.snapshot.careBay.petId="puddle";g.snapshot.careBay.petGeneration=2
   assert(g:get(123,"puddle",character)==exact and g:renderActor(123,"puddle",character)==exact and not exact.cosmeticCareGap)
   exact.mode="Room";exact.action="follow";exact.behavior="follow";exact.care=nil;g.snapshot.careBay=nil
   assert(g:renderActor(123,"puddle",character)==exact and not exact.care)
   board:SetAttribute("CompanionGeneration",3);assert(not g:renderActor(123,"puddle",character))
  end)
 end)
 for _,owner in ipairs(owners)do owner:destroy()end;folder:Destroy();assert(ok,problem);return {passed=#cases,cases=cases}
end
