-- Actual static GUI/rigs with injected confirmed snapshots; no server/profile writes.
return function(client,parent,onlySize)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent)
 local Hues=require(game.ReplicatedStorage.Shared.HueCatalog);local Palette=require(game.ReplicatedStorage.Shared.PetPalette)
 local Gui=game:GetService("GuiService");local Run=game:GetService("RunService")
 local previous=Gui.SelectedObject;local root=Instance.new("Frame");root.Name="_HueLayout";root.BackgroundTransparency=1;root.Parent=parent
 local sent,cases={},{};local serial,pendingHatches,played=0,0,0;local view
 local intent=Intent.new({id=function()serial+=1;return"layout-"..serial end,send=function(a,v,r)table.insert(sent,{action=a,value=v,revision=r})end,changed=function()if view then view:refresh()end end})
 view=View.new(root,intent,{appearance=function()return{charmVisible=false}end,play=function()played+=1 end,pendingHatch=function()pendingHatches+=1 end})
 local function state(revision,held)
  return{status="Ready",revision=revision or 1,nectar=22,inventoryMask=3,hues={},heldHueEgg=if held then{token="held-egg",purchaseId="saved-purchase"}else nil}
 end
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local function test(n,f)parent:SetAttribute("HueViewProgress",n);f();table.insert(cases,n)end
 local function visible(n)while n and n~=root do if n:IsA("GuiObject")and not n.Visible then return false end;n=n.Parent end;return n==root end
 local function fit(n)assert(n.TextFits,string.format("%s %q box=%s bounds=%s",n:GetFullName(),n.Text,tostring(n.AbsoluteSize),tostring(n.TextBounds)))end
 local function inside(n,h)local p,s,q,t=n.AbsolutePosition,n.AbsoluteSize,h.AbsolutePosition,h.AbsoluteSize;return p.X>=q.X-.1 and p.Y>=q.Y-.1 and p.X+s.X<=q.X+t.X+.1 and p.Y+s.Y<=q.Y+t.Y+.1 end
 local function check()
  fit(view.title);fit(view.wallet);fit(view.action)
  assert(view.closeButton.AbsoluteSize.X>=44 and view.closeButton.AbsoluteSize.Y>=44 and inside(view.closeButton,view.card))
  assert(view.action.AbsoluteSize.Y>=44 and inside(view.action,view.card)and view.body.AbsoluteSize.Y>=44)
  for _,n in ipairs(view.body:GetDescendants())do
   if n:IsA("TextLabel")and visible(n)then fit(n)end
   if n:IsA("TextButton")and visible(n)then assert(n.AbsoluteSize.X>=44 and n.AbsoluteSize.Y>=44,"small action "..n.Name);fit(n)end
  end
 end
 local ok,problem=pcall(function()
  for sizeIndex,size in ipairs(if onlySize then{onlySize}else{Vector2.new(1649,971),Vector2.new(749,381),Vector2.new(350,703),Vector2.new(568,210)})do
   test(tostring(size).." generic purchase exposes no target or direction before hatching",function()
    root.Size=UDim2.fromOffset(size.X,size.Y);settle();assert(view:open(state(sizeIndex*3),"buy","pip"));settle();check()
    assert(view.generic.Visible and not view.current.host.Visible and not view.targets[1].Visible and not view.offers.rose.button.Visible)
    assert(view.action.Interactable and view.action.Text:find("Hatch Hue Egg",1,true)and #sent==0)
    if size.X>=760 and size.Y>=560 then assert(view.card.Size.X.Offset>=500 and view.card.Size.X.Offset<=560 and view.card.Size.Y.Offset<400,"generic buy retained empty full-height card")end
   end)
   test(tostring(size).." held assignment and colors use measured scroll choices and matched rigs",function()
    assert(view:open(state(sizeIndex*3+1,true),"buy","pip"));view:chooseHue("rose");settle();check()
    assert(view.offers.rose.button.Visible and view.targets[1].Visible and view.current.host.Visible)
    if size.X>=760 and size.Y>=900 then
     assert(view.genericEgg.Size.X.Offset<=64)
     for _,offer in pairs(view.offers)do assert(inside(offer.button,view.body),string.format("desktop held swatch %s outside body; card=%s body=%s/%s canvas=%s scroll=%s offer=%s/%s generic=%s quote=%s targets=%s",offer.button.Name,tostring(view.card.AbsoluteSize),tostring(view.body.AbsolutePosition),tostring(view.body.AbsoluteSize),tostring(view.body.CanvasSize),tostring(view.body.CanvasPosition),tostring(offer.button.AbsolutePosition),tostring(offer.button.AbsoluteSize),tostring(view.generic.Size),tostring(view.quote.Size),tostring(view.targets[1].Size)))end
    end
    assert(view.current.camera.CFrame==view.after.camera.CFrame and view.current.viewport.Ambient==view.after.viewport.Ambient)
    assert(view.current.visual.model~=view.after.visual.model and view.current.visual.idleMotionFrozen and view.after.visual.idleMotionFrozen)
    assert(view.previewContained and view.previewBodyFraction<=.641)
    assert(view.current.visual.colors.body==Palette.resolve("pip",{}).body and view.after.visual.colors.body==Palette.resolve("pip",{body="rose",bodyRank=1}).body)
    assert(view.current.visual.charmVisible==false and view.after.visual.charmVisible==false)
    local a,b=view.current.visual,view.after.visual;view:chooseHue("tide");assert(view.current.visual==a and view.after.visual==b and #sent==0)
    view:setPage("palette");settle();check();assert(view.resetAction.Visible and view.bodyTitle.Visible and not view.mixTitle.Visible and view.paletteTab:GetAttribute("SelectedTab"))
   end)
  end
  test("insufficient funds suppress purchase; max grade preserves held item and free Colors remains accessible",function()
   local poor=state(100);poor.nectar=0;view:open(poor,"buy","pip")
   assert(view.action.Interactable and view.action.Text=="Earn 8 more Stars"and view.status.Visible)
   assert(view:activate()and played==1 and not view:isOpen()and #sent==0,"shortfall failed to return to earned play without purchase")
   local max=state(101,true);max.hues.pip={body="rose",secondary="default",ranks={rose=3,tide=0,citrus=0,iris=0}}
   view:open(max,"buy","pip");view:chooseHue("rose");assert(view.action.Text=="Already at grade III"and not view.action.Interactable and max.heldHueEgg)
   view:setPage("palette");view:choosePalette("body","original");assert(view.action.Interactable and #sent==0)
  end)
  test("mix preview uses two learned bases while reset has an explicit independent action",function()
   local s=state(102,true);s.nectar=0;s.hues.pip={body="tide",secondary="rose",ranks={rose=1,tide=2,citrus=0,iris=0}}
   view:open(s,"palette","pip");assert(view:chooseMix("tide")and view:chooseMix("rose"));settle()
   assert(view.after.visual.colors.body==Palette.resolve("pip",{bodyMix="rose:tide",bodyRank=1,secondary="rose"}).body)
   assert(view.current.visual.secondaryColor==view.after.visual.secondaryColor and view.action.Interactable and view.resetAction.Interactable)
   assert(not view:chooseMix("iris")and s.heldHueEgg.token=="held-egg"and #sent==0)
   assert(view.mixChip.Visible and view.action.Text:find("Rose + Tide",1,true),"pinned mix result lost its name or swatch")
  end)
  test("Colors groups keep one choice set, reset and measured tabs without saving or moving portrait framing",function()
   local s=state(110);s.hues.pip={body="rose",secondary="tide",ranks={rose=1,tide=1,citrus=0,iris=0}}
   view:open(s,"palette","pip");local current,after=view.current.visual,view.after.visual
   for _,group in ipairs({"body","secondary","mix"})do
    view.body.CanvasPosition=Vector2.new(0,200);assert(view:setColorsGroup(group));settle();check()
    assert(view.paletteGroup==group and view.body.CanvasPosition.Y==0 and view.current.visual==current and view.after.visual==after)
    assert(view.bodyChoices.original.Visible==(group=="body")and view.secondaryChoices.default.Visible==(group=="secondary")and view.mixChoices.rose.Visible==(group=="mix"))
    assert(view.resetAction.Visible and not view.receipt.Visible and not view.equipAccent.Visible and #sent==0)
    for _,tab in pairs(view.colorTabs)do assert(tab.Visible and tab.AbsoluteSize.X>=44 and tab.AbsoluteSize.Y>=44)end
   end
  end)
  test("applied result leads once, next paid action is explicit, and old Saved never masks exhausted or shortfall reasons",function()
   root.Size=UDim2.fromOffset(1649,971);settle()
   local s=state(111);s.hueLastPurchase={id="purchase"};s.hues.pip={body="rose",secondary="default",ranks={rose=1,tide=0,citrus=0,iris=0}}
   s.lastHueResult={id="apply-result",action="hueApply",petId="pip",hue="rose",newRank=1,secondaryUnlocked=true,revision=111}
   intent.status,intent.message="Saved","Saved";view:open(s,"buy","pip");settle();check()
   assert(view.receipt.Text=="Rose I applied to Zivvi"and view.resultLead and view.receipt.Position.Y.Offset<view.generic.Position.Y.Offset)
   assert(not view.status.Visible and view.action.Text:find("Hatch another Hue Egg",1,true)and view.equipAccent.Visible)
   assert(view.card.Size.X.Offset>=500 and view.card.Size.X.Offset<=560 and view.card.Size.Y.Offset<500,"result retained empty full-height card")
   s=state(112);s.nectar=2;s.hueLastPurchase={id="purchase"};s.lastHueResult={id="saved-color",action="hueEquip",petId="pip",revision=112}
   intent.status,intent.message="Saved","Saved";view:open(s,"buy","pip");assert(view.status.Visible and view.status.Text:find("6 Stars",1,true)and view.action.Text=="Earn 6 more Stars")
   s=state(113);for _,pet in ipairs({"pip","puddle"})do s.hues[pet]={body="rose",secondary="default",ranks={rose=3,tide=3,citrus=3,iris=3}}end
   intent.status,intent.message="Saved","Saved";view:open(s,"buy","pip");assert(not view.action.Interactable and view.status.Visible and view.status.Text:find("No owned supported baby",1,true))
  end)
  test("companion reveal preempts Hue without consuming or hiding committed held stock",function()
   local s=state(200,true);s.lastHatch={id="pending-companion",petId="puddle"};intent:update(s);settle()
   assert(not view:isOpen()and pendingHatches==1 and s.heldHueEgg.token=="held-egg"and #sent==0)
  end)
 end)
 view:destroy();root:Destroy();Gui.SelectedObject=previous;assert(ok,problem)
 return{passed=#cases,cases=cases,purchases=0,actualWalletMutation=false}
end
