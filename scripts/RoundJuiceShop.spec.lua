return function(client,parent)
 local Shop=require(client.EggHatchView);local Art=require(client.DeckArt)
 local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
 local view=Shop.new(root,{play=function()end,stopOwner=function()end},function()return true end,function()error("shop geometry fixture must not purchase")end)
 local state={status="Ready",revision=10,nectar=4,inventoryMask=127,materialAvailable=true,toyUnlocks={},featureStock={}}
 local cases={};local order={"meadow","hue","material","toy","feature"}
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function fit(n)assert(n.TextFits,n:GetFullName().." clipped "..n.Text.." box "..tostring(n.AbsoluteSize).." bounds "..tostring(n.TextBounds))end
 local ok,err=pcall(function()
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(749,381),Vector2.new(350,703)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle();view:open(state);settle()
   local column=view.body.EggColumn;local cols=column:GetAttribute("RecipeColumns")
   if size.X>=749 then assert(cols==3,"normal desktop and landscape phone require three measured columns")else assert(cols>=1 and cols<=3)end
   local first=column.Recipe_meadow;local rect=Art.scrollContentRect(view.body,view.body.Size.X.Offset)
   for index,id in ipairs(order)do
    local card=column["Recipe_"..id];fit(card.RecipeName);fit(card.Cost)
    assert(card.AbsoluteSize.X>=44 and card.AbsoluteSize.Y>=44)
    assert(card.Position.Y.Offset==first.Position.Y.Offset+math.floor((index-1)/cols)*(first.Size.Y.Offset+8))
    assert(card.Position.X.Offset+card.Size.X.Offset<=rect.width+4.01,"right offer border cropped")
    assert(card.Cost.Position.Y.Offset+card.Cost.Size.Y.Offset<=card.Size.Y.Offset-5,"price outside offer")
   end
   if cols==3 then assert(column.Recipe_material.Position.Y==first.Position.Y and column.Recipe_toy.Position.Y==column.Recipe_feature.Position.Y)end
   assert(view.action.AbsoluteSize.Y>=44 and view.closeButton.AbsoluteSize.Y>=44);fit(view.action)
   table.insert(cases,tostring(size).." measured offers names prices borders and fixed actions fit")
   view:close()
  end
 end)
 view.shade:Destroy();root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
