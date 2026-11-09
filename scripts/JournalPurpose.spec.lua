-- Native collection and color navigation fixture; archived rank inputs stay invisible.
return function(client,parent)
 local Journal=require(client.PetJournal);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(350,600);root.BackgroundTransparency=1;root.Parent=parent
 local cases,views={},{};local function test(name,run)run();table.insert(cases,name)end
 local function fixture()
  local visits,tracks,goals={},{},0
  local view=Journal.new(root,nil,nil,function(pet)table.insert(visits,pet.id)end,function(pet)table.insert(tracks,pet.id)end,function()goals+=1 end)
  table.insert(views,view);return view,visits,tracks,function()return goals end
 end
 local ok,problem=pcall(function()
  test("rare-only sparse inventory never unlocks base or displays archived ranks",function()
   local view,visits,tracks,goals=fixture()
   view:open(0,0,"foxfire_wick",false,nil,Catalog.bit("foxfire_wick"),{wick=3})
   local rare,base=view.cards[Pets.byId.foxfire_wick.index],view.cards[Pets.byId.wick.index]
   assert(rare.Interactable and rare.Status.Text=="Equipped"and not base.Interactable and base.Status.Text=="Hatch from eggs")
   assert(not view.goalsButton and view.openFamilyGoals==nil and not rare:FindFirstChild("FamilyCrest")and not rare:FindFirstChild("FamilyRank"))
   assert(view.title.Text:find("01/07",1,true)and goals()==0 and #visits==0 and #tracks==0)
   assert(view:activatePet(Pets.byId.foxfire_wick.index)and visits[1]=="foxfire_wick"and not view.shade.Visible)
  end)
  test("body and accent shortcut appears only for owned supported pets",function()
   local view=fixture();view:setColors(function()end)
   view:open(0,0,"foxfire_wick",false,nil,Catalog.bit("foxfire_wick"),{})
   assert(not view.colorsButton.Visible)
   view:open(0,0,"puddle",false,nil,Catalog.bit("puddle"),{puddle=3})
   assert(view.colorsButton.Visible and view.colorsButton.Interactable and view.companionId=="puddle")
   assert(view.cards[2].ColorHint.Text=="Body & accents in Colors")
  end)
  test("largest collection rows scroll on compact and portrait safe widths",function()
   local view=fixture();view:setColors(function()end)
   for _,size in ipairs({Vector2.new(350,198),Vector2.new(568,160),Vector2.new(390,740)})do
    root.Size=UDim2.fromOffset(size.X,size.Y);task.wait(.06)
    view:open(0,0,"pip",false,nil,127,{pip=3,puddle=3,wick=3,orbit=3});task.wait(.06)
    assert(view.title.TextFits and view.closeButton.AbsoluteSize==Vector2.new(44,44)and view.scroll.AbsoluteSize.Y>=44)
    assert(view.colorsButton.AbsoluteSize.Y>=44 and view.colorsButton.TextFits)
    for _,entry in ipairs(view.cards)do
     assert(entry.Species.TextFits and entry.Status.TextFits and entry.Size.Y.Offset>=44)
     if entry.ColorHint.Visible then assert(entry.ColorHint.TextFits)end
     view:ensureVisible(entry)
    end
   end
  end)
 end)
 for _,view in ipairs(views)do view:close();view.shade:Destroy()end
 root:Destroy();assert(ok,problem);return{passed=#cases,cases=cases}
end
