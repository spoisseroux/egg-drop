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
 local ok,problem=pcall(function()
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(390,740),Vector2.new(733,307),Vector2.new(600,360),Vector2.new(568,160)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle()
   test(tostring(size).." all six tabs reachable both directions and active tab fully visible",function()
    allowed=true;assert(view:open(state(),"pet","pip"));settle()
    for _,order in ipairs({{"pet","hue","charm","materials","toys","features"},{"features","toys","materials","charm","hue","pet"}})do for _,id in ipairs(order)do
     assert(view:setTab(id));settle();local tab=view.editorTabs[id];local rail=view.tabRail;fit(tab)
     assert(tab.AbsoluteSize.X>=44 and tab.AbsoluteSize.Y>=44)
     local stroke=tab:FindFirstChildOfClass("UIStroke");local half=if stroke then stroke.Thickness*.5 else 0
     assert(tab.AbsolutePosition.Y-half>=rail.scroll.AbsolutePosition.Y and tab.AbsolutePosition.Y+tab.AbsoluteSize.Y+half<=rail.scroll.AbsolutePosition.Y+rail.scroll.AbsoluteSize.Y,"tab outline clipped vertically")
     assert(tab.AbsolutePosition.X>=rail.scroll.AbsolutePosition.X+5.9 and tab.AbsolutePosition.X+tab.AbsoluteSize.X<=rail.scroll.AbsolutePosition.X+rail.scroll.AbsoluteSize.X-5.9,"active tab obscured: "..id)
     assert(view.body.AbsoluteSize.Y>=43.9,"tabs leave no usable44px choice window")
    end end
    if view.tabRail.overflow then
     view.tabRail:scrollBy(-100);assert(not view.tabRail.left.Interactable and view.tabRail.right.Interactable)
     view.tabRail:scrollBy(100);assert(not view.tabRail.right.Interactable and view.tabRail.left.Interactable)
    end
    view:close()
   end)
   test(tostring(size).." five egg families disclose actual pool and full feature odds",function()
    local s=state();s.toyUnlocks={ball=true};shop:open(s);settle()
    for _,id in ipairs({"meadow","hue","material","toy","feature"})do assert(shop:selectRecipe(id));settle();local card=shop.body.EggColumn["Recipe_"..id];assert(card and card.AbsoluteSize.X>=44);fit(card.RecipeName);fit(card.Cost)end
    shop:selectRecipe("toy");settle();local column=shop.body.EggColumn;assert(not column:FindFirstChild("ToyOdds_ball")and column.ToyOdds_bone.Text:find("50%%")and column.ToyOdds_sparkler.Text:find("50%%"))
    shop:selectRecipe("feature");settle();column=shop.body.EggColumn
    assert(column.FeatureOdds_horns.Text:find("50%%")and column.FeatureOdds_claws.Text:find("35%%")and column.FeatureOdds_wings.Text:find("15%%"))
    assert(column.FeatureRules.Text:find("99",1,true)and column.FeatureRules.Text:find("no Stars",1,true));shop:close()
   end)
  end
  test("private unselected pet preview uses its own toy and visible feature stages",function()
   allowed=true;view:open(state(),"hue","puddle");local a=view:appearance();assert(a.toyId=="bone"and a.featureStages.horns==1 and a.featureStages.wings==0)
   assert(view:setTab("features")and view.featurePanel:preview("horns",5));assert(view:appearance().featureStages.horns==5 and #sent==0)
   assert(view:setTab("toys")and view:appearance().featureStages.horns==1)
  end)
  test("stale Toy and Feature handlers check live cradle before mutation",function()
   allowed=true;assert(view:setTab("toys"));assert(view:setTab("hue"));assert(not view.toyPanel:choose("ball")and #sent==0)
   assert(view:setTab("features"));assert(view.featurePanel:requestUse("horns"));view:close()
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
