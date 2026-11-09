-- All four item receipts share one art/copy stage and pinned functional actions.
return function(client,parent)
 local View=require(client.HueEggView);local Hue=require(client.HueIntent);local Material=require(client.MaterialIntent)
 local Toy=require(client.ToyIntent);local Feature=require(client.FeatureIntent)
 local H=require(game.ReplicatedStorage.Shared.HueCatalog);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local root=Instance.new("Frame");root.Parent=parent;local view;local cases={}
 local function deps()return{id=function()return "composition-fixture"end,delay=function()end,send=function()error("layout must not send")end,changed=function()end}end
 local hue,material,toy,feature=Hue.new(deps()),Material.new(deps()),Toy.new(deps()),Feature.new(deps())
 view=View.new(root,hue,{materialIntent=material,toyIntent=toy,featureIntent=feature,reduceEffects=function()return true end,appearance=function()return{charmVisible=false}end})
 local function state(kind)
  local hues={};for _,p in ipairs(Pets.collection)do hues[p.id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
  local s={status="Ready",revision=10,nectar=48,inventoryMask=127,petHues=hues,hueInventory={rose=3},materialAvailable=true,materialUnlocks={gloss=true},toyUnlocks={bone=true},featureStock={horns=2},petFeatures={}}
  if kind=="hue"then s.pendingHueResult={id="receipt-hue",itemId="rose",revision=10,catalogVersion=H.CatalogVersion}
  elseif kind=="material"then s.pendingMaterialResult={id="receipt-material",finishId="gloss",revision=10,catalogVersion=1}
  elseif kind=="toy"then s.pendingToyResult={id="receipt-toy",toyId="bone",revision=10,catalogVersion=1}
  else s.pendingFeatureResult={id="receipt-feature",featureId="horns",revision=10,catalogVersion=1}end
  return s
 end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function fit(n)assert(n.TextFits,n:GetFullName().." clipped: "..n.Text)end
 local ok,problem=pcall(function()
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(390,740),Vector2.new(733,307),Vector2.new(568,160)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle()
   for _,kind in ipairs({"hue","material","toy","feature"})do
    assert(view:open(state(kind),kind.."Buy","pip"));settle();view:layout();settle()
    local panel=if kind=="material"then view.materialPanel elseif kind=="toy"then view.toyPanel elseif kind=="feature"then view.featurePanel else nil
    local art=if panel then panel.art else view.receiptArt;local copy=if panel then panel.note else view.receipt
    local use=if panel then panel.useNow else view.useNow
    assert(math.abs(art.AbsoluteSize.X-art.AbsoluteSize.Y)<.1)
    if size.Y>=420 then
     assert(art.AbsoluteSize.X>=184 and art.AbsoluteSize.X<=208,"receipt art did not use bounded200px stage")
     assert(copy.AbsolutePosition.Y>=art.AbsolutePosition.Y+art.AbsoluteSize.Y+7.9)
    else
     assert(art.AbsoluteSize.X<=110.1 and art.AbsoluteSize.Y<=view.body.AbsoluteSize.Y+.1)
     assert(copy.AbsolutePosition.X>=art.AbsolutePosition.X+art.AbsoluteSize.X+7.9,"short receipt lost side-by-side composition")
    end
    if panel then assert(not panel.title.Visible,"receipt duplicates its fixed header")else assert(not view.receiptDetail.Visible)end
    fit(view.title);fit(copy);fit(use);fit(view.action)
    assert(use.Parent==view.card and use.AbsoluteSize.Y>=44 and view.action.AbsoluteSize.Y>=44)
    assert(use.AbsolutePosition.Y==view.action.AbsolutePosition.Y and use.AbsolutePosition.X+use.AbsoluteSize.X<=view.action.AbsolutePosition.X-7.9)
    table.insert(cases,tostring(size).."/"..kind.." one bounded stage one copy and pinned Use now Store")
    view:close()
   end
  end
 end)
 view:destroy();material:destroy();toy:destroy();feature:destroy();root:Destroy();assert(ok,problem);return cases
end
