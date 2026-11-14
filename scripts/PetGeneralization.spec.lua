-- Studio Client. Overnight 2026-11-14 slice E (SYSTEMS-SCOPE 1.2, 1.7): "one pet" is generalized.
--  * Every `"pip"` string literal left in the client sits on an allowlisted line (the
--    rig-specific R rows and the legacy L rows of the scope table). A new one fails here.
--  * Companions hub: only pets that are active (a rig in this build) are selector cards, and
--    without a companion the hub shows the first owned active pet.
--  * Wardrobe: open(nil) and open(<a pet without wearables>) land on the first active pet
--    that has items; no pet is named in the module.
--  * Customize (HueEggView) and the legacy DeckMenu start on the first active pet.
-- The server half of the literal check (src/server) cannot be read from a client; lane S
-- covers it. Module Sources need the Studio command context (as ClientLocalBudget does).
-- Usage: require(PlayerScripts.Client.ZZSpecs.PetGeneralization)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Pets=require(Shared.PetCatalog)
 local Catalog=require(Shared.WearableCatalog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_PetGeneralizationSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 -- Allowlist: module name -> substrings; a line with a "pip" literal must contain one.
 -- R = names a rig behaviour, L = legacy / retired-pet compatibility (scope table 1.2).
 local allowed={
  DeckMenu={'FamilyCrest.create(host, "pip"'},                -- L #37: the crest is family art
  FamilyCrest={'else "pip"','family == "pip"'},               -- L #37
  GardenPetVisual={'self.petId=="pip"then math.cos'},         -- R #34: the Bear's walk squash
  HatchCinematic={'(pet.family or pet.id)=="pip"'},           -- R + L #33: hatch greeting pose
  PetPortrait={'pet.id == "pip"'},                            -- D #36: the Bear's portrait accent
  RoomView={'family=="pip"or family=="puddle"then 2'},        -- R #32: legacy rig greeting capture
  CareFeedbackData={"JSONDecode"},                            -- generated data blob
 }
 local ok,problem=xpcall(function()
  test("every \"pip\" literal in the client is on an allowlisted line",function()
   local scripts={client}
   for _,d in ipairs(client:GetDescendants())do
    if d:IsA("LuaSourceContainer")and not d:FindFirstAncestor("ZZSpecs")then table.insert(scripts,d)end
   end
   local found=0
   for _,module in ipairs(scripts)do
    local source=module.Source
    local number=0
    for line in string.gmatch(source.."\n","([^\n]*)\n")do
     number+=1
     if string.find(line,'"pip"',1,true)or string.find(line,"'pip'",1,true)then
      found+=1
      local fine=false
      for _,piece in ipairs(allowed[module.Name]or {})do if string.find(line,piece,1,true)then fine=true end end
      assert(fine,module.Name..":"..number.." names the Bear: "..string.sub(line,1,120))
     end
    end
   end
   assert(found>=1,"the scan read the sources")
  end)
  test("Companions hub: selector cards are owned AND active; no companion falls to the first owned active pet",function()
   local Hub=require(client.CompanionsHub)
   local every=bit32.lshift(1,#Pets.collection)-1
   local cards=Hub.petCards({inventoryMask=every},Pets.active[1].id)
   assert(#cards==#Pets.active,"one card per active pet ("..#cards.." vs "..#Pets.active..")")
   for _,card in ipairs(cards)do assert(Pets.isActive(card.id),card.id.." is not active")end
   assert(cards[1].following==true and cards[1].id==Pets.active[1].id)
   assert(#Hub.petCards({inventoryMask=0},nil)==0 and #Hub.petCards(nil,nil)==0)
   -- A retired pet that is owned is never a card (it cannot be drawn as the companion).
   for _,pet in ipairs(Pets.collection)do
    if not Pets.isActive(pet)then
     assert(#Hub.petCards({inventoryMask=bit32.lshift(1,pet.index-1)},nil)==0,pet.id.." listed while inactive")
    end
   end
   assert(Hub.firstOwned({inventoryMask=every})==Pets.active[1].id)
   assert(Hub.firstOwned({inventoryMask=0})==Pets.active[1].id and Hub.firstOwned(nil)==Pets.active[1].id,"a fresh save still has a pet to draw")
  end)
  test("Companions hub built without a companion id shows the first owned active pet",function()
   local Hub=require(client.CompanionsHub)
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(1280,720);host.Parent=gui
   local opened={}
   local hub=Hub.new(host,{appearance=function()return{}end,open=function(row,petId)table.insert(opened,{row,petId});return true end})
   assert(hub:open({wallet=5,state={inventoryMask=1}}));settle()
   assert(hub:petId()==Pets.active[1].id and hub.petName.Text==Pets.active[1].name)
   hub:focusRow(2);hub:act()
   assert(opened[1]and opened[1][1]=="wardrobe"and opened[1][2]==Pets.active[1].id,"rows open on the shown pet")
   hub:destroy();host:Destroy()
  end)
  test("Wardrobe: no pet until asked; open(nil) and open(<no wearables>) pick the first active pet with items",function()
   local Shop=require(client.WardrobeShop)
   local first=Shop.firstPet()
   assert(first~=nil and Pets.isActive(first)and Catalog.hasItems(first),"an active pet sells wearables")
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(1280,720);host.Parent=gui
   local shop=Shop.new(host,{appearance=function()return{}end})
   assert(shop.petId==first,"built on the first active pet with items")
   shop:open(nil,{wallet=10,row={owned={},equipped={}}});settle()
   assert(shop:isOpen()and shop.petId==first and #shop.tiles>0,"open(nil)")
   shop:close()
   shop:open("no_such_pet",{wallet=10,row={owned={},equipped={}}});settle()
   assert(shop.petId==first,"a pet without wearables falls back")
   shop:close()
   for _,pet in ipairs(Pets.collection)do
    if Catalog.hasItems(pet.id)then
     shop:open(pet.id,{wallet=10,row={owned={},equipped={}}});settle()
     assert(shop.petId==pet.id and shop.root:GetAttribute("FocusedItem")~=nil,pet.id.." opens on its own items")
     shop:close()
    end
   end
   assert(#Shop.tileList(nil,"Hat")==0,"no pet, no cards")
   shop:destroy();host:Destroy()
  end)
  test("Customize and the legacy menu start on the first active pet",function()
   local source=client.HueEggView.Source
   assert(string.find(source,"petId=(Pets.active[1]or Pets[1]).id",1,true),"HueEggView's first pet comes from the catalogue")
   assert(string.find(client.DeckMenu.Source,"Pets.active[1]or Pets[1]",1,true),"DeckMenu falls back to the first active pet")
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
