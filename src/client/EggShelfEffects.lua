-- One passive glint, one visible-sheet clock; no offscreen card clocks.
local Run=game:GetService("RunService");local Gui=game:GetService("GuiService");local Input=game:GetService("UserInputService")
local Art=require(script.Parent.DeckArt)
local Shelf={};Shelf.__index=Shelf
local function visible(node)
 if not node or not node.Parent or node.AbsoluteSize.X<1 or node.AbsoluteSize.Y<1 then return false end
 local l,t=node.AbsolutePosition.X,node.AbsolutePosition.Y;local r,b=l+node.AbsoluteSize.X,t+node.AbsoluteSize.Y
 local p=node
 while p do
  if p:IsA("GuiObject")then
   if not p.Visible then return false end
   if p.ClipsDescendants then
    local x,y=p.AbsolutePosition.X,p.AbsolutePosition.Y;local w,h=p.AbsoluteSize.X,p.AbsoluteSize.Y
    if r<=x or l>=x+w or b<=y or t>=y+h then return false end
   end
  elseif p:IsA("ScreenGui")and not p.Enabled then return false end
  p=p.Parent
 end
 return true
end
function Shelf.new(parent,options)
 local self=setmetatable({parent=parent,options=options or {},eggs={},connections={},age=0,index=0,windowActive=true},Shelf)
 local function watch(signal,fn)table.insert(self.connections,signal:Connect(fn))end
 watch(parent:GetPropertyChangedSignal("Visible"),function()self:refresh()end)
 watch(Gui:GetPropertyChangedSignal("MenuIsOpen"),function()self:refresh()end)
 watch(Gui:GetPropertyChangedSignal("ReducedMotionEnabled"),function()self:refresh()end)
 watch(Input.WindowFocusReleased,function()self.windowActive=false;self:refresh()end)
 watch(Input.WindowFocused,function()self.windowActive=true;self:refresh()end)
 watch(Input.TextBoxFocused,function()self:refresh()end);watch(Input.TextBoxFocusReleased,function()self:refresh()end)
 watch(parent.Destroying,function()self:destroy()end)
 return self
end
function Shelf:owned()
 return not self.destroyed and self.windowActive and visible(self.parent)and not Gui.MenuIsOpen and Input:GetFocusedTextBox()==nil and(not self.options.owns or self.options.owns())
end
function Shelf:reduced()return Gui.ReducedMotionEnabled or(self.options.reduceEffects and self.options.reduceEffects())end
function Shelf:clearGlint()if self.glint then self.glint:Destroy();self.glint=nil end;self.glintScale=nil end
function Shelf:choose()
 self:clearGlint();local count=#self.eggs
 for _=1,count do
  self.index=self.index%count+1;local egg=self.eggs[self.index]
  if visible(egg)then
   local host=egg:FindFirstChild("RegisteredShell")or egg
   local glint=Art.frame(host,"ShelfGlint",Color3.fromHex("#FFFFEA"),UDim2.fromScale(.32,.28),UDim2.fromScale(.15,.15),host.ZIndex+10)
   glint.AnchorPoint=Vector2.new(.5,.5);glint.BackgroundTransparency=1;self.glint=glint
   local aspect=Instance.new("UIAspectRatioConstraint");aspect.AspectRatio=1;aspect.Parent=glint
   local scale=Instance.new("UIScale");scale.Parent=glint;self.glintScale=scale
   for _,seat in ipairs({{.42,0,.16,1},{0,.42,1,.16}})do
    local ray=Art.frame(glint,"IvoryRay",Color3.fromHex("#FFFFEA"),UDim2.fromScale(seat[1],seat[2]),UDim2.fromScale(seat[3],seat[4]),glint.ZIndex)
    Art.corner(ray,100)
   end
   return true
  end
 end
 return false
end
function Shelf:setEggs(eggs)self.eggs=eggs or {};self.index=0;self.age=3.2;self:clearGlint();self:refresh()end
function Shelf:disconnect()if self.clock then self.clock:Disconnect();self.clock=nil end end
function Shelf:refresh()
 if not self:owned()or #self.eggs==0 then self:disconnect();self:clearGlint();return end
 if self:reduced()then self:disconnect();if not self.glint or not visible(self.glint)then self:choose()end;if self.glintScale then self.glintScale.Scale=.75 end;return end
 if not self.clock then self.clock=Run.RenderStepped:Connect(function(dt)self:step(dt)end)end
end
function Shelf:step(dt)
 if not self:owned()or self:reduced()then self:refresh();return end
 self.age+=math.max(0,math.min(dt,.25))
 if self.age>=3.2 then self.age=0;self:choose()end
 if self.glint then
  if not visible(self.glint.Parent)or self.age>=.22 then self:clearGlint()
  else local t=self.age/.22;self.glintScale.Scale=math.sin(math.pi*t)^.8 end
 end
end
function Shelf:destroy()
 if self.destroyed then return end;self.destroyed=true;self:disconnect();self:clearGlint()
 for _,connection in ipairs(self.connections)do connection:Disconnect()end;table.clear(self.connections);table.clear(self.eggs)
end
return Shelf
