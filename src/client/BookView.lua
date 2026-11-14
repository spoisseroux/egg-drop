-- Collection book (play-forever F2; BUILD-PLAN F2, architect review 1 to 7). Its own
-- ScreenGui (init.client.lua), opened from the Pocket Menu row "Collection book" and
-- the Companions hub. House style: the shared header in the `book` tint (mint-teal
-- #7FE0C8, decoration only), a page list of pressable tiles (name, owned / total, a %
-- bar, a sticker while a milestone waits), one open page (items owned or not as name
-- chips with a colour dot where it is cheap; discoveries as found / not-yet badges),
-- four milestone cells per page (25 / 50 / 75 / 100 with their Stars; a reached one is
-- a "Claim ★5" button) and a Records page with the lifetime counters.
--
-- Presentation only: the snapshot (`book`, `stats`, `stamps`) is the data and the
-- server computes every percent and pays every claim. A claim fires HatchRequest
-- "bookClaim" {id = new op guid, milestoneId, reward = the shown reward}; the reply
-- rides FaceplateResult with kind = "book" (BallShop's pending handling, plus a
-- timeout so a Retrying claim never sits on "Saving…" for ever).
--
-- Focus is owned here (as in BallShop / CompanionsHub): up / down (W / S, d-pad) and
-- LB / RB (Q / E) change page, right moves onto the milestones and left back to the
-- pages, A claims (on the page list: the first claim waiting on that page), B backs
-- out. Touch and mouse use the tiles and buttons directly. Nothing is Selectable.
-- Desktop 848 x 608 (scaled to fit, pet peek over the header); phones 812 x 354 get
-- the menu sheet below y 60 with scrolling lists, 44 px targets and a 12 px text floor.
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").Shared
local BookCatalog=require(Shared.BookCatalog)
local BallThemes=require(Shared.BallThemes)
local DeckThemes=require(Shared.DeckThemes)
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local Peek=require(script.Parent.PetPeek)
local View={}
View.__index=View
View.Size=Vector2.new(848,608)
View.RecordsId="records"
View.PendingTimeout=8
-- Lifetime counters shown on Records, in order (`parkGames` has no source yet and the
-- server leaves it out; an unknown key is never shown).
View.StatsOrder=table.freeze({"rounds","winsEasy","winsMedium","winsHard","tidyWins","merges","bestChain","tierFive",
 "itemsUsed","pets","starsEarned","starsSpent"})
-- Desktop rects (panel units): page list and page pane under the 84 px header.
View.Regular=table.freeze({list={x=24,y=84,w=264,h=452},pane={x=304,y=84,w=520,h=452},hints=566,tileGap=8})
View.PeekSlot=table.freeze({x=420,y=4,w=200,h=80})
-- Item thumbnails (v1 track D). Balls draw their themed balls live (JellySprite, as the
-- BallShop strip) and faceplates the Deck style mini deck; wardrobe, toys, finishes and
-- discoveries come from one atlas (scripts/deck_art/build_book_atlas.py ->
-- assets/ui/book/book-atlas.png, 128 px cells, 8 columns; rows 0..3 full colour, rows
-- 4..7 white silhouettes the client tints). `atlas` stays nil until the upload: a page
-- whose items are not all drawable keeps the old name chips.
-- Slots past `perPage` (32) live on page 2 (`atlas2`, book-atlas-2.png; slice A face items).
View.Art={atlas="rbxassetid://99292277254782",atlas2="rbxassetid://76026456070624",perPage=32,cell=128,columns=8,silhouetteRows=4,
 slots=table.freeze({["pip:beanie"]=1,["pip:sunhat"]=2,["pip:flowercrown"]=3,["pip:tee"]=4,["pip:hoodie"]=5,["pip:beads"]=6,
  ["pip:bellcollar"]=7,["pip:ring"]=8,["pip:starstud"]=9,["pip:sparkle"]=10,["pip:sleepy"]=11,["pip:blep"]=12,["pip:heart"]=13,
  ["toy:ball"]=14,["toy:bone"]=15,["toy:sparkler"]=16,["finish:gloss"]=17,["finish:matte"]=18,["finish:metal"]=19,
  ["tier_five"]=20,["chain_five"]=21,["win_bank_pair"]=22,["win_creek_crossing"]=23,["win_lantern_chain"]=24,
  ["win_ripple_relay"]=25,["win_bank_bounce"]=26,["win_mirror_marks"]=27,["win_easy"]=28,["win_medium"]=29,["win_hard"]=30,
  ["pip:round"]=31,["pip:happy"]=32,["pip:w"]=33,["pip:lash"]=34})}
View.Thumb=table.freeze({size=48,pad=2,nameH=18,gap=8})
-- Ball tiers shown in a ball theme's thumbnail (small, middle, biggest).
View.ThumbTiers=table.freeze({1,3,5})

-- ── Pure ─────────────────────────────────────────────────────────────────────
local function milestoneList(page)return type(page)=="table"and type(page.milestones)=="table"and page.milestones or {}end
-- Milestones reached and not claimed on one page (local claims count as claimed).
function View.claimableCount(page,localClaimed)
 local n=0
 for _,m in ipairs(milestoneList(page))do
  if m.reached==true and m.claimed~=true and not(localClaimed and localClaimed[m.id])then n+=1 end
 end
 return n
end
-- The list entries: every snapshot page in order (five or six; Pets joins once a
-- second pet exists), then Records. (Instances read theirs with self:entries().)
function View.pageEntries(book)
 local out={}
 for _,page in ipairs(type(book)=="table"and type(book.pages)=="table"and book.pages or {})do
  if type(page)=="table"and type(page.id)=="string"then table.insert(out,page)end
 end
 table.insert(out,{id=View.RecordsId,name=UICopy.get("book.records.name"),records=true})
 return out
end
-- One milestone's state: "claimed", "claim" (reached, waiting), "pending", "retrying",
-- "failed" (the last try did not land; it can be tried again) or "locked" (not reached).
-- pending: {milestoneId, retrying}; failed: {[id] = text}; localClaimed: {[id] = true}.
function View.milestoneState(m,pending,failed,localClaimed)
 if type(m)~="table"then return "locked"end
 if m.claimed==true or(localClaimed and localClaimed[m.id])then return "claimed"end
 if pending and pending.milestoneId==m.id then return if pending.retrying then "retrying"else "pending"end
 if m.reached~=true then return "locked"end
 if failed and failed[m.id]then return "failed"end
 return "claim"
end
-- What a milestone cell shows: {text, enabled, kind ("button" | "chip"), tone}.
function View.milestoneLook(m,state,compact)
 local reward=m and m.reward or 0
 local pct=tostring(m and m.percent or 0).."%"
 if state=="claim"or state=="failed"then
  return{text=UICopy.get("book.claim",{reward=reward}),enabled=true,kind="button"}
 elseif state=="pending"then return{text=UICopy.get("book.pending"),enabled=false,kind="button"}
 elseif state=="retrying"then return{text=UICopy.get("book.retrying"),enabled=false,kind="button"}
 elseif state=="claimed"then return{text=if compact then "✓ "..pct else "✓ "..UICopy.get("book.claimed"),kind="chip",tone="accent"}end
 return{text=if compact then pct.."  ★"..reward else "★ "..reward,kind="chip",tone="soft"}
end
-- Records rows {key, label, value}: the known counters the snapshot carries, then stamps.
function View.statsRows(stats,stamps)
 local rows={}
 if type(stats)=="table"then
  for _,key in ipairs(View.StatsOrder)do
   local value=stats[key]
   if type(value)=="number"and value==value then
    table.insert(rows,{key=key,label=UICopy.get("book.stats."..key),value=Kit.formatStars(math.max(0,math.floor(value)))})
   end
  end
 end
 if type(stamps)=="number"then table.insert(rows,{key="stamps",label=UICopy.get("book.stats.stamps"),value=Kit.formatStars(math.max(0,math.floor(stamps)))})end
 return rows
end
-- Bookworm progress: pages finished and claimed at 100% (the server grants the plate
-- on the claim that makes three).
function View.bookworm(book)
 local count=0
 if type(book)=="table"and type(book.claimed)=="table"then
  for _,id in ipairs(book.claimed)do
   local m=BookCatalog.milestone(id)
   if m and m.percent==100 then count+=1 end
  end
 end
 local earned=type(book)=="table"and book.faceplateEarned==true
 return{count=math.min(count,BookCatalog.PagesForFaceplate),need=BookCatalog.PagesForFaceplate,earned=earned or count>=BookCatalog.PagesForFaceplate}
end
local function toColor(value)
 if typeof(value)=="Color3"then return value end
 if type(value)=="string"then local ok,c=pcall(Color3.fromHex,value);if ok then return c end end
 return nil
end
-- The items of one page {id, name, owned, color?} (colour dots where they are free:
-- a ball theme's middle tier, a faceplate's accent).
function View.items(pageId,ownedIds)
 local page=BookCatalog.Pages[pageId];if not page then return {}end
 local owned={}
 for _,id in ipairs(type(ownedIds)=="table"and ownedIds or {})do owned[id]=true end
 local out={}
 for _,item in ipairs(page.items)do
  local color
  if pageId=="balls"then
   local theme=BallThemes.ById[item.id];local ramp=theme and theme.ramps and theme.ramps[3]
   color=ramp and toColor(ramp.body)
  elseif pageId=="faceplates"then
   local theme=DeckThemes.ById[item.id];color=theme and toColor(theme.accent)
  end
  table.insert(out,{id=item.id,name=item.name,owned=owned[item.id]==true,color=color,discovery=pageId=="discoveries"})
 end
 return out
end
-- Pure: the atlas cell for a book item id, owned (full colour) or not (silhouette), or nil
-- while the atlas has no id or the item has no slot. {image, offset, size}.
function View.atlasRect(id,owned)
 local art=View.Art
 if type(art.atlas)~="string"or art.atlas==""then return nil end
 local slot=art.slots[id];if not slot then return nil end
 local image=art.atlas
 local perPage=art.perPage or math.huge
 if slot>perPage then
  image=art.atlas2;slot-=perPage
  if type(image)~="string"or image==""then return nil end
 end
 local column,row=(slot-1)%art.columns,(slot-1)//art.columns
 if not owned then row+=art.silhouetteRows end
 return{image=image,offset=Vector2.new(column*art.cell,row*art.cell),size=Vector2.new(art.cell,art.cell)}
end
-- Pure: how an item's thumbnail draws: "ball" (live themed balls), "plate" (mini deck),
-- "atlas", or nil (no picture: the page falls back to name chips).
function View.thumbKind(pageId,item)
 if type(item)~="table"then return nil end
 if pageId=="balls"then return if BallThemes.ById[item.id]then "ball"else nil end
 if pageId=="faceplates"then return if DeckThemes.ById[item.id]then "plate"else nil end
 return if View.atlasRect(item.id,true)then "atlas"else nil
end
-- Pure: true when every item on the page has a thumbnail (cards), else name chips.
function View.pageHasThumbs(pageId,items)
 if #items==0 then return false end
 for _,item in ipairs(items)do if not View.thumbKind(pageId,item)then return false end end
 return true
end
-- Focus movement in the page list (clamped, no wrap).
function View.stepPage(index,delta,count)return math.clamp(index+delta,1,math.max(1,count))end

local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
local function colorOf(role)
 if role=="accent"or role=="selected"or role=="raised"or role=="well"or role=="panel"then return Kit.color(role)end
 return Kit.Color[role]or Kit.Color.text
end
-- Hint glyph letters keep the 12 px floor (Kit.glyph draws 22 px caps at 11 px).
local function glyph12(glyph)
 for _,label in ipairs(glyph:GetDescendants())do if label:IsA("TextLabel")and label.TextSize<12 then label.TextSize=12 end end
end

-- ── Instances ────────────────────────────────────────────────────────────────
-- host: a full-screen Frame. callbacks: send(action, payload) (default fires
-- Remotes.HatchRequest), claimed(message, pending) (a saved claim: toast it),
-- back(), closed(reason).
function View.new(host,callbacks)
 local self=setmetatable({host=host,callbacks=callbacks or {},visible=false,ctx={book=nil,stats=nil,stamps=nil,wallet=0,revision=0},
  pageIndex=1,zone="pages",milestoneIndex=1,pending=nil,failed={},localClaimed={},pendingToken=0,tiles={},cells={}},View)
 -- QA Q2.1: one full-screen shade beside the panel (never its parent).
 local shade=Kit.modalShade(host,"BookShade",30);self.shade=shade
 local root=Kit.frame(host,"CollectionBook","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
 root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.ClipsDescendants=true;root.ZIndex=31;root.Visible=false;self.rootStroke=Kit.stroke(root)
 local gradient=Kit.frame(root,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 self.gradient=gradient;self.root=root
 self.scale=Kit.node("UIScale",root,{Scale=1})
 return self
end

function View:entries()return View.pageEntries(self.ctx.book)end
function View:currentEntry()local list=self:entries();return list[math.clamp(self.pageIndex,1,#list)]end

-- Builds the whole screen for the regular panel (view nil) or a phone view.
function View:build(view)
 if self.content then Peek.hide(self.content);self.content:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 self.view=view;self.key=View.viewKey(view,self:entries())
 local root=self.root;local phone=view~=nil
 root.BackgroundTransparency=if phone then 1 else 0;self.gradient.Visible=not phone;self.rootStroke.Enabled=not phone;root.ClipsDescendants=not phone
 Kit.setShadeAlpha(self.shade,Kit.ShadeAlpha) -- R3.1: one full-screen shade, phones too
 local W=if phone then view.W else 848
 local H=if phone then view.H else 608
 self.W,self.H=W,H
 local content=Kit.frame(root,"Content",nil,UDim2.new(),UDim2.fromOffset(W,H));content.ZIndex=root.ZIndex+2
 self.content=content
 Kit.halftone(content,"book",phone)
 local body=content
 if phone then
  local sheet=Kit.sheet(content,W,H)
  body=Kit.frame(content,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 end
 self.body=body
 self.header=Kit.header(body,{title=UICopy.get("book.title"),eyebrow=UICopy.get("book.eyebrow"),tint="book",compact=phone,width=W,
  left=if phone then view.hx else 24,onBack=function()self:back()end})
 self.header.root.Name="BookHeader"
 if self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
 self:buildList(body,phone)
 self:buildPane(body,phone)
 if not phone then self:buildHints(content)end
 self.ring=Kit.focusRing(root)
 self:openPage(self.pageIndex,true)
end
function View.viewKey(view,entries)
 local ids={}
 for _,entry in ipairs(entries or {})do table.insert(ids,entry.id)end
 return(if view then string.format("%dx%d",view.W,view.H)else "regular")..":"..table.concat(ids,",")
end

-- Page list: one pressable tile per page plus Records.
function View:buildList(body,phone)
 local entries=self:entries()
 self.tiles={}
 local x,y,w,h,tileH,gap
 local parent
 if phone then
  x,y,w,h=20,64,200,self.H-64-12;tileH,gap=48,6
  local list=Kit.node("ScrollingFrame",body,{Name="Pages",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
   ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6,
   CanvasSize=UDim2.fromOffset(0,#entries*(tileH+gap)-gap+3+Kit.Lip.compact)})
  parent=list;self.pageList=list
  -- QA v2 R3.2: the first page tile's selection stroke was cut at the top and left.
  local bleed=Kit.scrollBleed(list,4)
  list.CanvasSize+=UDim2.fromOffset(0,bleed*2)
  x,y,w=0,0,w-8
 else
  local R=View.Regular.list
  x,y,w,h=R.x,R.y,R.w,R.h;gap=View.Regular.tileGap
  tileH=math.min(56,math.floor((h-(#entries-1)*gap)/#entries))
  parent=body;self.pageList=nil
 end
 self.tileH,self.tileGap=tileH,gap
 for index,entry in ipairs(entries)do
  local ty=y+(index-1)*(tileH+gap)
  local tile,state=Kit.tile(parent,"Page_"..entry.id,{selectable=false,radius=12,compact=phone,position=UDim2.fromOffset(x,ty),size=UDim2.fromOffset(w,tileH)})
  tile:SetAttribute("PageId",entry.id)
  local name=txt(tile,"Name",entry.name or entry.id,"text",12,if phone then 5 else 7,w-24-70,if phone then 20 else 22,{TextSize=if phone then 14 else 16,TextTruncate=Enum.TextTruncate.AtEnd})
  local count=txt(tile,"Counter","","soft",w-12-80,if phone then 5 else 7,80,if phone then 20 else 22,{TextSize=if phone then 12 else 14,TextXAlignment=Enum.TextXAlignment.Right})
  local bar,line
  if entry.records then
   line=txt(tile,"Small",UICopy.get("book.records.line"),"soft",12,if phone then 26 else 30,w-24,18,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
  else
   bar=Kit.progress(tile,if phone then 6 else 8);bar.root.Position=UDim2.fromOffset(12,tileH-(if phone then 14 else 18));bar.root.Size=UDim2.fromOffset(w-24,if phone then 6 else 8)
  end
  -- Claim marks: a sticker on desktop (the list never scrolls there), a gold dot on
  -- phones (stickers never sit at a scroll area's edge).
  local sticker,dot
  if phone then
   dot=Kit.frame(tile,"ClaimDot","stars",UDim2.fromOffset(12,13),UDim2.fromOffset(8,8),999);dot.Visible=false;dot.ZIndex=tile.ZIndex+4
  else
   sticker=Kit.chip(tile,UICopy.get("book.claimShort",{reward=0}),"sticker",24)
   sticker.root.AnchorPoint=Vector2.new(1,0);sticker.root.Position=UDim2.fromOffset(w-8,-1);sticker.root.Visible=false
  end
  self.tiles[index]={id=entry.id,button=tile,stroke=state.stroke,state=state,name=name,count=count,bar=bar,line=line,sticker=sticker,dot=dot}
  tile.Activated:Connect(function()
   if not self.visible then return end
   self.zone="pages";self:openPage(index);Kit.boing(tile)
  end)
 end
end

-- The open page's pane: title, %, bar, milestone cells, items (or Records rows).
function View:buildPane(body,phone)
 local pane=Kit.card(body,"PagePane",nil,{pad=16,seam=true})
 local px,py,pw,ph
 if phone then px,py=232,64;pw,ph=self.W-20-232,self.H-64-12 else local R=View.Regular.pane;px,py,pw,ph=R.x,R.y,R.w,R.h end
 pane.Position=UDim2.fromOffset(px,py);pane.Size=UDim2.fromOffset(pw,ph)
 self.pane,self.paneW,self.paneH=pane,pw,ph
 local pad=if phone then 12 else 16
 self.pad=pad
 local inner=pw-pad*2
 local percentW=if phone then 150 else 180
 self.pageName=txt(pane,"Title","","text",pad,if phone then 6 else 12,inner-percentW,if phone then 24 else 30,{TextSize=if phone then 18 else 24,TextTruncate=Enum.TextTruncate.AtEnd})
 self.pagePercent=txt(pane,"Counter","","text",pad+inner-percentW,if phone then 6 else 12,percentW,if phone then 24 else 30,{TextSize=if phone then 14 else 18,TextXAlignment=Enum.TextXAlignment.Right})
 self.pageLine=txt(pane,"Small","","soft",pad,if phone then 30 else 42,inner,18,{TextSize=if phone then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 local bar=Kit.progress(pane,if phone then 6 else 10);bar.root.Position=UDim2.fromOffset(pad,if phone then 32 else 46);bar.root.Size=UDim2.fromOffset(inner,if phone then 6 else 10)
 self.pageBar=bar
 -- Milestone cells: label + 44 px element on desktop, the 44 px element alone on phones.
 local cellGap=if phone then 8 else 12
 local cellW=math.floor((inner-3*cellGap)/4)
 local cellY=if phone then 44 else 68
 self.cells={}
 for index=1,4 do
  local cx=pad+(index-1)*(cellW+cellGap)
  local holder=Kit.frame(pane,"Milestone"..index,nil,UDim2.fromOffset(cx,cellY),UDim2.fromOffset(cellW,if phone then 44 else 64))
  local label
  if not phone then label=txt(holder,"Label","","dim",0,0,cellW,16,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Center})end
  local ey=if phone then 0 else 20
  local button,bstate=Kit.button(holder,"Claim",{variant="reward",text="Claim",size=Vector2.new(cellW,44),textSize=if phone then 14 else 15,selectable=false,compact=true})
  button.Position=UDim2.fromOffset(0,ey)
  local chip=Kit.frame(holder,"Chip","well",UDim2.fromOffset(0,ey),UDim2.fromOffset(cellW,44),12);Kit.stroke(chip)
  local chipText=txt(chip,"Counter","","soft",0,0,cellW,44,{TextSize=if phone then 13 else 15,TextXAlignment=Enum.TextXAlignment.Center,AutoLocalize=true})
  self.cells[index]={holder=holder,label=label,button=button,bstate=bstate,chip=chip,chipText=chipText}
  button.Activated:Connect(function()
   if not self.visible then return end
   self.zone="milestones";self.milestoneIndex=index;self:paintFocus()
   self:claimIndex(index)
  end)
 end
 self.cellBottom=cellY+(if phone then 44 else 64)
 -- One status line under the cells: why the last claim did not land (or "Still saving").
 self.status=txt(pane,"Small","","dangerText",pad,self.cellBottom+2,inner,if phone then 16 else 20,{Name="Status",TextSize=if phone then 12 else 13,TextTruncate=Enum.TextTruncate.AtEnd})
 self.status.Visible=false
 self.cellBottom+=if phone then 16 else 20
 -- Items / records scroller below the milestones, the faceplates footer under it.
 local footerH=if phone then 18 else 36
 self.footerH=footerH
 local gy=self.cellBottom+(if phone then 8 else 12)
 local footer=Kit.frame(pane,"Footer",if phone then nil else "well",UDim2.fromOffset(pad,ph-pad-footerH),UDim2.fromOffset(inner,footerH),10)
 if not phone then Kit.stroke(footer)end
 self.footer=footer
 self.footerText=txt(footer,"Small","","soft",if phone then 0 else 12,0,inner-(if phone then 60 else 90),footerH,{TextSize=if phone then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 self.footerCount=txt(footer,"Counter","","text",inner-(if phone then 56 else 84),0,if phone then 56 else 72,footerH,{TextSize=if phone then 12 else 15,TextXAlignment=Enum.TextXAlignment.Right})
 local grid=Kit.node("ScrollingFrame",pane,{Name="Items",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(pad,gy),
  Size=UDim2.fromOffset(inner,ph-pad-gy),ScrollBarThickness=4,ZIndex=pane.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
  ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6,CanvasSize=UDim2.new()})
 self.grid,self.gridTop,self.gridW=grid,gy,inner
end

function View:buildHints(content)
 local hints=Kit.frame(content,"Hints",nil,UDim2.fromOffset(24,View.Regular.hints),UDim2.fromOffset(560,24))
 local x=0
 for _,pair in ipairs({{"+",UICopy.get("book.hint.move")},{"LB",UICopy.get("book.hint.pages")},{"A",UICopy.get("book.hint.claim")},{"B",UICopy.get("book.hint.back")}})do
  local g=Kit.glyph(hints,pair[1],false,22,true);g.Position=UDim2.fromOffset(x,1);glyph12(g)
  local t=txt(hints,"Small",pair[2],"soft",x+g.Size.X.Offset+6,0,120,24);t.AutomaticSize=Enum.AutomaticSize.X
  x+=g.Size.X.Offset+6+Kit.measure(pair[2],"Small",14).X+18
 end
 txt(content,"Small",UICopy.get("book.promise"),"dim",424,View.Regular.hints,400,24,{Name="Promise",TextXAlignment=Enum.TextXAlignment.Right})
end

-- ── Page contents ────────────────────────────────────────────────────────────
function View:clearGrid()
 for _,child in ipairs(self.grid:GetChildren())do if child:IsA("GuiObject")then child:Destroy()end end
end
-- Thumbnails (v1 track D) inside a card's picture well. Owned items draw in full colour;
-- missing ones are a tinted silhouette (atlas) or veiled (live balls / mini deck).
local function ballThumb(well,themeId,w,h,owned)
 local LCD=require(script.Parent.JellyLCD)
 local Sprite=require(script.Parent.JellySprite)
 local sizes,total={},0
 for i,tier in ipairs(View.ThumbTiers)do sizes[i]=LCD.ballRuns(themeId,tier,"idle",0,false).size;total+=sizes[i]end
 local gap=4
 local px=math.min((h-4)/sizes[#sizes],(w-12-gap*(#sizes-1))/total)
 local x=(w-(total*px+gap*(#sizes-1)))/2
 for i,tier in ipairs(View.ThumbTiers)do
  local d=sizes[i]*px
  local holder=Kit.frame(well,"Ball"..tier,nil,UDim2.fromOffset(math.floor(x),math.floor(h-2-d)),UDim2.fromOffset(d,d))
  Sprite.preview(holder).set(themeId,tier,if owned then "idle"else "sleepy",0,false)
  x+=d+gap
 end
end
local function plateThumb(well,plateId,w,h)
 local Shop=require(script.Parent.FaceplateShop)
 local width=math.min(2*(h-4),w-12)
 local deck=Shop.miniDeck(well,width,UDim2.fromOffset(math.floor((w-width)/2),math.floor((h-width/2)/2)))
 deck.set(DeckThemes.ById[plateId],plateId)
 return deck
end
local function atlasThumb(well,id,owned,w,h)
 local rect=View.atlasRect(id,owned);if not rect then return nil end
 local size=View.Thumb.size
 local image=Kit.node("ImageLabel",well,{Name="Thumb",BackgroundTransparency=1,Image=rect.image,ImageRectOffset=rect.offset,ImageRectSize=rect.size,
  Position=UDim2.fromOffset(math.floor((w-size)/2),math.floor((h-size)/2)),Size=UDim2.fromOffset(size,size),ZIndex=well.ZIndex+1,Active=false})
 if not owned then Kit.paint(image,"ImageColor3","line");image.ImageTransparency=.45 end
 return image
end

-- Items for a page: picture cards when every item has a thumbnail (balls and faceplates
-- always; the atlas pages once it is uploaded), else the name chips (or discovery
-- badges). Rebuilt only when the page or what is owned on it changes (a snapshot),
-- never per frame.
function View:buildItems(entry)
 self:clearGrid()
 local items=View.items(entry.id,entry.ownedIds)
 if View.pageHasThumbs(entry.id,items)then return self:buildCards(entry,items)end
 local phone=self.view~=nil
 local discoveries=entry.id=="discoveries"
 local cols=if discoveries then 2 elseif phone then(if self.gridW>=420 then 3 else 2)else 3
 local gap=8
 local cw=math.floor((self.gridW-8-(cols-1)*gap)/cols)
 local ch=if phone then 32 else 36
 self.root:SetAttribute("ItemLayout","chips")
 for index,item in ipairs(items)do
  local col,row=(index-1)%cols,math.floor((index-1)/cols)
  local chip=Kit.frame(self.grid,"Item_"..item.id,if item.owned then "raised"else "well",UDim2.fromOffset(col*(cw+gap),row*(ch+gap)),UDim2.fromOffset(cw,ch),10)
  local stroke=Kit.stroke(chip)
  if item.owned and discoveries then stroke.Thickness=2;stroke.Transparency=0;stroke.Color=Kit.Tint.book end
  chip:SetAttribute("Owned",item.owned);chip:SetAttribute("AccessibleLabel",item.name..", "..UICopy.get(if item.owned then "book.found"else "book.missing"))
  local x=10
  if discoveries then
   local icon=Kit.icon(chip,if item.owned then "star"else "lock",16,if item.owned then "stars"else "dim");icon.AnchorPoint=Vector2.new(0,.5);icon.Position=UDim2.new(0,x,.5,0)
   x+=24
  elseif item.color then
   local dot=Kit.frame(chip,"Swatch",nil,UDim2.new(0,x,.5,0),UDim2.fromOffset(12,12),999);dot.AnchorPoint=Vector2.new(0,.5)
   dot.BackgroundTransparency=if item.owned then 0 else .55;dot.BackgroundColor3=item.color
   x+=20
  end
  local right=if item.owned then 28 else 10
  local name=txt(chip,"Small",item.name,if item.owned then "text"else "soft",x,0,cw-x-right,ch,{TextSize=if phone then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
  if not item.owned then name.TextTransparency=.15 end
  if item.owned and not discoveries then
   local check=Kit.icon(chip,"check",16,"accent");check.AnchorPoint=Vector2.new(1,.5);check.Position=UDim2.new(1,-8,.5,0)
  end
 end
 local rows=math.ceil(#items/cols)
 self.grid.CanvasSize=UDim2.fromOffset(0,math.max(0,rows*(ch+gap)-gap))
 if #items==0 then txt(self.grid,"Small",UICopy.get("book.empty"),"soft",0,0,self.gridW-8,24,{TextSize=if phone then 12 else 14})end
end
-- Picture cards: a well with the thumbnail (48 px, 52 px tall well), the name under it
-- and a check beside the name when owned. Same columns as the chips.
function View:buildCards(entry,items)
 local phone=self.view~=nil
 local discoveries=entry.id=="discoveries"
 local T=View.Thumb
 local cols=if discoveries then 2 elseif phone then(if self.gridW>=420 then 3 else 2)else 3
 local gap=T.gap
 local cw=math.floor((self.gridW-8-(cols-1)*gap)/cols)
 local wellH=T.size+T.pad*2
 local ch=6+wellH+3+T.nameH+5
 self.root:SetAttribute("ItemLayout","cards")
 for index,item in ipairs(items)do
  local col,row=(index-1)%cols,math.floor((index-1)/cols)
  local card=Kit.frame(self.grid,"Item_"..item.id,if item.owned then "raised"else "well",UDim2.fromOffset(col*(cw+gap),row*(ch+gap)),UDim2.fromOffset(cw,ch),10)
  local stroke=Kit.stroke(card)
  if item.owned and discoveries then stroke.Thickness=2;stroke.Transparency=0;stroke.Color=Kit.Tint.book end
  card:SetAttribute("Owned",item.owned);card:SetAttribute("AccessibleLabel",item.name..", "..UICopy.get(if item.owned then "book.found"else "book.missing"))
  local wellW=cw-12
  local well=Kit.frame(card,"Picture","well",UDim2.fromOffset(6,6),UDim2.fromOffset(wellW,wellH),8)
  well.ClipsDescendants=true
  local kind=View.thumbKind(entry.id,item)
  card:SetAttribute("Thumb",kind)
  if kind=="ball"then ballThumb(well,item.id,wellW,wellH,item.owned)
  elseif kind=="plate"then plateThumb(well,item.id,wellW,wellH)
  elseif kind=="atlas"then atlasThumb(well,item.id,item.owned,wellW,wellH)end
  if not item.owned and kind~="atlas"then
   -- Live pictures have no silhouette: a well-coloured veil fades them back.
   local veil=Kit.frame(well,"Veil","well",UDim2.new(),UDim2.fromScale(1,1),8);veil.BackgroundTransparency=.35;veil.ZIndex=well.ZIndex+20
  end
  local right=if item.owned then 22 else 0
  local name=txt(card,"Small",item.name,if item.owned then "text"else "soft",8,6+wellH+3,cw-16-right,T.nameH,
   {TextSize=if phone then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
  if not item.owned then name.TextTransparency=.15 end
  if item.owned then
   local check=Kit.icon(card,if discoveries then "star"else "check",16,if discoveries then "stars"else "accent")
   check.AnchorPoint=Vector2.new(1,.5);check.Position=UDim2.fromOffset(cw-6,6+wellH+3+T.nameH/2)
  end
 end
 local rows=math.ceil(#items/cols)
 self.grid.CanvasSize=UDim2.fromOffset(0,math.max(0,rows*(ch+gap)-gap))
end
-- Records: label / value rows, two columns on desktop and wide phones.
function View:buildRecords()
 self:clearGrid()
 local phone=self.view~=nil
 local rows=View.statsRows(self.ctx.stats,self.ctx.stamps)
 local cols=if self.gridW>=420 then 2 else 1
 local gap=if phone then 6 else 8
 local cw=math.floor((self.gridW-8-(cols-1)*12)/cols)
 local rh=if phone then 30 else 36
 local perCol=math.ceil(#rows/cols)
 for index,row in ipairs(rows)do
  local col,r=math.floor((index-1)/math.max(1,perCol)),(index-1)%math.max(1,perCol)
  local line=Kit.frame(self.grid,"Stat_"..row.key,"well",UDim2.fromOffset(col*(cw+12),r*(rh+gap)),UDim2.fromOffset(cw,rh),10)
  line:SetAttribute("StatKey",row.key)
  txt(line,"Small",row.label,"soft",12,0,cw-24-90,rh,{Name="Label",TextSize=if phone then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
  txt(line,"Counter",row.value,"text",cw-12-90,0,90,rh,{Name="Value",TextSize=if phone then 13 else 15,TextXAlignment=Enum.TextXAlignment.Right})
 end
 self.grid.CanvasSize=UDim2.fromOffset(0,math.max(0,perCol*(rh+gap)-gap))
 if #rows==0 then txt(self.grid,"Small",UICopy.get("book.records.empty"),"soft",0,0,self.gridW-8,24,{TextSize=if phone then 12 else 14})end
 self.root:SetAttribute("RecordRows",#rows)
end

-- Opens the page at `index` (list order) and repaints.
function View:openPage(index,instant)
 local entries=self:entries()
 index=math.clamp(index,1,#entries)
 local changed=index~=self.pageIndex or self.builtPage==nil
 self.pageIndex=index
 local entry=entries[index]
 if entry.records then self.zone="pages"end
 if changed or self.builtPage~=entry.id then self.builtPage=nil;self.itemsKey=nil end
 self:paint()
 if changed and self.grid then self.grid.CanvasPosition=Vector2.zero end
 if self.pageList then
  -- Keep the open page's tile in view on phones.
  local top=(index-1)*(self.tileH+self.tileGap);local bottom=top+self.tileH
  local viewH=self.pageList.AbsoluteWindowSize.Y;if viewH<=0 then viewH=self.pageList.Size.Y.Offset end
  local y=self.pageList.CanvasPosition.Y
  if top-8<y then y=top-8 elseif bottom+8>y+viewH then y=bottom+8-viewH end
  self.pageList.CanvasPosition=Vector2.new(0,math.clamp(y,0,math.max(0,self.pageList.CanvasSize.Y.Offset-viewH)))
 end
 self:paintFocus(instant)
end

-- ── Paint ────────────────────────────────────────────────────────────────────
function View:paintList()
 local entries=self:entries()
 for index,tile in ipairs(self.tiles)do
  local entry=entries[index]
  local open=index==self.pageIndex
  tile.state.setSelected(open,false)
  if entry and not entry.records then
   tile.count.Text=UICopy.get("book.owned",{owned=entry.owned or 0,total=entry.total or 0})
   if tile.bar then tile.bar.set(entry.percent or 0,100,false,false)end
   local waiting=View.claimableCount(entry,self.localClaimed)
   local reward=0
   for _,m in ipairs(milestoneList(entry))do
    if m.reached==true and m.claimed~=true and not self.localClaimed[m.id]then reward+=m.reward or 0 end
   end
   if tile.sticker then
    tile.sticker.root.Visible=waiting>0
    if waiting>0 then tile.sticker.set(UICopy.get("book.claimShort",{reward=reward}),"sticker",Kit.Tint.book)end
   end
   if tile.dot then
    tile.dot.Visible=waiting>0
    local w=Kit.measure(tile.name.Text,"Name",tile.name.TextSize).X
    tile.dot.Position=UDim2.fromOffset(math.min(12+math.ceil(w)+6,tile.button.Size.X.Offset-100),13)
   end
   tile.button:SetAttribute("Claimable",waiting)
   tile.button:SetAttribute("AccessibleLabel",(entry.name or entry.id)..", "..tile.count.Text..(if waiting>0 then ", "..waiting.." to claim"else ""))
  elseif entry then
   tile.count.Text=""
   tile.button:SetAttribute("AccessibleLabel",entry.name)
  end
 end
end

function View:paintPane()
 local entry=self:currentEntry();if not entry then return end
 local phone=self.view~=nil
 self.pageName.Text=entry.name or entry.id
 self.root:SetAttribute("OpenPage",entry.id)
 if entry.records then
  self.pagePercent.Text="";self.pageBar.root.Visible=false
  self.pageLine.Visible=true;self.pageLine.Text=UICopy.get("book.records.line")
  for _,cell in ipairs(self.cells)do cell.holder.Visible=false end
  self.footer.Visible=false;self.status.Visible=false
  local top=(if phone then 30 else 42)+24
  self.grid.Position=UDim2.fromOffset(self.pad,top);self.grid.Size=UDim2.fromOffset(self.gridW,self.paneH-self.pad-top)
  local parts={}
  for _,statKey in ipairs(View.StatsOrder)do table.insert(parts,tostring(type(self.ctx.stats)=="table"and self.ctx.stats[statKey]))end
  local key="records:"..table.concat(parts,",")..":"..tostring(self.ctx.stamps)
  if self.builtPage~="records"or self.itemsKey~=key then self:buildRecords();self.builtPage="records";self.itemsKey=key end
  return
 end
 self.pageLine.Visible=false
 self.pagePercent.Text=tostring(entry.percent or 0).."%  ·  "..UICopy.get("book.owned",{owned=entry.owned or 0,total=entry.total or 0})
 self.pageBar.root.Visible=true;self.pageBar.set(entry.percent or 0,100,false,false)
 local ms=milestoneList(entry)
 local failure
 for _,m in ipairs(ms)do if self.failed[m.id]and not(self.pending and self.pending.milestoneId==m.id)then failure=self.failed[m.id]end end
 if self.pending and self.pending.retrying and self.pending.milestoneId then
  for _,m in ipairs(ms)do if m.id==self.pending.milestoneId then failure=UICopy.get("book.retrying")end end
 end
 self.status.Visible=failure~=nil;self.status.Text=failure or ""
 local statusTone=if self.pending and self.pending.retrying then "soft"else "dangerText"
 Kit.paint(self.status,"TextColor3",function()return Kit.Color[statusTone]end)
 for index,cell in ipairs(self.cells)do
  local m=ms[index]
  cell.holder.Visible=m~=nil
  if m then
   local state=View.milestoneState(m,self.pending,self.failed,self.localClaimed)
   local look=View.milestoneLook(m,state,phone)
   if cell.label then cell.label.Text=tostring(m.percent).."%"end
   cell.button.Visible=look.kind=="button";cell.chip.Visible=look.kind=="chip"
   if look.kind=="button"then Kit.setText(cell.button,look.text);Kit.setEnabled(cell.button,look.enabled==true)
   else
    cell.chipText.Text=look.text
    Kit.paint(cell.chipText,"TextColor3",function()return colorOf(look.tone)end)
   end
   cell.holder:SetAttribute("MilestoneId",m.id);cell.holder:SetAttribute("State",state)
   cell.button:SetAttribute("AccessibleLabel",tostring(m.percent).."%, "..look.text)
  end
 end
 -- Faceplates page footer: the Bookworm plate for finishing any three pages.
 local isPlates=entry.id=="faceplates"
 self.footer.Visible=isPlates
 local gridBottom=self.paneH-self.pad-(if isPlates then self.footerH+8 else 0)
 local gy=self.cellBottom+(if phone then 8 else 12)
 self.grid.Position=UDim2.fromOffset(self.pad,gy);self.grid.Size=UDim2.fromOffset(self.gridW,math.max(32,gridBottom-gy))
 if isPlates then
  local worm=View.bookworm(self.ctx.book)
  local line=if worm.earned then UICopy.get("book.bookworm.done")else UICopy.get("book.bookworm.line")
  self.footerText.Text=line
  if not worm.earned then Kit.fitText(self.footerText,{line,UICopy.get("book.bookworm.short")})end
  self.footerCount.Text=UICopy.get("book.bookworm.count",{count=worm.count})
  Kit.paint(self.footerCount,"TextColor3",function()return if worm.earned then Kit.Tint.book else Kit.Color.text end)
  self.root:SetAttribute("Bookworm",worm.count)
 end
 local key=entry.id..":"..table.concat(type(entry.ownedIds)=="table"and entry.ownedIds or {},",")
 if self.builtPage~=entry.id or self.itemsKey~=key then self:buildItems(entry);self.builtPage=entry.id;self.itemsKey=key end
end

function View:paint()
 if not self.content then return end
 self:paintList()
 self:paintPane()
 if self.header and self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
 self.root:SetAttribute("Zone",self.zone);self.root:SetAttribute("Pending",self.pending~=nil)
end

-- The ring sits on the open page's tile, or on the focused milestone cell.
function View:paintFocus(instant)
 if not self.ring then return end
 if not self.visible then self.ring.hide();return end
 local entry=self:currentEntry()
 if self.zone=="milestones"and entry and not entry.records then
  local cell=self.cells[self.milestoneIndex]
  if cell and cell.holder.Visible then
   local target=if cell.button.Visible then cell.button else cell.chip
   self.ring.attach(target,12)
   self.root:SetAttribute("FocusedMilestone",self.milestoneIndex)
   return
  end
  self.zone="pages"
 end
 local tile=self.tiles[self.pageIndex]
 if tile then self.ring.attach(tile.button,12)end
 if instant and self.ring then self.ring.root.Visible=self.visible and self.ring.root.Visible end
 self.root:SetAttribute("FocusedMilestone",0)
end

-- ── Input ────────────────────────────────────────────────────────────────────
function View:move(dx,dy)
 if not self.visible then return false end
 local entries=self:entries()
 if dy~=0 then
  local nextIndex=View.stepPage(self.pageIndex,dy,#entries)
  if nextIndex==self.pageIndex then return false end
  self:openPage(nextIndex);return true
 end
 local entry=self:currentEntry()
 if self.zone=="pages"then
  if dx>0 and entry and not entry.records then
   self.zone="milestones"
   -- Land on the first claim waiting, else the first cell.
   self.milestoneIndex=1
   for index,m in ipairs(milestoneList(entry))do
    if View.milestoneState(m,self.pending,self.failed,self.localClaimed)=="claim"then self.milestoneIndex=index;break end
   end
   self:paint();self:paintFocus();return true
  end
  return false
 end
 local nextIndex=self.milestoneIndex+dx
 if nextIndex<1 then self.zone="pages";self:paint();self:paintFocus();return true end
 if nextIndex>#milestoneList(entry)then return false end
 self.milestoneIndex=nextIndex;self:paintFocus();return true
end
function View:shiftPage(delta)
 local nextIndex=View.stepPage(self.pageIndex,delta,#self:entries())
 if nextIndex==self.pageIndex then return false end
 self:openPage(nextIndex);return true
end
-- A / Enter / Space.
function View:act()
 if not self.visible then return false end
 local entry=self:currentEntry();if not entry or entry.records then return false end
 if self.zone=="milestones"then return self:claimIndex(self.milestoneIndex)end
 for index,m in ipairs(milestoneList(entry))do
  local state=View.milestoneState(m,self.pending,self.failed,self.localClaimed)
  if state=="claim"or state=="failed"then
   self.zone="milestones";self.milestoneIndex=index;self:paintFocus()
   return self:claimIndex(index)
  end
 end
 return false
end
function View:input(key)
 local K=Enum.KeyCode
 if key==K.Left or key==K.A or key==K.DPadLeft then self:move(-1,0)
 elseif key==K.Right or key==K.D or key==K.DPadRight then self:move(1,0)
 elseif key==K.Up or key==K.W or key==K.DPadUp then self:move(0,-1)
 elseif key==K.Down or key==K.S or key==K.DPadDown then self:move(0,1)
 elseif key==K.Q or key==K.ButtonL1 then self:shiftPage(-1)
 elseif key==K.E or key==K.ButtonR1 then self:shiftPage(1)
 elseif key==K.ButtonB or key==K.Backspace or key==K.Escape then self:back()
 elseif key==K.Return or key==K.KeypadEnter or key==K.Space or key==K.ButtonA then self:act()end
end

-- ── Claims ───────────────────────────────────────────────────────────────────
function View:send(action,payload)
 if self.callbacks.send then return self.callbacks.send(action,payload)end
 local remotes=game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
 local remote=remotes and remotes:FindFirstChild("HatchRequest")
 if remote then remote:FireServer(action,payload,self.ctx.revision or 0)end
end
-- Restarts the pending timer: a claim (or a Retrying reply) that hears nothing more in
-- View.PendingTimeout seconds stops waiting and says so; the op id makes a retry safe.
function View:armTimeout()
 self.pendingToken+=1;local token=self.pendingToken
 local pending=self.pending
 task.delay(View.PendingTimeout,function()
  if self.pendingToken~=token or self.pending~=pending or not pending then return end
  self.pending=nil;self.failed[pending.milestoneId]=UICopy.get("book.timeout")
  if self.content then self:paint();self:paintFocus()end
 end)
end
function View:claimIndex(index)
 local entry=self:currentEntry();if not entry or entry.records or self.pending then return false end
 local m=milestoneList(entry)[index];if not m then return false end
 local state=View.milestoneState(m,self.pending,self.failed,self.localClaimed)
 if state~="claim"and state~="failed"then return false end
 local id=HttpService:GenerateGUID(false)
 self.failed[m.id]=nil
 self.pending={id=id,milestoneId=m.id,reward=m.reward,retrying=false}
 local cell=self.cells[index];if cell then Kit.pulse(cell.button)end
 self:send("bookClaim",{id=id,milestoneId=m.id,reward=m.reward})
 self:armTimeout()
 self:paint();self:paintFocus()
 return true
end
local Reasons={Busy="shop.reason.busy",Throttled="shop.reason.throttled",InvalidMilestone="book.failed",NotReached="book.failed"}
-- Server reply (FaceplateResult, kind = "book"). Returns true when it was this view's.
function View:result(message)
 if type(message)~="table"or message.kind~="book"then return false end
 local p=self.pending
 if not p or message.id~=p.id then return false end
 if message.status=="Retrying"then
  p.retrying=true;self:armTimeout()
  if self.content then self:paint()end
  return true
 end
 self.pending=nil;self.pendingToken+=1
 if message.status=="Saved"or message.status=="AlreadyClaimed"or message.reason=="AlreadyClaimed"then
  -- Claimed until the next snapshot confirms it.
  self.localClaimed[p.milestoneId]=true;self.failed[p.milestoneId]=nil
  if self.callbacks.claimed then self.callbacks.claimed(message,p)end
 else
  self.failed[p.milestoneId]=UICopy.get(Reasons[message.reason]or "book.failed")
 end
 if self.content then self:paint();self:paintFocus()end
 return true
end

-- ── Open / close / context ───────────────────────────────────────────────────
-- ctx: {book, stats, stamps, wallet, revision}. Absent keys keep their value.
function View:setContext(ctx)
 for key,value in pairs(ctx or {})do self.ctx[key]=value end
 -- A snapshot that shows a claim drops the local mark for it.
 local claimed={}
 local book=self.ctx.book
 if type(book)=="table"and type(book.claimed)=="table"then for _,id in ipairs(book.claimed)do claimed[id]=true end end
 for id in pairs(self.localClaimed)do if claimed[id]then self.localClaimed[id]=nil end end
 if self.visible then
  -- Pets joining (five pages to six) changes the list: rebuild; otherwise repaint.
  if View.viewKey(self.view,self:entries())~=self.key then
   local id=self:currentEntry()and self:currentEntry().id
   self:build(self.view)
   for index,entry in ipairs(self:entries())do if entry.id==id then self:openPage(index,true)end end
  else self:paint();self:paintFocus()end
 end
end
function View:fit(size)
 if Kit.compactRule(size.X,size.Y)then
  local _,kh=Kit.keepOut();local top=kh+2
  local view={phone=true,W=math.floor(size.X),H=math.floor(size.Y)-top,hx=24}
  self.root.AnchorPoint=Vector2.zero;self.root.Position=UDim2.fromOffset(0,top);self.root.Size=UDim2.fromOffset(view.W,view.H);self.scale.Scale=1
  if self.key~=View.viewKey(view,self:entries())then self:build(view)end
  self:syncPeek();return
 end
 self.root.AnchorPoint=Vector2.new(.5,.5);self.root.Size=UDim2.fromOffset(848,608)
 if self.key~=View.viewKey(nil,self:entries())then self:build(nil)end
 self.root.Position=UDim2.fromScale(.5,.5)
 self.scale.Scale=math.max(.1,math.min(1.2,(size.X-24)/848,(size.Y-24)/608))
 self:syncPeek()
end
-- T4: the pet peeks over the header (desktop only), clear of the title, eyebrow,
-- wallet and back circle.
function View:syncPeek()
 if not self.content then return false end
 if not self.visible or self.view~=nil or not self.header or not self.header.geometry then Peek.hide(self.content);return false end
 local g=self.header.geometry
 local title=self.header.title
 local tw=Kit.measure(title.Text,"Title",title.TextSize).X*1.1
 local avoid={{x=g.title.x,y=g.title.y,w=tw,h=g.title.h}}
 if g.eyebrow then table.insert(avoid,{x=g.eyebrow.x,y=g.eyebrow.y,w=Kit.measure(self.header.eyebrow.Text,"Label",13).X*1.1+20,h=g.eyebrow.h})end
 if g.wallet then table.insert(avoid,g.wallet)end
 table.insert(avoid,g.back)
 return Peek.show(self.content,{rect=View.PeekSlot,avoid=avoid,align="center",key="book",compact=false})
end
function View:isOpen()return self.visible end
-- options: page (a page id to open on).
function View:open(ctx,options)
 options=options or {}
 for key,value in pairs(ctx or {})do self.ctx[key]=value end
 self.failed={};self.zone="pages";self.milestoneIndex=1
 local entries=self:entries()
 -- Lands on the requested page, else the first page with a claim waiting, else the first.
 local index=1
 for i,entry in ipairs(entries)do
  if options.page and entry.id==options.page then index=i;break end
  if not options.page and not entry.records and View.claimableCount(entry,self.localClaimed)>0 then index=i;break end
 end
 self.pageIndex=index;self.builtPage=nil
 self.visible=true;self.root.Visible=true
 Kit.shadeOpen(self,self.shade,function(covered)self.root.Visible=not covered end)
 self.key=nil
 self:fit(self.host.AbsoluteSize)
 self:openPage(index,true)
 -- QA Q2.2: in from the right like the Pets page (Reduced Motion cuts).
 Kit.slideIn(self.body,Kit.SlideOffset,Kit.headerSkip(self.header))
 self.sizeConnection=self.sizeConnection or self.host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.visible then self:fit(self.host.AbsoluteSize)end end)
 return true
end
function View:close(reason)
 if not self.visible then return false end
 self.visible=false;self.root.Visible=false;Kit.shadeClose(self)
 if self.ring then self.ring.hide()end
 if self.content then Peek.hide(self.content)end
 if self.callbacks.closed then self.callbacks.closed(reason)end
 return true
end
function View:back()
 self:close("back")
 if self.callbacks.back then self.callbacks.back()end
 return true
end
function View:destroy()
 self:close("destroy")
 if self.sizeConnection then self.sizeConnection:Disconnect();self.sizeConnection=nil end
 self.root:Destroy();self.shade:Destroy()
end
return View
