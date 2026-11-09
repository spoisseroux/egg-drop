-- Unified two-offer grid and complete pre-spend disclosures at compact sizes.
return function(client,parent)
 local View=require(client.EggHatchView);local Run=game:GetService("RunService");local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
 local cases={};local view=View.new(root,{play=function()end},function()return true end,function()error("browse must never purchase")end)
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local ok,err=pcall(function()
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(350,703),Vector2.new(568,210)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle();view:open({status="Ready",revision=10,nectar=24,inventoryMask=3,misses=0});settle()
   local grid=view.body.EggColumn;assert(grid.Recipe_meadow and grid.Recipe_hue and not grid:FindFirstChild("Recipe_sprout")and not grid:FindFirstChild("CompanionTab"))
   for _,id in ipairs({"meadow","hue"})do local n=grid["Recipe_"..id];assert(n.AbsoluteSize.X>=44 and n.AbsoluteSize.Y>=44 and n.RecipeName.TextFits and n.Cost.TextFits)end
   assert(view.action.AbsoluteSize.Y>=44 and view.action.TextFits and view.closeButton.AbsoluteSize==Vector2.new(44,44))
   assert(view:selectRecipe("hue"));settle();grid=view.body.EggColumn
   for _,id in ipairs({"rose","tide","citrus","iris","reset"})do assert(grid["Outcome_"..id].Chance.Text=="20%"and grid["Outcome_"..id]:FindFirstChild("Name").TextFits)end
   assert(view.action.Text:find("8",1,true));assert(not view:selectRecipe("sprout"));table.insert(cases,tostring(size).." unified grid exact price and five disclosed item chances")
  end
  view:update({status="Ready",revision=11,nectar=16,inventoryMask=3,misses=7});view:selectRecipe("meadow");settle()
  assert(view.body.EggColumn.RareProtection.Text:find("50% / 30% / 20%",1,true));table.insert(cases,"rare-only companion distribution follows protection state")
 end)
 view:close();view.shade:Destroy();root:Destroy();assert(ok,err);return cases
end
