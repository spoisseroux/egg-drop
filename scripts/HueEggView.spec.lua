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
    view:chooseChannel("secondary");settle();assert(view.bars.rose.value.Text=="2/5")
    for _,bar in pairs(view.bars)do assert(#bar.ticks==5)end
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
    assert(view:useResult());settle();check();assert(view.assignment.pendingResultId==s.pendingHueResult.id);assert(view:choosePet("puddle"));assert(view:activate());settle();check();assert(view.confirmation.pendingResultId==s.pendingHueResult.id);view:cancelConfirmation();assert(view.page=="receipt")
   end)
  end
  test("confirm sends once to unequipped selected pet and preserves exact result association",function()
   view:open(state(5000),"palette","puddle");view:chooseChannel("secondary");assert(view:chooseItem("rose"));assert(view:activate());assert(not view:activate())
   local v=sent[#sent].value;assert(v.petId=="puddle"and v.channel=="secondary"and v.itemId=="rose"and v.counts.rose==2 and not v.pendingResultId)
   local count=#sent;local r={id=v.id,action="hueUse",petId="puddle",revision=5001}
   assert(intent:receive({id=v.id,action="hueUse",petId="puddle",status="Saved",receipt=r}))
   local saved=state(5001);saved.lastHueResult=r;saved.petHues.puddle.secondary.rose=3;saved.hueInventory.rose=2;intent:update(saved)
   assert(not view.action.Visible and not view.action.Interactable and not view:activate()and #sent==count,"rapid second Confirm became a paid purchase")
  end)
 end)
 view:destroy();root:Destroy();assert(ok,err);return cases
end
