-- Quest log host (QA 2026-11-13 Q5). The quest log is no longer a deck overlay: it
-- opens from the garden machine hub's Quests tile, so it lives in its own ScreenGui
-- (the caller makes it) and this host gives QuestLog the overlay shape it was built
-- for: {layer, content, scale, onLayout}. Desktop: the 848 x 608 LCD glass, centred
-- and scaled to fit (content keeps its 848 x 608 units). Phone (Kit.compactRule): the
-- full width under the Roblox controls at scale 1, where QuestLog draws its own sheet.
-- The shade joins the Q2 shade stack while the layer is visible.
local Kit=require(script.Parent.DeckKit)
local Host={}
Host.__index=Host
Host.Size=Vector2.new(848,608)
Host.Margin=24

-- Pure: the layout for a root size. Phone: {phone=true, W, H, kx=0, kh=0, hx=24, top};
-- regular: {phone=false, scale}.
function Host.layoutFor(size,kh)
 if Kit.compactRule(size.X,size.Y)then
  local top=(kh or 58)+2
  return{phone=true,W=math.floor(size.X),H=math.floor(size.Y)-top,kx=0,kh=0,hx=24,top=top}
 end
 return{phone=false,scale=math.max(.1,math.min(1.2,(size.X-Host.Margin)/Host.Size.X,(size.Y-Host.Margin)/Host.Size.Y))}
end

-- root: a full-screen Frame in the quest log's ScreenGui.
function Host.new(root)
 local self=setmetatable({root=root},Host)
 self.shade=Kit.modalShade(root,"QuestLogShade",30)
 local layer=Kit.frame(root,"QuestLog","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),18)
 layer.AnchorPoint=Vector2.new(.5,.5);layer.ZIndex=31;layer.ClipsDescendants=true;layer.Visible=false;layer.Active=true
 self.stroke=Kit.stroke(layer)
 local tint=Kit.frame(layer,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1),18);tint.BackgroundTransparency=0;tint.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",tint,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 local content=Kit.frame(layer,"Content",nil,UDim2.new(),UDim2.fromOffset(848,608));content.ZIndex=layer.ZIndex+2
 local scale=Kit.node("UIScale",content,{Scale=1})
 -- The overlay QuestLog.new expects (it sets onLayout itself).
 self.overlay={layer=layer,content=content,scale=scale,tint=tint,host=self}
 self.connections={
  layer:GetPropertyChangedSignal("Visible"):Connect(function()self:sync()end),
  root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if layer.Visible then self:fit()end end),
 }
 return self
end
-- Shade in or out with the layer; lay out when it shows.
function Host:sync()
 local layer=self.overlay.layer
 if layer.Visible then
  Kit.shadeOpen(self,self.shade,function(covered)layer.Interactable=not covered end)
  self:fit()
 else Kit.shadeClose(self)end
end
function Host:fit()
 local o=self.overlay;local layer,content=o.layer,o.content
 local _,kh=Kit.keepOut()
 local l=Host.layoutFor(self.root.AbsoluteSize,kh)
 self.layout=l
 if l.phone then
  layer.AnchorPoint=Vector2.zero;layer.Position=UDim2.fromOffset(0,l.top);layer.Size=UDim2.fromOffset(l.W,l.H)
  layer.BackgroundTransparency=1;layer.ClipsDescendants=false;o.tint.Visible=false;self.stroke.Enabled=false
  content.Size=UDim2.fromOffset(l.W,l.H);o.scale.Scale=1
  Kit.setShadeAlpha(self.shade,1)
 else
  layer.AnchorPoint=Vector2.new(.5,.5);layer.Position=UDim2.fromScale(.5,.5)
  layer.Size=UDim2.fromOffset(math.floor(Host.Size.X*l.scale+.5),math.floor(Host.Size.Y*l.scale+.5))
  layer.BackgroundTransparency=0;layer.ClipsDescendants=true;o.tint.Visible=true;self.stroke.Enabled=true
  content.Size=UDim2.fromOffset(Host.Size.X,Host.Size.Y);o.scale.Scale=l.scale
  Kit.setShadeAlpha(self.shade,Kit.ShadeAlpha)
 end
 layer:SetAttribute("Layout",if l.phone then "phone"else "regular")
 if o.onLayout then o.onLayout(if l.phone then{phone=true,W=l.W,H=l.H,kx=0,kh=0,hx=l.hx}else nil)end
 return l
end
function Host:isOpen()return self.overlay.layer.Visible end
function Host:destroy()
 for _,connection in ipairs(self.connections)do connection:Disconnect()end
 Kit.shadeClose(self)
 self.overlay.layer:Destroy();self.shade:Destroy()
end
return Host
