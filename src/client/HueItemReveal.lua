-- Item adapter for the same receipt-owned timeline used by companion hatches.
-- QA v685 H2: when the host gives `options.stage` (HueEggView), the native scene plays on
-- the full-screen HatchItemStage, which ends on the host's receipt actions.
local Cinematic=require(script.Parent.HatchCinematic)
local ItemStage=require(script.Parent.HatchItemStage)
local JarArt=require(script.Parent.HueJarArt)
local Identity=require(script.Parent.HatchIdentity)
local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Reveal={};Reveal.__index=Reveal
function Reveal.new(parent,options)return setmetatable({parent=parent,options=options or {},generation=0,seen={}},Reveal)end
function Reveal:finish()if self.cinematic then self.cinematic:finishStatic()end;self.active=false end
function Reveal:skip()if self.cinematic and self.cinematic:skip()then self.active=false;return true end;return false end
function Reveal:consumeSkipInput()return self.cinematic~=nil and self.cinematic:consumeSkipInput()end
function Reveal:inputLocked()
 if not self.cinematic then return false end
 if self.cinematic.getPresentationState then return self.cinematic:getPresentationState().inputLocked==true end
 return self.cinematic.active==true
end
function Reveal:receiptReady()
 if not self.cinematic then return false end
 if self.cinematic.getPresentationState then return self.cinematic:getPresentationState().receiptReady==true end
 return not self.cinematic.active
end
function Reveal:identityReady(result)return Identity.ready(self,result or self.result)end
function Reveal:paintIdentity()
 local ready=self:identityReady()
 self.parent:SetAttribute("ResultIdentityReady",ready);self.parent:SetAttribute("ResultIdentityId",self.resultId)
 local c=self.cinematic;local graphic=c and c.getItemGraphic and c:getItemGraphic()
 self.identityLabels=self.identityLabels or setmetatable({},{__mode="k"})
 if graphic then
  local nodes=graphic:GetDescendants();table.insert(nodes,graphic)
  for _,node in ipairs(nodes)do
   local label=node:GetAttribute("AccessibleLabel")
   if label and self.identityLabels[node]==nil then self.identityLabels[node]=label end
   if self.identityLabels[node]~=nil then node:SetAttribute("AccessibleLabel",if ready then self.identityLabels[node]else Copy.get("hatch.display.wait"))end
  end
 end
 return ready
end
function Reveal:identityChanged()
 if self.destroyed then return end
 if self:paintIdentity()and not self.identityNotified then
  self.identityNotified=true
  if not self.showing and self.options.onIdentityReady then self.options.onIdentityReady()end
 end
end
function Reveal:cancel()self.generation+=1;self:finish()end
function Reveal:clearStage()
 local stage=self.stage;self.stage=nil
 if stage then
  if self.cinematic and self.cinematic.borrowedStage==stage then self.cinematic.borrowedStage=nil end
  stage:destroy()
 end
end
-- Full-screen stage over the host. The cinematic keeps its one scene and clock; the stage
-- borrows the scene and is painted from HatchCinematic:paint like the pet stage.
function Reveal:openStage(recipe,result)
 local host=self.options.stage;local c=self.cinematic
 if not host or not c or not c.nativeScene or not host.parent or(self.options.stageFactory==nil and c.nativeScene.borrow==nil)then return false end
 local ok,stage=pcall((self.options.stageFactory or ItemStage.show),host.parent,{
  scene=c.nativeScene,kind=recipe,tier=if c.rarityState then c.rarityState.tier else "Neutral",result=result,instant=not c.active,
  reduced=function()return c:reduced()end,owns=host.owns,cover=host.cover,zIndex=host.zIndex,
  name=function()return if host.name then host.name(result)else nil end,
  detail=function()return if host.detail then host.detail(result)else nil end,
  description=function()return if host.description then host.description(result)else(ItemStage.describe or function()return nil end)(recipe,result)end,
  actions=function()return if host.actions then host.actions(result)else {}end,
  onSkip=function()self:skip()end,onClose=host.close,consumeSkipInput=function()return self:consumeSkipInput()end})
 if not ok then warn("Item reveal stage could not open: "..tostring(stage));return false end
 self.stage=stage;c.borrowedStage=stage
 if c.presentationSample then stage:updateExternal(c.age,c.presentationSample)end
 return true
end
function Reveal:clear()
 self.generation+=1
 -- QA R4: a stage that is on screen leaves smoothly (HatchItemStage:dismiss). It keeps the
 -- cinematic's borrowed scene until it is gone, so the item never blinks out mid-fade; this
 -- adapter is free for the next result at once.
 local stage,cinematic,leaving=self.stage,self.cinematic,nil
 if stage and cinematic and type(stage.dismiss)=="function"then
  local frame=cinematic.frame
  if stage:dismiss(function()cinematic:destroy()end)then
   self.stage=nil;self.cinematic=nil;leaving=frame
   if cinematic.borrowedStage==stage then cinematic.borrowedStage=nil end
   if cinematic.stopAudio then cinematic:stopAudio()end
   frame.Visible=false
  end
 end
 self:clearStage();if self.cinematic then self.cinematic:destroy();self.cinematic=nil end
 -- This dedicated illustration seat is exclusively owned by the adapter. It
 -- may still contain the preceding shop egg or sizing decoration when no
 -- cinematic has been built; retire those as well as the shared timeline.
 for _,node in ipairs(self.parent:GetChildren())do if node~=leaving then node:Destroy()end end
 self.jar,self.whole,self.top,self.bottom,self.topArt,self.bottomArt=nil,nil,nil,nil,nil,nil
 self.resultId=nil;self.result=nil;self.identityLabels=nil;self.identityNotified=nil;self.active=false
 self.parent:SetAttribute("ResultIdentityReady",false);self.parent:SetAttribute("ResultIdentityId",nil)
end
function Reveal:show(result,animate)
 if self.destroyed or not result or not result.id or(not result.itemId and not result.finishId and not result.toyId and not result.featureId)then return false end
 if self.resultId==result.id then self.active=self:inputLocked();self:paintIdentity();return false end
 self:clear();self.resultId=result.id;self.result=result
 local recipe=self.options.recipeId or "hue";local presentation=table.clone(result)
 if result.featureId=="wings"then presentation.rare=true end
 local builder=self.options.resultBuilder or function(parent,r,position,size,z)return JarArt.create(parent,r.itemId,position,size,z)end
 self.cinematic=(self.options.cinematicFactory or Cinematic.new)(self.parent,self.options.audio,self.options.reduceEffects,self.options.owns)
 self.cinematic.frame.BackgroundTransparency=1
 local fresh=not self.seen[result.id];self.seen[result.id]=true
 local generation=self.generation
 self.showing=true
 self.cinematic:play(presentation,function()if self.generation==generation and not self.destroyed then self.active=false;self:identityChanged()end end,
  {nativeDisplay=self.options.nativeDisplay~=false,kind=recipe,recipeId=recipe,hideLabels=true,resultBuilder=builder,skipIntro=not animate or not fresh,
   onPresented=function()if self.generation==generation and not self.destroyed then self:identityChanged()end end})
 if self.options.nativeDisplay~=false then self:openStage(recipe,result)end
 self.showing=nil
 if self.options.nativeDisplay~=false and self.cinematic.getItemGraphic then
  self.jar=self.cinematic:getItemGraphic();self.whole,self.top,self.bottom,self.topArt,self.bottomArt=nil,nil,nil,nil,nil
 else
  self.jar=self.cinematic.heroGraphic;self.whole=self.cinematic.shell
  self.top,self.bottom=self.cinematic.discoveryArt.top,self.cinematic.discoveryArt.bottom
  self.topArt,self.bottomArt=self.cinematic.discoveryArt.topArt,self.cinematic.discoveryArt.bottomArt
 end
 self.active=self:inputLocked();self:paintIdentity();return self.active
end
function Reveal:destroy()if self.destroyed then return end;self:clear();self.destroyed=true end
return Reveal
