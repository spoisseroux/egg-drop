-- Native client fixture at Medium and Largest; no purchases or profile writes.
return function(client,parent)
 local Art=require(client.DeckArt);local Hue=require(client.HueEggView);local Intent=require(client.HueIntent)
 local Shop=require(client.EggHatchView);local Menu=require(client.DeckMenu)
 local Shared=game:GetService("ReplicatedStorage").Shared;local H=require(Shared.HueCatalog);local Pets=require(Shared.PetCatalog)
 local Run=game:GetService("RunService");local root=Instance.new("Frame");root.Name="_UsableWidth";root.BackgroundTransparency=1;root.Parent=parent
 local cases={};local hue,shop,menu
 local function settle()for _=1,3 do Run.Heartbeat:Wait()end end
 local function snapshot()
  local hues={};for _,pet in ipairs(Pets.collection)do hues[pet.id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
  return {status="Ready",revision=100,nectar=40,inventoryMask=127,misses=0,petHues=hues,hueInventory={rose=3,tide=2,citrus=1,iris=1,reset=2},contracts={}}
 end
 local function fit(n)assert(n.TextFits,n:GetFullName().." clipped text: "..n.Text)end
 local function contained(n,body)
  local rect=Art.scrollContentRect(body,body.AbsoluteSize.X)
  local x=n.AbsolutePosition.X-body.AbsolutePosition.X
  assert(x>=rect.x-.1 and x+n.AbsoluteSize.X<=rect.right+.1,n:GetFullName().." outside scrolling content: "..x.." + "..n.AbsoluteSize.X.." > "..rect.right)
 end
 local function checkChildren(body)
  for _,n in ipairs(body:GetChildren())do if n:IsA("GuiObject")and n.Visible then contained(n,body)end end
 end
 local function test(name,run)run();table.insert(cases,name)end
 local ok,problem=pcall(function()
  local intent=Intent.new({id=function()return "width-fixture"end,send=function()error("fixture must not send")end,changed=function()end})
  hue=Hue.new(root,intent,{appearance=function()return{charmVisible=false}end})
  shop=Shop.new(root,{play=function()end},function()return true end,function()error("fixture must not buy")end)
  menu=Menu.new(root,{pets=function()error("removed shortcut")end,style=function()error("removed shortcut")end,eggs=function()end,trials=function()end,settings=function()end})
  test("scroll budget resolves padding and scrollbar only once with integer boundaries",function()
   local body=Instance.new("ScrollingFrame");body.Size=UDim2.fromOffset(301,100);body.ScrollBarThickness=4;body.Parent=root
   local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,7);pad.PaddingRight=UDim.new(0,9);pad.Parent=body;settle()
   local r=Art.scrollContentRect(body,301);local inset=math.max(0,body.AbsoluteSize.X-body.AbsoluteWindowSize.X)
   assert(r.x==6 and r.width==math.floor(body.AbsoluteWindowSize.X-7-9-math.max(0,4-inset)-12))
   local finish=0;for i=0,3 do local x,w=Art.gridCell(r.width,i,4,8);assert(x%1==0 and w%1==0 and x>=finish);finish=x+w end
   assert(finish==r.width);body:Destroy()
  end)
  for _,size in ipairs({Vector2.new(1649,971),Vector2.new(900,720),Vector2.new(390,740),Vector2.new(350,703),Vector2.new(749,381),Vector2.new(568,210)})do
   root.Size=UDim2.fromOffset(size.X,size.Y);settle()
   test(tostring(size).." four pet columns fill usable width with wrapped names and selectable borders",function()
    hue:open(snapshot(),"pet","pip");settle();hue:layout();settle()
    local entries={};for _,pet in ipairs(Pets.collection)do local e=hue.gridPreviews[pet.id];if e.button.Visible then table.insert(entries,e)end end
    assert(#entries==7);local rect=Art.scrollContentRect(hue.body,hue.body.AbsoluteSize.X)
    assert(entries[1].button.Position.Y.Offset==entries[4].button.Position.Y.Offset and entries[5].button.Position.Y.Offset>entries[1].button.Position.Y.Offset)
    local first,last=entries[1].button,entries[4].button
    assert(math.abs(first.AbsolutePosition.X-hue.body.AbsolutePosition.X-rect.x)<.1)
    assert(math.abs(last.AbsolutePosition.X+last.AbsoluteSize.X-hue.body.AbsolutePosition.X-rect.right)<.1)
    for _,e in ipairs(entries)do contained(e.button,hue.body);assert(e.button.AbsoluteSize.X>=44 and e.button.AbsoluteSize.Y>=44);fit(e.caption);fit(e.active)end
    hue:layout();settle();contained(first,hue.body);assert(first.AbsolutePosition.X==hue.body.AbsolutePosition.X+rect.x,"reflow accumulated origin")
   end)
   test(tostring(size).." hue stock and confirmation remain inside real scrolling window",function()
    hue:setTab("hue");settle();hue:layout();settle();checkChildren(hue.body)
    for _,n in ipairs(hue.card:GetDescendants())do assert(n.Name~="SelectedGlint"and n.Name~="SelectedEdge"and n.Name~="SavedMark","decorative selected streak: "..n:GetFullName())end
    for _,j in pairs(hue.jars)do if j.button.Visible then
     fit(j.label);fit(j.quantity);fit(j.reason)
     for _,n in ipairs({j.label,j.quantity,j.reason})do assert(n.AbsolutePosition.X+n.AbsoluteSize.X<=j.button.AbsolutePosition.X+j.button.AbsoluteSize.X-.9)end
    end end
    assert(hue:chooseItem("rose"));settle();checkChildren(hue.body);fit(hue.action);fit(hue.cancel);hue:cancelConfirmation();hue:close()
   end)
   test(tostring(size).." all egg cards and odds preserve clear right stroke gutter",function()
    shop:open(snapshot());settle()
    for _,recipe in ipairs({"meadow","hue","material"})do
     shop:selectRecipe(recipe);settle();shop:renderBody();settle()
     local column=shop.body.EggColumn
     for _,n in ipairs(column:GetChildren())do if n:IsA("GuiObject")and n.Visible then
      contained(n,shop.body)
      if n:IsA("TextLabel")or n:IsA("TextButton")then fit(n)end
      for _,label in ipairs(n:GetChildren())do if label:IsA("TextLabel")and label.Visible then fit(label)end end
     end end
    end
    shop:close()
   end)
   test(tostring(size).." Pocket menu contains only three requested routes and no bottom copy",function()
    menu:update(snapshot());menu:open();settle();menu:layout();settle()
    assert(#menu.destinations==3 and not menu.playHint.Visible and menu.playHint.Size.Y.Offset==0)
    assert(not menu:activate("pets")and not menu:activate("style"))
    for _,e in ipairs(menu.destinations)do contained(e.button,menu.body);fit(e.title);if e.subtitle.Visible then fit(e.subtitle)end end
    for _,n in ipairs(menu.card:GetDescendants())do assert(n.Name~="MoldHighlight"and n.Name~="UpperSheen"and n.Name~="Accent"and n.Name~="SelectedGlint"and n.Name~="SelectedEdge")end
    menu:close()
   end)
  end
 end)
 if hue then hue:destroy()end;if shop then shop:close();shop.shade:Destroy()end;if menu then menu.shade:Destroy()end
 root:Destroy();assert(ok,problem);return cases
end
