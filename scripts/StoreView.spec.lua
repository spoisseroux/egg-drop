-- Robux "Get Stars" sheet: measured layout, honest states and server-only prompts.
-- Fixture only: every request goes to a local recorder, never to a remote.
return function(client,parent)
 local Store=require(client.StoreView);local Shop=require(client.EggHatchView)
 local Run=game:GetService("RunService");local Gui=game:GetService("GuiService")
 local root=Instance.new("Frame");root.Name="_StoreViewSpec";root.BackgroundTransparency=1;root.Parent=parent
 local cases,sent={},{}
 local reduced=false
 local view=Store.new(root,{reduceEffects=function()return reduced end,request=function(action,key)table.insert(sent,{action,key})end})
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local function snapshot(options)
  options=options or {}
  local available=options.available~=false
  local function product(key,name,price,stars,once)
   local claimed=once==true and options.claimed==true
   return{key=key,name=name,price=price,stars=stars,once=once==true,claimed=claimed,blurb=if once then "40 Stars to get your garden going. One per player."else nil,
    available=available and options.packsAllowed~=false and not claimed}
  end
  return{ready=options.ready~=false,packsAllowed=options.packsAllowed~=false,
   passes={{key="doubleStars",name="2× Stars",blurb="Double Stars from every round and daily contract. Forever.",price=299,owned=options.owned==true,available=available},
    {key="supporter",name="Supporter",blurb="+1 Star for every finished round. Thank you!",price=99,owned=false,available=available}},
   products={product("starter","Starter pack",49,40,true),product("handful","Handful of Stars",39,20),product("pouch","Pouch of Stars",99,60),
    product("jar","Jar of Stars",199,140),product("chest","Chest of Stars",499,400)}}
 end
 local function column()return view.body.Column end
 local function offers()
  local list={}
  for _,child in ipairs(column():GetChildren())do if child:IsA("TextButton")then table.insert(list,child)end end
  return list
 end
 local function noteText(node,wanted)
  for _,label in ipairs(node:GetDescendants())do if label:IsA("TextLabel")and label.Name:match("^Note")and label.Text==wanted then return true end end
  return false
 end
 -- Every label fits, every offer is a full touch target inside the sheet, none overlap.
 local function measured(label)
  local rootPos,rootSize=root.AbsolutePosition,root.AbsoluteSize;local card=view.card
  assert(card.AbsolutePosition.X>=rootPos.X-.5 and card.AbsolutePosition.Y>=rootPos.Y-.5
   and card.AbsolutePosition.X+card.AbsoluteSize.X<=rootPos.X+rootSize.X+.5 and card.AbsolutePosition.Y+card.AbsoluteSize.Y<=rootPos.Y+rootSize.Y+.5,label.." card leaves the safe root")
  assert(view.closeButton.AbsoluteSize==Vector2.new(44,44),label.." close must be 44×44")
  assert(view.heading.TextFits and view.amount.TextFits,label.." header text is clipped")
  if view.status.Visible then
   local statusBottom=view.status.AbsolutePosition.Y+view.status.AbsoluteSize.Y
   assert(view.status.TextFits and statusBottom<=card.AbsolutePosition.Y+card.AbsoluteSize.Y+.5 and view.status.AbsolutePosition.Y>=view.body.AbsolutePosition.Y+view.body.AbsoluteSize.Y-.5,label.." status must stay pinned under the list")
  else
   -- Only a short phone unpins it, and only the idle line; it then closes the list.
   local idle=column():FindFirstChild("IdleNote")
   assert(root.AbsoluteSize.Y<280 and view.status.Text==Store.Idle and idle and idle.TextFits and idle.Text==Store.Idle,label.." an unpinned status must be the idle line inside the list")
  end
  local intro=column().Intro;assert(intro.TextFits and intro.AbsolutePosition.X+intro.AbsoluteSize.X<=column().AbsolutePosition.X+view.body.AbsoluteWindowSize.X+.5,label.." intro is clipped")
  local list=offers();local left=column().AbsolutePosition.X;local right=left+view.body.AbsoluteWindowSize.X
  for _,node in ipairs(list)do
   assert(node.AbsoluteSize.X>=44 and node.AbsoluteSize.Y>=44,label.." "..node.Name.." is under 44px")
   assert(node.AbsolutePosition.X>=left-.5 and node.AbsolutePosition.X+node.AbsoluteSize.X<=right+.5,label.." "..node.Name.." leaves the scroll window")
   local price=node.Price
   assert(price.AbsolutePosition.Y+price.AbsoluteSize.Y<=node.AbsolutePosition.Y+node.AbsoluteSize.Y+.5 and price.AbsolutePosition.X+price.AbsoluteSize.X<=node.AbsolutePosition.X+node.AbsoluteSize.X+.5,label.." "..node.Name.." price leaves its tile")
   for _,text in ipairs(node:GetDescendants())do
    if text:IsA("TextLabel")and text.Name~="GoldStar"then
     assert(text.TextFits,label.." "..node.Name.."."..text.Name.." is clipped: "..text.Text)
     assert(text.AbsolutePosition.Y+text.AbsoluteSize.Y<=node.AbsolutePosition.Y+node.AbsoluteSize.Y+.5,label.." "..node.Name.."."..text.Name.." leaves its tile")
    end
   end
   local info=node.Info
   assert(info.AbsolutePosition.Y+info.AbsoluteSize.Y<=price.AbsolutePosition.Y+.5 or info.AbsolutePosition.X+info.AbsoluteSize.X<=price.AbsolutePosition.X+.5,label.." "..node.Name.." words collide with the price")
  end
  for i=1,#list do for j=i+1,#list do
   local a,b=list[i],list[j]
   local apart=a.AbsolutePosition.X+a.AbsoluteSize.X<=b.AbsolutePosition.X+.5 or b.AbsolutePosition.X+b.AbsoluteSize.X<=a.AbsolutePosition.X+.5
    or a.AbsolutePosition.Y+a.AbsoluteSize.Y<=b.AbsolutePosition.Y+.5 or b.AbsolutePosition.Y+b.AbsoluteSize.Y<=a.AbsolutePosition.Y+.5
   assert(apart,label.." "..a.Name.." overlaps "..b.Name)
  end end
  assert(view.body.CanvasSize.Y.Offset>=column().AbsoluteSize.Y-.5,label.." canvas is shorter than its content")
  -- At rest the first offer is whole inside the scroll window, even at 568×210.
  local first=column().Pass_doubleStars;local windowTop=view.body.AbsolutePosition.Y
  assert(view.body.CanvasPosition.Y==0 and first.AbsolutePosition.Y>=windowTop-.5 and first.AbsolutePosition.Y+first.AbsoluteSize.Y<=windowTop+view.body.AbsoluteSize.Y+.5,label.." first offer is cut off at rest")
  return #list
 end
 local previousSelection=Gui.SelectedObject
 local ok,problem=pcall(function()
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(350,703),Vector2.new(568,210)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle()
   -- Launch state: ids configured, packs allowed, starter unclaimed.
   view:setState(snapshot());view:open(24);settle()
   assert(measured(tostring(size).." live")==7,"two passes and five packs expected")
   local col=column()
   assert(col:GetAttribute("PacksShown")==true and col.Product_starter:GetAttribute("Featured")==true and col.Product_starter:FindFirstChild("StarWell"),"unclaimed starter must be featured")
   assert(col.Product_starter.AbsolutePosition.Y<col.Product_handful.AbsolutePosition.Y,"starter leads the packs")
   assert(col.Pass_doubleStars.Price.Label.Text=="R$ 299"and col.Pass_supporter.Price.Label.Text=="R$ 99")
   for key,want in pairs({handful={"R$ 39","20 Stars"},pouch={"R$ 99","60 Stars"},jar={"R$ 199","140 Stars"},chest={"R$ 499","400 Stars"}})do
    local node=col["Product_"..key];assert(node.Price.Label.Text==want[1]and node.Info.Amount.Text==want[2]and node.Interactable and node.Selectable,key.." price, Stars and action")
    assert(node.Price:GetAttribute("PillStyle")=="buy")
   end
   assert(col.Product_starter.Price.Label.Text=="R$ 49"and col.Product_starter.Info.Title.Text:find("40 Stars",1,true))
   -- 40/49 beats 400/499, so the honest tag sits on the starter until it is claimed.
   assert(noteText(col.Product_starter,Store.BestTag)and not noteText(col.Product_chest,Store.BestTag),"tag follows the real best ratio")
   assert(view.amount.Text=="24"and view:focusTarget()==col.Pass_doubleStars)
   table.insert(cases,tostring(size).." live sheet: 7 offers ≥44px, text fits, starter featured, exact R$ and Stars")

   -- Starter claimed: demoted to a quiet row and the chest earns the single tag.
   view:setState(snapshot({claimed=true}));settle();measured(tostring(size).." claimed");col=column()
   local starter=col.Product_starter
   assert(starter:GetAttribute("Claimed")==true and not starter:GetAttribute("Featured")and not starter.Interactable and not starter.Selectable and starter.Price.Label.Text=="Claimed")
   assert(starter.AbsolutePosition.Y>col.Product_chest.AbsolutePosition.Y,"claimed starter moves below the packs")
   local tagged=0;for _,node in ipairs(offers())do if noteText(node,Store.BestTag)then tagged+=1 end end
   assert(tagged==1 and noteText(col.Product_chest,Store.BestTag),"exactly one value tag, on the chest")
   table.insert(cases,tostring(size).." claimed starter is a disabled Claimed row; one value tag on the chest")

   -- Owned pass: a worded Owned state that cannot be prompted.
   view:setState(snapshot({owned=true}));settle();measured(tostring(size).." owned");col=column()
   local owned=col.Pass_doubleStars
   assert(owned:GetAttribute("Owned")==true and owned.Price.Label.Text=="Owned"and owned.Price:GetAttribute("PillStyle")=="owned"and not owned.Interactable and not owned.Selectable)
   assert(col.Pass_supporter.Interactable and col.Pass_supporter.Price.Label.Text=="R$ 99"and view:focusTarget()==col.Pass_supporter)
   table.insert(cases,tostring(size).." owned pass shows Owned and leaves the other pass buyable")

   -- Restricted (paid random items): no Stars product is drawn; passes remain.
   view:setState(snapshot({packsAllowed=false}));settle();assert(measured(tostring(size).." restricted")==2);col=column()
   assert(col:GetAttribute("PacksShown")==false and not col:FindFirstChild("PacksHeading"))
   for _,child in ipairs(col:GetChildren())do assert(not child.Name:match("^Product_"),"restricted mode drew "..child.Name)end
   assert(col.Pass_doubleStars.Interactable and col.Pass_supporter.Interactable)
   table.insert(cases,tostring(size).." restricted mode hides every Stars pack and keeps both passes")

   -- Studio today: nothing configured. Complete sheet, prices kept, Coming soon, no dead prompts.
   view:setState(snapshot({available=false}));settle();assert(measured(tostring(size).." coming soon")==7);col=column()
   for _,node in ipairs(offers())do
    assert(not node.Interactable and not node.Selectable and noteText(node,"Coming soon")and node.Price:GetAttribute("PillStyle")=="quiet"and node.Price.Label.Text:match("^R%$ %d+$"),node.Name.." must read Coming soon with its price")
   end
   assert(view:focusTarget()==view.closeButton)
   table.insert(cases,tostring(size).." unconfigured ids: all 7 offers listed with prices and Coming soon, focus falls to X")
   view:close("forced")
  end

  -- Before the first snapshot the gate fails closed and nothing is promptable.
  root.Size=UDim2.fromOffset(733,307);settle()
  local fresh=Store.new(root,{request=function()end});fresh:open(0);settle()
  local freshColumn=fresh.body.Column
  assert(freshColumn:GetAttribute("PacksShown")==false and freshColumn:FindFirstChild("PacksLoading")and freshColumn.Pass_doubleStars and not freshColumn.Pass_doubleStars.Interactable and noteText(freshColumn.Pass_doubleStars,"Loading…"))
  assert(not fresh:setState(nil)and not fresh:setState({passes={}}),"malformed snapshots are ignored")
  fresh:close("forced");fresh.shade:Destroy()
  table.insert(cases,"no snapshot yet: passes read Loading, packs hidden, malformed snapshots ignored")

  -- Prompts are requests to the server, one per quiet window, never while closed.
  table.clear(sent);view:setState(snapshot());view:open(24);settle()
  assert(#sent==1 and sent[1][1]=="open","opening asks for a fresh snapshot")
  assert(view:prompt("pouch")and not view:prompt("pouch")and not view:prompt("chest"),"double taps stay quiet")
  assert(#sent==2 and sent[2][1]=="prompt"and sent[2][2]=="pouch"and view.status.Text==Store.Opening)
  table.insert(cases,"a tap sends one server prompt request; repeat taps inside the quiet window send nothing")

  -- Grant: short confirmation, authoritative balance, optional pulse.
  view:handleResult({kind="product",key="pouch",stars=60,balance=84});settle()
  assert(view.status.Text=="+60 Stars added. You have 84 Stars."and view.status:GetAttribute("MessageKind")=="reward"and view.status.TextFits and view.amount.Text=="84")
  assert(view.walletDrop:FindFirstChild("GrantPulse"),"standard motion pulses the wallet star")
  view.walletDrop.GrantPulse:Destroy();reduced=true
  view:handleResult({kind="product",key="handful",stars=1,balance=85});settle()
  assert(view.status.Text=="+1 Star added. You have 85 Stars."and not view.walletDrop:FindFirstChild("GrantPulse"),"reduced motion shows the same values without a pulse")
  reduced=false
  assert(view:prompt("jar"),"a result reopens the quiet window")
  view:handleResult({kind="pass",key="supporter"});settle()
  assert(view.status.Text=="Supporter is yours. Thank you!"and view.body.Column.Pass_supporter.Price.Label.Text=="Owned")
  table.insert(cases,"grant reads +60 Stars with the new balance; reduced motion skips the pulse; pass purchase flips to Owned")

  -- Rejections: every server reason has plain copy; NotConfigured reads Coming soon.
  for _,reason in ipairs({"NotConfigured","Owned","Restricted","AlreadyClaimed","Loading","Throttled","Unknown","Unavailable","SomethingNew"})do
   view:handleResult({kind="rejected",key="pouch",reason=reason});settle()
   local text=view.status.Text
   assert(#text>12 and not text:find(reason,1,true)and view.status.TextFits and view.status:GetAttribute("MessageKind")=="notice",reason.." needs readable copy")
   if reason=="NotConfigured"then assert(text:find("Coming soon",1,true))end
  end
  for _,size in ipairs({Vector2.new(350,703),Vector2.new(568,210)})do root.Size=UDim2.fromOffset(size.X,size.Y);settle();measured(tostring(size).." rejection")end
  view:close("forced");view:open(85);settle();assert(view.status.Text==Store.Idle,"a reopened sheet starts from the idle line")
  view:close("forced")
  table.insert(cases,"9 rejection reasons give readable copy that fits at phone sizes; NotConfigured reads Coming soon")

  -- Entry point: Get Stars in the egg shop header. Back leaves the store first.
  local shopRoot=Instance.new("Frame");shopRoot.Name="_StoreEntrySpec";shopRoot.BackgroundTransparency=1;shopRoot.Parent=parent
  local closed={}
  local shop=Shop.new(shopRoot,{play=function()end},function()return true end,function()error("store entry must never hatch")end)
  shop.onClosed=function(reason)table.insert(closed,reason)end
  local eggState={status="Ready",revision=10,nectar=6,inventoryMask=3,misses=0}
  local okEntry,entryProblem=pcall(function()
   shopRoot.Size=UDim2.fromOffset(733,307);settle();shop:open(eggState);settle()
   assert(not shop.getStars.Visible and not shop:openStore(),"no store attached: no Get Stars button")
   shop:close("forced")
   table.clear(sent);table.clear(closed)
   local page=Store.new(shop.shade,{request=function(action,key)table.insert(sent,{action,key})end});page:setState(snapshot());shop:attachStore(page)
   for _,size in ipairs({Vector2.new(1649,971),Vector2.new(350,703),Vector2.new(568,210)})do
    shopRoot.Size=UDim2.fromOffset(size.X,size.Y);settle();shop:open(eggState);settle()
    local entry=shop.getStars
    assert(entry.Visible and entry.TextFits and entry.AbsoluteSize.X>=44 and entry.AbsoluteSize.Y>=44,tostring(size).." Get Stars target")
    local cardRight=shop.card.AbsolutePosition.X+shop.card.AbsoluteSize.X
    assert(entry.AbsolutePosition.X>=shop.card.AbsolutePosition.X and entry.AbsolutePosition.X+entry.AbsoluteSize.X<=cardRight,"entry stays inside the card")
    local function clear(a,b)return a.AbsolutePosition.X+a.AbsoluteSize.X<=b.AbsolutePosition.X+.5 or b.AbsolutePosition.X+b.AbsoluteSize.X<=a.AbsolutePosition.X+.5 or a.AbsolutePosition.Y+a.AbsoluteSize.Y<=b.AbsolutePosition.Y+.5 or b.AbsolutePosition.Y+b.AbsoluteSize.Y<=a.AbsolutePosition.Y+.5 end
    assert(clear(entry,shop.closeButton)and clear(entry,shop.heading)and clear(entry,shop.body)and clear(entry,shop.action),tostring(size).." Get Stars overlaps egg shop chrome")
    assert(shop.heading.TextFits and shop.action.TextFits and shop.closeButton.AbsoluteSize==Vector2.new(44,44))
    assert(shop:openStore()and page:isOpen()and not shop.card.Visible and shop:isOpen(),"store replaces the egg card inside the same owner")
    assert(page.amount.Text=="6"and shop:getControllerFocus().root==page.shade)
    shop:update({status="Ready",revision=11,nectar=66,inventoryMask=3,misses=0});settle();assert(page.amount.Text=="66","wallet follows the hatch snapshot")
    shop:close();settle()
    assert(not page:isOpen()and shop:isOpen()and shop.card.Visible and #closed==0 and shop:getControllerFocus().root==shop.shade,"Back returns to the egg shop")
    assert(shop:openStore());shop:close("forced");assert(not page:isOpen()and not shop:isOpen()and shop.card.Visible and closed[#closed]=="forced","a forced close takes both")
    table.clear(closed)
   end
   for _,entry in ipairs(sent)do assert(entry[1]=="open","browsing must never prompt")end
   table.insert(cases,"egg shop Get Stars: ≥44px at 3 sizes, opens the store in place, Back returns, forced close takes both, no prompt sent")
  end)
  shop:close("forced");shop.shade:Destroy();shopRoot:Destroy();assert(okEntry,entryProblem)
 end)
 view:close("forced");view.shade:Destroy();root:Destroy();Gui.SelectedObject=previousSelection;assert(ok,problem);return cases
end
