-- Native layout + confirmation behavior. Injected snapshots; no profile writes.
return function(client,parent,onlySize)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent);local H=require(game.ReplicatedStorage.Shared.HueCatalog)
 local Run=game:GetService("RunService");local root=Instance.new("Frame");root.Name="_HueLayout";root.BackgroundTransparency=1;root.Parent=parent
 local sent,cases={},{};local view;local serial=0
 local intent=Intent.new({id=function()serial+=1;return "layout-"..serial end,send=function(a,v,r)table.insert(sent,{action=a,value=v,revision=r})end,changed=function()if view then view:refresh()end end})
 view=View.new(root,intent,{appearance=function()return{charmVisible=false}end})
 local function state(rev)
  local pets={};for _,pet in ipairs(require(game.ReplicatedStorage.Shared.PetCatalog).collection)do pets[pet.id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
  pets.puddle.secondary.rose=2
  return {revision=rev,status="Ready",nectar=32,inventoryMask=127,hues={},petHues=pets,hueInventory={rose=3,tide=2,citrus=1,iris=1,reset=2}}
 end
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local function visible(n)while n and n~=root do if n:IsA("GuiObject")and not n.Visible then return false end;n=n.Parent end;return n==root end
 local function fit(n)assert(n.TextFits,n:GetFullName().." text does not fit: "..n.Text)end
 local function check()
  fit(view.title);assert(view.closeButton.AbsoluteSize.X>=44 and view.closeButton.AbsoluteSize.Y>=44)
  for _,n in ipairs(view.shade:GetDescendants())do if n:IsA("GuiObject")and visible(n)then
   if n:IsA("TextLabel")then fit(n)end
   if n:IsA("TextButton")then fit(n);assert(n.AbsoluteSize.X>=44 and n.AbsoluteSize.Y>=44,"small action "..n.Name)end
  end end
  assert(#view.world:GetChildren()<=(if view.tab=="pet"then 0 else 1),"Retired single portrait exceeded shared preview budget")
 end
 local function test(n,f)f();table.insert(cases,n)end
 local ok,err=pcall(function()
  for i,size in ipairs(if onlySize then{onlySize}else{Vector2.new(1649,971),Vector2.new(350,703),Vector2.new(568,210)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle()
   test(tostring(size).." one saved pet, independent channels and four five-notch rows",function()
    view:open(state(i*1000),"palette","puddle");settle();check();assert(view.petId=="puddle"and view.channel=="main")
    assert(not view.body:FindFirstChild("Current")and not view.body:FindFirstChild("After"))
    view:chooseChannel("secondary");settle();assert(view.bars.rose.value.Text==(if size.Y<436 and size.X>=540 then "3 jars"else "2/5"))
    for _,bar in pairs(view.bars)do assert(#bar.ticks==6 and bar.stages[0])end
   end)
   test(tostring(size).." inventory selection asks exact item pet channel; cancel spends nothing",function()
    local count=#sent;assert(view:chooseItem("rose"));settle();check()
    assert(view.quote.Text:find("Ovelle",1,true)and view.quote.Text:find("Secondary",1,true)and view.quote.Text:find("2/5 → 3/5",1,true))
    assert(view.cancel.Visible and view.action.Visible and #sent==count);assert(view:cancelConfirmation());assert(#sent==count)
   end)
   test(tostring(size).." reset names lost bars and original rejects without spend",function()
    assert(view:chooseItem("reset"));settle();check();assert(view.quote.Text:find("Erase Rose 2/5",1,true));view:cancelConfirmation();view:chooseChannel("main");assert(not view:chooseItem("reset"))
   end)
   test(tostring(size).." saved fixed jar receipt offers Store and Use now; no second grant",function()
    local s=state(i*1000+100);s.pendingHueResult={id="receipt-"..i,itemId="rose",quantity=1,inventoryAfter=3,revision=s.revision,catalogVersion=H.CatalogVersion}
    view:open(s,"palette","puddle");settle();assert(view.page=="receipt"and view.receipt.Text:find("3 in inventory",1,true));assert(view.action.Text=="Store"and view.useNow.Visible)
    assert(view:useResult());settle();check();assert(view.assignment.pendingResultId==s.pendingHueResult.id);assert(view:choosePet("puddle")and view.action.Text=="Store");assert(view:chooseChannel("main"));settle();check();assert(view.confirmation.pendingResultId==s.pendingHueResult.id and view.action.Text=="Use one");view:cancelConfirmation();assert(view.page=="palette"and view.tab=="hue"and view.assignment.pendingResultId==s.pendingHueResult.id)
   end)
  end
  test("short landscape right pane starts with stock and six full swatches without duplicated channel instructions",function()
   root.Size=UDim2.fromOffset(749,381);view:open(state(4999),"palette","puddle");settle();check()
   assert(not view.channelTitle.Visible and not view.inspection.Visible and view.bars.rose.value.Text=="3 jars")
   assert(view.bars.rose.row.Position.Y.Offset==0 and view.bars.rose.stages[0]:GetAttribute("SavedStage"))
   assert(view.bars.rose.row:GetAttribute("AccessibleLabel"):find("Current 0/5",1,true))
   for _,tick in ipairs(view.bars.rose.ticks)do assert(tick.AbsolutePosition.Y>=view.body.AbsolutePosition.Y and tick.AbsolutePosition.Y+tick.AbsoluteSize.Y<=view.body.AbsolutePosition.Y+view.body.AbsoluteSize.Y)end
   root.Size=UDim2.fromOffset(900,720);settle();assert(view.channelTitle.Visible and view.inspection.Visible and view.bars.rose.value.Text=="0/5","Resize did not restore roomy channel copy")
  end)
  test("short landscape Reset and fruit receipts keep name stock and adjacent Use now Store above the fold",function()
   root.Size=UDim2.fromOffset(733,307)
   for _,item in ipairs({"reset","rose"})do
    local s=state(4999);s.pendingHueResult={id="compact-receipt-"..item,itemId=item,quantity=1,inventoryAfter=3,revision=s.revision,catalogVersion=H.CatalogVersion}
    view:open(s,"palette","puddle");settle();check()
    assert(view.title.Text==(if item=="reset"then "Reset Hue"else "Rose fruit")and not view.receiptDetail.Visible)
    assert(view.receipt.Text:find("in inventory",1,true)and view.receipt.AbsolutePosition.X>view.receiptArt.AbsolutePosition.X+view.receiptArt.AbsoluteSize.X)
    local jar=view.itemReveal.jar;assert(jar.AbsoluteSize.X>=63 and jar.AbsoluteSize.Y>=63)
    assert(view.useNow.Parent==view.card and view.useNow.AbsolutePosition.Y==view.action.AbsolutePosition.Y)
    assert(view.useNow.AbsolutePosition.X+view.useNow.AbsoluteSize.X+7<=view.action.AbsolutePosition.X)
    assert(view.receipt.AbsolutePosition.Y+view.receipt.AbsoluteSize.Y<=view.body.AbsolutePosition.Y+view.body.AbsoluteSize.Y and not view.body.ScrollingEnabled)
    for _,node in ipairs({view.useNow,view.action})do assert(node.TextFits and node.AbsoluteSize.Y>=44 and node.AbsolutePosition.Y+node.AbsoluteSize.Y<=view.card.AbsolutePosition.Y+view.card.AbsoluteSize.Y)end
    assert(view.action.Text=="Store"and view:useResult());settle();assert(not jar.Parent and not view.itemReveal.resultId)
   end
  end)
  test("confirm sends once to unequipped selected pet and preserves exact result association",function()
   view:open(state(5000),"palette","puddle");view:chooseChannel("secondary");assert(view:chooseItem("rose"));assert(view:activate());assert(not view:activate())
   local v=sent[#sent].value;assert(v.petId=="puddle"and v.channel=="secondary"and v.itemId=="rose"and v.counts.rose==2 and not v.pendingResultId)
   local count=#sent;local r={id=v.id,action="hueUse",petId="puddle",revision=5001}
   assert(intent:receive({id=v.id,action="hueUse",petId="puddle",status="Saved",receipt=r}))
   local saved=state(5001);saved.lastHueResult=r;saved.petHues.puddle.secondary.rose=3;saved.hueInventory.rose=2;intent:update(saved)
   assert(not view.action.Visible and not view.action.Interactable and not view:activate()and #sent==count,"rapid second Confirm became a paid purchase")
   assert(not view.confirmJar and not view.status.Visible,"durable use retained confirmation art or success copy")
  end)
 end)
 view:destroy();root:Destroy();assert(ok,err);return cases
end
