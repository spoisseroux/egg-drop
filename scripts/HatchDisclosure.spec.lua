-- Real typed view/adapter/cinematic callbacks. No remotes or profile writes.
return function(client,parent)
 local View=require(client.HueEggView);local Hue=require(client.HueIntent)
 local Copy=require(game.ReplicatedStorage.Shared.UICopy);local H=require(game.ReplicatedStorage.Shared.HueCatalog)
 local Run=game:GetService("RunService");local gui=Instance.new("ScreenGui");gui.Name="_DisclosureSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(812,354);root.Parent=gui
 local view;local sent=0;local deps={id=function()return "unused"end,delay=function()end,send=function()sent+=1 end,changed=function()if view then view:refresh()end end}
 local hue=Hue.new(deps);local toy=require(client.ToyIntent).new(deps);local material=require(client.MaterialIntent).new(deps)
 view=View.new(root,hue,{toyIntent=toy,materialIntent=material,canCustomize=function()return false end,reduceEffects=function()return false end})
 local cases={};local serial=tostring(os.clock());local function test(name,run)run();table.insert(cases,name)end
 local function state(kind,id)
  id=serial..id
  local s={revision=1,status="Ready",inventoryMask=1,nectar=0,restricted=false,hueInventory={rose=1},petHues={pip={main=H.emptyCounts(),secondary=H.emptyCounts()}},
   toyUnlocks={ball=true},petToys={},materialUnlocks={jelly=true},petMaterials={}}
  if kind=="hue"then s.pendingHueResult={id=id,itemId="rose",catalogVersion=H.CatalogVersion,revision=1};view.purchaseInFlight=id
  elseif kind=="toy"then s.pendingToyResult={id=id,toyId="ball",catalogVersion=1,revision=1};view.toyPurchaseInFlight=id
  else s.pendingMaterialResult={id=id,finishId="jelly",catalogVersion=1,revision=1};view.materialPurchaseInFlight=id end
  return s
 end
 local function adapter(kind)return if kind=="hue"then view.itemReveal elseif kind=="toy"then view.toyPanel.reveal else view.materialPanel.reveal end
 local function waitPresented(c)
  local untilTime=os.clock()+4
  repeat c:disconnectClock();Run.Heartbeat:Wait()until c.presented or os.clock()>untilTime
  c:disconnectClock();assert(c.presented,"production renderer did not present an item/fallback")
 end
 local function paint(c,age)c:disconnectClock();c.active=true;c.age=age;c:paint();view:refresh();c:disconnectClock()end
 local ok,problem=pcall(function()
  for _,kind in ipairs({"toy","hue","material"})do
   test(kind.." headers and accessibility wait for the shared receipt beat",function()
    local s=state(kind,"disclosure-"..kind);view:open(s,kind,"pip");local reveal=adapter(kind);local c=reveal.cinematic;assert(c);waitPresented(c)
    for _,age in ipairs({.7,1.25,2.15})do
     paint(c,age);assert(view.title.Text==Copy.get("hatch.display.wait")and view.title:GetAttribute("AccessibleLabel")==view.title.Text)
     assert(view.shade:GetAttribute("ResultIdentityReady")==false and reveal.parent:GetAttribute("ResultIdentityReady")==false)
     if kind~="hue"then local p=if kind=="toy"then view.toyPanel else view.materialPanel;assert(p.title.Text==view.title.Text)end
     local graphic=c:getItemGraphic();if graphic then for _,n in ipairs(graphic:GetDescendants())do
      local label=n:GetAttribute("AccessibleLabel");if label then assert(label==Copy.get("hatch.display.wait"),"art accessible identity leaked")end
     end end
    end
    c.age=2.2;c:paint();c:complete()
    assert(view.shade:GetAttribute("ResultIdentityReady")==true,"completion did not repaint outer title")
    assert(view.title.Text==(if kind=="toy"then "Ball unlocked!"elseif kind=="material"then "Jelly unlocked!"else "Rose jar"))
    view:layoutTransaction();assert(view.title:GetAttribute("AccessibleLabel")==view.title.Text,"layout override lost title identity")
    view:close("fixture")
   end)
  end
  test("skip and settled reopen disclose together; new id stays fenced",function()
   local s=state("toy","disclosure-skip");view:open(s,"toys","pip");local reveal=view.toyPanel.reveal;local c=reveal.cinematic;waitPresented(c);paint(c,.7)
   assert(reveal:skip()and view.title.Text=="Ball unlocked!")
   view:close("fixture");view:open(s,"toys","pip");waitPresented(reveal.cinematic);view:refresh()
   assert(view.title.Text=="Ball unlocked!"and reveal:identityReady(s.pendingToyResult))
   s=state("toy","disclosure-new");view:open(s,"toys","pip");assert(view.title.Text==Copy.get("hatch.display.wait"))
  end)
 end)
 view:destroy();toy:destroy();material:destroy();gui:Destroy();assert(ok,problem);assert(sent==0,"presentation sent a transaction");return{passed=#cases,cases=cases}
end
