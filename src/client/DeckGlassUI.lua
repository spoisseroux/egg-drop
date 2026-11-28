-- Deck Aero glass, the client half (DECK-AERO-BRIEF sections 2, 4 and 5; the palette and numbers are Shared.DeckGlass).
-- Builds the glass on frames that already exist: no rect, hit area, focus order or copy changes. Every colour is bound
-- through DeckArt (Art.bind with a function that reads the equipped plate), so equipping a faceplate repaints the
-- frames, the UIGradient Colors and the UIStroke colours once (Art.applyTheme); the HUD is not rebuilt.
--   card     Glass.card(card, {radius, body, shadow, bounce}): white body + a 90-degree gradient, a 1.5 px rim with its own
--            gradient (replacing the ink outline), the gloss (top 46%, 10% to 4% white), the accent bounce (bottom 35%),
--            the static streak (also the sweep) and a shadow sibling 3 px under the card. The sink, the feel highlight
--            and the inner stroke are retired.
--   pill     a caps label's tab: a gel pill (full radius, the plate's pill colour mixed 55% to white -> pill, 1 px white at
--            .45, ink text, Builder Sans Bold 12). It changes colour only for state (GlassDone / GlassStatus /
--            GlassLive / GlassLow attributes, DeckGlass.pillState).
--   track    progress bars and the chain dots: full radius, the track colour, the fill a gradient (accent, or warn
--            when a claimable bar is full); lit dots warn with a 2 px white dot.
--   well     the board well's frame: wellTop -> well, a 1.5 px rim at .55. The board's own pixels do not change.
--   motion   the gloss sweep on a value change (one tween pair, at most once per card per 1.2 s) and two drifting bubbles
--            on Goals and Next (one looping tween each). Nothing under Reduced Motion, Motion: Low or a stepped-down
--            AliveBudget; never a per-frame write.
-- Everything answers false / does nothing while Alive "deckglass" (or "deckfeel") is off.
local TweenService=game:GetService("TweenService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Glass=require(Shared.DeckGlass)
local Themes=require(Shared.DeckThemes)
local Art=require(script.Parent.DeckArt)
local Kit=require(script.Parent.DeckKit)

local UI={}
local WHITE,BLACK=Color3.new(1,1,1),Color3.new(0,0,0)

function UI.on()return Glass.switch()end
-- The equipped plate's glass palette (DeckGlass.palette).
function UI.palette()return Glass.palette(Art.getTheme()or Themes.ById[Themes.Default])end

local function node(class,parent,props)
 local o=Instance.new(class)
 for k,v in pairs(props or {})do o[k]=v end
 o.Parent=parent
 return o
end
local function seq(a,b)return ColorSequence.new(a,b)end
-- Sets object[property] = fn() now and on every theme apply (replaces any binding Kit made for that property).
local function bind(object,property,fn)
 object[property]=fn()
 Art.bind(object,{[property]=fn})
 return object
end
UI.bind=bind
local function white()return WHITE end
local function corner(object,radius)
 local c=object:FindFirstChildOfClass("UICorner")or node("UICorner",object)
 c.CornerRadius=if typeof(radius)=="UDim"then radius else UDim.new(0,math.max(0,radius))
 return c
end
local function layer(card,name,props)
 local f=card:FindFirstChild(name)or node("Frame",card,{Name=name,BorderSizePixel=0,Active=false,Selectable=false})
 for k,v in pairs(props)do f[k]=v end
 return f
end
local function gradient(parent,name,rotation)
 return parent:FindFirstChild(name)or node("UIGradient",parent,{Name=name,Rotation=rotation or 90})
end

-- ── The card recipe ─────────────────────────────────────────────────────────────────────────────────────────────
-- A rim: the frame's KitStroke (or a new one) turned white with a gradient in `color` (default the palette's rim).
function UI.rim(frame,thickness,top,bottom,color,name)
 local stroke=frame:FindFirstChild(name or "KitStroke")or node("UIStroke",frame,{Name=name or "KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 Kit.inner(stroke)
 stroke.Enabled=true;stroke.Thickness=thickness;stroke.Transparency=0
 bind(stroke,"Color",white)
 local g=gradient(stroke,"GlassRim",90)
 g.Transparency=NumberSequence.new(top,bottom or top)
 bind(g,"Color",color or function()local p=UI.palette();return seq(p.rim,p.rim)end)
 return stroke
end
local function bodyDefault()local p=UI.palette();return seq(p.glassTop,p.glassBottom)end
-- opts: radius (px), body (fn -> ColorSequence), shadow (false: none), bounce (false: none).
function UI.card(card,opts)
 opts=opts or {}
 local C=Glass.Card
 local radius=opts.radius or Glass.cardRadius(opts.compact)
 local z=card.ZIndex
 corner(card,radius)
 card.BackgroundTransparency=0
 bind(card,"BackgroundColor3",white)
 for _,child in ipairs(card:GetChildren())do
  if child:IsA("UIGradient")and child.Name~="GlassBody"then child.Enabled=false end
 end
 bind(gradient(card,"GlassBody",90),"Color",opts.body or bodyDefault)
 local sink=card:FindFirstChild("TraySink");if sink then sink.Visible=false end
 for _,name in ipairs({"FeelHighlight","FeelInner"})do local o=card:FindFirstChild(name);if o then o:Destroy()end end
 UI.rim(card,C.rim,C.rimAlpha[1],C.rimAlpha[2])
 local G=C.gloss
 local gloss=layer(card,"GlassGloss",{BackgroundColor3=WHITE,BackgroundTransparency=0,ZIndex=z,
  Position=UDim2.fromOffset(G.inset,G.inset),Size=UDim2.new(1,-2*G.inset,G.height,-G.inset)})
 corner(gloss,radius-G.inset)
 gradient(gloss,"Fade",90).Transparency=NumberSequence.new(G.top,G.bottom)
 if opts.bounce~=false then
  local B=C.bounce
  local bounce=layer(card,"GlassBounce",{BackgroundTransparency=0,ZIndex=z,Position=UDim2.fromScale(0,1-B.height),Size=UDim2.fromScale(1,B.height)})
  corner(bounce,radius)
  bind(bounce,"BackgroundColor3",function()return UI.palette().accent end)
  gradient(bounce,"Fade",90).Transparency=NumberSequence.new(B.top,B.bottom)
 end
 local streak=layer(card,"GlassStreak",{BackgroundColor3=WHITE,BackgroundTransparency=0,ZIndex=z,Size=UDim2.fromScale(1,1)})
 corner(streak,radius)
 local keys={}
 for _,k in ipairs(C.streak.keys)do table.insert(keys,NumberSequenceKeypoint.new(k[1],k[2]))end
 local band=gradient(streak,"Band",C.streak.rotation)
 band.Transparency=NumberSequence.new(keys);band.Offset=Vector2.zero
 if opts.shadow~=false then UI.shadow(card,radius)end
 card:SetAttribute("Glass",true);card:SetAttribute("GlassRadius",radius)
 return card
end
-- The shadow: a sibling under the card (a child would draw over it), following its rect and visibility.
function UI.shadow(card,radius)
 local parent=card.Parent;if not parent then return nil end
 local S=Glass.Card.shadow
 local name="GlassShadow"..card.Name
 local shadow=parent:FindFirstChild(name)
 if not shadow then
  shadow=node("Frame",parent,{Name=name,BackgroundColor3=BLACK,BorderSizePixel=0,Active=false,Selectable=false})
  shadow:SetAttribute("GlassShadow",true)
  local function follow()
   shadow.Position=card.Position+UDim2.fromOffset(0,S.offset);shadow.Size=card.Size;shadow.Visible=card.Visible
   shadow.ZIndex=math.max(1,card.ZIndex-1)
  end
  for _,property in ipairs({"Position","Size","Visible","ZIndex"})do card:GetPropertyChangedSignal(property):Connect(follow)end
  card.Destroying:Connect(function()shadow:Destroy()end)
  follow()
 end
 shadow.BackgroundTransparency=S.alpha
 corner(shadow,radius)
 return shadow
end
-- A glass card's radius changed (WelcomeDeck2's 12): the card, its layers and its shadow.
function UI.setRadius(card,radius)
 if not card or not card:GetAttribute("Glass")then return end
 corner(card,radius)
 local gloss=card:FindFirstChild("GlassGloss");if gloss then corner(gloss,radius-Glass.Card.gloss.inset)end
 for _,name in ipairs({"GlassBounce","GlassStreak"})do local o=card:FindFirstChild(name);if o then corner(o,radius)end end
 local shadow=card.Parent and card.Parent:FindFirstChild("GlassShadow"..card.Name);if shadow then corner(shadow,radius)end
 card:SetAttribute("GlassRadius",radius)
end

-- ── Pills ───────────────────────────────────────────────────────────────────────────────────────────────────────
-- The pill's fill for its state (attributes on the tab).
function UI.pillColors(tab)
 local p=UI.palette()
 local state=Glass.pillState({done=tab:GetAttribute("GlassDone"),status=tab:GetAttribute("GlassStatus"),
  live=tab:GetAttribute("GlassLive"),low=tab:GetAttribute("GlassLow")})
 if state then return seq(p[state.."Top"],p[state])end
 return seq(p.pillTop,p.pill)
end
function UI.pill(label,compact)
 label:SetAttribute("FeelPill",if compact then "compact"else "regular")
 -- Caps labels are Builder Sans Bold 12; the level's name keeps its display face and size (15 and up), its pill grows.
 local caps=label:GetAttribute("KitRole")=="Label"
 if caps then label.TextSize=Glass.Pill.size end
 label:SetAttribute("FeelPillH",if caps then Glass.pillHeight(compact)else math.max(Glass.pillHeight(compact),label.TextSize+6))
 local tab=Kit.hudLabel(label,WHITE)
 tab:SetAttribute("FixedTab",true)
 tab:SetAttribute("Glass",true)
 bind(tab,"BackgroundColor3",white)
 bind(gradient(tab,"GlassFill",90),"Color",function()return UI.pillColors(tab)end)
 local stroke=tab:FindFirstChild("TabStroke")
 if stroke then stroke.Thickness=1;stroke.Transparency=Glass.Pill.stroke;bind(stroke,"Color",white)end
 bind(label,"TextColor3",function()return UI.palette().ink end)
 return tab
end
-- A pill's state flag (GlassDone, GlassStatus, GlassLive, GlassLow). Repaints only on a change.
function UI.setState(tab,key,value)
 if not tab or not tab:GetAttribute("Glass")then return false end
 value=value==true
 if(tab:GetAttribute(key)==true)==value then return false end
 tab:SetAttribute(key,value)
 local fill=tab:FindFirstChild("GlassFill");if fill then fill.Color=UI.pillColors(tab)end
 return true
end
-- The level's ★ ×n chip as a pill (it stays a pill whatever kind its screen asks for).
function UI.chip(chip,compact)
 if not chip or chip.glass then return end
 chip.glass=true
 local root,label=chip.root,chip.label
 local function dress()
  root.Rotation=0;root.BackgroundTransparency=0
  for _,name in ipairs({"StickerShadow","StickerFace"})do local o=root:FindFirstChild(name);if o then o.Visible=false end end
  bind(root,"BackgroundColor3",white)
  local stroke=root:FindFirstChild("KitStroke")
  if stroke then stroke.Enabled=true;stroke.Thickness=1;stroke.Transparency=Glass.Pill.stroke;bind(stroke,"Color",white)end
  bind(label,"TextColor3",function()return UI.palette().ink end)
 end
 corner(root,UDim.new(.5,0))
 bind(gradient(root,"GlassFill",90),"Color",function()local p=UI.palette();return seq(p.pillTop,p.pill)end)
 local set=chip.set
 if type(set)=="function"then chip.set=function(...)local out=set(...);dress();return out end end
 dress()
end

-- ── Tracks, dots and checks ─────────────────────────────────────────────────────────────────────────────────────
local function trackColor()return UI.palette().track end
function UI.track(api)
 if not api or api.glass then return end
 api.glass=true
 local track=api.root
 if api.cells then
  local set=api.set
  for _,cell in ipairs(api.cells)do
   corner(cell,UDim.new(.5,0))
   local s=cell:FindFirstChild("KitStroke");if s then s.Enabled=false end
   local D=Glass.Track.dot
   layer(cell,"GlassDot",{BackgroundColor3=WHITE,BackgroundTransparency=0,ZIndex=cell.ZIndex,Position=UDim2.fromOffset(D+1,1),
    Size=UDim2.fromOffset(D,D),Visible=false})
   corner(cell.GlassDot,UDim.new(.5,0))
  end
  api.set=function(value)
   set(value)
   for index,cell in ipairs(api.cells)do
    local on=index<=(value or 0)
    bind(cell,"BackgroundColor3",if on then function()return UI.palette().warn end else trackColor)
    local s=cell:FindFirstChild("KitStroke");if s then s.Enabled=false end
    cell.GlassDot.Visible=on
   end
  end
  api.set(0)
  return
 end
 corner(track,UDim.new(.5,0))
 local s=track:FindFirstChild("KitStroke");if s then s.Enabled=false end
 bind(track,"BackgroundColor3",trackColor)
 local fill=api.fill
 local band=gradient(fill,"GlassFill",90)
 local function fillColors()
  local p=UI.palette()
  if fill:GetAttribute("GlassClaim")then return seq(p.warnFillTop,p.warn)end
  return seq(p.fillTop,p.accent)
 end
 bind(band,"Color",fillColors)
 bind(fill,"BackgroundColor3",white)
 local set=api.set
 api.set=function(value,maximum,claimable,animate)
  set(value,maximum,claimable,animate)
  local claim=claimable==true and api.value>=1
  bind(fill,"BackgroundColor3",white)
  if(fill:GetAttribute("GlassClaim")==true)~=claim then fill:SetAttribute("GlassClaim",claim);band.Color=fillColors()end
 end
end
-- A goal's check: the open ring white at 55%, done a `good` disc (the ink check stays).
function UI.check(api)
 if not api or api.glass then return end
 api.glass=true
 local disc=api.root
 local ring=disc:FindFirstChild("Ring")
 if ring then ring.Color=WHITE;ring.Transparency=Glass.Check.ring end
 local set=api.set
 api.set=function(done)
  set(done)
  if done then bind(disc,"BackgroundColor3",function()return UI.palette().good end)end
 end
end

-- ── The well's frame ────────────────────────────────────────────────────────────────────────────────────────────
function UI.well(well)
 if not well then return end
 well.BackgroundTransparency=0
 bind(well,"BackgroundColor3",white)
 bind(gradient(well,"GlassWell",90),"Color",function()local p=UI.palette();return seq(p.wellTop,p.well)end)
 UI.rim(well,Glass.Well.rim,Glass.Well.rimAlpha,nil,nil,"GlassWellRim")
 well:SetAttribute("Glass",true)
end

-- ── Numbers ─────────────────────────────────────────────────────────────────────────────────────────────────────
UI.CounterRoles=table.freeze({Counter="HudCounter",CounterL="HudCounterL"})
function UI.counters(root)
 local n=0
 for _,d in ipairs(root:GetDescendants())do
  local role=d:IsA("TextLabel")and UI.CounterRoles[d:GetAttribute("KitRole")or ""]
  if role then Kit.setFontRole(d,role);n+=1 end
 end
 return n
end

-- ── Motion ──────────────────────────────────────────────────────────────────────────────────────────────────────
function UI.motion(compact)
 local ok,Budget=pcall(require,script.Parent.AliveBudget)
 local level=if ok then Budget.level()else 0
 return Glass.motion(Kit.reduced()or Kit.reducedEffects==true,level,compact)
end
local swept=setmetatable({},{__mode="k"})
-- One gloss sweep across `card` (its Streak's Offset 0 -> 1, then in from -1 -> 0; .35 s in all).
function UI.sweep(card)
 if not card or not card:GetAttribute("Glass")or not UI.motion(false).sweep then return false end
 local streak=card:FindFirstChild("GlassStreak")
 local band=streak and streak:FindFirstChild("Band")
 if not band then return false end
 local now=os.clock()
 if not Glass.sweepDue(swept[card],now)then return false end
 swept[card]=now
 local half=Glass.Motion.sweep/2
 local out=TweenService:Create(band,TweenInfo.new(half,Enum.EasingStyle.Sine,Enum.EasingDirection.In),{Offset=Vector2.new(1,0)})
 out.Completed:Once(function(state)
  if not band.Parent then return end
  if state~=Enum.PlaybackState.Completed then band.Offset=Vector2.zero;return end
  band.Offset=Vector2.new(-1,0)
  TweenService:Create(band,TweenInfo.new(half,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Offset=Vector2.zero}):Play()
 end)
 out:Play()
 return true
end
-- Two bubbles rising through `card` (clipped inside its corners), one looping tween each.
function UI.bubbles(card,radius)
 if not card or card:FindFirstChild("GlassBubbles")then return nil end
 local M=Glass.Motion
 local z=card.ZIndex
 local holder=node("Frame",card,{Name="GlassBubbles",BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true,Active=false,
  Selectable=false,ZIndex=z,Position=UDim2.fromOffset(0,radius),Size=UDim2.new(1,0,1,-2*radius)})
 for index,b in ipairs(M.bubbles)do
  local f=node("Frame",holder,{Name="Bubble"..index,BackgroundColor3=WHITE,BackgroundTransparency=M.bubbleAlpha,BorderSizePixel=0,
   AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(b.x,0,1,0),Size=UDim2.fromOffset(b.size,b.size),ZIndex=z,Active=false,Selectable=false})
  corner(f,UDim.new(.5,0))
  node("UIStroke",f,{Color=WHITE,Thickness=1,Transparency=M.bubbleRim,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  TweenService:Create(f,TweenInfo.new(b.period,Enum.EasingStyle.Linear,Enum.EasingDirection.In,-1),{Position=UDim2.new(b.x,0,0,-b.size)}):Play()
 end
 return holder
end

-- ── The round HUD (DeckFeelScreen:built calls this after its own polish) ─────────────────────────────────────────
-- cards: {name = card frame}; eyebrows: {name = eyebrow label}. Returns {name = pill tab}.
function UI.dressHud(screen,g,cards)
 local h=screen.hud
 local compact=g.phone==true or g.compact==true
 local radius=Glass.cardRadius(compact)
 local rects,byCard={},{}
 for _,card in pairs(cards)do
  local r={x=card.Position.X.Offset,y=card.Position.Y.Offset,w=card.Size.X.Offset,h=card.Size.Y.Offset}
  table.insert(rects,r);byCard[card]=r
 end
 for name,card in pairs(cards)do
  local r=if name=="QuestHandle"then 12 else radius
  UI.card(card,{radius=r,shadow=Glass.shadowWanted(Glass.gapBelow(byCard[card],rects))})
 end
 -- Every tabbed caps label (eyebrows, BALLS LEFT, THEN, the level's name) becomes a gel pill.
 local pills={}
 for _,d in ipairs(screen.hudRoot:GetDescendants())do
  if d:IsA("TextLabel")and d:GetAttribute("HudTab")and Kit.hudTabOf(d)then
   local tab=UI.pill(d,compact)
   local card=d.Parent
   if card and cards[card.Name]==card and not pills[card.Name]and d~=h.thenLabel then pills[card.Name]=tab end
  end
 end
 if h.diffChip then UI.chip(h.diffChip,compact)end
 UI.track(h.eggBar);UI.track(h.chainBar)
 for _,slot in ipairs(h.goals or {})do UI.track(slot.bar);UI.check(slot.check)end
 for _,slot in ipairs(h.daily or {})do UI.track(slot.bar)end
 UI.counters(screen.hudRoot)
 -- Rule 3: Stars gold as text only at 18 px and up; smaller, white (the star icon keeps the gold).
 if h.pays and not Glass.goldText(h.pays.TextSize)then bind(h.pays,"TextColor3",white)end
 UI.well(screen.well)
 if UI.motion(compact).bubbles then
  for name in pairs(Glass.Motion.bubbleCards)do local card=cards[name];if card then UI.bubbles(card,radius)end end
 end
 return pills
end

-- ── Keys ────────────────────────────────────────────────────────────────────────────────────────────────────────
-- The secondary key's face (#FFFFFF -> #DDEBFA, ink label) with a rim in `rim` (default 2 px `good`): the Welcome
-- deck's "Click to drop" pill (BoardHints). Returns a function that puts the old look back.
UI.Secondary=table.freeze({top=Color3.fromHex("#FFFFFF"),bottom=Color3.fromHex("#DDEBFA"),rim=2})
function UI.secondaryKey(face,label)
 face.BackgroundTransparency=0
 bind(face,"BackgroundColor3",white)
 local g=gradient(face,"GlassKey",90);g.Enabled=true
 g.Color=seq(UI.Secondary.top,UI.Secondary.bottom)
 local stroke=face:FindFirstChild("KitStroke")or node("UIStroke",face,{Name="KitStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 stroke.Thickness=UI.Secondary.rim;stroke.Transparency=0
 bind(stroke,"Color",function()return UI.palette().good end)
 if label then bind(label,"TextColor3",function()return UI.palette().ink end)end
end

return UI
