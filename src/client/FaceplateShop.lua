-- Faceplate shop (UI-SPEC-2026-11-12 section 5.5, mockup 07-faceplate-shop).
-- A 848x608 glass screen: preview pane, 4x4 grid of all 16 plates, wallet.
-- Fixed Star prices; the server validates and debits (HatchProgress.buyFaceplate).
-- Focus is owned here (d-pad / arrows / WASD move, A / Enter acts, B backs out);
-- touch and mouse select a tile with the first tap and act with the pane button.
local Shared=game:GetService("ReplicatedStorage").Shared
local Themes=require(Shared.DeckThemes)
local Catalog=require(Shared.AppearanceCatalog)
local Kit=require(script.Parent.DeckKit)
local Assets=require(script.Parent.DeckAssets)
local Shop={}
Shop.__index=Shop
Shop.Size=Vector2.new(848,608)
Shop.Columns=4
Shop.ConfirmSeconds=3
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

-- Mini deck composed from the real shell sprites (296 wide in the pane, 89 on tiles).
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
-- callbacks: equip(id), buy(id, price) -> bool sent, back(), backgrounds()
function Shop.new(host,callbacks)
 local self=setmetatable({host=host,callbacks=callbacks or {},index=1,ctx={equipped=Themes.Default,wallet=0,facts={}},
  visible=false,pending=nil,confirmUntil=0,columns=Shop.Columns},Shop)
 local root=Kit.frame(host,"FaceplateShop","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
 root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.Visible=false;root.ClipsDescendants=true;self.rootStroke=Kit.stroke(root)
 local gradient=Kit.frame(root,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 self.gradient=gradient
 self.root=root
 self.scale=Kit.node("UIScale",root,{Scale=1})
 self:build(nil)
 return self
end

function Shop:build(view)
 if self.content then self.content:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 self.view=view;self.key=Shop.viewKey(view)
 local root=self.root
 local phone=view~=nil
 root.BackgroundTransparency=if phone then 1 else 0;self.gradient.Visible=not phone;self.rootStroke.Enabled=not phone
 root.ClipsDescendants=not phone
 local content=Kit.frame(root,"Content",nil,UDim2.new(),if phone then UDim2.fromOffset(view.W,view.H)else UDim2.fromOffset(848,608));content.ZIndex=root.ZIndex+2
 self.content=content
 if phone then return self:buildCompact(view)end
 self.columns=Shop.Columns
 txt(content,"Label","DECK STYLE","dim",24,14,200,16)
 txt(content,"Title","Faceplates","text",24,32,300,32)
 self.wallet=Kit.wallet(content,40);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(824,24)
 local backgrounds=Kit.button(content,"Backgrounds",{variant="ghost",text="Backgrounds",size=Vector2.new(140,40),selectable=false})
 backgrounds.Position=UDim2.fromOffset(536,24);Kit.buttonState(backgrounds).label.TextSize=16
 backgrounds.Activated:Connect(function()if self.callbacks.backgrounds then self.callbacks.backgrounds()end end)
 self.backgroundsButton=backgrounds
 -- Preview pane.
 local pane=Kit.card(content,"Preview",nil,{pad=20});pane.Position=UDim2.fromOffset(24,84);pane.Size=UDim2.fromOffset(328,452)
 self.preview=miniDeck(pane,296,UDim2.fromOffset(16,16))
 self.name=txt(pane,"Title","","text",20,172,220,30)
 self.tier=Kit.chip(pane,"RARE",nil,26);self.tier.root.AnchorPoint=Vector2.new(1,0);self.tier.root.Position=UDim2.fromOffset(308,176)
 self.finish=txt(pane,"Small","","soft",20,208,288,20,{TextSize=15})
 txt(pane,"Label","TINTS YOUR MENUS","dim",20,248,288,16)
 local sample=Kit.frame(pane,"Sample",nil,UDim2.fromOffset(20,270),UDim2.fromOffset(288,56),12);sample.BackgroundTransparency=0
 Kit.stroke(sample)
 local samplePrimary=Kit.frame(sample,"Primary",nil,UDim2.fromOffset(10,10),UDim2.fromOffset(104,36),10);samplePrimary.BackgroundTransparency=0
 local sampleLabel=txt(samplePrimary,"Strong","Primary",nil,0,0,104,36,{TextXAlignment=Enum.TextXAlignment.Center})
 local track=Kit.frame(sample,"Track",nil,UDim2.fromOffset(128,24),UDim2.fromOffset(110,8),999);track.BackgroundTransparency=0
 local trackFill=Kit.frame(track,"Fill",nil,UDim2.new(),UDim2.fromScale(.68,1),999);trackFill.BackgroundTransparency=0
 local star=Kit.icon(sample,"star",20);star.Position=UDim2.fromOffset(254,18)
 self.sampleParts={sample=sample,primary=samplePrimary,label=sampleLabel,track=track,fill=trackFill}
 self.status=txt(pane,"Small","","soft",20,340,288,20)
 local action,actionState=Kit.button(pane,"Action",{variant="primary",text="Equip",glyph="A",size=Vector2.new(288,56),selectable=false})
 action.Position=UDim2.fromOffset(20,372);self.action,self.actionState=action,actionState
 action.Activated:Connect(function()self:act(true)end)
 -- Grid.
 self.tiles={}
 for index,id in ipairs(Themes.Order)do
  local col,row=(index-1)%4,math.floor((index-1)/4)
  local tile=Kit.node("TextButton",content,{Name="Tile_"..id,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
   Position=UDim2.fromOffset(368+col*(105+12),84+row*(104+12)),Size=UDim2.fromOffset(105,104),ZIndex=content.ZIndex+1})
  Kit.corner(tile,12)
  local stroke=Kit.stroke(tile)
  tile:SetAttribute("AccessibleLabel",Themes.ById[id].name)
  local deck=miniDeck(tile,89,UDim2.fromOffset(8,8));deck.set(Themes.ById[id],id)
  local nameLabel=txt(tile,"Strong",Themes.ById[id].name,"text",8,54,92,16,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
  local status=txt(tile,"Counter","","soft",8,74,92,18,{TextSize=13})
  self.tiles[index]={id=id,button=tile,status=status,name=nameLabel,stroke=stroke}
  tile.Activated:Connect(function()
   if self.index==index then self:act(true)else self:focus(index)end
  end)
 end
 self.ring=Kit.focusRing(root) -- root carries the UIScale the ring divides by
 self.grid=nil
 -- Hint bar.
 local hints=Kit.frame(content,"Hints",nil,UDim2.fromOffset(24,560),UDim2.fromOffset(500,24))
 local x=0
 for _,pair in ipairs({{"+","Browse"},{"A","Buy or equip"},{"B","Back"}})do
  local g=Kit.glyph(hints,pair[1],false,22);g.Position=UDim2.fromOffset(x,1)
  local t=txt(hints,"Small",pair[2],"soft",x+28,0,120,24);t.AutomaticSize=Enum.AutomaticSize.X
  x+=28+game:GetService("TextService"):GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
 end
 txt(content,"Small","Fixed prices. No random plates.","dim",524,560,300,24,{TextXAlignment=Enum.TextXAlignment.Right})
end

-- Pure (UI-SPEC-COMPACT 9): pane width, grid width, columns and tile width.
function Shop.compactGrid(W,H)
 local pw=if W<700 then 200 else 232
 local gw=W-pw-52
 local cols=if gw>=420 then 2 else 1
 return{pw=pw,gw=gw,cols=cols,tileW=math.floor((gw-8-(cols-1)*8)/cols),paneH=H-82,gridH=H-82}
end
function Shop.viewKey(view)
 return if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"
end

-- Compact (phone) shop: a scrolling grid on the left, a pinned preview pane with
-- Buy / Equip on the right, all in one menu sheet.
function Shop:buildCompact(v)
 local content=self.content
 local W,H=v.W,v.H
 local grid=Shop.compactGrid(W,H)
 self.columns=grid.cols
 local sheet=Kit.sheet(content,W,H)
 local body=Kit.frame(content,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 txt(body,"Title","Faceplates","text",v.hx,18,200,24,{TextSize=20})
 local titleW=game:GetService("TextService"):GetTextSize("Faceplates",20,Enum.Font.BuilderSansBold,Vector2.new(400,40)).X
 self.wallet=Kit.wallet(body,32);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(W-66,14)
 local backgrounds=Kit.button(body,"Backgrounds",{variant="ghost",text="Backgrounds",size=Vector2.new(122,44),textSize=14,selectable=false})
 backgrounds.Position=UDim2.fromOffset(v.hx+math.ceil(titleW)+14,8)
 local bs=Kit.buttonState(backgrounds)
 -- Drawn 36 high with a 1 px stroke inside the 44-high hit frame.
 bs.fill.Position=UDim2.fromOffset(0,4);bs.fill.Size=UDim2.new(1,0,0,36);bs.edge.Visible=false
 Kit.setFontRole(bs.label,"Strong")
 local outline=Kit.frame(backgrounds,"Outline",nil,UDim2.fromOffset(0,4),UDim2.new(1,0,0,36),12);Kit.stroke(outline)
 backgrounds.Activated:Connect(function()if self.callbacks.backgrounds then self.callbacks.backgrounds()end end)
 self.backgroundsButton=backgrounds
 local back=Kit.backArrow(body,true);back.root.Position=UDim2.fromOffset(W-12,8);back.root.ZIndex=body.ZIndex+5
 back.root.Activated:Connect(function()if self.callbacks.back then self.callbacks.back()end end)
 self.backArrow=back
 -- Preview pane (pinned).
 local pw,ph=grid.pw,grid.paneH
 local pane=Kit.card(body,"Preview",nil,{pad=12});pane.Position=UDim2.fromOffset(W-20-pw,64);pane.Size=UDim2.fromOffset(pw,ph)
 local deckW=if H<340 then 144 else pw-24
 self.preview=miniDeck(pane,deckW,UDim2.fromOffset((pw-deckW)/2,10))
 local nameY=10+deckW/2+16+9
 self.name=txt(pane,"Title","","text",12,nameY-12,pw-24-90,24,{TextSize=18,TextTruncate=Enum.TextTruncate.AtEnd})
 self.tier=Kit.chip(pane,"RARE",nil,22);self.tier.label.TextSize=12;self.tier.root.AnchorPoint=Vector2.new(1,.5);self.tier.root.Position=UDim2.fromOffset(pw-12,nameY)
 self.finish=txt(pane,"Small","","soft",12,nameY+22-9,pw-24,18,{TextSize=12})
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
 -- Grid: a vertical ScrollingFrame, 4 px bar inside an 8 px gutter.
 local list=Kit.node("ScrollingFrame",body,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,64),
  Size=UDim2.fromOffset(grid.gw,grid.gridH),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
  ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
 local rows=math.ceil(#Themes.Order/grid.cols)
 list.CanvasSize=UDim2.fromOffset(0,rows*72-8)
 self.grid=list
 self.tiles={}
 for index,id in ipairs(Themes.Order)do
  local col,row=(index-1)%grid.cols,math.floor((index-1)/grid.cols)
  local tile=Kit.node("TextButton",list,{Name="Tile_"..id,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
   Position=UDim2.fromOffset(col*(grid.tileW+8),row*72),Size=UDim2.fromOffset(grid.tileW,64),ZIndex=list.ZIndex+1})
  Kit.corner(tile,12)
  local stroke=Kit.stroke(tile)
  tile:SetAttribute("AccessibleLabel",Themes.ById[id].name)
  local deck=miniDeck(tile,88,UDim2.fromOffset(10,9));deck.set(Themes.ById[id],id)
  local nameLabel=txt(tile,"Strong",Themes.ById[id].name,"text",108,12,grid.tileW-116,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  local status=txt(tile,"Counter","","soft",108,34,grid.tileW-116,18,{TextSize=13})
  self.tiles[index]={id=id,button=tile,status=status,name=nameLabel,stroke=stroke}
  tile.Activated:Connect(function()
   if self.index==index then self:act(true)else self:focus(index)end
  end)
 end
 self.ring=Kit.focusRing(self.root)
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
 self:refresh()
 if self.visible then self.root.Visible=true;self:focus(self.index,true)end
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
 self.finish.Text=finishName(theme)
 -- The sample is drawn in that plate's own panel and accent (live preview).
 local p=self.sampleParts
 if p then
  p.sample.BackgroundColor3=theme.ui.inset;p.primary.BackgroundColor3=theme.accent;p.label.TextColor3=theme.ink
  p.track.BackgroundColor3=theme.ui.raised;p.fill.BackgroundColor3=theme.accent
 end
 local status=Shop.status(id,self.ctx)
 local confirming=self.confirmId==id and os.clock()<self.confirmUntil
 local pending=self.pending and self.pending.plateId==id
 self.status.Text=if pending then "Buying…"elseif self.errorId==id and self.errorText then self.errorText else status.text
 local tone=if status.kind=="equipped"then "accent"elseif status.kind=="short"or(self.errorId==id and self.errorText)then(if self.view then "dangerText"else "danger")else "soft"
 Kit.paint(self.status,"TextColor3",function()return colorOf(tone)end)
 self.action.Visible=status.button~=nil
 if status.button then
  Kit.setText(self.action,if pending then "Buying…"elseif confirming then "Confirm ★ "..status.price else status.button)
  Kit.setEnabled(self.action,status.enabled==true and not pending)
 end
 self.root:SetAttribute("FocusedPlate",id);self.root:SetAttribute("PaneState",status.kind)
end

function Shop:focus(index,instant)
 index=math.clamp(index,1,#self.tiles)
 if index~=self.index then self.confirmId=nil;self.errorId=nil end
 self.index=index
 self:refresh()
 if self.grid and not self.anchoring then self:scrollTo(index)end
 self.ring.attach(self.tiles[index].button,12)
 if instant then self.ring.root.Visible=self.visible and self.ring.root.Visible end
 if self.action and self.view then Kit.setGlyphVisible(self.action,not Kit.lastInputTouch())end
end
function Shop:move(dx,dy)
 local nextIndex=Shop.step(self.index,dx,dy,#self.tiles,self.columns)
 if nextIndex==self.index then return false end
 self:focus(nextIndex);return true
end

-- A / Enter / pane button. Buying needs one confirmation within 3 s.
function Shop:act(fromPane)
 local id=self.tiles[self.index].id
 local status=Shop.status(id,self.ctx)
 if self.pending then return false end
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

function Shop:open(equipped)
 self.visible=true;self.root.Visible=true
 local index=table.find(Themes.Order,equipped or self.ctx.equipped)or 1
 self.ctx.equipped=equipped or self.ctx.equipped
 self.confirmId,self.errorId=nil,nil
 self.anchoring=true;self:focus(index,true);self.anchoring=false
 if self.grid then self:scrollTo(index,2)end
end
function Shop:close()
 self.visible=false;self.root.Visible=false;self.ring.hide();self.confirmId=nil
end
return Shop
