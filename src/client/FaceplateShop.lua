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
local Assets=require(script.Parent.DeckAssets)
local BackgroundShop=require(script.Parent.BackgroundShop)
-- Third tab, Balls (batch 2026-11-13 R1): ball themes, drawn by BallShop.
local BallShop=require(script.Parent.BallShop)
local Shop={}
Shop.__index=Shop
Shop.Size=Vector2.new(848,608)
Shop.Columns=4
Shop.ConfirmSeconds=3
Shop.Title,Shop.Eyebrow="Deck style","Pocket deck"
Shop.Tabs={{id="faceplates",label="Faceplates",icon="faceplate"},{id="backgrounds",label="Backgrounds",icon="pattern"},{id="balls",label="Balls",icon="smiley"}}
-- Desktop rects in panel units (section 4): tabs where Wardrobe's slot tabs sit, the
-- pane at 24,144 328x392, a 4x4 grid of 104x88 cards from 371,147, hints on y 566.
Shop.Regular={tabs={24,84,800,44},pane={24,144,328,392},grid={371,147},tile={104,88},gap=12,hints=566}
Shop.Hints={
 {pairs={{"+","Browse"},{"LB","Tab"},{"A","Buy or equip"},{"B","Back"}},promise="Fixed prices. No random plates."},
 {pairs={{"+","Browse"},{"LB","Tab"},{"A","Use"},{"B","Back"}},promise="Backgrounds are earned, not bought."},
 {pairs={{"+","Browse"},{"LB","Tab"},{"A","Buy or use"},{"B","Back"}},promise="Fixed prices. Looks only, never an advantage."},
}
local TierChip={starter={"STARTER",Color3.fromHex("#C3C8D0")},common={"COMMON",Color3.fromHex("#9BE3A8")},
 rare={"RARE",Color3.fromHex("#8CC8FF")},showcase={"SHOWCASE",Color3.fromHex("#E6B3FF")}}
local function finishName(theme)
 local finish=theme.finish or "gloss"
 return string.upper(string.sub(finish,1,1))..string.sub(finish,2)
end

-- Pure: what the pane says and offers for one plate.
-- ctx = { equipped = id, wallet = n, facts = AppearanceCatalog facts (with .faceplates) }
function Shop.status(id,ctx)
 local theme=Themes.ById[id]
 if not theme then return {kind="invalid",text="",button=nil}end
 local facts=ctx.facts or {}
 if ctx.equipped==id then return {kind="equipped",text="Equipped",button=nil}end
 local price=Themes.price(id)
 if price and not Catalog.ownsFaceplate(facts,id)then
  local wallet=ctx.wallet or 0
  if wallet>=price then return {kind="buy",text="You have enough Stars",button="★ Buy "..price,price=price,enabled=true}end
  return {kind="short",text=(price-wallet).." more Stars needed",button="★ Buy "..price,price=price,enabled=false}
 end
 local requirement=Catalog.describeRequirement("theme",id,facts)
 if requirement.unlocked then return {kind="owned",text="",button="Equip",enabled=true}end
 return {kind="locked",text=requirement.text,button=nil}
end
-- Pure: the tile's status line.
function Shop.tileStatus(id,ctx)
 local s=Shop.status(id,ctx)
 if s.kind=="equipped"then return "EQUIPPED","accent"end
 if s.kind=="owned"then return "✓ Owned","soft"end
 if s.kind=="buy"then return "★ "..s.price,"stars"end
 if s.kind=="short"then return "★ "..s.price,"dim"end
 local short=({firstWin="Win 1",rankI="Win 3",rankII="Win 10"})[Themes.ById[id]and Themes.ById[id].rule or ""]or "Locked"
 return "🔒 "..short,"dim"
end
-- Pure: grid navigation (no wrap).
function Shop.step(index,dx,dy,count,columns)
 local cols=columns or Shop.Columns
 local col,row=(index-1)%cols,math.floor((index-1)/cols)
 local rows=math.ceil(count/cols)
 col=math.clamp(col+dx,0,cols-1);row=math.clamp(row+dy,0,rows-1)
 return math.min(count,row*cols+col+1)
end
-- Pure: the next tab for a Q / E (LB / RB) press, clamped (no wrap).
function Shop.nextTab(tab,delta)return math.clamp(tab+delta,1,#Shop.Tabs)end

-- Mini deck composed from the real shell sprites (296 wide in the pane, 88 on tiles).
local function miniDeck(parent,width,position)
 local s=width/1600;local L=Assets.Layout;local I=Assets.Image
 local root=Kit.frame(parent,"MiniDeck",nil,position,UDim2.fromOffset(width,800*s))
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
 return {root=root,set=function(theme,id)
  plate.Image=Assets.Faceplate[id]or Assets.Faceplate.sherbet
  band.ImageColor3=theme.bandTint or Color3.new(1,1,1)
  finish.Visible=theme.overlay~=nil;if theme.overlay then finish.Image=theme.overlay.image;finish.ImageTransparency=1-theme.overlay.max*.6 end
  lcd.BackgroundColor3=theme.ui.panel
  arrows.ImageColor3=theme.accent;buttonA.ImageColor3=theme.accent
  wordmark.ImageColor3=theme.engrave or Color3.new(0,0,0);wordmark.ImageTransparency=1-(theme.engraveOpacity or .42)
 end}
end

-- Colour by role, resolved at paint time so a re-tint repaints correctly.
local function colorOf(role)
 if role=="accent"or role=="selected"or role=="raised"or role=="well"or role=="panel"then return Kit.color(role)end
 return Kit.Color[role]or Kit.Color.text
end
local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end

-- host: a Frame that receives the 848x608 glass screen (scaled to fit).
-- callbacks: equip(id), buy(order), bought(id), back(), tab(index) (a tab request:
-- the owner answers with setTab), rebuilt(), and for Backgrounds: use(id), trials(),
-- retry(slot).
function Shop.new(host,callbacks)
 local self=setmetatable({host=host,callbacks=callbacks or {},index=1,tab=1,ctx={equipped=Themes.Default,wallet=0,facts={}},
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
  trials=function()if self.callbacks.trials then self.callbacks.trials()end end,
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
  self.header=Kit.header(parent,{title=Shop.Title,compact=true,width=view.W,left=view.hx,onBack=function()self:back()end})
 else
  self.header=Kit.header(parent,{title=Shop.Title,eyebrow=Shop.Eyebrow,width=848,onBack=function()self:back()end})
 end
 self.wallet,self.backArrow,self.title=self.header.wallet,self.header.back,self.header.title
 local labels,icons={},{}
 for _,tab in ipairs(Shop.Tabs)do table.insert(labels,tab.label);table.insert(icons,tab.icon)end
 if phone then
  self.tabs=Kit.tabs(parent,labels,tabsW,36,if tabsW<400 then 12 else 14,icons);self.tabs.root.Position=UDim2.fromOffset(20,64)
 else
  local R=Shop.Regular.tabs
  self.tabs=Kit.tabs(parent,labels,R[3],R[4],16,icons);self.tabs.root.Position=UDim2.fromOffset(R[1],R[2])
 end
 self.tabs.changed=function(index)self:requestTab(index)end
 self.hints={}
 if not phone then
  for index,set in ipairs(Shop.Hints)do
   local row=Kit.frame(parent,"Hints"..index,nil,UDim2.fromOffset(24,Shop.Regular.hints),UDim2.fromOffset(800,24))
   local hints=Kit.frame(row,"Hints",nil,UDim2.new(),UDim2.fromOffset(560,24))
   local x=0
   for _,pair in ipairs(set.pairs)do
    local g=Kit.glyph(hints,pair[1],false,22);g.Position=UDim2.fromOffset(x,1)
    local t=txt(hints,"Small",pair[2],"soft",x+28,0,120,24);t.AutomaticSize=Enum.AutomaticSize.X
    x+=28+game:GetService("TextService"):GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
   end
   txt(row,"Small",set.promise,"dim",500,0,300,24,{Name="Promise",TextXAlignment=Enum.TextXAlignment.Right})
   self.hints[index]=row
  end
 end
end

function Shop:build(view)
 if self.content then self.backgrounds:releasePreview();self.content:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 self.view=view;self.key=Shop.viewKey(view)
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
end

function Shop:buildRegular()
 local content=self.content
 self.columns=Shop.Columns
 self:buildChrome(content,nil)
 local R=Shop.Regular
 local plates=Kit.frame(content,"Faceplates",nil,UDim2.new(),UDim2.fromScale(1,1));self.plates=plates
 -- Preview pane.
 local pw,ph=R.pane[3],R.pane[4]
 local pane=Kit.card(plates,"Preview",nil,{pad=20});pane.Position=UDim2.fromOffset(R.pane[1],R.pane[2]);pane.Size=UDim2.fromOffset(pw,ph)
 self.preview=miniDeck(pane,296,UDim2.fromOffset(16,16))
 self.name=txt(pane,"Title","","text",20,170,200,30,{TextTruncate=Enum.TextTruncate.AtEnd})
 self.tier=Kit.chip(pane,"RARE",nil,26);self.tier.root.AnchorPoint=Vector2.new(1,.5);self.tier.root.Position=UDim2.fromOffset(308,185)
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
 -- Grid: 16 plates, 4 columns of 104x88, no scroll.
 self.tiles={}
 for index,id in ipairs(Themes.Order)do
  local col,row=(index-1)%4,math.floor((index-1)/4)
  local tile=Kit.node("TextButton",plates,{Name="Tile_"..id,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
   Position=UDim2.fromOffset(R.grid[1]+col*(R.tile[1]+R.gap),R.grid[2]+row*(R.tile[2]+R.gap)),Size=UDim2.fromOffset(R.tile[1],R.tile[2]),ZIndex=plates.ZIndex+1})
  Kit.corner(tile,12)
  local stroke=Kit.stroke(tile)
  tile:SetAttribute("AccessibleLabel",Themes.ById[id].name)
  local deck=miniDeck(tile,88,UDim2.fromOffset(8,6));deck.set(Themes.ById[id],id)
  local nameLabel=txt(tile,"Strong",Themes.ById[id].name,"text",8,51,90,16,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
  local status=txt(tile,"Counter","","soft",8,68,90,16,{TextSize=13})
  self.tiles[index]={id=id,button=tile,status=status,name=nameLabel,stroke=stroke}
  tile.Activated:Connect(function()
   if self.index==index then self:act(true)else self:focus(index)end
  end)
 end
 self.grid=nil
 self.backgrounds:build(content,nil,nil)
 self.balls:build(content,nil,nil)
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
 local pane=Kit.card(plates,"Preview",nil,{pad=12});pane.Position=UDim2.fromOffset(W-20-pw,64);pane.Size=UDim2.fromOffset(pw,ph)
 local deckW=if H<340 then 144 else pw-24
 self.preview=miniDeck(pane,deckW,UDim2.fromOffset((pw-deckW)/2,10))
 local nameY=10+deckW/2+16+9
 self.name=txt(pane,"Title","","text",12,nameY-12,pw-24-90,24,{TextSize=18,TextTruncate=Enum.TextTruncate.AtEnd})
 self.tier=Kit.chip(pane,"RARE",nil,22);self.tier.label.TextSize=12;self.tier.root.AnchorPoint=Vector2.new(1,.5);self.tier.root.Position=UDim2.fromOffset(pw-12,nameY)
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
 self.status=txt(pane,"Body","","soft",12,statusY-10,pw-24,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
 local action,actionState=Kit.button(pane,"Action",{variant="primary",text="Equip",glyph="A",size=Vector2.new(pw-24,48),textSize=16,selectable=false})
 action.Position=UDim2.fromOffset(12,buttonY);self.action,self.actionState=action,actionState
 action.Activated:Connect(function()self:act(true)end)
 -- Grid: a vertical ScrollingFrame under the tabs, 4 px bar inside an 8 px gutter.
 local list=Kit.node("ScrollingFrame",plates,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,112),
  Size=UDim2.fromOffset(grid.gw,grid.gridH),ScrollBarThickness=4,ZIndex=plates.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
  ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
 local rows=math.ceil(#Themes.Order/grid.cols)
 list.CanvasSize=UDim2.fromOffset(0,rows*72-8)
 self.grid=list
 self.tiles={}
 -- Narrow (three-column) cards draw a 72 px deck so the name keeps room.
 local deckTile=if grid.tileW>=200 then 88 else 72
 local tx=10+deckTile+10
 for index,id in ipairs(Themes.Order)do
  local col,row=(index-1)%grid.cols,math.floor((index-1)/grid.cols)
  local tile=Kit.node("TextButton",list,{Name="Tile_"..id,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
   Position=UDim2.fromOffset(col*(grid.tileW+8),row*72),Size=UDim2.fromOffset(grid.tileW,64),ZIndex=list.ZIndex+1})
  Kit.corner(tile,12)
  local stroke=Kit.stroke(tile)
  tile:SetAttribute("AccessibleLabel",Themes.ById[id].name)
  local deck=miniDeck(tile,deckTile,UDim2.fromOffset(10,(64-deckTile/2)/2));deck.set(Themes.ById[id],id)
  local nameLabel=txt(tile,"Strong",Themes.ById[id].name,"text",tx,12,grid.tileW-tx-8,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  local status=txt(tile,"Counter","","soft",tx,34,grid.tileW-tx-8,18,{TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd})
  self.tiles[index]={id=id,button=tile,status=status,name=nameLabel,stroke=stroke}
  tile.Activated:Connect(function()
   if self.index==index then self:act(true)else self:focus(index)end
  end)
 end
 self.backgrounds:build(body,v,grid)
 self.balls:build(body,v,grid)
end
-- Keep the selected tile fully in view with 8 px to spare; `anchorRow` puts it
-- in that visible row (the equipped plate opens in the second row).
function Shop:scrollTo(index,anchorRow)
 local list=self.grid;if not list then return end
 local cols=self.columns;local row=math.floor((index-1)/cols)
 local top,bottom=row*72,row*72+64
 local view=list.AbsoluteWindowSize.Y;if view<=0 then view=list.Size.Y.Offset end
 local maxY=math.max(0,list.CanvasSize.Y.Offset-view)
 local y=list.CanvasPosition.Y
 if anchorRow then y=top-72*(anchorRow-1)
 elseif top-8<y then y=top-8
 elseif bottom+8>y+view then y=bottom+8-view end
 list.CanvasPosition=Vector2.new(0,math.clamp(y,0,maxY))
end
-- Repaint after a rebuild.
function Shop:relayout()
 self.wallet.set(self.ctx.wallet)
 self:refresh();self.backgrounds:refresh();self.balls:refresh()
 if self.visible then self.root.Visible=true;self:applyTab();self:focusActive(true)end
end

function Shop:fit(size,rect)
 -- Compact phone roots get their own layout at scale 1 (UI-SPEC-COMPACT 9).
 if not rect and Kit.compactRule(size.X,size.Y)then
  local _,kh=Kit.keepOut();local top=kh+2
  -- Compact v2 plate grips (UI-SPEC-COMPACT-FRAME 4): the sheet moves in by mg - 6,
  -- and down under the Roblox controls (QA 2026-11-12), so it has no keep-out.
  local W=math.floor(size.X);local mg=require(script.Parent.DeckScreen).gripMargin(W);local off=mg-6
  local view={phone=true,W=W-2*off,H=math.floor(size.Y)-top,kx=0,kh=0,hx=mg+18-off,off=off}
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
 self.wallet.set(self.ctx.wallet)
 self:refresh()
end

function Shop:refresh()
 for index,tile in ipairs(self.tiles)do
  local text,role=Shop.tileStatus(tile.id,self.ctx)
  if self.view and role=="dim"then role="soft"end
  tile.status.Text=text
  tile.status.FontFace=if role=="accent"then Kit.Type.Label[3]else Kit.Type.Counter[3]
  Kit.paint(tile.status,"TextColor3",function()return colorOf(role)end)
  local focused=index==self.index
  Kit.paint(tile.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised")end)
  tile.stroke.Thickness=if focused then 2 else 1
  tile.stroke.Transparency=if focused then 0 else .86
  Kit.paint(tile.stroke,"Color",function()return if focused then Kit.color("accent")else Color3.new(1,1,1)end)
 end
 self:paintPane()
end

function Shop:paintPane()
 local id=self.tiles[self.index].id;local theme=Themes.ById[id]
 self.preview.set(theme,id)
 self.name.Text=theme.name
 local tier=TierChip[theme.tier or "starter"]or TierChip.starter
 self.tier.set(tier[1]);self.tier.label.TextColor3=tier[2]
 self.finish.Text=if self.view then finishName(theme).." finish" else finishName(theme).." finish. Tints the deck and its background."
 -- The sample is drawn in that plate's own panel and accent (live preview).
 local p=self.sampleParts
 if p then
  p.sample.BackgroundColor3=theme.ui.inset;p.primary.BackgroundColor3=theme.accent;p.label.TextColor3=theme.ink
  p.track.BackgroundColor3=theme.ui.raised;p.fill.BackgroundColor3=theme.accent
 end
 local status=Shop.status(id,self.ctx)
 local retry=self.ctx.retry==true and self.ctx.chosen==id
 local note=if self.ctx.chosen==id and self.ctx.note then self.ctx.note else nil
 local confirming=self.confirmId==id and os.clock()<self.confirmUntil
 local pending=self.pending and self.pending.plateId==id
 self.status.Text=if pending then "Buying…"elseif self.errorId==id and self.errorText then self.errorText elseif note then note else status.text
 local tone=if status.kind=="equipped"and not retry then "accent"elseif retry or status.kind=="short"or(self.errorId==id and self.errorText)then(if self.view then "dangerText"else "danger")else "soft"
 Kit.paint(self.status,"TextColor3",function()return colorOf(tone)end)
 self.action.Visible=status.button~=nil or retry
 if retry then
  Kit.setText(self.action,"Retry");Kit.setEnabled(self.action,true)
 elseif status.button then
  Kit.setText(self.action,if pending then "Buying…"elseif confirming then "Confirm ★ "..status.price else status.button)
  Kit.setEnabled(self.action,status.enabled==true and not pending)
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
 local index=table.find(Themes.Order,id);if not index then return false end
 self:focus(index,true);return true
end
function Shop:focusActive(instant)
 if self.tab==2 then self.backgrounds:focus(self.backgrounds.index,instant)elseif self.tab==3 then self.balls:focus(self.balls.index,instant)else self:focus(self.index,instant)end
end
-- D-pad / arrows / WASD on the selected tab's grid.
function Shop:move(dx,dy)
 if self.tab==2 then return self.backgrounds:move(dx,dy)end
 if self.tab==3 then return self.balls:move(dx,dy)end
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
 self.root:SetAttribute("Tab",Shop.Tabs[self.tab].id)
end
function Shop:setTab(index,landOnConfirmed)
 index=math.clamp(index,1,#Shop.Tabs)
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
 elseif self.visible then
  self:focus(self.index,true)
  if changed and not Kit.reduced()and self.plates then self.plates.Position=UDim2.fromOffset(0,6);Kit.tween(self.plates,.09,{Position=UDim2.new()})end
 end
 return changed
end
-- A tab press (click, tap, Q / E, LB / RB): the owner decides, else switch here.
function Shop:requestTab(index)
 index=math.clamp(index,1,#Shop.Tabs)
 if index==self.tab then if self.tabs then self.tabs.select(self.tab)end;return false end
 if self.callbacks.tab then
  local accepted=self.callbacks.tab(index)
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
 if self.tab==2 then return self.backgrounds:act()end
 if self.tab==3 then return self.balls:act()end
 local id=self.tiles[self.index].id
 local status=Shop.status(id,self.ctx)
 if self.pending then return false end
 if self.ctx.retry==true and self.ctx.chosen==id then
  if self.callbacks.retry then self.callbacks.retry("theme")end;return true
 end
 if status.kind=="owned"then
  if self.callbacks.equip then self.callbacks.equip(id)end;return true
 elseif status.kind=="buy"then
  if self.confirmId==id and os.clock()<self.confirmUntil then
   self.confirmId=nil
   local opId=game:GetService("HttpService"):GenerateGUID(false)
   self.pending={id=opId,plateId=id,price=status.price}
   if self.callbacks.buy then self.callbacks.buy(self.pending)end
   self:paintPane();return true
  end
  self.confirmId,self.confirmUntil=id,os.clock()+Shop.ConfirmSeconds
  local token=self.confirmUntil
  task.delay(Shop.ConfirmSeconds,function()if self.confirmUntil==token then self.confirmId=nil;if self.visible then self:paintPane()end end end)
  self:paintPane();return true
 end
 return false
end

-- Server reply to a purchase.
function Shop:result(message)
 if type(message)=="table"and message.kind=="ballTheme"then return self.balls:result(message)end
 if not self.pending or type(message)~="table"or message.id~=self.pending.id then return false end
 if message.status=="Retrying"then return false end
 local plateId=self.pending.plateId;self.pending=nil
 if message.status~="Saved"then
  self.errorId,self.errorText=plateId,({NeedStars="Not enough Stars",Busy="Busy, try again",Throttled="Try again in a moment"})[message.reason]or "Not bought"
 else
  self.errorId,self.errorText=nil,nil
  if self.callbacks.bought then self.callbacks.bought(plateId)end
 end
 self:refresh();return true
end

function Shop:back()if self.callbacks.back then self.callbacks.back()end end
function Shop:isOpen()return self.visible end
-- Opens on the equipped plate (tab 1) or the background in use (tab 2);
-- `keepFocus` (back from Pocket Trials) keeps the cards that were focused.
function Shop:open(equipped,tab,keepFocus)
 self.visible=true;self.root.Visible=true
 local index=if keepFocus then self.index else table.find(Themes.Order,equipped or self.ctx.equipped)or 1
 self.ctx.equipped=equipped or self.ctx.equipped
 self.confirmId,self.errorId=nil,nil
 self.tab=tab or self.tab
 self.anchoring=true;self.index=index;self:refresh();self.anchoring=false
 self:applyTab()
 if self.tab==2 then self.backgrounds:show(true,not keepFocus)elseif self.tab==3 then self.balls:show(true,not keepFocus)else self:focus(index,true)end
 if self.grid then self:scrollTo(index,2)end
end
function Shop:close()
 self.visible=false;self.root.Visible=false;if self.ring then self.ring.hide()end;self.confirmId=nil
 self.backgrounds:show(false)
 self.balls:show(false)
end
return Shop
