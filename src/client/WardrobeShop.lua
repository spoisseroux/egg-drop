-- Wardrobe: pet wearables for Stars (the faceplate shop pattern, UI-SPEC-2026-11-12
-- section 3 components, UI-SPEC-COMPACT section 5 sheet on phones).
-- Opened from the Companions editor at the Care Cradle. Slot tabs (hat, shirt, neck,
-- ears, eyes, mouth, tail), item cards with price / owned / wearing states, and a pinned
-- preview pane where the pet wears the focused item live. Fixed prices; the server
-- validates, debits and saves (HatchProgress.buyWearable / equipWearable).
-- Focus is owned here: d-pad / arrows / WASD move, Q / E and L1 / R1 switch tabs,
-- A / Enter acts, B / Backspace backs out. Touch: the first tap selects, the pane
-- button (or a second tap) acts.
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.WearableCatalog)
local Pets=require(Shared.PetCatalog)
local Rules=require(Shared.PetAttachmentRules)
local Defs=require(Shared.PetRigDefinitions)
local Palette=require(Shared.PetPalette)
local Kit=require(script.Parent.DeckKit)
local UICopy=require(Shared.UICopy)
local Factory=require(script.Parent.PetFactory)
local Bounds=require(script.Parent.PetRigBounds)
local Shop={}
Shop.__index=Shop
Shop.Size=Vector2.new(848,608)
Shop.ConfirmSeconds=3
local TierChip={common={"COMMON",Color3.fromHex("#9BE3A8")},rare={"RARE",Color3.fromHex("#8CC8FF")},showcase={"SHOWCASE",Color3.fromHex("#E6B3FF")}}
local SlotNote={Hat="Hats sit on the crown",Shirt="Sleeves move with the arms",Neck="Draws over a shirt",EarPiercing="A pair, one for each ear",
 Eyes="Replaces the eyes",Mouth="Replaces the neutral smile",Tail="Replaces the tail"}

-- Pure: what the pane says and offers for one item.
-- ctx = { petId, wallet, row = {owned={...}, equipped={key=id}} }
function Shop.status(petId,itemId,ctx)
 local item=Catalog.item(petId,itemId)
 if not item then return {kind="invalid",text="",button=nil}end
 local row=ctx.row or {owned={},equipped={}}
 local owned=table.find(row.owned or {},itemId)~=nil
 if owned and Catalog.equippedIn(petId,row.equipped,item.slot)==itemId then return {kind="equipped",text="Wearing",button="Take off",enabled=true}end
 if owned then return {kind="owned",text="",button="Wear",enabled=true}end
 local wallet=ctx.wallet or 0
 if wallet>=item.price then return {kind="buy",text="You have enough Stars",button="★ Buy "..item.price,price=item.price,enabled=true}end
 return {kind="short",text=(item.price-wallet).." more Stars needed",button="★ Buy "..item.price,price=item.price,enabled=false}
end
function Shop.tileStatus(petId,itemId,ctx)
 local s=Shop.status(petId,itemId,ctx)
 if s.kind=="equipped"then return "WEARING","accent"end
 if s.kind=="owned"then return "✓ Owned","soft"end
 if s.kind=="buy"then return "★ "..s.price,"stars"end
 if s.kind=="short"then return "★ "..s.price,"dim"end
 return "","dim"
end
-- Pure: the wearables shown on the preview pet: what is saved, with the focused item
-- swapped into its slot (or the slot emptied when the focused item is the one worn).
function Shop.previewWearables(petId,equipped,itemId)
 local result=table.clone(equipped or {})
 local item=itemId and Catalog.item(petId,itemId)
 if not item then return result end
 for _,key in ipairs(Catalog.slotKeys(petId,item.slot))do result[key]=nil end
 for _,key in ipairs(item.keys)do result[key]=item.id end
 return result
end
-- Pure: a short line about exclusions for the focused item (hide, never unequip).
function Shop.note(petId,itemId,stages)
 local item=Catalog.item(petId,itemId);if not item then return ""end
 local horns=(stages and stages.horns or 0)>0
 if item.slot=="Hat"and item.flags.openCrown then return if horns then "Open crown: your horns stay visible"else "Open crown: horns stay visible"end
 if item.slot=="Hat"and item.flags.coversHorns and horns then return "Hides your horns while worn"end
 if item.slot=="Mouth"and item.flags.neutralOnly then return "Shows on the neutral face; other moods keep their mouth"end
 return SlotNote[item.slot]or ""
end
function Shop.step(index,dx,dy,count,columns)
 local cols=math.max(1,columns or 2)
 local col,row=(index-1)%cols,math.floor((index-1)/cols)
 local rows=math.max(1,math.ceil(count/cols))
 col=math.clamp(col+dx,0,cols-1);row=math.clamp(row+dy,0,rows-1)
 return math.max(1,math.min(count,row*cols+col+1))
end
-- Pure (UI-SPEC-COMPACT 9 geometry): pane width, grid width, columns, tile width.
function Shop.compactGrid(W,H)
 local pw=if W<700 then 200 else 232
 local gw=W-pw-52
 local cols=if gw>=420 then 2 else 1
 return{pw=pw,gw=gw,cols=cols,tileW=math.floor((gw-8-(cols-1)*8)/cols),paneH=H-82,gridH=H-82-48}
end
function Shop.viewKey(view)return if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"end
-- QA Q2.3 card previews: each visible card shows the pet wearing only that item,
-- framed on the slot, in its own ViewportFrame. Built lazily (one per frame, visible
-- cards only), cached per pet / item / tint while the Wardrobe is open, and the
-- colour tile stays as the fallback when a rig cannot be built.
-- Code review: only visible cards hold a ViewportFrame (at most CardPreviewLive at
-- once); a card scrolled off screen has its preview detached, and past the cache size
-- the least recently shown detached preview is destroyed (visible ones never are).
Shop.CardPreviewLive=12
Shop.CardPreviewCache=24
-- Pure: where a card preview's camera looks ("head", "body" or "tail") and its zoom.
function Shop.cardFraming(slot)
 if slot=="Hat"or slot=="Eyes"or slot=="Mouth"or slot=="EarPiercing"then return "head",.62 end
 if slot=="Tail"then return "tail",.85 end
 return "body",.9
end
-- Pure: the cache key (a tinted item renders in the pet's own palette colour).
function Shop.cardKey(petId,itemId,tint)return petId..":"..itemId..":"..(if tint then tint:ToHex()else "")end
-- Pure: is a card (top y, height) inside the scroll window (top y, height), with a margin.
function Shop.cardVisible(cardY,cardH,windowY,windowH)
 return cardY+cardH>=windowY-8 and cardY<=windowY+windowH+8
end

local function colorOf(role)
 if role=="accent"or role=="selected"or role=="raised"or role=="well"or role=="panel"then return Kit.color(role)end
 return Kit.Color[role]or Kit.Color.text
end
local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end

-- host: a full-screen Frame. callbacks: buy(order), equip(order), back(), appearance(petId) -> appearance.
function Shop.new(host,callbacks)
 local self=setmetatable({host=host,callbacks=callbacks or {},tab=1,index=1,petId="pip",ctx={wallet=0,row={owned={},equipped={}}},
  visible=false,pending=nil,confirmUntil=0,columns=2},Shop)
 -- QA Q2.1: one full-screen shade beside the panel (never its parent).
 local shade=Kit.modalShade(host,"WardrobeShade",40);self.shade=shade
 local root=Kit.frame(host,"WardrobeShop","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
 root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.ClipsDescendants=true;root.ZIndex=41;root.Visible=false;self.rootStroke=Kit.stroke(root)
 local gradient=Kit.frame(root,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 self.gradient=gradient;self.root=root
 self.scale=Kit.node("UIScale",root,{Scale=1})
 self:build(nil)
 return self
end

function Shop:items()return Catalog.inTab(self.petId,Catalog.Tabs[self.tab].slot)end

-- Shared pane pieces: a ViewportFrame with the pet, name, tier, note, status, action.
function Shop:buildPane(pane,pw,ph,compact)
 local pad=if compact then 12 else 16
 local nameH=if compact then 22 else 30
 local actionH=if compact then 48 else 56
 local lower=(if compact then 22+18+20+12 else 30+22+24+16)+actionH+pad
 local viewH=math.max(80,ph-lower-pad)
 local well=Kit.frame(pane,"PreviewWell","well",UDim2.fromOffset(pad,pad),UDim2.fromOffset(pw-pad*2,viewH),12);Kit.stroke(well)
 local viewport=Kit.node("ViewportFrame",well,{Name="PetPreview",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=well.ZIndex+1,
  Ambient=Color3.fromRGB(175,184,183),LightColor=Color3.fromRGB(255,250,231),LightDirection=Vector3.new(-1,-1.4,-3)})
 local world=Kit.node("WorldModel",viewport,{});local camera=Kit.node("Camera",viewport,{FieldOfView=30})
 viewport.CurrentCamera=camera
 self.viewport,self.world,self.camera=viewport,world,camera
 if self.visual then self.visual:destroy();self.visual=nil end
 local y=pad+viewH+(if compact then 8 else 12)
 self.name=txt(pane,"Title","","text",pad,y,pw-pad*2-96,nameH,{TextSize=if compact then 18 else 24,TextTruncate=Enum.TextTruncate.AtEnd})
 self.tier=Kit.chip(pane,"RARE","sticker",if compact then 22 else 26);if compact then self.tier.label.TextSize=12 end
 self.tier.root.AnchorPoint=Vector2.new(1,.5);self.tier.root.Position=UDim2.fromOffset(pw-pad,y+nameH/2)
 y+=nameH+(if compact then 0 else 4)
 self.note=txt(pane,"Small","","soft",pad,y,pw-pad*2,18,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd});y+=if compact then 18 else 22
 self.status=txt(pane,"Body","","soft",pad,y,pw-pad*2,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
 local action,state=Kit.button(pane,"Action",{variant="primary",text="Wear",glyph="A",size=Vector2.new(pw-pad*2,actionH),textSize=if compact then 16 else nil,selectable=false})
 action.Position=UDim2.fromOffset(pad,ph-pad-actionH);self.action,self.actionState=action,state
 action.Activated:Connect(function()self:act()end)
end

function Shop:buildTiles(parent,x0,y0,tileW,tileH,gap,cols)
 self:detachPreviews()
 if self.tileRoot then self.tileRoot:Destroy()end
 local holder=Kit.frame(parent,"Tiles",nil,UDim2.new(),UDim2.fromScale(1,1));holder.ZIndex=parent.ZIndex+1;self.tileRoot=holder
 self.tiles={}
 for index,item in ipairs(self:items())do
  local col,row=(index-1)%cols,math.floor((index-1)/cols)
  -- T2: pressable tile with a lip (4 px in the 12 px desktop gap, 3 px in the 8 px phone gap).
  local tile,tileState=Kit.tile(holder,"Tile_"..item.id,{selectable=false,radius=12,compact=gap<12,
   position=UDim2.fromOffset(x0+col*(tileW+gap),y0+row*(tileH+gap)),size=UDim2.fromOffset(tileW,tileH)})
  local stroke=tileState.stroke
  tile:SetAttribute("AccessibleLabel",item.name);tile:SetAttribute("ItemId",item.id)
  -- Swatch: the item's own colour (or the pet's secondary for tinted items).
  local side=tileH-20
  local swatch=Kit.frame(tile,"Swatch",nil,UDim2.fromOffset(10,10),UDim2.fromOffset(side,side),10);swatch.BackgroundTransparency=0
  swatch.BackgroundColor3=if item.primary then Color3.fromHex(item.primary)else Kit.Color.soft;Kit.stroke(swatch)
  local tier=TierChip[item.tier]or TierChip.common
  local dot=Kit.frame(swatch,"TierDot",nil,UDim2.new(1,-12,0,4),UDim2.fromOffset(8,8),999);dot.BackgroundTransparency=0;dot.BackgroundColor3=tier[2];dot.ZIndex=swatch.ZIndex+3
  local tx=10+side+12
  local nameLabel=txt(tile,"Name",item.name,"text",tx,tileH/2-20,tileW-tx-8,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
  local status=txt(tile,"Counter","","soft",tx,tileH/2+2,tileW-tx-8,18,{TextSize=13})
  self.tiles[index]={id=item.id,button=tile,status=status,name=nameLabel,stroke=stroke,swatch=swatch,role=item.role,slot=item.slot,primary=item.primary}
  tile.Activated:Connect(function()if self.index==index then self:act()else self:focus(index);Kit.boing(tile)end end)
 end
 if #self.tiles==0 then txt(holder,"Body",UICopy.get("wardrobe.emptySlot"),"soft",x0,y0,300,24)end
end

function Shop:build(view)
 self:detachPreviews()
 if self.content then self.content:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 self.view=view;self.key=Shop.viewKey(view);self.tileRoot=nil
 local root=self.root;local phone=view~=nil
 root.BackgroundTransparency=if phone then 1 else 0;self.gradient.Visible=not phone;self.rootStroke.Enabled=not phone;root.ClipsDescendants=not phone
 Kit.setShadeAlpha(self.shade,if phone then 1 else Kit.ShadeAlpha)
 local content=Kit.frame(root,"Content",nil,UDim2.new(),if phone then UDim2.fromOffset(view.W,view.H)else UDim2.fromOffset(848,608));content.ZIndex=root.ZIndex+2
 self.content=content
 local labels={};for _,tab in ipairs(Catalog.Tabs)do table.insert(labels,tab.label)end
 if phone then
  local W,H=view.W,view.H;local g=Shop.compactGrid(W,H);self.columns=g.cols;self.grid=g
  local sheet=Kit.sheet(content,W,H)
  local body=Kit.frame(content,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3;self.body=body
  -- Shared header (redesign 0.1): title, Stars capsule and back circle, 36 drawn.
  self.header=Kit.header(body,{title="Wardrobe",tint="companions",compact=true,width=W,left=view.hx,onBack=function()self:back()end})
  self.title,self.wallet,self.backArrow=self.header.title,self.header.wallet,self.header.back
  local pane=Kit.card(body,"Preview",nil,{pad=12,seam=true});pane.Position=UDim2.fromOffset(W-20-g.pw,64);pane.Size=UDim2.fromOffset(g.pw,g.paneH)
  self:buildPane(pane,g.pw,g.paneH,true)
  self.tabs=Kit.tabs(body,labels,g.gw,36,if g.gw<400 then 12 else 14);self.tabs.root.Position=UDim2.fromOffset(20,64)
  local list=Kit.node("ScrollingFrame",body,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(20,112),
   Size=UDim2.fromOffset(g.gw,g.gridH),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
   ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
  self.list=list
 else
  self.columns=2;self.grid=nil;self.body=content
  self.header=Kit.header(content,{title="Wardrobe",eyebrow="Companions",tint="companions",width=848,onBack=function()self:back()end})
  Kit.halftone(content,"companions",false)
  self.title,self.wallet,self.backArrow=self.header.title,self.header.wallet,self.header.back
  self.tabs=Kit.tabs(content,labels,800,44,16);self.tabs.root.Position=UDim2.fromOffset(24,84)
  local pane=Kit.card(content,"Preview",nil,{pad=16,seam=true});pane.Position=UDim2.fromOffset(24,144);pane.Size=UDim2.fromOffset(328,404)
  self:buildPane(pane,328,404,false)
  local list=Kit.node("ScrollingFrame",content,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(368,144),
   Size=UDim2.fromOffset(456,404),ScrollBarThickness=4,ZIndex=content.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
   ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
  self.list=list
  local hints=Kit.frame(content,"Hints",nil,UDim2.fromOffset(24,566),UDim2.fromOffset(560,24))
  local x=0
  for _,pair in ipairs({{"+","Browse"},{"LB","Slot"},{"A","Buy or wear"},{"B","Back"}})do
   local g=Kit.glyph(hints,pair[1],false,22,true);g.Position=UDim2.fromOffset(x,1)
   local t=txt(hints,"Small",pair[2],"soft",x+28,0,120,24);t.AutomaticSize=Enum.AutomaticSize.X
   x+=28+game:GetService("TextService"):GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
  end
  txt(content,"Small","Fixed prices. No random items.","dim",524,566,300,24,{TextXAlignment=Enum.TextXAlignment.Right})
 end
 self.tabs.changed=function(index)self:setTab(index)end
 self.tabs.select(self.tab)
 self.ring=Kit.focusRing(self.root)
 self:layoutTiles()
end

function Shop:layoutTiles()
 local list=self.list
 if self.view then
  local g=self.grid
  -- 3 px in from the scroll edges: the selected tile's outline was clipped (QA 2026-11-12).
  self:buildTiles(list,3,3,g.tileW-6,64,8,g.cols)
  list.CanvasSize=UDim2.fromOffset(0,math.max(0,math.ceil(#self.tiles/g.cols)*72-8+6))
 else
  self:buildTiles(list,3,3,217,96,12,2)
  list.CanvasSize=UDim2.fromOffset(0,math.max(0,math.ceil(#self.tiles/2)*108-12+6))
 end
 list.CanvasPosition=Vector2.zero
 self:placeEmptyLine()
end
-- T12: this pet owns no wearables yet: one line in voice under the cards, only where
-- the grid has room below them (no layout change; the pane already shows the pet).
function Shop.ownsNothing(row)return not(row and type(row.owned)=="table"and #row.owned>0)end
function Shop.emptyText(petId)
 local pet=Pets.byId[petId]
 return if pet then UICopy.get("wardrobe.empty",{pet=pet.name})else UICopy.get("wardrobe.emptySolo")
end
function Shop:placeEmptyLine()
 self.emptyLine=nil
 local list=self.list
 if not list or not self.tileRoot or #self.tiles==0 then return end
 local last=self.tiles[#self.tiles].button
 local y=last.Position.Y.Offset+last.Size.Y.Offset+12
 if y+22>list.Size.Y.Offset then return end
 self.emptyLine=txt(self.tileRoot,"Body",Shop.emptyText(self.petId),"soft",3,y,list.Size.X.Offset-6,22,
  {Name="EmptyLine",TextSize=if self.view then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 self.emptyLine.Visible=Shop.ownsNothing(self.ctx.row)
end

function Shop:fit(size)
 if Kit.compactRule(size.X,size.Y)then
  -- QA 2026-11-12: the sheet starts under the Roblox controls, so it has no keep-out.
  local _,kh=Kit.keepOut();local top=kh+2
  local view={phone=true,W=math.floor(size.X),H=math.floor(size.Y)-top,kx=0,kh=0,hx=24}
  self.root.AnchorPoint=Vector2.zero;self.root.Position=UDim2.fromOffset(0,top);self.root.Size=UDim2.fromOffset(view.W,view.H);self.scale.Scale=1
  if self.key~=Shop.viewKey(view)then self:build(view);self:relayout()end
  return
 end
 if self.view then self.root.Size=UDim2.fromOffset(848,608);self:build(nil);self:relayout()end
 self.root.AnchorPoint=Vector2.new(.5,.5);self.root.Position=UDim2.fromScale(.5,.5)
 self.scale.Scale=math.min(1.2,(size.X-24)/848,(size.Y-24)/608)
end
function Shop:relayout()
 self.wallet.set(self.ctx.wallet);self.index=math.clamp(self.index,1,math.max(1,#self.tiles))
 self:refresh();if self.visible then self:focus(self.index,true)end
end

-- Pure (QA Q2.4): the equipped map after wearing (wear = item id) or taking off
-- (wear = false) one item, as the server's equipWearable saves it.
function Shop.applyEquip(petId,equipped,itemId,wear)
 if wear then return Shop.previewWearables(petId,equipped,itemId)end
 local result=table.clone(equipped or {})
 local item=Catalog.item(petId,itemId);if not item then return result end
 for _,key in ipairs(Catalog.slotKeys(petId,item.slot))do result[key]=nil end
 return result
end
-- Code review: the look shown is the last server-confirmed look (`self.confirmed`)
-- with every equip still in flight (`self.equips`, oldest first) replayed on top, so a
-- refusal only ever undoes its own change and never a save that already succeeded.
function Shop.replayEquips(petId,confirmed,equips)
 local result=table.clone(confirmed or {})
 for _,order in ipairs(equips or {})do if order.petId==petId then result=Shop.applyEquip(petId,result,order.itemId,order.wear)end end
 return result
end
function Shop:setContext(ctx)
 if ctx.wallet then self.ctx.wallet=ctx.wallet end
 if ctx.row then
  -- The server's word; an optimistic equip in flight stays on until its own result says otherwise.
  self.confirmed=table.clone(ctx.row.equipped or {})
  self.ctx.row={owned=ctx.row.owned,equipped=Shop.replayEquips(self.petId,self.confirmed,self.equips)}
 end
 if ctx.stages then self.ctx.stages=ctx.stages end
 if self.wallet then self.wallet.set(self.ctx.wallet)end
 if self.visible then self:refresh()end
end

function Shop:focusedId()local tile=self.tiles[self.index];return tile and tile.id end

-- Card previews (QA Q2.3).
-- The card's own colour tile (the pet's palette colour for tinted items).
function Shop:swatchColor(tile)
 if tile.role then
  local palette=Palette.resolve(self.petId,self.callbacks.appearance and self.callbacks.appearance(self.petId)or nil)
  if palette and typeof(palette[tile.role])=="Color3"then return palette[tile.role]end
 end
 return if tile.primary then Color3.fromHex(tile.primary)else Kit.Color.soft
end
-- One card loses its preview (scrolled off, rebuilt or closed); the entry stays cached.
function Shop:detachPreview(tile)
 local entry=tile.preview
 if not entry then return end
 entry.viewport.Parent=nil;entry.shownAt=os.clock();tile.preview=nil
 if tile.swatch.Parent then tile.swatch:SetAttribute("Preview",nil);tile.swatch.BackgroundColor3=self:swatchColor(tile)end
end
function Shop:detachPreviews()
 for _,tile in ipairs(self.tiles or {})do self:detachPreview(tile)end
end
local function destroyEntry(entry)
 if entry.visual and not entry.visual.destroyed then entry.visual:destroy()end
 entry.viewport:Destroy()
end
-- Destroy the least recently shown detached preview; false when every one is on a card.
function Shop:evictPreview()
 local oldestKey,oldest=nil,nil
 for key,entry in pairs(self.previews or {})do
  if entry and entry.viewport.Parent==nil and(oldest==nil or(entry.shownAt or 0)<(oldest.shownAt or 0))then oldestKey,oldest=key,entry end
 end
 if not oldest then return false end
 destroyEntry(oldest);self.previews[oldestKey]=nil;self.previewCount-=1
 return true
end
function Shop:clearPreviews()
 self:detachPreviews()
 for _,entry in pairs(self.previews or {})do if entry then destroyEntry(entry)end end
 self.previews,self.previewCount={},0
end
-- Previews currently on cards (each one a rendering ViewportFrame).
function Shop:livePreviews()
 local live=0
 for _,tile in ipairs(self.tiles or {})do if tile.preview then live+=1 end end
 return live
end
function Shop:poseCard(entry)
 local v=entry.visual;if not v or v.destroyed then return end
 v.yaw=if entry.slot=="Tail"then math.pi*.8 else -.35
 v.reducedEffects=true;v.poseDirty=true;v:update(0)
 entry.rig=v.rigRevision
 local box,size=Bounds.get(v)
 local focus,zoom=Shop.cardFraming(entry.slot)
 local half=math.tan(math.rad(entry.camera.FieldOfView/2))
 local distance=(math.max(size.Y,size.X)*.5/half+size.Z*.5+.3)*zoom
 local center=box.Position+(if focus=="head"then Vector3.new(0,size.Y*.22,0)elseif focus=="body"then Vector3.new(0,-size.Y*.04,0)else Vector3.zero)
 entry.camera.CFrame=CFrame.lookAt(center+Vector3.new(0,.1,distance),center)
end
function Shop:buildCardPreview(tile)
 local pet=Pets.byId[self.petId];if not pet then return false end
 local appearance=table.clone(self.callbacks.appearance and self.callbacks.appearance(self.petId)or {})
 appearance.wearables=Shop.previewWearables(self.petId,{},tile.id)
 local viewport=Instance.new("ViewportFrame");viewport.Name="CardPreview";viewport.BackgroundTransparency=1;viewport.Size=UDim2.fromScale(1,1)
 viewport.Ambient=Color3.fromRGB(175,184,183);viewport.LightColor=Color3.fromRGB(255,250,231);viewport.LightDirection=Vector3.new(-1,-1.4,-3)
 local world=Instance.new("WorldModel");world.Parent=viewport
 local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
 local ok,visual=pcall(Factory.new,world,Vector3.zero,pet,nil,appearance)
 if not ok or not visual then viewport:Destroy();return false end
 local entry={viewport=viewport,camera=camera,visual=visual,slot=tile.slot}
 local posed=pcall(self.poseCard,self,entry)
 if not posed then visual:destroy();viewport:Destroy();return false end
 return entry
end
-- Runs every frame while open: detaches previews from cards scrolled off screen,
-- attaches cached previews to visible cards, builds at most one missing one, and refits
-- a card whose rig finished loading after it was built.
function Shop:pumpPreviews()
 if not self.visible or not self.list or not self.tiles then return end
 self.previews=self.previews or {};self.previewCount=self.previewCount or 0
 local windowY=self.list.AbsolutePosition.Y;local windowH=self.list.AbsoluteWindowSize.Y
 if windowH<=0 then windowH=self.list.AbsoluteSize.Y end
 local now=os.clock()
 local visible={}
 local live=0
 for index,tile in ipairs(self.tiles)do
  visible[index]=tile.button.Parent~=nil and Shop.cardVisible(tile.button.AbsolutePosition.Y,tile.button.AbsoluteSize.Y,windowY,windowH)
  if tile.preview then
   if not visible[index]then self:detachPreview(tile)
   else
    live+=1;tile.preview.shownAt=now
    local v=tile.preview.visual
    if v and not v.destroyed and v.rigRevision~=tile.preview.rig then self:poseCard(tile.preview)end
   end
  end
 end
 local built=false
 for index,tile in ipairs(self.tiles)do
  if live>=Shop.CardPreviewLive then break end
  if tile.preview==nil and visible[index]then
   local palette=tile.role and Palette.resolve(self.petId,self.callbacks.appearance and self.callbacks.appearance(self.petId)or nil)
   local tint=if palette and typeof(palette[tile.role])=="Color3"then palette[tile.role]else nil
   local key=Shop.cardKey(self.petId,tile.id,tint)
   local entry=self.previews[key]
   if entry==nil then
    if built then continue end
    while self.previewCount>=Shop.CardPreviewCache and self:evictPreview()do end
    if self.previewCount>=Shop.CardPreviewCache then continue end
    built=true
    entry=self:buildCardPreview(tile);self.previews[key]=entry
    if entry then self.previewCount+=1 end
   end
   if entry then
    entry.viewport.ZIndex=tile.swatch.ZIndex+1;entry.viewport.Parent=tile.swatch;entry.shownAt=now
    tile.preview=entry;tile.swatch.BackgroundColor3=Kit.color("well")
    tile.swatch:SetAttribute("Preview",true);live+=1
   else tile.preview=false end
  end
 end
end
function Shop:refresh()
 if self.emptyLine then self.emptyLine.Visible=Shop.ownsNothing(self.ctx.row)end
 -- Tinted items show this pet's own palette colour (its secondary, face...), not grey.
 local palette=Palette.resolve(self.petId,self.callbacks.appearance and self.callbacks.appearance(self.petId)or nil)
 for index,tile in ipairs(self.tiles)do
  if tile.role and palette and typeof(palette[tile.role])=="Color3"and not tile.preview then tile.swatch.BackgroundColor3=palette[tile.role]end
  local text,role=Shop.tileStatus(self.petId,tile.id,self.ctx)
  if self.view and role=="dim"then role="soft"end
  tile.status.Text=text
  tile.status.FontFace=if role=="accent"then Kit.Type.Label[3]else Kit.Type.Counter[3]
  Kit.paint(tile.status,"TextColor3",function()return colorOf(role)end)
  local focused=index==self.index
  Kit.paint(tile.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised")end)
  tile.stroke.Thickness=if focused then 2 else 1;tile.stroke.Transparency=if focused then 0 else .86
  Kit.paint(tile.stroke,"Color",function()return if focused then Kit.color("accent")else Color3.new(1,1,1)end)
  tile.button:SetAttribute("TileState",Shop.status(self.petId,tile.id,self.ctx).kind)
 end
 self:paintPane()
end

function Shop:paintPreview()
 local id=self:focusedId()
 local base=table.clone(self.callbacks.appearance and self.callbacks.appearance(self.petId)or {})
 base.wearables=Shop.previewWearables(self.petId,self.ctx.row.equipped,if id and Shop.status(self.petId,id,self.ctx).kind~="equipped"then id else nil)
 if id and Shop.status(self.petId,id,self.ctx).kind=="equipped"then base.wearables=table.clone(self.ctx.row.equipped)end
 base.appearanceGeneration=(base.appearanceGeneration or 0)
 if not self.visual or self.visualPet~=self.petId then
  if self.visual then self.visual:destroy()end
  self.visual=Factory.new(self.world,Vector3.zero,Pets.byId[self.petId],nil,base);self.visualPet=self.petId;self.cameraKey=nil
 end
 local slot=Catalog.Tabs[self.tab].slot
 -- The tail tab turns the pet round so the tail faces the viewer.
 self.visual.yaw=if slot=="Tail"then math.pi*.8 else -.25
 self.visual.reducedEffects=GuiService.ReducedMotionEnabled
 if self.visual.applyAppearance then self.visual:applyAppearance(base)end
 self.visual.poseDirty=true;self.visual:update(0)
 self.root:SetAttribute("PreviewWearables",Rules.signature(Rules.normalize(Defs[self.petId],base.wearables)))
 self:fitCamera()
end
function Shop:fitCamera()
 local v=self.visual;if not v then return end
 local key=tostring(self.viewport.AbsoluteSize)..":"..tostring(v.rigRevision or 0)..":"..self.tab
 if self.cameraKey==key then return end;self.cameraKey=key
 local box,size=Bounds.get(v);local a=math.max(.1,self.viewport.AbsoluteSize.X/math.max(1,self.viewport.AbsoluteSize.Y));local half=math.tan(math.rad(self.camera.FieldOfView/2))
 local slot=Catalog.Tabs[self.tab].slot
 local zoom=if slot=="Hat"or slot=="Eyes"or slot=="Mouth"or slot=="EarPiercing"then .78 else 1
 local distance=(math.max(size.Y*.5/half,size.X*.5/(half*a))+size.Z*.5+.3)*zoom
 local center=box.Position+(if zoom<1 then Vector3.new(0,size.Y*.18,0)else Vector3.zero)
 self.camera.CFrame=CFrame.lookAt(center+Vector3.new(0,.12,distance*1.10),center)
end

function Shop:paintPane()
 local id=self:focusedId()
 if not id then
  self.name.Text="";self.note.Text="";self.status.Text="";self.action.Visible=false;self.tier.root.Visible=false
  if self.visible then self:paintPreview()end;return
 end
 local item=Catalog.item(self.petId,id);self.tier.root.Visible=true
 self.name.Text=item.name
 local tier=TierChip[item.tier]or TierChip.common;self.tier.set(tier[1],"sticker",tier[2]) -- T6: tier sticker, ink on the tier colour
 self.note.Text=Shop.note(self.petId,id,self.ctx.stages)
 local status=Shop.status(self.petId,id,self.ctx)
 local confirming=self.confirmId==id and os.clock()<self.confirmUntil
 local pending=self.pending and self.pending.itemId==id and self.pending.action=="wearableBuy"
 self.status.Text=if pending then "Saving…"elseif self.errorId==id and self.errorText then self.errorText else status.text
 if not pending and self.errorId==id and self.errorFit then Kit.fitText(self.status,self.errorFit)end
 local tone=if status.kind=="equipped"then "accent"elseif status.kind=="short"or(self.errorId==id and self.errorText)then(if self.view then "dangerText"else "danger")else "soft"
 Kit.paint(self.status,"TextColor3",function()return colorOf(tone)end)
 self.action.Visible=status.button~=nil
 if status.button then
  Kit.setText(self.action,if pending then "Saving…"elseif confirming then "Confirm ★ "..status.price else status.button)
  Kit.setEnabled(self.action,status.enabled==true and not(self.pending and self.pending.action=="wearableBuy"))
 end
 self.root:SetAttribute("FocusedItem",id);self.root:SetAttribute("PaneState",status.kind);self.root:SetAttribute("Tab",Catalog.Tabs[self.tab].id)
 if self.visible then self:paintPreview()end
end

function Shop:scrollTo(index)
 local list=self.list;local tile=self.tiles[index];if not list or not tile then return end
 local top=tile.button.Position.Y.Offset;local bottom=top+tile.button.Size.Y.Offset
 local view=list.AbsoluteWindowSize.Y;if view<=0 then view=list.Size.Y.Offset end
 local y=list.CanvasPosition.Y
 if top-8<y then y=top-8 elseif bottom+8>y+view then y=bottom+8-view end
 list.CanvasPosition=Vector2.new(0,math.clamp(y,0,math.max(0,list.CanvasSize.Y.Offset-view)))
end
function Shop:focus(index,instant)
 if #self.tiles==0 then self.index=1;self.ring.hide();self:refresh();return end
 index=math.clamp(index,1,#self.tiles)
 if index~=self.index then self.confirmId=nil;self.errorId=nil end
 self.index=index;self:refresh();self:scrollTo(index)
 self.ring.attach(self.tiles[index].button,12)
 if instant then self.ring.root.Visible=self.visible and self.ring.root.Visible end
 if self.view then Kit.setGlyphVisible(self.action,not Kit.lastInputTouch())end
end
function Shop:move(dx,dy)
 local nextIndex=Shop.step(self.index,dx,dy,#self.tiles,self.columns)
 if nextIndex==self.index then return false end
 self:focus(nextIndex);return true
end
function Shop:setTab(index)
 index=math.clamp(index,1,#Catalog.Tabs)
 if self.pending and self.pending.action=="wearableBuy"then self.tabs.select(self.tab);return false end
 self.tab=index;self.tabs.select(index);self.confirmId=nil;self.errorId=nil;self.cameraKey=nil
 self:layoutTiles()
 -- Land on the item worn in this slot, else the first card.
 local worn=Catalog.equippedIn(self.petId,self.ctx.row.equipped,Catalog.Tabs[index].slot);local landing=1
 for i,tile in ipairs(self.tiles)do if tile.id==worn then landing=i end end
 self.index=landing;self:focus(landing,true);return true
end
function Shop:shiftTab(delta)
 local index=math.clamp(self.tab+delta,1,#Catalog.Tabs)
 if index==self.tab then return false end;return self:setTab(index)
end

-- A / Enter / pane button. Buying needs one confirmation within 3 s.
function Shop:act()
 local id=self:focusedId();if not id then return false end
 -- An equip in flight never blocks the next choice; a buy does.
 if self.pending and self.pending.action~="wearableEquip"then return false end
 local item=Catalog.item(self.petId,id);local status=Shop.status(self.petId,id,self.ctx)
 local opId=game:GetService("HttpService"):GenerateGUID(false)
 if status.kind=="owned"or status.kind=="equipped"then
  -- QA Q2.4: optimistic. The pet wears it (or takes it off) at once; the save runs in
  -- the background and only a refusal puts the previous look back, with a toast.
  self.equips=self.equips or {}
  if #self.equips==0 or self.confirmed==nil then self.confirmed=table.clone(self.ctx.row.equipped or {})end
  local wear=if status.kind=="owned"then id else false
  self.pending={id=opId,action="wearableEquip",petId=self.petId,slot=item.slot,itemId=id,wear=wear}
  table.insert(self.equips,self.pending)
  self.ctx.row={owned=self.ctx.row.owned,equipped=Shop.replayEquips(self.petId,self.confirmed,self.equips)}
  self.errorId,self.errorText=nil,nil
  if self.callbacks.equip then self.callbacks.equip(self.pending)end
  self:refresh();return true
 elseif status.kind=="buy"then
  if self.pending then return false end -- let an equip's save land first
  if self.confirmId==id and os.clock()<self.confirmUntil then
   self.confirmId=nil
   self.pending={id=opId,action="wearableBuy",petId=self.petId,itemId=id,price=status.price}
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

local Reasons={NeedStars="shop.reason.needStars",Busy="shop.reason.busy",Throttled="shop.reason.throttled",NotOwned="shop.reason.notOwned",
 PriceChanged="shop.reason.priceChanged",Retrying="shop.reason.retrying"}
function Shop:result(message)
 if type(message)~="table"then return false end
 -- Equips: any in-flight order (an earlier one superseded by a quicker second tap still
 -- reports, and its save counts).
 local index=nil
 for i,order in ipairs(self.equips or {})do if order.id==message.id then index=i end end
 if index then
  if message.status=="Retrying"then return false end
  local order=table.remove(self.equips,index)
  local latest=index>#self.equips -- nothing newer was tapped after it
  if self.pending==order then self.pending=self.equips[#self.equips]end
  if message.status=="Saved"then
   if order.petId==self.petId then self.confirmed=Shop.applyEquip(order.petId,self.confirmed,order.itemId,order.wear)end
   if latest then self.errorId,self.errorText=nil,nil end
  else
   -- Roll back this change only: the confirmed look with the newer equips still on top.
   self.errorId,self.errorText,self.errorFit=order.itemId,UICopy.get(Reasons[message.reason]or "shop.failed.applied"),nil
   if self.callbacks.rolledBack then self.callbacks.rolledBack(order)
   else self.toaster=self.toaster or Kit.toaster(self.host);self.toaster.show(UICopy.get("shop.rolledBack"))end
  end
  self.ctx.row={owned=self.ctx.row.owned,equipped=Shop.replayEquips(self.petId,self.confirmed,self.equips)}
  if self.visible then self:refresh()end;return true
 end
 if not self.pending or self.pending.action=="wearableEquip"or message.id~=self.pending.id then return false end
 if message.status=="Retrying"then return false end
 local order=self.pending;self.pending=nil
 if message.status~="Saved"then
  self.errorId,self.errorText,self.errorFit=order.itemId,UICopy.get(Reasons[message.reason]or "shop.failed.saved"),nil
  if message.reason=="NeedStars"then
   local item=Catalog.item(order.petId or self.petId,order.itemId)
   self.errorFit=UICopy.starsShort(if item and item.price then item.price-(self.ctx.wallet or 0)else nil);self.errorText=self.errorFit[1]
  end
 else self.errorId,self.errorText=nil,nil;if self.callbacks.done then self.callbacks.done(order)end end
 self:refresh();return true
end

function Shop:isOpen()return self.visible end
function Shop:open(petId,ctx)
 self.petId=if petId and Catalog.hasItems(petId)then petId else "pip"
 if ctx then self:setContext(ctx)end
 self.visible=true;self.root.Visible=true;self.confirmId,self.errorId=nil,nil
 Kit.shadeOpen(self,self.shade,function(covered)self.root.Visible=not covered end)
 self:fit(self.host.AbsoluteSize)
 if self.visual and self.visualPet~=self.petId then self.visual:destroy();self.visual=nil end
 self:setTab(self.tab)
 -- QA Q2.2: in from the right like the Pets page (Reduced Motion cuts); Back is a cut
 -- to the screen underneath, which slides back in from the left.
 Kit.slideIn(self.body,Kit.SlideOffset,Kit.headerSkip(self.header))
 if self.clock then self.clock:Disconnect()end
 self.clock=RunService.RenderStepped:Connect(function(dt)
  if self.visible then self:pumpPreviews()end
  local v=self.visual;if not self.visible or not v or v.destroyed then return end
  if GuiService.ReducedMotionEnabled then return end
  v.cosmeticTime=os.clock();v:update(math.min(dt,.1))
 end)
 self.sizeConnection=self.sizeConnection or self.host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.visible then self:fit(self.host.AbsoluteSize)end end)
end
function Shop:back()if self.callbacks.back then self.callbacks.back()else self:close()end end
function Shop:close()
 self.visible=false;self.root.Visible=false;Kit.shadeClose(self);if self.ring then self.ring.hide()end;self.confirmId=nil
 if self.clock then self.clock:Disconnect();self.clock=nil end
 if self.visual then self.visual:destroy();self.visual=nil end
 self:clearPreviews()
end
function Shop:destroy()self:close();if self.sizeConnection then self.sizeConnection:Disconnect()end;self.root:Destroy();self.shade:Destroy()end
return Shop
