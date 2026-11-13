-- Deck glass tokens and components (UI-SPEC-2026-11-12 sections 2 and 3).
-- Every constructor returns plain Roblox instances; colours that lean with the
-- equipped faceplate are registered with DeckArt.bind so a theme change repaints
-- them once. Text is always neutral; the accent marks selection, the primary
-- action, progress and checks only.
local GuiService=game:GetService("GuiService")
local TweenService=game:GetService("TweenService")
local Art=require(script.Parent.DeckArt)
local Assets=require(script.Parent.DeckAssets)
local Kit={}

-- 2.1 Colour. `dim` is #959BA5 rather than the spec's #8A909A so 13 px labels keep
-- 4.5:1 on every plate's `raised` card (#8A909A measures 4.1:1 on Scout).
Kit.Color={text=Color3.fromHex("#F3F4F6"),soft=Color3.fromHex("#C3C8D0"),dim=Color3.fromHex("#959BA5"),
 ink=Color3.fromHex("#0E0F12"),stars=Color3.fromHex("#FFC14D"),danger=Color3.fromHex("#FF5A6E"),dangerText=Color3.fromHex("#FF8090"),
 good=Color3.fromHex("#7BE495"),focus=Color3.fromHex("#FFFFFF"),white=Color3.new(1,1,1),black=Color3.new(0,0,0)}
local fallback={panel=Color3.fromHex("#152525"),raised=Color3.fromHex("#213335"),well=Color3.fromHex("#0D1818"),
 selected=Color3.fromHex("#2D4E46"),line=Color3.fromHex("#8DBEAC"),accent=Color3.fromHex("#76F6B0"),ink=Color3.fromHex("#0E0F12")}
-- Plate-leaning glass layers and the accent come from the confirmed theme.
function Kit.color(role)
 local theme=Art.getTheme();local ui=theme and theme.ui
 if ui then
  local value=if role=="well"then ui.inset else ui[role]
  if value then return value end
 end
 return fallback[role]or Kit.Color[role]or Kit.Color.text
end
local function paint(object,property,role)
 if type(role)=="string"and(fallback[role]~=nil)then
  object[property]=Kit.color(role);Art.bind(object,{[property]=function()return Kit.color(role)end})
 elseif type(role)=="function"then object[property]=role();Art.bind(object,{[property]=role})
 elseif type(role)=="string"then object[property]=Kit.Color[role]
 else object[property]=role end
end
Kit.paint=paint
function Kit.mix(color,toward,amount)return color:Lerp(toward,amount)end

-- 2.2 Type. {regular size, compact size, face}
local function face(family,weight)return Font.new("rbxasset://fonts/families/"..family..".json",weight)end
local sans,mono=function(w)return face("BuilderSans",w)end,function(w)return face("RobotoMono",w)end
Kit.Type={
 Display={40,30,sans(Enum.FontWeight.ExtraBold)},Title={26,20,sans(Enum.FontWeight.Bold)},
 Heading={20,16,sans(Enum.FontWeight.Bold)},Body={16,14,sans(Enum.FontWeight.Regular)},
 BodyMedium={16,14,sans(Enum.FontWeight.Medium)},Small={14,12,sans(Enum.FontWeight.Regular)},
 Label={13,12,sans(Enum.FontWeight.Bold)},Counter={18,15,mono(Enum.FontWeight.Bold)},
 CounterL={34,22,mono(Enum.FontWeight.Bold)},Strong={16,14,sans(Enum.FontWeight.Bold)},
}
Kit.LineHeight=1.25
-- 2.3 Spacing, radius, border.
Kit.Space={4,8,12,16,24,32}
Kit.Radius={button=12,card=14,row=10,tile=12,well=14,chip=999}
Kit.Stroke={color=Color3.new(1,1,1),transparency=.86,thickness=1}
-- 2.4 Motion (seconds).
Kit.Motion={screen=.16,focus=.09,pressDown=.06,pressUp=.10,hover=.08,tab=.14,toggle=.11,progress=.45,toastIn=.24,toastHold=2.4,toastOut=.16}

function Kit.reduced()return GuiService.ReducedMotionEnabled end
local UserInputService=game:GetService("UserInputService")
function Kit.lastInputTouch()return UserInputService:GetLastInputType()==Enum.UserInputType.Touch end
-- Compact screens hide the focus ring and glyph chips after touch input (UI-SPEC-COMPACT 2.5).
Kit.touchHidesFocus=false
function Kit.tween(object,time,goal,style)
 if Kit.reduced()then for key,value in pairs(goal)do object[key]=value end;return end
 TweenService:Create(object,TweenInfo.new(time,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal):Play()
end

local function node(class,parent,props)
 local object=Instance.new(class)
 for key,value in pairs(props)do object[key]=value end
 object.Parent=parent;return object
end
Kit.node=node
function Kit.corner(parent,radius)
 local c=parent:FindFirstChildOfClass("UICorner")or node("UICorner",parent,{})
 c.CornerRadius=if radius>=999 then UDim.new(.5,0)else UDim.new(0,radius);return c
end
-- One 1 px white 14% border on every card, row, track and pill.
function Kit.stroke(parent,color,thickness,transparency)
 local s=parent:FindFirstChild("KitStroke")or node("UIStroke",parent,{Name="KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 s.Thickness=thickness or Kit.Stroke.thickness;s.Transparency=transparency or(if color then 0 else Kit.Stroke.transparency)
 if color then paint(s,"Color",color)else s.Color=Kit.Stroke.color end
 return s
end

-- Text in one of the 2.2 roles. `compact` picks the second size (never below 12).
function Kit.text(parent,role,content,color,props)
 local spec=Kit.Type[role]or Kit.Type.Body
 local label=node("TextLabel",parent,{Name=props and props.Name or role,BackgroundTransparency=1,
  Text=if role=="Label"then string.upper(content or "")else content or "",FontFace=spec[3],TextSize=spec[1],
  TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
  LineHeight=Kit.LineHeight,TextWrapped=false,ZIndex=parent.ZIndex+1,Active=false,Size=UDim2.fromOffset(10,spec[1]+4)})
 label:SetAttribute("KitRole",role)
 paint(label,"TextColor3",color or(if role=="Label"then "dim"else "text"))
 if props then for key,value in pairs(props)do if key~="Name"then label[key]=value end end end
 return label
end
function Kit.setFontRole(label,role)
 local spec=Kit.Type[role];if not spec then return end
 label.FontFace=spec[3];label:SetAttribute("KitRole",role)
end
function Kit.setCompact(label,compact)
 local spec=Kit.Type[label:GetAttribute("KitRole")or "Body"]
 if spec then label.TextSize=if compact then math.max(12,spec[2])else spec[1]end
end

function Kit.frame(parent,name,role,position,size,radius)
 local f=node("Frame",parent,{Name=name,BorderSizePixel=0,Position=position or UDim2.new(),Size=size or UDim2.fromScale(1,1),ZIndex=parent.ZIndex+1,Active=false})
 if role then paint(f,"BackgroundColor3",role)else f.BackgroundTransparency=1 end
 if radius then Kit.corner(f,radius)end
 return f
end

-- Icons: white art in 64 px cells, tinted with ImageColor3. The star is always gold.
function Kit.icon(parent,name,size,color)
 local image=node("ImageLabel",parent,{Name="Icon_"..name,BackgroundTransparency=1,Image=Assets.Image.icons,
  ImageRectOffset=Assets.Icon[name]or Vector2.zero,ImageRectSize=Vector2.new(64,64),Size=UDim2.fromOffset(size,size),ZIndex=parent.ZIndex+1})
 paint(image,"ImageColor3",if name=="star"then "stars"else color or "text")
 return image
end

-- Check circle (22): done = accent disc with an ink check; open = 2 px dim ring.
function Kit.check(parent,size)
 size=size or 22
 local disc=Kit.frame(parent,"Check",nil,UDim2.new(),UDim2.fromOffset(size,size),999)
 local ring=node("UIStroke",disc,{Name="Ring",Thickness=2,Color=Kit.Color.dim})
 local mark=Kit.icon(disc,"check",math.floor(size*.82),"ink")
 mark.AnchorPoint,mark.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 local api={root=disc}
 function api.set(done)
  disc.BackgroundTransparency=if done then 0 else 1
  if done then paint(disc,"BackgroundColor3","accent")end
  ring.Enabled=not done;mark.Visible=done
 end
 api.set(false);return api
end

-- Chip: height 26 (22 on the board), full radius, padding 10. Kinds: plain, gold, danger, accent.
function Kit.chip(parent,content,kind,height)
 height=height or 26
 local role=if height<=22 then "Label"else "Label"
 local chip=Kit.frame(parent,"Chip",nil,UDim2.new(),UDim2.fromOffset(40,height),999)
 chip.BackgroundTransparency=0
 local label=Kit.text(chip,role,content,"soft",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
 if height<=22 then label.TextSize=11 end
 local api={root=chip,label=label}
 function api.set(text,newKind)
  label.Text=string.upper(text);kind=newKind or kind
  if kind=="gold"then paint(chip,"BackgroundColor3",function()return Kit.color("well"):Lerp(Kit.Color.stars,.14)end);paint(label,"TextColor3","stars")
  elseif kind=="danger"then paint(chip,"BackgroundColor3",function()return Kit.color("well"):Lerp(Kit.Color.danger,.18)end);paint(label,"TextColor3","danger")
  else paint(chip,"BackgroundColor3","well");paint(label,"TextColor3","soft")end
  local width=game:GetService("TextService"):GetTextSize(label.Text,label.TextSize,Enum.Font.BuilderSansBold,Vector2.new(1000,100)).X+20
  chip.Size=UDim2.fromOffset(math.ceil(width),height)
 end
 Kit.stroke(chip);api.set(content,kind);return api
end

-- Glyph chip: 26 px circle (pill for words) inside buttons and hint bars.
function Kit.glyph(parent,letter,onAccent,size)
 size=size or 26
 local wide=#letter>1
 local width=if wide then game:GetService("TextService"):GetTextSize(letter,math.floor(size*.5),Enum.Font.BuilderSansBold,Vector2.new(500,100)).X+16 else size
 local chip=Kit.frame(parent,"Glyph",nil,UDim2.new(),UDim2.fromOffset(width,size),999)
 chip.BackgroundTransparency=0
 local stroke=node("UIStroke",chip,{Name="KitStroke",Thickness=1})
 local text=Kit.text(chip,"Strong",letter,nil,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=math.floor(size*.54)})
 local function repaint(accent)
  if accent then chip.BackgroundColor3,chip.BackgroundTransparency=Kit.Color.ink,.82;stroke.Color,stroke.Transparency=Kit.Color.ink,.65;text.TextColor3=Kit.Color.ink
  else chip.BackgroundColor3,chip.BackgroundTransparency=Kit.Color.white,.88;stroke.Color,stroke.Transparency=Kit.Color.white,.73;text.TextColor3=Kit.Color.text end
 end
 repaint(onAccent);return chip,repaint
end

-- Button. variants: secondary (default), primary, reward, ghost, destructive.
-- The TextButton is the hit rect; Edge + Fill + Content draw it. Content settles
-- 2 px on press while the hit rect stays put.
local buttons=setmetatable({},{__mode="k"})
local function baseFill(state)
 local v=state.variant
 if not state.enabled then return Kit.color("raised"),.4 end
 local color=if v=="primary"then Kit.color("accent")elseif v=="reward"then Kit.Color.stars
  elseif v=="destructive"then Kit.color("raised"):Lerp(Kit.Color.danger,.10)
  elseif state.selected then Kit.color("selected")else Kit.color("raised")
 local transparency=if v=="ghost"and not state.hover then 1 else 0
 if v=="ghost"and state.hover then return Kit.Color.white,.94 end
 if state.hover then color=color:Lerp(Kit.Color.white,.06)end
 if state.pressed then color=color:Lerp(Kit.Color.black,.08)end
 return color,transparency
end
function Kit.paintButton(button)
 local s=buttons[button];if not s then return end
 local color,transparency=baseFill(s)
 s.fill.BackgroundColor3,s.fill.BackgroundTransparency=color,transparency
 local accent=s.enabled and(s.variant=="primary"or s.variant=="reward")
 local edge=accent and not s.pressed
 s.edge.Visible=edge;s.edge.BackgroundColor3=color:Lerp(Kit.Color.black,.38)
 s.sheen.Visible=accent
 s.stroke.Enabled=s.enabled and s.variant~="ghost"and s.variant~="primary"and s.variant~="reward"or s.selected
 if s.selected then s.stroke.Color,s.stroke.Thickness,s.stroke.Transparency=Kit.color("accent"),2,0
 elseif s.variant=="destructive"then s.stroke.Color,s.stroke.Thickness,s.stroke.Transparency=Kit.Color.danger,1.5,0
 else s.stroke.Color,s.stroke.Thickness,s.stroke.Transparency=Kit.Color.white,1,.86 end
 local ink=if accent then Kit.Color.ink elseif s.variant=="destructive"then Kit.Color.danger elseif s.enabled then Kit.Color.text else Kit.Color.dim
 s.label.TextColor3=ink;s.label.TextTransparency=if s.enabled then 0 else .4
 if s.repaintGlyph then s.repaintGlyph(accent)end
 if s.glyph then s.glyph.Visible=s.showGlyph==true end
 s.content.Position=UDim2.fromOffset(0,if s.pressed then 2 else 0)
end
function Kit.button(parent,name,options)
 options=options or {}
 local variant=options.variant or "secondary"
 local radius=options.radius or Kit.Radius.button
 local size=options.size or(if variant=="primary"then Vector2.new(200,56)elseif variant=="reward"then Vector2.new(120,38)else Vector2.new(180,48))
 local button=node("TextButton",parent,{Name=name,Text="",AutoButtonColor=false,BackgroundTransparency=1,
  Size=UDim2.fromOffset(size.X,size.Y),ZIndex=parent.ZIndex+1,Selectable=options.selectable~=false})
 button:SetAttribute("AccessibleLabel",options.text)
 local edge=Kit.frame(button,"Edge",nil,UDim2.fromOffset(0,3),UDim2.fromScale(1,1),radius);edge.BackgroundTransparency=0
 local fill=Kit.frame(button,"Fill",nil,UDim2.new(),UDim2.new(1,0,1,0),radius);fill.BackgroundTransparency=0;fill.ZIndex=edge.ZIndex+1
 local sheen=Kit.frame(fill,"Sheen",nil,UDim2.new(),UDim2.fromScale(1,.5),radius)
 sheen.BackgroundColor3,sheen.BackgroundTransparency=Kit.Color.white,0
 node("UIGradient",sheen,{Rotation=90,Transparency=NumberSequence.new(.82,1)})
 local stroke=node("UIStroke",fill,{Name="KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1})
 local content=Kit.frame(button,"Content",nil,UDim2.new(),UDim2.fromScale(1,1));content.ZIndex=fill.ZIndex+2
 local list=node("UIListLayout",content,{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,
  VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
 local glyph,repaintGlyph
 if options.glyph then glyph,repaintGlyph=Kit.glyph(content,options.glyph,false,if variant=="reward"then 22 else 26);glyph.LayoutOrder=1 end
 local role=if variant=="reward"then "Strong"else "Heading"
 local label=Kit.text(content,role,options.text or name,nil,{Name="Label",AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,size.Y),LayoutOrder=2,TextXAlignment=Enum.TextXAlignment.Center})
 if options.textSize then label.TextSize=options.textSize end
 local state={variant=variant,enabled=true,hover=false,pressed=false,selected=false,showGlyph=options.showGlyph~=false,
  fill=fill,edge=edge,sheen=sheen,stroke=stroke,content=content,label=label,glyph=glyph,repaintGlyph=repaintGlyph,list=list}
 buttons[button]=state
 Art.bind(fill,{BackgroundColor3=function()Kit.paintButton(button);return fill.BackgroundColor3 end})
 button.MouseEnter:Connect(function()state.hover=true;Kit.paintButton(button)end)
 button.MouseLeave:Connect(function()state.hover=false;state.pressed=false;Kit.paintButton(button)end)
 button.MouseButton1Down:Connect(function()if state.enabled then state.pressed=true;Kit.paintButton(button)end end)
 button.MouseButton1Up:Connect(function()if state.pressed then task.delay(Kit.Motion.pressUp,function()state.pressed=false;Kit.paintButton(button)end)end end)
 Kit.paintButton(button)
 return button,state
end
function Kit.buttonState(button)return buttons[button]end
function Kit.setEnabled(button,enabled)
 local s=buttons[button];if not s then return end
 s.enabled=enabled~=false;button.Active=s.enabled;button.Interactable=s.enabled
 if not s.enabled then s.pressed=false end;Kit.paintButton(button)
end
function Kit.setSelected(button,selected)local s=buttons[button];if s then s.selected=selected==true;Kit.paintButton(button)end end
function Kit.setText(button,text)local s=buttons[button];if s then s.label.Text=text;button:SetAttribute("AccessibleLabel",text)end end
function Kit.setGlyphVisible(button,visible)local s=buttons[button];if s then s.showGlyph=visible;Kit.paintButton(button)end end
-- Hardware or keyboard press: a short settle with no pointer involved.
function Kit.pulse(button)
 local s=buttons[button];if not s or not s.enabled then return end
 s.pressed=true;Kit.paintButton(button)
 task.delay(Kit.Motion.pressDown+Kit.Motion.pressUp,function()s.pressed=false;Kit.paintButton(button)end)
end

-- Card: radius 14, raised, 1 px stroke; label row first.
function Kit.card(parent,name,label,options)
 options=options or {}
 local card=Kit.frame(parent,name,options.role or "raised",UDim2.new(),UDim2.fromOffset(100,100),options.radius or Kit.Radius.card)
 Kit.stroke(card)
 local pad=options.pad or 20
 local eyebrow
 if label then eyebrow=Kit.text(card,"Label",label,"dim",{Name="Eyebrow",Position=UDim2.fromOffset(pad,options.labelY or 12),Size=UDim2.new(1,-pad*2,0,16)})end
 return card,eyebrow
end

-- Progress bar: track well + stroke, accent fill never shorter than its height.
function Kit.progress(parent,height,segments)
 local track=Kit.frame(parent,"Progress",nil,UDim2.new(),UDim2.fromOffset(100,height),if segments then nil else 999)
 local api={root=track,height=height}
 if segments then
  api.cells={}
  for index=1,segments do
   local cell=Kit.frame(track,"Segment"..index,"well",UDim2.new(),UDim2.fromOffset(20,height),3)
   Kit.stroke(cell);api.cells[index]=cell
  end
  function api.layout(width,gap)
   gap=gap or 4;local w=(width-gap*(segments-1))/segments
   track.Size=UDim2.fromOffset(width,height)
   for index,cell in ipairs(api.cells)do cell.Position=UDim2.fromOffset((index-1)*(w+gap),0);cell.Size=UDim2.fromOffset(w,height)end
  end
  function api.set(value)
   for index,cell in ipairs(api.cells)do
    local on=index<=value
    paint(cell,"BackgroundColor3",if on then "accent"else "well");cell.KitStroke.Enabled=not on
   end
  end
  api.layout(segments*24,4)
 else
  paint(track,"BackgroundColor3","well");Kit.stroke(track)
  local fill=Kit.frame(track,"Fill","accent",UDim2.new(),UDim2.new(0,height,1,0),999);api.fill=fill
  api.value=0
  function api.set(value,maximum,claimable,animate)
   local ratio=if(maximum or 0)>0 then math.clamp(value/maximum,0,1)else 0
   paint(fill,"BackgroundColor3",if claimable and ratio>=1 then "stars"else "accent")
   fill.Visible=ratio>0
   local goal=UDim2.new(ratio,0,1,0)
   if animate and ratio~=api.value then Kit.tween(fill,Kit.Motion.progress,{Size=goal})else fill.Size=goal end
   api.value=ratio
  end
  local minimum=node("UISizeConstraint",fill,{MinSize=Vector2.new(height,0)})
  api.minimum=minimum
 end
 return api
end

-- Toggle 52x30. Knob travel 110 ms.
function Kit.toggle(parent,name)
 local button=node("TextButton",parent,{Name=name or "Toggle",Text="",AutoButtonColor=false,Size=UDim2.fromOffset(52,30),ZIndex=parent.ZIndex+1,BackgroundTransparency=0})
 Kit.corner(button,999);local stroke=Kit.stroke(button)
 local knob=Kit.frame(button,"Knob",nil,UDim2.fromOffset(4,4),UDim2.fromOffset(22,22),999);knob.BackgroundTransparency=0
 local api={root=button,on=false}
 function api.set(on,enabled)
  api.on=on==true
  paint(button,"BackgroundColor3",if api.on then "accent"else "well");stroke.Enabled=not api.on
  knob.BackgroundColor3=if api.on then Kit.Color.ink else Kit.Color.soft
  Kit.tween(knob,Kit.Motion.toggle,{Position=UDim2.fromOffset(if api.on then 26 else 4,4)})
  button.BackgroundTransparency=if enabled==false then .53 else 0;button.Active=enabled~=false
 end
 api.set(false);return api
end

-- Tabs: 520x44 track, accent pill inset 4 under the selected label.
-- Compact: `height` 36 with 14 px labels; every segment keeps a 44-high hit frame.
function Kit.tabs(parent,labels,width,height,textSize)
 width=width or 520;height=height or 44;textSize=textSize or 17
 local track=Kit.frame(parent,"Tabs","well",UDim2.new(),UDim2.fromOffset(width,height),999);Kit.stroke(track)
 local segment=(width-8)/#labels
 local pill=Kit.frame(track,"Pill","accent",UDim2.fromOffset(4,4),UDim2.fromOffset(segment,height-8),999)
 local api={root=track,buttons={},selected=1,labels={}}
 for index,text in ipairs(labels)do
  local hitH=math.max(44,height-8)
  local b=node("TextButton",track,{Name="Tab"..index,Text="",AutoButtonColor=false,BackgroundTransparency=1,Position=UDim2.fromOffset(4+(index-1)*segment,(height-hitH)/2),Size=UDim2.fromOffset(segment,hitH),ZIndex=pill.ZIndex+1})
  local label=Kit.text(b,"Strong",text,"soft",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=textSize})
  local dot=Kit.frame(b,"ClaimDot","stars",UDim2.new(.5,0,.5,-11),UDim2.fromOffset(8,8),999);dot.Visible=false
  api.buttons[index],api.labels[index]=b,label;b:SetAttribute("ClaimDot",false)
  b.Activated:Connect(function()api.select(index)if api.changed then api.changed(index)end end)
 end
 function api.select(index)
  api.selected=index
  Kit.tween(pill,Kit.Motion.tab,{Position=UDim2.fromOffset(4+(index-1)*segment,4)})
  for i,label in ipairs(api.labels)do paint(label,"TextColor3",if i==index then "ink"else "soft")end
 end
 function api.setDot(index,on)
  local label,dot=api.labels[index],api.buttons[index].ClaimDot
  dot.Visible=on==true
  local w=game:GetService("TextService"):GetTextSize(label.Text,textSize,Enum.Font.BuilderSansBold,Vector2.new(500,50)).X
  dot.Position=UDim2.new(.5,w/2+(if textSize<17 then 4 else 9),.5,if textSize<17 then -9 else -11)
 end
 api.select(1);return api
end

-- Wallet pill: height 40, well + stroke, star 22, Counter 18.
function Kit.wallet(parent,height)
 height=height or 40
 local pill=Kit.frame(parent,"Wallet","well",UDim2.new(),UDim2.fromOffset(110,height),999);Kit.stroke(pill)
 local star=Kit.icon(pill,"star",math.floor(height*.55));star.AnchorPoint=Vector2.new(0,.5);star.Position=UDim2.new(0,math.floor(height*.45),.5,0)
 local amount=Kit.text(pill,"Counter","0","text",{Name="Amount",AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-18,.5,0),Size=UDim2.fromOffset(60,height),TextXAlignment=Enum.TextXAlignment.Right})
 if height<40 then amount.TextSize=15 end
 local api={root=pill,amount=amount}
 function api.set(value)
  amount.Text=tostring(value)
  local w=game:GetService("TextService"):GetTextSize(amount.Text,amount.TextSize,Enum.Font.RobotoMono,Vector2.new(500,50)).X
  pill.Size=UDim2.fromOffset(math.ceil(w+height*.45+height*.55+12+18),height)
  pill:SetAttribute("AccessibleLabel",value.." Stars")
 end
 api.set(0);return api
end

-- List row 784x42 (history, settings).
function Kit.listRow(parent,time,title,reward)
 local row=node("TextButton",parent,{Name="ListRow",Text="",AutoButtonColor=false,BackgroundTransparency=1,Size=UDim2.fromOffset(784,42),ZIndex=parent.ZIndex+1})
 Kit.corner(row,10)
 local hair=Kit.frame(row,"Hairline",nil,UDim2.new(0,0,1,1),UDim2.new(1,0,0,1));hair.BackgroundColor3,hair.BackgroundTransparency=Kit.Color.white,.95
 Kit.text(row,"Counter",time,"dim",{Name="Time",TextSize=13,Position=UDim2.fromOffset(14,0),Size=UDim2.fromOffset(76,42)})
 Kit.text(row,"Body",title,"text",{Name="Title",Position=UDim2.fromOffset(96,0),Size=UDim2.fromOffset(560,42)})
 if reward then Kit.text(row,"Counter","★ +"..reward,"stars",{Name="Reward",TextSize=15,AnchorPoint=Vector2.new(1,0),Position=UDim2.fromOffset(738,0),Size=UDim2.fromOffset(80,42),TextXAlignment=Enum.TextXAlignment.Right})end
 local mark=Kit.icon(row,"check",18,"accent");mark.Position=UDim2.fromOffset(756,12)
 row.MouseEnter:Connect(function()row.BackgroundTransparency=0;row.BackgroundColor3=Kit.color("raised"):Lerp(Kit.Color.white,.06)end)
 row.MouseLeave:Connect(function()row.BackgroundTransparency=1 end)
 return row
end

-- Shared focus ring: 2.5 px white, 4 px outside, radius + 4, soft glow behind.
-- One instance per host; it slides to its next target in 90 ms.
function Kit.focusRing(host)
 local ring=node("Frame",host,{Name="FocusRing",BackgroundTransparency=1,Visible=false,ZIndex=200,Active=false,Selectable=false})
 local corner=Kit.corner(ring,16)
 node("UIStroke",ring,{Name="Ring",Thickness=2.5,Color=Kit.Color.focus,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 local glow=node("ImageLabel",ring,{Name="Glow",BackgroundTransparency=1,Image=Assets.Image.focusGlow,ImageTransparency=.35,
  ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(40,40,56,56),Position=UDim2.fromOffset(-20,-20),Size=UDim2.new(1,40,1,40),ZIndex=199})
 local api={root=ring,target=nil}
 local connection
 local function place(instant)
  local t=api.target;if not t or not t.Parent or not t.Visible then ring.Visible=false;return end
  if Kit.touchHidesFocus and Kit.lastInputTouch()then ring.Visible=false;return end
  local origin=host.AbsolutePosition
  local scale=1
  local ancestor=host:FindFirstAncestorWhichIsA("GuiObject")
  local uiScale=host:FindFirstChildOfClass("UIScale");if uiScale then scale=uiScale.Scale end
  local goal={Position=UDim2.fromOffset((t.AbsolutePosition.X-origin.X)/scale-4,(t.AbsolutePosition.Y-origin.Y)/scale-4),
   Size=UDim2.fromOffset(t.AbsoluteSize.X/scale+8,t.AbsoluteSize.Y/scale+8)}
  local _=ancestor
  if instant or not ring.Visible then ring.Position,ring.Size=goal.Position,goal.Size else Kit.tween(ring,Kit.Motion.focus,goal)end
  ring.Visible=true
 end
 function api.attach(target,radius)
  if connection then connection:Disconnect();connection=nil end
  local moved=target~=api.target;api.target=target
  corner.CornerRadius=if(radius or 12)>=999 then UDim.new(.5,0)else UDim.new(0,(radius or 12)+4)
  glow.Visible=not Kit.reduced()
  if target then connection=target:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()place(true)end)end
  place(not moved)
 end
 function api.hide()if connection then connection:Disconnect();connection=nil end;api.target=nil;ring.Visible=false end
 return api
end

-- Toast: top centre of the view, y 30, 48 high, gold stroke, 2.4 s, queued.
function Kit.toaster(host)
 local queue,busy={},false
 local toast=Kit.frame(host,"Toast","well",UDim2.new(.5,0,0,30),UDim2.fromOffset(300,48),999)
 toast.AnchorPoint=Vector2.new(.5,0);toast.Visible=false;toast.ZIndex=300
 Kit.stroke(toast,"stars",1.5)
 local check=Kit.icon(toast,"check",22,"stars");check.Position=UDim2.fromOffset(28,13)
 local text=Kit.text(toast,"Strong","","text",{Name="Message",TextSize=17,Position=UDim2.fromOffset(60,0),Size=UDim2.new(1,-150,1,0)})
 local amount=Kit.text(toast,"Counter","","stars",{Name="Amount",TextSize=17,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-20,0,0),Size=UDim2.fromOffset(80,48),TextXAlignment=Enum.TextXAlignment.Right})
 local api={root=toast}
 local function nextToast()
  if busy then return end
  local item=table.remove(queue,1);if not item then return end
  busy=true;text.Text=item.text;amount.Text=if item.amount then "★ +"..item.amount else ""
  -- Compact (UI-SPEC-COMPACT 3): 40 high, Strong 14, centred where `api.placement` says.
  local x,y,compact=nil,30,false
  if api.placement then x,y,compact=api.placement()end
  local size=if compact then 14 else 17
  text.TextSize=size;amount.TextSize=size
  local w=game:GetService("TextService"):GetTextSize(item.text,size,Enum.Font.BuilderSansBold,Vector2.new(2000,50)).X
  local h=if compact then 40 else 48
  toast.Size=UDim2.fromOffset(math.ceil(w)+(if compact then 96 else 124)+(if item.amount then 40 else 0),h)
  check.Position=UDim2.fromOffset(if compact then 16 else 28,(h-22)/2);text.Position=UDim2.fromOffset(if compact then 46 else 60,0)
  amount.Size=UDim2.fromOffset(80,h)
  local function at(dy)return if x then UDim2.new(0,x,0,y+dy)else UDim2.new(.5,0,0,y+dy)end
  toast.Position=at(if Kit.reduced()then 0 else -16);toast.Visible=true
  Kit.tween(toast,Kit.Motion.toastIn,{Position=at(0)})
  task.delay(Kit.Motion.toastIn+Kit.Motion.toastHold,function()
   toast.Visible=false;busy=false;nextToast()
  end)
 end
 function api.show(message,stars)table.insert(queue,{text=message,amount=stars});nextToast()end
 return api
end

-- Back arrow: 56 px circle (44 compact) at the top right of the view.
function Kit.backArrow(parent,compact)
 local size=if compact then 44 else 56
 local button=node("TextButton",parent,{Name="BackArrow",Text="",AutoButtonColor=false,AnchorPoint=Vector2.new(1,0),
  Size=UDim2.fromOffset(size,size),BackgroundColor3=Color3.fromHex("#15171B"),BackgroundTransparency=.28,ZIndex=60,Selectable=false})
 button:SetAttribute("AccessibleLabel","Back")
 Kit.corner(button,999)
 local stroke=node("UIStroke",button,{Name="KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1.5,Color=Kit.Color.white,Transparency=.76})
 local shadow=node("ImageLabel",button,{Name="Shadow",BackgroundTransparency=1,Image=Assets.Image.focusGlow,ImageColor3=Kit.Color.black,ImageTransparency=.55,
  ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(40,40,56,56),Position=UDim2.fromOffset(-14,-9),Size=UDim2.new(1,28,1,28),ZIndex=59})
 local icon=Kit.icon(button,"back",26,"text");icon.AnchorPoint,icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 local api={root=button,enabled=true,size=size}
 local hover,pressed=false,false
 local function repaint()
  button.BackgroundColor3=if hover and api.enabled then Color3.fromHex("#282B32")else Color3.fromHex("#15171B")
  button.BackgroundTransparency=if not api.enabled then .65 elseif hover then .22 else .28
  if pressed then button.BackgroundColor3=button.BackgroundColor3:Lerp(Kit.Color.black,.08)end
  icon.Position=UDim2.new(.5,0,.5,if pressed then 2 else 0)
  icon.ImageTransparency=if api.enabled then 0 else .65;stroke.Transparency=if api.enabled then .76 else .9
  shadow.Visible=not Kit.reduced()
 end
 button.MouseEnter:Connect(function()hover=true;repaint()end)
 button.MouseLeave:Connect(function()hover=false;pressed=false;repaint()end)
 button.MouseButton1Down:Connect(function()pressed=api.enabled;repaint()end)
 button.MouseButton1Up:Connect(function()pressed=false;repaint()end)
 function api.setEnabled(enabled)api.enabled=enabled~=false;button.Active=api.enabled;button.Interactable=api.enabled;repaint()end
 function api.setCompact(isCompact)
  api.size=if isCompact then 44 else 56;button.Size=UDim2.fromOffset(api.size,api.size)
  icon.Size=UDim2.fromOffset(if isCompact then 22 else 26,if isCompact then 22 else 26)
 end
 repaint();return api
end

-- ── Compact (UI-SPEC-COMPACT-2026-11-12) ────────────────────────────────────
-- Glass island (section 3): the content rect in `panel` (or `well`) with the
-- 1 px white 14% stroke, set in a bezel grown by `bezel` px (#090A0C, radius +
-- bezel, 1 px white 18%). Returns the inner frame and the bezel frame.
function Kit.island(parent,name,r,radius,role,bezel)
 bezel=bezel or 3;radius=radius or 12
 local outer=Kit.frame(parent,name,nil,UDim2.fromOffset(r.x-bezel,r.y-bezel),UDim2.fromOffset(r.w+bezel*2,r.h+bezel*2),radius+bezel)
 outer.BackgroundTransparency=0;outer.BackgroundColor3=Color3.fromHex("#090A0C")
 Kit.stroke(outer,nil,1,.82).Color=Color3.new(1,1,1)
 local inner=Kit.frame(outer,"Glass",role or "panel",UDim2.fromOffset(bezel,bezel),UDim2.fromOffset(r.w,r.h),radius)
 Kit.stroke(inner)
 return inner,outer
end
-- Chevron from two short bars; direction "up" or "down".
function Kit.chevron(parent,size,direction,color)
 local holder=Kit.frame(parent,"Chevron",nil,UDim2.new(),UDim2.fromOffset(size,size))
 local arm=math.max(6,math.floor(size*.6));local sign=if direction=="up"then -1 else 1
 for side=-1,1,2 do
  local bar=Kit.frame(holder,"Arm",nil,UDim2.new(.5,side*arm*.36,.5,0),UDim2.fromOffset(arm,2),999)
  bar.AnchorPoint=Vector2.new(.5,.5);bar.BackgroundTransparency=0
  paint(bar,"BackgroundColor3",color or "text")
  bar.Rotation=side*sign*-40
 end
 return holder
end
-- Menu sheet (section 5) in a root of W x H: rim 0..6 (whatever is behind),
-- bezel at 6, the panel sheet at 8 with its gradient and stroke, header hairline at y 60.
function Kit.sheet(parent,W,H)
 local bezel=Kit.frame(parent,"SheetBezel",nil,UDim2.fromOffset(6,6),UDim2.fromOffset(W-12,H-12),18)
 bezel.BackgroundTransparency=0;bezel.BackgroundColor3=Color3.fromHex("#090A0C")
 local sheet=Kit.frame(parent,"Sheet","panel",UDim2.fromOffset(8,8),UDim2.fromOffset(W-16,H-16),16);Kit.stroke(sheet)
 local tint=Kit.frame(sheet,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1),16);tint.BackgroundTransparency=0;tint.BackgroundColor3=Color3.new(1,1,1)
 node("UIGradient",tint,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 local hair=Kit.frame(parent,"HeaderHairline",nil,UDim2.fromOffset(20,60),UDim2.fromOffset(W-40,1))
 hair.BackgroundTransparency=.93;hair.BackgroundColor3=Color3.new(1,1,1);hair.ZIndex=sheet.ZIndex+3
 return sheet,bezel
end
-- Keep-out for the Roblox controls (section 1.1): kx = TopbarInset.Min.X,
-- kh = TopbarInset.Height; 116 x 58 when the API returns an empty rect.
function Kit.keepOut()
 -- Studio fixtures can pin the phone keep-out (PlayerGui attribute FixtureKeepOut, a Vector2).
 local player=game:GetService("Players").LocalPlayer
 local fixture=player and player:FindFirstChild("PlayerGui")and player.PlayerGui:GetAttribute("FixtureKeepOut")
 if typeof(fixture)=="Vector2"then return math.floor(fixture.X),math.floor(fixture.Y)end
 local inset=GuiService.TopbarInset
 local kx,kh=inset.Min.X,inset.Height
 if kx<=0 or kh<=0 then kx,kh=116,58 end
 return math.floor(kx),math.floor(kh)
end
-- Section 1: compact = landscape and (H < 500 or W < 1000).
function Kit.compactRule(W,H)
 return W>=H*1.2 and(H<500 or W<1000)
end
return Kit
