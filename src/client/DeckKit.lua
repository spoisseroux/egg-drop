-- Deck glass tokens and components (UI-SPEC-2026-11-12 sections 2 and 3).
-- Every constructor returns plain Roblox instances; colours that lean with the
-- equipped faceplate are registered with DeckArt.bind so a theme change repaints
-- them once. Text is always neutral; the accent marks selection, the primary
-- action, progress and checks only.
local GuiService=game:GetService("GuiService")
local TweenService=game:GetService("TweenService")
local Art=require(script.Parent.DeckArt)
local Assets=require(script.Parent.DeckAssets)
local Alive=require(game:GetService("ReplicatedStorage").Shared.Alive)
local Spring=require(script.Parent.KitSpring)
local Kit={}

-- 2.1 Colour: the Toy Shell (UI-RETRO-RESTYLE-2026-11-19). Plastic is bright and
-- outlined, screens are dark and dotted. These constants are the Classic Shell values;
-- the bound roles below follow the equipped deck (Art.toyPalette) or Classic.
Kit.Color={text=Color3.fromHex("#FFFFFF"),soft=Color3.fromHex("#DCE5FF"),dim=Color3.fromHex("#DCE5FF"),
 ink=Color3.fromHex("#15143A"),stars=Color3.fromHex("#FFC14D"),danger=Color3.fromHex("#FF5A4D"),dangerText=Color3.fromHex("#FFA3A8"),
 good=Color3.fromHex("#43DB5F"),focus=Color3.fromHex("#FFFFFF"),white=Color3.new(1,1,1),black=Color3.new(0,0,0),
 cream=Color3.fromHex("#FFF4DC"),lemon=Color3.fromHex("#FFE14D"),go=Color3.fromHex("#43DB5F"),tomato=Color3.fromHex("#FF5A4D"),
 tomatoText=Color3.fromHex("#B3261E"),inkSoft=Color3.fromHex("#4A4972")}
-- Kit role -> Toy Shell palette role (3.1). `panel` is the shell (sheets), `raised` the
-- sunk tray (things you read), `well` the LCD glass, `tile` the cream key (things you
-- press), `selected` lemon on every deck, `accent` the one primary action (go).
Kit.ToyRole=table.freeze({panel="shell",raised="tray",well="well",inset="well",selected="selected",line="onShellSoft",accent="go",ink="ink",
 tile="cream",tileLip="creamLip",selectedLip="selectedLip",shell="shell",shellHi="shellHi",shellLip="shellLip",tray="tray",
 wellDot="wellDot",tag="tag",tagLip="tagLip",stage="stage",stageDot="stageDot",stageGlow="stageGlow",inkSoft="inkSoft",
 cream="cream",creamLip="creamLip",lemon="selected",go="go",goLip="goLip",tomato="tomato",tomatoText="tomatoText",
 text="onShell",soft="onShellSoft",dim="onShellSoft",onShell="onShell",onShellSoft="onShellSoft"})
local fallback={}
for role in pairs(Kit.ToyRole)do fallback[role]=true end
-- Text roles read the surface they sit on: ink on cream and lemon (things you press),
-- white or soft on shell, tray and well (rule 1 of section 4).
Kit.SurfaceRoles=table.freeze({text="ink",soft="inkSoft",dim="inkSoft",stars="ink",accent="ink",good="ink",danger="tomatoText",dangerText="tomatoText"})
function Kit.color(role)
 local toy=Art.toyPalette()
 local key=Kit.ToyRole[role]
 return(key and toy[key])or Kit.Color[role]or Kit.Color.text
end
-- "light" (cream / lemon keys and tiles) or "dark" (shell, tray, well, stage): the nearest
-- ancestor that says, else dark.
function Kit.surfaceOf(object)
 local n=object
 while n and not n:IsA("LayerCollector")do
  local surface=n:GetAttribute("ToySurface")
  if surface then return surface end
  n=n.Parent
 end
 return "dark"
end
-- A role read for `object` (screens that paint with their own role helpers): `raised`
-- on a Kit tile is its cream face, text roles follow the surface, the rest as Kit.color.
function Kit.roleOn(object,role,property)
 if object and role=="raised"and property=="BackgroundColor3"and object:GetAttribute("KitTile")then role="tile"end
 if object and Kit.SurfaceRoles[role]then return Kit.onSurface(object,role,property or "TextColor3")end
 if Kit.ToyRole[role]then return Kit.color(role)end
 return Kit.Color[role]or Kit.Color.text
end
function Kit.setSurface(object,surface)object:SetAttribute("ToySurface",surface);return object end
-- A text-role colour for `object` on its surface. `property` keeps Stars gold and the
-- go accent as shapes (an icon or fill) and only moves text off them on cream.
function Kit.onSurface(object,role,property)
 local light=Kit.SurfaceRoles[role]
 if light and Kit.surfaceOf(object)=="light"then
  if(role=="stars"or role=="accent"or role=="good")and property~="TextColor3"then return Kit.color(role)end
  return Kit.color(light)
 end
 return Kit.color(role)
end
-- QA v2 R3.6 (asked by R4): a fixed colour painted over a property that Kit bound to
-- a theme role earlier must replace that binding, or the next theme apply (equipping a
-- faceplate) repaints the old role (once-selected tab labels went ink-dark and
-- vanished). Kit remembers which properties it bound and pins those to the constant.
local kitBound=setmetatable({},{__mode="k"})
-- A binding that steps aside once a caller sets the property by hand (the value is no
-- longer the one it painted). Text roles and the default outline were constants before
-- the Toy Shell, so screens that recolour them by hand keep their colour.
local function softBind(object,property,fn)
 local last=fn()
 object[property]=last
 Art.bind(object,{[property]=function()
  if object[property]~=last then return object[property]end
  last=fn();return last
 end})
 local set=kitBound[object] or {};set[property]=true;kitBound[object]=set
end
Kit.softBind=softBind
local function paint(object,property,role)
 -- A Kit tile painted `raised` by its screen is a cream key in the Toy Shell (3.2).
 if role=="raised"and property=="BackgroundColor3"and object:GetAttribute("KitTile")then role="tile"end
 if type(role)=="string"and Kit.SurfaceRoles[role]then
  softBind(object,property,function()return Kit.onSurface(object,role,property)end)
 elseif type(role)=="string"and(fallback[role]~=nil)then
  object[property]=Kit.color(role);Art.bind(object,{[property]=function()return Kit.color(role)end})
  local set=kitBound[object] or {};set[property]=true;kitBound[object]=set
 elseif type(role)=="function"then
  object[property]=role();Art.bind(object,{[property]=role})
  local set=kitBound[object] or {};set[property]=true;kitBound[object]=set
 else
  local value=if type(role)=="string"then Kit.Color[role]else role
  object[property]=value
  local set=kitBound[object]
  if set and set[property]then Art.bind(object,{[property]=function()return value end})end
 end
end
Kit.paint=paint
-- A palette colour for `node`'s own surface (the equipped plate's inside the Pocket Deck).
function Kit.colorFor(node,role)return Art.scoped(node,Kit.color,role)end
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
 -- DECK-AERO-BRIEF 2 (Alive deckglass): the glass HUD's numbers in Builder Sans ExtraBold (Roboto Mono leaves the deck).
 HudCounter={18,15,sans(Enum.FontWeight.ExtraBold)},HudCounterL={34,22,sans(Enum.FontWeight.ExtraBold)},
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
 local key=face.Family.."|"..face.Weight.Name.."|"..GuiService.PreferredTextSize.Name.."|"..size.."|"..width.."|"..text
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
-- Toy Shell 3.2: every piece has an opaque ink outline drawn inside its rect (2 px; 3 on
-- sheets), so no rect, gap or 44 px target changes.
Kit.Stroke={color=Color3.fromHex("#15143A"),transparency=0,thickness=2,sheet=3}
-- 2.4 Motion (seconds).
Kit.Motion={screen=.16,focus=.09,pressDown=.06,pressUp=.10,hover=.08,tab=.14,toggle=.11,progress=.45,toastIn=.24,toastHold=2.4,toastOut=.16,
 bounce=1} -- scales every spring's overshoot (0 = none)

function Kit.reduced()return GuiService.ReducedMotionEnabled end
local UserInputService=game:GetService("UserInputService")
-- Can this take gamepad focus now: in the game, selectable, and nothing above it hidden or off.
function Kit.focusable(object)
 if not object or not object.Parent or not object:IsDescendantOf(game)or not object:IsA("GuiObject")or not object.Selectable then return false end
 local n=object
 while n do
  if n:IsA("GuiObject")and(not n.Visible or not n.Interactable)or n:IsA("ScreenGui")and not n.Enabled then return false end
  n=n.Parent
 end
 return true
end
function Kit.lastInputTouch()return UserInputService:GetLastInputType()==Enum.UserInputType.Touch end
-- Compact screens hide the focus ring and glyph chips after touch input (UI-SPEC-COMPACT 2.5).
Kit.touchHidesFocus=false
-- v887 QA (2026-11-17): the white focus ring shows for a gamepad only. Mouse, keyboard
-- and touch rely on each screen's own selected state (the green card edge).
Kit.ringGamepadOnly=true
function Kit.lastInputGamepad()return UserInputService:GetLastInputType().Name:sub(1,7)=="Gamepad"end
-- object -> {property -> {tween, goal}}: Kit tweens a spring may have to take over. Kept only while Alive is on.
local tweens=setmetatable({},{__mode="k"})
function Kit.tween(object,time,goal,style)
 if Spring.busy(object)then for key in pairs(goal)do Spring.cancel(object,key)end end
 if Kit.reduced()then for key,value in pairs(goal)do object[key]=value end;return end
 if Alive.on("springs")or Alive.on("menus")then
  local record={goal=goal,tween=TweenService:Create(object,TweenInfo.new(time,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal)}
  local set=tweens[object]or {};tweens[object]=set
  for key in pairs(goal)do set[key]=record end
  record.tween.Completed:Once(function()for key in pairs(goal)do if set[key]==record then set[key]=nil end end end)
  record.tween:Play()
  return
 end
 TweenService:Create(object,TweenInfo.new(time,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal):Play()
end
-- Stops the Kit tweens on `covered` (property names) of `object`; the other properties of a stopped
-- tween land on their goals, since the spring only takes these.
local function dropTween(object,covered)
 local set=tweens[object];if not set then return end
 for property in pairs(covered)do
  local record=set[property]
  if record then
   local land={}
   for key,value in pairs(record.goal)do
    if set[key]==record then set[key]=nil;if not covered[key]then land[key]=value end end
   end
   record.tween:Cancel()
   for key,value in pairs(land)do object[key]=value end
  end
 end
end
-- Springs (KitSpring). Alive motion plays only with its switch on and neither Reduced Motion nor Motion: Low.
Kit.Spring=Spring
function Spring.reduced()return Kit.patternStill()end
function Kit.alive(feature)return Alive.on(feature)and not Kit.patternStill()end
local function springTo(object,property,goal,options)
 options.damping=math.clamp(1-(1-(options.damping or .5))*Kit.Motion.bounce,.1,1)
 local ok,result=pcall(Spring.to,object,property,goal,options)
 if ok then return result end
 -- Never a stuck key or a lost rest: an error lands on the goal.
 warn("[Kit.spring] "..tostring(result))
 pcall(function()if options.set then options.set(goal,0)else object[property]=goal end end)
 if options.done then pcall(options.done,"snap")end
 return nil
end
-- options: time and style (today's tween, used while springs are off), frequency, damping, velocity, done.
function Kit.spring(object,property,goal,options)
 options=if options then table.clone(options)else {}
 if not Kit.alive(options.feature or "springs")then return Kit.tween(object,options.time or Kit.Motion.screen,{[property]=goal},options.style)end
 dropTween(object,{[property]=true})
 return springTo(object,property,goal,options)
end
-- Open and close paint may never break the screen it decorates: an error is a warning and `fallback`.
local function paintSafely(name,fallback,fn)
 return function(...)
  local ok,result=pcall(fn,...)
  if ok then return result end
  warn("[Kit."..name.."] "..tostring(result));return fallback
 end
end
-- Screen rise (step 2): true when it took the rise; false leaves the caller its own (today's 8 px tween).
-- QA-R2-LOOK 1: a rise you can see. 28 px (22 on a phone) at 3.0 Hz, damping .42 (about 6 px past home), with the
-- screen's own fit UIScale riding .90 to 1 on the same spring (clamped at 1.03); a phone bottom sheet comes 40 px at
-- 3.2 Hz, .50. AliveBudget level 2: the rise only. rootScale=false keeps the rise alone everywhere (a low phone's
-- text re-raster, Fable's [check]).
Kit.Rise={offset=28,phone=22,frequency=3.0,damping=.42,scale=.90,top=1.03,rootScale=true,sheet=40,sheetFrequency=3.2,sheetDamping=.50}
-- The fit UIScale (the screen's own, written by its fit code) times k: one helper keeps the fit and writes fit * k, so
-- a re-fit mid-open (a rotation) is a foreign write that wins, and a spring cut short rests at exactly the fit.
local rides=setmetatable({},{__mode="k"}) -- UIScale -> {fit, last}: the fit lives here, never read back mid-ride
function Kit.rideScale(uiScale,from,top,options)
 -- The fit: the value the owner last wrote. Our own in-flight write (an arrive again before a step, a close and
 -- reopen in one frame) is never taken for it.
 local ride=rides[uiScale]
 if not ride or uiScale.Scale~=ride.last then ride={fit=uiScale.Scale};rides[uiScale]=ride end
 local fit=ride.fit
 local k=from
 local function write(value)k=value;uiScale.Scale=fit*math.min(value,top);ride.last=uiScale.Scale end
 write(from)
 return springTo(uiScale,"ArriveScale",1,{feature="menus",frequency=options.frequency,damping=options.damping,limit=options.limit,
  get=function()return k end,mark=function()return uiScale.Scale end,set=function(value)write(value)end,
  done=function(reason)
   -- Cut: back to the fit exactly (unless the fit code wrote it meanwhile). Replaced: the new ride owns it.
   if reason=="cancel"and uiScale.Scale==ride.last then uiScale.Scale=fit;ride.last=uiScale.Scale end
  end})
end
function Kit.phoneScreen()
 local camera=workspace.CurrentCamera
 return camera~=nil and math.min(camera.ViewportSize.X,camera.ViewportSize.Y)<500
end
-- options.sheet: a phone bottom sheet (the longer, softer rise from below).
Kit.arrive=paintSafely("arrive",false,function(object,goal,options)
 if not Kit.alive("menus")then return false end
 options=options or {}
 goal=goal or UDim2.fromScale(.5,.5)
 dropTween(object,{Position=true})
 local R=Kit.Rise
 local phone=Kit.phoneScreen()
 local sheet=options.sheet==true and phone
 local offset=if sheet then R.sheet elseif phone then R.phone else R.offset
 local frequency,damping=if sheet then R.sheetFrequency else R.frequency,if sheet then R.sheetDamping else R.damping
 object.Position=goal+UDim2.fromOffset(0,offset)
 springTo(object,"Position",goal,{feature="menus",frequency=frequency,damping=damping})
 -- The scale grows from the AnchorPoint: only a centred screen grows (a top-left one would grow out of its corner and
 -- its clip would cut the overshoot), so anything else rises only.
 local fit=object:FindFirstChildOfClass("UIScale")
 local centred=object.AnchorPoint==Vector2.new(.5,.5)
 if R.rootScale and not sheet and centred and fit and require(script.Parent.AliveBudget).level()<2 then
  Kit.rideScale(fit,R.scale,R.top,{frequency=frequency,damping=damping})
 end
 return true
end)
-- 2D art pops in, .70 to 1 (top 1.12), one after another 40 ms apart: the first eight shown, all done by .55 s
-- (QA-R2-LOOK 1; was .85 / 1.06 / .35 s). Its UIScale is removed at rest. Never text, viewports, scrollers, canvas
-- groups, list children or art that is scaled already.
Kit.Pop={from=.70,top=1.12,gap=.04,count=8,time=.55,frequency=4.5,damping=.40}
local function popAllowed(object)
 if not object:IsA("GuiObject")or object:FindFirstChildOfClass("UIScale")or Spring.stateOf(object)~="ok"then return false end
 if object.Parent:FindFirstChildWhichIsA("UIGridStyleLayout")then return false end
 local function heavy(n)
  return n:IsA("ViewportFrame")or n:IsA("ScrollingFrame")or n:IsA("CanvasGroup")or n:IsA("TextLabel")or n:IsA("TextButton")or n:IsA("TextBox")
 end
 if heavy(object)then return false end
 for _,n in ipairs(object:GetDescendants())do if heavy(n)then return false end end
 return true
end
Kit.artPop=paintSafely("artPop",0,function(objects)
 if not objects or not Kit.alive("menus")or require(script.Parent.AliveBudget).level()>=2 then return 0 end
 local count=0
 for _,object in ipairs(objects)do
  if count>=Kit.Pop.count then break end
  if popAllowed(object)then
   count+=1
   -- A UIScale grows from the AnchorPoint; the art shifts to grow from its centre.
   local home,lean=object.Position,Vector2.new(.5,.5)-object.AnchorPoint
   local size=Vector2.new(object.Size.X.Offset,object.Size.Y.Offset)
   local scale=Instance.new("UIScale");scale.Name="PopScale";scale.Scale=Kit.Pop.from;scale.Parent=object
   local placed=home
   springTo(scale,"Scale",1,{feature="menus",frequency=Kit.Pop.frequency,damping=Kit.Pop.damping,delay=(count-1)*Kit.Pop.gap,limit=Kit.Pop.time,
    get=function()return scale.Scale end,
    set=function(value)
     scale.Scale=math.min(value,Kit.Pop.top)
     if lean~=Vector2.zero and object.Position==placed then
      local shift=size*lean*(1-scale.Scale)
      object.Position=home+UDim2.fromOffset(math.floor(shift.X+.5),math.floor(shift.Y+.5));placed=object.Position
     end
    end,
    done=function()
     if object.Position==placed and placed~=home then object.Position=home end
     scale:Destroy()
    end})
  end
 end
 return count
end)

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
-- The ink outline on every card, row, track and pill (inside the rect).
function Kit.inner(stroke)
 pcall(function()stroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner end)
 return stroke
end
function Kit.stroke(parent,color,thickness,transparency)
 local s=parent:FindFirstChild("KitStroke")or node("UIStroke",parent,{Name="KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 s.Thickness=thickness or Kit.Stroke.thickness;s.Transparency=transparency or(if color then 0 else Kit.Stroke.transparency)
 Kit.inner(s)
 if color then paint(s,"Color",color)else softBind(s,"Color",function()return Kit.color("ink")end)end
 return s
end

-- Translation rules (v1 track C, artifacts/localization/LOCALIZATION.md). Roblox
-- automatic translation swaps a label's rendered text when AutoLocalize is true.
-- Words stay on; numbers, pet and player names, ids and rich text built from parts
-- (tier circles, capped goal markup) are off, so they are never translated or
-- captured once per value.
Kit.FixedRoles={Counter=true,CounterL=true,HudCounter=true,HudCounterL=true}
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
-- Name tag (Companions Name tile, 2026-11-20): a tag tilted up to the left, a pointed end and its string loop.
function Vector.tag(h,s,t)
 ink(h,"Body",.58,.56,S(.5,.38),-35,3)
 ink(h,"Tip",.38,.42,S(.27,.27),10,2)
 outline(h,"Loop",.22,.26,S(.2,.2),t,999)
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
-- Toys (QA v2 R4.5, moved here from ToyTabIcon): a chew bone, a bar tilted 35 degrees
-- up to the right with two knobs at each end. Pure knob centres in scale units.
function Kit.toyKnobs()
 local a=math.rad(-35);local d=Vector2.new(math.cos(a),math.sin(a));local p=Vector2.new(-d.Y,d.X)
 local out={}
 for _,e in ipairs({.31,-.31})do
  local c=Vector2.new(.5,.5)+d*e
  table.insert(out,c+p*.09);table.insert(out,c-p*.09)
 end
 return out
end
function Vector.toy(h)
 ink(h,"Bar",.5,.5,S(.62,.2),-35,999)
 for i,k in ipairs(Kit.toyKnobs())do ink(h,"Knob"..i,k.X,k.Y,S(.24,.24),0,999)end
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
  shadow.BackgroundTransparency=0;shadow.BackgroundColor3=Kit.Color.ink;shadow.ZIndex=z
  local face=Kit.frame(chip,"StickerFace",nil,UDim2.new(),UDim2.fromScale(1,1),999)
  face.BackgroundTransparency=0;face.ZIndex=z+1
  -- 3.5: a cream edge over an ink drop (the shadow turns into the sticker's ink lip).
  Kit.inner(node("UIStroke",face,{Name="StickerBorder",Thickness=Kit.Sticker.border,Color=Kit.Sticker.cream,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}))
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
  -- Toy Shell 3.5: count chips are a solid ink pill with cream caps; state chips
  -- (accent) go with ink caps; quantity (lemon) a lemon pill; gold an LCD capsule with
  -- gold digits; danger a tomato pill. Every kind keeps the ink outline.
  if kind=="gold"then paint(chip,"BackgroundColor3","well");paint(label,"TextColor3",Kit.Color.stars)
  elseif kind=="danger"then paint(chip,"BackgroundColor3","tomato");paint(label,"TextColor3","ink")
  elseif kind=="accent"then paint(chip,"BackgroundColor3","go");paint(label,"TextColor3","ink")
  elseif kind=="lemon"then paint(chip,"BackgroundColor3","selected");paint(label,"TextColor3","ink")
  elseif isSticker then
   sticker.face.BackgroundColor3=Kit.tintColor(stickerColor)or Kit.Color.stars;paint(label,"TextColor3","ink")
  else paint(chip,"BackgroundColor3","ink");paint(label,"TextColor3","cream")end
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
 Kit.inner(stroke)
 -- Toy Shell 3.4: on a button (`accent`: any filled key) the cap is a white disc with an
 -- ink ring; in hint bars A is a go cap and the rest grey caps, each with its lip.
 local function repaint(accent)
  local ink=Kit.color("ink")
  if kind=="a"then
   chip.BackgroundColor3,chip.BackgroundTransparency=Kit.color("go"),0;stroke.Color,stroke.Thickness,stroke.Transparency=ink,1.5,0;text.TextColor3=ink
   lip.BackgroundColor3=Kit.color("goLip")
  elseif kind=="grey"then
   chip.BackgroundColor3,chip.BackgroundTransparency=Kit.CapGrey,0;stroke.Color,stroke.Thickness,stroke.Transparency=ink,1.5,0;text.TextColor3=Kit.Color.text
   lip.BackgroundColor3=Kit.CapGrey:Lerp(Kit.Color.black,.45)
  elseif accent then chip.BackgroundColor3,chip.BackgroundTransparency=Kit.Color.white,0;stroke.Color,stroke.Thickness,stroke.Transparency=ink,1.5,0;text.TextColor3=ink
  else chip.BackgroundColor3,chip.BackgroundTransparency=Kit.Color.white,.86;stroke.Color,stroke.Thickness,stroke.Transparency=Kit.Color.white,1,.6;text.TextColor3=Kit.Color.text end
 end
 repaint(onAccent);return chip,repaint
end

-- Button. variants: secondary (default), primary, reward, ghost, destructive.
-- The TextButton is the hit rect; Edge + Fill + Content draw it. Content settles
-- 2 px on press while the hit rect stays put.
local buttons=setmetatable({},{__mode="k"})
-- Toy Shell 3.4 states. Primary is go, every other key cream, reward Stars gold, danger a
-- tomato key; all with ink text. Selected is lemon. Hover lifts the face 22% to white,
-- press drops it onto the lip 10% darker, disabled is grey-lilac.
Kit.Disabled=table.freeze({face=Color3.fromHex("#B9B6C9"),lip=Color3.fromHex("#8C89A3"),text=Color3.fromHex("#5A5878")})
local function restFill(state)
 local v=state.variant
 if v=="primary"then return Kit.color("go"),Kit.color("goLip")end
 if v=="reward"then return Kit.Color.stars,Kit.Color.stars:Lerp(Color3.fromHex("#7A4A00"),.45)end
 if v=="destructive"then return Kit.color("tomato"),Kit.color("tomato"):Lerp(Kit.Color.black,.35)end
 if state.selected then return Kit.color("selected"),Kit.color("selectedLip")end
 return Kit.color("cream"),Kit.color("creamLip")
end
local function baseFill(state)
 local v=state.variant
 if not state.enabled then return Kit.Disabled.face,0,Kit.Disabled.lip end
 if v=="ghost"then
  if state.hover then return Kit.Color.white,.88,Kit.Color.white end
  return Kit.Color.white,1,Kit.Color.white
 end
 local color,lip=restFill(state)
 if state.hover then color=color:Lerp(Kit.Color.white,.22)end
 if state.pressed then color=color:Lerp(Kit.Color.black,.10)end
 return color,0,lip
end
Kit.buttonFill=baseFill
-- QA v760: painted with the palette of the surface the button sits on (Art.scoped), on
-- every state change and not only when a theme is applied.
local paintButtonNow
function Kit.paintButton(button)
 if buttons[button]then Art.scoped(button,paintButtonNow,button)end
end
-- Presses on springs (step 1): one scalar per key writes everything that drops with its face. Down stays the
-- .06 s tween (the face also widens 2 px a side over a ledge); the release overshoots up to 2 px above rest.
-- QA-R2-LOOK 1 (Spencer R2.2, "i didnt see any springiness"): the release overshoots 5 px and rings slower and rounder
-- (4.5 Hz, damping .32), and the face takes a press scale too. Springs off, the press is today's tween (these
-- numbers never run).
Kit.Press={over=5,widen=4,minWidth=60,frequency=4.5,damping=.32,epsilon=.3,limit=.6} -- under .5 px draws as rest
-- Tiles (pressTile): the drop and its overshoot only (no Face holder: tiles carry art straight on the tile).
Kit.TilePress={over=4,frequency=4.5,damping=.38,epsilon=.3,limit=.6}
-- The press scale (a UIScale named PressScale on the face, never on the hit rect): down in 60 ms, back on a spring,
-- clamped at `top`. By control: a ledge button, a ghost one, a round key.
Kit.PressScale=table.freeze({
 ledge=table.freeze({scale=.95,top=1.06,frequency=4.5,damping=.32,limit=.6}),
 ghost=table.freeze({scale=.94,top=1.06,frequency=4.5,damping=.32,limit=.6}),
 round=table.freeze({scale=.88,top=1.12,frequency=5,damping=.32,limit=.6}),
})
-- Kit buttons get their Face holder (Edge, Fill and Content under one frame that can scale) only on the place where
-- springs can ever run (Alive's place ceiling, read once); the live game keeps today's button tree exactly. Specs set it.
Kit.FaceOn=(function()local ok,on=pcall(Alive.ceiling,"springs");return ok and on==true end)()
-- Deck juice P5 (AeroUI: the aero press, the key glints, the card caustics, the rolling Stars): required on first use and
-- only where its switch can ever be on (Alive "deckjuice", read once). The live game loads AeroUI (init.client starts it
-- for the menu lift and counters' sound) but every piece of it checks the switch, so live keeps today's keys and cards.
Kit.AeroOn=(function()local ok,on=pcall(Alive.ceiling,"deckjuice");return ok and on==true end)()
local aeroModule=nil
function Kit.aero()
 if not Kit.AeroOn then return nil end
 if aeroModule==nil then local ok,m=pcall(require,script.Parent.AeroUI);aeroModule=if ok then m else false end
 return aeroModule or nil
end
-- The press scale on `target` (a face or a disc, never a GuiButton): down (a 60 ms tween to spec.scale) or up (a
-- spring back to 1, clamped at spec.top). Nothing beside a foreign UIScale or under a grid layout; springs off or
-- Reduced Motion: none at all (rest at 1).
function Kit.pressScale(target,down,spec)
 if not target or target:IsA("GuiButton")or not target.Parent then return nil end
 local scale=target:FindFirstChild("PressScale")
 if not scale then
  if not Kit.alive("springs")then return nil end
  local foreign=target:FindFirstChildOfClass("UIScale")
  if foreign or target.Parent:FindFirstChildWhichIsA("UIGridStyleLayout")then return nil end
  scale=node("UIScale",target,{Name="PressScale",Scale=1})
 end
 if not Kit.alive("springs")then
  Spring.cancel(scale,"Scale");dropTween(scale,{Scale=true});scale.Scale=1
  return scale
 end
 if down then
  Spring.cancel(scale,"Scale")
  Kit.tween(scale,Kit.Motion.pressDown,{Scale=spec.scale})
 else
  dropTween(scale,{Scale=true})
  springTo(scale,"Scale",1,{frequency=spec.frequency,damping=spec.damping,limit=spec.limit,
   get=function()return scale.Scale end,set=function(value)scale.Scale=math.min(value,spec.top)end})
 end
 return scale
end
local FillRest=UDim2.new(1,0,1,0)
local function dropButton(s,d)
 local y=math.floor(math.max(d,-Kit.Press.over)+.5)
 s.content.Position=UDim2.fromOffset(0,y)
 if s.ledge>0 then
  local w=if s.wide then math.clamp(math.floor(Kit.Press.widen*d/math.max(1,s.lip)+.5),0,Kit.Press.widen)else 0
  s.fill.Position=UDim2.fromOffset(-w,y)
  if s.wide then s.fill.Size=UDim2.new(1,w*2,1,0)end
 end
end
local function springButton(button,s,drop)
 if s.face then
  local spec=if s.variant=="ghost"then Kit.PressScale.ghost else Kit.PressScale.ledge
  local aero=Kit.aero();if aero then spec=aero.pressSpec(spec)end
  Kit.pressScale(s.face,drop>0,spec)
  -- Deck juice P5: a glint sweeps the key's face on release.
  if aero and drop==0 then aero.sweep(s.fill)end
 end
 if drop>0 then
  Spring.cancel(s.content,"KitDrop")
  s.wide=s.ledge>0 and button.AbsoluteSize.X>=Kit.Press.minWidth and(s.wide or s.fill.Size==FillRest)or nil
  Kit.tween(s.content,Kit.Motion.pressDown,{Position=UDim2.fromOffset(0,drop)})
  if s.wide then Kit.tween(s.fill,Kit.Motion.pressDown,{Position=UDim2.fromOffset(-Kit.Press.widen,drop),Size=UDim2.new(1,Kit.Press.widen*2,1,0)})
  elseif s.ledge>0 then Kit.tween(s.fill,Kit.Motion.pressDown,{Position=UDim2.fromOffset(0,drop)})end
  return
 end
 dropTween(s.content,{Position=true});dropTween(s.fill,{Position=true,Size=true})
 if not s.enabled then Spring.cancel(s.content,"KitDrop");dropButton(s,0);s.wide=nil;return end
 springTo(s.content,"KitDrop",0,{frequency=Kit.Press.frequency,damping=Kit.Press.damping,epsilon=Kit.Press.epsilon,limit=Kit.Press.limit,
  get=function()return s.content.Position.Y.Offset end,mark=function()return s.content.Position end,set=function(d)dropButton(s,d)end,
  done=function(reason)
   if reason=="replaced"or reason=="cancel"then return end
   -- Someone moved the content: the face follows it, at its own width.
   if reason=="foreign"and s.ledge>0 then s.fill.Position=UDim2.fromOffset(0,s.content.Position.Y.Offset)end
   if s.wide then s.wide=nil;s.fill.Size=FillRest end
  end})
end
function paintButtonNow(button)
 local s=buttons[button];if not s then return end
 local color,transparency,lip=baseFill(s)
 s.fill.BackgroundColor3,s.fill.BackgroundTransparency=color,transparency
 local ghost=s.variant=="ghost"
 local filled=s.enabled and not ghost
 local ink=Kit.color("ink")
 -- T2: every enabled button with a ledge shows its darker lip; on press the face
 -- (Fill + Content) drops onto it, so the lip stays covered rather than hidden.
 s.edge.Visible=s.ledge>0 and not ghost;s.edge.BackgroundColor3=lip
 -- The glint: one light line along the top (keys 20 px and taller, not pressed, not disabled).
 local h=if s.button.Size.Y.Scale==0 then s.button.Size.Y.Offset else s.button.AbsoluteSize.Y
 s.sheen.Visible=filled and not s.pressed and h>=20
 s.stroke.Enabled=not ghost or s.selected
 s.stroke.Color,s.stroke.Transparency=ink,0
 s.stroke.Thickness=if s.selected then 3 else 2
 s.edgeStroke.Enabled=s.edge.Visible
 s.label.TextColor3=if not s.enabled then Kit.Disabled.text elseif ghost then Kit.onSurface(s.button,"text","TextColor3")else ink
 s.label.TextTransparency=0
 -- Every key (disabled too) carries its cap as a white disc with an ink ring; ghosts keep the glass cap.
 if s.repaintGlyph then s.repaintGlyph(not ghost)end
 if s.glyph then s.glyph.Visible=s.showGlyph==true end
 if s.cap then Kit.capButtonLabel(button)end
 -- Press: 60 ms down, 100 ms up; only when the pressed state changes (never per paint).
 local drop=if s.pressed then s.lip else 0
 if s.drop~=drop then
  s.drop=drop
  if Kit.alive("springs")then springButton(button,s,drop);return end
  -- Springs went off mid-press: hand the face back at its own width (and its full size).
  if s.face then Kit.pressScale(s.face,false,Kit.PressScale.ledge)end
  if Spring.cancel(s.content,"KitDrop")or s.wide then
   dropTween(s.fill,{Position=true,Size=true})
   s.wide=nil;s.fill.Size=FillRest;s.fill.Position=UDim2.fromOffset(0,s.fill.Position.Y.Offset)
  end
  local time=if s.pressed then Kit.Motion.pressDown else Kit.Motion.pressUp
  Kit.tween(s.content,time,{Position=UDim2.fromOffset(0,drop)})
  if s.ledge>0 then Kit.tween(s.fill,time,{Position=UDim2.fromOffset(0,drop)})end
 end
end
-- Glint (3.2): one 2 px line of light along the top of a key, with a 3 px break and a
-- 2 px dot at its right end. Inside the outline; pieces under 20 px tall skip it.
Kit.GlintTransparency=.45
function Kit.glint(face,radius)
 radius=math.min(radius or 12,16)
 local left=math.max(8,math.floor(radius*.75))
 local holder=node("Frame",face,{Name="Sheen",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(left,4),
  Size=UDim2.new(1,-left*2,0,2),ZIndex=face.ZIndex,Active=false,Selectable=false})
 local line=node("Frame",holder,{Name="Line",BorderSizePixel=0,BackgroundColor3=Kit.Color.white,BackgroundTransparency=Kit.GlintTransparency,
  Size=UDim2.new(1,-7,1,0),ZIndex=face.ZIndex,Active=false,Selectable=false})
 Kit.corner(line,999)
 local dot=node("Frame",holder,{Name="Dot",BorderSizePixel=0,BackgroundColor3=Kit.Color.white,BackgroundTransparency=Kit.GlintTransparency,
  AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.fromOffset(2,2),ZIndex=face.ZIndex,Active=false,Selectable=false})
 Kit.corner(dot,999)
 face:GetPropertyChangedSignal("ZIndex"):Connect(function()holder.ZIndex=face.ZIndex;line.ZIndex=face.ZIndex;dot.ZIndex=face.ZIndex end)
 return holder
end
-- The lip colour under a face colour: the Toy Shell's own lips for its fixed faces,
-- else the face 38% toward black.
function Kit.lipFor(color)
 local toy=Art.toyPalette()
 if color==toy.cream then return toy.creamLip end
 if color==toy.selected then return toy.selectedLip end
 if color==toy.go then return toy.goLip end
 if color==toy.tag then return toy.tagLip end
 if color==toy.shell then return toy.shellLip end
 if color==Kit.Disabled.face then return Kit.Disabled.lip end
 return color:Lerp(Kit.Color.black,.38)
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
 -- QA-R2-LOOK 1: on the beta place the drawn key lives in a Face holder (centred, the button's size, never active or
 -- selectable) so a PressScale can shrink the key while the hit rect, focus and AccessibleLabel stay on the button.
 local holder=button
 local face=nil
 if Kit.FaceOn then
  face=node("Frame",button,{Name="Face",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),
   BackgroundTransparency=1,BorderSizePixel=0,ZIndex=button.ZIndex,Active=false,Selectable=false})
  holder=face
 end
 local edge=Kit.frame(holder,"Edge",nil,UDim2.fromOffset(0,ledge),UDim2.fromScale(1,1),radius);edge.BackgroundTransparency=0
 local edgeStroke=Kit.inner(node("UIStroke",edge,{Name="EdgeStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2,Color=Kit.Color.ink}))
 local fill=Kit.frame(holder,"Fill",nil,UDim2.new(),UDim2.new(1,0,1,0),radius);fill.BackgroundTransparency=0;fill.ZIndex=edge.ZIndex+1
 -- Glint (3.2): a 2 px light line along the top, with a break and a dot at its right end.
 local sheen=Kit.glint(fill,radius)
 local stroke=Kit.inner(node("UIStroke",fill,{Name="KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2}))
 if variant~="ghost"then Kit.setSurface(button,"light")end
 local content=Kit.frame(holder,"Content",nil,UDim2.new(),UDim2.fromScale(1,1));content.ZIndex=fill.ZIndex+2
 local list=node("UIListLayout",content,{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Center,
  VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
 local glyph,repaintGlyph
 if options.glyph then glyph,repaintGlyph=Kit.glyph(content,options.glyph,false,if variant=="reward"then 22 else 26);glyph.LayoutOrder=1 end
 -- The button label role (T1): Fredoka One at 15 px and up; reward buttons keep
 -- their 16 px default size.
 local label=Kit.text(content,"Button",options.text or name,nil,{Name="Label",AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,size.Y),LayoutOrder=2,TextXAlignment=Enum.TextXAlignment.Center,
  TextSize=options.textSize or(if variant=="reward"then Kit.Type.Strong[1]else Kit.Type.Button[1])})
 local state={variant=variant,enabled=true,hover=false,pressed=false,selected=false,showGlyph=options.showGlyph~=false,lip=options.lip or(if options.ledge then options.ledge else defaultLip),ledge=ledge,drop=0,
  fill=fill,edge=edge,edgeStroke=edgeStroke,sheen=sheen,stroke=stroke,content=content,label=label,glyph=glyph,repaintGlyph=repaintGlyph,list=list,button=button,face=face}
 buttons[button]=state
 if Kit.translating then
  state.cap=node("UISizeConstraint",label,{Name="TranslateCap"});label.TextTruncate=Enum.TextTruncate.AtEnd
  button:GetPropertyChangedSignal("Size"):Connect(function()Kit.capButtonLabel(button)end)
  button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()Kit.capButtonLabel(button)end)
  Kit.capButtonLabel(button)
 end
 Art.bind(fill,{BackgroundColor3=function()Kit.paintButton(button);return fill.BackgroundColor3 end})
 -- Deck juice P5: a primary key glints when it appears and every 6 s while shown.
 if variant=="primary"then local aero=Kit.aero();if aero then aero.watchPrimary(button,fill)end end
 button.MouseEnter:Connect(function()if state.enabled then state.hover=true;Kit.paintButton(button)end end)
 button.MouseLeave:Connect(function()state.hover=false;state.pressed=false;Kit.paintButton(button)end)
 button.MouseButton1Down:Connect(function()if state.enabled then state.pressed=true;Kit.paintButton(button)end end)
 button.MouseButton1Up:Connect(function()if state.pressed then task.delay(Kit.Motion.pressUp,function()state.pressed=false;Kit.paintButton(button)end)end end)
 Kit.paintButton(button)
 return button,state
end
function Kit.buttonState(button)return buttons[button]end
function Kit.setEnabled(button,enabled)
 local s=buttons[button];if not s then return end
 s.enabled=enabled~=false;button.Active=s.enabled or s.tappable==true;button.Interactable=button.Active
 if not s.enabled then
  s.pressed=false;s.hover=false;Spring.settle(s.content,"KitDrop")
  -- QA R2 Studio check R3: the face's press scale (and any boing on the key) lands at 1 too, never mid-ring.
  for _,name in ipairs({"PressScale","BoingScale"})do
   local scale=(s.face and s.face:FindFirstChild(name))or button:FindFirstChild(name)
   if scale then Spring.settle(scale);dropTween(scale,{Scale=true});scale.Scale=1 end
  end
 end;Kit.paintButton(button)
end
-- Stars store access: a disabled button that still takes a press (a short buy opens the
-- "need more Stars" card). It keeps the disabled paint; only Active / Interactable change.
function Kit.setTappable(button,tappable)
 local s=buttons[button];if not s then return end
 s.tappable=tappable==true;button.Active=s.enabled or s.tappable;button.Interactable=button.Active
end
function Kit.setSelected(button,selected)local s=buttons[button];if s then s.selected=selected==true;Kit.paintButton(button)end end
-- Growth cuts (2026-11-25): change a key's variant in place (the results Hatch eggs key turns gold). Colours only;
-- its ledge stays the one it was built with.
function Kit.setVariant(button,variant)local s=buttons[button];if s and s.variant~=variant then s.variant=variant;Kit.paintButton(button)end end
function Kit.setText(button,text)local s=buttons[button];if s then s.label.Text=text;button:SetAttribute("AccessibleLabel",text)end end
function Kit.setGlyphVisible(button,visible)local s=buttons[button];if s then s.showGlyph=visible;Kit.paintButton(button)end end
-- A round close key with an ink X (round 3: the snack pouch closes with an X at its top right).
-- `size` px square (default 30); the label is "Close" for screen readers. Returns the button.
function Kit.closeKey(parent,name,size,label)
 size=size or 30
 local button,state=Kit.button(parent,name,{text="",size=Vector2.new(size,size),radius=math.floor(size/2),compact=true,selectable=false})
 button:SetAttribute("AccessibleLabel",label or "Close")
 state.label.Visible=false
 local mark=Kit.frame(state.content,"X",nil,UDim2.new(),UDim2.fromOffset(math.floor(size*.42),math.floor(size*.42)))
 local bars={}
 for i,angle in ipairs({45,-45})do
  local bar=Kit.frame(mark,"Bar"..i,nil,UDim2.fromScale(.5,.5),UDim2.new(1.25,0,0,math.max(2,math.floor(size*.1))),999)
  bar.AnchorPoint=Vector2.new(.5,.5);bar.Rotation=angle;bar.BackgroundTransparency=0;paint(bar,"BackgroundColor3","ink");bars[i]=bar
 end
 return button,state
end
-- Hardware or keyboard press: a short settle with no pointer involved.
function Kit.pulse(button)
 local s=buttons[button];if not s or not s.enabled then return end
 s.pressed=true;Kit.paintButton(button)
 task.delay(Kit.Motion.pressDown+Kit.Motion.pressUp,function()s.pressed=false;Kit.paintButton(button)end)
end

-- Tray (3.2): the dark pane you read. Sunk: a 3 px shadow under its top edge, no lip.
-- One full-size overlay whose gradient keeps the shadow 3 px deep at any height.
Kit.SinkDepth=3
function Kit.sink(frame,depth)
 depth=depth or Kit.SinkDepth
 local shade=frame:FindFirstChild("TraySink")or node("Frame",frame,{Name="TraySink",BorderSizePixel=0,BackgroundColor3=Kit.Color.black,
  BackgroundTransparency=0,Size=UDim2.fromScale(1,1),ZIndex=frame.ZIndex,Active=false,Selectable=false})
 local corner=frame:FindFirstChildOfClass("UICorner")
 if corner and not shade:FindFirstChildOfClass("UICorner")then node("UICorner",shade,{CornerRadius=corner.CornerRadius})end
 local g=shade:FindFirstChildOfClass("UIGradient")or node("UIGradient",shade,{Rotation=90})
 local function fit()
  local h=frame.AbsoluteSize.Y
  if h<depth*3 then g.Transparency=NumberSequence.new(1);return end
  local a=math.clamp(depth/h,.001,.5)
  g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.62),NumberSequenceKeypoint.new(a,1),NumberSequenceKeypoint.new(1,1)})
 end
 frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
 fit()
 return shade
end
-- Card: radius 14, a tray with the ink outline; label row first.
function Kit.card(parent,name,label,options)
 options=options or {}
 local card=Kit.frame(parent,name,options.role or "raised",UDim2.new(),UDim2.fromOffset(100,100),options.radius or Kit.Radius.card)
 Kit.stroke(card)
 Kit.setSurface(card,"dark")
 if(options.role or "raised")=="raised"then Kit.sink(card)end
 -- options.seam (T2): the stitched seam 6 px inside the edge (information panes only;
 -- no seam asset = no instance; hidden on cards under 150 px tall).
 if options.seam then card:SetAttribute("KitSeam",true);Kit.seam(card)end
 -- Deck juice P5: the light-net under the card's text (nothing until its image is uploaded).
 local aero=Kit.aero();if aero then aero.caustics(card)end
 local pad=options.pad or 20
 local eyebrow
 if label then eyebrow=Kit.text(card,"Label",label,"dim",{Name="Eyebrow",Position=UDim2.fromOffset(pad,options.labelY or 12),Size=UDim2.new(1,-pad*2,0,16)})end
 return card,eyebrow
end

-- Border stays outside a single rounded compositor mask. Unlike a Frame corner,
-- CanvasGroup's rounded mask clips descendant viewports/images at the corners.
-- Toy Shell R1.2.5: every 3D preview sits on the fixed warm berry stage (never deck
-- tinted, never teal), lifted a little toward apricot at the top.
Kit.WarmWell=table.freeze({top=Color3.fromHex("#4A1D3A"):Lerp(Color3.fromHex("#FFB26B"),.16),floor=Color3.fromHex("#4A1D3A")})
function Kit.warmWell(frame)
 -- A fill of its own over the themed well colour (theme repaints never reach it).
 local fill=frame:FindFirstChild("WarmFill")or node("Frame",frame,{Name="WarmFill",BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=frame.ZIndex,Active=false})
 fill.BackgroundColor3=Color3.new(1,1,1);fill.BackgroundTransparency=0
 local corner=frame:FindFirstChildOfClass("UICorner");if corner then node("UICorner",fill,{CornerRadius=corner.CornerRadius})end
 local g=fill:FindFirstChild("WarmGradient")or node("UIGradient",fill,{Name="WarmGradient"})
 g.Rotation=90;g.Color=ColorSequence.new(Kit.WarmWell.top,Kit.WarmWell.floor)
 frame:SetAttribute("WarmWell",true);Kit.setSurface(frame,"dark")
 return fill
end
-- The light on every pet preview in the menus (cards, headshots, Companions, Stats, Customize,
-- Wardrobe, inspect, the peeking pet, the Pocket menu tile). Spencer 2026-11-22: "the pet previews
-- are a little dark/washed out. can we make them bright ... across the boards". It was ambient 206 /
-- light 128 and rendered white fur at 229 and the yellow Bear at 226,180,68 (true 255,208,75).
-- Eggs, jars, snacks and the directed hatch stages keep their own light.
Kit.PetLight=table.freeze({ambient=Color3.fromRGB(215,213,210),color=Color3.fromRGB(200,194,182),direction=Vector3.new(-1,-1.4,-3)})
function Kit.petLight(viewport)
 viewport.Ambient=Kit.PetLight.ambient;viewport.LightColor=Kit.PetLight.color;viewport.LightDirection=Kit.PetLight.direction
 return viewport
end
-- A stage: the berry preview backdrop with its dot grid (R1.2.5), for 3D previews.
function Kit.stage(frame)
 paint(frame,"BackgroundColor3","stage");frame.BackgroundTransparency=0
 Kit.setSurface(frame,"dark");frame:SetAttribute("ToyStage",true)
 Kit.dotGrid(frame,"stageDot")
 return frame
end
function Kit.previewWell(parent,name,position,size,radius)
 radius=radius or 12
 local outer=Kit.frame(parent,name,"stage",position,size,radius);Kit.stroke(outer)
 Kit.stage(outer)
 local clip=Kit.node("CanvasGroup",outer,{Name="RoundedContent",BackgroundTransparency=1,BorderSizePixel=0,
  Position=UDim2.fromOffset(2,2),Size=UDim2.new(1,-4,1,-4),ClipsDescendants=true,GroupTransparency=0,
  ZIndex=outer.ZIndex+1,Active=false,Selectable=false})
 Kit.corner(clip,math.max(1,radius-2))
 clip:SetAttribute("RequiresSiblingMask",true)
 local owner=clip:FindFirstAncestorWhichIsA("LayerCollector")
 clip:SetAttribute("SiblingMaskOwnerValid",owner~=nil and owner.ZIndexBehavior==Enum.ZIndexBehavior.Sibling)
 return outer,clip
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
 if Kit.alive("springs")and not(object.Parent and object.Parent:FindFirstChildWhichIsA("UIGridStyleLayout"))then
  -- QA-R2-LOOK 1: from .90 (.88 for art), damping .35, at most 14 px of growth in all (7 a side).
  local size=object.AbsoluteSize/math.max(scale.Scale,.01)
  local top=1+14/math.max(size.X,size.Y,1)
  local from=if object:IsA("GuiButton")or object:FindFirstChildWhichIsA("GuiButton",true)then .90 else .88
  scale.Scale=from
  springTo(scale,"Scale",1,{frequency=5,damping=.35,get=function()return scale.Scale end,set=function(value)scale.Scale=math.clamp(value,from,top)end})
  return
 end
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
-- Toy Shell step 3: the stitched seam is retired (trays are sunk instead); nothing is made.
Kit.SeamRetired=true
function Kit.seam(card)
 if Kit.SeamRetired then return nil end
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
local PadDrop={PaddingTop=true,PaddingBottom=true}
local function dropTile(state,d)
 local y=math.floor(math.max(d,-Kit.TilePress.over)+.5)
 state.pad.PaddingTop,state.pad.PaddingBottom=UDim.new(0,y),UDim.new(0,-y)
 state.lipFrame.Position=UDim2.fromOffset(0,state.lip-y)
end
local function springTile(state)
 dropTween(state.pad,PadDrop);dropTween(state.lipFrame,{Position=true})
 local tile=state.pad.Parent
 if not tile or not tile.Interactable or not tile.Visible then Spring.cancel(state.pad,"KitDrop");dropTile(state,0);return end
 springTo(state.pad,"KitDrop",0,{frequency=Kit.TilePress.frequency,damping=Kit.TilePress.damping,epsilon=Kit.TilePress.epsilon,limit=Kit.TilePress.limit,
  get=function()return state.pad.PaddingTop.Offset end,set=function(d)dropTile(state,d)end})
end
local function pressTile(state,down)
 if state.pressed==down then return end
 state.pressed=down
 if not down and Kit.alive("springs")then springTile(state);return end
 Spring.cancel(state.pad,"KitDrop")
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
 Spring.cancel(s.pad,"KitDrop");dropTween(s.pad,PadDrop);dropTween(s.lipFrame,{Position=true})
 s.pad.PaddingTop,s.pad.PaddingBottom=UDim.new(),UDim.new()
 s.lipFrame.Position=UDim2.fromOffset(0,depth);s.lipFrame.BackgroundTransparency=if depth>0 then 0 else 1
 tile:SetAttribute("KitLip",depth)
end

-- Pure: a tile outline for a screen's thickness (old rest 1 -> 2, old selected 2 -> 3).
-- Rest is stored as 2.25 (it draws as 2 px) so a screen setting 2 for "selected" always
-- changes the value and is seen.
Kit.TileRest=2.25
function Kit.tileStrokeFor(thickness)
 if thickness<1.5 then return Kit.TileRest end
 if thickness<2.1 then return Kit.Stroke.thickness+1 end
 return thickness
end
-- WCAG relative luminance (pure).
function Kit.luminance(c)
 local function ch(v)return if v<=.03928 then v/12.92 else((v+.055)/1.055)^2.4 end
 return .2126*ch(c.R)+.7152*ch(c.G)+.0722*ch(c.B)
end
function Kit.contrast(a,b)
 local x,y=Kit.luminance(a),Kit.luminance(b)
 return(math.max(x,y)+.05)/(math.min(x,y)+.05)
end
-- A face this light takes ink text (cream, lemon, go, white); darker faces take white.
Kit.LightFace=.3
function Kit.surfaceForColor(color)return if Kit.luminance(color)>=Kit.LightFace then "light"else "dark"end
-- Follows a face colour: marks `object` light or dark and repaints the text under it
-- when that flips (a screen that paints its own tile face keeps readable text).
function Kit.followSurface(object,color)
 local want=Kit.surfaceForColor(color)
 if object:GetAttribute("ToySurface")~=want then object:SetAttribute("ToySurface",want);Art.repaintDescendants(object)end
end
-- Tile (T2, Toy Shell 3.2): a pressable cream key (radius 12) with the ink outline,
-- glint and lip. options: position, size, radius, role ("tile": cream; "raised" also
-- means cream), lip (px; 0 = none), compact (3 px lip), selectable. Returns the
-- TextButton (the hit rect) and its state {lip, face, lipFrame, stroke, setSelected(on, animate)}.
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
 Kit.inner(node("UIStroke",lipFrame,{Name="LipStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2,Color=Kit.Color.ink}))
 local face=node("Frame",tile,{Name="TileFace",BorderSizePixel=0,BackgroundTransparency=0,Size=UDim2.fromScale(1,1),ZIndex=tile.ZIndex,Active=false,Selectable=false})
 Kit.corner(face,radius)
 local stroke=Kit.stroke(face)
 -- The outline stays opaque ink whatever the screen sets (it used to fade the hairline),
 -- and a screen's old 1 px / 2 px (rest / selected) read as 2 px / 3 px: selected is lemon
 -- and a thicker outline, so colour is never the only signal.
 stroke:GetPropertyChangedSignal("Transparency"):Connect(function()if stroke.Transparency~=0 then stroke.Transparency=0 end end)
 local mapping=false
 stroke:GetPropertyChangedSignal("Thickness"):Connect(function()
  if mapping then return end
  local want=Kit.tileStrokeFor(stroke.Thickness)
  if want~=stroke.Thickness then mapping=true;stroke.Thickness=want;mapping=false end
 end)
 stroke.Thickness=Kit.TileRest
 local glint=Kit.glint(face,radius)
 local role=if options.role==nil or options.role=="raised"then "tile"else options.role
 local pad=node("UIPadding",tile,{Name="PressPad"})
 local state={lip=lip,selected=false,stroke=stroke,face=face,lipFrame=lipFrame,pad=pad,pressed=false}
 tiles[tile]=state
 local function mirror()
  face.BackgroundColor3=tile.BackgroundColor3
  lipFrame.BackgroundColor3=Kit.lipFor(tile.BackgroundColor3)
  Kit.followSurface(tile,tile.BackgroundColor3)
  glint.Visible=tile.AbsoluteSize.Y>=20 or tile.Size.Y.Offset>=20
 end
 tile:GetPropertyChangedSignal("BackgroundColor3"):Connect(mirror)
 -- A caller that changes the hit rect's ZIndex keeps the lip and face under its children.
 tile:GetPropertyChangedSignal("ZIndex"):Connect(function()lipFrame.ZIndex=tile.ZIndex-1;face.ZIndex=tile.ZIndex end)
 tile:SetAttribute("KitTile",true)
 Kit.setSurface(tile,if role=="tile"then "light"else "dark")
 paint(tile,"BackgroundColor3",role)
 mirror()
 tile:SetAttribute("KitLip",lip)
 if lip>0 then
  tile.MouseButton1Down:Connect(function()if tile.Interactable then pressTile(state,true)end end)
  tile.MouseButton1Up:Connect(function()pressTile(state,false)end)
  tile.MouseLeave:Connect(function()pressTile(state,false)end)
  -- Never leave a tile dropped when it is disabled, hidden or loses selection mid-press (code review).
  local function release()pressTile(state,false)end
  local function rest()release();Spring.settle(pad,"KitDrop")end
  tile:GetPropertyChangedSignal("Interactable"):Connect(rest)
  tile:GetPropertyChangedSignal("Visible"):Connect(rest)
  tile.SelectionLost:Connect(release)
 end
 function state.setSelected(on,animate)
  local was=state.selected
  state.selected=on==true
  paint(tile,"BackgroundColor3",if state.selected then "selected"else role)
  -- Selected: lemon and a thicker outline (colour is never the only signal).
  stroke.Thickness=if state.selected then 2 else 1;stroke.Transparency=0 -- mapped to 3 / 2 (Kit.tileStrokeFor)
  paint(stroke,"Color","ink")
  if animate and state.selected and not was then Kit.boing(tile)end
 end
 return tile,state
end

-- Well (T7): an inset preview window. Wells that show an egg, a board or a row of
-- balls carry a 6 px LCD dot grid at about 6% white under the art (tiled image,
-- Assets.Personality.dotGrid); with no id nothing extra is created.
-- Toy Shell 3.3: the dots are the visible `wellDot` (or the stage's `stageDot`).
Kit.DotGridTransparency=.25
function Kit.dotGrid(well,role)
 local image=Assets.Personality and Assets.Personality.dotGrid
 if not(image and well)then return nil end
 local existing=well:FindFirstChild("DotGrid")
 if existing then if role then paint(existing,"ImageColor3",role)end;return existing end
 local grid=node("ImageLabel",well,{Name="DotGrid",BackgroundTransparency=1,Image=image,ImageTransparency=Kit.DotGridTransparency,ScaleType=Enum.ScaleType.Tile,
  TileSize=UDim2.fromOffset(6,6),Size=UDim2.fromScale(1,1),ZIndex=well.ZIndex,Active=false,Selectable=false})
 -- Dots inside a preview stage (its rounded content) take the stage's own dot colour.
 if not role then
  local n=well
  while n and not n:IsA("LayerCollector")do if n:GetAttribute("ToyStage")then role="stageDot";break end;n=n.Parent end
 end
 paint(grid,"ImageColor3",role or "wellDot")
 local corner=well:FindFirstChildOfClass("UICorner")
 if corner then node("UICorner",grid,{CornerRadius=corner.CornerRadius})end
 return grid
end
function Kit.well(parent,name,position,size,radius)
 local well=Kit.frame(parent,name or "Well","well",position,size,radius or Kit.Radius.well)
 Kit.stroke(well);Kit.setSurface(well,"dark")
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
  paint(button,"BackgroundColor3",if api.on then "accent"else "well");stroke.Enabled=true
  knob.BackgroundColor3=if api.on then Kit.Color.ink else Kit.Color.soft
  Kit.spring(knob,"Position",UDim2.fromOffset(if api.on then 26 else 4,4),{time=Kit.Motion.toggle,frequency=4.5,damping=.45,limit=.5}) -- QA-R2: 4-5 px past
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
-- Toy Shell 3.5: the bar is a sunk trough (shellLip, ink outline), the active tab a
-- raised lemon key (cream with options.level 2) with its own lip; inactive labels white.
function Kit.tabs(parent,labels,width,height,textSize,icons,options)
 width=width or 520;height=height or 44;textSize=textSize or 17
 local level2=options~=nil and options.level==2
 local track=Kit.frame(parent,"Tabs","shellLip",UDim2.new(),UDim2.fromOffset(width,height),999);Kit.stroke(track);Kit.setSurface(track,"dark")
 Kit.sink(track,4)
 local segment=(width-8)/#labels
 local pill=Kit.frame(track,"Pill",if level2 then "creamLip"else "selectedLip",UDim2.fromOffset(4,4),UDim2.fromOffset(segment,height-8),999)
 Kit.stroke(pill)
 local pillFace=Kit.frame(pill,"Face",if level2 then "cream"else "selected",UDim2.new(),UDim2.new(1,0,1,-2),999)
 pillFace.ZIndex=pill.ZIndex
 Kit.inner(node("UIStroke",pillFace,{Name="FaceStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2,Color=Kit.Color.ink}))
 local api={root=track,buttons={},selected=1,labels={},icons={}}
 -- options.iconOnly: the icon alone (a narrow phone's four tabs); the name stays for screen readers.
 local iconOnly=options~=nil and options.iconOnly==true and icons~=nil and #icons==#labels
 local withIcons=iconOnly or Kit.tabIconsFit(labels,icons,segment,textSize)
 local iconSize=if iconOnly then 18 else textSize+4
 api.hasIcons=withIcons;track:SetAttribute("TabIcons",withIcons)
 for index,text in ipairs(labels)do
  local hitH=math.max(44,height-8)
  local b=node("TextButton",track,{Name="Tab"..index,Text="",AutoButtonColor=false,BackgroundTransparency=1,Position=UDim2.fromOffset(4+(index-1)*segment,(height-hitH)/2),Size=UDim2.fromOffset(segment,hitH),ZIndex=pill.ZIndex+1})
  b:SetAttribute("AccessibleLabel",text);b:SetAttribute("ClickSound","tab") -- UIClick: a tab's own cue
  local label
  if withIcons then
   local w=math.ceil(Kit.measure(text,"Strong",textSize).X)
   local x=math.floor((segment-(iconSize+Kit.TabIconGap+w))/2)
   local icon=Kit.icon(b,icons[index],iconSize,"text");icon.AnchorPoint=Vector2.new(0,.5);icon.Position=UDim2.new(0,x,.5,0)
   api.icons[index]=icon
   label=Kit.text(b,"Strong",text,"text",{Position=UDim2.fromOffset(x+iconSize+Kit.TabIconGap,0),Size=UDim2.new(0,w+2,1,0),TextSize=textSize})
   if iconOnly then icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5);label.Visible=false end
  else
   label=Kit.text(b,"Strong",text,"text",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=textSize})
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
  local springs=Kit.alive("springs")
  if not springs then Spring.cancel(pill,"KitPill")end
  if springs then
   if moved or inFlight~=index then
    squashToken+=1;cancelMotion();inFlight=nil
    if moved then
     inFlight=index
     local stretch=math.floor(segment*.14+.5) -- QA-R2: 14% at mid-flight (was 6)
     springTo(pill,"KitPill",x,{frequency=5,damping=.5,epsilon=.3,limit=.45,get=function()return pill.Position.X.Offset end,mark=function()return pill.Position end,
      set=function(value,speed)
       -- The stretch follows the speed; the pill never leaves the track.
       local w=size.X+math.min(stretch,math.floor(math.abs(speed)*.02))
       pill.Size=UDim2.fromOffset(w,size.Y)
       pill.Position=UDim2.fromOffset(math.clamp(math.floor(value-(w-size.X)/2+.5),4,math.max(4,4+inner-w)),4)
      end,
      done=function(reason)
       if reason=="replaced"then return end
       if inFlight==index then inFlight=nil end
       if reason=="cancel"then return end
       pill.Size=rest
       if reason~="foreign"then pill.Position=goal end
      end})
    else Spring.cancel(pill,"KitPill");pill.Position=goal;pill.Size=rest end
   end
  -- T11 squash: the pill stretches 6% along its travel at mid-flight, centred on
  -- its path, then settles (cut under Reduced Motion).
  elseif moved or inFlight~=index then
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
   paint(label,"TextColor3",if i==index then "ink"else "text")
   if api.icons[i]then Kit.tintIcon(api.icons[i],if i==index then "ink"else "text")end
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

-- HUD label tabs (3.5): on the deck LCD a card's caps label sits on a small coloured
-- plate with an ink edge and ink text. Same text, same place: the plate is a sibling
-- just under the label, sized to its text (4 px each side) and kept in step with it.
Kit.HudTabColors=table.freeze({CHAIN=Color3.fromHex("#FF5A4D"),SCORE=Color3.fromHex("#FFE14D"),GOALS=Color3.fromHex("#43DB5F"),
 NEXT=Color3.fromHex("#7FD4FF"),THEN=Color3.fromHex("#7FD4FF"),EGGS=Color3.fromHex("#FF9838"),WIN=Color3.fromHex("#FFC14D"),
 DAILY=Color3.fromHex("#FF8FC0"),QUESTS=Color3.fromHex("#FF8FC0"),CONTROLS=Color3.fromHex("#A98BFF")})
-- Pure: the tab colour for a label's text (by its first word), or nil.
function Kit.hudTabColor(text)
 local word=string.match(string.upper(text or ""),"^%s*(%u+)")
 return word and Kit.HudTabColors[word]or nil
end
local hudTabOf=setmetatable({},{__mode="k"})
function Kit.hudTabOf(label)return hudTabOf[label]end
function Kit.hudLabel(label,color)
 local tab=hudTabOf[label]
 if tab and tab.Parent then tab.BackgroundColor3=color;return tab end
 tab=node("Frame",label.Parent,{Name=label.Name.."Tab",BorderSizePixel=0,BackgroundColor3=color,ZIndex=label.ZIndex,Active=false,Selectable=false})
 hudTabOf[label]=tab;label:SetAttribute("HudTab",true)
 Kit.corner(tab,4)
 Kit.inner(node("UIStroke",tab,{Name="TabStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1.5,Color=Kit.Color.ink}))
 label.ZIndex+=1
 paint(label,"TextColor3","ink")
 local function place()
  local text=label.Text
  -- The tab colour follows the label's first word (a status line or NEXT / THEN swap).
  local want=Kit.hudTabColor(text)
  if want and tab.BackgroundColor3~=want and tab:GetAttribute("FixedTab")~=true then tab.BackgroundColor3=want end
  local w=if text=="" then 0 else math.ceil(Kit.measure(text,label:GetAttribute("KitRole")or "Label",label.TextSize).X)+8
  -- The label's drawn box (a scale-sized eyebrow measures from its AbsoluteSize).
  local box=label.AbsoluteSize
  local lw=if label.Size.X.Scale==0 then label.Size.X.Offset else box.X
  local lh=if label.Size.Y.Scale==0 then label.Size.Y.Offset else box.Y
  local h=math.min(lh,label.TextSize+4)
  w=math.min(w,lw+8)
  local ax=label.TextXAlignment
  local lx=label.Position.X.Offset-label.AnchorPoint.X*lw
  local x=if ax==Enum.TextXAlignment.Right then lx+lw-w+4 elseif ax==Enum.TextXAlignment.Center then lx+math.floor((lw-w)/2)else lx-4
  -- DECK-FEEL-BRIEF 7 (Alive deckfeel; DeckFeelScreen sets the attributes): a roomier pill, 10 px (8 compact) each
  -- side, 24 tall (or the card's FeelPillH), radius 8 (6), with a 2 px darker lip along its foot.
  local pill=label:GetAttribute("FeelPill")
  if pill then
   local pad=if pill=="compact"then 8 else 10
   h=label:GetAttribute("FeelPillH")or(if pill=="compact"then 20 else 24)
   w=if text==""then 0 else math.ceil(Kit.measure(text,label:GetAttribute("KitRole")or "Label",label.TextSize).X)+2*pad
   x=if ax==Enum.TextXAlignment.Right then lx+lw-w+pad elseif ax==Enum.TextXAlignment.Center then lx+math.floor((lw-w)/2)else lx-pad
   local corner=tab:FindFirstChildOfClass("UICorner")
   if tab:GetAttribute("Glass")then
    -- DECK-AERO-BRIEF 2 (Alive deckglass; DeckGlassUI.pill): a gel pill, full radius, no lip (its fill is GlassFill).
    if corner then corner.CornerRadius=UDim.new(.5,0)end
    local lip=tab:FindFirstChild("FeelLip");if lip then lip:Destroy()end
   else
    if corner then corner.CornerRadius=UDim.new(0,if pill=="compact"then 6 else 8)end
    local lip=tab:FindFirstChild("FeelLip")or node("UIGradient",tab,{Name="FeelLip",Rotation=90})
    local k=math.clamp((h-2)/math.max(1,h),.5,.99)
    lip.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(k,Color3.new(1,1,1)),
     ColorSequenceKeypoint.new(math.min(.999,k+.001),Color3.new(.68,.68,.68)),ColorSequenceKeypoint.new(1,Color3.new(.68,.68,.68))})
   end
  end
  local y=label.Position.Y.Offset-label.AnchorPoint.Y*lh+math.floor((lh-h)/2)
  tab.Position=UDim2.new(label.Position.X.Scale,x,label.Position.Y.Scale,y)
  tab.Size=UDim2.fromOffset(w,h)
  tab.Visible=label.Visible and w>0
 end
 for _,property in ipairs({"Text","Position","Size","Visible","TextSize","AbsoluteSize"})do label:GetPropertyChangedSignal(property):Connect(place)end
 label:GetAttributeChangedSignal("FeelPill"):Connect(place);label:GetAttributeChangedSignal("FeelPillH"):Connect(place)
 tab:GetAttributeChangedSignal("Glass"):Connect(place)
 -- The tab follows its label only (a card that hides or shows its children by hand never
 -- leaves a visible label without its tab).
 tab:GetPropertyChangedSignal("Visible"):Connect(function()if tab.Visible~=(label.Visible and label.Text~="")then place()end end)
 label.Destroying:Connect(function()tab:Destroy()end)
 place()
 return tab
end
-- Every caps label under `root` whose first word has a tab colour gets its tab.
function Kit.hudTabs(root)
 if not root then return 0 end
 local n=0
 for _,d in ipairs(root:GetDescendants())do
  if d:IsA("TextLabel")and d:GetAttribute("KitRole")=="Label"then
   local color=Kit.hudTabColor(d.Text)
   if color then Kit.hudLabel(d,color);n+=1 end
  end
 end
 return n
end

-- Stars with thousands separators ("1,280"); the accessible label keeps the raw number.
function Kit.formatStars(value)
 if type(value)=="number"and value>=1000 and value%1==0 and value<1e15 then
  local text=string.format("%d",value):reverse():gsub("(%d%d%d)","%1,"):reverse()
  return(text:gsub("^,",""))
 end
 return tostring(value)
end
-- Stars capsule, the "Star Bank" (Astra, artifacts/v2-stars-counter-2026-11-20/STARS-COUNTER-SPEC.md).
-- Spencer 2026-11-20: the dark LCD pill read dull and dated beside the cream keys, so it is a
-- Toy Shell token: a cream face on a gold coin-edge lip, ink digits in the display face, and the
-- Star in a dark medallion that pops out of the left end (4 px past the slot). Not pressable.
-- Per height: lip, face, disc (medallion), star, text (digit size), pad (right), eyes, glint.
-- Other heights scale from 44.
Kit.WalletSpec={
 [44]={lip=4,disc=48,star=28,text=22,pad=14,eyes=true,glint=true},
 [40]={lip=4,disc=44,star=26,text=20,pad=13,eyes=true,glint=true},
 [36]={lip=3,disc=40,star=22,text=18,pad=12,eyes=true,glint=true},
 [32]={lip=3,disc=34,star=20,text=16,pad=10,eyes=true,glint=true},
 [28]={lip=2,disc=30,star=16,text=15,pad=9,eyes=false,glint=false},
}
Kit.WalletGold=Color3.fromHex("#D9A31C")
Kit.WalletFace=table.freeze({Color3.fromHex("#FFF4DC"),Color3.fromHex("#FFE7B0")})
function Kit.walletSpec(height)
 local spec=Kit.WalletSpec[height]
 if spec then return spec end
 local k=height/44
 -- The Star keeps the older .55 share below the table, so tiny capsules stay a plain 2D Star.
 return {lip=math.max(2,math.floor(4*k+.5)),disc=math.floor(48*k+.5),star=math.floor(height*.55),text=math.max(12,math.floor(22*k+.5)),
  pad=math.max(8,math.floor(14*k+.5)),eyes=height>=32,glint=height>=32}
end
-- Pure: the capsule's width for a digit width `textW` (the medallion overhangs 4 px of it).
function Kit.walletWidth(height,textW)
 local spec=Kit.walletSpec(height)
 return math.ceil((spec.disc-4)+6+textW+spec.pad)
end
-- Stars store access: set by init.client; called with the wallet's api when a tappable
-- wallet is pressed. Returns true when it opened the store (else the wallet only flashes).
Kit.onWalletTap=nil
function Kit.wallet(parent,height,options)
 height=height or 44
 options=options or {}
 local spec=Kit.walletSpec(height)
 local faceH=height-spec.lip
 local root=Kit.frame(parent,"Wallet",nil,UDim2.new(),UDim2.fromOffset(110,height));root.ClipsDescendants=false
 local z=root.ZIndex
 local edge=Kit.frame(root,"Edge",nil,UDim2.new(),UDim2.fromScale(1,1),999);edge.BackgroundTransparency=0;edge.BackgroundColor3=Kit.WalletGold;edge.ZIndex=z+1
 Kit.stroke(edge,"ink",2,0)
 local face=Kit.frame(root,"Face",nil,UDim2.new(),UDim2.new(1,0,0,faceH),999);face.BackgroundTransparency=0;face.BackgroundColor3=Color3.new(1,1,1);face.ZIndex=z+2
 node("UIGradient",face,{Name="FaceShade",Rotation=90,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Kit.WalletFace[1]),
  ColorSequenceKeypoint.new(.45,Kit.WalletFace[1]),ColorSequenceKeypoint.new(1,Kit.WalletFace[2])})})
 Kit.stroke(face,"ink",2,0);Kit.setSurface(face,"light");Kit.setSurface(root,"light")
 if spec.glint then local g=Kit.glint(face,999);g.Position=UDim2.fromOffset(spec.disc-2,4);g.Size=UDim2.new(1,-(spec.disc-2)-14,0,2)end
 local flash=Kit.frame(face,"Flash",nil,UDim2.new(),UDim2.fromScale(1,1),999);flash.BackgroundColor3=Kit.Color.lemon;flash.BackgroundTransparency=1;flash.ZIndex=z+2
 -- The medallion: deck well glass, ink ring, its own ink drop, a thin Stars-gold inner ring.
 local medalPos=UDim2.fromOffset(-4,math.floor(faceH/2))
 local drop=Kit.frame(root,"MedalDrop","ink",medalPos+UDim2.fromOffset(0,2),UDim2.fromOffset(spec.disc,spec.disc),999);drop.BackgroundTransparency=0;drop.AnchorPoint=Vector2.new(0,.5);drop.ZIndex=z+3
 local medal=Kit.frame(root,"Medal","well",medalPos,UDim2.fromOffset(spec.disc,spec.disc),999);medal.BackgroundTransparency=0;medal.AnchorPoint=Vector2.new(0,.5);medal.ZIndex=z+4
 Kit.stroke(medal,"ink",2,0)
 if height>28 then
  local ring=Kit.frame(medal,"MedalRing",nil,UDim2.fromOffset(3,3),UDim2.new(1,-6,1,-6),999);ring.ZIndex=z+5
  node("UIStroke",ring,{Color=Color3.fromHex("#FFC14D"),Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 end
 -- The Star sits on the root (WalletStar puts its 3D Star beside the icon), centred on the medallion.
 local star=Kit.icon(root,"star",spec.star);star.AnchorPoint=Vector2.new(.5,.5);star.ZIndex=z+6
 star.Position=UDim2.fromOffset(-4+spec.disc/2,math.floor(faceH/2)+1)
 -- T9: the Star gets two eyes from 20 px up and stays plain below. The uploaded eyes cell
 -- (DeckAssets.Personality.starFace, right half) when there is one, else two ink dots.
 local starSize=star.Size.X.Offset
 if spec.eyes and starSize>=20 then
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
 -- From WalletStar.MinSize (16 px, R3.3) up the icon gives way to a small front-facing 3D Star
 -- once the StarToken mesh loads (WalletStar); the 2D Star stays as the fallback.
 local star3D=require(script.Parent.WalletStar).attach(root,star,starSize)
 local amount=Kit.text(face,"Counter","0","ink",{Name="Amount",AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-spec.pad,.5,-1),
  Size=UDim2.fromOffset(60,faceH),TextXAlignment=Enum.TextXAlignment.Right,FontFace=Kit.DisplayFace,TextSize=spec.text})
 amount.ZIndex=z+3
 local pop=node("UIScale",amount,{Name="Pop"})
 local api={root=root,amount=amount,height=height,star=star,star3D=star3D,face=face,medal=medal}
 local shown
 local TweenService=game:GetService("TweenService")
 -- The Star (2D and 3D) hops 8 px on a gain; gains within .3 s share one hop.
 local starHome,hoppedAt=star.Position,-math.huge
 local function hop()
  if not Kit.alive("springs")or os.clock()-hoppedAt<.3 then return end
  hoppedAt=os.clock()
  springTo(root,"KitHop",0,{frequency=5,damping=.4,velocity=620*Kit.Motion.bounce,epsilon=.1, -- QA-R2: 416 -> 620, cap 12
   get=function()return starHome.Y.Offset-star.Position.Y.Offset end,mark=function()return star.Position end,
   set=function(value)
    star.Position=starHome-UDim2.fromOffset(0,math.floor(math.min(value,12)+.5))
    local shown3D=star3D.wallet;if shown3D and shown3D.holder.Parent then shown3D.holder.Position=star.Position end
   end,
   -- However a hop ends, the two Stars end on one spot.
   done=function(reason)
    local shown3D=star3D.wallet
    if reason~="replaced"and shown3D and shown3D.holder.Parent then shown3D.holder.Position=star.Position end
   end})
 end
 -- Earn juice (spec: number goes up only): the digits pop and the face flashes lemon. The text itself changes at once (screens and specs read it straight after set).
 local function earn()
  if not root:IsDescendantOf(game)then return end
  flash.BackgroundTransparency=.15
  TweenService:Create(flash,TweenInfo.new(.32,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,.12),{BackgroundTransparency=1}):Play()
  if game:GetService("GuiService").ReducedMotionEnabled then return end
  require(script.Parent.WalletStar).celebrate(star3D)
  pop.Scale=1
  local up=TweenService:Create(pop,TweenInfo.new(.08,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.25})
  up.Completed:Once(function()TweenService:Create(pop,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1}):Play()end)
  up:Play()
  hop()
 end
 function api.set(value)
  local before=shown;shown=value
  amount.Text=Kit.formatStars(value)
  local w=game:GetService("TextService"):GetTextSize(amount.Text,spec.text,Enum.Font.FredokaOne,Vector2.new(500,50)).X
  amount.Size=UDim2.fromOffset(math.ceil(w)+2,faceH)
  root.Size=UDim2.fromOffset(Kit.walletWidth(height,w),height)
  root:SetAttribute("AccessibleLabel",require(script.Parent.StarText).amount(value))
  -- Deck juice P5: the digits roll up to the new amount (Text already holds it).
  local aero=Kit.aero();if aero then aero.roll(amount,value,Kit.formatStars)end
  if type(before)=="number"and type(value)=="number"and value>before then earn()end
 end
 -- Stars store access (opt-in: Kit.header only). A transparent key over the capsule and its
 -- medallion; not in the gamepad focus chain. The tap goes to Kit.onWalletTap; when that is
 -- unset or refuses (a round, a hatch waiting), the face flashes and nothing else happens.
 if options.tap then
  local tap=node("TextButton",root,{Name="Tap",Text="",AutoButtonColor=false,BackgroundTransparency=1,Selectable=false,
   -- At least 44 px tall (touch target rule; the compact header capsule is 36), centred on it.
   Position=UDim2.fromOffset(-4,-math.max(0,44-height)/2),Size=UDim2.new(1,4,0,math.max(44,height)),ZIndex=z+8})
  tap:SetAttribute("AccessibleLabel",require(game:GetService("ReplicatedStorage").Shared.UICopy).get("starsShort.wallet"))
  local press=node("UIScale",root,{Name="TapScale"})
  local function settle(scale)TweenService:Create(press,TweenInfo.new(.1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=scale}):Play()end
  tap.MouseButton1Down:Connect(function()if not game:GetService("GuiService").ReducedMotionEnabled then settle(.94)end end)
  tap.MouseButton1Up:Connect(function()settle(1)end)
  tap.MouseLeave:Connect(function()settle(1)end)
  tap.Activated:Connect(function()
   -- Spencer 2026-11-21: "there's no feedback visually showing i clicked the stars button".
   -- Every tap: the face flashes lemon and the capsule pops (1.12 and back), then the store
   -- opens (or, refused, that flash is the whole answer). Reduced Motion: the flash only.
   flash.BackgroundTransparency=.15
   TweenService:Create(flash,TweenInfo.new(.36,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,.06),{BackgroundTransparency=1}):Play()
   if game:GetService("GuiService").ReducedMotionEnabled then press.Scale=1
   elseif Kit.alive("springs")then
    -- QA-R2-LOOK 1: 1.18 and back on a spring (5 Hz, .35), never past 1.18.
    Spring.cancel(press,"Scale")
    press.Scale=1.18
    springTo(press,"Scale",1,{frequency=5,damping=.35,limit=.6,get=function()return press.Scale end,set=function(value)press.Scale=math.min(value,1.18)end})
   else
    press.Scale=1.12
    TweenService:Create(press,TweenInfo.new(.22,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
   end
   pcall(function()require(script.Parent.UIClick).play("confirm")end)
   if Kit.onWalletTap then pcall(Kit.onWalletTap,api)end
  end)
  api.tap=tap
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

-- Rings follow the input device: one listener re-places every live ring on a switch
-- (weak keys: a destroyed screen's ring drops out).
local liveRings=setmetatable({},{__mode="k"})
UserInputService.LastInputTypeChanged:Connect(function()
 for api in pairs(liveRings)do if api.target and api.root.Parent then api.place(true)end end
end)
-- Shared focus ring: 2.5 px white, 4 px outside, radius + 4, soft glow behind.
-- One instance per host; it slides to its next target in 90 ms.
function Kit.focusRing(host)
 local ring=node("Frame",host,{Name="FocusRing",BackgroundTransparency=1,Visible=false,ZIndex=200,Active=false,Selectable=false})
 local corner=Kit.corner(ring,16)
 node("UIStroke",ring,{Name="Ring",Thickness=2.5,Color=Kit.Color.focus,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 -- 3.4: a 1.5 px ink hairline outside the white ring, so it reads on cream and lemon too.
 local hair=node("Frame",ring,{Name="InkHairline",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(-2,-2),Size=UDim2.new(1,4,1,4),ZIndex=200,Active=false,Selectable=false})
 local hairCorner=node("UICorner",hair,{})
 node("UIStroke",hair,{Name="Hair",Thickness=1.5,Color=Kit.Color.ink,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 local glow=node("ImageLabel",ring,{Name="Glow",BackgroundTransparency=1,Image=Assets.Image.focusGlow,ImageTransparency=.35,
  ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(40,40,56,56),Position=UDim2.fromOffset(-20,-20),Size=UDim2.new(1,40,1,40),ZIndex=199})
 local api={root=ring,target=nil}
 local connection
 local function place(instant)
  local t=api.target;if not t or not t.Parent or not t.Visible then ring.Visible=false;return end
  if Kit.touchHidesFocus and Kit.lastInputTouch()then ring.Visible=false;return end
  if Kit.ringGamepadOnly and not Kit.lastInputGamepad()then ring.Visible=false;return end
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
  hairCorner.CornerRadius=if(radius or 12)>=999 then UDim.new(.5,0)else UDim.new(0,(radius or 12)+6)
  glow.Visible=not Kit.reduced()
  if target then connection=target:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()place(true)end)end
  place(not moved)
 end
 function api.hide()if connection then connection:Disconnect();connection=nil end;api.target=nil;ring.Visible=false end
 api.place=place
 liveRings[api]=true
 return api
end

-- Compatibility adapter: all former per-screen queues now share the topbar rail.
-- `placement` is accepted by old callers but deliberately cannot move this owner.
-- `detail` (QA v735 H5) names the notice card a tap on the line opens (NoticeCards.detail).
-- `activate` (optional, v2 tickets) is the caller's own opener for a tap (it wins over the
-- detail card); it should do nothing when its menu is already open (no second copy).
local toastSerial=0
function Kit.toaster(host,rail)
 local Rail=rail or require(script.Parent.NotificationRail)
 local api={root=host}
 function api.show(message,stars,eventKey,detail,activate)
  toastSerial+=1
  return Rail.enqueue(host,if eventKey~=nil then eventKey else "toast:"..toastSerial,{text=message,amount=stars,detail=detail,
   activate=if type(activate)=="function"then activate else nil})
 end
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
-- Round keys (back, help): cream with the ink outline and a 2 px lip under them (in a
-- header, where the hit frame holds the disc). Hover goes white, press 10% darker.
Kit.RoundLip=2
function Kit.roundKeyLip(button,disc)
 if disc==button then return nil end
 -- FABLE-REVIEW-R3 1: the round Back and Help keys press too. Their Disc (with its glyph) carries a PressScale on the
 -- beta place (the Face gate): .88 down in 60 ms, back on 5 Hz / .32, clamp 1.12 (Kit.pressScale); the KeyLip and the
 -- hit rect stay still.
 if Kit.FaceOn and not disc:FindFirstChildOfClass("UIScale")then node("UIScale",disc,{Name="PressScale",Scale=1})end
 local lip=node("Frame",button,{Name="KeyLip",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,Kit.RoundLip),Size=disc.Size,
  BorderSizePixel=0,BackgroundColor3=Kit.Color.cream,ZIndex=button.ZIndex-1,Active=false,Selectable=false})
 Kit.corner(lip,999)
 Kit.inner(node("UIStroke",lip,{Name="LipStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2,Color=Kit.Color.ink}))
 disc:GetPropertyChangedSignal("Size"):Connect(function()lip.Size=disc.Size end)
 button:GetPropertyChangedSignal("ZIndex"):Connect(function()lip.ZIndex=button.ZIndex-1 end)
 return lip
end
function Kit.paintRoundKey(disc,stroke,lip,enabled,hover,pressed)
 local face=if not enabled then Kit.Disabled.face elseif hover then Kit.Color.white else Kit.color("cream")
 if pressed then face=face:Lerp(Kit.Color.black,.10)end
 disc.BackgroundColor3,disc.BackgroundTransparency=face,0
 stroke.Color,stroke.Transparency=Kit.color("ink"),0
 if lip then lip.BackgroundColor3=if enabled then Kit.color("creamLip")else Kit.Disabled.lip;lip.LipStroke.Color=Kit.color("ink")end
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
 local stroke=node("UIStroke",disc,{Name="KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2,Color=Kit.Color.ink,Transparency=0})
 Kit.inner(stroke)
 -- Toy Shell 3.6: a cream round key; the old glow shadow stays as an instance, hidden.
 local shadow=node("ImageLabel",disc,{Name="Shadow",BackgroundTransparency=1,Image=Assets.Image.focusGlow,ImageColor3=Kit.Color.black,ImageTransparency=.55,
  ScaleType=Enum.ScaleType.Slice,SliceCenter=Rect.new(40,40,56,56),Position=UDim2.fromOffset(-14,-9),Size=UDim2.new(1,28,1,28),ZIndex=59,Visible=false})
 local keyLip=Kit.roundKeyLip(button,disc)
 Kit.setSurface(disc,"light")
 local iconSize=if drawn>=56 then 26 elseif drawn>=44 then 22 else 18
 local icon=Kit.icon(disc,"back",iconSize,"text");icon.AnchorPoint,icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 local api={root=button,disc=disc,enabled=true,size=hit,drawn=drawn,header=header,lip=keyLip}
 local hover,pressed=false,false
 local function repaint()
  Kit.paintRoundKey(disc,stroke,keyLip,api.enabled,hover,pressed)
  icon.Position=UDim2.new(.5,0,.5,if pressed then 2 else 0)
  icon.ImageTransparency=if api.enabled then 0 else .45
  shadow.Visible=false
 end
 button.MouseEnter:Connect(function()hover=true;repaint()end)
 -- QA-R2-LOOK 1: a round key's disc takes the press scale (.88, 5 Hz); a bare button (no disc) keeps today's press.
 local function squeeze(down)if disc~=button then Kit.pressScale(disc,down,Kit.PressScale.round)end end
 button.MouseLeave:Connect(function()local was=pressed;hover=false;pressed=false;repaint();if was then squeeze(false)end end)
 button.MouseButton1Down:Connect(function()pressed=api.enabled;repaint();if pressed then squeeze(true)end end)
 button.MouseButton1Up:Connect(function()local was=pressed;pressed=false;repaint();if was then squeeze(false)end end)
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
-- Toy Shell 3.1: the screen tints are saturated toy colours, worn by the header plate
-- (ink title on them, 6.6:1 and up). Garden is go.
Kit.Tint={hatch=Color3.fromHex("#FF8A5C"),style=Color3.fromHex("#A98BFF"),companions=Color3.fromHex("#FF8FC0"),
 quests=Color3.fromHex("#7FD4FF"),results=Kit.Color.stars,book=Color3.fromHex("#3FD9B4"),garden=Color3.fromHex("#43DB5F")}
local function tintColor(tint)
 if typeof(tint)=="Color3"then return tint end
 return Kit.Tint[tint]
end
Kit.tintColor=tintColor
-- Dot + eyebrow: the eyebrow text takes the tint and moves 14 px right inside its
-- own rect (a UIPadding), with an 8 px dot where the text used to start.
-- Toy Shell 3.6: the header plate carries the tint; the eyebrow dot is retired, so the
-- eyebrow keeps its soft text and only records the tint.
Kit.TintDotRetired=true
function Kit.tintEyebrow(eyebrow,tint)
 local color=tintColor(tint);if not(eyebrow and color)then return nil end
 if Kit.TintDotRetired then eyebrow:SetAttribute("Tint",color:ToHex());return nil end
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
-- Retired by the header plate (3.6): nothing is made.
function Kit.squiggle(parent,title,tint)
 if Kit.TintDotRetired then return nil end
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
-- Toy Shell 3.3: the halftone fade is retired (no pattern behind text). Desktop menu
-- panels that called it get the shell's moving checker instead (Kit.shellPattern); the
-- deck's results never do. Returns the pattern controller or nil.
Kit.HalftoneRetired=true
function Kit.halftone(panel,tint,compact,height)
 if Kit.HalftoneRetired then
  if compact or not panel or tint=="results"then return nil end
  return Kit.shellPattern(panel)
 end
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
-- QA v2 R3.8 `help`: a "How it works" circle (drawn like the back circle, 44 hit) 8 px
-- left of the capsule (or of the back circle with no wallet); the title then stops
-- 12 px before it.
function Kit.headerGeometry(W,compact,walletW,left,help)
 compact=compact==true
 local h=if compact then 36 else 44
 local cy=if compact then 34 else 44
 local right=W-(if compact then 20 else 24)
 left=left or 24
 local g={compact=compact,height=if compact then 60 else 84,centerY=cy,controlH=h,right=right}
 g.back={x=right-h,y=cy-h/2,w=h,h=h}
 g.backHit={x=right-h/2-22,y=cy-22,w=44,h=44}
 g.wallet=if walletW then{x=g.back.x-8-walletW,y=cy-h/2,w=walletW,h=h}else nil
 if help then
  local edge=if g.wallet then g.wallet.x else g.back.x
  g.help={x=edge-8-h,y=cy-h/2,w=h,h=h}
  g.helpHit={x=g.help.x+h/2-22,y=cy-22,w=44,h=44}
 end
 local limit=(if g.help then g.help.x elseif g.wallet then g.wallet.x else g.back.x)-12
 local th=if compact then 24 else 32
 local tcy=if compact then 34 else 48
 g.title={x=left,y=tcy-th/2,w=math.max(0,limit-left),h=th}
 g.eyebrow=if compact then nil else{x=left,y=14,w=math.max(0,limit-left),h=16}
 return g
end
-- ── "How it works" (QA v2 R3.8) ─────────────────────────────────────────────
-- Every machine header carries a ? circle that opens that machine's two or three
-- illustrated cards (HowItWorks). The family comes from options.help (an id, or
-- false for none) or else from the header's tint key, so every screen that already
-- passes a family tint gets its ? without further wiring. The hub (cream tint) has none.
Kit.HelpIds=table.freeze({hatch="hatch",style="style",companions="companions",quests="quests",book="book"})
function Kit.helpIdFor(options)
 options=options or {}
 if options.help==false then return nil end
 if type(options.help)=="string"then return options.help end
 if type(options.tint)=="string"then return Kit.HelpIds[options.tint]end
 return nil
end
-- Opening: Kit.onHelp (specs and callers may replace it) or the HowItWorks overlay.
Kit.onHelp=nil
function Kit.openHelp(id)
 if Kit.onHelp then return Kit.onHelp(id)end
 local ok,HowItWorks=pcall(require,script.Parent.HowItWorks)
 if not ok then warn("HowItWorks unavailable: "..tostring(HowItWorks));return false end
 return HowItWorks.open(id)
end
-- The ? circle: drawn 44 (36 compact) inside a 44 x 44 hit frame, like the header back.
function Kit.helpButton(parent,compact,id)
 local drawn=if compact then 36 else 44
 local button=node("TextButton",parent,{Name="HelpButton",Text="",AutoButtonColor=false,Size=UDim2.fromOffset(44,44),BackgroundTransparency=1,ZIndex=60,Selectable=false})
 button:SetAttribute("AccessibleLabel",require(game:GetService("ReplicatedStorage").Shared.UICopy).get("r3.help.button"));button:SetAttribute("HelpId",id)
 local disc=node("Frame",button,{Name="Disc",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(drawn,drawn),
  BorderSizePixel=0,BackgroundColor3=Color3.fromHex("#15171B"),BackgroundTransparency=.28,ZIndex=button.ZIndex,Active=false})
 Kit.corner(disc,999)
 local stroke=Kit.inner(node("UIStroke",disc,{Name="KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2,Color=Kit.Color.ink,Transparency=0}))
 local keyLip=Kit.roundKeyLip(button,disc)
 Kit.setSurface(disc,"light")
 local mark=Kit.fixedText(Kit.text(disc,"Title","?","text",{Name="Mark",Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextSize=if compact then 18 else 22}))
 mark.ZIndex=button.ZIndex+1
 button:GetPropertyChangedSignal("ZIndex"):Connect(function()disc.ZIndex=button.ZIndex;mark.ZIndex=button.ZIndex+1 end)
 local api={root=button,disc=disc,mark=mark,id=id,lip=keyLip}
 local function repaint(hover)Kit.paintRoundKey(disc,stroke,keyLip,true,hover,false)end
 repaint(false)
 button.MouseEnter:Connect(function()repaint(true)end)
 -- QA-R2-LOOK 1: the round key's press scale on its disc.
 local down=false
 button.MouseLeave:Connect(function()repaint(false);if down then down=false;Kit.pressScale(disc,false,Kit.PressScale.round)end end)
 button.MouseButton1Down:Connect(function()down=true;Kit.pressScale(disc,true,Kit.PressScale.round)end)
 button.MouseButton1Up:Connect(function()if down then down=false;Kit.pressScale(disc,false,Kit.PressScale.round)end end)
 button.Activated:Connect(function()Kit.openHelp(id)end)
 return api
end

-- options: title, eyebrow (regular only), wallet (false hides the capsule), compact,
-- width (W), left (title x, default 24), onBack, tint (T5: a Kit.Tint key or Color3
-- for the dot + eyebrow and the title squiggle), help (R3.8: a HowItWorks id, or false;
-- default from the tint key). Returns {root, title, eyebrow,
-- wallet = {root, amount, set}, back = Kit.backArrow api, help = {root, id} or nil,
-- layout(W, left), setTitle}.
Kit.PlatePad=9
Kit.PlateLip=2
function Kit.header(parent,options)
 options=options or {}
 local compact=options.compact==true
 local api={compact=compact,W=options.width or 848,left=options.left or 24}
 local holder=Kit.frame(parent,"Header",nil,UDim2.new(),UDim2.fromOffset(api.W,if compact then 60 else 84))
 api.root=holder
 api.eyebrow=Kit.text(holder,"Label",options.eyebrow or "","dim",{Name="Eyebrow",TextTruncate=Enum.TextTruncate.AtEnd})
 api.title=Kit.text(holder,"Title",options.title or "","text",{Name="Title",TextSize=if compact then 20 else 26,TextTruncate=Enum.TextTruncate.AtEnd})
 -- Toy Shell 3.6: a header plate behind the title in the screen's tint (the deck's tag
 -- without one): ink outline, 2 px lip, ink title and a four-point sparkle after it. The
 -- title keeps its rect; the plate follows the text and stops where the title stops.
 local tint=if options.tint then tintColor(options.tint)else nil
 local plate=Kit.frame(holder,"TitlePlate",nil,UDim2.new(),UDim2.fromOffset(10,10),10)
 plate.BackgroundTransparency=0;plate.ZIndex=api.title.ZIndex;api.title.ZIndex=plate.ZIndex+2
 local plateFace=Kit.frame(plate,"Face",nil,UDim2.new(),UDim2.new(1,0,1,-Kit.PlateLip),10)
 plateFace.BackgroundTransparency=0;plateFace.ZIndex=plate.ZIndex
 Kit.stroke(plate)
 Kit.inner(node("UIStroke",plateFace,{Name="FaceStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2,Color=Kit.Color.ink}))
 if tint then
  paint(plateFace,"BackgroundColor3",function()return tint end)
  paint(plate,"BackgroundColor3",function()return tint:Lerp(Kit.color("ink"),.32)end)
 else paint(plateFace,"BackgroundColor3","tag");paint(plate,"BackgroundColor3","tagLip")end
 local sparkle=Kit.icon(plate,"sparkle",if compact then 11 else 13,"ink");sparkle.AnchorPoint=Vector2.new(1,.5);sparkle.ZIndex=plate.ZIndex+1
 for _,part in ipairs(sparkle:GetDescendants())do if part:IsA("GuiObject")then part.ZIndex=plate.ZIndex+1 end end
 paint(api.title,"TextColor3","ink")
 api.plate=plate
 local function placePlate()
  local g=api.geometry;if not g then return end
  local text=api.title.Text
  local textW=if text=="" then 0 else math.ceil(Kit.measure(text,"Title",api.title.TextSize).X)
  local pad=Kit.PlatePad
  local spark=sparkle.Size.X.Offset
  local h=if compact then 30 else 38
  local room=g.title.w+pad
  local withSpark=textW+pad*2+spark+4<=room+pad
  local w=math.min(textW+pad*2+(if withSpark then spark+4 else 0),room)
  plate.Position=UDim2.fromOffset(g.title.x-pad,math.floor(g.title.y+g.title.h/2-h/2+.5))
  plate.Size=UDim2.fromOffset(math.max(0,w),h)
  plate.Visible=api.title.Visible and textW>0 and w>=pad*2
  sparkle.Visible=withSpark
  sparkle.Position=UDim2.new(1,-pad+2,.5,-1)
 end
 api.title:GetPropertyChangedSignal("Text"):Connect(placePlate)
 api.title:GetPropertyChangedSignal("Visible"):Connect(placePlate)
 api.title:GetPropertyChangedSignal("TextSize"):Connect(placePlate)
 local inner
 if options.wallet~=false then inner=Kit.wallet(holder,if compact then 36 else 44,{tap=true});inner.root.AnchorPoint=Vector2.zero end
 local back=Kit.backArrow(holder,compact,{header=true});back.root.AnchorPoint=Vector2.zero;back.root.ZIndex=holder.ZIndex+5
 api.back=back
 -- R3.8: the machine's "How it works" circle, from options.help or the tint's family.
 local helpId=Kit.helpIdFor(options)
 if helpId then api.help=Kit.helpButton(holder,compact,helpId);api.help.root.ZIndex=holder.ZIndex+5;api.helpId=helpId end
 local function place(object,r)object.Position=UDim2.fromOffset(r.x,r.y);object.Size=UDim2.fromOffset(r.w,r.h)end
 function api.layout(W,left)
  api.W=W or api.W;api.left=left or api.left
  holder.Size=UDim2.fromOffset(api.W,if compact then 60 else 84)
  local g=Kit.headerGeometry(api.W,compact,inner and inner.root.Size.X.Offset or nil,api.left,api.help~=nil)
  api.geometry=g
  place(api.title,g.title)
  api.eyebrow.Visible=g.eyebrow~=nil and api.eyebrow.Text~=""
  if g.eyebrow then place(api.eyebrow,g.eyebrow)end
  if inner then place(inner.root,g.wallet)end
  if api.help and g.helpHit then api.help.root.Position=UDim2.fromOffset(g.helpHit.x,g.helpHit.y)end
  back.root.Position=UDim2.fromOffset(g.backHit.x,g.backHit.y)
  if api.squiggle then api.squiggle.update()end
  placePlate()
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
 back.root:SetAttribute("ClickSound","back") -- UIClick: Back's own cue
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
 -- Toy Shell: the bezel is the ink rim around the glass.
 outer.BackgroundTransparency=0;paint(outer,"BackgroundColor3","ink")
 Kit.stroke(outer,"ink",1,0)
 local inner=Kit.frame(outer,"Glass",role or "panel",UDim2.fromOffset(bezel,bezel),UDim2.fromOffset(r.w,r.h),radius)
 Kit.stroke(inner);Kit.setSurface(inner,"dark")
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
-- Menu sheet (section 5) in a root of W x H: rim 0..6 (whatever is behind), the bezel
-- at 6 (Toy Shell: the shell's darker lip, 4 px deeper at the bottom inside the rim), the
-- shell sheet at 8 with its 3 px ink outline and the moving checker, header hairline at y 60.
Kit.SheetLip=4
function Kit.sheet(parent,W,H)
 -- Spencer 2026-11-21 (phone): "fix those sharp unrounded corners at the bottom of each ui". The
 -- lip was one frame 4 px taller than the rim, so its 18 px arcs sat off the sheet's and left a
 -- dark wedge at each bottom corner. Now, like a Kit button's Edge, the lip is a copy of the rim
 -- shifted down SheetLip px: its bottom corners follow the sheet's curve exactly.
 local lip=Kit.frame(parent,"SheetLipBand",nil,UDim2.fromOffset(6,6+Kit.SheetLip),UDim2.fromOffset(W-12,H-12),18)
 lip.BackgroundTransparency=0;paint(lip,"BackgroundColor3","shellLip");Kit.stroke(lip,"ink",2,0)
 local bezel=Kit.frame(parent,"SheetBezel",nil,UDim2.fromOffset(6,6),UDim2.fromOffset(W-12,H-12),18)
 bezel.BackgroundTransparency=0;paint(bezel,"BackgroundColor3","shellLip");Kit.stroke(bezel,"ink",2,0)
 lip.ZIndex=bezel.ZIndex-1 -- under the rim (children of a Sibling gui still draw over their parent)
 local sheet=Kit.frame(parent,"Sheet","panel",UDim2.fromOffset(8,8),UDim2.fromOffset(W-16,H-16),16);Kit.stroke(sheet,nil,Kit.Stroke.sheet)
 Kit.setSurface(sheet,"dark")
 local tint=Kit.frame(sheet,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1),16);tint.BackgroundTransparency=1;tint.BackgroundColor3=Color3.new(1,1,1)
 node("UIGradient",tint,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 Kit.shellPattern(sheet,16)
 local hair=Kit.frame(parent,"HeaderHairline",nil,UDim2.fromOffset(20,60),UDim2.fromOffset(W-40,1))
 hair.BackgroundTransparency=1;hair.BackgroundColor3=Color3.new(1,1,1);hair.ZIndex=sheet.ZIndex+3
 return sheet,bezel
end

-- ── The moving checker (3.3, R1.6) ─────────────────────────────────────────
-- One tiled ImageLabel per shell surface: a 32 px two-tone checker (white on transparent,
-- 9% over the shell) drifting 8 px/s down and to the right, one tile every 4 s, by one
-- linear looping tween in the engine (no per-frame Lua). It sits in a rectangular clip
-- holder inset ceil(r * (1 - 1/sqrt 2)) px: ClipsDescendants ignores UICorner (step 0
-- spike), and that inset keeps the rectangle inside the rounded corners, so the pattern
-- never shows past them and no CanvasGroup is needed. A static shell-coloured fade above
-- it takes the pattern from full strength at the top to 35% at the bottom; tiles, trays
-- and text above cover it. Still (resting at offset 0) under Reduced Motion or the game's
-- Motion: Low; paused while the surface or its ScreenGui is hidden; gone with it.
Kit.Checker=table.freeze({image="rbxassetid://71708936221007",tile=32,period=4,transparency=.91,fadeTo=.35})
Kit.reducedEffects=false
local patterns=setmetatable({},{__mode="k"})
function Kit.patternStill()return Kit.reduced()or Kit.reducedEffects==true end
-- The game's own Motion setting (board attribute ReducedEffects); init.client keeps it.
function Kit.setReducedEffects(on)
 Kit.reducedEffects=on==true
 for ctl in pairs(patterns)do ctl.sync()end
end
-- Roblox's Reduced Motion turned on or off mid-session stops or restarts every live checker.
GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()for ctl in pairs(patterns)do ctl.sync()end end)
function Kit.patternInset(radius)return math.ceil((radius or 0)*(1-1/math.sqrt(2)))end
local function cornerOffset(frame)
 local c=frame and frame:FindFirstChildOfClass("UICorner")
 if not c then return nil end
 if c.CornerRadius.Scale>0 then return math.floor(math.min(frame.AbsoluteSize.X,frame.AbsoluteSize.Y)*c.CornerRadius.Scale)end
 return c.CornerRadius.Offset
end
-- Pure-ish: is `node` part of the Pocket Deck's own screen (a PlateSurface root)?
function Kit.onDeckScreen(node)
 local n=node
 while n do if n:GetAttribute("PlateSurface")==true then return true end;n=n.Parent end
 return false
end
function Kit.shellPattern(surface,radius)
 -- Never on the deck's LCD (its results, picker and pause sheets): R1.6 "Never".
 if not surface or Kit.onDeckScreen(surface)then return nil end
 local existing=surface:FindFirstChild("ShellPattern")
 if existing then for ctl in pairs(patterns)do if ctl.holder==existing then return ctl end end end
 -- A transparent content frame over a menu root takes the root's corner and outline.
 local root=if surface.BackgroundTransparency>=1 and surface.Parent and surface.Parent:IsA("GuiObject")then surface.Parent else surface
 radius=radius or cornerOffset(surface)or cornerOffset(root)or 16
 local rootStroke=root:FindFirstChild("KitStroke")
 if rootStroke then rootStroke.Thickness=Kit.Stroke.sheet end
 local C=Kit.Checker
 -- Spencer 2026-11-21: the inset rectangle's corners touched the rounded edge exactly, so they
 -- covered the surface's ink outline right at the curve and read as square corners. Inset by
 -- the outline too (plus 1 px), so the pattern stays inside the outline everywhere.
 local outline=root:FindFirstChild("KitStroke")
 local pad=Kit.patternInset(radius)+(if outline then math.ceil(outline.Thickness) else 0)+1
 -- Lowest of its siblings in a Sibling gui (cards, text and wells all draw over it); the
 -- fade above the checker inside the holder. A Global gui keeps the surface's own layer.
 local gui=surface:FindFirstAncestorWhichIsA("LayerCollector")
 local sibling=gui==nil or gui.ZIndexBehavior==Enum.ZIndexBehavior.Sibling
 local z=surface.ZIndex
 if sibling then
  -- Below the surface's own layer and every child it has, so children made later (at the
  -- usual parent + 1, or even the parent's own ZIndex) all draw over it.
  z=surface.ZIndex-1
  for _,child in ipairs(surface:GetChildren())do if child:IsA("GuiObject")and child.ZIndex<=z then z=child.ZIndex-1 end end
 end
 local holder=node("Frame",surface,{Name="ShellPattern",BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,
  Position=UDim2.fromOffset(pad,pad),Size=UDim2.new(1,-pad*2,1,-pad*2),ZIndex=z,Active=false,Selectable=false})
 local tile=node("ImageLabel",holder,{Name="Checker",BackgroundTransparency=1,Image=C.image,ImageTransparency=C.transparency,
  ImageColor3=Kit.Color.white,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(C.tile,C.tile),
  Size=UDim2.new(1,C.tile,1,C.tile),Position=UDim2.fromOffset(-C.tile,-C.tile),ZIndex=z,Active=false,Selectable=false})
 local fade=node("Frame",holder,{Name="Fade",BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=if sibling then z+1 else z,Active=false,Selectable=false})
 -- Spencer 2026-11-21 (phone, second look): the fade was painted "shell" while a phone sheet
 -- fills with its own "panel" shade, so the opaque bottom band read as a lighter rectangle with
 -- square ends. The fade now copies the surface's own fill, so it melts into it.
 local fill=if root.BackgroundTransparency<1 then root else surface
 -- `fill` can outlive this pattern (a desktop root whose content is rebuilt), so the link is
 -- dropped with it (review 2026-11-22: one connection and one Fade leaked per rebuild).
 local fillLink
 local function watchFill()
  fade.BackgroundColor3=fill.BackgroundColor3
  if not fillLink then fillLink=fill:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()fade.BackgroundColor3=fill.BackgroundColor3 end)end
 end
 watchFill()
 local gradient=node("UIGradient",fade,{Rotation=90,Transparency=NumberSequence.new(1,C.fadeTo)})
 -- Spencer 2026-11-21: the checker is a rectangle inside a rounded surface, so its square
 -- bottom corners read as "unrounded". Over the last FadeBand px (two corner radii) the fade
 -- turns fully shell-coloured, so the pattern is gone before the curve starts.
 local band=math.max(12,(radius or 16)*2)
 local function fitFade()
  local h=holder.AbsoluteSize.Y
  if h<=band*2 then gradient.Transparency=NumberSequence.new(1,C.fadeTo);return end
  local at=1-band/h
  gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),
   NumberSequenceKeypoint.new(at,1+(C.fadeTo-1)*at),NumberSequenceKeypoint.new(1,0)})
 end
 holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitFade)
 fitFade()
 holder:SetAttribute("ShellPattern",true)
 local ctl={holder=holder,tile=tile,fade=fade,running=false}
 local tween,links=nil,{}
 local function shown()
  local n=holder
  while n and not n:IsA("LayerCollector")do
   if n:IsA("GuiObject")and not n.Visible then return false end
   n=n.Parent
  end
  return n~=nil and(not n:IsA("ScreenGui")or n.Enabled)
 end
 function ctl.sync()
  if not holder.Parent then return end
  local still=Kit.patternStill()
  local run=not still and shown()
  if still then
   if tween then tween:Cancel();tween=nil end
   tile.Position=UDim2.fromOffset(-C.tile,-C.tile)
  elseif run then
   if not tween then
    tile.Position=UDim2.fromOffset(-C.tile,-C.tile)
    tween=TweenService:Create(tile,TweenInfo.new(C.period,Enum.EasingStyle.Linear,Enum.EasingDirection.In,-1),{Position=UDim2.fromOffset(0,0)})
   end
   tween:Play()
  elseif tween then tween:Pause()end
  ctl.running=run
  holder:SetAttribute("PatternRunning",run)
 end
 local function unwire()for _,link in ipairs(links)do link:Disconnect()end;table.clear(links)end
 local function wire()
  unwire()
  local n=holder.Parent
  while n and not n:IsA("LayerCollector")do
   if n:IsA("GuiObject")then table.insert(links,n:GetPropertyChangedSignal("Visible"):Connect(ctl.sync))end
   n=n.Parent
  end
  if n and n:IsA("ScreenGui")then table.insert(links,n:GetPropertyChangedSignal("Enabled"):Connect(ctl.sync))end
 end
 function ctl.destroy()
  unwire();patterns[ctl]=nil
  if fillLink then fillLink:Disconnect();fillLink=nil end
  if tween then tween:Cancel();tween=nil end
 end
 function ctl.watchingFill()return fillLink~=nil end -- specs
 holder.AncestryChanged:Connect(function()if holder.Parent then patterns[ctl]=true;watchFill();wire();ctl.sync()else ctl.destroy()end end)
 holder.Destroying:Connect(ctl.destroy)
 patterns[ctl]=true
 wire();ctl.sync()
 return ctl
end
-- Live moving patterns (budget: one sheet on screen at a time).
function Kit.patternCount()local n=0;for ctl in pairs(patterns)do if ctl.holder.Parent and ctl.running then n+=1 end end;return n end
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
-- Pure (Studio R15, the capsule shot): px a covering frame is slid down for its `CoverShift` attribute (0 home, 1 the
-- screen's height plus 40 px, fully off the bottom, as the tucked panel). Anything else is 0.
function Kit.coverShift(screenHeight,shift)
 if type(shift)~="number"or shift~=shift or shift<=0 or type(screenHeight)~="number"then return 0 end
 return math.floor(math.min(shift,1)*(screenHeight+40))
end
-- Keeps `frame` covering the whole screen whatever insets its ScreenGui uses (slid down by its CoverShift attribute).
function Kit.coverScreen(frame)
 local probe=Kit.screenProbe(frame)
 if not probe then frame.Position=UDim2.new();frame.Size=UDim2.fromScale(1,1);return false end
 local function sync()
  local parent=frame.Parent
  if not parent or not parent:IsA("GuiBase2d")then return end
  local position,size=Kit.coverRect(probe.AbsolutePosition,probe.AbsoluteSize,parent.AbsolutePosition)
  position=position+UDim2.fromOffset(0,Kit.coverShift(probe.AbsoluteSize.Y,frame:GetAttribute("CoverShift")))
  if frame.Position~=position then frame.Position=position end
  if frame.Size~=size then frame.Size=size end
 end
 local links={}
 local function watch(signal)table.insert(links,signal:Connect(sync))end
 watch(probe:GetPropertyChangedSignal("AbsoluteSize"));watch(probe:GetPropertyChangedSignal("AbsolutePosition"))
 local parent=frame.Parent
 if parent and parent:IsA("GuiBase2d")then watch(parent:GetPropertyChangedSignal("AbsolutePosition"))end
 watch(frame:GetPropertyChangedSignal("Visible"))
 watch(frame:GetAttributeChangedSignal("CoverShift"))
 frame.Destroying:Connect(function()for _,link in ipairs(links)do link:Disconnect()end end)
 frame:SetAttribute("CoversScreen",true)
 sync();return true
end
-- R3.2: where a phone sheet starts in `host`: 2 px under the Roblox controls,
-- measured from the real screen top (the ScreenInsets.None probe), so a host that
-- already sits below the controls (an inset ScreenGui, the safe overlay) does not
-- add the keep-out a second time. kh defaults to Kit.keepOut().
function Kit.sheetTop(host,kh)
 if not kh then local _;_,kh=Kit.keepOut()end
 local want=kh+2
 local probe=host and Kit.screenProbe(host)
 if not probe then return want end
 local below=host.AbsolutePosition.Y-probe.AbsolutePosition.Y
 return math.max(0,math.floor(want-below+.5))
end
-- R3.2: room inside a ScrollingFrame for the selection strokes, tile lips and card
-- shadows of its first and last rows (a UIPadding of `pad` on every side). Callers
-- add 2 * pad to their CanvasSize (Kit.scrollInset returns pad) and keep children at
-- their own 0-based positions. AutomaticCanvasSize already counts the padding.
Kit.ScrollInset=4
function Kit.scrollInset(scroll,pad)
 pad=pad or Kit.ScrollInset
 local inset=scroll:FindFirstChild("ScrollInset")or node("UIPadding",scroll,{Name="ScrollInset"})
 inset.PaddingLeft,inset.PaddingRight=UDim.new(0,pad),UDim.new(0,pad)
 inset.PaddingTop,inset.PaddingBottom=UDim.new(0,pad),UDim.new(0,pad)
 scroll:SetAttribute("ScrollInset",pad)
 return pad
end
-- The same room without moving anything: the frame grows `pad` on every side and the
-- padding puts its children back where they were (callers still add 2 * pad to a
-- CanvasSize they set themselves). Applied once per frame.
function Kit.scrollBleed(scroll,pad)
 pad=pad or Kit.ScrollInset
 if scroll:GetAttribute("ScrollBleed")==nil then
  scroll.Position=scroll.Position-UDim2.fromOffset(pad,pad);scroll.Size=scroll.Size+UDim2.fromOffset(pad*2,pad*2)
  scroll:SetAttribute("ScrollBleed",pad)
 end
 return Kit.scrollInset(scroll,pad)
end
-- A black full-screen shade, hidden until Kit.shadeOpen.
function Kit.modalShade(host,name,zIndex)
 local shade=Kit.frame(host,name,nil,UDim2.new(),UDim2.fromScale(1,1))
 shade.BackgroundTransparency=Kit.ShadeAlpha;shade.BackgroundColor3=Color3.new(0,0,0);shade.Active=true;shade.Visible=false
 shade.ZIndex=zIndex or 30;shade:SetAttribute("ShadeAlpha",Kit.ShadeAlpha)
 Kit.coverScreen(shade)
 return shade
end
-- Close plate (step 3). The close has already happened; this only paints where the screen was: one pooled
-- plate, .35 to clear and 4% smaller in .12 s. Called first thing by the handlers that mean "the player
-- closed this", while the screen still shows; drawn on the next Heartbeat only when the garden is bare.
-- QA-R2-LOOK 1: no spring on the way out: .12 s Quad In to .94 and 10 px down, fading (closing stays snappy).
Kit.Depart={alpha=.35,shrink=.06,drop=10,time=.12,displayOrder=20}
local shadeSerial,departToken=0,0
local ghost -- {gui, plate, corner, tween, link}
function Kit.inRoom()
 local boards=game:GetService("ReplicatedStorage"):FindFirstChild("EggDropBoards")
 local player=game:GetService("Players").LocalPlayer
 local board=boards and player and boards:FindFirstChild(tostring(player.UserId))
 return board~=nil and board:GetAttribute("Mode")=="Room"
end
function Kit.cutDepart()
 if not ghost then return end
 if ghost.link then ghost.link:Disconnect();ghost.link=nil end
 if ghost.tween then ghost.tween:Cancel();ghost.tween=nil end
 ghost.gui.Enabled=false
end
local function departBlocked(serial)
 return serial~=shadeSerial or Kit.shadeTop()~=nil or not Kit.alive("close")or not Kit.inRoom()
end
local function drawDepart(holder,shape,serial)
 if not ghost or not ghost.plate.Parent or ghost.gui.Parent~=holder then
  if ghost then Kit.cutDepart();ghost.gui:Destroy()end
  local gui=node("ScreenGui",holder,{Name="EggDropDepart",ResetOnSpawn=false,ScreenInsets=Enum.ScreenInsets.None,ClipToDeviceSafeArea=false,
   DisplayOrder=Kit.Depart.displayOrder,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,Enabled=false})
  local plate=node("Frame",gui,{Name="Plate",BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),Active=false,Selectable=false,Interactable=false})
  ghost={gui=gui,plate=plate,corner=node("UICorner",plate,{})}
 end
 Kit.cutDepart()
 local plate=ghost.plate
 plate.Position=shape.position;plate.Size=shape.size;plate.BackgroundColor3=shape.color;plate.BackgroundTransparency=Kit.Depart.alpha
 ghost.corner.CornerRadius=UDim.new(0,shape.radius)
 ghost.gui.Enabled=true
 local k=1-Kit.Depart.shrink
 ghost.tween=TweenService:Create(plate,TweenInfo.new(Kit.Depart.time,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
  {BackgroundTransparency=1,Size=UDim2.fromOffset(shape.size.X.Offset*k,shape.size.Y.Offset*k),Position=shape.position+UDim2.fromOffset(0,Kit.Depart.drop or 0)})
 local began=os.clock()
 ghost.link=game:GetService("RunService").Heartbeat:Connect(function()
  if os.clock()-began>=Kit.Depart.time+.02 or departBlocked(serial)then Kit.cutDepart()end
 end)
 ghost.tween:Play()
end
Kit.depart=paintSafely("depart",false,function(root)
 if not root or not Kit.alive("close")or not Kit.inRoom()or Spring.stateOf(root)~="ok"then return false end
 local gui=root:FindFirstAncestorOfClass("ScreenGui");local holder=gui and gui.Parent
 local probe=Kit.screenProbe(root)
 if not holder or not probe then return false end
 -- A phone screen's root is clear: its sheet is the plate.
 local face=if root.BackgroundTransparency<1 then root else root:FindFirstChild("Sheet",true)or root
 local position,size=Kit.coverRect(face.AbsolutePosition,face.AbsoluteSize,probe.AbsolutePosition)
 local corner=face:FindFirstChildOfClass("UICorner");local scale=root:FindFirstChildOfClass("UIScale")
 local shape={size=size,position=position+UDim2.fromOffset(size.X.Offset/2,size.Y.Offset/2),color=face.BackgroundColor3,
  radius=(if corner then corner.CornerRadius.Offset else 16)*(if scale then scale.Scale else 1)}
 departToken+=1
 local serial,token=shadeSerial,departToken
 game:GetService("RunService").Heartbeat:Once(function()
  if token~=departToken or departBlocked(serial)or Spring.stateOf(root)=="ok"or not holder.Parent then return end
  local ok,problem=pcall(drawDepart,holder,shape,serial)
  if not ok then warn("[Kit.depart] "..tostring(problem))end
 end)
 return true
end)
local shadeStack={}
-- QA v2 R3.1: one full-screen shade per open screen, always, on phones too. A screen
-- that asks for a clear shade (ShadeAlpha 1, the old phone-sheet rule) still dims at
-- Kit.ShadeAlpha; only a shade marked ShadeClear (a screen that paints the whole
-- screen itself) stays clear.
function Kit.shadeAlphaOf(shade)
 local alpha=shade:GetAttribute("ShadeAlpha")or Kit.ShadeAlpha
 if alpha>=1 and shade:GetAttribute("ShadeClear")~=true then alpha=Kit.ShadeAlpha end
 return alpha
end
local function paintShades()
 for i=#shadeStack,1,-1 do
  local entry=shadeStack[i]
  if not entry.shade.Parent then table.remove(shadeStack,i)end
 end
 for i,entry in ipairs(shadeStack)do
  local top=i==#shadeStack
  entry.shade.BackgroundTransparency=if top then Kit.shadeAlphaOf(entry.shade)else 1
  entry.shade:SetAttribute("ShadeCovered",not top)
  -- An overlay shade (R3.8 "How it works" cards) dims over a screen without hiding it:
  -- the screens under it go clear but are not told they are covered.
  local hidden=false
  for j=i+1,#shadeStack do if not shadeStack[j].overlay then hidden=true;break end end
  if entry.covered~=hidden then
   local first=entry.covered==nil
   entry.covered=hidden
   if entry.onCovered and not(first and not hidden)then task.spawn(entry.onCovered,hidden)end
  end
 end
end
-- owner: any key (the screen object). onCovered(covered) runs when a later shade
-- opens over this one (true) and when it closes again (false).
-- Opening again while already open keeps the owner's place in the stack (a rebuilt
-- shade frame swaps in), so a refresh under a child screen never jumps above it.
-- options.overlay: this shade dims over the screens under it without covering them.
function Kit.shadeOpen(owner,shade,onCovered,options)
 shadeSerial+=1;Kit.cutDepart()
 local entry
 for _,e in ipairs(shadeStack)do if e.owner==owner then entry=e end end
 if entry then
  if entry.shade~=shade and entry.shade.Parent then entry.shade.Visible=false end
  entry.shade=shade;entry.onCovered=onCovered or entry.onCovered
 else entry={owner=owner,shade=shade,onCovered=onCovered};table.insert(shadeStack,entry)end
 entry.overlay=options~=nil and options.overlay==true
 shade.Visible=true;paintShades()
end
-- R3.1: a full-screen shade that follows `container`'s Visible (screens whose open
-- flag is their own container frame: the Deck style / Settings picker, the journal).
-- The shade is made in `host` (the container's parent by default) under the container.
function Kit.attachShade(owner,container,options)
 options=options or {}
 local host=options.host or container.Parent
 local shade=Kit.modalShade(host,options.name or(container.Name.."Shade"),options.zIndex or math.max(1,container.ZIndex-1))
 local function sync()
  if container.Visible and container.Parent then Kit.shadeOpen(owner,shade,options.onCovered)
  elseif Kit.shadeIsOpen(owner)then Kit.shadeClose(owner)end
 end
 container:GetPropertyChangedSignal("Visible"):Connect(sync)
 container.Destroying:Connect(function()Kit.shadeClose(owner);if shade.Parent then shade:Destroy()end end)
 sync()
 return shade
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
   if entry.shade.Parent then entry.shade.Visible=false;entry.shade.BackgroundTransparency=Kit.shadeAlphaOf(entry.shade)end
  end
 end
 if found then paintShades()end
 return found
end
function Kit.setShadeAlpha(shade,alpha)shade:SetAttribute("ShadeAlpha",alpha);paintShades()end
function Kit.shadeDepth()paintShades();return #shadeStack end
function Kit.shadeTop()
 -- A screen destroyed while open takes its shade with it (paintShades drops it on the next change).
 local popped=false
 while #shadeStack>0 and not shadeStack[#shadeStack].shade.Parent do table.remove(shadeStack);popped=true end
 if popped then paintShades()end
 local entry=shadeStack[#shadeStack];return entry and entry.owner,entry and entry.shade
end
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
