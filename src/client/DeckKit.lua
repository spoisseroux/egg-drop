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
-- Glass layers and the accent come from the house palette (the default plate):
-- the equipped faceplate tints only the deck and its background (batch 2026-11-13).
function Kit.color(role)
 local theme=Art.uiTheme();local ui=theme and theme.ui
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
-- UI personality T1: Fredoka One is the display face for screen titles, item and
-- pet names and button labels. Only at 15 px and up (smaller sizes fall back to
-- Builder Sans Bold), never sentences, never numbers. DeckArt keeps Builder Sans.
Kit.DisplayFace=Font.new("rbxasset://fonts/families/FredokaOne.json")
Kit.DisplayMin=15
Kit.Type={
 Display={40,30,sans(Enum.FontWeight.ExtraBold)},Title={26,20,Kit.DisplayFace},
 Name={20,16,Kit.DisplayFace},Button={20,16,Kit.DisplayFace},
 Heading={20,16,sans(Enum.FontWeight.Bold)},Body={16,14,sans(Enum.FontWeight.Regular)},
 BodyMedium={16,14,sans(Enum.FontWeight.Medium)},Small={14,12,sans(Enum.FontWeight.Regular)},
 Label={13,12,sans(Enum.FontWeight.Bold)},Counter={18,15,mono(Enum.FontWeight.Bold)},
 CounterL={34,22,mono(Enum.FontWeight.Bold)},Strong={16,14,sans(Enum.FontWeight.Bold)},
}
-- Roles drawn in the display face, and the face they use under Kit.DisplayMin.
Kit.DisplayRoles={Title=true,Name=true,Button=true}
local displayFallback=sans(Enum.FontWeight.Bold)
-- The face a role actually draws with at `size` (the display roles drop to Builder
-- Sans Bold under 15 px).
function Kit.faceFor(role,size)
 local spec=Kit.Type[role]or Kit.Type.Body
 if Kit.DisplayRoles[role]and(size or spec[1])<Kit.DisplayMin then return displayFallback end
 return spec[3]
end
Kit.LineHeight=1.25

-- Text measuring that follows the role's face (architect review 2). Synchronous on
-- purpose (code review 2026-11-13): GetTextBoundsAsync can yield on a cold cache,
-- which suspended layout mid-build (results, HUD chips) and let stale updates land
-- later. Every face the kit uses has a legacy Enum.Font twin, so GetTextSize is
-- exact; anything unmapped measures as Builder Sans Bold widened 5%.
local TextService=game:GetService("TextService")
local legacyFonts={
 ["rbxasset://fonts/families/FredokaOne.json"]={Regular=Enum.Font.FredokaOne},
 ["rbxasset://fonts/families/BuilderSans.json"]={Regular=Enum.Font.BuilderSans,Medium=Enum.Font.BuilderSansMedium,
  SemiBold=Enum.Font.BuilderSansBold,Bold=Enum.Font.BuilderSansBold,ExtraBold=Enum.Font.BuilderSansExtraBold,Heavy=Enum.Font.BuilderSansExtraBold},
 ["rbxasset://fonts/families/RobotoMono.json"]={Regular=Enum.Font.RobotoMono,Medium=Enum.Font.RobotoMono,Bold=Enum.Font.RobotoMono},
}
function Kit.legacyFont(face)
 local family=legacyFonts[face.Family]
 return family and(family[face.Weight.Name]or family.Regular)or nil
end
local measureCache,measureCount={},0
function Kit.measure(text,role,size,width)
 text=tostring(text or "");role=role or "Body"
 local face=Kit.faceFor(role,size)
 size=size or(Kit.Type[role]or Kit.Type.Body)[1]
 width=width or 10000
 local key=face.Family.."|"..face.Weight.Name.."|"..size.."|"..width.."|"..text
 local hit=measureCache[key]
 if hit then return hit end
 local font=Kit.legacyFont(face)
 local bounds=TextService:GetTextSize(text,size,font or Enum.Font.BuilderSansBold,Vector2.new(width,10000))
 if not font then bounds=Vector2.new(math.ceil(bounds.X*1.05),bounds.Y)end
 if measureCount>=1024 then table.clear(measureCache);measureCount=0 end
 measureCache[key]=bounds;measureCount+=1
 return bounds
end
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

-- Translation rules (v1 track C, artifacts/localization/LOCALIZATION.md). Roblox
-- automatic translation swaps a label's rendered text when AutoLocalize is true.
-- Words stay on; numbers, pet and player names, ids and rich text built from parts
-- (tier circles, capped goal markup) are off, so they are never translated or
-- captured once per value.
Kit.FixedRoles={Counter=true,CounterL=true}
function Kit.fixedText(label)label.AutoLocalize=false;return label end
-- Rich text: translate only while the text has no markup (a tag would be translated
-- with it, or captured once per circle size).
function Kit.localizeRich(label)label.AutoLocalize=not string.find(label.Text,"<",1,true);return label end
-- Text fit guard (v1 track C). A translation can run 20-35% longer than English and
-- the screen never lays out again, so for players whose Roblox language is not English
-- (or under the Studio pseudo locale) every Kit label whose box was sized for its
-- English text gets an ellipsis instead of a hard cut, and wraps when its box has room
-- for two lines. A label whose English already runs past its box (drawn on purpose) is
-- left alone. Kit buttons cap their auto-sized label at the button width. English
-- players see no change. `KitEnglish` (attribute) is the source text when a spec swaps
-- in a pseudo translation.
local function localeIsEnglish(id)return type(id)~="string"or id==""or string.sub(string.lower(id),1,2)=="en"end
local function translating()
 local okL,roblox=pcall(function()return game:GetService("LocalizationService").RobloxLocaleId end)
 local player=game:GetService("Players").LocalPlayer
 local okP,locale=pcall(function()return player and player.LocaleId end)
 local okC,Copy=pcall(function()return require(game:GetService("ReplicatedStorage").Shared.UICopy)end)
 return not localeIsEnglish(okL and roblox or nil)or not localeIsEnglish(okP and locale or nil)
  or(okC and type(Copy)=="table"and type(Copy.pseudoEnabled)=="function"and Copy.pseudoEnabled())
end
Kit.translating=translating()==true
-- Specs: guard the labels made from now on as a translated client would.
function Kit.setTranslating(on)Kit.translating=on==true end
local function guardText(label)
 if label.TextScaled or label.AutomaticSize~=Enum.AutomaticSize.None or not label.AutoLocalize then return end
 local english=label:GetAttribute("KitEnglish")or label.Text
 if label.RichText and string.find(english,"<",1,true)then return end
 local box=label.AbsoluteSize
 if box.X<2 or box.Y<2 then return end
 local m=Kit.measure(english,label:GetAttribute("KitRole")or "Body",label.TextSize)
 if m.X<=box.X+1 then
  if label.TextTruncate==Enum.TextTruncate.None then label.TextTruncate=Enum.TextTruncate.AtEnd;label:SetAttribute("KitTruncateGuard",true)end
  if not label.TextWrapped and box.Y>=m.Y*2 then label.TextWrapped=true;label:SetAttribute("KitWrapGuard",true)end
 else
  -- English drawn past its box on purpose: put back only what the guard changed.
  if label:GetAttribute("KitTruncateGuard")then label.TextTruncate=Enum.TextTruncate.None;label:SetAttribute("KitTruncateGuard",nil)end
  if label:GetAttribute("KitWrapGuard")then label.TextWrapped=false;label:SetAttribute("KitWrapGuard",nil)end
 end
end
function Kit.guardText(label)
 if label:GetAttribute("KitGuard")then return label end
 label:SetAttribute("KitGuard",true)
 local function run()if label.Parent then guardText(label)end end
 label:GetPropertyChangedSignal("AbsoluteSize"):Connect(run)
 label:GetPropertyChangedSignal("Text"):Connect(run)
 label:GetPropertyChangedSignal("TextSize"):Connect(run)
 task.defer(run)
 return label
end

-- Text in one of the 2.2 roles. `compact` picks the second size (never below 12).
function Kit.text(parent,role,content,color,props)
 local spec=Kit.Type[role]or Kit.Type.Body
 local label=node("TextLabel",parent,{Name=props and props.Name or role,BackgroundTransparency=1,
  Text=if role=="Label"then string.upper(content or "")else content or "",FontFace=spec[3],TextSize=spec[1],
  TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
  LineHeight=Kit.LineHeight,TextWrapped=false,ZIndex=parent.ZIndex+1,Active=false,Size=UDim2.fromOffset(10,spec[1]+4)})
 label:SetAttribute("KitRole",role)
 -- Translation (v1 track C): the counter roles show numbers (scores, Stars, n/m), which
 -- Roblox auto-translation would capture once per value. A counter that shows words
 -- passes AutoLocalize=true in `props`.
 if Kit.FixedRoles[role]then label.AutoLocalize=false end
 paint(label,"TextColor3",color or(if role=="Label"then "dim"else "text"))
 if props then for key,value in pairs(props)do if key~="Name"then label[key]=value end end end
 -- A caller that passes its own FontFace keeps it (the deck's hardware letters).
 if props and props.FontFace then label:SetAttribute("KitFaceFixed",true)end
 Kit.watchDisplayFace(label)
 if Kit.translating then Kit.guardText(label)end
 return label
end
-- Display roles keep the 15 px rule whenever a caller changes TextSize later
-- (one connection per label, set up once; nothing runs per frame).
local function syncFace(label)
 local role=label:GetAttribute("KitRole")
 if role and Kit.DisplayRoles[role]and not label:GetAttribute("KitFaceFixed")then label.FontFace=Kit.faceFor(role,label.TextSize)end
end
function Kit.watchDisplayFace(label)
 syncFace(label)
 if label:GetAttribute("KitFaceWatch")or not Kit.DisplayRoles[label:GetAttribute("KitRole")or ""]then return end
 label:SetAttribute("KitFaceWatch",true)
 label:GetPropertyChangedSignal("TextSize"):Connect(function()syncFace(label)end)
end
function Kit.setFontRole(label,role)
 local spec=Kit.Type[role];if not spec then return end
 label:SetAttribute("KitRole",role);label:SetAttribute("KitFaceFixed",nil);label.FontFace=spec[3]
 Kit.watchDisplayFace(label)
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

-- Vector icons (redesign menus 0.2 / 7: paw, shirt, wand, drop, sparkle, sphere,
-- ball, none, pattern, chevron). The atlas cells for these need a new Open Cloud
-- upload, so until then they are drawn with Frames and UIStrokes inside a size x
-- size holder. Every inked part carries the IconInk attribute; Kit.tintIcon paints them.
local Vector={}
local function ink(holder,name,x,y,size,rotation,radius)
 local f=node("Frame",holder,{Name=name,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,y),Size=size,
  Rotation=rotation or 0,BackgroundTransparency=0,ZIndex=holder.ZIndex,Active=false})
 if radius then Kit.corner(f,radius)end
 f:SetAttribute("IconInk",true);return f
end
local function outline(holder,name,x,y,size,thickness,radius)
 local f=node("Frame",holder,{Name=name,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,y),Size=size,
  BackgroundTransparency=1,ZIndex=holder.ZIndex,Active=false})
 Kit.corner(f,radius or 999)
 local s=node("UIStroke",f,{Name="IconStroke",Thickness=thickness,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 s:SetAttribute("IconInk",true);return f
end
local S=UDim2.fromScale
function Vector.pattern(h,s,t)
 outline(h,"Frame",.5,.5,S(.84,.66),t,math.max(2,math.floor(s*.14)))
 for i,p in ipairs({{.36,.42},{.64,.42},{.36,.6},{.64,.6}})do ink(h,"Dot"..i,p[1],p[2],S(.16,.1),0,999)end
end
function Vector.chevron(h,s,t)
 ink(h,"Upper",.46,.36,UDim2.new(.42,0,0,t),45,999);ink(h,"Lower",.46,.64,UDim2.new(.42,0,0,t),-45,999)
end
function Vector.none(h,s,t)
 outline(h,"Ring",.5,.5,S(.76,.76),t,999);ink(h,"Slash",.5,.5,UDim2.new(.76,0,0,t),-45,999)
end
function Vector.drop(h)ink(h,"Bulb",.5,.62,S(.58,.58),0,999);ink(h,"Tip",.5,.42,S(.41,.41),45,2)end
function Vector.sparkle(h)
 ink(h,"Tall",.44,.54,S(.16,.7),0,999);ink(h,"Wide",.44,.54,S(.7,.16),0,999)
 ink(h,"SmallTall",.8,.2,S(.08,.3),0,999);ink(h,"SmallWide",.8,.2,S(.3,.08),0,999)
end
function Vector.sphere(h)
 ink(h,"Body",.5,.5,S(.78,.78),0,999)
 local shine=node("Frame",h,{Name="Shine",BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),Position=S(.38,.36),Size=S(.22,.22),
  BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.45,ZIndex=h.ZIndex+1,Active=false})
 Kit.corner(shine,999)
end
function Vector.ball(h,s,t)
 outline(h,"Ring",.5,.5,S(.76,.76),t,999)
 ink(h,"Seam",.5,.5,UDim2.new(0,t,.76,0),0);ink(h,"Band",.5,.5,UDim2.new(.76,0,0,t),0)
end
function Vector.paw(h)
 ink(h,"Pad",.5,.68,S(.46,.36),0,999)
 for i,p in ipairs({{.24,.4},{.5,.26},{.76,.4}})do ink(h,"Toe"..i,p[1],p[2],S(.18,.22),0,999)end
end
function Vector.shirt(h)
 ink(h,"Body",.5,.58,S(.44,.6),0,3)
 ink(h,"SleeveL",.24,.36,S(.3,.18),-28,3);ink(h,"SleeveR",.76,.36,S(.3,.18),28,3)
end
function Vector.wand(h)
 ink(h,"Stick",.4,.6,S(.11,.66),45,999)
 ink(h,"Star",.72,.28,S(.26,.26),45,2)
end
-- Deck style "Balls" tab (batch 2026-11-13 R1): a crude smiley.
function Vector.smiley(h,s,t)
 outline(h,"Ring",.5,.5,S(.8,.8),t,999)
 ink(h,"EyeL",.37,.42,S(.12,.14),0,999);ink(h,"EyeR",.63,.42,S(.12,.14),0,999)
 ink(h,"Mouth",.5,.66,UDim2.new(.34,0,0,t),0,999)
end
-- Collection book (play-forever F2): an open book, two tilted pages and the gap of its spine.
function Vector.book(h)
 ink(h,"PageL",.29,.52,S(.38,.6),-6,2);ink(h,"PageR",.71,.52,S(.38,.6),6,2)
end
Kit.VectorIcons=Vector

-- Icons: white art in 64 px cells, tinted with ImageColor3. The star is always gold.
-- Names without an atlas cell but with a vector drawing return a Frame instead.
function Kit.icon(parent,name,size,color)
 if not Assets.Icon[name]and Vector[name]then
  local holder=node("Frame",parent,{Name="Icon_"..name,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(size,size),ZIndex=parent.ZIndex+1,Active=false})
  holder:SetAttribute("VectorIcon",true)
  Vector[name](holder,size,math.max(1.5,math.floor(size*.09*2+.5)/2))
  Kit.tintIcon(holder,color or "text")
  return holder
 end
 local image=node("ImageLabel",parent,{Name="Icon_"..name,BackgroundTransparency=1,Image=Assets.Image.icons,
  ImageRectOffset=Assets.Icon[name]or Vector2.zero,ImageRectSize=Vector2.new(64,64),Size=UDim2.fromOffset(size,size),ZIndex=parent.ZIndex+1})
 paint(image,"ImageColor3",if name=="star"then "stars"else color or "text")
 return image
end
-- Tint an icon from Kit.icon (atlas image or vector holder) with a colour role.
function Kit.tintIcon(icon,color)
 if icon:IsA("ImageLabel")then
  if icon.Name~="Icon_star"then paint(icon,"ImageColor3",color)end
  return
 end
 for _,part in ipairs(icon:GetDescendants())do
  if part:GetAttribute("IconInk")then
   if part:IsA("UIStroke")then paint(part,"Color",color)elseif part:IsA("GuiObject")then paint(part,"BackgroundColor3",color)end
  end
 end
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

-- Chip: height 26 (22 on the board), full radius, padding 10. Kinds: plain, gold,
-- danger, accent, sticker. `sticker` (T6) is the one chip on a card that deserves
-- attention (a detail pane's price, the detail card's tier, "New best"): a solid
-- colour (Stars gold by default, or `color` = a Color3 / Kit.Tint key), ink text
-- (11.9:1 on gold, 11.2:1 on lilac), a cream 2 px border, tilted 4 degrees, a small
-- shadow, landing with a 120 ms overshoot. Under 22 px tall it stays a gold chip.
-- Callers keep 3 px clearance and never put one at a scroll area's edge.
function Kit.chip(parent,content,kind,height)
 height=height or 26
 local role="Label"
 local chip=Kit.frame(parent,"Chip",nil,UDim2.new(),UDim2.fromOffset(40,height),999)
 chip.BackgroundTransparency=0
 local label=Kit.text(chip,role,content,"soft",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
 if height<=22 then label.TextSize=11 end
 local plainSize -- the caller's label size, kept while the chip is a sticker
 local stroke=Kit.stroke(chip)
 local api={root=chip,label=label}
 local sticker -- {shadow, face}, made on first use
 local stickerColor,lastText,lastKind
 local function stickerParts()
  if sticker then return sticker end
  local z=chip.ZIndex
  local shadow=Kit.frame(chip,"StickerShadow",nil,UDim2.fromOffset(1,2),UDim2.fromScale(1,1),999)
  shadow.BackgroundTransparency=Kit.Sticker.shadow;shadow.BackgroundColor3=Kit.Color.black;shadow.ZIndex=z
  local face=Kit.frame(chip,"StickerFace",nil,UDim2.new(),UDim2.fromScale(1,1),999)
  face.BackgroundTransparency=0;face.ZIndex=z+1
  node("UIStroke",face,{Name="StickerBorder",Thickness=Kit.Sticker.border,Color=Kit.Sticker.cream,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  sticker={shadow=shadow,face=face}
  return sticker
 end
 function api.set(text,newKind,color)
  label.Text=string.upper(text);kind=newKind or kind
  if kind=="sticker"and not Kit.stickerAllowed(height)then kind="gold"end
  if color~=nil then stickerColor=color end
  chip:SetAttribute("ChipKind",kind or "plain")
  local isSticker=kind=="sticker"
  if sticker or isSticker then
   local parts=stickerParts()
   parts.shadow.Visible=isSticker;parts.face.Visible=isSticker
  end
  chip.BackgroundTransparency=if isSticker then 1 else 0
  stroke.Enabled=not isSticker
  chip.Rotation=if isSticker then Kit.Sticker.tilt else 0
  label.ZIndex=if isSticker then chip.ZIndex+2 else chip.ZIndex+1
  if isSticker then
   if lastKind~="sticker"then plainSize=label.TextSize end
   label.TextSize=math.max(12,label.TextSize)
  elseif lastKind=="sticker"and plainSize then label.TextSize=plainSize end
  if kind=="gold"then paint(chip,"BackgroundColor3",function()return Kit.color("well"):Lerp(Kit.Color.stars,.14)end);paint(label,"TextColor3","stars")
  elseif kind=="danger"then paint(chip,"BackgroundColor3",function()return Kit.color("well"):Lerp(Kit.Color.danger,.18)end);paint(label,"TextColor3","danger")
  elseif isSticker then
   sticker.face.BackgroundColor3=Kit.tintColor(stickerColor)or Kit.Color.stars;paint(label,"TextColor3","ink")
  else paint(chip,"BackgroundColor3","well");paint(label,"TextColor3","soft")end
  local width=Kit.measure(label.Text,role,label.TextSize).X+20
  chip.Size=UDim2.fromOffset(math.ceil(width),height)
  -- The sticker lands (120 ms overshoot) when it appears or its text changes.
  -- A chip whose owner already animates its own UIScale (the results "New best" pop) is left alone.
  local foreign=chip:FindFirstChildOfClass("UIScale")
  if isSticker and(lastKind~="sticker"or lastText~=label.Text)and not Kit.reduced()and not(foreign and foreign.Name~="BoingScale")then
   local scale=chip:FindFirstChild("BoingScale")or node("UIScale",chip,{Name="BoingScale",Scale=1})
   scale.Scale=.86
   TweenService:Create(scale,TweenInfo.new(Kit.Sticker.land,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
  end
  lastKind,lastText=kind,label.Text
 end
 api.set(content,kind);return api
end

-- Glyph chip: 26 px circle (pill for words) inside buttons and hint bars.
-- `cap` (T8, hint bars only): A draws as the deck's mint cap and B / LB (any other
-- letter word) as a grey cap, each with a 2 px darker lip under it. Symbols such
-- as "+" and "◀▶" keep the plain chip. Size, position and text stay the same.
Kit.CapGrey=Color3.fromHex("#4A505A")
local function capKind(letter)
 if letter=="A"then return "a"end
 if string.match(letter,"^%u+$")then return "grey"end
 return nil
end
function Kit.glyph(parent,letter,onAccent,size,cap)
 size=size or 26
 local wide=#letter>1
 local width=if wide then Kit.measure(letter,"Strong",math.floor(size*.5)).X+16 else size
 local chip=Kit.frame(parent,"Glyph",nil,UDim2.new(),UDim2.fromOffset(width,size),999)
 chip.BackgroundTransparency=0
 local stroke=node("UIStroke",chip,{Name="KitStroke",Thickness=1})
 local text=Kit.text(chip,"Strong",letter,nil,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=math.floor(size*.54)})
 Kit.fixedText(text) -- a key or button name (A, B, LB, ESC), never translated
 local kind=if cap then capKind(letter)else nil
 local lip
 if kind then
  -- The lip sits 2 px below the cap, behind it, inside the same footprint.
  lip=Kit.frame(parent,"GlyphLip",nil,UDim2.new(),UDim2.fromOffset(width,size),999)
  lip.BackgroundTransparency=0;lip.ZIndex=chip.ZIndex
  chip.ZIndex+=1;text.ZIndex=chip.ZIndex+1
  local function follow()lip.Position=chip.Position+UDim2.fromOffset(0,2);lip.Visible=chip.Visible end
  chip:GetPropertyChangedSignal("Position"):Connect(follow)
  chip:GetPropertyChangedSignal("Visible"):Connect(follow)
  chip.Destroying:Connect(function()lip:Destroy()end)
  follow()
  chip:SetAttribute("GlyphCap",kind)
 end
 local function repaint(accent)
  if kind=="a"then
   chip.BackgroundColor3,chip.BackgroundTransparency=Kit.color("accent"),0;stroke.Transparency=1;text.TextColor3=Kit.Color.ink
   lip.BackgroundColor3=Kit.color("accent"):Lerp(Kit.Color.black,.38)
  elseif kind=="grey"then
   chip.BackgroundColor3,chip.BackgroundTransparency=Kit.CapGrey,0;stroke.Color,stroke.Transparency=Kit.Color.white,.82;text.TextColor3=Kit.Color.text
   lip.BackgroundColor3=Kit.CapGrey:Lerp(Kit.Color.black,.45)
  elseif accent then chip.BackgroundColor3,chip.BackgroundTransparency=Kit.Color.ink,.82;stroke.Color,stroke.Transparency=Kit.Color.ink,.65;text.TextColor3=Kit.Color.ink
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
 -- T2: every enabled button with a ledge shows its darker lip; on press the face
 -- (Fill + Content) drops onto it, so the lip stays covered rather than hidden.
 s.edge.Visible=s.enabled and s.ledge>0;s.edge.BackgroundColor3=color:Lerp(Kit.Color.black,.38)
 s.sheen.Visible=accent
 s.stroke.Enabled=s.enabled and s.variant~="ghost"and s.variant~="primary"and s.variant~="reward"or s.selected
 if s.selected then s.stroke.Color,s.stroke.Thickness,s.stroke.Transparency=Kit.color("accent"),2,0
 elseif s.variant=="destructive"then s.stroke.Color,s.stroke.Thickness,s.stroke.Transparency=Kit.Color.danger,1.5,0
 else s.stroke.Color,s.stroke.Thickness,s.stroke.Transparency=Kit.Color.white,1,.86 end
 local ink=if accent then Kit.Color.ink elseif s.variant=="destructive"then Kit.Color.danger elseif s.enabled then Kit.Color.text else Kit.Color.dim
 s.label.TextColor3=ink;s.label.TextTransparency=if s.enabled then 0 else .4
 if s.repaintGlyph then s.repaintGlyph(accent)end
 if s.glyph then s.glyph.Visible=s.showGlyph==true end
 if s.cap then Kit.capButtonLabel(button)end
 -- Press: 60 ms down, 100 ms up; only when the pressed state changes (never per paint).
 local drop=if s.pressed then s.lip else 0
 if s.drop~=drop then
  s.drop=drop
  local time=if s.pressed then Kit.Motion.pressDown else Kit.Motion.pressUp
  Kit.tween(s.content,time,{Position=UDim2.fromOffset(0,drop)})
  if s.ledge>0 then Kit.tween(s.fill,time,{Position=UDim2.fromOffset(0,drop)})end
 end
end
-- T2 lips. options.ledge: the darker lip under the face (primary 6; secondary,
-- destructive and reward 4, or 3 on phones; ghost none). options.lip: how far the
-- face drops on press (the ledge, or 2 px for ghost buttons). `options.compact`
-- picks the phone depth; without it a button 44 px tall or less counts as compact.
Kit.ButtonLip=2 -- ghost settle (no ledge)
Kit.ButtonLedge=6 -- primary ledge (was 3)
Kit.Lip={tile=4,compact=3,primary=6}
-- Pure: {ledge, press drop} for a button variant.
function Kit.buttonLip(variant,compact)
 if variant=="ghost"then return 0,Kit.ButtonLip end
 if variant=="primary"then return Kit.ButtonLedge,Kit.ButtonLedge end
 local depth=if compact then Kit.Lip.compact else Kit.Lip.tile
 return depth,depth
end
-- Translation guard (track C): a translated button label stops at the button's inner
-- width (16 px padding, less the glyph) and truncates, instead of running past the edges.
function Kit.capButtonLabel(button)
 local s=buttons[button];if not(s and s.cap)then return end
 local w=if button.Size.X.Scale==0 then button.Size.X.Offset else button.AbsoluteSize.X
 local glyph=if s.glyph and s.showGlyph then s.glyph.Size.X.Offset+s.list.Padding.Offset else 0
 s.cap.MaxSize=Vector2.new(math.max(10,w-16-glyph),math.huge)
end
function Kit.button(parent,name,options)
 options=options or {}
 local variant=options.variant or "secondary"
 local radius=options.radius or Kit.Radius.button
 local size=options.size or(if variant=="primary"then Vector2.new(200,56)elseif variant=="reward"then Vector2.new(120,38)else Vector2.new(180,48))
 local button=node("TextButton",parent,{Name=name,Text="",AutoButtonColor=false,BackgroundTransparency=1,
  Size=UDim2.fromOffset(size.X,size.Y),ZIndex=parent.ZIndex+1,Selectable=options.selectable~=false})
 button:SetAttribute("AccessibleLabel",options.text)
 local compact=if options.compact~=nil then options.compact==true else size.Y<=44
 local defaultLedge,defaultLip=Kit.buttonLip(variant,compact)
 local ledge=options.ledge or defaultLedge
 local edge=Kit.frame(button,"Edge",nil,UDim2.fromOffset(0,ledge),UDim2.fromScale(1,1),radius);edge.BackgroundTransparency=0
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
 -- The button label role (T1): Fredoka One at 15 px and up; reward buttons keep
 -- their 16 px default size.
 local label=Kit.text(content,"Button",options.text or name,nil,{Name="Label",AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,size.Y),LayoutOrder=2,TextXAlignment=Enum.TextXAlignment.Center,
  TextSize=options.textSize or(if variant=="reward"then Kit.Type.Strong[1]else Kit.Type.Button[1])})
 local state={variant=variant,enabled=true,hover=false,pressed=false,selected=false,showGlyph=options.showGlyph~=false,lip=options.lip or(if options.ledge then options.ledge else defaultLip),ledge=ledge,drop=0,
  fill=fill,edge=edge,sheen=sheen,stroke=stroke,content=content,label=label,glyph=glyph,repaintGlyph=repaintGlyph,list=list}
 buttons[button]=state
 if Kit.translating then
  state.cap=node("UISizeConstraint",label,{Name="TranslateCap"});label.TextTruncate=Enum.TextTruncate.AtEnd
  button:GetPropertyChangedSignal("Size"):Connect(function()Kit.capButtonLabel(button)end)
  button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()Kit.capButtonLabel(button)end)
  Kit.capButtonLabel(button)
 end
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
 -- options.seam (T2): the stitched seam 6 px inside the edge (information panes only;
 -- no seam asset = no instance; hidden on cards under 150 px tall).
 if options.seam then card:SetAttribute("KitSeam",true);Kit.seam(card)end
 local pad=options.pad or 20
 local eyebrow
 if label then eyebrow=Kit.text(card,"Label",label,"dim",{Name="Eyebrow",Position=UDim2.fromOffset(pad,options.labelY or 12),Size=UDim2.new(1,-pad*2,0,16)})end
 return card,eyebrow
end

-- ── P2 surfaces (UI personality T2, T6, T7, T11) ───────────────────────────
-- Three surfaces, three meanings: things you press have a lip, things you read have
-- a seam, preview windows stay inset (with the LCD dot grid). Every motion here is
-- cut under Reduced Motion, and a missing asset id creates no instance at all.

-- Boing (T11): 0.96 -> 1.04 -> 1 in 160 ms (Back-out on the way home) on the
-- object's UIScale. Selection and stickers only, never text being read. Nothing
-- under Reduced Motion. One UIScale per object, made on first use.
Kit.BoingTime=.16
function Kit.boing(object)
 if not object or Kit.reduced()then return end
 -- Never fight an owner's own UIScale (two UIScales on one object do not stack).
 local foreign=object:FindFirstChildOfClass("UIScale")
 if foreign and foreign.Name~="BoingScale"then return end
 local scale=object:FindFirstChild("BoingScale")or node("UIScale",object,{Name="BoingScale",Scale=1})
 local half=Kit.BoingTime/2
 scale.Scale=.96
 TweenService:Create(scale,TweenInfo.new(half,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1.04}):Play()
 task.delay(half,function()
  if scale.Parent then TweenService:Create(scale,TweenInfo.new(half,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()end
 end)
end

-- Seam (T2): a stitched line 6 px inside an information pane's edge, white at 12%.
-- One image (Assets.Personality.seam, 64 x 40 at 2x): a 40 x 40 corner 9-slice
-- (radius 8 at 1x) plus a horizontal and a vertical dash tile, so the stitches keep
-- their length on any card size (a 9-slice alone would stretch them). Dropped on
-- cards under 150 px tall.
Kit.SeamInset=6
Kit.SeamMinHeight=150
Kit.SeamTransparency=.88
Kit.SeamRects={corner={0,0,40,40},horizontal={40,0,16,4},vertical={56,0,4,16}}
-- Pure: does a card of this height carry a seam?
function Kit.seamAllowed(height)return(height or 0)>=Kit.SeamMinHeight end
local function cardHeight(card)
 if card.Size.Y.Scale==0 then return card.Size.Y.Offset end
 return card.AbsoluteSize.Y
end
function Kit.seam(card)
 local image=Assets.Personality and Assets.Personality.seam
 if not(image and card)then return nil end
 local existing=card:FindFirstChild("Seam")
 if existing then return existing end
 local inset=Kit.SeamInset
 local z=card.ZIndex
 local holder=node("Frame",card,{Name="Seam",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(inset,inset),
  Size=UDim2.new(1,-inset*2,1,-inset*2),ZIndex=z,Active=false,Selectable=false})
 local R=Kit.SeamRects
 local function piece(name,props)
  local p=node("ImageLabel",holder,{Name=name,BackgroundTransparency=1,Image=image,ImageTransparency=Kit.SeamTransparency,ZIndex=z,Active=false,Selectable=false})
  for key,value in pairs(props)do p[key]=value end
  return p
 end
 piece("Corners",{Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(18,18,22,22),SliceScale=.5,
  ImageRectOffset=Vector2.new(R.corner[1],R.corner[2]),ImageRectSize=Vector2.new(R.corner[3],R.corner[4])})
 local function strip(name,position,size,rect,tile)
  piece(name,{Position=position,Size=size,ScaleType=Enum.ScaleType.Tile,TileSize=tile,
   ImageRectOffset=Vector2.new(rect[1],rect[2]),ImageRectSize=Vector2.new(rect[3],rect[4])})
 end
 strip("Top",UDim2.fromOffset(9,0),UDim2.new(1,-18,0,2),R.horizontal,UDim2.fromOffset(8,2))
 strip("Bottom",UDim2.new(0,9,1,-2),UDim2.new(1,-18,0,2),R.horizontal,UDim2.fromOffset(8,2))
 strip("Left",UDim2.fromOffset(0,9),UDim2.new(0,2,1,-18),R.vertical,UDim2.fromOffset(2,8))
 strip("Right",UDim2.new(1,-2,0,9),UDim2.new(0,2,1,-18),R.vertical,UDim2.fromOffset(2,8))
 local function update()holder.Visible=Kit.seamAllowed(cardHeight(card))end
 card:GetPropertyChangedSignal("Size"):Connect(update)
 card:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
 update()
 return holder
end

-- Lip (T2): the darker bottom lip under a pressable surface, 4 px (3 on phones).
-- The surface is a transparent hit rect (TextButton) holding Lip (ZIndex - 1) and
-- Face (ZIndex) under the caller's own children, so it draws the same under
-- Sibling and Global ZIndexBehavior; the hit rect, size and focus order never move.
-- The Face mirrors the hit rect's BackgroundColor3, so callers keep painting the
-- button itself. On press the face and its contents drop onto the lip (a UIPadding
-- with a matching negative bottom, so nothing resizes): 60 ms down, 100 ms up.
local tiles=setmetatable({},{__mode="k"})
-- Pure: lip depth for a pressable tile.
function Kit.tileLip(compact)return if compact then Kit.Lip.compact else Kit.Lip.tile end
local function pressTile(state,down)
 if state.pressed==down then return end
 state.pressed=down
 local time=if down then Kit.Motion.pressDown else Kit.Motion.pressUp
 local drop=if down then state.lip else 0
 Kit.tween(state.pad,time,{PaddingTop=UDim.new(0,drop),PaddingBottom=UDim.new(0,-drop)})
 Kit.tween(state.lipFrame,time,{Position=UDim2.fromOffset(0,state.lip-drop)})
end
Kit.pressTile=function(tile,down)local s=tiles[tile];if s then pressTile(s,down==true)end end
-- Hardware or keyboard press on a tile (the Kit.pulse of tiles).
function Kit.pulseTile(tile)
 local s=tiles[tile];if not s then return end
 pressTile(s,true)
 task.delay(Kit.Motion.pressDown+Kit.Motion.pressUp,function()pressTile(s,false)end)
end
function Kit.tileState(tile)return tiles[tile]end
-- A reused tile that moves between desktop and phone layouts changes lip depth.
function Kit.setTileLip(tile,depth)
 local s=tiles[tile];if not s or s.lip==depth then return end
 s.lip=depth;s.pressed=false
 s.pad.PaddingTop,s.pad.PaddingBottom=UDim.new(),UDim.new()
 s.lipFrame.Position=UDim2.fromOffset(0,depth);s.lipFrame.BackgroundTransparency=if depth>0 then 0 else 1
 tile:SetAttribute("KitLip",depth)
end

-- Tile (T2): a pressable card (radius 12, 1 px stroke) with the lip. options:
-- position, size, radius, role ("raised"), lip (px; 0 = none), compact (3 px lip),
-- selectable. Returns the TextButton (the hit rect) and its state {lip, face,
-- lipFrame, stroke, setSelected(on, animate)}.
function Kit.tile(parent,name,options)
 options=options or {}
 local radius=options.radius or Kit.Radius.tile
 local tile=node("TextButton",parent,{Name=name or "Tile",Text="",AutoButtonColor=false,BackgroundTransparency=1,
  Position=options.position or UDim2.new(),Size=options.size or UDim2.fromOffset(104,88),ZIndex=parent.ZIndex+1,Selectable=options.selectable~=false})
 Kit.corner(tile,radius)
 local lip=options.lip or Kit.tileLip(options.compact)
 local lipFrame=node("Frame",tile,{Name="TileLip",BorderSizePixel=0,BackgroundTransparency=if lip>0 then 0 else 1,Position=UDim2.fromOffset(0,lip),
  Size=UDim2.fromScale(1,1),ZIndex=tile.ZIndex-1,Active=false,Selectable=false})
 Kit.corner(lipFrame,radius)
 local face=node("Frame",tile,{Name="TileFace",BorderSizePixel=0,BackgroundTransparency=0,Size=UDim2.fromScale(1,1),ZIndex=tile.ZIndex,Active=false,Selectable=false})
 Kit.corner(face,radius)
 local stroke=Kit.stroke(face)
 local pad=node("UIPadding",tile,{Name="PressPad"})
 local state={lip=lip,selected=false,stroke=stroke,face=face,lipFrame=lipFrame,pad=pad,pressed=false}
 tiles[tile]=state
 local function mirror()
  face.BackgroundColor3=tile.BackgroundColor3
  lipFrame.BackgroundColor3=tile.BackgroundColor3:Lerp(Kit.Color.black,.38)
 end
 tile:GetPropertyChangedSignal("BackgroundColor3"):Connect(mirror)
 -- A caller that changes the hit rect's ZIndex keeps the lip and face under its children.
 tile:GetPropertyChangedSignal("ZIndex"):Connect(function()lipFrame.ZIndex=tile.ZIndex-1;face.ZIndex=tile.ZIndex end)
 paint(tile,"BackgroundColor3",options.role or "raised")
 mirror()
 tile:SetAttribute("KitTile",true);tile:SetAttribute("KitLip",lip)
 if lip>0 then
  tile.MouseButton1Down:Connect(function()if tile.Interactable then pressTile(state,true)end end)
  tile.MouseButton1Up:Connect(function()pressTile(state,false)end)
  tile.MouseLeave:Connect(function()pressTile(state,false)end)
  -- Never leave a tile dropped when it is disabled, hidden or loses selection mid-press (code review).
  local function release()pressTile(state,false)end
  tile:GetPropertyChangedSignal("Interactable"):Connect(release)
  tile:GetPropertyChangedSignal("Visible"):Connect(release)
  tile.SelectionLost:Connect(release)
 end
 function state.setSelected(on,animate)
  local was=state.selected
  state.selected=on==true
  paint(tile,"BackgroundColor3",if state.selected then "selected"else(options.role or "raised"))
  stroke.Thickness=if state.selected then 2 else 1;stroke.Transparency=if state.selected then 0 else Kit.Stroke.transparency
  paint(stroke,"Color",if state.selected then "accent"else function()return Kit.Stroke.color end)
  if animate and state.selected and not was then Kit.boing(tile)end
 end
 return tile,state
end

-- Well (T7): an inset preview window. Wells that show an egg, a board or a row of
-- balls carry a 6 px LCD dot grid at about 6% white under the art (tiled image,
-- Assets.Personality.dotGrid); with no id nothing extra is created.
Kit.DotGridTransparency=.94
function Kit.dotGrid(well)
 local image=Assets.Personality and Assets.Personality.dotGrid
 if not(image and well)then return nil end
 local existing=well:FindFirstChild("DotGrid")
 if existing then return existing end
 local grid=node("ImageLabel",well,{Name="DotGrid",BackgroundTransparency=1,Image=image,ImageTransparency=Kit.DotGridTransparency,ScaleType=Enum.ScaleType.Tile,
  TileSize=UDim2.fromOffset(6,6),Size=UDim2.fromScale(1,1),ZIndex=well.ZIndex,Active=false,Selectable=false})
 local corner=well:FindFirstChildOfClass("UICorner")
 if corner then node("UICorner",grid,{CornerRadius=corner.CornerRadius})end
 return grid
end
function Kit.well(parent,name,position,size,radius)
 local well=Kit.frame(parent,name or "Well","well",position,size,radius or Kit.Radius.well)
 Kit.stroke(well)
 Kit.dotGrid(well)
 return well
end

-- Sticker chip rules (T6): never under 22 px tall, 3 px clearance for the tilt, never
-- at a scroll area's edge. Pure; Kit.chip falls back to a gold chip under 22 px.
Kit.Sticker={tilt=-4,border=2,minHeight=22,clearance=3,cream=Color3.fromHex("#FFF4DC"),shadow=.72,land=.12}
function Kit.stickerAllowed(height,clearance,atScrollEdge)
 return(height or 0)>=Kit.Sticker.minHeight and(clearance or Kit.Sticker.clearance)>=Kit.Sticker.clearance and not atScrollEdge
end
-- First candidate that fits `width` at the label's role and size (UICopy fit chains:
-- a voiced line falls back to its shorter or older wording, never wraps).
function Kit.fitText(label,candidates,width)
 local role=label:GetAttribute("KitRole")or "Body"
 width=width or label.Size.X.Offset
 for index,text in ipairs(candidates)do
  if index==#candidates or Kit.measure(text,role,label.TextSize).X<=width then label.Text=text;return text end
 end
 return label.Text
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
-- `icons` (optional, one name per label, redesign 0.2): icon (label size + 4) and
-- label side by side, 7 px apart, centred in the segment. When any segment cannot fit
-- icon + label with 6 px each side, the whole row drops its icons (never the labels).
Kit.TabIconGap=7
function Kit.tabIconsFit(labels,icons,segment,textSize)
 if not icons then return false end
 for index,text in ipairs(labels)do
  if not icons[index]then return false end
  local w=Kit.measure(text,"Strong",textSize).X
  if(textSize+4)+Kit.TabIconGap+w+12>segment then return false end
 end
 return true
end
function Kit.tabs(parent,labels,width,height,textSize,icons)
 width=width or 520;height=height or 44;textSize=textSize or 17
 local track=Kit.frame(parent,"Tabs","well",UDim2.new(),UDim2.fromOffset(width,height),999);Kit.stroke(track)
 local segment=(width-8)/#labels
 local pill=Kit.frame(track,"Pill","accent",UDim2.fromOffset(4,4),UDim2.fromOffset(segment,height-8),999)
 local api={root=track,buttons={},selected=1,labels={},icons={}}
 local withIcons=Kit.tabIconsFit(labels,icons,segment,textSize)
 local iconSize=textSize+4
 api.hasIcons=withIcons;track:SetAttribute("TabIcons",withIcons)
 for index,text in ipairs(labels)do
  local hitH=math.max(44,height-8)
  local b=node("TextButton",track,{Name="Tab"..index,Text="",AutoButtonColor=false,BackgroundTransparency=1,Position=UDim2.fromOffset(4+(index-1)*segment,(height-hitH)/2),Size=UDim2.fromOffset(segment,hitH),ZIndex=pill.ZIndex+1})
  b:SetAttribute("AccessibleLabel",text)
  local label
  if withIcons then
   local w=math.ceil(Kit.measure(text,"Strong",textSize).X)
   local x=math.floor((segment-(iconSize+Kit.TabIconGap+w))/2)
   local icon=Kit.icon(b,icons[index],iconSize,"soft");icon.AnchorPoint=Vector2.new(0,.5);icon.Position=UDim2.new(0,x,.5,0)
   api.icons[index]=icon
   label=Kit.text(b,"Strong",text,"soft",{Position=UDim2.fromOffset(x+iconSize+Kit.TabIconGap,0),Size=UDim2.new(0,w+2,1,0),TextSize=textSize})
  else
   label=Kit.text(b,"Strong",text,"soft",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=textSize})
  end
  local dot=Kit.frame(b,"ClaimDot","stars",UDim2.new(.5,0,.5,-11),UDim2.fromOffset(8,8),999);dot.Visible=false
  api.buttons[index],api.labels[index]=b,label;b:SetAttribute("ClaimDot",false)
  b.Activated:Connect(function()api.select(index)if api.changed then api.changed(index)end end)
 end
 -- QA 2026-11-13 (Deck style Balls tab overflowed the track's right edge): a
 -- re-select of the tab already in flight (the owner's applyTab right after the
 -- click) cancelled the settle half while the squash tween kept its stretched
 -- width. Now every select owns and cancels its tweens, a re-select of the tab in
 -- flight lets it land, the squash is clamped inside the track and the pill always
 -- ends on the exact segment rect (Kit.tabs.pillRect).
 local squashToken,running,inFlight=0,{},nil
 local function cancelMotion()
  for _,tween in ipairs(running)do tween:Cancel()end
  table.clear(running)
 end
 local function play(time,goal)
  local tween=TweenService:Create(pill,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal)
  table.insert(running,tween);tween:Play()
 end
 local inner=width-8
 api.pillRect=function(index)
  -- Pure: the pill's resting x and size for `index`, inside the 4 px track inset.
  local x0=math.floor(4+(index-1)*segment+.5)
  local x1=math.floor(4+index*segment+.5)
  if index>=#labels then x1=4+inner end
  return x0,Vector2.new(x1-x0,height-8)
 end
 api.squashX=function(fromX,toX,stretch,w)
  -- Pure: the mid-flight x of the stretched pill, never past either track edge.
  local mid=math.floor((fromX+toX)/2-stretch/2+.5)
  return math.clamp(mid,4,math.max(4,4+inner-(w+stretch)))
 end
 function api.select(index)
  local moved=index~=api.selected
  api.selected=index
  local x,size=api.pillRect(index)
  local goal,rest=UDim2.fromOffset(x,4),UDim2.fromOffset(size.X,size.Y)
  -- T11 squash: the pill stretches 6% along its travel at mid-flight, centred on
  -- its path, then settles (cut under Reduced Motion).
  if moved or inFlight~=index then
   squashToken+=1;cancelMotion();inFlight=nil
   if moved and not Kit.reduced()then
    local token,half=squashToken,Kit.Motion.tab/2
    local stretch=math.floor(segment*.06+.5)
    inFlight=index
    play(half,{Position=UDim2.fromOffset(api.squashX(pill.Position.X.Offset,x,stretch,size.X),4),Size=UDim2.fromOffset(size.X+stretch,size.Y)})
    task.delay(half,function()
     if token~=squashToken or not pill.Parent then return end
     cancelMotion();play(half,{Position=goal,Size=rest})
     task.delay(half+.03,function()
      if token==squashToken and pill.Parent then cancelMotion();inFlight=nil;pill.Position=goal;pill.Size=rest end
     end)
    end)
   elseif Kit.reduced()then pill.Position=goal;pill.Size=rest
   else
    pill.Size=rest;play(Kit.Motion.tab,{Position=goal})
   end
  end
  for i,label in ipairs(api.labels)do
   paint(label,"TextColor3",if i==index then "ink"else "soft")
   if api.icons[i]then Kit.tintIcon(api.icons[i],if i==index then "ink"else "soft")end
  end
  track:SetAttribute("Selected",index)
 end
 function api.setDot(index,on)
  local label,dot=api.labels[index],api.buttons[index].ClaimDot
  dot.Visible=on==true
  local w=Kit.measure(label.Text,"Strong",textSize).X
  local dy=if textSize<17 then -9 else -11
  if withIcons then dot.Position=UDim2.new(0,label.Position.X.Offset+w+(if textSize<17 then 4 else 9),.5,dy)
  else dot.Position=UDim2.new(.5,w/2+(if textSize<17 then 4 else 9),.5,dy)end
 end
 api.select(1);return api
end

-- Stars with thousands separators ("1,280"); the accessible label keeps the raw number.
function Kit.formatStars(value)
 if type(value)=="number"and value>=1000 and value%1==0 and value<1e15 then
  local text=string.format("%d",value):reverse():gsub("(%d%d%d)","%1,"):reverse()
  return(text:gsub("^,",""))
 end
 return tostring(value)
end
-- Wallet pill (Stars capsule). The shared header heights (redesign 0.1): 44 with
-- star 22, Counter 18 and padding 18; 36 (compact) with star 18, Counter 15 and
-- padding 15. Other heights keep the older proportions their screens were built with.
Kit.WalletSpec={[44]={star=22,text=18,pad=18},[36]={star=18,text=15,pad=15}}
function Kit.wallet(parent,height)
 height=height or 44
 local spec=Kit.WalletSpec[height]
 local pill=Kit.frame(parent,"Wallet","well",UDim2.new(),UDim2.fromOffset(110,height),999);Kit.stroke(pill)
 local star=Kit.icon(pill,"star",if spec then spec.star else math.floor(height*.55));star.AnchorPoint=Vector2.new(0,.5)
 star.Position=UDim2.new(0,if spec then spec.pad else math.floor(height*.45),.5,0)
 -- T9: the Star gets two eyes from 20 px up and stays plain below. The uploaded
 -- eyes cell (DeckAssets.Personality.starFace, right half) when there is one, else
 -- two ink dots; a missing id creates no ImageLabel.
 local starSize=star.Size.X.Offset
 if starSize>=20 then
  local faceId=Assets.Personality and Assets.Personality.starFace
  if faceId then
   node("ImageLabel",star,{Name="StarFace",BackgroundTransparency=1,Image=faceId,ImageRectOffset=Vector2.new(128,0),ImageRectSize=Vector2.new(128,128),
    Size=UDim2.fromScale(1,1),ZIndex=star.ZIndex+1,Active=false})
  else
   for side=-1,1,2 do
    local eye=node("Frame",star,{Name="StarEye",BorderSizePixel=0,BackgroundColor3=Color3.fromHex("#3B2608"),AnchorPoint=Vector2.new(.5,.5),
     Position=UDim2.fromScale(.5+side*.11,.54),Size=UDim2.fromOffset(math.max(2,math.floor(starSize*.12+.5)),math.max(3,math.floor(starSize*.18+.5))),
     ZIndex=star.ZIndex+1,Active=false})
    Kit.corner(eye,999)
   end
  end
  star:SetAttribute("StarFace",true)
 end
 -- From 20 px up the icon gives way to a small spinning 3D Star in the same rect
 -- once the StarToken mesh loads (WalletStar); the 2D Star stays as the fallback.
 local star3D=require(script.Parent.WalletStar).attach(pill,star,starSize)
 local amount=Kit.text(pill,"Counter","0","text",{Name="Amount",AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-(if spec then spec.pad else 18),.5,0),Size=UDim2.fromOffset(60,height),TextXAlignment=Enum.TextXAlignment.Right})
 if spec then amount.TextSize=spec.text elseif height<40 then amount.TextSize=15 end
 local api={root=pill,amount=amount,height=height,star=star,star3D=star3D}
 function api.set(value)
  amount.Text=Kit.formatStars(value)
  local w=game:GetService("TextService"):GetTextSize(amount.Text,amount.TextSize,Enum.Font.RobotoMono,Vector2.new(500,50)).X
  amount.Size=UDim2.fromOffset(math.ceil(w)+2,height)
  pill.Size=if spec then UDim2.fromOffset(math.ceil(spec.pad+spec.star+8+w+spec.pad),height)
   else UDim2.fromOffset(math.ceil(w+height*.45+height*.55+12+18),height)
  pill:SetAttribute("AccessibleLabel",require(script.Parent.StarText).amount(value))
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
  -- A padded host (the phone sheets' plate-grip inset) shifts its children's origin.
  local pad=host:FindFirstChildOfClass("UIPadding")
  if pad then origin+=Vector2.new(pad.PaddingLeft.Offset,pad.PaddingTop.Offset)end
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
  local w=Kit.measure(item.text,"Strong",size).X
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
-- options.header (redesign 0.1): the shared header's circle, 44 drawn on regular
-- screens and 36 drawn inside a 44x44 hit frame on compact ones. The TextButton is
-- always the hit frame; `Disc` draws the circle.
function Kit.backArrowSizes(compact,header)
 local drawn=if header then(if compact then 36 else 44)elseif compact then 44 else 56
 return drawn,math.max(44,drawn)
end
function Kit.backArrow(parent,compact,options)
 local header=options and options.header==true
 local drawn,hit=Kit.backArrowSizes(compact,header)
 local button=node("TextButton",parent,{Name="BackArrow",Text="",AutoButtonColor=false,AnchorPoint=Vector2.new(1,0),
  Size=UDim2.fromOffset(hit,hit),BackgroundColor3=Color3.fromHex("#15171B"),BackgroundTransparency=.28,ZIndex=60,Selectable=false})
 button:SetAttribute("AccessibleLabel","Back")
 local disc=button
 if header then
  button.BackgroundTransparency=1
  disc=node("Frame",button,{Name="Disc",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(drawn,drawn),
   BorderSizePixel=0,BackgroundColor3=Color3.fromHex("#15171B"),BackgroundTransparency=.28,ZIndex=button.ZIndex,Active=false})
  button:GetPropertyChangedSignal("ZIndex"):Connect(function()disc.ZIndex=button.ZIndex
   for _,child in ipairs(disc:GetChildren())do if child:IsA("GuiObject")then child.ZIndex=if child.Name=="Shadow"then button.ZIndex-1 else button.ZIndex+1 end end
  end)
 end
 Kit.corner(disc,999)
 local stroke=node("UIStroke",disc,{Name="KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1.5,Color=Kit.Color.white,Transparency=.76})
 local shadow=node("ImageLabel",disc,{Name="Shadow",BackgroundTransparency=1,Image=Assets.Image.focusGlow,ImageColor3=Kit.Color.black,ImageTransparency=.55,
  ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(40,40,56,56),Position=UDim2.fromOffset(-14,-9),Size=UDim2.new(1,28,1,28),ZIndex=59})
 local iconSize=if drawn>=56 then 26 elseif drawn>=44 then 22 else 18
 local icon=Kit.icon(disc,"back",iconSize,"text");icon.AnchorPoint,icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 local api={root=button,disc=disc,enabled=true,size=hit,drawn=drawn,header=header}
 local hover,pressed=false,false
 local function repaint()
  disc.BackgroundColor3=if hover and api.enabled then Color3.fromHex("#282B32")else Color3.fromHex("#15171B")
  disc.BackgroundTransparency=if not api.enabled then .65 elseif hover then .22 else .28
  if pressed then disc.BackgroundColor3=disc.BackgroundColor3:Lerp(Kit.Color.black,.08)end
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
  local d,h=Kit.backArrowSizes(isCompact,header)
  api.size,api.drawn=h,d;button.Size=UDim2.fromOffset(h,h)
  if disc~=button then disc.Size=UDim2.fromOffset(d,d)end
  local s=if d>=56 then 26 elseif d>=44 then 22 else 18
  icon.Size=UDim2.fromOffset(s,s)
 end
 repaint();return api
end

-- T5 one tint per screen family. Decoration only, never state: it appears in exactly
-- three places, a dot plus the eyebrow, a squiggle under the title and a halftone
-- dot fade along the panel's bottom edge (phones skip the halftone). Mint stays the
-- only action colour; gold marks only Stars (the results family).
-- Collection book (play-forever F2) = mint-teal #7FE0C8, kept apart from the action
-- mint: 10.1:1 on the panel, 8.4:1 on raised cards, ink on it 12.2:1.
Kit.Tint={hatch=Color3.fromHex("#FFA98F"),style=Color3.fromHex("#C9A7FF"),companions=Color3.fromHex("#FF9EC4"),
 quests=Color3.fromHex("#8CC8FF"),results=Kit.Color.stars,book=Color3.fromHex("#7FE0C8")}
local function tintColor(tint)
 if typeof(tint)=="Color3"then return tint end
 return Kit.Tint[tint]
end
Kit.tintColor=tintColor
-- Dot + eyebrow: the eyebrow text takes the tint and moves 14 px right inside its
-- own rect (a UIPadding), with an 8 px dot where the text used to start.
function Kit.tintEyebrow(eyebrow,tint)
 local color=tintColor(tint);if not(eyebrow and color)then return nil end
 paint(eyebrow,"TextColor3",function()return color end)
 local pad=eyebrow:FindFirstChild("TintPad")or node("UIPadding",eyebrow,{Name="TintPad"})
 pad.PaddingLeft=UDim.new(0,14)
 local dot=eyebrow:FindFirstChild("TintDot")or Kit.frame(eyebrow,"TintDot",nil,UDim2.new(0,0,.5,0),UDim2.fromOffset(8,8),999)
 dot.AnchorPoint=Vector2.new(0,.5);dot.BackgroundTransparency=0;dot.BackgroundColor3=color
 -- UIPadding shifts children too; pull the dot back to the rect's left edge.
 dot.Position=UDim2.new(0,-14,.5,0)
 eyebrow:SetAttribute("Tint",color:ToHex())
 return dot
end
-- Squiggle under a title (tiled image, 12 x 6 per wave). Width follows the title's
-- text: about 62% of it, at least 24 px, never past the title rect. Missing asset:
-- nothing is created and nil is returned.
function Kit.squiggle(parent,title,tint)
 local color,image=tintColor(tint),Assets.Personality and Assets.Personality.squiggle
 if not(color and image and title)then return nil end
 local line=node("ImageLabel",parent,{Name="TintSquiggle",BackgroundTransparency=1,Image=image,ImageColor3=color,
  ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(12,6),Size=UDim2.fromOffset(24,6),ZIndex=title.ZIndex,Active=false})
 local api={root=line}
 function api.update()
  local role=title:GetAttribute("KitRole")or "Title"
  local w=if title.Text=="" then 0 else Kit.measure(title.Text,role,title.TextSize).X
  local limit=title.Size.X.Offset
  local width=math.min(limit,math.max(24,math.floor(w*.62/12+.5)*12))
  line.Visible=title.Visible and w>0 and limit>=24
  line.Position=UDim2.fromOffset(title.Position.X.Offset,title.Position.Y.Offset+title.Size.Y.Offset-1)
  line.Size=UDim2.fromOffset(width,6)
 end
 api.update()
 return api
end
-- Halftone dot fade along `panel`'s bottom edge, behind the hint bar, at about 10%.
-- Phones (compact) and a missing asset create nothing.
function Kit.halftone(panel,tint,compact,height)
 local color,image=tintColor(tint),Assets.Personality and Assets.Personality.halftone
 if compact or not(color and image and panel)then return nil end
 height=height or 48
 local fade=node("ImageLabel",panel,{Name="TintHalftone",BackgroundTransparency=1,Image=image,ImageColor3=color,ImageTransparency=.9,
  ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(48,48),AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),
  Size=UDim2.new(1,0,0,height),ZIndex=panel.ZIndex,Active=false,Selectable=false})
 local radius=panel:FindFirstChildOfClass("UICorner")
 if radius then node("UICorner",fade,{CornerRadius=radius.CornerRadius})end
 return fade
end

-- 0.1 Shared header (one component; redesign menus). Pure geometry first, in the
-- parent's units for a W-wide screen. Regular: eyebrow at left,14 (Label 13), title
-- Title 26 centred on y 48, back circle 44 with its right edge at W-24 centred on y 44,
-- the Stars capsule 44 high 8 px left of it. Compact: no eyebrow, title Title 20
-- centred on y 34, back drawn 36 (hit 44) with its right edge at W-20, capsule 36.
-- The title stops 12 px before the capsule (or the back circle with no wallet).
function Kit.headerGeometry(W,compact,walletW,left)
 compact=compact==true
 local h=if compact then 36 else 44
 local cy=if compact then 34 else 44
 local right=W-(if compact then 20 else 24)
 left=left or 24
 local g={compact=compact,height=if compact then 60 else 84,centerY=cy,controlH=h,right=right}
 g.back={x=right-h,y=cy-h/2,w=h,h=h}
 g.backHit={x=right-h/2-22,y=cy-22,w=44,h=44}
 g.wallet=if walletW then{x=g.back.x-8-walletW,y=cy-h/2,w=walletW,h=h}else nil
 local limit=(if g.wallet then g.wallet.x else g.back.x)-12
 local th=if compact then 24 else 32
 local tcy=if compact then 34 else 48
 g.title={x=left,y=tcy-th/2,w=math.max(0,limit-left),h=th}
 g.eyebrow=if compact then nil else{x=left,y=14,w=math.max(0,limit-left),h=16}
 return g
end
-- options: title, eyebrow (regular only), wallet (false hides the capsule), compact,
-- width (W), left (title x, default 24), onBack, tint (T5: a Kit.Tint key or Color3
-- for the dot + eyebrow and the title squiggle). Returns {root, title, eyebrow,
-- wallet = {root, amount, set}, back = Kit.backArrow api, layout(W, left), setTitle}.
function Kit.header(parent,options)
 options=options or {}
 local compact=options.compact==true
 local api={compact=compact,W=options.width or 848,left=options.left or 24}
 local holder=Kit.frame(parent,"Header",nil,UDim2.new(),UDim2.fromOffset(api.W,if compact then 60 else 84))
 api.root=holder
 api.eyebrow=Kit.text(holder,"Label",options.eyebrow or "","dim",{Name="Eyebrow",TextTruncate=Enum.TextTruncate.AtEnd})
 api.title=Kit.text(holder,"Title",options.title or "","text",{Name="Title",TextSize=if compact then 20 else 26,TextTruncate=Enum.TextTruncate.AtEnd})
 local inner
 if options.wallet~=false then inner=Kit.wallet(holder,if compact then 36 else 44);inner.root.AnchorPoint=Vector2.zero end
 local back=Kit.backArrow(holder,compact,{header=true});back.root.AnchorPoint=Vector2.zero;back.root.ZIndex=holder.ZIndex+5
 api.back=back
 local function place(object,r)object.Position=UDim2.fromOffset(r.x,r.y);object.Size=UDim2.fromOffset(r.w,r.h)end
 function api.layout(W,left)
  api.W=W or api.W;api.left=left or api.left
  holder.Size=UDim2.fromOffset(api.W,if compact then 60 else 84)
  local g=Kit.headerGeometry(api.W,compact,inner and inner.root.Size.X.Offset or nil,api.left)
  api.geometry=g
  place(api.title,g.title)
  api.eyebrow.Visible=g.eyebrow~=nil and api.eyebrow.Text~=""
  if g.eyebrow then place(api.eyebrow,g.eyebrow)end
  if inner then place(inner.root,g.wallet)end
  back.root.Position=UDim2.fromOffset(g.backHit.x,g.backHit.y)
  if api.squiggle then api.squiggle.update()end
  return g
 end
 -- options.tint: a Kit.Tint key or Color3 (T5). Dot + eyebrow and the squiggle.
 if options.tint then
  api.tint=tintColor(options.tint)
  api.dot=Kit.tintEyebrow(api.eyebrow,api.tint)
  api.squiggle=Kit.squiggle(holder,api.title,api.tint)
  holder:SetAttribute("Tint",api.tint and api.tint:ToHex())
 end
 api.wallet=if inner then{root=inner.root,amount=inner.amount,height=inner.height,set=function(value)inner.set(value);api.layout()end}else nil
 function api.setTitle(text,eyebrow)
  api.title.Text=text or "";if eyebrow~=nil then api.eyebrow.Text=string.upper(eyebrow)end
  api.layout()
 end
 if options.onBack then back.root.Activated:Connect(options.onBack)end
 holder:SetAttribute("HeaderCompact",compact)
 api.layout()
 return api
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
-- Insets for a gui that follows the compact rule. Measure the DeviceSafeInsets
-- probe, never the gui itself: its own size changes with the insets chosen here,
-- so near the breakpoint it would flip Device/CoreUI on every size change.
function Kit.compactInsets(probeSize)
 return if probeSize.X>0 and Kit.compactRule(probeSize.X,probeSize.Y)then Enum.ScreenInsets.DeviceSafeInsets else Enum.ScreenInsets.CoreUISafeInsets
end

-- Modal shades (QA 2026-11-13 Q2.1). Every menu screen lives in an inset ScreenGui,
-- so a 1x1-scale shade stopped under the Roblox top bar, and a screen opened over
-- another drew a second shade on top of the first. A shade now covers the whole
-- screen (measured from a ScreenInsets.None probe) and only the top open shade dims;
-- the screens under it go clear and, when they ask, hide their panel until uncovered.
Kit.ShadeAlpha=.35
local probeFrame
function Kit.screenProbe(anchor)
 if probeFrame and probeFrame.Parent and probeFrame.Parent.Parent then return probeFrame end
 local gui=anchor and anchor:FindFirstAncestorOfClass("ScreenGui")
 local holder=gui and gui.Parent
 if not holder then return nil end
 local probeGui=holder:FindFirstChild("EggDropScreenProbe")
 if not probeGui then probeGui=node("ScreenGui",holder,{Name="EggDropScreenProbe",ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.None,DisplayOrder=0,Enabled=true})end
 probeFrame=probeGui:FindFirstChild("Screen")or node("Frame",probeGui,{Name="Screen",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false})
 return probeFrame
end
-- Pure: the offset rect (relative to `parentPosition`) that covers the probed screen.
function Kit.coverRect(screenPosition,screenSize,parentPosition)
 local origin=screenPosition-parentPosition
 return UDim2.fromOffset(math.floor(origin.X),math.floor(origin.Y)),UDim2.fromOffset(math.ceil(screenSize.X)+1,math.ceil(screenSize.Y)+1)
end
-- Keeps `frame` covering the whole screen whatever insets its ScreenGui uses.
function Kit.coverScreen(frame)
 local probe=Kit.screenProbe(frame)
 if not probe then frame.Position=UDim2.new();frame.Size=UDim2.fromScale(1,1);return false end
 local function sync()
  local parent=frame.Parent
  if not parent or not parent:IsA("GuiBase2d")then return end
  local position,size=Kit.coverRect(probe.AbsolutePosition,probe.AbsoluteSize,parent.AbsolutePosition)
  if frame.Position~=position then frame.Position=position end
  if frame.Size~=size then frame.Size=size end
 end
 local links={}
 local function watch(signal)table.insert(links,signal:Connect(sync))end
 watch(probe:GetPropertyChangedSignal("AbsoluteSize"));watch(probe:GetPropertyChangedSignal("AbsolutePosition"))
 local parent=frame.Parent
 if parent and parent:IsA("GuiBase2d")then watch(parent:GetPropertyChangedSignal("AbsolutePosition"))end
 watch(frame:GetPropertyChangedSignal("Visible"))
 frame.Destroying:Connect(function()for _,link in ipairs(links)do link:Disconnect()end end)
 frame:SetAttribute("CoversScreen",true)
 sync();return true
end
-- A black full-screen shade, hidden until Kit.shadeOpen.
function Kit.modalShade(host,name,zIndex)
 local shade=Kit.frame(host,name,nil,UDim2.new(),UDim2.fromScale(1,1))
 shade.BackgroundTransparency=Kit.ShadeAlpha;shade.BackgroundColor3=Color3.new(0,0,0);shade.Active=true;shade.Visible=false
 shade.ZIndex=zIndex or 30;shade:SetAttribute("ShadeAlpha",Kit.ShadeAlpha)
 Kit.coverScreen(shade)
 return shade
end
local shadeStack={}
local function paintShades()
 for i=#shadeStack,1,-1 do
  local entry=shadeStack[i]
  if not entry.shade.Parent then table.remove(shadeStack,i)end
 end
 for i,entry in ipairs(shadeStack)do
  local top=i==#shadeStack
  local alpha=entry.shade:GetAttribute("ShadeAlpha")or Kit.ShadeAlpha
  entry.shade.BackgroundTransparency=if top then alpha else 1
  entry.shade:SetAttribute("ShadeCovered",not top)
  if entry.covered~=(not top)then
   local first=entry.covered==nil
   entry.covered=not top
   if entry.onCovered and not(first and top)then task.spawn(entry.onCovered,not top)end
  end
 end
end
-- owner: any key (the screen object). onCovered(covered) runs when a later shade
-- opens over this one (true) and when it closes again (false).
-- Opening again while already open keeps the owner's place in the stack (a rebuilt
-- shade frame swaps in), so a refresh under a child screen never jumps above it.
function Kit.shadeOpen(owner,shade,onCovered)
 local entry
 for _,e in ipairs(shadeStack)do if e.owner==owner then entry=e end end
 if entry then
  if entry.shade~=shade and entry.shade.Parent then entry.shade.Visible=false end
  entry.shade=shade;entry.onCovered=onCovered or entry.onCovered
 else table.insert(shadeStack,{owner=owner,shade=shade,onCovered=onCovered})end
 shade.Visible=true;paintShades()
end
function Kit.shadeIsOpen(owner)
 for _,e in ipairs(shadeStack)do if e.owner==owner then return true end end
 return false
end
function Kit.shadeClose(owner)
 local found=false
 for i=#shadeStack,1,-1 do
  local entry=shadeStack[i]
  if entry.owner==owner then table.remove(shadeStack,i);found=true
   if entry.shade.Parent then entry.shade.Visible=false;entry.shade.BackgroundTransparency=entry.shade:GetAttribute("ShadeAlpha")or Kit.ShadeAlpha end
  end
 end
 if found then paintShades()end
 return found
end
function Kit.setShadeAlpha(shade,alpha)shade:SetAttribute("ShadeAlpha",alpha);paintShades()end
function Kit.shadeDepth()paintShades();return #shadeStack end
function Kit.shadeTop()local entry=shadeStack[#shadeStack];return entry and entry.owner,entry and entry.shade end
-- How many open shades currently dim the screen (always 0 or 1).
function Kit.dimmingShades()
 local n=0
 for _,entry in ipairs(shadeStack)do if entry.shade.Parent and entry.shade.Visible and entry.shade.BackgroundTransparency<1 then n+=1 end end
 return n
end

-- Screen slide (QA Q2.2): the Pets page move, shared. Every GuiObject child of
-- `container` (except those `skip(child)` keeps) starts `from` px to the side and
-- eases home in Kit.Motion.screen. Reduced Motion is a cut. A slide that starts
-- while another is still running finishes from the first one's goal.
Kit.SlideOffset=24
local slides=setmetatable({},{__mode="k"})
function Kit.slideIn(container,from,skip)
 if not container or from==0 then return 0 end
 local count=0
 for _,child in ipairs(container:GetChildren())do
  if child:IsA("GuiObject")and not(skip and skip(child))then
   local live=slides[child];local goal=child.Position
   if live then slides[child]=nil;live.tween:Cancel();goal=live.goal;child.Position=goal end
   if not Kit.reduced()then
    child.Position=goal+UDim2.fromOffset(from,0)
    local tween=TweenService:Create(child,TweenInfo.new(Kit.Motion.screen,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=goal})
    slides[child]={tween=tween,goal=goal}
    tween.Completed:Connect(function()if slides[child]and slides[child].tween==tween then slides[child]=nil end end)
    tween:Play();count+=1
   end
  end
 end
 return count
end
-- The header stays put while a page slides (as on the Pets page).
function Kit.headerSkip(header)
 return function(child)return(header~=nil and child==header.root)or child.Name=="HeaderHairline"end
end
return Kit
