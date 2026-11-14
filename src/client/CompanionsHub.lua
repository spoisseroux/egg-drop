-- Companions hub (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 1) and its Pets selector.
-- Opened from the Care Cradle and the garden machine hub's Companions tile. A pinned
-- pet pane (who am I dressing) and three large rows: Pets, Wardrobe, Customize (QA
-- 2026-11-13 Q5: the Collection book moved to the machine hub). The Pets
-- selector is the Wardrobe layout with pets as the items; receipts ("Use now" on a
-- hatched material, toy, feature or jar) land on it in assign mode.
-- Focus is owned here (as in WardrobeShop): arrows / WASD / d-pad move, A / Enter
-- acts, B / Backspace goes up one level. Touch: the first tap on a pet card selects
-- it; the pane button (or a second tap) acts. Rows open on the first tap.
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local TextService=game:GetService("TextService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Pets=require(Shared.PetCatalog)
local Eggs=require(Shared.EggCatalog)
local CharmCatalog=require(Shared.PetCharmCatalog)
local MaterialCatalog=require(Shared.MaterialCatalog)
local ToyCatalog=require(Shared.ToyCatalog)
local WearableCatalog=require(Shared.WearableCatalog)
local Kit=require(script.Parent.DeckKit)
local UICopy=require(Shared.UICopy)
local Factory=require(script.Parent.PetFactory)
local Bounds=require(script.Parent.PetRigBounds)
local BondPips=require(script.Parent.BondPips)
local Hub={}
Hub.__index=Hub
Hub.Size=Vector2.new(848,608)
Hub.Rows=table.freeze({
 table.freeze({id="pets",icon="paw",name="Pets",line="Choose who follows you around the garden"}),
 table.freeze({id="wardrobe",icon="shirt",name="Wardrobe",line="Hats, shirts and more, bought with Stars"}),
 table.freeze({id="customize",icon="wand",name="Customize",line="Hue, charm, materials and toys"}),
})
-- Row rects (the three-row sizes from before the play-forever build): desktop rows
-- 140 high on a 156 pitch beside the pet pane; phone rows 64 high on a 73 pitch.
Hub.RowPitch={regular=156,regularH=140,phone=73,phoneH=64}
Hub.DefaultRow=3 -- Customize the first time (section 1, Behaviour).

-- Pure: hatched items waiting to be used (one per pending receipt kind).
function Hub.newItems(state)
 state=state or {}
 local n=0
 for _,key in ipairs({"pendingHueResult","pendingMaterialResult","pendingToyResult","pendingFeatureResult"})do if state[key]~=nil then n+=1 end end
 return n
end
-- Pure: wearables owned for one pet.
function Hub.ownedCount(state,petId)
 local row=state and state.petWearables and state.petWearables[petId]
 return if row and type(row.owned)=="table"then #row.owned else 0
end
-- Pure: a row's status line and tone ({text, tone, dot}).
function Hub.status(rowId,ctx)
 ctx=ctx or {}
 if rowId=="pets"then return{text=string.upper(ctx.petName or ""),tone="dim"}end
 if rowId=="wardrobe"then return{text=tostring(ctx.owned or 0).." OWNED",tone="dim"}end
 if rowId=="customize"then
  local n=ctx.newItems or 0
  if n>0 then return{text=n..(if n==1 then " NEW ITEM"else " NEW ITEMS"),tone="stars",dot=true}end
  return{text="",tone="dim"}
 end
 return{text="",tone="dim"}
end
-- Pure: the read-only pane rows (Wearing, Charm, Finish, Toy) for one appearance.
function Hub.summary(petId,appearance)
 appearance=appearance or {}
 local worn,seen={},{}
 for _,id in pairs(appearance.wearables or {})do
  if type(id)=="string"and not seen[id]then seen[id]=true
   local item=WearableCatalog.item(petId,id);if item then table.insert(worn,item.name)end
  end
 end
 table.sort(worn)
 local wearing=if #worn==0 then UICopy.get("companions.wearing.none")elseif #worn==1 then worn[1]else worn[1].." +"..(#worn-1)
 local charm=if appearance.charmVisible==false then "None"else(CharmCatalog.ById[CharmCatalog.renderShape(appearance.charmShape or CharmCatalog.Default)]or CharmCatalog.ById[CharmCatalog.Default]).name
 local finish=MaterialCatalog.ById[appearance.finish or MaterialCatalog.Default]or MaterialCatalog.ById[MaterialCatalog.Default]
 local toy=ToyCatalog.ById[appearance.toyId or ToyCatalog.Default]or ToyCatalog.ById[ToyCatalog.Default]
 return{{"Wearing",wearing},{"Charm",charm},{"Finish",finish.name},{"Toy",toy.name}}
end
-- Pure: owned pets as selector cards, in catalog order. Only pets that can be shown
-- (Pets.isActive: a rig in this build) are listed, so an owned pet whose rig is not in
-- the build (slice E: the second pet behind its flag) never becomes the companion.
function Hub.petCards(state,activeId)
 local cards={}
 for _,pet in ipairs(Pets.collection)do
  if Pets.isActive(pet)and Eggs.isOwned(state and state.inventoryMask or 0,pet.id)then table.insert(cards,{id=pet.id,name=pet.name,following=pet.id==activeId})end
 end
 return cards
end
-- Pure (slice E): the pet the hub shows when no companion is set: the first owned
-- active pet, else the first active pet (a fresh save's pane still has a pet to draw).
function Hub.firstOwned(state)
 local mask=state and state.inventoryMask or 0
 for _,pet in ipairs(Pets.active)do if Eggs.isOwned(mask,pet.id)then return pet.id end end
 return Pets.active[1]and Pets.active[1].id or Pets[1].id
end
-- Pure: focus movement. Hub rows are one column; the selector is a cols-wide grid.
function Hub.step(index,dx,dy,count,cols)
 cols=math.max(1,cols or 1)
 if count<1 then return 1 end
 local col,row=(index-1)%cols,math.floor((index-1)/cols)
 local rows=math.ceil(count/cols)
 col=math.clamp(col+dx,0,cols-1);row=math.clamp(row+dy,0,rows-1)
 return math.clamp(row*cols+col+1,1,count)
end
-- Pure: what Back does from a page ("hub", "close", or "cancel" for assign mode).
function Hub.backTarget(page,assigning)
 if assigning then return "cancel"end
 if page=="pets"then return "hub"end
 return "close"
end

local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
local function colorOf(role)
 if role=="accent"or role=="selected"or role=="raised"or role=="well"or role=="panel"then return Kit.color(role)end
 return Kit.Color[role]or Kit.Color.text
end

-- host: a full-screen Frame. callbacks: open(rowId, petId) -> bool, follow(petId) -> bool,
-- appearance(petId) -> appearance, back(), closed(reason).
function Hub.new(host,callbacks)
 local self=setmetatable({host=host,callbacks=callbacks or {},page="hub",rowIndex=Hub.DefaultRow,cardIndex=1,visible=false,
  ctx={wallet=0,state={},activeId=nil},assign=nil,pendingFollow=nil},Hub)
 -- QA Q2.1: one full-screen shade (Kit.modalShade) beside the panel, never its parent,
 -- so the shade can reach under the top bar while the panel keeps the safe area.
 local shade=Kit.modalShade(host,"CompanionsShade",30);self.shade=shade
 local root=Kit.frame(host,"CompanionsHub","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
 root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.ClipsDescendants=true;root.ZIndex=31;root.Visible=false;self.rootStroke=Kit.stroke(root)
 local gradient=Kit.frame(root,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 self.gradient=gradient;self.root=root
 self.scale=Kit.node("UIScale",root,{Scale=1})
 return self
end

function Hub:petId()
 if self.focusPet then return self.focusPet end
 return self:activePet()
end
-- The companion, or the first owned active pet while none is set (slice E).
function Hub:activePet()return self.ctx.activeId or Hub.firstOwned(self.ctx.state)end
function Hub:appearanceOf(petId)
 return table.clone(self.callbacks.appearance and self.callbacks.appearance(petId)or {})
end
function Hub:cards()return Hub.petCards(self.ctx.state,self.ctx.activeId)end
function Hub:statusCtx()
 local petId=self:activePet();local pet=Pets.byId[petId]
 return{petName=pet and pet.name or "",owned=Hub.ownedCount(self.ctx.state,petId),newItems=Hub.newItems(self.ctx.state)}
end

-- Preview well: a ViewportFrame with the pet (same set-up as the Wardrobe pane).
function Hub:buildWell(parent,x,y,w,h)
 local well=Kit.frame(parent,"PreviewWell","well",UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),12);Kit.stroke(well)
 local viewport=Kit.node("ViewportFrame",well,{Name="PetPreview",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=well.ZIndex+1,
  Ambient=Color3.fromRGB(175,184,183),LightColor=Color3.fromRGB(255,250,231),LightDirection=Vector3.new(-1,-1.4,-3)})
 local world=Kit.node("WorldModel",viewport,{});local camera=Kit.node("Camera",viewport,{FieldOfView=30})
 viewport.CurrentCamera=camera
 viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
  if self.viewport==viewport and self.visual and self.visualPet then self.cameraKey=nil;self:paintPreview(self.visualPet)end
 end)
 if self.visual then self.visual:destroy();self.visual=nil end
 self.viewport,self.world,self.camera,self.cameraKey=viewport,world,camera,nil
 return well
end
function Hub:paintPreview(petId)
 if not self.world or not self.visible then return end
 local appearance=self:appearanceOf(petId)
 if not self.visual or self.visualPet~=petId then
  if self.visual then self.visual:destroy()end
  local pet=Pets.byId[petId];if not pet then return end
  self.visual=Factory.new(self.world,Vector3.zero,pet,nil,appearance);self.visualPet=petId;self.cameraKey=nil
 end
 self.visual.yaw=-.25;self.visual.reducedEffects=GuiService.ReducedMotionEnabled
 if self.visual.applyAppearance then self.visual:applyAppearance(appearance)end
 self.visual.poseDirty=true;self.visual:update(0)
 local v=self.visual
 local key=tostring(self.viewport.AbsoluteSize)..":"..tostring(v.rigRevision or 0)
 if self.cameraKey~=key then
  self.cameraKey=key
  local box,size=Bounds.get(v);local a=math.max(.1,self.viewport.AbsoluteSize.X/math.max(1,self.viewport.AbsoluteSize.Y));local half=math.tan(math.rad(self.camera.FieldOfView/2))
  local distance=math.max(size.Y*.5/half,size.X*.5/(half*a))+size.Z*.5+.3
  self.camera.CFrame=CFrame.lookAt(box.Position+Vector3.new(0,.12,distance*1.10),box.Position)
 end
end

local function chevron(parent,x,y,size)
 local c=Kit.icon(parent,"chevron",size,"soft");c.AnchorPoint=Vector2.new(.5,.5);c.Position=UDim2.fromOffset(x,y);return c
end
-- Icon disc: the focused row's disc turns accent with an ink icon.
local function disc(parent,icon,x,y,size)
 local d=Kit.frame(parent,"IconDisc",nil,UDim2.fromOffset(x,y),UDim2.fromOffset(size,size),999);d.BackgroundTransparency=0
 d.BackgroundColor3=Kit.Color.ink
 local i=Kit.icon(d,icon,math.floor(size*.42),"text");i.AnchorPoint=Vector2.new(.5,.5);i.Position=UDim2.fromScale(.5,.5)
 return d,i
end

function Hub:buildHints(content,pairs_,promise)
 local hints=Kit.frame(content,"Hints",nil,UDim2.fromOffset(24,566),UDim2.fromOffset(560,24))
 local x=0
 for _,pair in ipairs(pairs_)do
  local g=Kit.glyph(hints,pair[1],false,22,true);g.Position=UDim2.fromOffset(x,1)
  local t=txt(hints,"Small",pair[2],"soft",x+28,0,120,24);t.AutomaticSize=Enum.AutomaticSize.X
  x+=28+TextService:GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
 end
 txt(content,"Small",promise,"dim",424,566,400,24,{Name="Promise",TextXAlignment=Enum.TextXAlignment.Right})
end

function Hub:build(view)
 if self.content then self.content:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 if self.visual then self.visual:destroy();self.visual=nil end
 self.world=nil
 self.view=view;self.key=(if view then string.format("%dx%d",view.W,view.H)else "regular")..":"..self.page..":"..tostring(self.assign~=nil)
 local root=self.root;local phone=view~=nil
 root.BackgroundTransparency=if phone then 1 else 0;self.gradient.Visible=not phone;self.rootStroke.Enabled=not phone;root.ClipsDescendants=not phone
 Kit.setShadeAlpha(self.shade,Kit.ShadeAlpha) -- R3.1: one full-screen shade, phones too
 local W=if phone then view.W else 848
 local H=if phone then view.H else 608
 local content=Kit.frame(root,"Content",nil,UDim2.new(),UDim2.fromOffset(W,H));content.ZIndex=root.ZIndex+2
 self.content=content
 Kit.halftone(content,"companions",phone)
 local body=content
 if phone then
  local sheet=Kit.sheet(content,W,H)
  body=Kit.frame(content,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 end
 self.body=body
 local title=if self.page=="pets"then "Pets"else "Companions"
 self.header=Kit.header(body,{title=title,eyebrow=if self.page=="pets"then "Companions"else "Garden",tint="companions",compact=phone,width=W,left=if phone then view.hx else 24,onBack=function()self:back()end})
 self.header.root.Name="HubHeader"
 if self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
 self.rows,self.cardButtons={},{}
 if self.page=="pets"then self:buildSelector(body,W,H,phone)else self:buildHub(body,W,H,phone)end
 if not phone then
  if self.page=="pets"then self:buildHints(content,{{"+","Browse"},{"A",if self.assign then "Choose"else "Follow"},{"B","Back"}},"Your pet follows you around the garden.")
  else self:buildHints(content,{{"+","Browse"},{"A","Open"},{"B","Back"}},"Changes save as you make them.")end
 end
 self.ring=Kit.focusRing(self.root)
 root:SetAttribute("Page",self.page);root:SetAttribute("Assigning",self.assign~=nil)
 -- Hub to child: the content slides in 24 px from the right (160 ms); Reduced Motion cuts.
 -- Wardrobe and Customize reuse this move (Kit.slideIn).
 if self.slideFrom then Kit.slideIn(body,self.slideFrom,Kit.headerSkip(self.header))end
 self.slideFrom=nil
end

function Hub:buildHub(body,W,H,phone)
 local petId=self:activePet();local pet=Pets.byId[petId]
 local pane=Kit.card(body,"PetPane",nil,{pad=16,seam=true})
 -- Slice F: bond pips with the pet's name (nil while bond data is not in the snapshot).
 local bond=BondPips.info(self.ctx.state and self.ctx.state.bond,petId)
 self.pips=nil
 if phone then
  local ph=H-64-20
  pane.Position=UDim2.fromOffset(20,64);pane.Size=UDim2.fromOffset(200,ph)
  self:buildWell(pane,12,12,176,math.max(60,ph-80))
  -- Phone: the pips sit beside the name (no room under it above "Following you").
  local pipsW=if bond then BondPips.extent(BondPips.Size.compact)+8 else 0
  self.petName=txt(pane,"Title",pet and pet.name or "","text",12,ph-62,176-pipsW,24,{TextSize=18,TextTruncate=Enum.TextTruncate.AtEnd,AutoLocalize=false})
  self.following=txt(pane,"Small","Following you","soft",12,ph-34,176,18,{TextSize=12})
  if bond then
   self.pips=BondPips.new(pane,true);self.pips.root.Position=UDim2.fromOffset(12+176-self.pips.width,ph-62+2);self.pips.set(bond)
  end
 else
  pane.Position=UDim2.fromOffset(24,84);pane.Size=UDim2.fromOffset(328,452)
  -- Desktop: the pips go under the name; the preview well gives up their 22 px.
  local lift=if bond then 22 else 0
  self:buildWell(pane,16,16,296,248-lift)
  self.petName=txt(pane,"Title",pet and pet.name or "","text",16,276-lift,190,32,{TextSize=24,TextTruncate=Enum.TextTruncate.AtEnd,AutoLocalize=false})
  local chip=Kit.chip(pane,"Following",nil,26);chip.root.AnchorPoint=Vector2.new(1,.5);chip.root.Position=UDim2.fromOffset(312,292-lift)
  Kit.paint(chip.label,"TextColor3","accent");self.followChip=chip
  if bond then
   self.pips=BondPips.new(pane,false);self.pips.root.Position=UDim2.fromOffset(16,288);self.pips.set(bond)
   self.pipsLabel=txt(pane,"Small",BondPips.label(bond),"soft",16+self.pips.width+10,286,296-self.pips.width-10,20,{Name="BondLabel",TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd})
  end
  self.summaryLabels={}
  for i,pair in ipairs(Hub.summary(petId,self:appearanceOf(petId)))do
   local y=318+(i-1)*28
   local name=txt(pane,"Body",pair[1],"soft",16,y,120,26,{TextSize=15})
   local value=txt(pane,"Body",pair[2],"text",136,y,176,26,{Name="Value_"..pair[1],TextSize=15,TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd})
   if i<4 then local hair=Kit.frame(pane,"Hairline",nil,UDim2.fromOffset(16,y+27),UDim2.fromOffset(296,1));hair.BackgroundTransparency=.93;hair.BackgroundColor3=Color3.new(1,1,1)end
   self.summaryLabels[pair[1]]=value;local _=name
  end
 end
 local ctx=self:statusCtx()
 for index,row in ipairs(Hub.Rows)do
  local P=Hub.RowPitch
  local x,y,w,h=368,84+(index-1)*P.regular,456,P.regularH
  if phone then x,y,w,h=232,64+(index-1)*P.phone,W-20-232,P.phoneH end
  -- T2: pressable row with a lip (4 px in the 16 px desktop gap, 3 px in the 9 px phone gap).
  local button,tileState=Kit.tile(body,"Row_"..row.id,{selectable=false,radius=if phone then 12 else 14,compact=phone,
   position=UDim2.fromOffset(x,y),size=UDim2.fromOffset(w,h)})
  local stroke=tileState.stroke
  button:SetAttribute("AccessibleLabel",row.name..", "..row.line)
  local discSize=if phone then 44 else 72
  local d,icon=disc(button,row.icon,if phone then 16 else 24,(h-discSize)/2,discSize)
  local tx=if phone then 72 else 116
  local name,line,status
  local s=Hub.status(row.id,ctx)
  if phone then
   name=txt(button,"Strong",row.name,"text",tx,10,w-tx-160,22,{TextSize=16})
   line=txt(button,"Small",row.line,"soft",tx,34,w-tx-170,18,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
   status=txt(button,"Label",s.text,s.tone,w-190,0,150,h,{Name="Status",TextSize=12,TextXAlignment=Enum.TextXAlignment.Right})
  else
   name=txt(button,"Heading",row.name,"text",tx,32,w-tx-56,28,{TextSize=22})
   line=txt(button,"Body",row.line,"soft",tx,62,w-tx-56,22,{TextSize=15,TextTruncate=Enum.TextTruncate.AtEnd})
   status=txt(button,"Label",s.text,s.tone,tx+(if s.dot then 14 else 0),90,w-tx-70,18,{Name="Status",TextSize=12})
  end
  Kit.paint(status,"TextColor3",function()return colorOf(s.tone)end)
  if row.id=="pets"then Kit.fixedText(status)end -- the pet's name (stays as named)
  local dot
  if s.dot then
   dot=Kit.frame(button,"NewDot","stars",UDim2.new(),UDim2.fromOffset(8,8),999)
   if phone then
    local tw=TextService:GetTextSize(status.Text,12,Enum.Font.BuilderSansBold,Vector2.new(500,30)).X
    dot.Position=UDim2.fromOffset(w-40-tw-14,h/2-4)
   else dot.Position=UDim2.fromOffset(tx,95)end
  end
  chevron(button,w-(if phone then 26 else 36),h/2,if phone then 16 else 20)
  self.rows[index]={id=row.id,button=button,stroke=stroke,disc=d,icon=icon,name=name,line=line,status=status,dot=dot}
  button.Activated:Connect(function()self:focusRow(index);self:act()end)
 end
end

function Hub:buildSelector(body,W,H,phone)
 local cards=self:cards()
 local pw,ph,px,py,gx,gy,gw,gh,cardW,cardH,cols,gap
 if phone then
  pw=232;ph=H-84;px,py=W-20-pw,64;gx,gy=20,64;gw=W-52-pw;gh=H-84
  cols=if gw>=420 then 2 else 1;gap=8;cardH=64;cardW=math.floor((gw-6-(cols-1)*gap)/cols)
 else
  pw,ph,px,py=328,452,24,84;gx,gy,gw,gh=368,84,456,452;cols=2;gap=12;cardH=96;cardW=math.floor((gw-6-gap)/2)
 end
 self.cols=cols
 local pane=Kit.card(body,"PetPane",nil,{pad=16,seam=true});pane.Position=UDim2.fromOffset(px,py);pane.Size=UDim2.fromOffset(pw,ph)
 local pad=if phone then 12 else 16
 local actionH=if phone then 44 else 56
 local wellH=math.max(60,ph-pad*2-actionH-(if phone then 56 else 92))
 self:buildWell(pane,pad,pad,pw-pad*2,wellH)
 local y=pad+wellH+(if phone then 6 else 12)
 -- Slice F: the focused pet's bond pips sit at the right of its name.
 local hasBond=BondPips.info(self.ctx.state and self.ctx.state.bond,self:activePet())~=nil
 local pipsW=if hasBond then BondPips.extent(if phone then BondPips.Size.compact else BondPips.Size.regular)+8 else 0
 self.paneName=txt(pane,"Title","","text",pad,y,pw-pad*2-pipsW,if phone then 22 else 30,{TextSize=if phone then 18 else 24,TextTruncate=Enum.TextTruncate.AtEnd,AutoLocalize=false})
 self.pips=nil
 if hasBond then
  self.pips=BondPips.new(pane,phone);self.pips.root.Position=UDim2.fromOffset(pw-pad-self.pips.width,y+(if phone then 1 else 4))
 end
 y+=if phone then 22 else 34
 self.paneLine=txt(pane,"Small","","soft",pad,y,pw-pad*2,18,{TextSize=if phone then 12 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 local action,state=Kit.button(pane,"Action",{variant="primary",text="Follow",glyph="A",size=Vector2.new(pw-pad*2,actionH),textSize=if phone then 16 else nil,selectable=false})
 action.Position=UDim2.fromOffset(pad,ph-pad-actionH);self.action,self.actionState=action,state
 action.Activated:Connect(function()self:act()end)
 local list=Kit.node("ScrollingFrame",body,{Name="Grid",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(gx,gy),
  Size=UDim2.fromOffset(gw,gh),ScrollBarThickness=4,ZIndex=body.ZIndex+1,Selectable=false,ScrollingDirection=Enum.ScrollingDirection.Y,
  ScrollBarImageColor3=Color3.new(1,1,1),ScrollBarImageTransparency=.6})
 self.list=list
 for index,card in ipairs(cards)do
  local col,row=(index-1)%cols,math.floor((index-1)/cols)
  -- T2: pressable card with a lip inside the 12 / 8 px grid gap.
  local b,tileState=Kit.tile(list,"Pet_"..card.id,{selectable=false,radius=12,compact=phone,
   position=UDim2.fromOffset(3+col*(cardW+gap),3+row*(cardH+gap)),size=UDim2.fromOffset(cardW,cardH)})
  local stroke=tileState.stroke
  b:SetAttribute("AccessibleLabel",card.name);b:SetAttribute("PetId",card.id)
  local side=cardH-20
  local swatch=Kit.frame(b,"Swatch","well",UDim2.fromOffset(10,10),UDim2.fromOffset(side,side),10);Kit.stroke(swatch)
  local paw=Kit.icon(swatch,"paw",math.floor(side*.5),"soft");paw.AnchorPoint=Vector2.new(.5,.5);paw.Position=UDim2.fromScale(.5,.5)
  local tx=10+side+12
  local nameLabel=txt(b,"Name",card.name,"text",tx,cardH/2-20,cardW-tx-8,20,{TextSize=if phone then 14 else 16,TextTruncate=Enum.TextTruncate.AtEnd,AutoLocalize=false})
  local status=txt(b,"Label","","soft",tx,cardH/2+2,cardW-tx-8,18,{Name="Status",TextSize=12})
  self.cardButtons[index]={id=card.id,button=b,stroke=stroke,name=nameLabel,status=status}
  b.Activated:Connect(function()
   if self.cardIndex==index then self:act()else self:focusCard(index);Kit.boing(b)end
  end)
 end
 list.CanvasSize=UDim2.fromOffset(0,math.ceil(#cards/cols)*(cardH+gap)-gap+6)
 if #cards==0 then txt(list,"Body",UICopy.get("e2.hub.none"),"soft",3,3,gw-6,48,{TextWrapped=true})end
end

function Hub:fit(size)
 if Kit.compactRule(size.X,size.Y)then
  local _,kh=Kit.keepOut();local top=kh+2
  local view={phone=true,W=math.floor(size.X),H=math.floor(size.Y)-top,hx=24}
  self.root.AnchorPoint=Vector2.zero;self.root.Position=UDim2.fromOffset(0,top);self.root.Size=UDim2.fromOffset(view.W,view.H);self.scale.Scale=1
  local key=string.format("%dx%d",view.W,view.H)..":"..self.page..":"..tostring(self.assign~=nil)
  if self.key~=key then self:build(view);self:refocus()end
  return
 end
 local key="regular:"..self.page..":"..tostring(self.assign~=nil)
 self.root.AnchorPoint=Vector2.new(.5,.5);self.root.Size=UDim2.fromOffset(848,608)
 if self.key~=key then self:build(nil);self:refocus()end
 self.root.Position=UDim2.fromScale(.5,.5)
 self.scale.Scale=math.max(.1,math.min(1.2,(size.X-24)/848,(size.Y-24)/608))
end

function Hub:refocus()
 if self.page=="pets"then self:focusCard(self.cardIndex,true)else self:focusRow(self.rowIndex,true)end
end
function Hub:setContext(ctx)
 if ctx.wallet then self.ctx.wallet=ctx.wallet end
 if ctx.state then self.ctx.state=ctx.state end
 if ctx.activeId~=nil then
  if self.pendingFollow and ctx.activeId==self.pendingFollow then self.pendingFollow=nil end
  self.ctx.activeId=ctx.activeId
 end
 if self.visible then
  if self.header and self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
  -- Status lines and owned pets can change shape: rebuild the current page.
  self.key=nil;self:fit(self.host.AbsoluteSize)
 end
end

local function paintRowFocus(entry,focused)
 Kit.paint(entry.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised")end)
 entry.stroke.Thickness=if focused then 2 else 1;entry.stroke.Transparency=if focused then 0 else .86
 Kit.paint(entry.stroke,"Color",function()return if focused then Kit.color("accent")else Color3.new(1,1,1)end)
end
function Hub:refresh()
 if self.page=="pets"then
  local cards=self:cards()
  self.cardIndex=math.clamp(self.cardIndex,1,math.max(1,#cards))
  for index,entry in ipairs(self.cardButtons)do
   local card=cards[index]
   local focused=index==self.cardIndex
   paintRowFocus(entry,focused)
   local following=card~=nil and card.following==true
   local text=if following then "FOLLOWING"elseif self.assign then "CHOOSE"else "FOLLOW"
   local tone=if following then "accent"else "soft"
   if self.pendingFollow==entry.id then text,tone="SAVING…","soft"end
   entry.status.Text=text;Kit.paint(entry.status,"TextColor3",function()return colorOf(tone)end)
   entry.button:SetAttribute("Following",card~=nil and card.following==true)
  end
  self:paintSelectorPane()
 else
  self.rowIndex=math.clamp(self.rowIndex,1,#Hub.Rows)
  for index,entry in ipairs(self.rows)do
   local focused=index==self.rowIndex
   paintRowFocus(entry,focused)
   Kit.paint(entry.disc,"BackgroundColor3",function()return if focused then Kit.color("accent")else Kit.Color.ink end)
   Kit.tintIcon(entry.icon,if focused then "ink"else "text")
  end
  self.focusPet=nil
  if self.visible then self:paintPreview(self:activePet())end
 end
 self.root:SetAttribute("FocusedRow",if self.page=="hub"then Hub.Rows[self.rowIndex].id else nil)
end
function Hub:paintSelectorPane()
 local entry=self.cardButtons[self.cardIndex]
 if not entry then
  self.paneName.Text="";self.paneLine.Text="";self.action.Visible=false
  if self.pips then self.pips.set(nil)end
  return
 end
 self.focusPet=entry.id
 if self.pips then self.pips.set(BondPips.info(self.ctx.state and self.ctx.state.bond,entry.id))end
 local pet=Pets.byId[entry.id];local following=entry.id==self.ctx.activeId
 self.paneName.Text=pet.name
 self.action.Visible=true
 if self.assign then
  self.paneLine.Text=self.assign.line or("Use it on "..pet.name)
  Kit.setText(self.action,self.assign.button or "Choose");Kit.setEnabled(self.action,true)
 elseif self.pendingFollow then
  self.paneLine.Text="Saving…";Kit.setText(self.action,"Saving…");Kit.setEnabled(self.action,false)
 elseif following then
  self.paneLine.Text="Following you around the garden";Kit.setText(self.action,"Following");Kit.setEnabled(self.action,false)
 else
  self.paneLine.Text="Tap Follow to bring "..pet.name.." along";Kit.setText(self.action,"Follow");Kit.setEnabled(self.action,true)
 end
 if self.view then Kit.setGlyphVisible(self.action,not Kit.lastInputTouch())end
 self.root:SetAttribute("FocusedPet",entry.id)
 if self.visible then self:paintPreview(entry.id)end
end

function Hub:focusRow(index,instant)
 self.rowIndex=math.clamp(index,1,#Hub.Rows);self:refresh()
 local entry=self.rows[self.rowIndex]
 if entry and self.ring then self.ring.attach(entry.button,if self.view then 12 else 14)end
 if instant and self.ring then self.ring.root.Visible=self.visible and self.ring.root.Visible end
end
function Hub:focusCard(index,instant)
 local count=#self.cardButtons
 if count==0 then if self.ring then self.ring.hide()end;self:refresh();return end
 self.cardIndex=math.clamp(index,1,count);self:refresh()
 local entry=self.cardButtons[self.cardIndex]
 if self.list and entry then
  local top=entry.button.Position.Y.Offset;local bottom=top+entry.button.Size.Y.Offset
  local view=self.list.AbsoluteWindowSize.Y;if view<=0 then view=self.list.Size.Y.Offset end
  local y=self.list.CanvasPosition.Y
  if top-8<y then y=top-8 elseif bottom+8>y+view then y=bottom+8-view end
  self.list.CanvasPosition=Vector2.new(0,math.clamp(y,0,math.max(0,self.list.CanvasSize.Y.Offset-view)))
 end
 if entry and self.ring then self.ring.attach(entry.button,12)end
 if instant and self.ring then self.ring.root.Visible=self.visible and self.ring.root.Visible end
end
function Hub:move(dx,dy)
 if self.page=="pets"then
  local nextIndex=Hub.step(self.cardIndex,dx,dy,#self.cardButtons,self.cols)
  if nextIndex==self.cardIndex then return false end
  self:focusCard(nextIndex);return true
 end
 local nextIndex=Hub.step(self.rowIndex,0,dy,#Hub.Rows,1)
 if nextIndex==self.rowIndex then return false end
 self:focusRow(nextIndex);return true
end

function Hub:setPage(page,instant)
 if page==self.page then return end
 self.slideFrom=if page=="pets"then 24 else -24
 self.page=page;self.key=nil
 if page=="pets"then
  local cards=self:cards();self.cardIndex=1
  for i,card in ipairs(cards)do if card.following then self.cardIndex=i end end
 end
 self:fit(self.host.AbsoluteSize)
 if page=="pets"then self:focusCard(self.cardIndex,instant)else self:focusRow(self.rowIndex,instant)end
end

-- A / Enter / tap: open the focused row, or follow / choose the focused pet.
function Hub:act()
 if not self.visible then return false end
 if self.page=="hub"then
  local row=Hub.Rows[self.rowIndex];if not row then return false end
  self.lastRow=self.rowIndex
  if row.id=="pets"then self:setPage("pets");return true end
  if self.callbacks.open then return self.callbacks.open(row.id,self:activePet())==true end
  return false
 end
 local entry=self.cardButtons[self.cardIndex];if not entry then return false end
 if self.assign then
  local assign=self.assign;self.assign=nil
  local ok=assign.choose and assign.choose(entry.id)==true
  self:close("assigned");return ok
 end
 if self.pendingFollow or entry.id==self.ctx.activeId then return false end
 if self.callbacks.follow and self.callbacks.follow(entry.id)==true then
  self.pendingFollow=entry.id;self:refresh();return true
 end
 return false
end
function Hub:back()
 local target=Hub.backTarget(self.page,self.assign~=nil)
 if target=="cancel"then
  local assign=self.assign;self.assign=nil
  self:close("cancel");if assign and assign.cancel then assign.cancel()end
  return "cancel"
 elseif target=="hub"then self:setPage("hub");return "hub"end
 self:close("back");if self.callbacks.back then self.callbacks.back()end
 return "close"
end
-- Keyboard / gamepad (bound by the caller, as the Wardrobe's ContextAction is).
function Hub:input(key)
 local K=Enum.KeyCode
 if key==K.Left or key==K.A or key==K.DPadLeft then self:move(-1,0)
 elseif key==K.Right or key==K.D or key==K.DPadRight then self:move(1,0)
 elseif key==K.Up or key==K.W or key==K.DPadUp then self:move(0,-1)
 elseif key==K.Down or key==K.S or key==K.DPadDown then self:move(0,1)
 elseif key==K.ButtonB or key==K.Backspace or key==K.Escape then self:back()
 elseif key==K.Return or key==K.KeypadEnter or key==K.Space or key==K.ButtonA then self:act()end
end

function Hub:isOpen()return self.visible end
-- A screen opened over the hub (Wardrobe, the Pets selector over Customize)
-- hides this panel; coming back slides the content in from the left, as Pets -> hub does.
function Hub:setCovered(covered)
 if not self.visible then return end
 self.covered=covered==true
 self.root.Visible=not self.covered
 if self.covered then if self.ring then self.ring.hide()end;return end
 if self.body then Kit.slideIn(self.body,-Kit.SlideOffset,Kit.headerSkip(self.header))end
 self:refocus()
end
-- options: page ("hub" or "pets"), assign = {choose(petId) -> bool, cancel(), line, button}.
function Hub:open(ctx,options)
 options=options or {}
 if ctx then
  if ctx.wallet then self.ctx.wallet=ctx.wallet end
  if ctx.state then self.ctx.state=ctx.state end
  if ctx.activeId~=nil then self.ctx.activeId=ctx.activeId end
 end
 self.assign=options.assign;self.pendingFollow=nil
 self.page=options.page or "hub";self.key=nil;self.slideFrom=nil
 self.rowIndex=self.lastRow or Hub.DefaultRow
 self.visible=true;self.covered=false;self.root.Visible=true
 Kit.shadeOpen(self,self.shade,function(covered)self:setCovered(covered)end)
 if self.page=="pets"then
  self.cardIndex=1;for i,card in ipairs(self:cards())do if card.following then self.cardIndex=i end end
 end
 self:fit(self.host.AbsoluteSize)
 if self.page=="pets"then self:focusCard(self.cardIndex,true)else self:focusRow(self.rowIndex,true)end
 -- Screen in: 160 ms fade plus an 8 px rise (desktop); Reduced Motion is a cut.
 -- Back from a child screen (Customize) slides in from the left instead (QA Q2.2).
 if options.slideFrom and self.body then Kit.slideIn(self.body,options.slideFrom,Kit.headerSkip(self.header))
 elseif not self.view and not Kit.reduced()then
  self.root.Position=UDim2.new(.5,0,.5,8);Kit.tween(self.root,Kit.Motion.screen,{Position=UDim2.fromScale(.5,.5)})
 end
 if self.clock then self.clock:Disconnect()end
 self.clock=RunService.RenderStepped:Connect(function(dt)
  local v=self.visual;if not self.visible or not v or v.destroyed then return end
  if GuiService.ReducedMotionEnabled then return end
  v.cosmeticTime=os.clock();v:update(math.min(dt,.1))
 end)
 self.sizeConnection=self.sizeConnection or self.host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.visible then self:fit(self.host.AbsoluteSize)end end)
 return true
end
function Hub:close(reason)
 if not self.visible then return false end
 self.visible=false;self.covered=false;self.root.Visible=false;Kit.shadeClose(self);if self.ring then self.ring.hide()end
 if self.clock then self.clock:Disconnect();self.clock=nil end
 if self.visual then self.visual:destroy();self.visual=nil end
 if reason~="assigned"and reason~="cancel"then self.assign=nil end
 if self.callbacks.closed then self.callbacks.closed(reason)end
 return true
end
function Hub:destroy()self:close("destroy");if self.sizeConnection then self.sizeConnection:Disconnect()end;self.root:Destroy();self.shade:Destroy()end
return Hub
