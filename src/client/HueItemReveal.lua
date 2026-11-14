-- Item adapter for the same receipt-owned timeline used by companion hatches.
local Cinematic=require(script.Parent.HatchCinematic)
local JarArt=require(script.Parent.HueJarArt)
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
function Reveal:cancel()self.generation+=1;self:finish()end
function Reveal:clear()
 self.generation+=1;if self.cinematic then self.cinematic:destroy();self.cinematic=nil end
 -- This dedicated illustration seat is exclusively owned by the adapter. It
 -- may still contain the preceding shop egg or sizing decoration when no
 -- cinematic has been built; retire those as well as the shared timeline.
 for _,node in ipairs(self.parent:GetChildren())do node:Destroy()end
 self.jar,self.whole,self.top,self.bottom,self.topArt,self.bottomArt=nil,nil,nil,nil,nil,nil
 self.resultId=nil;self.active=false
end
function Reveal:show(result,animate)
 if self.destroyed or not result or not result.id or(not result.itemId and not result.finishId and not result.toyId and not result.featureId)then return false end
 if self.resultId==result.id then self.active=self:inputLocked();return false end
 self:clear();self.resultId=result.id
 local recipe=self.options.recipeId or "hue";local presentation=table.clone(result)
 if result.featureId=="wings"then presentation.rare=true end
 local builder=self.options.resultBuilder or function(parent,r,position,size,z)return JarArt.create(parent,r.itemId,position,size,z)end
 self.cinematic=(self.options.cinematicFactory or Cinematic.new)(self.parent,self.options.audio,self.options.reduceEffects,self.options.owns)
 self.cinematic.frame.BackgroundTransparency=1
 local fresh=not self.seen[result.id];self.seen[result.id]=true
 local generation=self.generation
 self.cinematic:play(presentation,function()if self.generation==generation then self.active=false end end,{nativeDisplay=self.options.nativeDisplay~=false,kind=recipe,recipeId=recipe,hideLabels=true,resultBuilder=builder,skipIntro=not animate or not fresh})
 if self.options.nativeDisplay~=false and self.cinematic.getItemGraphic then
  self.jar=self.cinematic:getItemGraphic();self.whole,self.top,self.bottom,self.topArt,self.bottomArt=nil,nil,nil,nil,nil
 else
  self.jar=self.cinematic.heroGraphic;self.whole=self.cinematic.shell
  self.top,self.bottom=self.cinematic.discoveryArt.top,self.cinematic.discoveryArt.bottom
  self.topArt,self.bottomArt=self.cinematic.discoveryArt.topArt,self.cinematic.discoveryArt.bottomArt
 end
 self.active=self:inputLocked();return self.active
end
function Reveal:destroy()if self.destroyed then return end;self:clear();self.destroyed=true end
return Reveal
