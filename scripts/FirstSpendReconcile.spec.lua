-- Actual HueIntent.changed -> HueEggView.refresh/close -> ToyIntent.changed order.
-- Native GUI/real typed intents; injected owner snapshots, no remotes/profile writes.
return function(client,parent)
 local View=require(client.HueEggView);local Hue=require(client.HueIntent);local Toy=require(client.ToyIntent)
 local Guide=require(client.FirstSpendGuide);local Shared=game:GetService("ReplicatedStorage").Shared
 local Toys=require(Shared.ToyCatalog);local Hues=require(Shared.HueCatalog)
 local gui=Instance.new("ScreenGui");gui.Name="_FirstSpendReconcile";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local fixtures,cases={},{};local function test(name,run)run();table.insert(cases,name)end
 local function copy(value)if type(value)~="table"then return value end;local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result end
 local function fixture()
  local c={entered=0,played=0,sent=0,events={}};table.insert(fixtures,c)
  local root=Instance.new("Frame");root.Size=UDim2.fromOffset(812,354);root.Parent=gui;c.root=root
  local view,guide;local internal=false
  local hue=Hue.new({id=function()return "hue-unused"end,send=function()error("unexpected Hue write")end,
   changed=function()if view then table.insert(c.events,"hue-changed");view:refresh()end end})
  local toy=Toy.new({id=function()return "reconcile-equip"end,delay=function()end,
   send=function(action)assert(action=="toyEquip");c.sent+=1 end,
   changed=function(intent)
    if guide then table.insert(c.events,"toy-changed");guide:update(intent.state,{eligible=true})end
    if view then view:refresh()end
   end})
  guide=Guide.new({intent=toy,actorIdentity=function()return "character:pet1"end,
   enterRoom=function()
    c.entered+=1;table.insert(c.events,"enter-room")
    internal=true;view:close("first-toy");internal=false
   end,play=function()c.played+=1;return true end})
  view=View.new(root,hue,{toyIntent=toy,canCustomize=function()return false end,reduceEffects=function()return true end,
   routeChanged=function(kind,reason)
    table.insert(c.events,kind..":"..tostring(reason))
    if not internal then guide:routeChanged(kind,reason)end
   end})
  c.view,c.guide,c.hue,c.toy=view,guide,hue,toy
  c.state={revision=2,status="Ready",inventoryMask=1,nectar=0,toyUnlocks={ball=true},petToys={},
   hueInventory={},petHues={pip={main=Hues.emptyCounts(),secondary=Hues.emptyCounts()}},
   materialUnlocks={},petMaterials={},featureStock={},petFeatures={},
   pendingToyResult={id="first-purchase",toyId="ball",revision=2,catalogVersion=Toys.CatalogVersion},
   lastToyResult={id="first-purchase",action="toyBuy",resultId="first-purchase",toyId="ball",revision=2,
    catalogVersion=Toys.CatalogVersion,cost=Toys.Cost,balanceBefore=Toys.Cost,balanceAfter=0}}
  view:open(c.state,"toys","pip");assert(view.shade.Visible and guide.stage=="receipt")
  assert(guide:give("pip")and c.sent==1);c.flight=guide.flight;c.generation=guide.generation
  c.saved=copy(c.state);c.saved.revision=3;c.saved.pendingToyResult=nil;c.saved.petToys.pip="ball"
  c.saved.lastToyResult={id=c.flight.operationId,action="toyEquip",petId="pip",toyId="ball",revision=3,
   catalogVersion=Toys.CatalogVersion,cost=0,selectedBefore="none",selectedAfter="ball",acknowledgedResultId="first-purchase"}
  c.events={}
  return c
 end
 local ok,problem=pcall(function()
  test("automatic close before typed Saved preserves exactly one validated handoff",function()
   local c=fixture();c.hue:update(c.saved)
   assert(not c.view.shade.Visible and table.find(c.events,"receipt-reconciled:receipt-finished"),"real automatic close did not run")
   assert(c.guide.flight==c.flight and c.guide.generation==c.generation and c.flight.phase=="equip"and c.entered==0)
   assert(c.toy.pending and c.toy.status=="Pending","Hue callback manufactured Toy Saved")
   c.toy:update(c.saved)
   assert(c.toy.status=="Saved"and not c.toy.pending and c.entered==1 and c.flight.phase=="room")
   assert(c.guide:step({mode="Room",ready=true,petId="pip",actorReady=true,actorIdentity="character:pet1"})and c.played==1)
   c.toy:update(c.saved);c.hue:update(c.saved)
   assert(c.entered==1 and c.played==1 and not c.guide.flight and c.sent==1)
  end)
  test("explicit closes and stale operations cancel; automatic close never weakens Saved proof",function()
   for _,kind in ipairs({"back","same-reason","tab","focus","stale-operation","wrong-saved"})do
    local c=fixture()
    if kind=="back"then c.view:close("back")
    elseif kind=="same-reason"then c.view:close("receipt-finished")
    elseif kind=="tab"then c.guide:routeChanged("tab")
    elseif kind=="focus"then c.guide:routeChanged()
    elseif kind=="stale-operation"then c.toy.pending.value.id="other-operation"
    elseif kind=="wrong-saved"then c.saved.lastToyResult.acknowledgedResultId="other-purchase"end
    c.hue:update(c.saved);c.toy:update(c.saved)
    assert(c.entered==0 and c.played==0,kind.." inherited a saved handoff")
    if kind=="wrong-saved"then assert(c.toy.pending and c.toy.status~="Saved"and c.guide.flight==c.flight)
    else assert(c.guide.flight==nil,kind.." did not cancel the current flight")end
   end
  end)
 end)
 for _,c in ipairs(fixtures)do c.guide:destroy();c.toy:destroy();c.view:destroy();c.root:Destroy()end
 gui:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
