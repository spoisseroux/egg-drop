-- Client LocalScript QA only. Current single-portrait versus owned-grid workload;
-- this does not reconstruct the published v344 runtime or measure physical phones.
return function(client,parent)
 local Run=game:GetService("RunService");local Gui=game:GetService("GuiService")
 local View=require(client.HueEggView);local Intent=require(client.HueIntent)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Hue=require(game.ReplicatedStorage.Shared.HueCatalog)
 local Materials=require(game.ReplicatedStorage.Shared.MaterialCatalog)
 require(script.Parent.PetAssetsReadyFixture)(client)
 local previous=Gui.SelectedObject;local root=Instance.new("Frame");root.Name="_OwnedEditorBenchmark";root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Parent=parent
 local view;local writes=0
 local intent=Intent.new({id=function()return "benchmark-no-command"end,send=function()writes+=1;error("editor benchmark must never send")end,changed=function()if view then view:refresh()end end})
 local state={status="Ready",revision=1,nectar=64,inventoryMask=127,hueInventory={},petHues={},materialUnlocks={},petMaterials={},materialAvailable=true}
 for _,id in ipairs(Materials.PaidOrder)do state.materialUnlocks[id]=true end
 for _,pet in ipairs(Pets.collection)do state.petHues[pet.id]={main=Hue.emptyCounts(),secondary=Hue.emptyCounts()};state.petMaterials[pet.id]="standard"end
 view=View.new(root,intent,{activePet=function()return "pip"end,reduceEffects=function()return false end,appearance=function()return {charmVisible=true,charmShape="ring",finish="standard"}end})
 local function frames(count)local times={};for _=1,count do table.insert(times,Run.RenderStepped:Wait()*1000)end;return times end
 local function percentile(values,fraction)local copy=table.clone(values);table.sort(copy);return copy[math.ceil(#copy*fraction)]end
 local function counts()
  local models=if view.visual then 1 else 0
  for _,entry in pairs(view.gridPreviews)do if entry.visual then models+=1 end end
  local all,parts,surfaces=0,0,0
  for _,node in ipairs(root:GetDescendants())do all+=1;if node:IsA("BasePart")then parts+=1 elseif node:IsA("SurfaceAppearance")then surfaces+=1 end end
  return {models=models,instances=all,parts=parts,surfaces=surfaces}
 end
 local rounds={};local ok,problem=pcall(function()
  for index,tab in ipairs({"hue","pet","pet","hue","hue","pet"})do
   assert(view:open(state,if tab=="pet"then "pet"else "palette","pip"));frames(60)
   local opened=counts();assert(opened.models>=1 and opened.models<=7 and view.portraitClock,"preview budget or scheduler invalid")
   local size=view.shade.AbsoluteSize;local samples=frames(120);local after=counts()
   assert(size==view.shade.AbsoluteSize and opened.instances==after.instances and opened.models==after.models,"sample changed geometry/loading; rerun after stable assets")
   view:close("benchmark");frames(3);local closed=counts()
   assert(not view.portraitClock and(tab~="pet"or closed.models==0),"closed grid retained a model or scheduler")
   rounds[index]={tab=tab,viewport=tostring(size),preference=Gui.PreferredTextSize.Name,warmFrames=60,sampleFrames=120,frameMs=samples,
    frameP50Ms=percentile(samples,.50),frameP95Ms=percentile(samples,.95),open=opened,closed=closed}
  end
 end)
 view:destroy();root:Destroy()
 if previous and previous.Parent then Gui.SelectedObject=previous end
 assert(ok,problem);assert(writes==0)
 local byTab={hue={},pet={}}
 for _,round in ipairs(rounds)do table.insert(byTab[round.tab],round.frameP95Ms)end
 return {rounds=rounds,singlePortraitMedianP95Ms=percentile(byTab.hue,.50),ownedGridMedianP95Ms=percentile(byTab.pet,.50),
  persistentWrites=false,modelLimit=7,comparison="current production Hue single portrait versus visible seven-owned Pet grid; not historical v344",physicalDevice=false}
end
