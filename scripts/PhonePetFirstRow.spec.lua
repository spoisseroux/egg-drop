-- The photographed749x381 safe landscape viewport at native Largest.
return function(client,parent)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent)
 local H=require(game.ReplicatedStorage.Shared.HueCatalog);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local root=Instance.new("Frame");root.Name="_PhonePetFirstRow";root.Size=UDim2.fromOffset(749,381);root.Parent=parent
 local state={status="Ready",revision=1,nectar=24,inventoryMask=127,petHues={},hueInventory={}}
 for _,pet in ipairs(Pets.collection)do state.petHues[pet.id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
 local view=View.new(root,Intent.new({id=function()return "first-row"end,send=function()error("fixture must not send")end,changed=function()end}),{appearance=function()return{charmVisible=false}end})
 local function frames()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local ok,problem=pcall(function()
  frames();view:open(state,"pet","pip");frames();view:layout();frames()
  assert(view.body.CanvasPosition.Y==0,"first row must be readable before any user scroll")
  local first=view.gridPreviews[Pets.collection[1].id];local last=view.gridPreviews[Pets.collection[4].id]
  assert(first.button.AbsolutePosition.Y==last.button.AbsolutePosition.Y)
  assert(view.gridPreviews[Pets.collection[5].id].button.AbsolutePosition.Y>first.button.AbsolutePosition.Y,"four plus three row structure changed")
  for index=1,4 do local entry=view.gridPreviews[Pets.collection[index].id];local button=entry.button;local viewport=entry.viewport
   assert(button.AbsoluteSize.X>=44 and button.AbsoluteSize.Y>=44 and viewport.AbsoluteSize.X>=44)
   assert(viewport.AbsoluteSize.X==viewport.AbsoluteSize.Y,"preview must stay square")
   local center=viewport.AbsolutePosition.X+viewport.AbsoluteSize.X*.5
   assert(math.abs(center-button.AbsolutePosition.X-button.AbsoluteSize.X*.5)<.6,"preview not centered in unchanged column")
   for _,label in ipairs({entry.caption,entry.active})do
    assert(label.TextFits and label.AbsolutePosition.Y>=view.body.AbsolutePosition.Y)
    assert(label.AbsolutePosition.Y+label.AbsoluteSize.Y<=view.body.AbsolutePosition.Y+view.body.AbsoluteWindowSize.Y-.9,"first-row name or Active clipped: "..label.Text)
   end
  end
  assert(view.petTab.TextFits and view.petTab.AbsoluteSize.Y>=44,"tab type or target changed")
 end)
 view:destroy();root:Destroy();assert(ok,problem)
 return {"749x381 first-row four names and Active visible before scroll with centered square previews"}
end
