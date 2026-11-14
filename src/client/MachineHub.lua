-- Machine hub (QA 2026-11-13 Q5, Spencer approved "Yes, machine hub"): the Pocket menu
-- outside rounds. One tile per garden machine (Hatch eggs, Deck style, Companions) plus
-- Quests, the Collection book and Settings, in the house style: Kit.header with a tint,
-- Kit.tile lips, Fredoka names, a status line with a gold dot when something waits,
-- and the hint caps along the bottom. During a round the deck keeps its pause menu
-- (PocketMenu: Resume, Restart round, Quit to garden, Settings).
--
-- Presentation only. Opening a tile goes back through `callbacks.open(id)`; the caller
-- opens that machine's screen exactly as its station does, and Back from it reopens
-- this hub sliding in from the left (Kit.slideIn, as the Companions hub does).
-- Before the first pet every tile but Settings is locked: a locked tile still takes
-- focus and taps and `callbacks.locked(id)` says why (as the Pocket Menu does).
-- Focus is owned here (arrows / WASD / d-pad move on the 3 x 2 grid, A / Enter opens,
-- B / Backspace / Escape / Menu closes); the caller binds the keys and calls :input.
local Kit=require(script.Parent.DeckKit)
local Shared=game:GetService("ReplicatedStorage").Shared
local UICopy=require(Shared.UICopy)
local Pets=require(Shared.PetCatalog)
local WearableCatalog=require(Shared.WearableCatalog)
local DeckThemes=require(Shared.DeckThemes)
local BallThemes=require(Shared.BallThemes)
local Deal=require(script.Parent.ShelfDeal)
local Hub={}
Hub.__index=Hub
Hub.Size=Vector2.new(848,608)
Hub.Cols=3
-- Each machine's screen tint (T5) colours its tile disc; Settings stays neutral.
Hub.Tiles=table.freeze({
 table.freeze({id="hatch",icon="egg",tint="hatch",name="hub.tile.hatch.name",line="r3.hub.hatchLine"}),
 table.freeze({id="style",icon="faceplate",tint="style",name="hub.tile.style.name",line="hub.tile.style.line",short="hub.tile.style.short"}),
 table.freeze({id="companions",icon="paw",tint="companions",name="hub.tile.companions.name",line="hub.tile.companions.line"}),
 table.freeze({id="quests",icon="quests",tint="quests",name="hub.tile.quests.name",line="r3.hub.questsLine"}),
 table.freeze({id="book",icon="book",tint="book",name="book.title",line="book.entry.line",short="hub.tile.book.short"}),
 table.freeze({id="settings",icon="settings",tint=nil,name="hub.tile.settings.name",line="hub.tile.settings.line"}),
})
Hub.Count=#Hub.Tiles
Hub.Tint=Kit.Sticker.cream -- the hub's own header tint: the house cream, not a machine's
Hub.DefaultIndex=1

-- Pure: is this tile locked for a player who owns `owned` pets? Everything but
-- Settings waits for the first pet (the Pocket Menu's rule on a fresh save).
function Hub.locked(id,owned)
 return id~="settings"and(owned or 0)<=0
end
-- Pure: quests ready to claim in a snapshot's `quests` (daily, weekly and the weekly bonus).
function Hub.questsReady(quests)
 if type(quests)~="table"then return 0 end
 local n=0
 for _,scope in ipairs({"daily","weekly"})do
  for _,row in ipairs(type(quests[scope])=="table"and quests[scope]or {})do
   if type(row)=="table"and row.ready==true and row.claimed~=true then n+=1 end
  end
 end
 if quests.bonusReady==true then n+=1 end
 return n
end
-- Pure: the status line under a tile. ctx = {owned, state = snapshot}.
-- Returns {text, tone, dot, locked}.
function Hub.status(id,ctx)
 ctx=ctx or {}
 if Hub.locked(id,ctx.owned)then return{text=UICopy.get("hub.status.locked"),tone="dim",dot=false,locked=true}end
 local state=type(ctx.state)=="table"and ctx.state or {}
 local function claims(n)
  if n<=0 then return nil end
  return if n==1 then UICopy.get("book.entry.claimOne")else UICopy.get("book.entry.claimMany",{count=n})
 end
 -- QA v2 R3.8: the stamp card moved to Quests, so its "stamp ready" status did too
 -- (quest claims first, then today's stamp).
 if id=="quests"then
  local text=claims(Hub.questsReady(state.quests))
  if text then return{text=text,tone="stars",dot=true,locked=false}end
  if state.dailyAvailable==true then return{text=UICopy.get("hub.status.stamp"),tone="stars",dot=true,locked=false}end
 end
 if id=="book"then
  local book=state.book
  local text=claims(type(book)=="table"and type(book.claimable)=="table"and #book.claimable or 0)
  if text then return{text=text,tone="stars",dot=true,locked=false}end
 end
 return{text="",tone="dim",dot=false,locked=false}
end
-- Slice C (weekly shelf): which shelf kinds a tile sells, and how an id reads as a name.
Hub.ShelfKinds=table.freeze({style=table.freeze({"faceplate","ball"}),companions=table.freeze({"wearable"})})
Hub.ShelfNames=table.freeze({
 wearable=function(id)
  for _,pet in ipairs(Pets.active)do
   local item=WearableCatalog.item(pet.id,id)
   if item then return item.name end
  end
  return nil
 end,
 faceplate=function(id)local theme=DeckThemes.ById[id];return theme and theme.name or nil end,
 ball=function(id)local theme=BallThemes.ById[id];return theme and theme.name or nil end,
})
-- Pure: the shelf line for a tile, longest wording first ("This week: Mint Pom Beanie,
-- Party Hat", then "20% off this week"); nil when the tile has nothing on this week's
-- shelf, the tile is locked, or the shelf is off. No countdown (no FOMO).
function Hub.shelfLines(id,ctx)
 ctx=ctx or {}
 local kinds=Hub.ShelfKinds[id]
 if not kinds or Hub.locked(id,ctx.owned)then return nil end
 local week=if ctx.week~=nil then ctx.week else Deal.week(type(ctx.state)=="table"and ctx.state or {})
 if not week then return nil end
 return Deal.lines(week,kinds,Hub.ShelfNames)
end
-- Pure: tile rects for a W x H screen (desktop: the 848 x 608 panel). Three columns,
-- two rows. Desktop: under the 84 px header, above the hint bar at 566. Phone: under
-- the 60 px header, 20 px side margins, 8 px gaps (the lip sits in the gap).
function Hub.geometry(W,H,phone)
 local x0,y0,gap,bottom
 if phone then x0,y0,gap,bottom=20,64,8,H-12 else x0,y0,gap,bottom=24,84,16,548 end
 local cols=Hub.Cols;local rows=math.ceil(Hub.Count/cols)
 local w=math.floor((W-2*x0-(cols-1)*gap)/cols)
 local h=math.floor((bottom-y0-(rows-1)*gap)/rows)
 local tiles={}
 for i=1,Hub.Count do
  local c,r=(i-1)%cols,(i-1)//cols
  tiles[i]={x=x0+c*(w+gap),y=y0+r*(h+gap),w=w,h=h}
 end
 return{cols=cols,rows=rows,tiles=tiles,phone=phone==true}
end
-- Pure: the next focus index moving (dx, dy) on the grid; stays put at an edge
-- (locked tiles still take focus).
function Hub.step(index,dx,dy,cols,count)
 cols=cols or Hub.Cols;count=count or Hub.Count
 local c,r=(index-1)%cols,(index-1)//cols
 local rows=math.ceil(count/cols)
 local nc,nr=math.clamp(c+dx,0,cols-1),math.clamp(r+dy,0,rows-1)
 local nextIndex=nr*cols+nc+1
 if nextIndex>count then return index end
 return nextIndex
end
-- Pure: what a key does (nil when the hub ignores it).
function Hub.keyAction(key)
 local K=Enum.KeyCode
 if key==K.Left or key==K.A or key==K.DPadLeft then return "left"end
 if key==K.Right or key==K.D or key==K.DPadRight then return "right"end
 if key==K.Up or key==K.W or key==K.DPadUp then return "up"end
 if key==K.Down or key==K.S or key==K.DPadDown then return "down"end
 if key==K.Return or key==K.KeypadEnter or key==K.Space or key==K.ButtonA then return "open"end
 if key==K.ButtonB or key==K.Backspace or key==K.Escape or key==K.M or key==K.ButtonY or key==K.ButtonSelect or key==K.ButtonStart then return "back"end
 return nil
end
Hub.Keys={Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.A,Enum.KeyCode.D,Enum.KeyCode.W,Enum.KeyCode.S,
 Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,
 Enum.KeyCode.Space,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,Enum.KeyCode.Escape,Enum.KeyCode.M,
 Enum.KeyCode.ButtonY,Enum.KeyCode.ButtonSelect,Enum.KeyCode.ButtonStart}

local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
local function colorOf(role)
 if role=="accent"or role=="selected"or role=="raised"or role=="well"or role=="panel"then return Kit.color(role)end
 return Kit.Color[role]or Kit.Color.text
end

-- host: a full-screen Frame (its own ScreenGui). callbacks: open(id) -> bool,
-- locked(id), closed(reason).
function Hub.new(host,callbacks)
 local self=setmetatable({host=host,callbacks=callbacks or {},index=Hub.DefaultIndex,visible=false,covered=false,
  ctx={owned=0,wallet=0,state={}},tileViews={}},Hub)
 -- Q2 shade stack: one full-screen shade beside the panel (never its parent).
 self.shade=Kit.modalShade(host,"MachineHubShade",30)
 local root=Kit.frame(host,"MachineHub","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
 root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.ClipsDescendants=true;root.ZIndex=31;root.Visible=false
 self.rootStroke=Kit.stroke(root)
 local gradient=Kit.frame(root,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 self.gradient=gradient;self.root=root
 self.scale=Kit.node("UIScale",root,{Scale=1})
 self.sizeConnection=host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.visible then self:fit(host.AbsoluteSize)end end)
 return self
end

function Hub:buildHints(content)
 local hints=Kit.frame(content,"Hints",nil,UDim2.fromOffset(24,566),UDim2.fromOffset(560,24))
 local x=0
 for _,pair in ipairs({{"+","Move"},{"A","Open"},{"B","Back"}})do
  local g=Kit.glyph(hints,pair[1],false,22,true);g.Position=UDim2.fromOffset(x,1)
  txt(hints,"Small",pair[2],"soft",x+28,0,120,24)
  x+=28+Kit.measure(pair[2],"Small",14).X+18
 end
 txt(content,"Small",UICopy.get("hub.promise"),"dim",424,566,400,24,{Name="Promise",TextXAlignment=Enum.TextXAlignment.Right})
end

function Hub:build(view)
 if self.content then self.content:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 self.view=view;self.key=if view then string.format("%dx%d",view.W,view.H)else "regular"
 local root=self.root;local phone=view~=nil
 root.BackgroundTransparency=if phone then 1 else 0;self.gradient.Visible=not phone;self.rootStroke.Enabled=not phone;root.ClipsDescendants=not phone
 Kit.setShadeAlpha(self.shade,Kit.ShadeAlpha) -- R3.1: one full-screen shade, phones too
 local W=if phone then view.W else 848
 local H=if phone then view.H else 608
 local content=Kit.frame(root,"Content",nil,UDim2.new(),UDim2.fromOffset(W,H));content.ZIndex=root.ZIndex+2
 self.content=content
 Kit.halftone(content,Hub.Tint,phone)
 local body=content
 if phone then
  local sheet=Kit.sheet(content,W,H)
  body=Kit.frame(content,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 end
 self.body=body
 local title=if self.notice then self.notice.short else UICopy.get("hub.title")
 self.header=Kit.header(body,{title=title,eyebrow=UICopy.get("hub.eyebrow"),tint=Hub.Tint,compact=phone,width=W,
  left=if phone then view.hx else 24,onBack=function()self:back()end})
 self.header.root.Name="HubHeader"
 if self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
 self:buildTiles(body,W,H,phone)
 if not phone then self:buildHints(content)end
 self.ring=Kit.focusRing(self.root)
 root:SetAttribute("Layout",if phone then "phone"else "regular")
end

function Hub:buildTiles(body,W,H,phone)
 local g=Hub.geometry(W,H,phone)
 self.geometryCache=g
 self.tileViews={}
 for index,tile in ipairs(Hub.Tiles)do
  local r=g.tiles[index]
  local button,tileState=Kit.tile(body,"Tile_"..tile.id,{selectable=false,radius=if phone then 12 else 14,compact=phone,
   position=UDim2.fromOffset(r.x,r.y),size=UDim2.fromOffset(r.w,r.h)})
  local name=UICopy.get(tile.name);local line=UICopy.get(tile.line)
  button:SetAttribute("AccessibleLabel",name..", "..line);button:SetAttribute("TileId",tile.id)
  local discSize=if phone then 36 else 64
  local pad=if phone then 12 else 20
  local disc=Kit.frame(button,"IconDisc",nil,UDim2.fromOffset(pad,pad),UDim2.fromOffset(discSize,discSize),999);disc.BackgroundTransparency=0
  local icon=Kit.icon(disc,tile.icon,math.floor(discSize*.5),"ink");icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5)
  local nameLabel,lineLabel,statusLabel
  if phone then
   local tx=pad+discSize+8
   nameLabel=txt(button,"Name",name,"text",tx,pad-2,r.w-tx-8,22,{TextSize=16,TextTruncate=Enum.TextTruncate.AtEnd})
   statusLabel=txt(button,"Label","","dim",tx,pad+20,r.w-tx-8,16,{Name="Status",TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
   lineLabel=txt(button,"Small",line,"soft",pad,pad+discSize+6,r.w-2*pad,18,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
   lineLabel.Visible=r.h>=pad+discSize+6+18+4
   if tile.short then Kit.fitText(nameLabel,{name,UICopy.get(tile.short)},r.w-tx-8)end
  else
   nameLabel=txt(button,"Name",name,"text",pad,pad+discSize+14,r.w-2*pad,28,{TextSize=22,TextTruncate=Enum.TextTruncate.AtEnd})
   lineLabel=txt(button,"Body",line,"soft",pad,pad+discSize+46,r.w-2*pad,44,{TextSize=15,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
   statusLabel=txt(button,"Label","","dim",pad,r.h-pad-16,r.w-2*pad,16,{Name="Status",TextSize=12})
  end
  local dot=Kit.frame(button,"ReadyDot","stars",UDim2.new(),UDim2.fromOffset(8,8),999);dot.BackgroundTransparency=0;dot.Visible=false
  -- A chevron says "this opens a screen" (as on the Companions rows).
  local chev=Kit.icon(button,"chevron",if phone then 14 else 18,"soft");chev.AnchorPoint=Vector2.new(.5,.5)
  chev.Position=UDim2.fromOffset(r.w-(if phone then 16 else 24),pad+discSize/2)
  local entry={id=tile.id,tint=tile.tint,button=button,stroke=tileState.stroke,state=tileState,disc=disc,icon=icon,name=nameLabel,line=lineLabel,status=statusLabel,dot=dot,
   chevron=chev,phone=phone,pad=pad,
   -- The line label's room: one line on phones, two wrapped lines on desktop.
   lineWidth=if phone then r.w-2*pad else math.floor((r.w-2*pad)*1.8)}
  self.tileViews[index]=entry
  button.Activated:Connect(function()
   if not self.visible then return end
   self:focusTile(index);self:act()
  end)
  button.MouseEnter:Connect(function()if self.visible and self.index~=index then self:focusTile(index)end end)
 end
 self:paintTiles()
end

-- Status lines, dots, lock look and focus.
function Hub:paintTiles()
 for index,entry in ipairs(self.tileViews)do
  local s=Hub.status(entry.id,self.ctx)
  local focused=index==self.index
  entry.status.Text=string.upper(s.text)
  Kit.paint(entry.status,"TextColor3",function()return colorOf(s.tone)end)
  entry.button:SetAttribute("Locked",s.locked);entry.button:SetAttribute("Ready",s.dot)
  entry.dot.Visible=s.dot and s.text~=""
  if entry.dot.Visible then
   local p=entry.status.Position
   if entry.phone then
    entry.status.Position=UDim2.fromOffset(entry.pad+36+8+14,p.Y.Offset)
    entry.dot.Position=UDim2.fromOffset(entry.pad+36+8,p.Y.Offset+4)
   else
    entry.status.Position=UDim2.fromOffset(entry.pad+14,p.Y.Offset)
    entry.dot.Position=UDim2.fromOffset(entry.pad,p.Y.Offset+4)
   end
  else
   entry.status.Position=UDim2.fromOffset(if entry.phone then entry.pad+36+8 else entry.pad,entry.status.Position.Y.Offset)
  end
  -- Locked: the disc goes grey and the line says how it opens up.
  local tint=if s.locked then nil else Kit.tintColor(entry.tint)
  entry.disc.BackgroundColor3=tint or(if s.locked then Kit.Color.dim else Kit.Color.soft)
  entry.line.Text=if s.locked then UICopy.get("menu.subtitle.locked")else UICopy.get(Hub.Tiles[index].line)
  -- Slice C: this week's shelf takes the line on the tiles that sell it, in Stars gold.
  local shelf=Hub.shelfLines(entry.id,self.ctx)
  if shelf then Kit.fitText(entry.line,shelf,entry.lineWidth)end
  Kit.paint(entry.line,"TextColor3",function()return colorOf(if shelf then "stars"else "soft")end)
  entry.button:SetAttribute("Shelf",shelf~=nil)
  if not s.locked then entry.button:SetAttribute("AccessibleLabel",entry.name.Text..", "..entry.line.Text)end
  Kit.paint(entry.name,"TextColor3",function()return colorOf(if s.locked then "soft"else "text")end)
  Kit.paint(entry.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised")end)
  entry.stroke.Thickness=if focused then 2 else 1;entry.stroke.Transparency=if focused then 0 else Kit.Stroke.transparency
  Kit.paint(entry.stroke,"Color",function()return if focused then Kit.color("accent")else Kit.Stroke.color end)
 end
 local focusedTile=Hub.Tiles[self.index]
 self.root:SetAttribute("FocusedTile",focusedTile and focusedTile.id or nil)
end

function Hub:fit(size)
 if Kit.compactRule(size.X,size.Y)then
  local _,kh=Kit.keepOut();local top=kh+2
  local view={phone=true,W=math.floor(size.X),H=math.floor(size.Y)-top,hx=24}
  self.root.AnchorPoint=Vector2.zero;self.root.Position=UDim2.fromOffset(0,top);self.root.Size=UDim2.fromOffset(view.W,view.H);self.scale.Scale=1
  if self.key~=string.format("%dx%d",view.W,view.H)then self:build(view);self:focusTile(self.index,true)end
  return
 end
 self.root.AnchorPoint=Vector2.new(.5,.5);self.root.Size=UDim2.fromOffset(848,608)
 if self.key~="regular"then self:build(nil);self:focusTile(self.index,true)end
 self.root.Position=UDim2.fromScale(.5,.5)
 self.scale.Scale=math.max(.1,math.min(1.2,(size.X-24)/848,(size.Y-24)/608))
end

-- ctx = {owned = pets owned, wallet = Stars, state = snapshot}. Partial updates keep the rest.
function Hub:setContext(ctx)
 ctx=ctx or {}
 if ctx.owned~=nil then self.ctx.owned=ctx.owned end
 if ctx.wallet~=nil then self.ctx.wallet=ctx.wallet end
 if ctx.state~=nil then self.ctx.state=ctx.state end
 if self.visible and self.content then
  if self.header and self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
  self:paintTiles()
 end
end

function Hub:focusTile(index,instant)
 self.index=math.clamp(index,1,Hub.Count)
 if self.content then self:paintTiles()end
 local entry=self.tileViews[self.index]
 if entry and self.ring and self.visible and not self.covered then
  self.ring.attach(entry.button,if self.view then 12 else 14)
  if instant then self.ring.root.Visible=self.visible and self.ring.root.Visible end
 end
end
function Hub:move(dx,dy)
 if not self.visible then return false end
 local nextIndex=Hub.step(self.index,dx,dy)
 if nextIndex==self.index then return false end
 self:focusTile(nextIndex);return true
end
-- A / Enter / tap: open the focused machine, or say why it is locked.
function Hub:act()
 if not self.visible then return false end
 local tile=Hub.Tiles[self.index];if not tile then return false end
 local entry=self.tileViews[self.index]
 if Hub.locked(tile.id,self.ctx.owned)then
  if entry then Kit.boing(entry.button)end
  if self.callbacks.locked then self.callbacks.locked(tile.id)end
  return false
 end
 if entry then Kit.pulseTile(entry.button)end
 if self.callbacks.open then return self.callbacks.open(tile.id)==true end
 return false
end
function Hub:back()
 if not self.visible then return false end
 self:close("back")
 return true
end
-- Keyboard / gamepad (bound by the caller with Hub.Keys).
function Hub:input(key)
 if not self:takesInput()then return false end
 local action=Hub.keyAction(key)
 if action=="left"then return self:move(-1,0)
 elseif action=="right"then return self:move(1,0)
 elseif action=="up"then return self:move(0,-1)
 elseif action=="down"then return self:move(0,1)
 elseif action=="open"then return self:act()
 elseif action=="back"then return self:back()end
 return false
end

function Hub:isOpen()return self.visible end
-- Open and topmost: a screen stacked over the hub (covered) owns the keys, so the
-- caller's binding passes them through instead of sinking them here.
function Hub:takesInput()return self.visible and not self.covered end
-- A screen opened over the hub hides this panel; uncovered, it slides in from the left.
function Hub:setCovered(covered)
 if not self.visible then return end
 self.covered=covered==true
 self.root.Visible=not self.covered
 if self.covered then if self.ring then self.ring.hide()end;return end
 if self.body then Kit.slideIn(self.body,-Kit.SlideOffset,Kit.headerSkip(self.header))end
 self:focusTile(self.index,true)
end
-- ctx: as setContext. options: focus (a tile id), slideFrom (px; Back from a machine
-- screen passes -Kit.SlideOffset so the hub slides in from the left).
function Hub:open(ctx,options)
 options=options or {}
 if ctx then self:setContext(ctx)end
 local wasOpen=self.visible
 if options.focus then
  for i,tile in ipairs(Hub.Tiles)do if tile.id==options.focus then self.index=i end end
 elseif not wasOpen then self.index=self.lastIndex or Hub.DefaultIndex end
 self.visible=true;self.covered=false;self.root.Visible=true
 Kit.shadeOpen(self,self.shade,function(covered)self:setCovered(covered)end)
 self.key=nil;self:fit(self.host.AbsoluteSize)
 self:focusTile(self.index,true)
 if options.slideFrom and self.body then Kit.slideIn(self.body,options.slideFrom,Kit.headerSkip(self.header))
 elseif not wasOpen and not self.view and not Kit.reduced()then
  -- Screen in: 160 ms with an 8 px rise (desktop); Reduced Motion is a cut.
  self.root.Position=UDim2.new(.5,0,.5,8);Kit.tween(self.root,Kit.Motion.screen,{Position=UDim2.fromScale(.5,.5)})
 end
 return true
end
function Hub:close(reason)
 if not self.visible then return false end
 self.lastIndex=self.index
 self.visible=false;self.covered=false;self.root.Visible=false;Kit.shadeClose(self)
 if self.ring then self.ring.hide()end
 if self.callbacks.closed then self.callbacks.closed(reason or "close")end
 return true
end
function Hub:destroy()
 self:close("destroy")
 if self.sizeConnection then self.sizeConnection:Disconnect()end
 self.root:Destroy();self.shade:Destroy()
end

-- Compatibility with the garden menu's old callers (init.client.lua `gameMenu`):
-- `shade.Visible` is "open", activate("close") closes, update(snapshot) refreshes,
-- and the hub owns its own focus (no native selection).
function Hub:activate(key)
 if key=="close"then return self:back()end
 return false
end
function Hub:update(state)
 if type(state)=="table"then self:setContext({state=state,wallet=state.nectar or 0})end
 return true
end
function Hub:setPage()return false end
function Hub:setFieldObjective()return false end
function Hub:setSaveNotice(notice)
 if self.notice==notice then return false end
 self.notice=notice
 if self.header then self.header.setTitle(if notice then notice.short else UICopy.get("hub.title"))end
 return true
end
function Hub:getControllerFocus()return nil end
function Hub:bumpControllerEpoch()end
return Hub
