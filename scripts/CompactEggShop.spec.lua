-- Hatch eggs list (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 3) at desktop and compact
-- landscape sizes: text-only rows for the item eggs (no Companion Egg, no Feature Egg
-- while flagged), the selected egg's odds once in the pane, exact price on the button.
return function(client,parent)
 local View=require(client.EggHatchView);local Run=game:GetService("RunService");local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Parent=parent
 local cases={};local view=View.new(root,{play=function()end},function()return true end,function()error("browse must never purchase")end)
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local ok,err=pcall(function()
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(812,354),Vector2.new(568,210)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle();view:open({status="Ready",revision=10,nectar=24,inventoryMask=3,misses=0});settle()
   local list=view.body.EggColumn;assert(not list:FindFirstChild("Recipe_meadow")and not list:FindFirstChild("Recipe_sprout")and not list:FindFirstChild("Recipe_feature"))
   for _,id in ipairs({"toy","material","hue"})do local n=list["Recipe_"..id];assert(n.AbsoluteSize.X>=44 and n.AbsoluteSize.Y>=44 and n.RecipeName.TextFits and n.Cost.TextFits)end
   -- The desktop panel scales up to 1.2, so the back hit frame is 44 or larger.
   assert(view.hatchButton.AbsoluteSize.Y>=44,"Hatch button under 44 px at "..tostring(size))
   assert(view.shopBackButton.AbsoluteSize.X>=43.9 and view.shopBackButton.AbsoluteSize.Y>=43.9,"back hit frame under 44 px at "..tostring(size))
   assert(view:selectRecipe("hue"));settle()
   for _,id in ipairs({"rose","tide","citrus","iris","reset"})do assert(view.oddsHolder["Odds_"..id]:GetAttribute("OddsText")=="20%")end
   assert(view.action.Text:find("8",1,true));assert(not view:selectRecipe("sprout"));table.insert(cases,tostring(size).." list, exact price and five disclosed item chances")
  end
  -- The retired Companion Egg cannot be selected and no companion odds or pity promise appear.
  view:update({status="Ready",revision=11,nectar=16,inventoryMask=3,misses=7});assert(not view:selectRecipe("meadow")and view.selected=="hue");settle()
  local list=view.body.EggColumn;assert(not list:FindFirstChild("RareProtection")and not list:FindFirstChild("PoolNote")and not list:FindFirstChild("Recipe_meadow"))
  for _,id in ipairs({"pip","puddle","wick","orbit","bloom_pip","foxfire_wick","eclipse_orbit"})do assert(not view.oddsHolder:FindFirstChild("Odds_"..id))end
  table.insert(cases,"retired Companion Egg cannot be selected and shows no companion odds at stored misses7")
 end)
 view:close();view.shade:Destroy();root:Destroy();assert(ok,err);return cases
end
