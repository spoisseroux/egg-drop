-- Hatch eggs list geometry (redesign 3): one column of text rows (name, line, price)
-- at a fixed pitch inside the list, prices inside their rows, pane button 44+.
return function(client,parent)
 local Shop=require(client.EggHatchView)
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
 local view=Shop.new(root,{play=function()end,stopOwner=function()end},function()return true end,function()error("shop geometry fixture must not purchase")end)
 local state={status="Ready",revision=10,nectar=4,inventoryMask=127,materialAvailable=true,toyUnlocks={},featureStock={}}
 local cases={};local order=Shop.liveOrder()
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function fit(n)assert(n.TextFits,n:GetFullName().." clipped "..n.Text.." box "..tostring(n.AbsoluteSize).." bounds "..tostring(n.TextBounds))end
 local ok,err=pcall(function()
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(749,381),Vector2.new(812,354)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle();view:open(state);settle()
   local column=view.body.EggColumn;assert(column:GetAttribute("RecipeColumns")==1)
   assert(not column:FindFirstChild("Recipe_meadow"))
   local first=column.Recipe_toy;local g=view.shopGeom
   for index,id in ipairs(order)do
    local card=column["Recipe_"..id];fit(card.RecipeName);fit(card.Cost)
    assert(card.AbsoluteSize.X>=44 and card.AbsoluteSize.Y>=44)
    assert(card.Position.Y.Offset==first.Position.Y.Offset+(index-1)*(g.rowH+g.rowGap),"rows keep one pitch")
    assert(card.Position.X.Offset+card.Size.X.Offset<=view.body.Size.X.Offset,"row border cropped")
    assert(card.Cost.Position.X.Offset+card.Cost.Size.X.Offset<=card.Size.X.Offset,"price outside row")
   end
   assert(view.hatchButton.AbsoluteSize.Y>=44 and view.shopBackButton.AbsoluteSize.Y>=44)
   assert(not require(client.DeckKit).buttonState(view.hatchButton).enabled and view.needLine.Visible,"4 Stars cannot hatch an 8-Star egg")
   table.insert(cases,tostring(size).." measured rows names prices borders and pane action fit")
   view:close()
  end
 end)
 view.shade:Destroy();root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
