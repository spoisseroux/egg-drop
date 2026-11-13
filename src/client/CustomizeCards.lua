-- Customize card grid (UI-SPEC-REDESIGN-MENUS-2026-11-12 sections 2.2 and 2.3).
-- The Wardrobe card look for the Customize tabs: swatch at the left, name, one
-- status line (WEARING in accent caps, else soft), the `selected` fill and a 2 px
-- accent stroke on the focused card. `dress` restyles an existing TextButton in
-- place (panels keep their own buttons, names and Activated handlers).
local Kit=require(script.Parent.DeckKit)
local Cards={}

-- Pure: card rectangles for n cards in `cols` columns, 3 px in from the scroll edges
-- (the focused outline was clipped otherwise). Returns rects and the used height.
function Cards.rects(n,width,cols,cardH,gap,y0)
 cols=math.max(1,cols or 2);gap=gap or 12;y0=y0 or 3
 local cw=math.floor((width-6-(cols-1)*gap)/cols)
 local rects={}
 for i=1,n do
  local c,r=(i-1)%cols,math.floor((i-1)/cols)
  rects[i]={x=3+c*(cw+gap),y=y0+r*(cardH+gap),w=cw,h=cardH}
 end
 local h=if n>0 then math.ceil(n/cols)*(cardH+gap)-gap else 0
 return rects,h
end
-- Pure: focus movement on a cols-wide grid of `count` cards.
function Cards.step(index,dx,dy,count,cols)
 cols=math.max(1,cols or 2)
 if count<1 then return 1 end
 local col,row=(index-1)%cols,math.floor((index-1)/cols)
 local rows=math.ceil(count/cols)
 col=math.clamp(col+dx,0,cols-1);row=math.clamp(row+dy,0,rows-1)
 return math.clamp(row*cols+col+1,1,count)
end

local function colorOf(role)
 if role=="accent"or role=="selected"or role=="raised"or role=="well"or role=="panel"then return Kit.color(role)end
 return Kit.Color[role]or Kit.Color.text
end
Cards.colorOf=colorOf

function Cards.place(node,r)node.Position=UDim2.fromOffset(r.x,r.y);node.Size=UDim2.fromOffset(r.w,r.h)end

-- New card button (Kit look, not selectable: the screen owns focus).
function Cards.new(parent,name)
 local b=Kit.node("TextButton",parent,{Name=name,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
  Size=UDim2.fromOffset(200,96),ZIndex=parent.ZIndex+1})
 Kit.corner(b,12);Kit.stroke(b)
 return b
end

-- spec: {name, status, tone, swatch (Color3 or nil), icon (vector icon name or nil),
-- iconColor (Color3 or nil), focused, compact}
function Cards.dress(button,spec)
 button.Text="";button.AutoButtonColor=false;button.BackgroundTransparency=0
 for _,child in ipairs(button:GetChildren())do if child:IsA("UIGradient")then child.Enabled=false end end
 Kit.corner(button,12)
 local stroke=button:FindFirstChild("KitStroke")or button:FindFirstChildOfClass("UIStroke")or Kit.stroke(button)
 local parts=button:FindFirstChild("CardParts")
 if not parts then
  parts=Kit.frame(button,"CardParts",nil,UDim2.new(),UDim2.fromScale(1,1));parts.ZIndex=button.ZIndex+1
  local swatch=Kit.frame(parts,"Swatch","well",UDim2.new(),UDim2.fromOffset(40,40),10);Kit.stroke(swatch)
  Kit.text(parts,"Strong","","text",{Name="CardName",TextTruncate=Enum.TextTruncate.AtEnd})
  Kit.text(parts,"Small","","soft",{Name="CardStatus",TextTruncate=Enum.TextTruncate.AtEnd})
 end
 -- Every old child (Art labels, checks) hides under the card face.
 for _,child in ipairs(button:GetChildren())do
  if child:IsA("GuiObject")and child~=parts then child.Visible=false end
 end
 local h=button.Size.Y.Offset;local w=button.Size.X.Offset
 local side=math.max(28,h-20)
 local swatch=parts.Swatch
 swatch.Position=UDim2.fromOffset(10,(h-side)/2);swatch.Size=UDim2.fromOffset(side,side)
 if spec.swatch then swatch.BackgroundColor3=spec.swatch;swatch:SetAttribute("Painted",true)
 else Kit.paint(swatch,"BackgroundColor3","well")end
 local iconKey=tostring(spec.icon)..":"..side
 if swatch:GetAttribute("IconKey")~=iconKey then
  for _,child in ipairs(swatch:GetChildren())do if child.Name:match("^Icon_")then child:Destroy()end end
  if spec.icon then
   local icon=Kit.icon(swatch,spec.icon,math.floor(side*.55),"soft");icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5)
  end
  swatch:SetAttribute("IconKey",iconKey)
 end
 local icon=swatch:FindFirstChild("Icon_"..tostring(spec.icon))
 if icon and spec.iconColor then Kit.tintIcon(icon,function()return spec.iconColor end)end
 local tx=10+side+12
 local name,status=parts.CardName,parts.CardStatus
 name.Text=spec.name or "";status.Text=spec.status or ""
 name.TextSize=if spec.compact then 14 else 16;status.TextSize=if spec.compact then 12 else 14
 local wearing=spec.tone=="accent"
 status.FontFace=if wearing then Kit.Type.Label[3]else Kit.Type.Small[3]
 name.Position=UDim2.fromOffset(tx,h/2-20);name.Size=UDim2.fromOffset(math.max(1,w-tx-8),20)
 status.Position=UDim2.fromOffset(tx,h/2+2);status.Size=UDim2.fromOffset(math.max(1,w-tx-8),18)
 Kit.paint(status,"TextColor3",function()return colorOf(spec.tone or "soft")end)
 local focused=spec.focused==true
 Kit.paint(button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised")end)
 stroke.Thickness=if focused then 2 else 1;stroke.Transparency=if focused then 0 else .86
 Kit.paint(stroke,"Color",function()return if focused then Kit.color("accent")else Color3.new(1,1,1)end)
 button:SetAttribute("CardStatus",spec.status or "");button:SetAttribute("Focused",focused)
 button:SetAttribute("AccessibleLabel",(spec.name or "")..(if spec.status and spec.status~=""then " · "..spec.status else ""))
 return button
end
return Cards
