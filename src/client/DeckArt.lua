local Stars=require(script.Parent.StarText)
local Art = {}

-- Stable default constants. Confirmed interface palettes are resolved only by
-- explicit semantic bindings; species, status and hardware identity stay stable.
-- Deck glass type (UI-SPEC-2026-11-12 2.2): Builder Sans for words, Roboto Mono for
-- anything that ticks, everywhere. DeckKit holds the full role table.
Art.Type = { Reward = 32, Heading = 26, Action = 20, Body = 16, Supporting = 14, Counter = 18, Compact = 14 }
Art.Font = { Reward=Enum.Font.BuilderSansExtraBold, Heading=Enum.Font.BuilderSansBold, Action=Enum.Font.BuilderSansBold, Body=Enum.Font.BuilderSans, Supporting=Enum.Font.BuilderSans, Counter=Enum.Font.RobotoMono }
Art.Space = { Small = 4, Related = 8, Group = 12, Panel = 20 }
-- Sheets (anything inside an Art.panel content surface) use a clean modern sans.
-- The handheld keeps its playful faces outside those surfaces.
Art.SheetFont = { Reward=Enum.Font.BuilderSansExtraBold, Heading=Enum.Font.BuilderSansBold, Action=Enum.Font.BuilderSansBold, Body=Enum.Font.BuilderSans, Supporting=Enum.Font.BuilderSans, Counter=Enum.Font.RobotoMono }
-- Frosted sheet glass: share of the scene that shows through a sheet panel.
Art.SheetGlass = 0.14
for name, hex in pairs({
	Backdrop = "#123C35", Ink = "#201D32", Surface = "#123C35", Raised = "#234A43", Inset = "#0F322C",
	Line = "#69F4B3", Silver = "#FFF6E4", Muted = "#E0DCE8", Amber = "#FFC14D",
	Leaf = "#A8DE78", Orange = "#FFBF50", Canopy = "#303B31", Field = "#2B332C",
	Focus = "#A3F4FF", Danger = "#FF826D", LCD = "#D2E5BB", LCDInk = "#213D37",
}) do
	Art[name] = Color3.fromHex(hex)
end
-- Existing consumers use Cyan for affirmative fills. Focus has its own role.
Art.Cyan = Art.Leaf

-- Explicit semantic bindings; no RGB inference or GUI discovery. The registry
-- owns one destroy connection per node and paints only on a confirmed theme change.
local roleNames={panel="Surface",raised="Raised",inset="Inset",ink="Ink",text="Silver",muted="Muted",line="Line",selected="Selected",focus="Focus",accent="Accent",reward="Amber"}
Art.Selected,Art.Accent=Art.Inset,Color3.fromHex("#76F6B0")
local bindings={};local currentTheme;local paletteStats={nodes=0,applies=0,writes=0}
-- Batch 2026-11-13 (Spencer): the Pocket Deck faceplate tints only the deck and its
-- background. Menus, cards, tabs and buttons always use the house palette (the
-- default plate's glass); `currentTheme` stays for the hardware readers (getTheme).
local Themes=require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
local uiTheme=Themes.ById[Themes.Default]
function Art.uiTheme()return uiTheme end
function Art.paletteColor(role)return (uiTheme.ui and uiTheme.ui[role])or Art[roleNames[role]or role]end
local contentDefaults={contentPanel=Color3.fromHex("#16201E"),contentRaised=Color3.fromHex("#232D2C"),contentInset=Color3.fromHex("#0C1311"),contentText=Color3.fromHex("#F3F4F6"),contentMuted=Color3.fromHex("#C3C8D0"),contentLine=Color3.fromHex("#69F4B3"),contentSelected=Color3.fromHex("#3A5249"),contentFocus=Color3.fromHex("#A3F4FF"),contentReward=Color3.fromHex("#FFC14D")}
local scoped={panel="contentPanel",raised="contentRaised",inset="contentInset",text="contentText",muted="contentMuted",line="contentLine",selected="contentSelected",focus="contentFocus",reward="contentReward"}
local function contentOwner(object)
 local n=object
 while n do if n:GetAttribute("ContentSurface")==true then return true end;n=n.Parent end
 return false
end
-- Copy sitting on a filled primary control (a selected card, the main action)
-- reads in ink, like the control's own label, whatever surface it lives on.
local function onPrimaryFill(object)
 local n=object.Parent
 while n and not n:IsA("LayerCollector")do
  if n:IsA("GuiButton")then return n:GetAttribute("PrimaryAction")==true and n:GetAttribute("ActionEnabled")==true end
  n=n.Parent
 end
 return false
end
function Art.surfaceColor(object,role)
 if(role=="text"or role=="muted")and onPrimaryFill(object)then return Art.paletteColor("ink")end
 local mapped=contentOwner(object)and scoped[role]
 return if mapped then uiTheme.ui[mapped]or contentDefaults[mapped]else Art.paletteColor(role)
end
local function paintBinding(node,entry)
 for property,role in pairs(entry.properties)do
  local value=if type(role)=="function"then role()else Art.surfaceColor(node,role)
  if node[property]~=value then node[property]=value;paletteStats.writes+=1 end
 end
end
function Art.bind(object,properties)
 local entry=bindings[object]
 if not entry then
  entry={properties={}};bindings[object]=entry;paletteStats.nodes+=1
  entry.connection=object.Destroying:Connect(function()if bindings[object]then bindings[object]=nil;paletteStats.nodes-=1;entry.connection:Disconnect()end end)
 end
 for property,role in pairs(properties)do entry.properties[property]=role end
 paintBinding(object,entry)
 if Art.surfaceGradient and type(properties.BackgroundColor3)=="string"then Art.surfaceGradient(object,properties.BackgroundColor3)end
 return object
end
function Art.themeStats()return table.clone(paletteStats)end
function Art.getTheme()return currentTheme end
function Art.applyTheme(theme)
 if currentTheme==theme then return false end
 currentTheme=theme
 paletteStats.applies+=1;paletteStats.writes=0
 for object,entry in pairs(bindings)do paintBinding(object,entry)end
 return true
end

local function node(class, parent, properties)
	local object = Instance.new(class)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

function Art.corner(parent, radius)
	local curve = parent:FindFirstChildOfClass("UICorner") or node("UICorner", parent, {})
	curve.CornerRadius = UDim.new(0, radius)
	return curve
end

function Art.stroke(parent,color,transparency,thickness)
 local stroke=node("UIStroke",parent,{ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Color=if type(color)=="string"then Art.paletteColor(color)else color,Thickness=thickness or 1,Transparency=transparency or 0})
 if type(color)=="string"then Art.bind(stroke,{Color=color})end;return stroke
end

function Art.shade(parent, top, bottom)
	local gradient = parent:FindFirstChildOfClass("UIGradient") or node("UIGradient", parent, {})
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.new(top, top, top), Color3.new(bottom, bottom, bottom))
	return gradient
end

local surfaceGradients={}
for role,stops in pairs({panel={1,.96},raised={1,.97},selected={1,.97},inset={.96,1},ink={.96,1},primary={1,.96}})do
 surfaceGradients[role]=ColorSequence.new(Color3.new(stops[1],stops[1],stops[1]),Color3.new(stops[2],stops[2],stops[2]))
end
function Art.surfaceGradient(parent,role)
 local sequence=surfaceGradients[role];if not sequence then return end
 local gradient=parent:FindFirstChildOfClass("UIGradient")or node("UIGradient",parent,{Name="SurfaceGradient"})
 local rotation=if role=="panel"then 100 else 90
 if gradient.Rotation~=rotation then gradient.Rotation=rotation end
 if gradient:GetAttribute("SurfaceRole")~=role then gradient.Color=sequence;gradient:SetAttribute("SurfaceRole",role)end
 return gradient
end
-- Explicit hardware application also serves locked previews without changing the
-- confirmed registry. Sequences are authored once by DeckThemes, never per frame.
function Art.finish(parent,theme,role)
 local gradient=parent:FindFirstChildOfClass("UIGradient")or node("UIGradient",parent,{Name="FinishGradient"})
 local sequence=if role=="face"then theme.faceGradient else theme.shellGradient
 if gradient:GetAttribute("FinishId")~=theme.name or gradient:GetAttribute("FinishRole")~=role then
  parent.BackgroundColor3=Color3.new(1,1,1);gradient.Color=sequence;gradient.Rotation=105
  gradient:SetAttribute("FinishId",theme.name);gradient:SetAttribute("FinishRole",role)
 end
 return gradient
end
-- State is explicit at the actual refresh site. Reward/status colors never enter
-- this helper, and repeated refreshes reuse its background gradient and bindings.
function Art.control(button,primary,enabled)
 primary,enabled=primary==true,enabled~=false
 if button:GetAttribute("PrimaryAction")==primary and button:GetAttribute("ActionEnabled")==enabled then return end
 button:SetAttribute("PrimaryAction",primary);button:SetAttribute("ActionEnabled",enabled)
 Art.bind(button,{BackgroundColor3=function()return if primary and enabled then Art.paletteColor("accent")else Art.surfaceColor(button,"raised")end,
  TextColor3=function()return if primary then Art.paletteColor("ink")else Art.surfaceColor(button,if enabled then "text"else "muted")end})
 Art.surfaceGradient(button,if primary and enabled then "primary"else "raised")
 -- Labels inside the control follow its fill.
 for _,child in ipairs(button:GetDescendants())do local entry=bindings[child];if entry then paintBinding(child,entry)end end
end
function Art.tab(button,selected,enabled)
 Art.control(button,false,enabled)
 Art.bind(button,{BackgroundColor3=function()local t=uiTheme.ui;return if selected then t and t.tab or Art.Accent else Art.surfaceColor(button,"raised")end,
 TextColor3=function()local t=uiTheme.ui;return if selected then t and t.tabInk or Color3.fromHex("#0E0F12") else Art.surfaceColor(button,"text")end})
 button:SetAttribute("SelectedTab",selected)

end

function Art.frame(parent,name,color,position,size,z)
 local f=node("Frame",parent,{Name=name,Position=position,Size=size,BackgroundColor3=if type(color)=="string"then Art.paletteColor(color)else color,BorderSizePixel=0,ZIndex=z or parent.ZIndex,Active=false})
 if type(color)=="string"then Art.bind(f,{BackgroundColor3=color})end;return f
end

-- Passive glass instruments share one recessed face; their children remain data,
-- never action seats or focus targets. All depth stays inside the solved rectangle.
function Art.instrument(parent)
	Art.bind(parent,{BackgroundColor3="inset"})
	parent.ClipsDescendants=true
	Art.corner(parent,8);Art.surfaceGradient(parent,"inset")
	if not parent:FindFirstChild("InsetShadow")then
		local top=Art.frame(parent,"InsetShadow",Art.Ink,UDim2.fromOffset(3,1),UDim2.new(1,-6,0,2),parent.ZIndex+1)
		top.BackgroundTransparency=.18;Art.corner(top,1)
		local lip=Art.frame(parent,"InsetLip",Art.Line,UDim2.new(0,4,1,-2),UDim2.new(1,-8,0,1),parent.ZIndex+1)
		lip.BackgroundTransparency=.65
	end
	return parent
end

function Art.text(parent,name,content,position,size,color,textSize,font)
 local f=node("TextLabel",parent,{Name=name,Text=content,Position=position,Size=size,TextColor3=if type(color)=="string"then Art.paletteColor(color)else color,TextSize=textSize,Font=font or(if contentOwner(parent)then Art.SheetFont.Body else Art.Font.Body),BackgroundTransparency=1,ZIndex=parent.ZIndex+1,Active=false})
 if type(color)=="string"then Art.bind(f,{TextColor3=color})end;return f
end

-- Opt-in for bounded button/readout text. Repeated layouts reuse the same objects.
function Art.fitText(label, maximum, minimum, padding, wrapped)
	local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
		or node("UITextSizeConstraint", label, { Name = "TextBounds" })
	limit.MaxTextSize = maximum or 16
	limit.MinTextSize = math.min(minimum or 12, limit.MaxTextSize)
	label.TextScaled = true
	label.TextWrapped = wrapped == true
	label.TextTruncate = Enum.TextTruncate.None
	local inset = label:FindFirstChildOfClass("UIPadding") or node("UIPadding", label, { Name = "TextInset" })
	local gap = padding or 6
	inset.PaddingLeft, inset.PaddingRight = UDim.new(0, gap), UDim.new(0, gap)
	inset.PaddingTop, inset.PaddingBottom = UDim.new(0, 2), UDim.new(0, 2)
	return limit
end

-- Functional text keeps a real size and preferred-text support. Layout owns wrapping.
function Art.type(label, role, compact)
	local sizes = { Reward = 26, Heading = 20, Action = 18, Body = 16, Supporting = 14, Counter = 13 }
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then constraint:Destroy() end
	local inset=label:FindFirstChildOfClass("UIPadding")
	if inset then inset.PaddingTop,inset.PaddingBottom=UDim.new(0,0),UDim.new(0,0) end
	label.TextScaled = false
	label.TextSize = if compact then (sizes[role] or 14) else (Art.Type[role] or 16)
	local faces = if contentOwner(label) then Art.SheetFont else Art.Font
	label.Font = faces[role] or faces.Body
	label:SetAttribute("TypeRole",role)
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
	return label
end

-- Roomy sheets opt into larger roles through their own measured layout.
function Art.roomyType(label,role,compact,roomy)
 Art.type(label,role,compact)
 if roomy then label.TextSize=({Heading=28,Action=22,Body=19,Supporting=18,Counter=20,Reward=32})[role]or label.TextSize end
 return label
end

-- Shared passive 22x24 silhouette. The owning 44px button retains input/focus.
function Art.carryArrow(button,direction)
 local icon=button:FindFirstChild("CarryArrow")
 if not icon then
  icon=Art.frame(button,"CarryArrow",Art.Ink,UDim2.fromScale(.5,.5),UDim2.fromOffset(22,24),button.ZIndex+2)
  icon.AnchorPoint=Vector2.new(.5,.5);icon.BackgroundTransparency=1
  -- Horizontal strips make one broad, softly stepped head without hollow chevrons.
  for row,width in ipairs({4,6,8,10,12,14,16,16})do
   local strip=Art.frame(icon,"Head"..row,"text",UDim2.fromOffset((22-width)/2,row-1),UDim2.fromOffset(width,1),icon.ZIndex)
   Art.corner(strip,1)
  end
  local stem=Art.frame(icon,"Stem","text",UDim2.fromOffset(9,7),UDim2.fromOffset(4,17),icon.ZIndex);Art.corner(stem,1)
 end
 icon.Rotation=if direction=="down"then 180 elseif direction=="back"then -90 else 0
 button.Text="";return icon
end

function Art.close(button)
	button.Name,button.Text="Close","×"
	button:SetAttribute("AccessibleLabel","Close")
	Art.type(button,"Heading",false)
	button.TextSize=26
	button.TextWrapped=false
	local inset=button:FindFirstChildOfClass("UIPadding")
	if inset then inset.PaddingLeft,inset.PaddingRight=UDim.new(0,0),UDim.new(0,0) end
	return button
end

-- Measure the native preferred-size glyph without changing authored TextSize.
-- Offset cache is bounded by preference, font face and authored role size.
local preferenceMeasurement={key=nil,entries={},lastOffset=nil}
local function measurementSize(label)
 if label.TextScaled then return label.TextSize end
 local preference=game:GetService("GuiService").PreferredTextSize.Name
 if preferenceMeasurement.key~=preference then preferenceMeasurement={key=preference,entries={},lastOffset=nil}end
 local face=label.FontFace
 local key=face.Family..":"..tostring(face.Weight)..":"..tostring(face.Style)..":"..label.TextSize
 local entry=preferenceMeasurement.entries[key]
 if entry and entry.size then return entry.size end
 local service=game:GetService("TextService");local now=os.clock()
 if not entry then entry={};preferenceMeasurement.entries[key]=entry end
 local offset=preferenceMeasurement.lastOffset or 0;local confirmed=false
 if not entry.loading and(not entry.retryAt or now>=entry.retryAt)then
  entry.loading=true
  local ok,value=pcall(function()return service:GetTextSizeOffsetAsync(label.TextSize,face)end)
  entry.loading=false
  if ok and type(value)=="number"and value==value and value>=0 and value<100 then
   offset=value;preferenceMeasurement.lastOffset=value;entry.retryAt=nil;confirmed=true
  else
   -- A transient failure uses the last known preference offset and retries on
   -- the next layout after this bounded backoff; zero is never cached as proof.
   entry.retryAt=now+1
  end
 end
 local size=label.TextSize
 if offset>0 then
  local native=service:GetTextSize("Mg",size,label.Font,Vector2.new(10000,10000)).Y
  if native<size+offset-1 then size+=offset end
 end
 if confirmed then entry.size=size end;return size
end
function Art.measureText(content,size,font,width)
 local probe={TextScaled=false,TextSize=size,Font=font,FontFace=Font.fromEnum(font)}
 return game:GetService("TextService"):GetTextSize(content,measurementSize(probe),font,Vector2.new(math.max(1,width),10000))
end
function Art.textHeight(label,width,minimum)
 local inset=label:FindFirstChildOfClass("UIPadding")
 local horizontal=if inset then inset.PaddingLeft.Offset+inset.PaddingRight.Offset+(inset.PaddingLeft.Scale+inset.PaddingRight.Scale)*width else 0
 local measured=game:GetService("TextService"):GetTextSize(label.Text,measurementSize(label),label.Font,Vector2.new(math.max(1,width-horizontal),10000))
 return math.max(minimum or 0,math.ceil(measured.Y)+4)
end
function Art.textWidth(label,content)
 return math.ceil(game:GetService("TextService"):GetTextSize(content or label.Text,measurementSize(label),label.Font,Vector2.new(10000,10000)).X)+8
end
function Art.actionHeight(label,width)return math.max(44,Art.textHeight(label,width,0)+12)end

-- Manual scrolling layouts own their child rectangles. Budget the native window,
-- optional content padding, scrollbar and selected-stroke clearance exactly once.
function Art.scrollContentRect(scroller,plannedWidth)
 local outer=math.max(1,math.floor(plannedWidth or scroller.AbsoluteSize.X))
 local actual=scroller.AbsoluteSize.X;local window=scroller.AbsoluteWindowSize.X
 -- A same-frame shell resize has not necessarily published AbsoluteWindowSize.
 local measured=actual>0 and math.abs(actual-outer)<1 and window>0
 local nativeInset=if measured then math.max(0,actual-window)else 0
 local gutter=math.max(0,scroller.ScrollBarThickness-nativeInset)
 local width=if measured then math.min(outer,window)else outer
 local padding=scroller:FindFirstChildOfClass("UIPadding")
 local left=if padding then padding.PaddingLeft.Offset+padding.PaddingLeft.Scale*outer else 0
 local right=if padding then padding.PaddingRight.Offset+padding.PaddingRight.Scale*outer else 0
 -- UIPadding shifts native child coordinates already; subtract its width here,
 -- but do not add it again to the child origin.
 local x=6
 local edge=math.floor(width-left-right-gutter-6)
 return {x=x,width=math.max(1,edge-x),right=math.max(x+1,edge),window=math.floor(width),gutter=gutter}
end

-- Cumulative boundaries distribute fractional pixels without right-edge drift.
function Art.gridCell(width,index,columns,gap)
 columns=math.max(1,columns);gap=gap or 8
 local room=math.max(columns,math.floor(width)-(columns-1)*gap)
 local first=math.floor(index*room/columns)
 local last=math.floor((index+1)*room/columns)
 return first+index*gap,math.max(1,last-first)
end

-- One invalidation listener per component; hidden sheets reflow on open.
function Art.watchTextPreference(owner,visible,reflow)
	local queued,alive=false,true
	local connection=game:GetService("GuiService"):GetPropertyChangedSignal("PreferredTextSize"):Connect(function()
		owner:SetAttribute("TextPreferenceDirty",true)
		if queued or not visible() then return end
		queued=true
		task.defer(function()
			game:GetService("RunService").Heartbeat:Wait()
			queued=false
			if alive and owner.Parent and visible() then reflow();owner:SetAttribute("TextPreferenceDirty",false) end
		end)
	end)
	owner.Destroying:Connect(function()alive=false;connection:Disconnect()end)
	return connection
end

-- Common sheet chrome keeps actual value data separate from title/status copy.
-- Widgets/connections remain owned by their sheet; this only styles and places.
function Art.bareClose(button)
	Art.close(button)
	if button:GetAttribute("BareClose")then return button end
	button:SetAttribute("BareClose",true)
	local border=button:FindFirstChildOfClass("UIStroke")
	button.BackgroundTransparency=1
	local pressed=false
	local function paint()
		local focused=game:GetService("GuiService").SelectedObject==button
		button.BackgroundTransparency=if pressed then .80 elseif focused then .94 else 1
		if border then border.Color=Art.paletteColor("focus");border.Transparency=if focused or pressed then .05 else 1 end
	end
	button.SelectionGained:Connect(paint);button.SelectionLost:Connect(function()pressed=false;paint()end)
	button.MouseButton1Down:Connect(function()pressed=true;paint()end)
	button.MouseButton1Up:Connect(function()pressed=false;paint()end)
	button.MouseLeave:Connect(function()pressed=false;paint()end)
	paint();return button
end
local function clearInset(label)
	local inset=label:FindFirstChildOfClass("UIPadding");if inset then inset:Destroy()end
end
function Art.sheetHeader(width,heading,wallet,amount,glyph,close,options)
	options=options or {};local pad=options.pad or 10;local top=options.top or 0
	Art.roomyType(heading,if options.status then "Body"else "Heading",true,options.roomy)
	Art.roomyType(amount,"Counter",true,options.roomy);clearInset(heading);clearInset(amount)
	Art.bind(amount,{TextColor3="reward"})
	amount.Text=tostring(options.amount or 0);amount.TextWrapped=false;amount.TextXAlignment=Enum.TextXAlignment.Left
	amount:SetAttribute("AccessibleLabel",Stars.amount(options.amount or 0))
	wallet.BackgroundTransparency=1
	local amountW=Art.textWidth(amount)+2;local glyphW,gap=18,4
	local walletW=glyphW+gap+amountW
	local closeX=width-pad-44
	local minimumLeft=pad+walletW+6
	local right=closeX-6
	local secondary=options.secondary;local secondaryW,secondaryH=0,44
	if secondary then Art.type(secondary,"Action",true);secondaryW=math.max(44,Art.textWidth(secondary)+12);secondaryH=Art.actionHeight(secondary,secondaryW)end
	local full,short=options.title or "",options.shortTitle or options.title or ""
	local function intrinsic(content)return Art.textWidth(heading,content)end
	local secondaryHeader=secondary and secondaryH<=44 and right-minimumLeft-secondaryW-8>=intrinsic(short)
	if secondaryHeader then right-=secondaryW+8 end
	local available=math.max(1,right-minimumLeft)
	heading.Text=if intrinsic(full)<=available then full else short
	heading:SetAttribute("AccessibleLabel",options.accessibleTitle or full)
	heading.TextWrapped=intrinsic(heading.Text)>available
	heading.TextXAlignment=Enum.TextXAlignment.Center
	local titleW=math.min(available,intrinsic(heading.Text))
	local titleH=Art.textHeight(heading,titleW,0)
	local rowH=math.max(44,titleH,Art.textHeight(amount,amountW,0))
	local titleX=math.clamp((width-titleW)/2,minimumLeft,math.max(minimumLeft,right-titleW))
	heading.Position,heading.Size=UDim2.fromOffset(titleX,top+(rowH-titleH)/2),UDim2.fromOffset(titleW,titleH)
	wallet.Position,wallet.Size=UDim2.fromOffset(pad,top),UDim2.fromOffset(walletW,rowH)
	glyph.Position,glyph.Size=UDim2.fromOffset(0,(rowH-20)/2),UDim2.fromOffset(glyphW,20);glyph.Visible=true
	amount.Position,amount.Size=UDim2.fromOffset(glyphW+gap,0),UDim2.fromOffset(amountW,rowH);amount.Visible=true
	close.Position,close.Size=UDim2.fromOffset(closeX,top+(rowH-44)/2),UDim2.fromOffset(44,44)
	if secondaryHeader then secondary.Position,secondary.Size=UDim2.fromOffset(closeX-8-secondaryW,top+(rowH-44)/2),UDim2.fromOffset(secondaryW,44)end
	return{height=top+rowH,rowHeight=rowH,secondaryHeader=secondaryHeader==true,secondaryWidth=secondaryW,secondaryHeight=secondaryH,walletWidth=walletW,titleFull=full}
end
function Art.dockTransparency(preference)return .18*math.clamp(preference,0,1)end
-- Glass and see-through floors scale by the player's Reduce transparency setting
-- (GuiService.PreferredTransparency: 1 default, 0 fully opaque).
function Art.glassTransparency(base)return base*math.clamp(game:GetService("GuiService").PreferredTransparency,0,1)end
function Art.dockCircle(button,kind)
	button.Text=if kind=="menu"then "Menu"else "Open deck";button.TextTransparency=1;Art.bind(button,{BackgroundColor3="panel"});Art.corner(button,24)
	button:SetAttribute("AccessibleLabel",if kind=="menu"then "Menu"else "Deck")
	local glyph=Art.frame(button,"DockGlyph","text",UDim2.new(.5,-12,.5,-12),UDim2.fromOffset(24,24),button.ZIndex+1);glyph.BackgroundTransparency=1
	if kind=="menu"then
		for index=0,2 do local bar=Art.frame(glyph,"Bar","text",UDim2.fromOffset(2,4+index*7),UDim2.fromOffset(20,2),glyph.ZIndex);Art.corner(bar,1)end
	else
		local deck=Art.frame(glyph,"Handheld","text",UDim2.fromOffset(0,4),UDim2.fromOffset(24,16),glyph.ZIndex);deck.BackgroundTransparency=1;Art.corner(deck,4);Art.stroke(deck,"text",0,1)
		local screen=Art.frame(deck,"Screen",Art.LCD,UDim2.fromOffset(8,3),UDim2.fromOffset(8,10),deck.ZIndex);Art.corner(screen,1)
		Art.frame(deck,"Rocker","text",UDim2.fromOffset(3,7),UDim2.fromOffset(3,3),deck.ZIndex)
		Art.corner(Art.frame(deck,"A","text",UDim2.fromOffset(19,7),UDim2.fromOffset(3,3),deck.ZIndex),2)
	end
	return button
end

function Art.leaf(parent, name, position, size, tint, rotation, z)
	local leaf = Art.frame(parent, name, tint, position, size, z)
	Art.corner(leaf, 1000)
	leaf.Rotation = rotation or 0
	local vein = Art.frame(leaf, "Vein", Art.Ink, UDim2.new(0.5, -1, 0.18, 0), UDim2.new(0, 2, 0.64, 0))
	vein.BackgroundTransparency = 0.8
	Art.corner(vein, 1)
	return leaf
end

local PatternBackdrop=require(script.Parent.DeckBackdrop)
local previewBackground
local previewLeases=setmetatable({},{__mode="k"})
local backdropMotion=setmetatable({},{__mode="k"})
local function canopyOwner(motion,home,owner)
 if not motion.art or not motion.art.Parent or not owner.Parent then return end
 if motion.art.Parent~=owner then motion.art.Parent=owner end
 if motion.layerOwner==owner and motion.layerOwnerZ==owner.ZIndex then return end
 motion.layerOwner,motion.layerOwnerZ=owner,owner.ZIndex
 local base=owner.ZIndex+(if owner==home then motion.homeOffset else 1)
 for _,entry in ipairs(motion.layers)do local z=base+entry.offset;if entry.node.ZIndex~=z then entry.node.ZIndex=z end end
end
Art.BackdropPeriod=12
local function buildCanopy(parent,motion)
 local art=Art.frame(parent,"CanopyArt",Art.Backdrop,UDim2.fromScale(0,0),UDim2.fromScale(1,1));art.BackgroundTransparency=1
 if motion.owner and motion.owner.Parent then motion.phases[motion.owner]=motion.elapsed end
 motion.art,motion.entries,motion.layers=art,{},{}
 motion.homeOffset=art.ZIndex-parent.ZIndex;motion.layerOwner=nil;motion.layerOwnerZ=nil
 motion.owner=nil;motion.lastTime=nil;motion.lastTint=nil;motion.bucket=nil;motion.resting=true
	-- Broad silhouettes read as an outdoor setting, even around a small phone deck.
	for index, data in ipairs({
		{ -0.18, -0.38, 0.65, 0.78, Art.Canopy },
		{ 0.66, -0.30, 0.54, 0.72, Art.Canopy },
		{ -0.18, 0.67, 0.67, 0.70, Art.Field },
		{ 0.45, 0.78, 0.77, 0.52, Art.Field },
	}) do
		local shape = Art.frame(art, "Canopy" .. index, data[5], UDim2.fromScale(data[1], data[2]),
			UDim2.fromScale(data[3], data[4]))
		local corner = Art.corner(shape, 1)
		corner.CornerRadius = UDim.new(0.5, 0)
	end
	for index, data in ipairs({ {0.04, 0.38, -28}, {0.93, 0.53, 32}, {0.10, 0.85, 38}, {0.87, 0.08, -35} }) do
		local leaf = Art.leaf(art, "Leaf" .. index, UDim2.fromScale(data[1], data[2]),
			UDim2.fromOffset(18, 36), Art.Line, data[3])
		leaf.BackgroundTransparency = 0.5
		table.insert(motion.entries,{node=leaf,position=leaf.Position,rotation=leaf.Rotation,phase=index*math.pi/2,x=3,y=4})
	end
	for index, data in ipairs({{0.03, 0.18}, {0.19, 0.92}, {0.95, 0.83}, {0.78, 0.06}}) do
		local seed = Art.frame(art, "Seed" .. index, Art.Leaf, UDim2.fromScale(data[1], data[2]), UDim2.fromOffset(4, 4))
		Art.corner(seed, 2)
		seed.BackgroundTransparency = 0.35
		table.insert(motion.entries,{node=seed,position=seed.Position,rotation=seed.Rotation,phase=index*math.pi/2+.4,x=4,y=3})
	end
 motion.layers[1]={node=art,offset=0}
 for _,node in ipairs(art:GetDescendants())do if node:IsA("GuiObject")then table.insert(motion.layers,{node=node,offset=node.ZIndex-art.ZIndex})end end
end
function Art.backdrop(parent)
 if backdropMotion[parent]then return end
 -- Every exterior pixel, tint and underlay is flattened exactly once. BoardBacking
 -- itself is transparent so the see-through share really comes from the garden.
 parent.BackgroundTransparency=1;parent.ClipsDescendants=true
 local host=node("CanvasGroup",parent,{Name="ExteriorComposite",Size=UDim2.fromScale(1,1),BackgroundColor3=Art.Backdrop,BackgroundTransparency=Art.glassTransparency(1-PatternBackdrop.ExteriorOpacity),BorderSizePixel=0,GroupTransparency=0,ZIndex=parent.ZIndex,Active=false,Selectable=false})
 Art.shade(host,1,.76)
 local motion={host=host,entries={},layers={},resting=true,elapsed=0,phases=setmetatable({},{__mode="k"}),confirmed="canopy"}
 backdropMotion[parent]=motion;buildCanopy(host,motion)
 parent.Destroying:Connect(function()
  motion.destroyed=true;backdropMotion[parent]=nil
  if motion.surface then motion.surface:destroy()end
  if motion.art and motion.art.Parent then motion.art:Destroy()end
 end)
end

-- The existing board render clock calls this once. No new connection, GUI walk,
-- tween, or allocation runs per frame; hidden/reduced presentation rests at base.
function Art.backgroundThumbnail(host,id,theme)return PatternBackdrop.thumbnail(host,id,theme)end
function Art.backdropStats(parent)local m=backdropMotion[parent];return m and m.surface and not m.surface.destroyed and m.surface.root.Parent and m.surface.stats end
function Art.setBackdropCase(parent,rect)
 local motion=backdropMotion[parent];if not motion then return end
 -- QA v2 R6.1: the phone draws the whole handheld with the background around it
 -- (as on desktop), so the exterior pattern draws on every device now. `compact`
 -- stays false (it used to skip the pattern under the old full-root phone plate).
 motion.compact=false
 motion.case=rect;if motion.surface then motion.surface:setCase(rect)end
end
-- The confirmed background also feeds every registered in-board pattern layer.
local boardPatterns=setmetatable({},{__mode="k"})
local boardBackground
function Art.setBackground(parent,id,theme)
 if not boardBackground or boardBackground.id~=id or boardBackground.theme~=theme then boardBackground={id=id,theme=theme}end
 for _,pattern in pairs(boardPatterns)do if not pattern.destroyed then pattern:configure(id,theme);pattern:setVisible(true)end end
 local motion=backdropMotion[parent];if not motion then return end
 motion.confirmed,motion.theme=id,theme
end
-- Register the board well (the tray overlay) once; returns the pattern root.
-- The layer is drawn on every device, under the fill line and the danger haze.
function Art.boardPattern(host)
 local pattern=boardPatterns[host]
 if not pattern or pattern.destroyed then
  pattern=PatternBackdrop.board(host);boardPatterns[host]=pattern
  if boardBackground then pattern:configure(boardBackground.id,boardBackground.theme);pattern:setVisible(true)end
 end
 return pattern.root
end
-- Global ZIndex depth of the board pattern (it must stay below the gel layer).
function Art.setBoardPatternDepth(host,z)
 local pattern=boardPatterns[host];if pattern and not pattern.destroyed then pattern:setZIndex(z)end
end
function Art.boardPatternStats(host)
 local pattern=boardPatterns[host];return pattern and not pattern.destroyed and pattern.stats or nil
end
local function returnPreview(host)
 -- This is a cached-owner registry, visited only on an explicit handoff. Return
 -- before callers can destroy a temporary page under deferred signal delivery.
 for parent,motion in pairs(backdropMotion)do
  if not motion.destroyed and parent:IsDescendantOf(game)then
   if motion.art and motion.art.Parent==host then canopyOwner(motion,motion.host,motion.host);motion.art.Visible=false end
   if motion.surface and not motion.surface.destroyed and motion.surface.root.Parent==host then motion.surface:releaseOwner(host)end
  end
 end
end
local function releasePreview(host)
 if not previewLeases[host]then return end
 previewLeases[host]=nil;returnPreview(host)
end
function Art.isBackgroundPreviewVisible(host)return previewBackground~=nil and previewBackground.host==host and host.Parent~=nil end
function Art.setBackgroundPreview(host,id,theme,active)
 if not active or not host.Parent then
  if previewBackground and previewBackground.host==host then previewBackground=nil end
  releasePreview(host);return
 end
 if previewBackground and previewBackground.host~=host then releasePreview(previewBackground.host)end
 if not host:GetAttribute("BackgroundPreviewOwner")then
  host:SetAttribute("BackgroundPreviewOwner",true)
  host.Destroying:Connect(function()
   if previewBackground and previewBackground.host==host then previewBackground=nil end
   -- Deferred destruction can already have removed children. Never reparent a
   -- dead root here; the next visible request repairs only a missing renderer.
   releasePreview(host)
  end)
 end
 previewLeases[host]=true;previewBackground={host=host,id=id,theme=theme}
end

function Art.updateBackdrop(parent,now,visible,reduced,previewAllowed)
	local motion=backdropMotion[parent]
	if not motion or motion.destroyed or not parent:IsDescendantOf(game)then return end
 local preview=previewBackground and previewBackground.host.Parent and previewBackground.host.Visible and previewAllowed~=false
 local owner=if preview then previewBackground.host else motion.host
 local id=if preview then previewBackground.id else motion.confirmed
 local theme=if preview then previewBackground.theme else motion.theme
 if motion.compact and not preview then visible=false end
 local wanted=preview or visible
 local canopyAlive=motion.art and motion.art.Parent~=nil
 local surfaceAlive=motion.surface and not motion.surface.destroyed and motion.surface.root.Parent~=nil
 if wanted then
  if motion.surface and not surfaceAlive then motion.surface:destroy();motion.surface=nil end
  if id=="canopy"and not canopyAlive then buildCanopy(motion.host,motion);canopyAlive=true end
 end
 if not wanted and not canopyAlive then if surfaceAlive then motion.surface:update(motion.host,now,false,reduced)end;return end
 if theme then
  if not wanted and not surfaceAlive then return end
  if canopyAlive then if motion.art.Visible then motion.art.Visible=false end;canopyOwner(motion,motion.host,motion.host)end
  if not motion.surface then if not wanted then return end;motion.surface=PatternBackdrop.new(motion.host,{exterior=true})end
  -- The themed surface owns the see-through floor; the host fill would double it.
  if motion.host.BackgroundTransparency~=1 then motion.host.BackgroundTransparency=1 end
  motion.surface:configure(id,theme);if motion.case then motion.surface:setCase(motion.case)end;motion.surface:update(owner,now,preview or visible,reduced)
  motion.lastTime=nil;return
 end
 if surfaceAlive then motion.surface:update(motion.host,now,false,reduced)end
 -- Back on the canopy: the host fill is the see-through floor again (the themed
 -- path cleared it so it would not double its own floor).
 local floor=Art.glassTransparency(1-PatternBackdrop.ExteriorOpacity)
 if motion.host.BackgroundTransparency~=floor then motion.host.BackgroundTransparency=floor end
 if motion.compact and not preview then if motion.art.Visible then motion.art.Visible=false end;return end
 canopyOwner(motion,motion.host,owner);if not motion.art.Visible then motion.art.Visible=true end
 visible=preview or visible
 if motion.owner~=owner then
  if motion.owner then motion.phases[motion.owner]=motion.elapsed end
  motion.owner=owner;motion.elapsed=motion.phases[owner]or 0;motion.lastTime=nil;motion.bucket=nil;motion.resting=false
 end
 if theme and motion.lastTint~=theme then
  for _,node in ipairs(motion.art:GetChildren())do if node:IsA("Frame")then node.BackgroundColor3=if node.Name:find("Canopy")then theme.band else theme.trim end end
  motion.lastTint=theme
 end
 if not visible or reduced then
		if not motion.resting then
			for _,entry in ipairs(motion.entries)do entry.node.Position=entry.position;entry.node.Rotation=entry.rotation end
			motion.resting=true
		end
		motion.lastTime=nil
		return
	end
	motion.elapsed=(motion.elapsed+(if motion.lastTime then math.max(0,now-motion.lastTime)else 0))%Art.BackdropPeriod
	motion.lastTime=now;if motion.resting then motion.bucket=nil end;motion.resting=false
 local bucket=math.floor(motion.elapsed*15+1e-6);if motion.bucket==bucket then return end;motion.bucket=bucket
	-- Paint the sampled bucket, not its unsampled fractional tail. Returning
 -- from a hidden/static base pose restores exactly the last displayed phase.
 local phase=(bucket/15)/Art.BackdropPeriod*math.pi*2
	for _,entry in ipairs(motion.entries)do
		entry.node.Position=entry.position+UDim2.fromOffset(math.sin(phase+entry.phase)*entry.x,math.sin(phase*2+entry.phase)*entry.y)
		entry.node.Rotation=entry.rotation+math.sin(phase+entry.phase)*2
	end
end

function Art.pixels(parent, name, rows, colors, unit, position, z)
	local sprite = Art.frame(parent, name, Art.Ink, position,
		UDim2.fromOffset(#rows[1] * unit, #rows * unit), z)
	sprite.BackgroundTransparency = 1
	for y, row in ipairs(rows) do
		local start = 1
		while start <= #row do
			local symbol = row:sub(start, start)
			local stop = start + 1
			while row:sub(stop, stop) == symbol do
				stop += 1
			end
			if colors[symbol] then
				Art.frame(sprite, "Pixel", colors[symbol], UDim2.fromOffset((start - 1) * unit, (y - 1) * unit),
					UDim2.fromOffset((stop - start) * unit, unit))
			end
			start = stop
		end
	end
	return sprite
end

local eggMark = { "..X..", ".....", "..X..", ".....", "..X..", ".X.X.", "X...X", "X..XX", ".XXX." }

function Art.insignia(parent, unit, position, tint, z)
	return Art.pixels(parent, "DropMark", eggMark, { X = tint }, unit, position, z)
end

-- Panels follow a live change to Reduce transparency through one shared connection.
local glassPanels = setmetatable({}, { __mode = "k" })
game:GetService("GuiService"):GetPropertyChangedSignal("PreferredTransparency"):Connect(function()
	for panel in pairs(glassPanels) do
		if panel.Parent then panel.BackgroundTransparency = Art.glassTransparency(Art.SheetGlass) end
	end
end)
-- Dark frosted glass: a slightly see-through graphite sheet, one thin light edge.
function Art.panel(parent, radius, accent)
 parent:SetAttribute("ContentSurface",true)
	Art.bind(parent,{BackgroundColor3="panel"})
	parent.BackgroundTransparency = Art.glassTransparency(Art.SheetGlass)
	glassPanels[parent] = true
	Art.corner(parent, radius)
	Art.surfaceGradient(parent,"panel")
	-- One 1 px white 14% border (UI-SPEC 2.3).
	Art.stroke(parent,Color3.new(1,1,1),0.86,1)

end

function Art.button(button, radius)
	button.AutoButtonColor = false
	Art.corner(button, radius)
	local border = Art.stroke(button,"line",0.22)
 Art.surfaceGradient(button,"raised")
 local keyline=Art.frame(button,"FocusKeyline",Art.Ink,UDim2.fromOffset(2,2),UDim2.new(1,-4,1,-4),button.ZIndex)
 keyline.BackgroundTransparency=1;keyline.Active,keyline.Selectable=false,false;Art.corner(keyline,math.max(1,radius-2))
 local inner=Art.stroke(keyline,"ink",1,1)
 border.Transparency=.86
 Art.bind(border,{Color=function()return if button==game:GetService("GuiService").SelectedObject then Art.surfaceColor(button,"focus")else Color3.new(1,1,1) end})
	button.MouseButton1Down:Connect(function()
		if button.Interactable then
			border.Color = Art.surfaceColor(button,"focus")
   border.Thickness=button:GetAttribute("FocusThickness")or 2.5;border.Transparency=0;inner.Transparency=0
		end
	end)
	local function focusPaint(focused)
  -- Focus: the 2.5 px white ring; rest: the 1 px white 14% border.
  border.Thickness=if focused then button:GetAttribute("FocusThickness")or 2.5 else 1;inner.Transparency=if focused then 0 else 1
		border.Transparency=if focused then 0 else .86
		border.Color = if focused then Art.surfaceColor(button,"focus")else Color3.new(1,1,1)
	end
	local function restore()focusPaint(button==game:GetService("GuiService").SelectedObject)end
 button.MouseButton1Up:Connect(restore)
 button.MouseLeave:Connect(restore)
 -- Selection events can run before SelectedObject publishes its next value.
 -- Their event intent is authoritative for this button's paired strokes.
 button.SelectionGained:Connect(function()focusPaint(true)end)
 button.SelectionLost:Connect(function()focusPaint(false)end)
 button:GetPropertyChangedSignal("Interactable"):Connect(function()
  local primary=button:GetAttribute("PrimaryAction")
  if primary~=nil then Art.control(button,primary,button.Interactable)end
 end)
	return border
end

local previewGel=setmetatable({},{__mode="k"});local previewGradients={}
function Art.jellyPreview(parent,tier,mark)
 local palette=require(game:GetService("ReplicatedStorage").Shared.JellyPalette).byTier[tier]
 local state=previewGel[parent]
 if not state then
  -- No outline any more (UI-SPEC-REDESIGN-MENUS 6.1): the stroke stays for
  -- existing readers but is fully transparent.
  state={gradient=parent:FindFirstChildOfClass("UIGradient")or node("UIGradient",parent,{}),rim=Art.stroke(parent,palette.deep,0,1),glint=Art.frame(parent,"GelGlint",palette.glint,UDim2.fromScale(.18,.13),UDim2.fromScale(.22,.085),parent.ZIndex+1)}
  state.rim.Transparency=1
  Art.corner(state.glint,100);previewGel[parent]=state
  parent.Destroying:Connect(function()previewGel[parent]=nil end)
 end
 if state.tier==tier then return end;state.tier=tier
 -- Same ramp as the board sprites: light upper-left, body, deep lower-right.
 if not previewGradients[tier]then previewGradients[tier]=ColorSequence.new({ColorSequenceKeypoint.new(0,palette.light),ColorSequenceKeypoint.new(.45,palette.body),ColorSequenceKeypoint.new(1,palette.deep)})end
 parent.BackgroundColor3=Color3.new(1,1,1);state.gradient.Color=previewGradients[tier];state.gradient.Rotation=55
 state.rim.Color=palette.deep;state.glint.BackgroundColor3=palette.glint;parent:SetAttribute("JellyTier",tier)
 -- No tier numerals any more (batch 2026-11-13 R1): an old mark label is hidden.
 if mark then mark.Visible=false end
end

function Art.wordmark(parent,z)return require(script.Parent.DeckWordmark).new(parent,z or parent.ZIndex+1,Art)end

function Art.deck(backdrop, shell, bezel)
	Art.backdrop(backdrop)
	-- Authored finish is applied by paintDeck after confirmed appearance resolves.
	Art.shade(bezel, 1, 0.9)
	local seam = Art.frame(shell, "MoldSeam", Art.Ink, UDim2.fromOffset(5, 5), UDim2.new(1, -10, 1, -10))
	seam.BackgroundTransparency = 1
	local seamCurve = Art.corner(seam, 13)
	local shellCurve = shell:FindFirstChildOfClass("UICorner")
	if shellCurve then
		local function followCurve()
			seamCurve.CornerRadius = UDim.new(0, math.max(1, shellCurve.CornerRadius.Offset - 5))
		end
		followCurve()
		shellCurve:GetPropertyChangedSignal("CornerRadius"):Connect(followCurve)
	end
	Art.stroke(seam, Art.Ink, 0.58)
	for _, side in ipairs({ 0, 1 }) do
		local screw = Art.frame(shell, "Screw", Art.Ink,
			UDim2.new(side, if side == 0 then 15 else -23, 1, -22), UDim2.fromOffset(8, 8))
		Art.corner(screw, 4)
		Art.stroke(screw, Art.Line)
		Art.frame(screw, "Slot", Art.Line, UDim2.fromOffset(2, 3), UDim2.fromOffset(4, 1)).Rotation = -28
	end
	Art.leaf(shell, "SproutLeaf", UDim2.fromOffset(16, 10), UDim2.fromOffset(7, 12), Art.Leaf, -35, shell.ZIndex + 1)
	Art.insignia(shell, 2, UDim2.fromOffset(28, 7), Art.Ink, shell.ZIndex + 1)
	local glint = Art.frame(bezel, "LensGlint", Art.Silver,
		UDim2.new(0, 14, 0, 2), UDim2.new(1, -28, 0, 1))
	glint.BackgroundTransparency = 0.65
end

function Art.tintBackdrop(parent,theme)
	local motion=backdropMotion[parent]
 local floor=if motion then motion.host else parent
 floor.BackgroundColor3=theme.backdrop or Art.Backdrop
	local art=motion and motion.art or parent:FindFirstChild("CanopyArt")
	if not art then return end
	for _,node in ipairs(art:GetChildren())do
		if node:IsA("Frame")then
			if node.Name:find("Canopy")then node.BackgroundColor3=theme.band or Art.Canopy
			else node.BackgroundColor3=theme.trim or Art.Leaf end
		end
	end
end
-- An owner-independent physical lens mask. Rounded GUI backgrounds do not clip
-- descendants, so these passive outside-arc strips cover every renderer/overlay.
function Art.lcdCorners(parent,color)
	local root=Art.frame(parent,"LCDCornerMask",color,UDim2.fromScale(0,0),UDim2.fromScale(1,1),100)
	root.BackgroundTransparency=1;root.Active,root.Selectable=false,false
	local rows={}
	for corner=1,4 do
		rows[corner]={}
		for row=1,12 do
			local strip=Art.frame(root,"Corner"..corner.."Row"..row,color,UDim2.fromOffset(0,0),UDim2.fromOffset(0,0),100)
			strip.Active,strip.Selectable=false,false;rows[corner][row]=strip
		end
	end
	local key
	local function resize()
		local size=parent.AbsoluteSize
		local width,height=math.floor(size.X+.5),math.floor(size.Y+.5)
		local radius=math.max(0,math.min(10,math.floor(width*.08),math.floor(height*.08)))
		local signature=width..":"..height..":"..radius
		if key==signature then return end;key=signature
		for corner=1,4 do for row,strip in ipairs(rows[corner])do
			strip.Visible=row<=radius
			if row<=radius then
				local dy=radius-(row-1)
				local extent=math.ceil(radius-math.sqrt(math.max(0,radius*radius-dy*dy)))
				local right,bottom=corner%2==0,corner>2
				strip.AnchorPoint=Vector2.new(if right then 1 else 0,if bottom then 1 else 0)
				strip.Position=UDim2.new(if right then 1 else 0,0,if bottom then 1 else 0,if bottom then -(row-1)else row-1)
				strip.Size=UDim2.fromOffset(extent,1)
			end
		end end
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize();return root
end
-- Components from the deck spec (button, tab, card, toggle, progress, toast, list
-- row, back arrow, focus ring) live in DeckKit, which builds on this module.
return Art
