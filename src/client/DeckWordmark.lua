-- One original, passive composition for the enamel face and LCD boot.
-- Four measured runs emphasize the two capitals without letter-spacing gaps.
local Wordmark={};Wordmark.__index=Wordmark
function Wordmark.new(parent,z,Art)
 local root=Instance.new("CanvasGroup");root.Name="PocketDeckMark";root.BackgroundTransparency=1
 root.Active,root.Selectable,root.ZIndex=false,false,z;root.Rotation=-5;root.Parent=parent
 local scale=Instance.new("UIScale");scale.Name="CompactArtScale";scale.Parent=root
 local self=setmetatable({root=root,scale=scale,runs={},Art=Art},Wordmark)
 for index,copy in ipairs({"P","ocket","D","eck"})do
  local shadow=Art.text(root,"Underprint"..index,copy,UDim2.fromOffset(0,0),UDim2.fromOffset(1,1),Art.Ink,24,Art.Font.Heading)
  local face=Art.text(root,"Lettering"..index,copy,UDim2.fromOffset(0,0),UDim2.fromOffset(1,1),Art.Silver,24,Art.Font.Heading)
  for _,label in ipairs({shadow,face})do label.TextWrapped=false;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextYAlignment=Enum.TextYAlignment.Top end
  shadow.ZIndex=z;face.ZIndex=z+1;self.runs[index]={shadow=shadow,face=face,text=copy}
 end
 self.leaves={Art.leaf(root,"PLeafLeft",UDim2.fromOffset(0,0),UDim2.fromOffset(8,14),Art.Ink,-38,z+2),Art.leaf(root,"PLeafRight",UDim2.fromOffset(0,0),UDim2.fromOffset(8,14),Art.Silver,35,z+2)}
 root:SetAttribute("AccessibleLabel","PocketDeck")
 return self
end
function Wordmark:layout(width,height,preferred)
 local key=table.concat({width,height,preferred,game:GetService("GuiService").PreferredTextSize.Name},"|")
 if self.key==key then return self.width,self.height end;self.key=key
 local service=game:GetService("TextService");local Art=self.Art
 local function measure(size,initials,shortFull)
  local result,total,tall={},0,0
  for i,run in ipairs(self.runs)do
   local visible=not initials or i==1 or i==3
   local actual=if i==1 or i==3 then size else math.max(12,size-3)
   local bounds=if visible then service:GetTextSize(run.text,actual,Art.Font.Heading,Vector2.new(10000,10000))else Vector2.zero
   result[i]={w=math.ceil(bounds.X)+1,h=math.ceil(bounds.Y)+3,size=actual,visible=visible};total+=if visible then result[i].w-1 else 0;tall=math.max(tall,if visible then result[i].h else 0)
  end
  return result,total+12,tall+(if initials or shortFull then 4 else 17)
 end
 local runs,w,h,chosen,compact,initials,shortFull
 for size=preferred or 28,18,-2 do
  local candidate,cw,ch=measure(size,false)
  if cw<=width and ch<=height then runs,w,h,chosen=candidate,cw,ch,size;break end
 end
 -- A flat four-run mark can occupy the normal phone's short branding row.
 -- Keep Largest on its established initials fallback and never claim a raw fit
 -- by scaling the full name into an illegible width.
 if not runs and game:GetService("GuiService").PreferredTextSize.Name=="Medium"then
  local candidate,cw,ch=measure(16,false,true)
  if cw<=width and ch<=height then runs,w,h,chosen,compact,shortFull=candidate,cw,ch,16,true,true end
 end
 if not runs then compact=true;initials=true;chosen=math.min(preferred or 26,24);runs,w,h=measure(chosen,true)
  while (w>width or h>height)and chosen>10 do chosen-=2;runs,w,h=measure(chosen,true)end
 end
 local x=4
 for i,run in ipairs(self.runs)do local r=runs[i]
  for _,label in ipairs({run.shadow,run.face})do label.Visible=r.visible;label.TextSize=r.size;label.Size=UDim2.fromOffset(r.w+2,r.h)end
  run.face.Position=UDim2.fromOffset(x,(if compact then 1 else 13)+(chosen-r.size));run.shadow.Position=run.face.Position+UDim2.fromOffset(2,2)
  x+=if r.visible then r.w-1 else 0
 end
 self.leaves[1].Position=UDim2.fromOffset(7,2);self.leaves[2].Position=UDim2.fromOffset(16,1)
 for _,leaf in ipairs(self.leaves)do leaf.Visible=not compact end
 local fitScale=if compact and width>0 and height>0 then math.min(1,width/w,height/h)else 1
 self.scale.Scale=fitScale;self.width,self.height=w*fitScale,h*fitScale
 self.root.Size=UDim2.fromOffset(w,h)
 self.root:SetAttribute("MarkRawWidth",w);self.root:SetAttribute("MarkRawHeight",h);self.root:SetAttribute("MarkLocalScale",fitScale)
 self.root:SetAttribute("CompactMark",compact==true);self.root:SetAttribute("MarkInitials",initials==true);self.root:SetAttribute("MarkShortFull",shortFull==true);self.root:SetAttribute("MarkTextSize",chosen)
 self.root.Visible=width>0 and height>0 and self.width<=width+.01 and self.height<=height+.01
 return self.width,self.height
end
return Wordmark
