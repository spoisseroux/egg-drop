-- The notification row: "Toy tickets" (artifacts/v2-notifications-2026-11-20/NOTIFICATIONS-SPEC.md
-- section 1). One spatial owner above game menus. TopbarSafeInsets already maps Roblox's
-- unoccupied topbar rectangle; offsets below are local to that area, exactly once.
--
-- Each line is a small cream key (Kit.tile style: face, lip, 2 px ink outline) with a kind
-- disc, one line of text and a timer bar that drains to the left. Up to 4 timed tickets and
-- 1 status ticket (pinned left) show at once in an X-only ScrollingFrame; the rest wait in
-- NotificationQueue. Oldest left, newest right. Tickets are positioned by code (no layout)
-- so they tween; each ticket's instances are built once, reused while it shows and
-- destroyed after its dissolve. Nothing is allocated per frame.
local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local TextService=game:GetService("TextService")
local TweenService=game:GetService("TweenService")
local Queue=require(script.Parent.NotificationQueue)
local Kit=require(script.Parent.DeckKit)
local Rail={};local queue=Queue.new(24);local stopped=false;local connection
local gui,root,row,scroll,fade
-- QA v735 H5: a line that opens something on a tap (its own `activate`, or a notice card
-- named by `detail`, see NoticeCards) shows a chevron at its end: 6 px gap + 14 px chevron.
Rail.MoreWidth=20
-- QA v775's calm gap (one line, then 3 s of nothing) is retired by the spec; the hold while
-- a tip or notice card is open stays (Rail.held). Kept at 0 for old readers.
Rail.Gap=0
Rail.Gutter=8 -- the row's x inside the free top bar (and its right margin)
Rail.CardGap=6
Rail.MinWidth=96
Rail.MaxWidth=260
Rail.NarrowMaxWidth=220 -- when the free bar is narrower than NarrowBar
Rail.NarrowBar=600
Rail.Hit=44 -- touch hit area height (clamped to the bar)
Rail.FadeWidth=16 -- the edge fade over hidden content, each side
Rail.DragQuiet=2 -- no auto-scroll this long after the player dragged the row
-- Edge fade: a UIGradient on the row's CanvasGroup (a gradient on a CanvasGroup applies to
-- the whole rendered group, so it fades the tickets under it). If Studio shows it does not
-- mask the group, set this false: the ScrollingFrame's own clip stays (a hard edge).
-- Spencer 2026-11-20 (round 3): no fades on scrolling lists, so the row keeps a hard clip.
Rail.EdgeFade=false
Rail.Motion={enter=.22,leave=.25,slide=.2,scroll=.25,reduced=.15,press=.06,breathe=1.2}
-- Per bar height (spec "Card"): card height, lip, face, corner radius, disc, text size.
-- Round 3 (Spencer: the timer clipped the text): cards 4 px taller, the text sits in the face
-- above the timer, the timer 3 px over the face's bottom. `tight` keeps the old 32 px key for
-- a 32 to 33 px bar.
-- drop (beta (12) QA U1, Fable DASH-DECK-UI-LOOK.md): a timed card's disc, message, amount and chevron move down this
-- many px (they sat high in the face above the timer); a persistent card is already centred and keeps 0.
Rail.Sizes={
 full={card=44,lip=4,face=40,radius=12,disc=24,text=14,drop=2},
 compact={card=34,lip=3,face=31,radius=10,disc=20,text=13,drop=2},
 tight={card=32,lip=3,face=29,radius=10,disc=18,text=12,drop=1}}
-- Space under the text kept for the timer bar (3 px bar, 3 px under it, 2 px over it).
Rail.TimerRoom=8
-- Kinds (spec table): disc fill, icon (a Kit.icon name) or glyph, icon colour, timer bar fill.
Rail.Kinds={
 stars={disc="well",icon="star",color="stars",bar="stars"},
 done={disc="go",icon="check",color="ink",bar="go"},
 level={disc="selected",glyph="▲",color="ink",bar="go"},
 info={disc="tray",glyph="•",color="onShell",bar="inkSoft"},
 warning={disc="tomato",glyph="!",color="white",bar="tomato"}}
local How -- HowItWorks, required on first use (it requires DeckKit, which uses this rail)
function Rail.held()
 if How==nil then
  local module=script.Parent:FindFirstChild("HowItWorks")
  local ok,value=pcall(require,module)
  How=if module and ok and type(value)=="table"then value else false
 end
 if Rail.holder~=nil and Rail.holder()==true then return true end -- Garden Dash: notices wait for the race
 return How~=false and How.isOpen()==true
end
function Rail.tappable(data)return type(data)=="table"and(data.activate~=nil or type(data.detail)=="table")end
-- A tap on a ticket: its own action, else its notice card. True when something answered.
-- The ticket then dissolves; if a card opened (Rail.held) it waits under it until it closes.
-- A notice card that is already showing is left as it is (no second copy).
function Rail.activate(data)
 if type(data)~="table"then return false end
 if data.activate then return data.activate()~=false end
 local detail=data.detail
 if type(detail)~="table"then return false end
 local how=require(script.Parent.HowItWorks)
 if how.isOpen()and how.noticeId()==detail.id then return true end
 return how.openNotice(detail.id,{vars=detail.vars,run=detail.run})==true
end
-- Pure: the disc kind of a line (data.kind wins): Stars (amount or ★), done (✓ or none),
-- level up (▲), warning (!), else info (the line's own glyph on the info disc).
function Rail.kind(data)
 if type(data)~="table"then return "info"end
 if data.kind and Rail.Kinds[data.kind]then return data.kind end
 local icon=data.icon
 if data.amount~=nil or icon=="★"then return "stars"end
 if icon==nil or icon=="✓"then return "done"end
 if icon=="▲"then return "level"end
 if icon=="!"then return "warning"end
 return "info"
end
-- Pure: the card size for a free bar `height` (nil under 32 px: the row hides).
-- Pure: how far a card's content moves down (U1): the size's drop for a timed card, 0 for a persistent one.
function Rail.contentDrop(size,persistent)
 if persistent or type(size)~="table"then return 0 end
 return size.drop or 0
end
function Rail.size(height)
 if height>=56 then return Rail.Sizes.full end
 if height>=34 then return Rail.Sizes.compact end
 if height>=32 then return Rail.Sizes.tight end
 return nil
end
-- Pure: a ticket's geometry in a free bar of width x height for `contentWidth` (the text,
-- plus "+N" for Stars, see Rail.measure). `fits`: the row can draw a ticket here; `full`:
-- the whole line shows (else it is truncated at the end). width is clamped to 96..260
-- (220 on a free bar under 600 px). y is the card's top inside the bar.
function Rail.geometry(width,height,contentWidth,tappable)
 local size=Rail.size(height)
 if not size then return{fits=false,full=false,width=0,height=0,x=Rail.Gutter,y=0,room=0}end
 local cap=math.min(if width<Rail.NarrowBar then Rail.NarrowMaxWidth else Rail.MaxWidth,width-2*Rail.Gutter)
 local pad=8+size.disc+8+12+(if tappable then Rail.MoreWidth else 0)
 local desired=math.ceil(contentWidth or 0)+pad
 local w=math.clamp(desired,Rail.MinWidth,math.max(Rail.MinWidth,cap))
 return{fits=cap>=Rail.MinWidth,full=cap>=Rail.MinWidth and desired<=cap,width=w,height=size.card,size=size,room=w-pad,
  x=Rail.Gutter,y=if height>=56 then height-size.card-4 else math.max(0,math.floor((height-size.card)/2))}
end
local font=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.Medium)
-- Measured once per data table and text size (handle:update makes a new data table).
local measured=setmetatable({},{__mode="k"})
-- The message, its width, the "+N" (Stars) and its width, and their total content width.
function Rail.measure(data,textSize)
 textSize=textSize or 14
 local cached=measured[data]
 if cached and cached.size==textSize then return cached.text,cached.textW,cached.amount,cached.amountW,cached.content end
 local text=tostring(data.text or "")
 local w=TextService:GetTextSize(text,textSize,Enum.Font.BuilderSansMedium,Vector2.new(10000,40)).X
 local amount=if data.amount~=nil then "+"..Kit.formatStars(data.amount)else nil
 local aw=if amount then TextService:GetTextSize(amount,textSize,Enum.Font.FredokaOne,Vector2.new(10000,40)).X else 0
 local content=w+(if amount then 4+aw else 0)
 measured[data]={size=textSize,text=text,textW=w,amount=amount,amountW=aw,content=content}
 return text,w,amount,aw,content
end
local owners=setmetatable({},{__mode="k"})
local tickets={} -- [queue item] = ticket
local order={} -- tickets in slot order (leaving ones keep their slot until gone)
local function node(class,parent,props)
 local object=Instance.new(class);for k,v in pairs(props)do object[k]=v end;object.Parent=parent;return object
end
local function ease(alpha,style,direction)return TweenService:GetValue(math.clamp(alpha,0,1),style,direction)end
local Quad,Back,Out=Enum.EasingStyle.Quad,Enum.EasingStyle.Back,Enum.EasingDirection.Out
-- The transparent parts of a subtree, with their resting transparency (for the fades).
local function collect(object,parts)
 local function add(o,property)table.insert(parts,{o,property,o[property]})end
 for _,o in ipairs(object:GetDescendants())do
  if o:IsA("UIStroke")then add(o,"Transparency")
  elseif o:IsA("ImageLabel")then add(o,"ImageTransparency");if o.BackgroundTransparency<1 then add(o,"BackgroundTransparency")end
  elseif o:IsA("TextLabel")then add(o,"TextTransparency");if o.BackgroundTransparency<1 then add(o,"BackgroundTransparency")end
  elseif o:IsA("GuiObject")and o.BackgroundTransparency<1 then add(o,"BackgroundTransparency")end
 end
 return parts
end
local function apply(parts,alpha)
 for _,p in ipairs(parts)do p[1][p[2]]=1-(1-p[3])*alpha end
end
local lastScrollX,dragAt=0,-math.huge
local scrollFrom,scrollTo,scrollT=0,0,1
local function ensure()
 if stopped then return false end
 if gui and gui.Parent then return true end
 local p=Players.LocalPlayer;local pg=p and p:FindFirstChildOfClass("PlayerGui")
 if not pg then return false end
 gui=node("ScreenGui",pg,{Name="EggDropNotificationRail",ResetOnSpawn=false,DisplayOrder=100,
  ScreenInsets=Enum.ScreenInsets.TopbarSafeInsets,ClipToDeviceSafeArea=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 root=node("Frame",gui,{Name="FreeTopbarArea",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false})
 -- The row is only as wide as its tickets, so the bar beside it stays clickable.
 row=node("CanvasGroup",root,{Name="Row",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(0,0),Visible=false})
 fade=node("UIGradient",row,{Name="EdgeFade",Enabled=false})
 scroll=node("ScrollingFrame",row,{Name="Tickets",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),
  ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.X,CanvasSize=UDim2.new(0,0,1,0),
  AutomaticCanvasSize=Enum.AutomaticSize.None,ElasticBehavior=Enum.ElasticBehavior.Never,ClipsDescendants=true,Selectable=false})
 -- A scroll this rail did not make is the player's drag: hold the auto-scroll for a while.
 scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
  if math.abs(scroll.CanvasPosition.X-lastScrollX)>.5 then dragAt=os.clock();scrollT=1;lastScrollX=scroll.CanvasPosition.X end
 end)
 tickets={};order={}
 return true
end
-- Kind paint: the disc fill, the icon or glyph, the timer bar fill (only when it changes).
local function paintKind(t,kind,glyph)
 if t.kind==kind and t.glyphText==glyph then return end
 t.kind,t.glyphText=kind,glyph
 local spec=Rail.Kinds[kind]
 Kit.paint(t.disc,"BackgroundColor3",spec.disc)
 if t.icon then t.icon:Destroy();t.icon=nil end
 local d=t.discSize or Rail.Sizes.full.disc
 if spec.icon then
  t.icon=Kit.icon(t.disc,spec.icon,math.floor(d*(if spec.icon=="check"then .82 else .78)),spec.color)
  t.icon.AnchorPoint,t.icon.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
 else
  t.icon=node("TextLabel",t.disc,{Name="Glyph",BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
   Size=UDim2.fromScale(1,1),Text=glyph,FontFace=Kit.DisplayFace,TextSize=math.floor(d*.62),AutoLocalize=false,Active=false})
  Kit.paint(t.icon,"TextColor3",spec.color)
 end
 t.iconParts=collect(t.disc,{})
 -- The disc's own stroke is in the ticket's parts; the icon fades on its own (status breathes).
 for i=#t.iconParts,1,-1 do if t.iconParts[i][1]==t.discStroke then table.remove(t.iconParts,i)end end
 t.iconAlpha=nil
 t.barRole=nil
end
local function paintFace(t)
 local role=if t.hover then "white"elseif t.persistent then "selected"else "cream"
 if t.faceRole~=role then t.faceRole=role;Kit.paint(t.face,"BackgroundColor3",role)end
 local lipRole=if t.persistent then "selectedLip"else "creamLip"
 if t.lipRole~=lipRole then t.lipRole=lipRole;Kit.paint(t.lip,"BackgroundColor3",lipRole)end
end
local function press(t,down)
 if t.pressed==down then return end
 t.pressed=down
 local y=if down then t.lipDepth or 4 else 0
 TweenService:Create(t.face,TweenInfo.new(Rail.Motion.press,Quad,Out),{Position=UDim2.fromOffset(0,y)}):Play()
end
-- One ticket's instances, built once. Hierarchy: Ticket (TextButton, the >= 44 px hit area)
-- > Card (the 40 / 32 px key) > Lip, Face > Disc, Message, Amount, More, Timer > Fill.
local function build(item)
 local t={item=item,persistent=item.persistent,enter=0,leave=0,x=nil,slideFrom=0,slideTo=0,slideT=1}
 local ticket=node("TextButton",scroll,{Name="Ticket",Text="",AutoButtonColor=false,BackgroundTransparency=1,BorderSizePixel=0,
  AnchorPoint=Vector2.new(.5,.5),Selectable=false,Active=false,Interactable=false,AutoLocalize=false})
 t.root=ticket
 t.scale=node("UIScale",ticket,{Scale=1})
 local card=node("Frame",ticket,{Name="Card",BackgroundTransparency=1,BorderSizePixel=0,Active=false})
 Kit.setSurface(card,"light")
 t.card=card
 t.lip=node("Frame",card,{Name="Lip",BorderSizePixel=0,ZIndex=1,Active=false})
 t.lipCorner=node("UICorner",t.lip,{})
 Kit.inner(node("UIStroke",t.lip,{Name="LipStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2,Color=Kit.color("ink")}))
 t.face=node("Frame",card,{Name="Face",BorderSizePixel=0,ZIndex=2,Active=false})
 t.faceCorner=node("UICorner",t.face,{})
 Kit.inner(node("UIStroke",t.face,{Name="FaceStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=2,Color=Kit.color("ink")}))
 t.disc=node("Frame",t.face,{Name="Disc",BorderSizePixel=0,Active=false})
 node("UICorner",t.disc,{CornerRadius=UDim.new(.5,0)})
 t.discStroke=Kit.inner(node("UIStroke",t.disc,{Name="DiscStroke",ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1.5,Color=Kit.color("ink")}))
 t.message=node("TextLabel",t.face,{Name="Message",BackgroundTransparency=1,Text="",FontFace=font,TextSize=14,TextWrapped=false,
  TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left,Active=false})
 t.amount=Kit.fixedText(node("TextLabel",t.face,{Name="Amount",BackgroundTransparency=1,Text="",FontFace=Kit.DisplayFace,TextSize=14,
  TextXAlignment=Enum.TextXAlignment.Left,Visible=false,Active=false}))
 t.more=node("TextLabel",t.face,{Name="More",BackgroundTransparency=1,Text="›",FontFace=font,TextSize=20,Visible=false,AutoLocalize=false,Active=false})
 t.timer=node("Frame",t.face,{Name="Timer",BorderSizePixel=0,BackgroundTransparency=.85,Active=false})
 node("UICorner",t.timer,{CornerRadius=UDim.new(0,2)})
 t.fill=node("Frame",t.timer,{Name="Fill",BorderSizePixel=0,Size=UDim2.fromScale(1,1),Active=false})
 node("UICorner",t.fill,{CornerRadius=UDim.new(0,2)})
 for _,o in ipairs({t.lip:FindFirstChild("LipStroke"),t.face:FindFirstChild("FaceStroke"),t.discStroke})do Kit.paint(o,"Color","ink")end
 Kit.paint(t.message,"TextColor3","ink");Kit.paint(t.amount,"TextColor3","ink");Kit.paint(t.more,"TextColor3","inkSoft")
 Kit.paint(t.timer,"BackgroundColor3","ink")
 paintFace(t)
 -- Hover lights the face; a press drops it onto the lip (tappable tickets only).
 -- A touch never hovers (it would stay lit with no MouseLeave).
 ticket.MouseEnter:Connect(function()if ticket.Active and not Kit.lastInputTouch()then t.hover=true;paintFace(t)end end)
 ticket.MouseLeave:Connect(function()t.hover=false;paintFace(t);press(t,false)end)
 ticket.MouseButton1Down:Connect(function()if ticket.Active then press(t,true)end end)
 ticket.MouseButton1Up:Connect(function()press(t,false)end)
 ticket.Activated:Connect(function()
  local it=t.item
  if t.leaving or not it or it.cancelled or not ticket.Active then return end
  Rail.activate(it.data)
  -- Timed: it dissolves now, or when the card it opened closes (the queue's hold).
  if not it.persistent then it.tapped=true end
 end)
 -- Resting transparencies, read once before any fade (the icon's are read in paintKind).
 t.parts=collect(card,{})
 return t
end
-- Lays a ticket out for its data and the bar (only when either changed).
local function configure(t,data,size,barW,barH)
 local tappable=Rail.tappable(data)
 local text,textW,amount,amountW,content=Rail.measure(data,size.text)
 local g=Rail.geometry(barW,barH,content,tappable)
 t.data,t.size,t.w,t.tappable=data,size,g.width,tappable
 t.lipDepth=size.lip;t.discSize=size.disc
 local w,face=g.width,size.face
 t.card.Size=UDim2.fromOffset(w,size.card)
 t.lip.Size=UDim2.fromOffset(w,face);t.lip.Position=UDim2.fromOffset(0,size.lip)
 t.face.Size=UDim2.fromOffset(w,face);t.face.Position=UDim2.fromOffset(0,if t.pressed then size.lip else 0)
 t.lipCorner.CornerRadius=UDim.new(0,size.radius);t.faceCorner.CornerRadius=UDim.new(0,size.radius)
 local textH=face-(if t.persistent then 0 else Rail.TimerRoom)
 local drop=Rail.contentDrop(size,t.persistent)
 local discY=math.floor((textH-size.disc)/2)+drop
 t.disc.Size=UDim2.fromOffset(size.disc,size.disc);t.disc.Position=UDim2.fromOffset(8,discY)
 local x=8+size.disc+8
 local room=g.room-(if amount then 4+amountW else 0)
 local shownW=math.max(0,math.min(math.ceil(textW),room))
 t.message.Text=text;t.message.TextSize=size.text
 t.message.Position=UDim2.fromOffset(x,drop);t.message.Size=UDim2.fromOffset(shownW+1,textH)
 t.amount.Visible=amount~=nil
 if amount then
  t.amount.Text=amount;t.amount.TextSize=size.text
  t.amount.Position=UDim2.fromOffset(x+shownW+4,drop);t.amount.Size=UDim2.fromOffset(math.ceil(amountW)+1,textH)
 end
 t.more.Visible=tappable
 t.more.Position=UDim2.fromOffset(w-12-14,drop);t.more.Size=UDim2.fromOffset(14,textH)
 t.timer.Visible=not t.persistent
 t.timer.Position=UDim2.fromOffset(10,face-3-3);t.timer.Size=UDim2.fromOffset(math.max(0,w-20),3)
 t.root:SetAttribute("Truncated",not g.full)
 t.root:SetAttribute("Kind",if t.persistent then "status"else Rail.kind(data))
 local kind=Rail.kind(data)
 local spec=Rail.Kinds[kind]
 -- An info line keeps its own glyph ("?", an item's glyph, "•").
 local glyph=if spec.glyph then(if kind=="info"and type(data.icon)=="string"and data.icon~=""then data.icon else spec.glyph)else nil
 if t.discSize~=t.paintedDisc then t.paintedDisc=t.discSize;t.kind=nil end
 paintKind(t,kind,glyph)
 t.alpha=nil;t.iconAlpha=nil
end
-- Slot targets: cumulative widths in slot order (leaving tickets keep their slot).
local function layout(reduced)
 local x=0
 for _,t in ipairs(order)do
  if t.x==nil then t.x=x;t.slideFrom,t.slideTo,t.slideT=x,x,1
  elseif t.slideTo~=x then
   if reduced then t.x=x;t.slideFrom,t.slideTo,t.slideT=x,x,1 else t.slideFrom,t.slideTo,t.slideT=t.x,x,0 end
  end
  x+=t.w+Rail.CardGap
 end
 return math.max(0,x-Rail.CardGap)
end
local function release(t)
 tickets[t.item]=nil
 local i=table.find(order,t);if i then table.remove(order,i)end
 t.root:Destroy()
end
local barKey
local function fitsYes()return true end
local function fitsNo()return false end
local function frame(dt)
 -- AbsolutePosition is in Roblox's GUI coordinate basis; TopbarInset is physical.
 -- Convert through the measured GUI inset, then through this root's local origin.
 local inset=GuiService.TopbarInset
 local barW,barH=inset.Width,inset.Height
 local size=Rail.size(barH)
 local drawable=size~=nil and barW-2*Rail.Gutter>=Rail.MinWidth
 local held=Rail.held()
 local reduced=GuiService.ReducedMotionEnabled
 local list=queue:step(dt,if drawable then fitsYes else fitsNo,held)
 local key=barW*1000+barH
 local resized=key~=barKey;barKey=key
 -- Reconcile: every listed item has a ticket; the rest dissolve.
 local added=false
 for _,item in ipairs(list)do
  local t=tickets[item]
  if not t then
   t=build(item);tickets[item]=t
   if item.persistent then table.insert(order,1,t)else table.insert(order,t)end
   added=added or not item.persistent
  elseif t.leaving then
   -- Back (switched on again): it fades back in from where its dissolve got to.
   t.leaving=false;t.enter=math.max(0,1-t.leave);t.leave=0
  end
  t.seen=true
  if t.data~=item.data or resized then configure(t,item.data,size,barW,barH)end
 end
 for i=#order,1,-1 do
  local t=order[i]
  if not t.seen and not t.leaving then t.leaving=true;t.leave=0;t.hover=false;paintFace(t);press(t,false)end
  t.seen=nil
 end
 -- Dissolves that finished release their slot; the others then slide over (layout).
 for i=#order,1,-1 do
  local t=order[i]
  if t.leaving then
   t.leave+=dt/(if reduced then Rail.Motion.reduced else Rail.Motion.leave)
   if t.leave>=1 then release(t)end
  end
 end
 if not drawable or #order==0 then row.Visible=false;return end
 local contentW=layout(reduced)
 -- Place the row in the free bar.
 local origin=root.AbsolutePosition
 local guiInset=GuiService:GetGuiInset()
 local avail=barW-2*Rail.Gutter
 local right=0
 for _,t in ipairs(order)do
  if t.slideT<1 then
   t.slideT=math.min(1,t.slideT+dt/Rail.Motion.slide)
   t.x=t.slideFrom+(t.slideTo-t.slideFrom)*ease(t.slideT,Quad,Out)
  end
  right=math.max(right,t.x+t.w)
 end
 local canvasW=math.max(contentW,right)
 local rowW=math.min(avail,canvasW)
 -- The engine clamps CanvasPosition when the canvas shrinks: expect that, it is no drag.
 local maxScroll=math.max(0,canvasW-rowW)
 lastScrollX=math.clamp(lastScrollX,0,maxScroll)
 local rx,ry=inset.Min.X-guiInset.X-origin.X+Rail.Gutter,inset.Min.Y-guiInset.Y-origin.Y
 if row.Position.X.Offset~=rx or row.Position.Y.Offset~=ry then row.Position=UDim2.fromOffset(rx,ry)end
 if row.Size.X.Offset~=rowW or row.Size.Y.Offset~=barH then row.Size=UDim2.fromOffset(rowW,barH)end
 if scroll.CanvasSize.X.Offset~=canvasW then scroll.CanvasSize=UDim2.new(0,canvasW,1,0)end
 row.Visible=true
 -- Overflow: scroll to the newest, unless the player dragged the row in the last 2 s.
 if added and maxScroll>0 and os.clock()-dragAt>Rail.DragQuiet then
  scrollFrom,scrollTo,scrollT=scroll.CanvasPosition.X,math.max(0,contentW-rowW),0
  if reduced then scrollT=1;lastScrollX=scrollTo;scroll.CanvasPosition=Vector2.new(scrollTo,0)end
 end
 if scrollT<1 then
  scrollT=math.min(1,scrollT+dt/Rail.Motion.scroll)
  lastScrollX=scrollFrom+(scrollTo-scrollFrom)*ease(scrollT,Quad,Out)
  scroll.CanvasPosition=Vector2.new(lastScrollX,0)
 end
 -- Edge fades only where tickets are hidden.
 local scrolled=scroll.CanvasPosition.X
 local left,rightHidden=Rail.EdgeFade and scrolled>.5,Rail.EdgeFade and scrolled<maxScroll-.5
 local fadeKey=(if left then 1 else 0)+(if rightHidden then 2 else 0)+rowW*4
 if fade:GetAttribute("Key")~=fadeKey then
  fade:SetAttribute("Key",fadeKey)
  local f=if rowW>0 then Rail.FadeWidth/rowW else 1
  if(not left and not rightHidden)or f>=.5 then fade.Enabled=false
  else
   local keys={NumberSequenceKeypoint.new(0,if left then 1 else 0)}
   if left then table.insert(keys,NumberSequenceKeypoint.new(f,0))end
   if rightHidden then table.insert(keys,NumberSequenceKeypoint.new(1-f,0))end
   table.insert(keys,NumberSequenceKeypoint.new(1,if rightHidden then 1 else 0))
   fade.Transparency=NumberSequence.new(keys);fade.Enabled=true
  end
 end
 -- Each ticket: hit area, enter / leave motion, timer, breathing status disc.
 local now=os.clock()
 -- (Rail.geometry's y: 4 px over the bar's bottom on a full bar, else centred.)
 local cardH=(size or Rail.Sizes.tight).card
 local cardY=if barH>=56 then barH-cardH-4 else math.max(0,math.floor((barH-cardH)/2))
 for _,t in ipairs(order)do
  local s=t.size or size
  local item=t.item
  if t.enter<1 then t.enter=math.min(1,t.enter+dt/(if reduced then Rail.Motion.reduced else Rail.Motion.enter))end
  local alpha,scale,dx
  if reduced then
   alpha=t.enter*(1-math.min(1,t.leave));scale=1;dx=0
  else
   local e=ease(t.enter,Quad,Out)
   alpha=e*(1-ease(t.leave,Quad,Out))
   scale=(.9+.1*ease(t.enter,Back,Out))*(1-.08*ease(t.leave,Quad,Out))
   dx=16*(1-e)
  end
  if t.enter>=1 and not t.leaving then alpha,scale,dx=1,1,0 end -- settled: exactly at rest
  local hitH=math.min(math.max(Rail.Hit,s.card),barH)
  local hitTop=math.clamp(math.floor(cardY+s.card/2-hitH/2),0,math.max(0,barH-hitH))
  local px,py=t.x+t.w/2+dx,hitTop+hitH/2
  if t.px~=px or t.py~=py then t.px,t.py=px,py;t.root.Position=UDim2.fromOffset(px,py)end
  if t.hitW~=t.w or t.hitH~=hitH or t.hitTop~=hitTop then
   t.hitW,t.hitH,t.hitTop=t.w,hitH,hitTop
   t.root.Size=UDim2.fromOffset(t.w,hitH);t.card.Position=UDim2.fromOffset(0,cardY-hitTop)
  end
  if t.scale.Scale~=scale then t.scale.Scale=scale end
  local active=t.tappable==true and not t.leaving
  if t.root.Active~=active then
   t.root.Active=active;t.root.Interactable=active -- a plain ticket lets a drag reach the row
   if not active then t.hover=false;paintFace(t)end
  end
  if t.alpha~=alpha then t.alpha=alpha;apply(t.parts,alpha)end
  -- Status: the disc icon breathes (still under Reduced Motion).
  local breathe=if t.persistent and not reduced then .4*(.5-.5*math.cos(now*2*math.pi/Rail.Motion.breathe))else 0
  local iconAlpha=alpha*(1-breathe)
  if t.iconAlpha~=iconAlpha then t.iconAlpha=iconAlpha;apply(t.iconParts,iconAlpha)end
  if not t.persistent then
   local duration=Queue.durationOf(item)
   local left01=if duration>0 then math.clamp(1-item.age/duration,0,1)else 0
   if t.leaving then left01=0 end
   if t.left01~=left01 then t.left01=left01;t.fill.Size=UDim2.fromScale(left01,1)end
   -- Held (a card is open) or paused: the bar freezes in inkSoft.
   local barRole=if held or item.data.paused==true then "inkSoft"else Rail.Kinds[t.kind or "info"].bar
   if t.barRole~=barRole then t.barRole=barRole;Kit.paint(t.fill,"BackgroundColor3",barRole)end
  end
 end
end
local function watch(owner)
 if typeof(owner)=="Instance"and not owners[owner]then
  owners[owner]=owner.Destroying:Connect(function()queue:cancelOwner(owner);local c=owners[owner];owners[owner]=nil;if c then c:Disconnect()end end)
 end
end
local function add(owner,key,data,persistent)
 if stopped then return{update=function()end,cancel=function()end,isVisible=function()return false end}end
 watch(owner);ensure()
 local item=queue:add(owner,key,data,persistent)
 local handle={}
 function handle:update(values)
  if not item or item.cancelled then return end
  local nextData=table.clone(item.data);for k,v in pairs(values)do nextData[k]=v end;item.data=nextData
 end
 function handle:cancel()queue:cancel(item)end
 function handle:isVisible()
  local t=item and tickets[item]
  return item~=nil and queue:visible(item)and t~=nil and not t.leaving and row~=nil and row.Visible
 end
 return handle
end
function Rail.enqueue(owner,key,data)return add(owner,key,data,false)end
function Rail.status(owner,key,data)return add(owner,key,data,true)end
function Rail.cancelOwner(owner)queue:cancelOwner(owner)end
-- Specs and tools: the ScreenGui, the newest showing ticket (its TextButton) and the row.
function Rail.view()
 local newest
 for i=#order,1,-1 do if not order[i].leaving then newest=order[i].root;break end end
 return gui,newest,row
end
-- Specs and tools: the showing tickets, left to right ({text, ticket, card, persistent, kind}).
function Rail.shown()
 local out={}
 if not row or not row.Visible then return out end
 for _,t in ipairs(order)do
  if not t.leaving and t.data then
   table.insert(out,{text=t.message.Text,ticket=t.root,card=t.card,persistent=t.persistent,kind=t.root:GetAttribute("Kind"),item=t.item})
  end
 end
 return out
end
function Rail.texts()
 local out={}
 for _,entry in ipairs(Rail.shown())do table.insert(out,entry.text)end
 return out
end
-- Nothing showing, waiting or pinned (a line that is switched off does not count).
function Rail.empty()
 for _,list in ipairs({queue.items,queue.providers})do
  for _,item in ipairs(list)do if not item.cancelled and item.data.active~=false then return false end end
 end
 return true
end
-- A cloned spec module can release its singleton; its destroyed GUI must not
-- leave a RenderStepped callback that recreates identically named empty rails.
function Rail.destroy()
 if stopped then return end;stopped=true
 if connection then connection:Disconnect();connection=nil end
 for owner,c in pairs(owners)do c:Disconnect();owners[owner]=nil end
 queue.items={};queue.providers={};queue.shown={};queue.status=nil
 tickets={};order={}
 if gui then gui:Destroy();gui,root,row,scroll,fade=nil,nil,nil,nil,nil end
end
script.Destroying:Connect(Rail.destroy)
connection=RunService.RenderStepped:Connect(function(dt)
 if not ensure()then return end
 frame(dt)
end)
return Rail
