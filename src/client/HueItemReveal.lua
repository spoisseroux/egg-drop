-- Item adapter for the same receipt-owned timeline used by companion hatches.
local Cinematic=require(script.Parent.HatchCinematic)
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
function Reveal:clear()
 self.generation+=1;if self.cinematic then self.cinematic:destroy();self.cinematic=nil end
 -- This dedicated illustration seat is exclusively owned by the adapter. It
 -- may still contain the preceding shop egg or sizing decoration when no
 -- cinematic has been built; retire those as well as the shared timeline.
 for _,node in ipairs(self.parent:GetChildren())do node:Destroy()end
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
