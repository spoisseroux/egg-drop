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
local HubArt=require(script.Parent.MachineHubArt)
local Stamp=require(Shared.StampCard)
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
Hub.Tint=Kit.Tint.garden -- the hub's own header tint (Toy Shell 3.1: Garden is go), not a machine's
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
-- QA 2026-11-14 U2 (the hub felt empty): progress chips under each tile's line.
-- Pure: today's daily quests finished (claimed, ready, or at their target) and how many there are.
function Hub.questsDone(quests)
 local rows=type(quests)=="table"and type(quests.daily)=="table"and quests.daily or {}
 local done,total=0,0
 for _,row in ipairs(rows)do
  if type(row)=="table"then
   total+=1
   local progress,target=tonumber(row.progress),tonumber(row.target)
   if row.claimed==true or row.ready==true or(progress and target and target>0 and progress>=target)then done+=1 end
  end
 end
 return done,total
end
-- Pure: owned and total over the named book pages (every page when `ids` is nil).
function Hub.bookCount(book,ids)
 local owned,total=0,0
 for _,page in ipairs(type(book)=="table"and type(book.pages)=="table"and book.pages or {})do
  if type(page)=="table"and(ids==nil or table.find(ids,page.id))then
   owned+=math.max(0,tonumber(page.owned)or 0);total+=math.max(0,tonumber(page.total)or 0)
  end
 end
 return owned,total
end
-- Which book pages a machine's "owned / total" chip counts, and its wording.
Hub.ChipPages=table.freeze({
 hatch=table.freeze({pages=table.freeze({"toys"}),copy="hub.chip.toys"}),
 style=table.freeze({pages=table.freeze({"faceplates","balls"}),copy="hub.chip.styles"}),
 companions=table.freeze({pages=table.freeze({"wardrobe"}),copy="hub.chip.outfits"}),
})
-- Pure: a tile's chips, most important first: {{text, kind}} with kind "gold" once the
-- thing is complete (all quests done, the whole book found), else "plain". None while
-- locked, and none for a count the snapshot does not carry yet.
function Hub.chips(id,ctx)
 ctx=ctx or {}
 if Hub.locked(id,ctx.owned)then return {}end
 local state=type(ctx.state)=="table"and ctx.state or {}
 local out={}
 if id=="quests"then
  local done,total=Hub.questsDone(state.quests)
  if total>0 then table.insert(out,{text=UICopy.get("hub.chip.quests",{done=done,total=total}),kind=if done>=total then "gold"else "plain"})end
  if type(state.stamps)=="number"and state.stamps==state.stamps and state.stamps>=0 then
   table.insert(out,{text=UICopy.get("hub.chip.stamp",{count=Stamp.onCard(math.floor(state.stamps)),total=Stamp.Length}),kind="plain"})
  end
 elseif id=="book"then
  local owned,total=Hub.bookCount(state.book)
  if total>0 then
   local percent=math.min(100,math.floor(owned*100/total))
   table.insert(out,{text=UICopy.get("hub.chip.book",{percent=percent}),kind=if percent>=100 then "gold"else "plain"})
  end
 elseif Hub.ChipPages[id]then
  local rule=Hub.ChipPages[id]
  local owned,total=Hub.bookCount(state.book,rule.pages)
  if total>0 then table.insert(out,{text=UICopy.get(rule.copy,{owned=owned,total=total}),kind=if owned>=total then "gold"else "plain"})end
 end
 return out
end
-- Pure: where a tile's parts sit, for a w x h tile. The art well takes the right side
-- of a phone tile (a square) and the top-right of a desktop tile (beside the disc);
-- the name, status, line and chips keep to the left of / under it. `line` and `chips`
-- are nil when the tile is too short for them (the chips win over the line).
function Hub.tileLayout(w,h,phone)
 if phone then
  local pad,disc=12,36
  local tx=pad+disc+8
  -- The well is a square on the right; a narrow tile (568-wide phones) shrinks it so the name keeps 56 px.
  local side=math.max(36,math.min(h-20,76,w-18-tx-56))
  local well={x=w-side-10,y=10,w=side,h=side}
  local textW=well.x-8-pad
  local out={pad=pad,disc=disc,well=well,name={x=tx,y=pad-2,w=well.x-8-tx,h=22},status={x=tx,y=pad+20,w=well.x-8-tx,h=16},textW=textW,chipH=24}
  local lineY=pad+disc+6
  if h>=lineY+18+2+24+6 then out.line={x=pad,y=lineY,w=textW,h=18};out.chips={x=pad,y=h-24-6,w=textW}
  elseif h>=lineY+24+6 then out.chips={x=pad,y=lineY,w=textW}
  elseif h>=lineY+18+4 then out.line={x=pad,y=lineY,w=textW,h=18}end
  return out
 end
 local pad,disc=20,64
 local wellX=pad+disc+12
 local well={x=wellX,y=14,w=w-wellX-14,h=disc+10}
 local textW=w-2*pad
 return{pad=pad,disc=disc,well=well,name={x=pad,y=pad+disc+12,w=textW,h=28},line={x=pad,y=pad+disc+42,w=textW,h=40},
  chips={x=pad,y=pad+disc+84,w=textW},status={x=pad,y=h-8-16,w=textW,h=16},textW=textW,chipH=24}
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
-- Toy Shell: a role read on `object`'s own surface (ink on cream tiles, white on trays).
local function colorOf(role,object,property)return Kit.roleOn(object,role,property)end

-- QA v775 note 9: the machine tiles' art moves (MachineHubArt). One shared clock
-- (PetPeek's, a single RenderStepped) steps the art only while this hub is open and on
-- top; closed, covered by a machine's screen or destroyed, nothing runs. Under Reduced
-- Effects (the OS setting or the game's own, `callbacks.reduced`) the art is posed once.
function Hub:reducedMotion()
 return Kit.reduced()or(self.callbacks.reduced~=nil and self.callbacks.reduced()==true)
end
function Hub:motionWanted()
 return self.visible and not self.covered and self.content~=nil and not self.destroyed and not self:reducedMotion()
end
function Hub:syncMotion()
 local Clock=require(script.Parent.PetPeek)
 self.motionKey=self.motionKey or("MachineHubTiles:"..tostring(self))
 local wanted=self:motionWanted()
 if wanted==(self.motionOn==true)then return wanted end
 self.motionOn=wanted
 if wanted then
  Clock.subscribe(self.motionKey,function(now,dt)
   -- Reduced Effects switched on while open: stop on the resting frame.
   if not self:motionWanted()then self:syncMotion();return end
   for _,entry in ipairs(self.tileViews)do
    local art=entry.art
    if art and HubArt.Animated[entry.id]then HubArt.step(art,now,dt)end
   end
  end)
 else
  Clock.unsubscribe(self.motionKey)
  for _,entry in ipairs(self.tileViews)do if entry.art then HubArt.still(entry.art)end end
 end
 self.root:SetAttribute("TileMotion",wanted)
 return wanted
end

-- host: a full-screen Frame (its own ScreenGui). callbacks: open(id) -> bool,
-- locked(id), closed(reason), reduced() -> bool (the game's Reduced Effects setting).
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
  local L=Hub.tileLayout(r.w,r.h,phone)
  local discSize,pad=L.disc,L.pad
  local disc=Kit.frame(button,"IconDisc",nil,UDim2.fromOffset(pad,pad),UDim2.fromOffset(discSize,discSize),999);disc.BackgroundTransparency=0
  local icon=Kit.icon(disc,tile.icon,math.floor(discSize*.5),"ink");icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5)
  -- U2: the glass art well (a live picture of the machine), with a sheen across its top
  -- half, and the tile's own stitched seam where the card is tall enough for one.
  local well=Kit.well(button,"ArtWell",UDim2.fromOffset(L.well.x,L.well.y),UDim2.fromOffset(L.well.w,L.well.h),if phone then 10 else 12)
  well.ClipsDescendants=true;well.Active=false
  Kit.stage(well) -- Toy Shell R1.2.5: live previews sit on the berry stage
  local wellStroke=well:FindFirstChildOfClass("UIStroke")
  local sheen=Kit.frame(well,"Sheen",nil,UDim2.new(),UDim2.new(1,0,.5,0),if phone then 10 else 12)
  sheen.BackgroundTransparency=0;sheen.BackgroundColor3=Color3.new(1,1,1);sheen.ZIndex=well.ZIndex+6;sheen.Active=false
  Kit.node("UIGradient",sheen,{Rotation=90,Transparency=NumberSequence.new(.9,1)})
  Kit.seam(button)
  local nameLabel,lineLabel,statusLabel
  if phone then
   nameLabel=txt(button,"Name",name,"text",L.name.x,L.name.y,L.name.w,L.name.h,{TextSize=16,TextTruncate=Enum.TextTruncate.AtEnd})
   statusLabel=txt(button,"Label","","dim",L.status.x,L.status.y,L.status.w,L.status.h,{Name="Status",TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
   local lr=L.line or {x=pad,y=pad+discSize+6,w=L.textW,h=18}
   lineLabel=txt(button,"Small",line,"soft",lr.x,lr.y,lr.w,lr.h,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
   lineLabel.Visible=L.line~=nil
   Kit.fitText(nameLabel,if tile.short then {name,UICopy.get(tile.short)}else {name},L.name.w)
  else
   nameLabel=txt(button,"Name",name,"text",L.name.x,L.name.y,L.name.w,L.name.h,{TextSize=22,TextTruncate=Enum.TextTruncate.AtEnd})
   lineLabel=txt(button,"Body",line,"soft",L.line.x,L.line.y,L.line.w,L.line.h,{TextSize=15,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
   statusLabel=txt(button,"Label","","dim",L.status.x,L.status.y,L.status.w,L.status.h,{Name="Status",TextSize=12})
  end
  local dot=Kit.frame(button,"ReadyDot","stars",UDim2.new(),UDim2.fromOffset(8,8),999);dot.BackgroundTransparency=0;dot.Visible=false
  -- A chevron says "this opens a screen": a small raised badge on the well's lower right corner.
  local badgeSize=if phone then 20 else 24
  local badge=Kit.frame(button,"Go","cream",UDim2.fromOffset(L.well.x+L.well.w-badgeSize+4,L.well.y+L.well.h-badgeSize+4),UDim2.fromOffset(badgeSize,badgeSize),999)
  badge.BackgroundTransparency=0;badge.ZIndex=well.ZIndex+8;badge.Active=false;Kit.stroke(badge);Kit.setSurface(badge,"light")
  local chev=Kit.icon(badge,"chevron",if phone then 12 else 14,"soft");chev.AnchorPoint=Vector2.new(.5,.5);chev.Position=UDim2.fromScale(.5,.5)
  -- Progress chips (two at most) and the weekly shelf sticker over the well's top-right corner.
  local chips={}
  for slot=1,2 do
   local chip=Kit.chip(button,"",nil,L.chipH);chip.label.TextSize=12;chip.root.Name="Chip"..slot;chip.root.Visible=false;chip.root.Active=false
   chips[slot]=chip
  end
  local week=Kit.chip(button,UICopy.get("hub.week"),"sticker",22);week.label.TextSize=12
  week.root.Name="WeekSticker";week.root.Visible=false;week.root.Active=false;week.root.ZIndex=well.ZIndex+9
  week.set(UICopy.get("hub.week"),"sticker",Kit.Color.stars)
  week.root.Position=UDim2.fromOffset(math.max(4,L.well.x+L.well.w-week.root.Size.X.Offset+2),L.well.y-6)
  local entry={id=tile.id,iconName=tile.icon,tint=tile.tint,button=button,stroke=tileState.stroke,state=tileState,disc=disc,icon=icon,name=nameLabel,line=lineLabel,status=statusLabel,dot=dot,
   chevron=chev,phone=phone,pad=pad,layout=L,well=well,wellStroke=wellStroke,chips=chips,week=week,
   -- The line label's room: one line on phones, two wrapped lines on desktop.
   lineWidth=if phone then L.textW else math.floor(L.textW*1.8)}
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
  Kit.paint(entry.status,"TextColor3",function()return colorOf(s.tone,entry.status,"TextColor3")end)
  entry.button:SetAttribute("Locked",s.locked);entry.button:SetAttribute("Ready",s.dot)
  entry.dot.Visible=s.dot and s.text~=""
  if entry.dot.Visible then
   local p=entry.status.Position
   if entry.phone then
    entry.status.Position=UDim2.fromOffset(entry.pad+36+8+14,p.Y.Offset)
    entry.status.Size=UDim2.fromOffset(entry.layout.status.w-14,entry.layout.status.h)
    entry.dot.Position=UDim2.fromOffset(entry.pad+36+8,p.Y.Offset+4)
   else
    entry.status.Position=UDim2.fromOffset(entry.pad+14,p.Y.Offset)
    entry.dot.Position=UDim2.fromOffset(entry.pad,p.Y.Offset+4)
   end
  else
   entry.status.Position=UDim2.fromOffset(if entry.phone then entry.pad+36+8 else entry.pad,entry.status.Position.Y.Offset)
   entry.status.Size=UDim2.fromOffset(entry.layout.status.w,entry.layout.status.h)
  end
  -- Locked: the disc goes grey and the line says how it opens up.
  local tint=if s.locked then nil else Kit.tintColor(entry.tint)
  entry.disc.BackgroundColor3=tint or(if s.locked then Kit.Color.dim else Kit.Color.soft)
  entry.line.Text=if s.locked then UICopy.get("menu.subtitle.locked")else UICopy.get(Hub.Tiles[index].line)
  -- Slice C: this week's shelf takes the line on the tiles that sell it, in Stars gold.
  local shelf=Hub.shelfLines(entry.id,self.ctx)
  if shelf then Kit.fitText(entry.line,shelf,entry.lineWidth)end
  Kit.paint(entry.line,"TextColor3",function()return colorOf(if shelf then "stars"else "soft",entry.line,"TextColor3")end)
  entry.button:SetAttribute("Shelf",shelf~=nil)
  -- U2: the art (rebuilt only when what it shows changes), the "this week" highlight
  -- (gold sticker and a gold rim on the well) and the progress chips.
  local key=HubArt.key(entry.id,self.ctx,s.locked)
  if entry.artKey~=key or not entry.well:FindFirstChild("Art")then
   entry.artKey=key
   entry.art=HubArt.fill(entry.well,entry.id,self.ctx,entry.layout.well.w,entry.layout.well.h,s.locked,entry.iconName)
   if not self.motionOn then HubArt.still(entry.art)end
  end
  entry.week.root.Visible=shelf~=nil
  if entry.wellStroke then
   entry.wellStroke.Thickness=if shelf then 2 else 1;entry.wellStroke.Transparency=if shelf then .15 else Kit.Stroke.transparency
   entry.wellStroke.Color=if shelf then Kit.Color.stars else Kit.Stroke.color
  end
  local list=Hub.chips(entry.id,self.ctx)
  local room=entry.layout.chips
  local x=room and room.x or 0
  local shown={}
  for slot,chip in ipairs(entry.chips)do
   local item=room and list[slot]
   if item then chip.set(item.text,item.kind)end
   local fits=item~=nil and x+chip.root.Size.X.Offset<=room.x+room.w
   chip.root.Visible=fits
   if fits then
    chip.root.Position=UDim2.fromOffset(x,room.y);x+=chip.root.Size.X.Offset+6
    table.insert(shown,chip.label.Text)
   end
  end
  entry.button:SetAttribute("Chips",table.concat(shown,", "))
  if not s.locked then entry.button:SetAttribute("AccessibleLabel",entry.name.Text..", "..entry.line.Text)end
  Kit.paint(entry.name,"TextColor3",function()return colorOf(if s.locked then "soft"else "text",entry.name,"TextColor3")end)
  Kit.paint(entry.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised",entry.button,"BackgroundColor3")end)
  entry.stroke.Thickness=if focused then 2 else 1;entry.stroke.Transparency=if focused then 0 else Kit.Stroke.transparency
  Kit.paint(entry.stroke,"Color",function()return Kit.color("ink")end) -- Toy Shell: the outline is always ink
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
 self:syncMotion()
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
 self:syncMotion()
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
 self:syncMotion()
 if self.ring then self.ring.hide()end
 if self.callbacks.closed then self.callbacks.closed(reason or "close")end
 return true
end
function Hub:destroy()
 self:close("destroy")
 self.destroyed=true;self:syncMotion()
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
