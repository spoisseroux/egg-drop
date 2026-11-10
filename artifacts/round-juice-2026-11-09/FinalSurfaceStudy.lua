-- QA ONLY LocalScript in PlayerScripts._RoundFinalQA. No remote/profile writes.
-- Attributes Mode="Hue" (default)|"Material"|"Round", Channel="main"|"secondary",
-- Finish="matte"|"gloss". Round is manually sampled at .18 seconds, not ordinary play.
local Players=game:GetService("Players");local Run=game:GetService("RunService")
local player=Players.LocalPlayer;local client=player.PlayerScripts.Client
local Art=require(client.DeckArt);local HueView=require(client.HueEggView)
local Hue=require(client.HueIntent);local Material=require(client.MaterialIntent)
local H=require(game.ReplicatedStorage.Shared.HueCatalog);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
local Recap=require(client.RoundRecap);local End=require(client.RoundEndPresentation)
local Objectives=require(game.ReplicatedStorage.Shared.FieldObjectives);local Eggs=require(game.ReplicatedStorage.Shared.EggCatalog)
local helper=player.PlayerScripts:FindFirstChild("_RoundQA")
helper=helper and helper:FindFirstChild("PetAssetsReadyFixture")
if helper then require(helper)(client)end
local gui=Instance.new("ScreenGui");gui.Name="_FinalSurfaceStudy";gui.IgnoreGuiInset=true;gui.DisplayOrder=960;gui.Parent=player.PlayerGui
local root=Art.frame(gui,"Study",Color3.fromHex("#DCEAE5"),UDim2.fromScale(.015,.025),UDim2.fromScale(.97,.95),2)
local caption=Art.text(root,"FixtureCaption","",UDim2.fromOffset(12,0),UDim2.new(1,-24,0,32),Color3.fromHex("#173D36"),19);caption.TextXAlignment=Enum.TextXAlignment.Center
local stage=Art.frame(root,"ProductionSurface",Art.Ink,UDim2.fromOffset(0,34),UDim2.new(1,0,1,-38),3);stage.BackgroundTransparency=1
local view,intent,material,ending,recap;local stopped=false;local epoch=0
local function clear()
 if ending then ending:destroy();ending=nil end
 if view then view:destroy();view=nil end
 if intent then if type(intent.destroy)=="function"then intent:destroy()end;intent=nil end
 if material then if type(material.destroy)=="function"then material:destroy()end;material=nil end
 for _,node in ipairs(stage:GetChildren())do node:Destroy()end;recap=nil
end
local function state()
 local rows={};for _,pet in ipairs(Pets.collection)do rows[pet.id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
 rows.pip.main={rose=2,tide=1,citrus=0,iris=3};rows.pip.secondary={rose=0,tide=2,citrus=1,iris=0}
 return{status="Ready",revision=10,nectar=24,inventoryMask=127,petHues=rows,hueInventory={rose=3,tide=3,citrus=3,iris=3,reset=1},materialAvailable=true,materialUnlocks={matte=true,gloss=true},petMaterials={pip="standard"}}
end
local function rebuild()
 epoch+=1;local token=epoch
 task.defer(function()
  if stopped or token~=epoch then return end;clear();Run.Heartbeat:Wait();if stopped or token~=epoch then return end
  local mode=script:GetAttribute("Mode")or"Hue"
  caption.Text=if mode=="Round"then "ROUND FINISH · production recap · manually sampled .18s FIXTURE"elseif mode=="Material"then "MATERIAL RECEIPT · production panel / saved result FIXTURE"else "HUE EDITOR · white zero notches / mixed saved colors FIXTURE"
  if mode=="Round"then
   local host=Art.frame(stage,"RecapHost","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(math.min(640,stage.AbsoluteSize.X-16),math.min(640,stage.AbsoluteSize.Y-12)),5);host.AnchorPoint=Vector2.new(.5,.5);Art.panel(host,16,Art.Amber)
   recap=Recap.new(host,nil,function()return true end);recap.frame.Visible=true;recap.endArt.Visible=true
   local board=Instance.new("Folder");board.Name="FixtureBoard";board.Parent=stage
   for key,value in pairs({ResetId=8,RunSequence=71,Mode="Board",RoundOver=false,FieldPhase="Playing",FieldSuccess=false,FieldReason="",FieldFinalStage=0})do board:SetAttribute(key,value)end
   for index=1,6 do local p=Instance.new("Part");p.Anchored=true;p.Size=Vector3.one;p.Position=Vector3.new(-2.5+index*.7,2+index*.2,0);p:SetAttribute("BoardSerial",8);p:SetAttribute("EggId",index);p:SetAttribute("Tier",1+(index-1)%5);p.Parent=board end
   local d=Objectives.create("creek_crossing",17)
   local descriptor={sequence=71,templateId=d.id,title=d.title,dynamics={id=d.dynamics.id,label=d.dynamics.label},goals=d.goals,step=1,progress=0,target=1,complete=false}
   ending=End.new(board,{readView=function()return descriptor end,owns=function()return not stopped and token==epoch end,reduced=function()return false end,target=function()return recap.endArt end})
   ending:observe();descriptor.step=3;descriptor.target=0;descriptor.complete=true
   board:SetAttribute("FieldPhase","Complete");board:SetAttribute("FieldSuccess",true);board:SetAttribute("FieldFinalStage",2);board:SetAttribute("FieldReason",d.title.." complete");board:SetAttribute("RoundOver",true)
   local final=assert(ending:observe())
   recap:update(630,4,2,nil,0,nil,0,700)
   recap:updateField({sequence=71,status="Saved",success=final.success,reason=final.reason,stage=final.stage,objective=final.objective,phase="Complete",award=8,daily=0,balance=24,recipe=Eggs.ById.meadow,reward={sequence=71,total=8,base=8,daily=0,contracts={}}})
   recap:layoutField(host.AbsoluteSize.Y);Run.Heartbeat:Wait();if stopped or token~=epoch then return end
   ending:step(.18);host:SetAttribute("FixtureAge",.18);return
  end
  local deps={id=function()return"surface-fixture"end,send=function()error("Fixture must never send a gameplay request")end,changed=function()if view then view:refresh()end end}
  intent=Hue.new(deps);material=Material.new(deps)
  view=HueView.new(stage,intent,{materialIntent=material,reduceEffects=function()return true end,canCustomize=function()return true end,appearance=function()return{charmVisible=false}end})
  local snapshot=state()
  if mode=="Material"then
   snapshot.pendingMaterialResult={id="surface-material-"..tostring(epoch),finishId=script:GetAttribute("Finish")or"matte",revision=10,catalogVersion=1}
   view:open(snapshot,"materials","pip")
  else
   view:open(snapshot,"hue","pip");view:setTab("hue");view:chooseChannel(script:GetAttribute("Channel")or"main")
  end
 end)
end
for _,name in ipairs({"Mode","Channel","Finish"})do script:GetAttributeChangedSignal(name):Connect(rebuild)end
script.Destroying:Connect(function()stopped=true;epoch+=1;clear();gui:Destroy()end)
Run.Heartbeat:Wait();rebuild()
