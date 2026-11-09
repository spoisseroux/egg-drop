-- Receipt use can choose an owned recipient away from a cradle; it cannot
-- become a general customization route. No remotes or account writes.
return function(client,parent)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent)
 local H=require(game.ReplicatedStorage.Shared.HueCatalog);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(900,720);root.Parent=parent
 local cases={};local view;local sent={};local allowed=false
 local intent=Intent.new({id=function()return "receipt-route-use"end,send=function(a,v)table.insert(sent,{action=a,value=v})end,changed=function()end})
 view=View.new(root,intent,{canCustomize=function()return allowed end,appearance=function()return{charmVisible=false}end,charm=function()error("receipt escaped into Charm")end})
 local function snapshot(withResult)
  local hues={};for _,pet in ipairs(Pets.collection)do hues[pet.id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
  return {status="Ready",revision=100,nectar=40,inventoryMask=127,petHues=hues,hueInventory={rose=3,tide=2,citrus=1,iris=1,reset=2},pendingHueResult=if withResult then{id="exact-jar",itemId="rose",quantity=1,inventoryAfter=3,revision=100,catalogVersion=H.CatalogVersion}else nil}
 end
 local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local ok,problem=pcall(function()
  settle()
  test("undocked ordinary editor refuses to open",function()assert(not view:open(snapshot(false),"pet","pip")and not view:isOpen())end)
  test("saved result chooses only its exact owned recipient and Hue channel",function()
   assert(view:open(snapshot(true),"pet","pip"));settle();assert(view.page=="receipt"and view:useResult());settle()
   assert(view:choosePet("puddle")and view.assignment.pendingResultId=="exact-jar")
   assert(not view:setTab("charm")and not view:setTab("materials")and not view:requestCharm(true,"ring"))
   assert(not view:chooseItem("tide")and not view:requestLegacy("tide"))
   assert(view:chooseChannel("secondary")and view.confirmation.itemId=="rose"and view.confirmation.pendingResultId=="exact-jar")
   assert(view:cancelConfirmation()and view.assignment.pendingResultId=="exact-jar")
   assert(view:setTab("pet")and view:setTab("hue")and #sent==0)
  end)
  test("lost or acknowledged receipt closes outside cradle instead of showing stock",function()
   intent:update(snapshot(false));view:refresh();assert(not view:isOpen())
   assert(not view:setTab("materials")and not view:choosePet("pip")and not view:chooseItem("rose")and #sent==0)
  end)
  test("stale material choice checks cradle at activation time",function()
   local panel=view.materialPanel;local count=0
   panel.intent={equip=function()count+=1;return true end}
   allowed=true;assert(panel:chooseFinish("gloss")and count==1)
   allowed=false;assert(not panel:chooseFinish("matte")and count==1)
   panel.intent=nil
  end)
  test("live cradle permission permits ordinary customization and its loss closes it",function()
   allowed=true;assert(view:open(snapshot(false),"pet","pip"));assert(view:setTab("charm")and view:setTab("materials"))
   allowed=false;view:refresh();assert(not view:isOpen()and not view:requestCharm(true,"ring"))
  end)
 end)
 view:destroy();root:Destroy();assert(ok,problem);return cases
end
