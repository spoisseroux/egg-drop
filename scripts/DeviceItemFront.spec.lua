-- Native measured six-tab rail, five shelves, private recipients and stale actions.
return function(client,parent)
 local Art=require(client.DeckArt);local View=require(client.HueEggView);local Hue=require(client.HueIntent)
 local Toy=require(client.ToyIntent);local Feature=require(client.FeatureIntent);local Shop=require(client.EggHatchView)
 local H=require(game.ReplicatedStorage.Shared.HueCatalog);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(900,720);root.Parent=parent
 local cases={};local sent={};local allowed=true;local view
 local function deps()return{id=function()return "front-fixture"end,delay=function()end,send=function(a,v)table.insert(sent,{action=a,value=v})end,changed=function()if view and view:isOpen()then view:refresh()end end}end
 local hue=Hue.new(deps());local toy=Toy.new(deps());local feature=Feature.new(deps())
 view=View.new(root,hue,{toyIntent=toy,featureIntent=feature,canCustomize=function()return allowed end,reduceEffects=function()return true end,appearance=function()return{charmVisible=false}end})
 local shop=Shop.new(root,{play=function()end,stopOwner=function()end},function()return true end,function()error("fixture must not buy")end)
 local function state()
  local hues={};local features={};for _,p in ipairs(Pets.collection)do hues[p.id]={main=H.emptyCounts(),secondary=H.emptyCounts()};features[p.id]={horns={earned=2,visible=1},claws={earned=0,visible=0},wings={earned=1,visible=0}}end
  return{status="Ready",revision=100,nectar=64,inventoryMask=127,petHues=hues,hueInventory={rose=3},materialAvailable=true,materialUnlocks={},toyUnlocks={ball=true,bone=true,sparkler=true},petToys={pip="ball",puddle="bone"},featureStock={horns=2,claws=1,wings=1},petFeatures=features}
 end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function test(n,f)f();table.insert(cases,n)end
 local function fit(n)assert(n.TextFits,n:GetFullName().." text clipped: "..n.Text)end
 -- The Features tab is hidden behind Shared.FeatureFlags (not removed): drive the panel directly.
 local function showFeatures()if not view:canCustomize()then return false end;view.tab="features";view:refresh();return view.featurePanel.root.Visible end
 local ok,problem=pcall(function()
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(390,740),Vector2.new(733,307),Vector2.new(600,360),Vector2.new(568,160)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle()
   test(tostring(size).." Customize icon tabs reachable both directions, Features hidden by the flag",function()
    allowed=true;assert(view:open(state(),"hue","pip"));settle()
    for _,order in ipairs({{"hue","charm","materials","toys"},{"toys","materials","charm","hue"}})do for _,id in ipairs(order)do
     view:setTab(id);settle();assert(view.tab==id,"tab not reached: "..id);local tab=view.editorTabs[id]
     assert(tab and tab.Visible,"tab missing: "..id)
     -- Portrait windows scale the 848 desktop panel down; 44 px targets hold in landscape.
     if size.X>size.Y then assert(tab.AbsoluteSize.X>=44 and tab.AbsoluteSize.Y>=44,id.." tab under 44 px at "..tostring(size))end
     -- A 160 px tall emulator window has no room for a choice grid under the header and tabs.
     if size.Y>=200 then assert(view.chromeGrid.AbsoluteSize.Y>=43.9,"tabs leave no usable 44 px choice window at "..tostring(size))end
    end end
    assert(not view:setTab("features")and view.editorTabs.features==nil and view.editorTabs.pet==nil)
    view:close()
   end)
   test(tostring(size).." five egg families disclose actual pool and full feature odds",function()
    local s=state();s.toyUnlocks={ball=true};shop:open(s);settle()
    for _,id in ipairs({"hue","material","toy"})do assert(shop:selectRecipe(id));settle();local card=shop.body.EggColumn["Recipe_"..id];assert(card and card.AbsoluteSize.X>=44);fit(card.RecipeName);fit(card.Cost)end
    -- Redesign 3: odds render once, in the pane; the Feature Egg row is hidden by the flag.
    shop:selectRecipe("toy");settle();local odds=shop.oddsHolder;assert(not odds:FindFirstChild("Odds_ball")and odds.Odds_bone:GetAttribute("OddsText")=="50%"and odds.Odds_sparkler:GetAttribute("OddsText")=="50%")
    assert(not shop:selectRecipe("feature")and shop.body.EggColumn:FindFirstChild("Recipe_feature")==nil)
    local feature={};for _,r in ipairs(shop.oddsRows("feature",s).rows)do feature[r.id]=r.value end
    assert(feature.horns=="50%"and feature.claws=="35%"and feature.wings=="15%");shop:close()
   end)
  end
  test("private unselected pet preview uses its own toy and visible feature stages",function()
   allowed=true;view:open(state(),"hue","puddle");local a=view:appearance();assert(a.toyId=="bone"and a.featureStages.horns==1 and a.featureStages.wings==0)
   assert(showFeatures()and view.featurePanel:preview("horns",5));assert(view:appearance().featureStages.horns==5 and #sent==0)
   assert(view:setTab("toys")and view:appearance().featureStages.horns==1)
  end)
  test("stale Toy and Feature handlers check live cradle before mutation",function()
   allowed=true;assert(view:setTab("toys"));assert(view:setTab("hue"));assert(not view.toyPanel:choose("ball")and #sent==0)
   assert(showFeatures());assert(view.featurePanel:requestUse("horns"));view:close()
   assert(not view.featurePanel:confirmUse()and not view.featurePanel:show("horns")and not view.featurePanel:preview("horns",3)and #sent==0,"closed still-docked feature row mutated")
   allowed=false;assert(not view.toyPanel:choose("bone")and not view.featurePanel:requestUse("horns")and not view.featurePanel:preview("horns",3)and not view.featurePanel:show("horns")and #sent==0)
   view:close()
  end)
  test("Toy receipt only chooses its exact owned recipient outside cradle",function()
   local s=state();s.pendingToyResult={id="saved-ball",toyId="ball",revision=100,catalogVersion=1};assert(view:open(s,"toyBuy","pip"));settle()
   view.toyAssignment={resultId="saved-ball",toyId="ball"};view.page="palette";view.tab="pet";view:refresh();assert(not view:setTab("charm")and not view:setTab("toys"))
   assert(view:choosePet("puddle"));local p=toy.pending;assert(p and p.value.petId=="puddle"and p.value.toyId=="ball"and p.value.resultId=="saved-ball")
  end)
 end)
 view:destroy();shop:close();shop.shade:Destroy();toy:destroy();feature:destroy();root:Destroy();assert(ok,problem);return cases
end
