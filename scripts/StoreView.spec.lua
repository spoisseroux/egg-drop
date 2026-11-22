-- Studio Client. "Get Stars" in the Toy Shell look (restyle 2026-11-21,
-- STORE-RESTYLE-PLAN-2026-11-21.md): offer order, honest states, the one Buy key,
-- server-only prompts, results, the Hatch eggs entry and Back. Fixture only: every
-- request goes to a local recorder, never to a remote.
-- Usage: require(PlayerScripts.Client.ZZSpecs.StoreView)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Store=require(client.StoreView);local Shop=require(client.EggHatchView);local Kit=require(client.DeckKit)
 local Run=game:GetService("RunService");local Gui=game:GetService("GuiService")
 local gui=Instance.new("ScreenGui");gui.Name="_StoreViewSpec";gui.ResetOnSpawn=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local root=Instance.new("Frame");root.Name="Root";root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Parent=gui
 do local anchor=Instance.new("Frame");anchor.Parent=root;Kit.screenProbe(anchor);anchor:Destroy()end
 local cases,sent={},{}
 local view=Store.new(root,{request=function(action,key)table.insert(sent,{action,key})end,geometry=Shop.shopGeometry})
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local function test(name,run)run();table.insert(cases,name)end
 local function snapshot(options)
  options=options or {}
  local available=options.available~=false
  local function product(key,name,price,stars,once)
   local claimed=once==true and options.claimed==true
   return{key=key,name=name,price=price,stars=stars,once=once==true,claimed=claimed,
    blurb=if once then "40 Stars to get your garden going. One per player."else nil,available=available and not claimed}
  end
  return{ready=options.ready~=false,packsAllowed=options.packsAllowed~=false,
   passes={{key="doubleStars",name="2× Stars",blurb="Double Stars from every round and quest. Forever.",price=299,owned=options.owned==true,available=available},
    {key="supporter",name="Supporter",blurb="+1 Star for every finished round. Thank you!",price=99,owned=false,available=available}},
   products={product("starter","Starter pack",49,40,true),product("handful","Handful of Stars",39,20),product("pouch","Pouch of Stars",99,60),
    product("jar","Jar of Stars",199,140),product("chest","Chest of Stars",499,400)}}
 end
 local function keys(list)local out={};for _,o in ipairs(list)do table.insert(out,o.key)end;return table.concat(out,",")end
 local previousSelection=Gui.SelectedObject
 local ok,problem=pcall(function()
  test("pure: offer order, best value, opening key, Buy key",function()
   local live=Store.offers(snapshot())
   assert(keys(live)=="doubleStars,supporter,starter,handful,pouch,jar,chest",keys(live))
   local best;for _,o in ipairs(live)do if o.best then assert(not best,"one tag");best=o.key end end
   assert(best=="starter","40/49 beats 400/499: the tag follows the real ratio")
   local claimed=Store.offers(snapshot({claimed=true}))
   assert(keys(claimed)=="doubleStars,supporter,handful,pouch,jar,chest","a claimed Starter leaves the list")
   for _,o in ipairs(claimed)do if o.best then assert(o.key=="chest")end end
   assert(keys(Store.offers(snapshot({packsAllowed=false})))=="doubleStars,supporter","restricted: passes only")
   assert(keys(Store.offers(snapshot({ready=false})))=="doubleStars,supporter","not ready: packs hidden (fail closed)")
   assert(Store.openingKey(Store.offers(snapshot({owned=true})))=="supporter","opens on the first buyable offer")
   local soon=Store.offers(snapshot({available=false}))
   assert(Store.openingKey(soon)=="doubleStars"and not soon[1].enabled and soon[1].reason=="soon")
   local text,enabled=Store.buyKey(live[6]);assert(text=="Buy · R$ 199"and enabled,text)
   text,enabled=Store.buyKey(Store.offers(snapshot({owned=true}))[1]);assert(text=="✓ Owned"and not enabled)
   text,enabled=Store.buyKey(live[6],true);assert(text=="Opening…"and not enabled)
   local gets=Store.gets(live[6],20);assert(gets[1][2]=="+140"and gets[2][2]=="160",gets[1][2].." / "..gets[2][2])
  end)
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(844,390),Vector2.new(568,320)})do
   test(tostring(size).." layout: header, rows ≥44, icons boxed, one Buy key, text fits",function()
    root.Size=UDim2.fromOffset(size.X,size.Y);settle()
    view:setState(snapshot());view:open(24);settle()
    local column=view.body.Column
    assert(view.header and view.header.title.Text=="Get Stars"and view.header.wallet.amount.Text=="24")
    local rows=0
    for _,child in ipairs(column:GetChildren())do
     if child:IsA("TextButton")then
      rows+=1
      assert(child.AbsoluteSize.Y>=44*(child.AbsoluteSize.Y/child.Size.Y.Offset)-.5 and child.Size.Y.Offset>=44,child.Name.." under 44")
      assert(child:FindFirstChild("Icon")and child.Icon:FindFirstChild("Badge"),child.Name.." has its icon box")
      for _,label in ipairs(child:GetDescendants())do if label:IsA("TextLabel")and label.Visible and label.Name~="Badge"then assert(label.TextFits or label.TextTruncate~=Enum.TextTruncate.None,child.Name.."."..label.Name.." clipped")end end
     end
    end
    assert(rows==7 and column:GetAttribute("PacksShown")==true,"7 offers")
    assert(view.selectedKey=="doubleStars"and column.Pass_doubleStars:GetAttribute("Selected")==true)
    assert(view.buyButton:GetAttribute("AccessibleLabel")=="Buy · R$ 299"and view.offerName.Text=="2× Stars")
    assert(column.Product_starter:FindFirstChild("BestValue"),"best value sticker on the real best")
    assert(view:focusTarget()==column.Pass_doubleStars)
    view:close("forced")
   end)
  end
  test("selection, owned and restricted states",function()
   root.Size=UDim2.fromOffset(1649,971);settle()
   view:setState(snapshot({owned=true}));view:open(24);settle()
   local column=view.body.Column
   assert(view.selectedKey=="supporter","opens past the owned pass")
   assert(column.Pass_doubleStars:FindFirstChild("OwnedChip")and column.Pass_doubleStars:GetAttribute("Owned")==true)
   view:select("doubleStars");settle()
   assert(view.buyButton:GetAttribute("AccessibleLabel")=="✓ Owned"and not Kit.buttonState(view.buyButton).enabled)
   assert(not view:buySelected(),"an owned pass cannot be prompted")
   assert(view:move(1)and view.selectedKey=="supporter"and view:move(1)and view.selectedKey=="starter")
   view:setState(snapshot({packsAllowed=false}));settle();column=view.body.Column
   assert(column:GetAttribute("PacksShown")==false and not column:FindFirstChild("PacksHeading"))
   for _,child in ipairs(column:GetChildren())do assert(not child.Name:match("^Product_"),"restricted drew "..child.Name)end
   assert(view.selectedKey=="doubleStars"or view.selectedKey=="supporter")
   view:setState(snapshot({available=false}));settle()
   assert(not Kit.buttonState(view.buyButton).enabled and view.buyButton:GetAttribute("AccessibleLabel")=="Coming soon")
   view:close("forced")
  end)
  test("prompts: one server request per quiet window, only from the Buy path",function()
   table.clear(sent);view:setState(snapshot());view:open(24);settle()
   assert(#sent==1 and sent[1][1]=="open")
   view:select("pouch");settle()
   assert(#sent==1,"selecting never prompts")
   assert(view:buySelected()and not view:buySelected(),"double press stays quiet")
   assert(#sent==2 and sent[2][1]=="prompt"and sent[2][2]=="pouch"and view.status.Text==Store.Opening)
   assert(view.buyButton:GetAttribute("AccessibleLabel")=="Opening…")
  end)
  test("results: grant updates the wallet and wallet-after; pass turns Owned; rejections read",function()
   view:select("jar");view:handleResult({kind="product",key="pouch",stars=60,balance=84});settle()
   assert(view.status.Text=="+60 Stars added. You have 84 Stars."and view.status:GetAttribute("MessageKind")=="reward")
   assert(view.header.wallet.amount.Text=="84")
   assert(view.gets.Get2.Value.Text=="224",view.gets.Get2.Value.Text)
   view:handleResult({kind="pass",key="supporter"});settle()
   assert(view.status.Text=="Supporter is yours. Thank you!"and view.body.Column.Pass_supporter:FindFirstChild("OwnedChip"))
   for _,reason in ipairs({"NotConfigured","Owned","Restricted","AlreadyClaimed","Loading","Throttled","Unknown","Unavailable","SomethingNew"})do
    view:handleResult({kind="rejected",key="pouch",reason=reason});settle()
    assert(#view.status.Text>12 and not view.status.Text:find(reason,1,true)and view.status:GetAttribute("MessageKind")=="notice",reason)
   end
   view:close("forced");view:open(85);settle();assert(view.status.Text==Store.Idle,"a reopened page starts from the idle line")
   view:close("forced")
  end)
  test("before the first snapshot: passes Loading, packs hidden, malformed snapshots ignored",function()
   local fresh=Store.new(root,{request=function()end,geometry=Shop.shopGeometry});fresh:open(0);settle()
   assert(fresh.body.Column:GetAttribute("PacksShown")==false and not Kit.buttonState(fresh.buyButton).enabled)
   assert(fresh.buyButton:GetAttribute("AccessibleLabel")=="Loading…")
   assert(not fresh:setState(nil)and not fresh:setState({passes={}}))
   fresh:close("forced");fresh.shade:Destroy()
  end)
  test("Hatch eggs entry: opens in place over the kept dim, Back returns, forced close takes both",function()
   local host=Instance.new("Frame");host.Name="_StoreEntrySpec";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
   local shop=Shop.new(host,{play=function()end,stopOwner=function()end},function()return true end,function()error("store entry must never hatch")end)
   local okEntry,entryProblem=pcall(function()
    table.clear(sent)
    local page=Store.new(shop.shade,{request=function(action,key)table.insert(sent,{action,key})end});page:setState(snapshot());shop:attachStore(page)
    assert(page.geometry==Shop.shopGeometry,"the store takes the shop's geometry")
    local state={status="Ready",revision=10,nectar=6,inventoryMask=3,misses=0,toyUnlocks={},materialUnlocks={}}
    for _,size in ipairs({Vector2.new(1649,971),Vector2.new(844,390)})do
     root.Size=UDim2.fromOffset(size.X,size.Y);host.Size=UDim2.fromOffset(size.X,size.Y);settle()
     shop:open(state);settle()
     assert(shop:openStore()and page:isOpen(),tostring(size).." opens")
     assert(shop.shopRoot.Visible and not shop.shopPanel.Visible,"the egg panel hides; its root and dim stay")
     assert(page.header.wallet.amount.Text=="6"and shop:getControllerFocus().root==page.shade)
     shop:close();settle()
     assert(not page:isOpen()and shop:isOpen()and shop.shopPanel.Visible,"Back returns to Hatch eggs")
     assert(shop:openStore());shop:close("forced");assert(not page:isOpen()and not shop:isOpen(),"a forced close takes both")
    end
    for _,entry in ipairs(sent)do assert(entry[1]=="open","browsing must never prompt")end
   end)
   shop:close("forced");shop.shade:Destroy();host:Destroy();assert(okEntry,entryProblem)
  end)
 end)
 view:close("forced");view.shade:Destroy();gui:Destroy();Gui.SelectedObject=previousSelection;assert(ok,problem)
 return{passed=#cases,cases=cases}
end
