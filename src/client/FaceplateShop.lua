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
function Shop.step(index,dx,dy,count)
 local cols=Shop.Columns
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
  visible=false,pending=nil,confirmUntil=0},Shop)
 local root=Kit.frame(host,"FaceplateShop","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
 root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.Visible=false;root.ClipsDescendants=true;Kit.stroke(root)
 local gradient=Kit.frame(root,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 local content=Kit.frame(root,"Content",nil,UDim2.new(),UDim2.fromOffset(848,608));content.ZIndex=root.ZIndex+2
 self.root,self.content=root,content
 self.scale=Kit.node("UIScale",root,{Scale=1})
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
 -- Hint bar.
 local hints=Kit.frame(content,"Hints",nil,UDim2.fromOffset(24,560),UDim2.fromOffset(500,24))
 local x=0
 for _,pair in ipairs({{"+","Browse"},{"A","Buy or equip"},{"B","Back"}})do
  local g=Kit.glyph(hints,pair[1],false,22);g.Position=UDim2.fromOffset(x,1)
  local t=txt(hints,"Small",pair[2],"soft",x+28,0,120,24);t.AutomaticSize=Enum.AutomaticSize.X
  x+=28+game:GetService("TextService"):GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
 end
 txt(content,"Small","Fixed prices. No random plates.","dim",524,560,300,24,{TextXAlignment=Enum.TextXAlignment.Right})
 return self
end

function Shop:fit(size,rect)
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
 p.sample.BackgroundColor3=theme.ui.inset;p.primary.BackgroundColor3=theme.accent;p.label.TextColor3=theme.ink
 p.track.BackgroundColor3=theme.ui.raised;p.fill.BackgroundColor3=theme.accent
 local status=Shop.status(id,self.ctx)
 local confirming=self.confirmId==id and os.clock()<self.confirmUntil
 local pending=self.pending and self.pending.plateId==id
 self.status.Text=if pending then "Buying…"elseif self.errorId==id and self.errorText then self.errorText else status.text
 local tone=if status.kind=="equipped"then "accent"elseif status.kind=="short"or(self.errorId==id and self.errorText)then "danger"else "soft"
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
 self.ring.attach(self.tiles[index].button,12)
 if instant then self.ring.root.Visible=self.visible end
end
function Shop:move(dx,dy)
 local nextIndex=Shop.step(self.index,dx,dy,#self.tiles)
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
 self:focus(index,true)
end
function Shop:close()
 self.visible=false;self.root.Visible=false;self.ring.hide();self.confirmId=nil
end
return Shop
