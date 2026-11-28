-- Deck style (UI-SPEC-REDESIGN-MENUS-2026-11-12 sections 0.1, 0.2 and 4; mockups
-- 04-deck-style-faceplates and 05-deck-style-backgrounds). One Kit screen: the shared
-- header ("Deck style", Stars, back), the Faceplates | Backgrounds icon tabs in the
-- Wardrobe tab position, and under them a preview pane plus card grid. This module
-- owns the screen, header, tab row, focus ring, hint bar and the Faceplates tab
-- (16 plates, fixed Star prices; the server validates and debits through
-- HatchProgress.buyFaceplate). BackgroundShop draws the Backgrounds tab into it.
-- Focus is owned here: d-pad / arrows / WASD move, Q / E and L1 / R1 switch tabs,
-- A / Enter acts, B backs out; touch and mouse select a card with the first tap and
-- act with the pane button (or a second tap).
local Shared=game:GetService("ReplicatedStorage").Shared
local Themes=require(Shared.DeckThemes)
local Catalog=require(Shared.AppearanceCatalog)
local Kit=require(script.Parent.DeckKit)
local UICopy=require(Shared.UICopy)
local Deal=require(script.Parent.ShelfDeal)
local Assets=require(script.Parent.DeckAssets)
local BackgroundShop=require(script.Parent.BackgroundShop)
-- Third tab, Balls (batch 2026-11-13 R1): ball themes, drawn by BallShop.
local BallShop=require(script.Parent.BallShop)
local Peek=require(script.Parent.PetPeek)
local TabInk=require(script.Parent.TabInk)
local HintLegend=require(script.Parent.HintLegend)
-- Levels matter: gated plates (S2) and the Effects tab (S3, EffectsShop, only while juice is on).
local Levels=require(Shared.Levels)
local Locked=require(script.Parent.LockedItem)
-- Rotation slice 2, lane D: Deck style as a closet under the rack_deck switch (DeckCloset; off = today's shop).
local Closet=require(script.Parent.DeckCloset)
local Shop={}
Shop.__index=Shop
Shop.Size=Vector2.new(848,608)
Shop.Columns=4
Shop.ConfirmSeconds=3
Shop.Title,Shop.Eyebrow="Deck style","Pocket deck"
Shop.Tabs={{id="faceplates",label="Faceplates",icon="faceplate"},{id="backgrounds",label="Backgrounds",icon="pattern"},{id="balls",label="Balls",icon="smiley"}}
-- Pure: the tabs shown. Off, exactly the three above.
Shop.EffectsTab={id="effects",label=UICopy.get("style.effects.title"),icon="sparkle"}
function Shop.tabList()
 if not Levels.on("juice")then return Shop.Tabs end
 local tabs=table.clone(Shop.Tabs);table.insert(tabs,Shop.EffectsTab)
 return tabs
end
-- Desktop rects in panel units (section 4): tabs where Wardrobe's slot tabs sit, the
-- pane at 24,144 328x392, a 4x4 grid of 104x88 cards from 371,147, hints on y 566.
Shop.Regular={tabs={24,84,800,44},pane={24,144,328,392},grid={371,147},tile={104,88},gap=12,hints=566}
-- QA v2 R2.5: footer rows are HintGlyphs actions (chips per device), not gamepad glyphs.
Shop.Hints={
 {pairs={{"browse","Browse"},{"tab","Tab"},{"confirm","Buy or equip"},{"back","Back"}},promise=UICopy.get("style.promise.faceplates")},
 {pairs={{"browse","Browse"},{"tab","Tab"},{"confirm","Use"},{"back","Back"}},promise=UICopy.get("style.promise.backgrounds")},
 {pairs={{"browse","Browse"},{"tab","Tab"},{"confirm","Buy or use"},{"back","Back"}},promise=UICopy.get("style.promise.balls")},
 {pairs={{"browse","Browse"},{"tab","Tab"},{"confirm","Use"},{"back","Back"}},promise=UICopy.get("style.effects.promise")},
}
local TierChip={starter={"STARTER",Color3.fromHex("#C3C8D0")},common={"COMMON",Color3.fromHex("#9BE3A8")},
 rare={"RARE",Color3.fromHex("#8CC8FF")},showcase={"SHOWCASE",Color3.fromHex("#E6B3FF")},book={"BOOK",Kit.Tint.book},
 -- Slice C: the deluxe tier (160), in Stars gold.
 deluxe={UICopy.get("shelf.deluxe"),Kit.Color.stars}}
Shop.TierChip=TierChip
-- Slice C: the shelf week for a ctx. ctx.week wins (false = no shelf, for specs); without
-- one the owner snapshot's day decides (ShelfDeal.week), as the server's check does.
local function weekOf(ctx)
 if ctx and ctx.week~=nil then return ctx.week end
 return Deal.week()
end
local function finishName(theme)
 local finish=theme.finish or "gloss"
 return string.upper(string.sub(finish,1,1))..string.sub(finish,2)
end

-- Pure: what the pane says and offers for one plate.
-- ctx = { equipped = id, wallet = n, facts = AppearanceCatalog facts (with .faceplates), levels, closet = bool }
-- closet (DeckCloset): an unowned plate the Deck Egg deals says "From the Deck Egg" (kind "egg"), and nothing sells
-- at a weekly-shelf price.
function Shop.status(id,ctx)
 local theme=Themes.ById[id]
 if not theme then return {kind="invalid",text="",button=nil}end
 local facts=ctx.facts or {}
 -- QA v2 R3.5 (194500, 195844): the plate on the deck keeps the Equip button, disabled,
 -- reading "Equipped" (no status line under the name, which overlapped it on phones).
 if ctx.equipped==id then return {kind="equipped",text="",button=UICopy.get("r4.equipped"),enabled=false}end
 local base=Themes.price(id)
 if base and not Catalog.ownsFaceplate(facts,id)then
  -- Levels matter (S2): below the level the pane shows the way there; the price stays on the card.
  local gate=Locked.info(theme,ctx.levels)
  if gate and not gate.met then return {kind="locked",text=gate.line,button=Locked.trainText(gate),price=base,gate=gate,enabled=true}end
  if theme.gate and not Locked.on()then return {kind="invalid",text="",button=nil}end -- not for sale, not listed
  local egg=Closet.status("plate",id,false,ctx.closet)
  if egg then return egg end
  local wallet=ctx.wallet or 0
  -- Slice C: a plate on this week's shelf sells at the shelf price (`full` = the struck price). Never in the closet.
  local price,full=Deal.quote("faceplate",id,base,Closet.week(ctx.closet,weekOf(ctx)))
  if wallet>=price then return {kind="buy",text=if full then UICopy.get("shelf.status")else "You have enough Stars",button="★ Buy "..price,price=price,full=full,enabled=true}end
  return {kind="short",text=require(script.Parent.ShopPriceState).need(price,wallet),button="★ Buy "..price,price=price,full=full,enabled=false}
 end
 local requirement=Catalog.describeRequirement("theme",id,facts)
 if requirement.unlocked then return {kind="owned",text=if theme.bookOnly then "From the book"else "",button="Equip",enabled=true}end
 return {kind="locked",text=requirement.text,button=nil}
end
-- Pure: the tile's status line.
function Shop.tileStatus(id,ctx)
 local s=Shop.status(id,ctx)
 if s.kind=="equipped"then return "EQUIPPED","accent"end
 if s.kind=="owned"then return (if Themes.isBookOnly(id)then "From the book"else "✓ Owned"),"soft"end
 if s.kind=="egg"then return Closet.tileStatus()end
 if s.kind=="buy"then return Deal.priceText(s.price,s.full),"stars"end
 if s.kind=="short"or s.gate then return Deal.priceText(s.price,s.full),"dim"end
 local short=({firstWin="Win 1",rankI="Win 3",rankII="Win 10",book="Book"})[Themes.ById[id]and Themes.ById[id].rule or ""]or "Locked"
 return "🔒 "..short,"dim"
end
-- Pure: the plates on the grid. The 16 sold / earned plates, then any book-only plate
-- the player owns (play-forever F2: Bookworm shows once the book grants it).
function Shop.order(facts)
 local order=Themes.listed(facts and facts.faceplates) -- Order, then gated plates while gates are on or owned
 for _,id in ipairs(Themes.BookOnly or {})do
  if Catalog.ownsFaceplate(facts or {},id)then table.insert(order,id)end
 end
 return order
end
-- Desktop rows when the grid holds more than the 4 x 4 that fit (a book-only plate
-- owned): the same 104 x 88 cards in a scrolling column, 100 px a row.
Shop.ScrollGrid=table.freeze({x=368,y=144,w=466,h=400,pitch=100})
-- Pure: grid navigation (no wrap).
function Shop.step(index,dx,dy,count,columns)
 local cols=columns or Shop.Columns
 local col,row=(index-1)%cols,math.floor((index-1)/cols)
 local rows=math.ceil(count/cols)
 col=math.clamp(col+dx,0,cols-1);row=math.clamp(row+dy,0,rows-1)
 return math.min(count,row*cols+col+1)
end
-- Pure: the next tab for a Q / E (LB / RB) press, clamped (no wrap).
function Shop.nextTab(tab,delta)return math.clamp(tab+delta,1,#Shop.tabList())end

-- Mini deck composed from the real shell sprites (296 wide in the pane, 88 on tiles).
local function miniDeck(parent,width,position)
 local s=width/1600;local L=Assets.Layout;local I=Assets.Image
 local root=Kit.node("CanvasGroup",parent,{Name="MiniDeck",BackgroundTransparency=1,BorderSizePixel=0,Position=position,Size=UDim2.fromOffset(width,800*s),ClipsDescendants=true,ZIndex=parent.ZIndex+1})
 Kit.corner(root,math.max(3,math.floor(width*.04)))
 local function img(name,id,r,z)
  local i=Kit.node("ImageLabel",root,{Name=name,BackgroundTransparency=1,Image=id,ZIndex=root.ZIndex+z,Active=false,
   Position=UDim2.fromOffset(r[1]*s,r[2]*s),Size=UDim2.fromOffset(r[3]*s,r[4]*s)})
  return i
 end
 local band=img("Band",I.band,L.band,0)
 local plate=img("Plate",Assets.Faceplate.sherbet,L.plate,1)
 local finish=img("Finish","",L.plate,2)
 img("PlateOverlay",I.plateOverlay,L.plate,3)
 img("Glass",I.glass,L.glass,4)
 local lcd=Kit.frame(root,"LCD",nil,UDim2.fromOffset(L.lcd[1]*s,L.lcd[2]*s),UDim2.fromOffset(L.lcd[3]*s,L.lcd[4]*s),math.max(2,math.floor(30*s)))
 lcd.BackgroundTransparency=0;lcd.ZIndex=root.ZIndex+5
 local d=L.dpad.diameter;local dpad=img("DPad",I.dpadDisc,{L.dpad.center.X-d/2,L.dpad.center.Y-d/2,d,d},6)
 local arrows=Kit.node("ImageLabel",dpad,{Name="Arrows",BackgroundTransparency=1,Image=I.dpadArrows,Size=UDim2.fromScale(1,1),ZIndex=dpad.ZIndex+1})
 local a=L.a.diameter;local buttonA=img("A",I.buttonBase,{L.a.center.X-a/2,L.a.center.Y-a/2,a,a*1.07},6)
 local b=L.b.diameter;local buttonB=img("B",I.buttonBase,{L.b.center.X-b/2,L.b.center.Y-b/2,b,b*1.07},6)
 buttonB.ImageColor3=Color3.fromHex("#3A3E47")
 local wordmark=img("Wordmark",I.wordmark,L.wordmark,4);wordmark.ResampleMode=Enum.ResamplerMode.Pixelated
 local epoch,ticket,lastId,ready,retryAt=0,nil,nil,false,0
 -- Launch candidate: a soft raised well with a gentle sweep while the art loads (it was a dark
 -- outline). StylePreload warms these images in the background, so most tiles never show it.
 local placeholder=Kit.frame(root,"LoadingOutline","raised",UDim2.new(0,2,0,2),UDim2.new(1,-4,1,-4),math.max(3,math.floor(width*.04)))
 placeholder.ZIndex=root.ZIndex;Kit.stroke(placeholder,"dim",1,.55)
 local Shimmer=require(script.Parent.LoadingShimmer);local shimmer=Shimmer.attach(placeholder)
 local overlayWanted=false
 local function show(on)
  placeholder.Visible=not on
  if on then shimmer.stop()elseif shimmer.stopped then shimmer=Shimmer.attach(placeholder)end
  -- The LCD is a plain frame (no image to wait for): it waits with the sprites, or the
  -- loading tile showed a dark screen-shaped box (Spencer, launch candidate).
  lcd.Visible=on
  for _,image in ipairs(root:GetDescendants())do if image:IsA("ImageLabel")then image.Visible=on and(image~=finish or overlayWanted)end end
 end
 root.Destroying:Connect(function()epoch+=1;if ticket then ticket:cancel()end end)
 return {root=root,set=function(theme,id)
  plate.Image=Assets.Faceplate[id]or Assets.Faceplate.sherbet
  local plain=Assets.plateBase(plate,theme)~=nil -- a gated plate never waits for its own texture
  band.ImageColor3=theme.bandTint or Color3.new(1,1,1)
  overlayWanted=theme.overlay~=nil;finish.Visible=ready and overlayWanted;if theme.overlay then finish.Image=theme.overlay.image;finish.ImageTransparency=1-theme.overlay.max*.6 end
  lcd.BackgroundColor3=theme.ui.panel
  arrows.ImageColor3=theme.accent;buttonA.ImageColor3=theme.accent
  wordmark.ImageColor3=theme.engrave or Color3.new(0,0,0);wordmark.ImageTransparency=1-(theme.engraveOpacity or .42)
  if id~=lastId or(not ready and os.clock()>=retryAt)then
   local retry=id==lastId;lastId=id;ready=false;epoch+=1;local serial=epoch
   if ticket then ticket:cancel()end
   local ids={};for _,image in ipairs(root:GetDescendants())do if image:IsA("ImageLabel")and image.Image~=""and(image~=finish or overlayWanted)and not(plain and image==plate)then table.insert(ids,image.Image)end end
   local warm=require(script.Parent.UIAssetWarmup).shared
   local request=if retry then warm.retry else warm.request
   retryAt=os.clock()+3
   ticket=request(warm,ids,function(ok)
    if not root.Parent or serial~=epoch then return end
    ready=ok;retryAt=os.clock()+3;show(ok)
   end,1)
  end
  show(ready)
 end}
end

-- The collection book's Faceplates page draws the same mini deck as its thumbnails.
Shop.miniDeck=miniDeck

-- Colour by role, resolved at paint time so a re-tint repaints correctly.
-- Toy Shell: a role read on `object`'s own surface (ink on cream tiles, white on trays).
local function colorOf(role,object,property)return Kit.roleOn(object,role,property)end
local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end

-- host: a Frame that receives the 848x608 glass screen (scaled to fit).
-- callbacks: equip(id), buy(order), bought(id), back(), tab(index) (a tab request:
-- the owner answers with setTab), rebuilt(), and for Backgrounds: use(id),
-- retry(slot). Levels matter: train(route) ({stat, petId}), the way to a locked item's training.
-- Rotation slice 2: deckEgg(kind, id) ("plate" | "ball"), the closet's way to the Deck Egg tile, and hasDeckEgg()
-- (optional: false keeps that button disabled while nobody answers it).
function Shop.new(host,callbacks)
 local self=setmetatable({host=host,callbacks=callbacks or {},index=1,tab=1,ctx={equipped=Themes.Default,wallet=0,facts={},closet=Closet.on()},
  visible=false,pending=nil,confirmUntil=0,columns=Shop.Columns},Shop)
 local root=Kit.frame(host,"FaceplateShop","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
 root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.Visible=false;root.ClipsDescendants=true;self.rootStroke=Kit.stroke(root)
 local gradient=Kit.frame(root,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 self.gradient=gradient
 self.root=root
 self.scale=Kit.node("UIScale",root,{Scale=1})
 self.backgrounds=BackgroundShop.new(self,{
  use=function(id)if self.callbacks.use then self.callbacks.use(id)end end,
  retry=function()if self.callbacks.retry then self.callbacks.retry("background")end end,
 })
 self.balls=BallShop.new(self,{
  bought=function(id)if self.callbacks.ballBought then self.callbacks.ballBought(id)end end,
  equipped=function(id)if self.callbacks.ballEquipped then self.callbacks.ballEquipped(id)end end,
  send=self.callbacks.ballSend,
 })
 self:build(nil)
 return self
end

-- Shared chrome for both tabs: header, icon tab row and (desktop) the hint bar.
function Shop:buildChrome(parent,view,tabsW)
 local phone=view~=nil
 if phone then
  self.header=Kit.header(parent,{title=Shop.Title,tint="style",compact=true,width=view.W,left=view.hx,onBack=function()self:back()end})
 else
  self.header=Kit.header(parent,{title=Shop.Title,eyebrow=Shop.Eyebrow,tint="style",width=848,onBack=function()self:back()end})
  Kit.halftone(parent,"style",false)
 end
 self.wallet,self.backArrow,self.title=self.header.wallet,self.header.back,self.header.title
 local labels,icons={},{}
 for _,tab in ipairs(self.tabSet)do table.insert(labels,tab.label);table.insert(icons,tab.icon)end
 if phone then
  local narrow=if #labels>3 then 460 else 400 -- a fourth tab needs the smaller words sooner
  local iconOnly=#labels>3 and tabsW<340 -- 568 wide phones: no room for four names at 12 px
  self.tabs=Kit.tabs(parent,labels,tabsW,36,if tabsW<narrow then 12 else 14,icons,if iconOnly then{iconOnly=true}else nil);self.tabs.root.Position=UDim2.fromOffset(20,64)
 else
  local R=Shop.Regular.tabs
  self.tabs=Kit.tabs(parent,labels,R[3],R[4],16,icons);self.tabs.root.Position=UDim2.fromOffset(R[1],R[2])
 end
 TabInk.guard(self.tabs) -- QA v2 R3.6 (194541): labels keep their ink across theme repaints
 self.tabs.changed=function(index)self:requestTab(index)end
 self.hints={};self.legends={}
 if not phone then
  for index,set in ipairs(Shop.Hints)do
   if index>#self.tabSet then break end
   local row=Kit.frame(parent,"Hints"..index,nil,UDim2.fromOffset(24,Shop.Regular.hints),UDim2.fromOffset(800,24))
   -- The closet: "Fixed prices. No random plates." would not be true; "Plates you own stay yours." instead.
   local promise=txt(row,"Small",if index==1 then Closet.promise(self.ctx.closet,set.promise)else set.promise,"dim",500,0,300,24,{Name="Promise",TextXAlignment=Enum.TextXAlignment.Right})
   local legend=HintLegend.attach(row,800,"style",set.pairs)
   local function sync()promise.Visible=row:GetAttribute("HintLegend")~=true end
   row:GetAttributeChangedSignal("HintLegend"):Connect(sync);sync()
   self.hints[index]=row;self.legends[index]=legend
  end
 end
end

function Shop:build(view)
 if self.content then Peek.hide(self.content);self.backgrounds:releasePreview();self.content:Destroy()end
 -- Levels matter S3: the fourth tab comes and goes with the part.
 self.levelsKey=Levels.key();self.tabSet=Shop.tabList()
 self.closetKey=self.ctx.closet==true
 if #self.tabSet>#Shop.Tabs then self.effects=self.effects or require(script.Parent.EffectsShop).new(self,{send=self.callbacks.effectSend})
 elseif self.effects then self.effects:release();self.effects=nil end
 if self.tab>#self.tabSet then self.tab=1 end
 self.lockBar,self.lockChip=nil,nil
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 self.view=view;self.key=Shop.viewKey(view)
 self.plateOrder=Shop.order(self.ctx.facts);self.orderKey=table.concat(self.plateOrder,",")
 local root=self.root
 local phone=view~=nil
 root.BackgroundTransparency=if phone then 1 else 0;self.gradient.Visible=not phone;self.rootStroke.Enabled=not phone
 root.ClipsDescendants=not phone
 local content=Kit.frame(root,"Content",nil,UDim2.new(),if phone then UDim2.fromOffset(view.W,view.H)else UDim2.fromOffset(848,608));content.ZIndex=root.ZIndex+2
 self.content=content
 if phone then self:buildCompact(view)else self:buildRegular()end
 self.ring=Kit.focusRing(root) -- root carries the UIScale the ring divides by
 self:applyTab()
 if self.callbacks.rebuilt then self.callbacks.rebuilt(self)end
 if self.visible then self:syncPeek()end
end

function Shop:buildRegular()
 local content=self.content
 self.columns=Shop.Columns
 self:buildChrome(content,nil)
 local R=Shop.Regular
 local plates=Kit.frame(content,"Faceplates",nil,UDim2.new(),UDim2.fromScale(1,1));self.plates=plates
 -- Preview pane.
 local pw,ph=R.pane[3],R.pane[4]
 local pane=Kit.card(plates,"Preview",nil,{pad=20,seam=true});pane.Position=UDim2.fromOffset(R.pane[1],R.pane[2]);pane.Size=UDim2.fromOffset(pw,ph)
 self.preview=miniDeck(pane,296,UDim2.fromOffset(16,16))
 self.name=txt(pane,"Title","","text",20,170,200,30,{TextTruncate=Enum.TextTruncate.AtEnd})
 self.tier=Kit.chip(pane,"RARE","sticker",26);self.tier.root.AnchorPoint=Vector2.new(1,.5);self.tier.root.Position=UDim2.fromOffset(308,185)
 -- Slice C: "THIS WEEK −20%" over the preview's corner while the focused plate is on the shelf.
 self.deal=Deal.chip(pane,22);self.deal.root.ZIndex=pane.ZIndex+20;self.deal.root.Position=UDim2.fromOffset(24,24);self.dealWidth=pw-48
 self.finish=txt(pane,"Small","","soft",20,204,288,20,{TextSize=15,TextTruncate=Enum.TextTruncate.AtEnd})
 local sample=Kit.frame(pane,"Sample",nil,UDim2.fromOffset(20,234),UDim2.fromOffset(288,44),12);sample.BackgroundTransparency=0
 Kit.stroke(sample)
 local samplePrimary=Kit.frame(sample,"Primary",nil,UDim2.fromOffset(8,8),UDim2.fromOffset(100,28),10);samplePrimary.BackgroundTransparency=0
 local sampleLabel=txt(samplePrimary,"Strong","Primary",nil,0,0,100,28,{TextSize=15,TextXAlignment=Enum.TextXAlignment.Center})
 local track=Kit.frame(sample,"Track",nil,UDim2.fromOffset(122,18),UDim2.fromOffset(122,8),999);track.BackgroundTransparency=0
 local trackFill=Kit.frame(track,"Fill",nil,UDim2.new(),UDim2.fromScale(.68,1),999);trackFill.BackgroundTransparency=0
 local star=Kit.icon(sample,"star",20);star.Position=UDim2.fromOffset(256,12)
 self.sampleParts={sample=sample,primary=samplePrimary,label=sampleLabel,track=track,fill=trackFill}
 self.status=txt(pane,"Small","","soft",20,286,288,20,{TextTruncate=Enum.TextTruncate.AtEnd})
 local action,actionState=Kit.button(pane,"Action",{variant="primary",text="Equip",glyph="A",size=Vector2.new(288,56),selectable=false})
 action.Position=UDim2.fromOffset(20,ph-16-56);self.action,self.actionState=action,actionState
 action.Activated:Connect(function()self:act(true)end)
 -- Grid: 16 plates, 4 columns of 104x88, no scroll. A book-only plate the player owns
 -- adds a fifth row: then the same cards sit in a scrolling column (Shop.ScrollGrid).
 self.tiles={}
 local order=self.plateOrder
 local gridParent,gx,gy=plates,R.grid[1],R.grid[2]
 self.grid=nil;self.rowPitch,self.tileH=R.tile[2]+R.gap,R.tile[2]
 if #order>16 then
  local G=Shop.ScrollGrid
  local list=Kit.node("ScrollingFrame",plates,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(G.x,G.y),
   Size=UDim2.fromOffset(G.w,G.h),ScrollBarThickness=4,ZIndex=plates.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
   ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
  list.CanvasSize=UDim2.fromOffset(0,math.ceil(#order/4)*G.pitch-R.gap+3+3+Kit.Lip.tile)
  gridParent,gx,gy=list,3,3
  self.grid=list;self.rowPitch=G.pitch
 end
 for index,id in ipairs(order)do
  local col,row=(index-1)%4,math.floor((index-1)/4)
  -- T2: pressable tile with a 4 px lip inside the 12 px grid gap.
  local tile,tileState=Kit.tile(gridParent,"Tile_"..id,{selectable=false,radius=12,
   position=UDim2.fromOffset(gx+col*(R.tile[1]+R.gap),gy+row*(R.tile[2]+R.gap)),size=UDim2.fromOffset(R.tile[1],R.tile[2])})
  local stroke=tileState.stroke
  tile:SetAttribute("AccessibleLabel",Themes.ById[id].name)
  local deck=miniDeck(tile,88,UDim2.fromOffset(8,6));deck.set(Themes.ById[id],id)
  local nameLabel=txt(tile,"Strong",Themes.ById[id].name,"text",8,51,90,16,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
  local status=txt(tile,"Counter","","soft",8,68,90,16,{TextSize=13})
  self.tiles[index]={id=id,button=tile,status=status,name=nameLabel,stroke=stroke}
  self:addLock(index,tile,UDim2.fromOffset(8,6),UDim2.fromOffset(88,44),R.tile[1])
  tile.Activated:Connect(function()
   if self.index==index then self:act(true)else self:focus(index);Kit.boing(tile)end
  end)
 end
 self.backgrounds:build(content,nil,nil)
 self.balls:build(content,nil,nil)
 if self.effects then self.effects:build(content,nil,nil)end
end

-- Pure (UI-SPEC-COMPACT 9, redesign 4): pane width, grid width, columns and tile width.
-- The grid sits under the 36-high tab row (y 64), so it starts at y 112.
-- Three columns once each card keeps at least 160 px (169 at 812 wide in the mockup).
function Shop.compactGrid(W,H)
 local pw=if W<700 then 200 else 232
 local gw=W-pw-52
 local cols=if(gw-8-16)/3>=160 then 3 elseif gw>=420 then 2 else 1
 return{pw=pw,gw=gw,cols=cols,tileW=math.floor((gw-8-(cols-1)*8)/cols),paneH=H-82,gridH=H-82-48}
end
function Shop.viewKey(view)
 return if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"
end

-- Compact (phone) Deck style: header, tab row over a scrolling grid on the left and
-- a pinned preview pane with Buy / Equip on the right, all in one menu sheet.
function Shop:buildCompact(v)
 local content=self.content
 local W,H=v.W,v.H
 local grid=Shop.compactGrid(W,H)
 self.columns=grid.cols
 local sheet=Kit.sheet(content,W,H)
 local body=Kit.frame(content,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 self:buildChrome(body,v,grid.gw)
 local plates=Kit.frame(body,"Faceplates",nil,UDim2.new(),UDim2.fromScale(1,1));self.plates=plates
 -- Preview pane (pinned).
 local pw,ph=grid.pw,grid.paneH
 -- QA v760: no stitched seam on a phone preview pane (the preview well sat on top of it, so it read as an occluded inner border)
 local pane=Kit.card(plates,"Preview",nil,{pad=12,seam=false});pane.Position=UDim2.fromOffset(W-20-pw,64);pane.Size=UDim2.fromOffset(pw,ph)
 local deckW=if H<340 then 144 else pw-24
 self.preview=miniDeck(pane,deckW,UDim2.fromOffset((pw-deckW)/2,10))
 local nameY=10+deckW/2+16+9
 self.name=txt(pane,"Title","","text",12,nameY-12,pw-24-90,24,{TextSize=18,TextTruncate=Enum.TextTruncate.AtEnd})
 self.tier=Kit.chip(pane,"RARE","sticker",22);self.tier.label.TextSize=12;self.tier.root.AnchorPoint=Vector2.new(1,.5);self.tier.root.Position=UDim2.fromOffset(pw-12,nameY)
 self.deal=Deal.chip(pane,22);self.deal.root.ZIndex=pane.ZIndex+20;self.deal.root.Position=UDim2.fromOffset(14,14);self.dealWidth=pw-28
 self.finish=txt(pane,"Small","","soft",12,nameY+22-9,pw-24,18,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
 local buttonY=ph-60
 local statusY=buttonY-14
 -- Tint sample only when at least 44 px is free above the status line.
 self.sampleParts=nil
 local sampleTop=nameY+38
 if (statusY-10)-(sampleTop+36)>=8 and (statusY-10)-(nameY+22+9)>=44 then
  local sample=Kit.frame(pane,"Sample",nil,UDim2.fromOffset(12,sampleTop),UDim2.fromOffset(pw-24,36),10);sample.BackgroundTransparency=0
  Kit.stroke(sample)
  local samplePrimary=Kit.frame(sample,"Primary",nil,UDim2.fromOffset(6,6),UDim2.fromOffset(70,24),8);samplePrimary.BackgroundTransparency=0
  local sampleLabel=txt(samplePrimary,"Strong","Primary",nil,0,0,70,24,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Center})
  local track=Kit.frame(sample,"Track",nil,UDim2.fromOffset(86,15),UDim2.fromOffset(pw-24-86-34,6),999);track.BackgroundTransparency=0
  local trackFill=Kit.frame(track,"Fill",nil,UDim2.new(),UDim2.fromScale(.68,1),999);trackFill.BackgroundTransparency=0
  local star=Kit.icon(sample,"star",14);star.Position=UDim2.fromOffset(pw-24-24,11)
  self.sampleParts={sample=sample,primary=samplePrimary,label=sampleLabel,track=track,fill=trackFill}
 end
 -- QA v2 R3.5 (195844): the status line never rides over the name / finish lines; with
 -- no room it hides (the button carries the state).
 local statusTop=math.max(statusY-10,nameY+22-9+18+2)
 self.status=txt(pane,"Body","","soft",12,statusTop,pw-24,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
 self.statusRoom=statusTop+20<=buttonY-2
 self.status.Visible=self.statusRoom
 local action,actionState=Kit.button(pane,"Action",{variant="primary",text="Equip",glyph="A",size=Vector2.new(pw-24,48),textSize=16,selectable=false})
 action.Position=UDim2.fromOffset(12,buttonY);self.action,self.actionState=action,actionState
 action.Activated:Connect(function()self:act(true)end)
 -- Grid: a vertical ScrollingFrame under the tabs, 4 px bar inside an 8 px gutter.
 local list=Kit.node("ScrollingFrame",plates,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,112),
  Size=UDim2.fromOffset(grid.gw,grid.gridH),ScrollBarThickness=4,ZIndex=plates.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
  ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
 local order=self.plateOrder
 local rows=math.ceil(#order/grid.cols)
 -- QA v2 R3.2: room for the first row's selection stroke and lip (tiles keep their place).
 local bleed=Kit.scrollBleed(list,4)
 list.CanvasSize=UDim2.fromOffset(0,rows*72-8+bleed*2)
 self.grid=list;self.rowPitch,self.tileH=72,64
 self.tiles={}
 -- Narrow (three-column) cards draw a 72 px deck so the name keeps room.
 local deckTile=if grid.tileW>=200 then 88 else 72
 local tx=10+deckTile+10
 for index,id in ipairs(order)do
  local col,row=(index-1)%grid.cols,math.floor((index-1)/grid.cols)
  -- T2: pressable tile with a 3 px phone lip inside the 8 px grid gap.
  local tile,tileState=Kit.tile(list,"Tile_"..id,{selectable=false,radius=12,compact=true,
   position=UDim2.fromOffset(col*(grid.tileW+8),row*72),size=UDim2.fromOffset(grid.tileW,64)})
  local stroke=tileState.stroke
  tile:SetAttribute("AccessibleLabel",Themes.ById[id].name)
  local deck=miniDeck(tile,deckTile,UDim2.fromOffset(10,(64-deckTile/2)/2));deck.set(Themes.ById[id],id)
  local nameLabel=txt(tile,"Strong",Themes.ById[id].name,"text",tx,12,grid.tileW-tx-8,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  local status=txt(tile,"Counter","","soft",tx,34,grid.tileW-tx-8,18,{TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd})
  self.tiles[index]={id=id,button=tile,status=status,name=nameLabel,stroke=stroke}
  self:addLock(index,tile,UDim2.fromOffset(10,(64-deckTile/2)/2),UDim2.fromOffset(deckTile,deckTile/2),deckTile+20)
  tile.Activated:Connect(function()
   if self.index==index then self:act(true)else self:focus(index);Kit.boing(tile)end
  end)
 end
 self.backgrounds:build(body,v,grid)
 self.balls:build(body,v,grid)
 if self.effects then self.effects:build(body,v,grid)end
end
-- Levels matter (S2): a gated plate's requirement chip and small lock over its picture, made only while
-- gates are on.
function Shop:addLock(index,tile,position,size,width)
 local entry=self.tiles[index]
 if not Themes.ById[entry.id].gate or not Locked.on()then return end
 local area=Kit.frame(tile,"LockArea",nil,position,size);area.ZIndex=tile.ZIndex+8
 entry.lock=Locked.mark(area,16)
 entry.chip=Locked.chip(tile,18);entry.chip.root.Position=UDim2.fromOffset(6,4);entry.chip.root.ZIndex=tile.ZIndex+14
 entry.chipRoom=width-12
end
-- The pane's chip over the preview and the bar under its status line, made the first time a locked plate
-- is shown.
function Shop:paintLock(gate,noted)
 if not gate and not self.lockBar then return end
 if not self.lockBar then
  local deck=self.preview.root
  self.lockChip=Locked.chip(deck.Parent,22);self.lockChip.root.Position=deck.Position+UDim2.fromOffset(8,8);self.lockChip.root.ZIndex=deck.Parent.ZIndex+20
  self.lockRoom=deck.Size.X.Offset-16
  self.lockBar=Locked.bar(self.action.Parent,self.action.Position.X.Offset,self.action.Position.Y.Offset-8,self.action.Size.X.Offset,5)
 end
 self.lockChip.set(gate,self.lockRoom);self.lockBar.set(gate)
 if gate and not noted then Kit.fitText(self.status,{gate.line,gate.needs})end
end
-- Keep the selected tile fully in view with 8 px to spare; `anchorRow` puts it
-- in that visible row (the equipped plate opens in the second row).
function Shop:scrollTo(index,anchorRow)
 local list=self.grid;if not list then return end
 local cols=self.columns;local row=math.floor((index-1)/cols)
 local pitch,tileH=self.rowPitch or 72,self.tileH or 64
 local top,bottom=row*pitch,row*pitch+tileH
 -- CanvasPosition and the window are in scaled pixels, the cards' offsets are not.
 local k=if list.Size.Y.Offset>0 and list.AbsoluteSize.Y>0 then list.AbsoluteSize.Y/list.Size.Y.Offset else 1
 local view=list.AbsoluteWindowSize.Y/k;if view<=0 then view=list.Size.Y.Offset end
 local maxY=math.max(0,list.CanvasSize.Y.Offset-view)
 local y=list.CanvasPosition.Y/k
 if anchorRow then y=top-pitch*(anchorRow-1)
 elseif top-8<y then y=top-8
 elseif bottom+8>y+view then y=bottom+8-view end
 list.CanvasPosition=Vector2.new(0,math.clamp(y,0,maxY)*k)
end
-- Repaint after a rebuild.
function Shop:relayout()
 self.wallet.set(self.ctx.wallet)
 self:refresh();self.backgrounds:refresh();self.balls:refresh();if self.effects then self.effects:refresh()end
 if self.visible then self.root.Visible=true;self:applyTab();self:focusActive(true)end
end

-- `top` (QA v2 R3.2, optional): where the phone sheet starts in the host (the picker
-- passes Kit.sheetTop so an inset host is not pushed down twice); default kh + 2.
function Shop:fit(size,rect,top)
 -- Compact phone roots get their own layout at scale 1 (UI-SPEC-COMPACT 9).
 if not rect and Kit.compactRule(size.X,size.Y)then
  if not top then local _,kh=Kit.keepOut();top=kh+2 end
  -- The sheet sits under the Roblox controls (QA 2026-11-12), so it has no keep-out.
  -- QA v760: it is the same rectangle as the Pocket menu, the whole root wide. It used
  -- to move in by the old plate grips (gripMargin - 6 a side), which made Deck style
  -- visibly narrower than the menu it opens from.
  local W=math.floor(size.X);local off=0
  local view={phone=true,W=W,H=math.floor(size.Y)-top,kx=0,kh=0,hx=24,off=off}
  self.root.AnchorPoint=Vector2.zero;self.root.Position=UDim2.fromOffset(off,top);self.root.Size=UDim2.fromOffset(view.W,view.H);self.scale.Scale=1
  if self.key~=Shop.viewKey(view)then self:build(view);self:relayout()end
  return
 end
 if self.view then self.root.Size=UDim2.fromOffset(848,608);self:build(nil);self:relayout()end
 -- Inside the deck LCD when given its rect (view px); otherwise centred and fitted.
 if rect then
  self.root.AnchorPoint=Vector2.zero;self.root.Position=UDim2.fromOffset(rect.x,rect.y)
  self.scale.Scale=rect.w/848
 else
  self.root.AnchorPoint=Vector2.new(.5,.5);self.root.Position=UDim2.fromScale(.5,.5)
  self.scale.Scale=math.min(1.2,(size.X-24)/848,(size.Y-24)/608)
 end
end

function Shop:setContext(ctx)
 self.ctx.equipped=ctx.equipped or self.ctx.equipped
 if ctx.wallet then self.ctx.wallet=ctx.wallet end
 if ctx.facts then self.ctx.facts=ctx.facts end
 -- Appearance words for the plate being applied (false clears), and its Retry.
 if ctx.chosen~=nil then self.ctx.chosen=ctx.chosen end
 if ctx.note~=nil then self.ctx.note=ctx.note end
 if ctx.retry~=nil then self.ctx.retry=ctx.retry end
 -- Levels matter: the pets' levels (the owner snapshot's); a flipped switch lists the tabs and cards again.
 self.ctx.levels=if Locked.on()then ctx.levels or Locked.levels()else nil
 -- The closet (rack_deck): read again with every context; a flip redraws the footer and every card, both tabs.
 self.ctx.closet=Closet.resolve(ctx.closet)
 if self.balls.ctx.closet~=self.ctx.closet then self.balls:setContext({closet=self.ctx.closet})end
 if self.levelsKey~=Levels.key()or self.closetKey~=self.ctx.closet then
  self:build(self.view);self:relayout();return
 end
 -- A book-only plate just granted (or a fresh save's facts) changes the grid: rebuild it.
 if table.concat(Shop.order(self.ctx.facts),",")~=self.orderKey then
  local id=self.tiles[self.index]and self.tiles[self.index].id
  self:build(self.view);self:relayout()
  if id and self.visible and self.tab==1 then self:focusId(id)end
  return
 end
 self.wallet.set(self.ctx.wallet)
 self:refresh()
 if self.effects and self.effects:active()then self.effects:refresh()end
end

function Shop:refresh()
 for index,tile in ipairs(self.tiles)do
  local text,role=Shop.tileStatus(tile.id,self.ctx)
  if self.view and role=="dim"then role="soft"end
  Deal.setPrice(tile.status,text)
  if tile.chip then
   local theme=Themes.ById[tile.id]
   local gate=Locked.info(theme,self.ctx.levels,Catalog.ownsFaceplate(self.ctx.facts or {},tile.id))
   tile.chip.set(gate,tile.chipRoom);tile.lock.set(gate~=nil and not gate.met)
   tile.button:SetAttribute("AccessibleLabel",if gate and not gate.met then theme.name..", "..gate.needs else theme.name)
  end
  tile.status.FontFace=if role=="accent"then Kit.Type.Label[3]else Kit.Type.Counter[3]
  Kit.paint(tile.status,"TextColor3",function()return colorOf(role,tile.status,"TextColor3")end)
  local focused=index==self.index
  Kit.paint(tile.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised",tile.button,"BackgroundColor3")end)
  tile.stroke.Thickness=if focused then 2 else 1
  tile.stroke.Transparency=if focused then 0 else .86
  Kit.paint(tile.stroke,"Color",function()return Kit.color("ink")end) -- Toy Shell: the outline is always ink
 end
 self:paintPane()
end

function Shop:paintPane()
 local id=self.tiles[self.index].id;local theme=Themes.ById[id]
 self.preview.set(theme,id)
 self.name.Text=theme.name
 local tier=TierChip[theme.tier or "starter"]or TierChip.starter
 self.tier.set(tier[1],"sticker",tier[2]) -- T6: the tier is the detail card's sticker (ink on the tier colour)
 self.finish.Text=if self.view then finishName(theme).." finish" else finishName(theme).." finish. Tints the deck and its background."
 -- The sample is drawn in that plate's own panel and accent (live preview).
 local p=self.sampleParts
 if p then
  p.sample.BackgroundColor3=theme.ui.inset;p.primary.BackgroundColor3=theme.accent;p.label.TextColor3=theme.ink
  p.track.BackgroundColor3=theme.ui.raised;p.fill.BackgroundColor3=theme.accent
 end
 local status=Shop.status(id,self.ctx)
 if self.deal then self.deal.set(status.full~=nil,self.dealWidth)end
 self.root:SetAttribute("ShelfPrice",if status.full then status.price else nil)
 local retry=self.ctx.retry==true and self.ctx.chosen==id
 local note=if self.ctx.chosen==id and self.ctx.note then self.ctx.note else nil
 local confirming=self.confirmId==id and os.clock()<self.confirmUntil
 local pending=self.pending and self.pending.plateId==id
 self.status.Text=if pending then "Buying…"elseif self.errorId==id and self.errorText then self.errorText elseif note then note else status.text
 if not pending and self.errorId==id and self.errorFit then Kit.fitText(self.status,self.errorFit)end
 local tone=if status.kind=="equipped"and not retry then "accent"elseif retry or status.kind=="short"or(self.errorId==id and self.errorText)then(if self.view then "dangerText"else "danger")else "soft"
 Kit.paint(self.status,"TextColor3",function()return colorOf(tone,self.status,"TextColor3")end)
 self:paintLock(if status.kind=="locked"then status.gate else nil,pending or note~=nil or(self.errorId==id and self.errorText~=nil))
 self.action.Visible=status.button~=nil or retry
 if retry then
  Kit.setText(self.action,"Retry");Kit.setEnabled(self.action,true)
 elseif status.button then
  Kit.setText(self.action,if pending then "Buying…"elseif confirming then "Confirm ★ "..status.price else status.button)
  Kit.setEnabled(self.action,status.enabled==true and not pending and(status.gate==nil or self.callbacks.train~=nil)and(status.kind~="egg"or self:canDeckEgg()))
  Kit.setTappable(self.action,status.kind=="short"and not self.pending)
 end
 self.root:SetAttribute("FocusedPlate",id);self.root:SetAttribute("PaneState",if retry then "retry"else status.kind)
end

function Shop:focus(index,instant)
 index=math.clamp(index,1,#self.tiles)
 if index~=self.index then self.confirmId=nil;self.errorId=nil end
 self.index=index
 self:refresh()
 if self.grid and not self.anchoring then self:scrollTo(index)end
 if self.tab==1 then
  self.ring.attach(self.tiles[index].button,12)
  if instant then self.ring.root.Visible=self.visible and self.ring.root.Visible end
 end
 if self.action and self.view then Kit.setGlyphVisible(self.action,not Kit.lastInputTouch())end
end
function Shop:focusId(id)
 local index=table.find(self.plateOrder or Themes.Order,id);if not index then return false end
 self:focus(index,true);return true
end
function Shop:focusActive(instant)
 if self.tab==2 then self.backgrounds:focus(self.backgrounds.index,instant)elseif self.tab==3 then self.balls:focus(self.balls.index,instant)
 elseif self.tab==4 and self.effects then self.effects:focus(self.effects.index,instant)else self:focus(self.index,instant)end
end
-- D-pad / arrows / WASD on the selected tab's grid.
function Shop:dismissLegend()for _,legend in pairs(self.legends or {})do legend.dismiss()end end
function Shop:move(dx,dy)
 self:dismissLegend()
 if self.tab==2 then return self.backgrounds:move(dx,dy)end
 if self.tab==3 then return self.balls:move(dx,dy)end
 if self.tab==4 and self.effects then return self.effects:move(dx,dy)end
 local nextIndex=Shop.step(self.index,dx,dy,#self.tiles,self.columns)
 if nextIndex==self.index then return false end
 self:focus(nextIndex);return true
end

-- Tabs. The header never moves; only the body under the tab row swaps.
function Shop:applyTab()
 local faces=self.tab==1
 if self.plates then self.plates.Visible=faces end
 for index,row in pairs(self.hints or {})do row.Visible=index==self.tab end
 if self.tabs then self.tabs.select(self.tab)end
 self.backgrounds:show(self.visible and self.tab==2,false)
 self.balls:show(self.visible and self.tab==3,false)
 if self.effects then self.effects:show(self.visible and self.tab==4,false)end
 self.root:SetAttribute("Tab",self.tabSet[self.tab].id)
end
function Shop:setTab(index,landOnConfirmed)
 index=math.clamp(index,1,#self.tabSet)
 local changed=index~=self.tab
 self.tab=index;self.confirmId=nil;self.errorId=nil
 self:applyTab()
 if index==2 then
  if self.visible then self.backgrounds:show(true,landOnConfirmed or changed)end
  if changed and not Kit.reduced()then
   -- Tab change: the grid cross-fades in (redesign 0.5); a short rise stands in for it.
   local body=self.backgrounds.body;if body then body.Position=UDim2.fromOffset(0,6);Kit.tween(body,.09,{Position=UDim2.new()})end
  end
 elseif index==3 then
  if self.visible then self.balls:show(true,landOnConfirmed or changed)end
  if changed and not Kit.reduced()then
   local body=self.balls.body;if body then body.Position=UDim2.fromOffset(0,6);Kit.tween(body,.09,{Position=UDim2.new()})end
  end
 elseif index==4 then
  if self.visible then self.effects:show(true,landOnConfirmed or changed)end
  if changed and not Kit.reduced()then
   local body=self.effects.body;if body then body.Position=UDim2.fromOffset(0,6);Kit.tween(body,.09,{Position=UDim2.new()})end
  end
 elseif self.visible then
  self:focus(self.index,true)
  if changed and not Kit.reduced()and self.plates then self.plates.Position=UDim2.fromOffset(0,6);Kit.tween(self.plates,.09,{Position=UDim2.new()})end
 end
 return changed
end
-- A tab press (click, tap, Q / E, LB / RB): the owner decides, else switch here.
function Shop:requestTab(index)
 index=math.clamp(index,1,#self.tabSet)
 if index==self.tab then if self.tabs then self.tabs.select(self.tab)end;return false end
 -- Effects is this screen's own tab (it is no appearance slot and holds no saved focus): the owner
 -- keeps the last of its own three, and is asked again on the way back.
 if self.tabSet[index].id=="effects"then require(script.Parent.UIClick).play("tab");return self:setTab(index)end
 if self.callbacks.tab then
  local fromEffects=self.tabSet[self.tab].id=="effects"
  local accepted=self.callbacks.tab(index)
  if fromEffects and self.tab~=index and self.visible then return self:setTab(index)end
  if self.tab~=index and self.tabs then self.tabs.select(self.tab)end
  return accepted~=false and self.tab==index
 end
 return self:setTab(index)
end
function Shop:shiftTab(delta)
 local index=Shop.nextTab(self.tab,delta)
 if index==self.tab then return false end
 return self:requestTab(index)
end

-- A / Enter / pane button. Buying needs one confirmation within 3 s.
function Shop:act(fromPane)
 self:dismissLegend()
 if self.tab==2 then return self.backgrounds:act()end
 if self.tab==3 then return self.balls:act()end
 if self.tab==4 and self.effects then return self.effects:act()end
 local id=self.tiles[self.index].id
 local status=Shop.status(id,self.ctx)
 if self.pending then return false end
 if self.ctx.retry==true and self.ctx.chosen==id then
  if self.callbacks.retry then self.callbacks.retry("theme")end;return true
 end
 if status.kind=="egg"then
  -- The closet: "More at the Deck Egg" opens Hatch eggs on the Deck Egg (init.client's onDeckEgg).
  if not self:canDeckEgg()then return false end
  return self.callbacks.deckEgg("plate",id)~=false
 end
 if status.kind=="owned"then
  if self.callbacks.equip then self.callbacks.equip(id)end
  require(script.Parent.UIClick).play("equip");return true -- QA v775 note 10
 elseif status.kind=="buy"then
  if self.confirmId==id and os.clock()<self.confirmUntil then
   self.confirmId=nil
   local opId=game:GetService("HttpService"):GenerateGUID(false)
   self.pending={id=opId,plateId=id,price=status.price}
   if self.callbacks.buy then self.callbacks.buy(self.pending)end
   self:paintPane();return true
  end
  -- Round 3 (Spencer): a buy asks in the confirm dialog instead of "press again".
  return require(script.Parent.ConfirmDialog).purchase(self,id,(Themes.ById[id]or{name=""}).name,status.price,
   function()return self.visible and self.tab==1 and self.tiles[self.index]~=nil and self.tiles[self.index].id==id end,function()self:act()end)~=nil
 elseif status.gate then
  -- Levels matter: the button leads to where that stat is trained.
  if not self.callbacks.train then return false end
  self.callbacks.train(Locked.route(status.gate));return true
 elseif status.kind=="short"then
  -- Stars store access: a short plate opens the "need more Stars" card.
  return require(script.Parent.StarsShort).ask({price=status.price,wallet=self.ctx.wallet,item=(Themes.ById[id]or{name=""}).name,from="style"},self)
 end
 return false
end

-- The closet's button has somewhere to go.
function Shop:canDeckEgg()
 local callbacks=self.callbacks
 return callbacks.deckEgg~=nil and(callbacks.hasDeckEgg==nil or callbacks.hasDeckEgg()==true)
end
-- "N Stars short. One more round?" (then "N Stars short") when the server says
-- NeedStars and the shortfall is known; the plain reason when it is not.
function Shop.shortText(plateId,ctx)
 local price=Themes.price(plateId)
 if price then price=Deal.quote("faceplate",plateId,price,Closet.week(ctx and ctx.closet,weekOf(ctx)))end
 return UICopy.starsShort(if price then price-((ctx and ctx.wallet)or 0)else nil)
end
-- Server reply to a purchase.
function Shop:result(message)
 if type(message)=="table"and message.kind=="ballTheme"then return self.balls:result(message)end
 if not self.pending or type(message)~="table"or message.id~=self.pending.id then return false end
 if message.status=="Retrying"then return false end
 local plateId=self.pending.plateId;self.pending=nil
 if message.status~="Saved"then
  local reason=({NeedStars="shop.reason.needStars",Busy="shop.reason.busy",Throttled="shop.reason.throttled",NeedsLevel="shop.reason.needsLevel",ShelfChanged="shop.reason.priceChanged",PriceChanged="shop.reason.priceChanged"})[message.reason]
  self.errorId,self.errorText,self.errorFit=plateId,Closet.reason(message.reason)or UICopy.get(reason or "shop.failed.bought"),nil
  -- A stale card: read the save again, so the chip shows.
  if message.reason=="NeedsLevel"then self.balls:send("snapshot")end
  if message.reason=="NeedStars"then self.errorFit=Shop.shortText(plateId,self.ctx);self.errorText=self.errorFit[1]end
 else
  self.errorId,self.errorText=nil,nil
  if self.callbacks.bought then self.callbacks.bought(plateId)end
 end
 self:refresh();return true
end

function Shop:back()if self.callbacks.back then self.callbacks.back()end end
function Shop:isOpen()return self.visible end
-- Opens on the equipped plate (tab 1) or the background in use (tab 2);
-- `keepFocus` (back from an inner page) keeps the cards that were focused.
function Shop:open(equipped,tab,keepFocus)
 self.visible=true;self.root.Visible=true
 -- Launch candidate: anything the background preload has not warmed yet jumps the queue now.
 require(script.Parent.StylePreload).boost()
 local index=if keepFocus then self.index else table.find(self.plateOrder or Themes.Order,equipped or self.ctx.equipped)or 1
 self.ctx.equipped=equipped or self.ctx.equipped
 self.confirmId,self.errorId=nil,nil
 self.tab=tab or self.tab
 self.anchoring=true;self.index=index;self:refresh();self.anchoring=false
 self:applyTab()
 if not keepFocus and self.legends and self.legends[self.tab]then self.legends[self.tab].open()end
 if self.tab==2 then self.backgrounds:show(true,not keepFocus)elseif self.tab==3 then self.balls:show(true,not keepFocus)
 elseif self.tab==4 and self.effects then self.effects:show(true,not keepFocus)else self:focus(index,true)end
 if self.grid then self:scrollTo(index,2)end
 self:syncPeek()
end
function Shop:close()
 if self.content then Peek.hide(self.content)end
 self.visible=false;self.root.Visible=false;if self.ring then self.ring.hide()end;self.confirmId=nil;require(script.Parent.ConfirmDialog).cancelFor(self)
 self.backgrounds:show(false)
 self.balls:show(false)
 if self.effects then self.effects:show(false)end
end
-- T4: the pet peeks over the tab bar (desktop only), between the title and the
-- Stars capsule; the clip keeps clear of the title, eyebrow and wallet.
Shop.PeekSlot=table.freeze({x=420,y=4,w=200,h=80})
function Shop:syncPeek()
 if not self.content then return false end
 if not self.visible or self.view~=nil or not self.header or not self.header.geometry then Peek.hide(self.content);return false end
 local g=self.header.geometry
 local TextService=game:GetService("TextService")
 local title=self.header.title
 local tw=TextService:GetTextSize(title.Text,title.TextSize,Enum.Font.FredokaOne,Vector2.new(2000,200)).X*1.1
 local avoid={{x=g.title.x,y=g.title.y,w=tw,h=g.title.h}}
 if g.eyebrow then table.insert(avoid,{x=g.eyebrow.x,y=g.eyebrow.y,w=TextService:GetTextSize(self.header.eyebrow.Text,13,Enum.Font.BuilderSansBold,Vector2.new(2000,200)).X*1.1+20,h=g.eyebrow.h})end
 if g.wallet then table.insert(avoid,g.wallet)end
 table.insert(avoid,g.back)
 return Peek.show(self.content,{rect=Shop.PeekSlot,avoid=avoid,align="center",key="style",compact=false})
end
return Shop
