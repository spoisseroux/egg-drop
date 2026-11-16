-- Studio Client. QA v760 (Customize, new item): opened as Customize, the view never replays a
-- hatch receipt. A result that is still waiting is stored quietly (one typed request at a
-- time) and its card carries a NEW badge until it is tapped or worn. Opened from a hatch
-- flow (or without the game's `quietOpen` mark) the receipt shows as before.
-- Real HueEggView, HueIntent, ToyIntent and MaterialIntent; injected snapshots, no remotes.
-- Usage: require(PlayerScripts.Client.ZZSpecs.CustomizeNewItem)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local View=require(client.HueEggView);local Hue=require(client.HueIntent);local Toy=require(client.ToyIntent)
 local Material=require(client.MaterialIntent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Toys=require(Shared.ToyCatalog);local Hues=require(Shared.HueCatalog);local Materials=require(Shared.MaterialCatalog)
 local gui=Instance.new("ScreenGui");gui.Name="_CustomizeNewItem";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function copy(value)if type(value)~="table"then return value end;local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result end
 local function fixture(change)
  local c={sent={}}
  local root=Instance.new("Frame");root.Size=UDim2.fromOffset(812,354);root.BackgroundTransparency=1;root.Parent=gui;c.root=root
  local view
  local serial=0
  local function id()serial+=1;return "op"..serial end
  local function send(action,value)table.insert(c.sent,{action=action,value=value})end
  local function changed()if view then view:refresh()end end
  c.hue=Hue.new({id=id,send=send,changed=changed})
  c.toy=Toy.new({id=id,delay=function()end,send=send,changed=changed})
  c.material=Material.new({id=id,delay=function()end,send=send,changed=changed})
  view=View.new(root,c.hue,{toyIntent=c.toy,materialIntent=c.material,reduceEffects=function()return true end})
  c.view=view
  c.state={revision=2,status="Ready",inventoryMask=1,nectar=4,toyUnlocks={ball=true},petToys={},
   hueInventory={rose=0},petHues={pip={main=Hues.emptyCounts(),secondary=Hues.emptyCounts()}},
   materialUnlocks={},petMaterials={},featureStock={},petFeatures={},materialAvailable=true,
   pendingToyResult={id="toy-result",toyId="ball",revision=2,catalogVersion=Toys.CatalogVersion}}
  if change then change(c.state)end
  function c:update(state)self.hue:update(state);self.toy:update(state);self.material:update(state)end
  function c:card(name)
   for _,node in ipairs(root:GetDescendants())do if node.Name==name and node:IsA("GuiButton")then return node end end
  end
  return c
 end
 local ok,problem=pcall(function()
  test("opened as Customize: the cards, the item's tab, one quiet ack, a NEW badge; no receipt",function()
   local c=fixture();local view=c.view
   view.quietOpen=true
   assert(view:open(c.state,"palette","pip")~=false and view.shade.Visible,"Customize opens")
   settle()
   assert(view.page=="palette"and view.tab=="toys","lands on the Toys cards, got "..tostring(view.page).." / "..tostring(view.tab))
   assert(#c.sent==1 and c.sent[1].action=="toyAck"and c.sent[1].value.resultId=="toy-result","one quiet toyAck, got "..#c.sent)
   assert(view.quietOpen==nil,"the mark is used once")
   local card=c:card("Toy_ball");assert(card and card:GetAttribute("IsNew")==true,"the Ball card is NEW")
   local badge=card:FindFirstChild("NewBadge",true);assert(badge and badge.Visible and badge.Text.Text=="NEW","badge drawn")
   -- The save lands: the result is gone, the toy is owned, the badge stays until a tap.
   local saved=copy(c.state);saved.revision=3;saved.pendingToyResult=nil
   saved.lastToyResult={id=c.sent[1].value.id,action="toyAck",revision=3,catalogVersion=Toys.CatalogVersion,cost=0,acknowledgedResultId="toy-result",balanceBefore=4,balanceAfter=4}
   c:update(saved);settle()
   assert(view.shade.Visible and view.page=="palette"and #c.sent==1,"stays on the cards and sends nothing more")
   assert(c:card("Toy_ball"):GetAttribute("IsNew")==true,"still NEW after the store")
   -- First tap (or focus move) on the card clears it.
   assert(view:seenItem("toys","ball")==true and view:isNewItem("toys","ball")==false,"a tap clears the badge")
   view:layout();settle()
   assert(c:card("Toy_ball"):GetAttribute("IsNew")==false and not c:card("Toy_ball"):FindFirstChild("NewBadge",true).Visible,"badge gone")
   view:close("back")
  end)
  test("a worn item is never NEW; a second visit sends nothing",function()
   local c=fixture(function(s)s.pendingToyResult=nil;s.petToys={pip="ball"}end);local view=c.view
   view.newItems["toys:ball"]=true
   view.quietOpen=true;view:open(c.state,"toys","pip");settle()
   assert(#c.sent==0 and view.page=="palette","nothing waiting, nothing sent")
   assert(c:card("Toy_ball"):GetAttribute("IsNew")==false and view.newItems["toys:ball"]==nil,"worn clears the mark")
   view:close("back")
  end)
  test("two waiting results are stored one request at a time",function()
   local finish=Materials.Order[2]or Materials.Order[1]
   local c=fixture(function(s)s.pendingMaterialResult={id="material-result",finishId=finish,revision=2,catalogVersion=Materials.CatalogVersion}end)
   local view=c.view
   view.quietOpen=true;view:open(c.state,"palette","pip");settle()
   assert(view.page=="palette"and #c.sent==1,"one request first, got "..#c.sent)
   local first=c.sent[1].action
   assert(first=="materialAck"or first=="toyAck","a quiet ack, got "..tostring(first))
   assert(view:isNewItem("toys","ball")and view.newItems["materials:"..tostring(finish)]==true,"both are marked NEW")
   view:close("back")
  end)
  test("a hatch flow and an unmarked open keep the receipt",function()
   local c=fixture();local view=c.view
   view:open(c.state,"toys","pip");settle()
   assert(view.page=="toyReceipt"and #c.sent==0,"unmarked open shows the receipt, got "..tostring(view.page))
   view:close("back")
   view.quietOpen=true;view:open(c.state,"toyBuy","pip");settle()
   assert(view.page=="toyReceipt"and #c.sent==0,"the Hatch eggs page shows the receipt, got "..tostring(view.page))
   view:close("back")
  end)
 end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
