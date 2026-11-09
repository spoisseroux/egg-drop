-- A measured horizontal rail; choices beneath it retain their vertical scroller.
local Art=require(script.Parent.DeckArt)
local Rail={};Rail.__index=Rail
local function place(n,x,y,w,h)n.Position,n.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)end
local function arrow(parent,name,caption,callback)
 local n=Instance.new("TextButton");n.Name,n.Text,n.Parent=name,caption,parent;n.BorderSizePixel=0;n.ZIndex=parent.ZIndex+2
 Art.button(n,8);Art.type(n,"Action");Art.bind(n,{BackgroundColor3="raised",TextColor3="text"});n.Activated:Connect(callback);return n
end
function Rail.new(parent,tabs)
 local root=Art.frame(parent,"EditorTabs","panel",UDim2.fromOffset(0,0),UDim2.fromOffset(100,44),parent.ZIndex+1);root.BackgroundTransparency=1
 local self=setmetatable({root=root,tabs=tabs,connections={}},Rail)
 local scroll=Instance.new("ScrollingFrame");scroll.Name="TabWindow";scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=0
 scroll.Active=true;scroll.ScrollingDirection=Enum.ScrollingDirection.X;scroll.ElasticBehavior=Enum.ElasticBehavior.Never;scroll.ClipsDescendants=true;scroll.ZIndex=root.ZIndex+1;scroll.Parent=root;self.scroll=scroll
 self.left=arrow(root,"EarlierTabs","‹",function()self:scrollBy(-1)end);self.right=arrow(root,"LaterTabs","›",function()self:scrollBy(1)end)
 self.left:SetAttribute("AccessibleLabel","Earlier companion tabs");self.right:SetAttribute("AccessibleLabel","Later companion tabs")
 for _,tab in ipairs(tabs)do tab.Parent=scroll;table.insert(self.connections,tab.SelectionGained:Connect(function()self:ensure(tab)end))end
 table.insert(self.connections,scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()self:refreshEdges()end))
 return self
end
function Rail:refreshEdges()
 if self.destroyed then return end
 local maximum=math.max(0,self.scroll.CanvasSize.X.Offset-self.scroll.Size.X.Offset)
 self.left.Interactable=self.overflow and self.scroll.CanvasPosition.X>1;self.right.Interactable=self.overflow and self.scroll.CanvasPosition.X<maximum-1
 Art.control(self.left,false,self.left.Interactable);Art.control(self.right,false,self.right.Interactable)
end
function Rail:ensure(tab)
 if self.destroyed or not tab or not tab.Visible or tab.Parent~=self.scroll then return end
 local x,w=tab.Position.X.Offset,tab.Size.X.Offset;local current=self.scroll.CanvasPosition.X;local viewport=self.scroll.Size.X.Offset
 local wanted=if x<current+6 then x-6 elseif x+w>current+viewport-6 then x+w-viewport+6 else current
 self.scroll.CanvasPosition=Vector2.new(math.clamp(wanted,0,math.max(0,self.scroll.CanvasSize.X.Offset-viewport)),0);self:refreshEdges()
end
function Rail:scrollBy(direction)
 local viewport=self.scroll.Size.X.Offset
 self.scroll.CanvasPosition=Vector2.new(math.clamp(self.scroll.CanvasPosition.X+direction*math.max(44,viewport*.75),0,math.max(0,self.scroll.CanvasSize.X.Offset-viewport)),0);self:refreshEdges()
end
function Rail:layout(x,y,width,style,active)
 local entries={};local total=12;local height=44
 for _,tab in ipairs(self.tabs)do tab.Parent=self.scroll end
 for _,tab in ipairs(self.tabs)do if tab.Visible then
  style(tab,"Action");local w=math.max(44,math.ceil(Art.textWidth(tab)+24));height=math.max(height,Art.actionHeight(tab,w));table.insert(entries,{node=tab,width=w});total+=w+4
 end end
 if #entries>0 then total-=4 end
 self.overflow=total>width;local inset=if self.overflow then 48 else 0;local window=math.max(1,width-inset*2)
 self.left.Visible,self.right.Visible=self.overflow,self.overflow;place(self.root,x,y,width,height+6);place(self.scroll,inset,0,window,height+6)
 place(self.left,0,3,44,height);place(self.right,width-44,3,44,height)
 local extra=if self.overflow then 0 else math.max(0,math.floor(width-total));local cursor=6
 for i,entry in ipairs(entries)do
  local share=math.floor(i*extra/math.max(1,#entries))-math.floor((i-1)*extra/math.max(1,#entries));local w=entry.width+share
  place(entry.node,cursor,3,w,height);cursor+=w+4
 end
 local canvas=if self.overflow then cursor+2 else width
 self.scroll.CanvasSize=UDim2.fromOffset(canvas,0);self.scroll.ScrollingEnabled=self.overflow
 self.scroll.CanvasPosition=Vector2.new(math.clamp(self.scroll.CanvasPosition.X,0,math.max(0,canvas-window)),0)
 self:ensure(active);self:refreshEdges();return height+6
end
function Rail:destroy()
 if self.destroyed then return end;self.destroyed=true;for _,c in ipairs(self.connections)do c:Disconnect()end;self.root:Destroy()
end
return Rail
