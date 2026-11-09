-- A receipt-owned shell-to-jar cue. It never gates actions or grants an item.
local TweenService=game:GetService("TweenService")
local Art=require(script.Parent.DeckArt)
local EggArt=require(script.Parent.EggArt)
local JarArt=require(script.Parent.HueJarArt)
local Reveal={};Reveal.__index=Reveal
function Reveal.new(parent,options)
 return setmetatable({parent=parent,options=options or {},generation=0,tweens={},seen={},seenOrder={},owner={}},Reveal)
end
function Reveal:finish()
 if self.whole then self.whole.Visible=false end
 if self.top then self.top.Visible=false end
 if self.bottom then self.bottom.Visible=false end
 if self.jar then self.jar.Visible=true;self.jar.Position=UDim2.fromScale(.22,.12)end
 self.active=false
end
function Reveal:cancel()
 self.generation+=1
 for _,tween in ipairs(self.tweens)do tween:Cancel()end;table.clear(self.tweens)
 if self.options.audio and self.options.audio.stopOwner then self.options.audio:stopOwner(self.owner)end
 self:finish()
end
function Reveal:later(seconds,generation,callback)
 (self.options.delay or task.delay)(seconds,function()
  if self.destroyed or generation~=self.generation or not self.parent.Parent then return end
  callback()
 end)
end
function Reveal:tween(node,seconds,properties)
 local tween=TweenService:Create(node,TweenInfo.new(seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties)
 table.insert(self.tweens,tween);tween:Play()
end
function Reveal:show(result,animate)
 if self.destroyed or not result or not result.id or not result.itemId then return false end
 if self.resultId==result.id then return false end
 self:cancel();self.resultId=result.id;local fresh=not self.seen[result.id]
 self.seen[result.id]=true;table.insert(self.seenOrder,result.id)
 if #self.seenOrder>32 then self.seen[table.remove(self.seenOrder,1)]=nil end
 for _,node in ipairs(self.parent:GetChildren())do node:Destroy()end
 self.jar=JarArt.create(self.parent,result.itemId,UDim2.fromScale(.22,.12),UDim2.fromScale(.56,.82),self.parent.ZIndex+3)
 self.whole=EggArt.create(self.parent,"hue",UDim2.fromScale(.20,.06),UDim2.fromScale(.60,.88),self.parent.ZIndex+4,"WholeShell")
 self.top=Art.frame(self.parent,"TopShellClip",Color3.new(1,1,1),UDim2.fromScale(.20,.06),UDim2.fromScale(.60,.44),self.parent.ZIndex+4);self.top.BackgroundTransparency=1;self.top.ClipsDescendants=true
 self.topArt=EggArt.create(self.top,"hue",UDim2.fromScale(0,0),UDim2.fromScale(1,2),self.top.ZIndex+1)
 self.bottom=Art.frame(self.parent,"BottomShellClip",Color3.new(1,1,1),UDim2.fromScale(.20,.50),UDim2.fromScale(.60,.44),self.parent.ZIndex+4);self.bottom.BackgroundTransparency=1;self.bottom.ClipsDescendants=true
 self.bottomArt=EggArt.create(self.bottom,"hue",UDim2.fromScale(0,-1),UDim2.fromScale(1,2),self.bottom.ZIndex+1)
 -- Six small native teeth make one clean original split, with no particle burst.
 for i=0,5 do
  local tooth=Art.frame(self.bottom,"SeamTooth"..i,Color3.fromHex("#56D4DD"),UDim2.fromScale(.12+i*.13,-.035),UDim2.fromScale(.13,.12),self.bottom.ZIndex+3);tooth.Rotation=45
 end
 self:finish()
 local reduced=self.options.reduceEffects and self.options.reduceEffects()
 if not animate or not fresh or reduced then return false end
 self.active=true;self.jar.Visible=false;self.whole.Visible=true
 local generation=self.generation
 self:later(.12,generation,function()
  self.whole.Visible=false;self.top.Visible=true;self.bottom.Visible=true
  if self.options.audio then self.options.audio:play("hatch",1.22,.24,self.owner)end
  self:tween(self.top,.19,{Position=UDim2.fromScale(.04,-.01)})
  self:tween(self.bottom,.19,{Position=UDim2.fromScale(.36,.55)})
  self:tween(self.topArt,.19,{Rotation=-10});self:tween(self.bottomArt,.19,{Rotation=10})
 end)
 self:later(.31,generation,function()
  self.jar.Visible=true;self.jar.Position=UDim2.fromScale(.22,.20)
  self:tween(self.jar,.24,{Position=UDim2.fromScale(.22,.12)})
 end)
 self:later(.60,generation,function()self:finish()end)
 return true
end
function Reveal:destroy()
 if self.destroyed then return end;self:cancel();self.destroyed=true
 for _,node in ipairs(self.parent:GetChildren())do node:Destroy()end
end
return Reveal
