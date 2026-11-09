-- Same-size reopen must reveal the retained recipe without controller focus or a swipe.
return function(client,parent)
 local Shop=require(client.EggHatchView);local Gui=game:GetService("GuiService")
 local Run=game:GetService("RunService");local previous=Gui.SelectedObject
 local root=Instance.new("Frame");root.Name="_EggShopReopen";root.BackgroundTransparency=1;root.Parent=parent
 local view=Shop.new(root,{play=function()end,stopOwner=function()end},function()return true end,function()error("reopen fixture must not purchase")end)
 local cases={};local state={status="Ready",revision=10,nectar=4,inventoryMask=127,materialAvailable=true,toyUnlocks={bone=true},featureStock={}}
 local function frames()for _=1,3 do Run.Heartbeat:Wait()end end
 local function selectedVisible(id)
  local row=view.body.EggColumn["Recipe_"..id];local top=row.AbsolutePosition.Y;local bottom=top+row.AbsoluteSize.Y
  local windowTop=view.body.AbsolutePosition.Y;local windowBottom=windowTop+view.body.AbsoluteWindowSize.Y
  assert(top<windowBottom and bottom>windowTop,"retained "..id.." is offscreen after reopen")
  if row.AbsoluteSize.Y<=view.body.AbsoluteWindowSize.Y then
   assert(top>=windowTop-.1 and bottom<=windowBottom+.1,"retained recipe should be fully visible")
  else assert(top>=windowTop-4.1 and top<=windowTop+4.1,"oversized retained recipe should lead the window")end
 end
 local ok,problem=pcall(function()
  for _,size in ipairs({Vector2.new(733,307),Vector2.new(568,210),Vector2.new(350,703)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);frames()
   for _,id in ipairs({"toy","feature"})do
    Gui.SelectedObject=nil;view:open(state);frames();assert(view:selectRecipe(id));frames()
    local signature=view.shopReflowSignature;view:close();Gui.SelectedObject=nil
    view:open(state);Gui.SelectedObject=nil;frames()
    assert(view.selected==id and view.shopReflowSignature==signature,"fixture must retain selection at unchanged viewport signature")
    selectedVisible(id)
    assert(Gui.SelectedObject==nil,"selected visibility must not depend on a gamepad focus target")
    table.insert(cases,tostring(size).." retained "..id.." visible on same-size reopen before user scroll")
    view:close()
   end
  end
  view:open(state);assert(view:selectRecipe("feature"));view:queueSelectedRecipe();view:close()
  view.body.CanvasPosition=Vector2.zero;frames();assert(view.body.CanvasPosition==Vector2.zero,"closed ownership epoch ran a stale recipe scroll")
  table.insert(cases,"close invalidates the queued opening scroll")
 end)
 view:close();view.shade:Destroy();root:Destroy();Gui.SelectedObject=previous;assert(ok,problem);return cases
end
