-- QA ONLY. Install as a LocalScript; helper: PlayerScripts._RoundQA.PetAssetsReadyFixture.
-- Attributes: Mode="Toy"|"Hatch", Phase=number or "whole"|"split"|"reveal".
-- Hatch Kind="companion"|"hue"|"material"|"toy"|"feature"; Finish="matte"|"gloss".
-- Toy phases default to Sparkler .9, Ball .8, Bone1.2. PetId defaults to pip.
-- Manually sampled presentation: no profile, remotes, grants, saves or ordinary-play claim.
local Players=game:GetService("Players");local Run=game:GetService("RunService")
local player=Players.LocalPlayer;local client=player.PlayerScripts.Client
local qa=assert(player.PlayerScripts:FindFirstChild("_RoundQA"),"Install _RoundQA helper first")
require(assert(qa:FindFirstChild("PetAssetsReadyFixture")))(client)
local Art=require(client.DeckArt);local Factory=require(client.PetFactory)
local Play=require(client.PetPlayVisual);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
local Cinematic=require(client.HatchCinematic);local ItemArt=require(client.RewardItemArt)
local JarArt=require(client.HueJarArt);local MaterialPanel=require(client.MaterialPanel)
local gui=Instance.new("ScreenGui");gui.Name="_ToyHatchStudy";gui.IgnoreGuiInset=true;gui.DisplayOrder=950;gui.Parent=player.PlayerGui
local root=Art.frame(gui,"Study",Color3.fromHex("#DCEAE5"),UDim2.fromScale(.025,.04),UDim2.fromScale(.95,.92),2)
local title=Art.text(root,"FixtureTitle","",UDim2.fromScale(.02,.01),UDim2.fromScale(.96,.065),Color3.fromHex("#173D36"),23)
title.TextXAlignment=Enum.TextXAlignment.Center
local content=Art.frame(root,"Contents",Art.Ink,UDim2.fromScale(.01,.085),UDim2.fromScale(.98,.90),3);content.BackgroundTransparency=1
local visuals={};local cine;local panel;local generation=0;local destroyed=false
local function clear()
 if cine then cine:destroy();cine=nil end
 if panel then panel:destroy();panel=nil end
 for _,v in ipairs(visuals)do v:destroy()end;table.clear(visuals)
 for _,n in ipairs(content:GetChildren())do n:Destroy()end
end
local function toyStudy(token)
 local phases={sparkler=.9,ball=.8,bone=1.2};local pet=Pets.byId[script:GetAttribute("PetId")or"pip"]or Pets.byId.pip
 title.Text="POSE FIXTURE · Sparkler / Ball / Bone · "..pet.name.." · no profile writes"
 local entries={}
 for index,id in ipairs({"sparkler","ball","bone"})do
  local card=Art.frame(content,"Toy_"..id,Color3.fromHex("#BBD6D0"),UDim2.new((index-1)/3,5,0,0),UDim2.new(1/3,-10,1,0),4);Art.corner(card,12)
  local viewport=Instance.new("ViewportFrame");viewport.Name="ProductionPet";viewport.BackgroundTransparency=1;viewport.Position=UDim2.fromScale(.02,.015);viewport.Size=UDim2.fromScale(.96,.88);viewport.ZIndex=5;viewport.Parent=card
  viewport.Ambient=Color3.fromRGB(175,184,183);viewport.LightColor=Color3.fromRGB(255,250,231);viewport.LightDirection=Vector3.new(-1,-1.4,-3)
  local world=Instance.new("WorldModel");world.Parent=viewport
  local v=Factory.new(world,Vector3.zero,pet,.72,{charmVisible=false,toyId=id,appearanceGeneration=1})
  table.insert(visuals,v);v.reducedEffects=false;v.personalPlayEnabled=true;v.greeting=2;v.gardenBehavior="follow";v.gardenAction=nil;v.gaitWeight=0;v.cosmeticSeed=42;v.personalIdleUntil=100
  Play.reset(v);v.cosmeticTime=0;v:update(0);v.cosmeticTime=1;v:update(0)
  local attribute=script:GetAttribute("Phase");local phase=if type(attribute)=="number"then attribute else script:GetAttribute(id.."Phase")or phases[id]
  v.cosmeticTime=1+phase;v.poseDirty=true;v:update(0)
  assert(v.personalToyActive and v.personalToy,"Toy fixture must sample the real eligible production pose: "..id)
  local label=Art.text(card,"Caption",id:sub(1,1):upper()..id:sub(2).." · phase "..phase.."s",UDim2.fromScale(.02,.90),UDim2.fromScale(.96,.08),Color3.fromHex("#173D36"),19)
  label.TextXAlignment=Enum.TextXAlignment.Center
  table.insert(entries,{visual=v,viewport=viewport})
 end
 Run.Heartbeat:Wait();if destroyed or token~=generation then return end
 for _,entry in ipairs(entries)do
  local v,vp=entry.visual,entry.viewport;local box,size=v.model:GetBoundingBox()
  local aspect=vp.AbsoluteSize.X/math.max(1,vp.AbsoluteSize.Y);local tan=math.tan(math.rad(15))
  local distance=math.max(size.Y,size.X/math.max(.1,aspect))/(2*tan*.86)+size.Z*.5+.05
  local camera=Instance.new("Camera");camera.FieldOfView=30;camera.CFrame=CFrame.lookAt(box.Position+Vector3.new(distance*.12,distance*.035,distance),box.Position);camera.Parent=vp;vp.CurrentCamera=camera
 end
end
local function hatchStudy(token)
 local kind=script:GetAttribute("Kind")or"companion";local phase=script:GetAttribute("Phase")or"split"
 title.Text="HATCH FIXTURE · "..kind.." · "..tostring(phase).." · manually sampled, no purchase"
 local host=Art.frame(content,"HatchStage",Art.Ink,UDim2.fromScale(.5,.5),UDim2.fromOffset(math.min(640,content.AbsoluteSize.X-16),math.min(420,content.AbsoluteSize.Y-16)),5);host.AnchorPoint=Vector2.new(.5,.5);host.BackgroundTransparency=1
 local id="study-"..game:GetService("HttpService"):GenerateGUID(false)
 local result={id=id,petId=script:GetAttribute("PetId")or"pip",rare=script:GetAttribute("Rare")==true}
 local options={kind=kind,recipeId=if kind=="companion"then "meadow"else kind,hideLabels=kind~="companion",skipIntro=true,appearance={charmVisible=true,charmShape="ring"}}
 if kind=="hue"then
  result.itemId=script:GetAttribute("ItemId")or"rose"
  options.resultBuilder=function(parent,r,pos,size,z)return JarArt.create(parent,r.itemId,pos,size,z)end
 elseif kind=="material"then
  result.finishId=script:GetAttribute("Finish")or"matte"
  panel=MaterialPanel.new(content,nil,{});panel.root.Visible=false;options.resultBuilder=panel.reveal.options.resultBuilder
 elseif kind=="toy"then result.toyId=script:GetAttribute("ToyId")or"bone";options.resultBuilder=ItemArt.create
 elseif kind=="feature"then result.featureId=script:GetAttribute("FeatureId")or"wings";result.rare=result.featureId=="wings";options.resultBuilder=ItemArt.create end
 cine=Cinematic.new(host,nil,function()return false end,function()return not destroyed and (script:GetAttribute("Mode")or"Toy")=="Hatch"end)
 cine:play(result,nil,options);cine:disconnectClock();Run.Heartbeat:Wait()
 if destroyed or token~=generation or not cine then return end
 cine:disconnectClock();cine:layout()
 local age=if type(phase)=="number"then phase elseif phase=="whole"then .35 elseif phase=="opening"then cine.splitAt+.11 elseif phase=="split"then cine.splitAt+.16 else cine.duration
 cine.age=age;cine.active=age<cine.duration;cine:paint();cine:disconnectClock()
 host:SetAttribute("FixtureAge",age);host:SetAttribute("FixtureClock",cine.connection~=nil)
end
local function rebuild()
 generation+=1;local token=generation
 task.defer(function()
  if destroyed or token~=generation then return end;clear();Run.Heartbeat:Wait()
  if destroyed or token~=generation then return end
  if (script:GetAttribute("Mode")or"Toy")=="Hatch"then hatchStudy(token)else toyStudy(token)end
 end)
end
for _,name in ipairs({"Mode","Phase","Kind","Finish","PetId","Rare","ItemId","ToyId","FeatureId","sparklerPhase","ballPhase","bonePhase"})do script:GetAttributeChangedSignal(name):Connect(rebuild)end
script.Destroying:Connect(function()destroyed=true;generation+=1;clear();gui:Destroy()end)
Run.Heartbeat:Wait();rebuild()
