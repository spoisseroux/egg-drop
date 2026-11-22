-- Companions hub (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 1) and its Pets selector.
-- Opened from the Care Cradle and the garden machine hub's Companions tile. A pinned
-- pet pane (who am I dressing) and a 2 x 3 grid of tiles: Pets, Stats, Name, Wardrobe, Customize, Toys (QA
-- 2026-11-13 Q5: the Collection book moved to the machine hub; UI-SPEC-v816 3: Toys are
-- their own screen again, Customize keeps Hue, Charm and Material). The Pets
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
local Earned=require(Shared.EarnedPets)
local CharmCatalog=require(Shared.PetCharmCatalog)
local MaterialCatalog=require(Shared.MaterialCatalog)
local ToyCatalog=require(Shared.ToyCatalog)
local WearableCatalog=require(Shared.WearableCatalog)
local Kit=require(script.Parent.DeckKit)
local UICopy=require(Shared.UICopy)
local Factory=require(script.Parent.PetFactory)
local Bounds=require(script.Parent.PetRigBounds)
local BondPips=require(script.Parent.BondPips)
-- v2 pet names: an owned pet shows its chosen name (the species while it has none).
local NameText=require(script.Parent.PetNameText)
-- Spencer 2026-11-20: pet cards show a headshot of the pet instead of the same paw on every card.
local Headshot=require(script.Parent.PetHeadshot)
local Hub={}
Hub.__index=Hub
Hub.Size=Vector2.new(848,608)
-- Spencer 2026-11-20: Stats and Name are their own tiles, not buttons over the preview, so the
-- hub is a 2 x 3 grid (row-major: Pets, Stats / Name, Wardrobe / Customize, Toys).
Hub.Rows=table.freeze({
 table.freeze({id="pets",icon="paw",name="Pets",line="Choose who follows you around the garden"}),
 table.freeze({id="stats",icon="bars",name=UICopy.get("stats.open"),line=UICopy.get("stats.row")}),
 table.freeze({id="name",icon="tag",name=UICopy.get("names.open"),line=UICopy.get("names.row")}),
 table.freeze({id="wardrobe",icon="shirt",name="Wardrobe",line="Hats, shirts and more, bought with Stars"}),
 table.freeze({id="customize",icon="wand",name="Customize",line=UICopy.get("r4.customize.subtitle")}),
 -- v834 phone notes: Toys moved to the bottom (Pets, Wardrobe, Customize, Toys).
 table.freeze({id="toys",icon="toy",name="Toys",line=UICopy.get("r4.customize.toys.row")}),
})
-- Row rects (UI-SPEC-v816 3, four rows): desktop rows 104 high on a 116 pitch beside the
-- pet pane; phone rows 59 high with 7 px gaps, the icon disc 37 (was 44).
Hub.RowPitch={regular=116,regularH=104,phone=66,phoneH=59,phoneMax=59,phoneGap=7,phoneDisc=37} -- (pre-grid; kept for callers)
Hub.Cols=2
Hub.Grid={x=368,y=84,w=456,h=452,gap=12,phoneX=232,phoneY=64,phoneGap=7,disc=56,phoneDisc=37}
Hub.DefaultRow=5 -- Customize the first time (section 1, Behaviour).

-- Pure: the tiles this hub shows (Stats / Name drop out when their callback is switched off).
function Hub.rowsFor(callbacks)
 callbacks=callbacks or {}
 local out={}
 for _,row in ipairs(Hub.Rows)do
  if not(row.id=="stats"and callbacks.stats==false)and not(row.id=="name"and callbacks.names==false)then table.insert(out,row)end
 end
 return out
end
-- Pure: tile rect {x, y, w, h} for tile `index` of `count` in the hub grid (body size W x H).
function Hub.tileRect(index,count,W,H,phone)
 local G=Hub.Grid
 local x0,y0,w,h,gap=G.x,G.y,G.w,G.h,G.gap
 if phone then x0,y0,w,h,gap=G.phoneX,G.phoneY,W-20-G.phoneX,H-84,G.phoneGap end
 local rows=math.max(1,math.ceil(count/Hub.Cols))
 local tw=math.floor((w-(Hub.Cols-1)*gap)/Hub.Cols)
 local th=math.max(44,math.floor((h-(rows-1)*gap)/rows))
 local col,row=(index-1)%Hub.Cols,math.floor((index-1)/Hub.Cols)
 return{x=x0+col*(tw+gap),y=y0+row*(th+gap),w=tw,h=th}
end
-- Pure: the default tile index for a row list (Customize, else the first).
function Hub.defaultIndex(rows)
 for i,row in ipairs(rows)do if row.id=="customize"then return i end end
 return 1
end

-- Pure: hatched items waiting to be used (one per pending receipt kind).
function Hub.newItems(state)
 state=state or {}
 local n=0
 for _,key in ipairs({"pendingHueResult","pendingMaterialResult","pendingFeatureResult"})do if state[key]~=nil then n+=1 end end
 return n
end
-- Pure (v816): toys owned, not counting None.
function Hub.toysOwned(state)
 local n=0
 for id,owned in pairs(state and state.toyUnlocks or {})do if owned==true and id~=ToyCatalog.Default and ToyCatalog.known(id)then n+=1 end end
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
 if rowId=="stats"then
  if ctx.totalLevel then return{text=string.upper(UICopy.get("stats.chip",{count=ctx.totalLevel})),tone="dim"}end
  return{text="",tone="dim"}
 end
 if rowId=="name"then return{text=if ctx.named then string.upper(ctx.shownName or ctx.petName or "")else string.upper(UICopy.get("names.rowUnnamed")),tone=if ctx.named then "dim"else "stars",dot=not ctx.named}end
 if rowId=="wardrobe"then return{text=tostring(ctx.owned or 0).." OWNED",tone="dim"}end
 if rowId=="toys"then
  local text=UICopy.get("r4.customize.toys.owned",{count=ctx.toys or 0})
  -- A hatched toy waiting to be seen: the NEW badge (the Stars dot).
  if ctx.newToy then return{text=UICopy.get("r4.customize.newBadge").." · "..text,tone="stars",dot=true}end
  return{text=text,tone="dim"}
 end
 if rowId=="customize"then
  local n=ctx.newItems or 0
  if n>0 then return{text=n..(if n==1 then " NEW ITEM"else " NEW ITEMS"),tone="stars",dot=true}end
  return{text="",tone="dim"}
 end
 return{text="",tone="dim"}
end
-- Pure: the read-only pane rows (Wearing, Charm, Material, Toy) for one appearance.
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
 -- v816: the Material row names the jar look ("Glossy", "Jelly Satin"); with no jars used, a
 -- legacy material keeps its name and the rest read Original.
 local material
 local sheen,jelly=appearance.sheen or 0,appearance.jellyStage or 0
 if sheen~=0 or jelly~=0 then material=require(script.Parent.FinishPanel).lookName({sheen=sheen,jelly=jelly})
 elseif appearance.finish and appearance.finish~=MaterialCatalog.Default and MaterialCatalog.ById[appearance.finish]then material=MaterialCatalog.ById[appearance.finish].name
 else material=UICopy.get("r4.customize.finish.sheen.zero")end
 local toy=ToyCatalog.ById[appearance.toyId or ToyCatalog.Default]or ToyCatalog.ById[ToyCatalog.Default]
 return{{"Wearing",wearing},{"Charm",charm},{"Material",material},{"Toy",toy.name}}
end
-- Pure: owned pets as selector cards, in catalog order. Only pets that can be shown
-- (Pets.isActive: a rig in this build) are listed, so an owned pet whose rig is not in
-- the build (slice E: the second pet behind its flag) never becomes the companion.
-- v2 Bunny: an active earned pet you do not own yet follows as an adopt card (`adopt`, its fixed
-- Star `price`, and the stamp rule: free at `need` stamps, `stamps` so far; `free` once earned).
function Hub.petCards(state,activeId)
 local cards={}
 local mask=state and state.inventoryMask or 0
 for _,pet in ipairs(Pets.collection)do
  if Pets.isActive(pet)and Eggs.isOwned(mask,pet.id)then table.insert(cards,{id=pet.id,name=(NameText.own(state,pet.id)),following=pet.id==activeId})end
 end
 for _,petId in ipairs(Earned.Order)do
  local pet,rule=Pets.byId[petId],Earned.Rules[petId]
  if pet and rule and type(rule.stars)=="number"and Pets.isActive(pet)and not Eggs.isOwned(mask,petId)then
   local stamps=if state and type(state.stamps)=="number"then state.stamps else 0
   table.insert(cards,{id=petId,name=pet.name,adopt=true,price=rule.stars,need=rule.stamps,stamps=stamps,free=stamps>=rule.stamps})
  end
 end
 return cards
end
-- Pure: the adopt pane's line, button text and whether the button can be pressed.
-- confirming: the first press arms a 3 s confirm, as the Wardrobe's buy does. An earned card
-- (`free`: the stamps are there, the grant has not landed yet) takes it home with no Stars.
function Hub.adoptPane(card,wallet,pending,confirming)
 if card.free then
  return UICopy.get("v2.adopt.freeLine",{need=card.need or 0}),UICopy.get(if pending then "v2.adopt.saving"else "v2.adopt.free"),not pending
 end
 local line=UICopy.get("v2.adopt.line",{need=card.need or 0,stamps=math.min(card.stamps or 0,card.need or 0),price=card.price})
 if pending then return line,UICopy.get("v2.adopt.saving"),false end
 if(wallet or 0)<card.price then return line,UICopy.get("v2.adopt.short",{price=card.price}),false end
 if confirming then return line,UICopy.get("v2.adopt.confirm",{price=card.price}),true end
 return line,UICopy.get("v2.adopt.button",{price=card.price}),true
end
-- Pure (slice E): the pet the hub shows when no companion is set: the first owned
-- active pet, else the first active pet (a fresh save's pane still has a pet to draw).
function Hub.firstOwned(state)
 local mask=state and state.inventoryMask or 0
 for _,pet in ipairs(Pets.active)do if Eggs.isOwned(mask,pet.id)then return pet.id end end
 return Pets.active[1]and Pets.active[1].id or Pets[1].id
end

-- Pure (v2 S3): a pet's total stat level from the snapshot, or nil without stats.
function Hub.totalLevel(state,petId)
 local stats=state and state.petStats
 local entry=type(stats)=="table"and type(stats.pets)=="table"and stats.pets[petId]or nil
 return if type(entry)=="table"and type(entry.total)=="number"then entry.total else nil
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
-- Toy Shell: a role read on `object`'s own surface (ink on cream tiles, white on trays).
local function colorOf(role,object,property)return Kit.roleOn(object,role,property)end

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
 self.rowDefs=Hub.rowsFor(self.callbacks);self.rowIndex=Hub.defaultIndex(self.rowDefs)
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
function Hub:cards()
 local cards=Hub.petCards(self.ctx.state,self.ctx.activeId)
 -- Assign mode (a receipt's "Use now") lists only pets you own.
 if self.assign then for i=#cards,1,-1 do if cards[i].adopt then table.remove(cards,i)end end end
 return cards
end
function Hub:statusCtx()
 local petId=self:activePet();local pet=Pets.byId[petId]
 return{petName=pet and pet.name or "",owned=Hub.ownedCount(self.ctx.state,petId),newItems=Hub.newItems(self.ctx.state),
  toys=Hub.toysOwned(self.ctx.state),newToy=self.ctx.state~=nil and self.ctx.state.pendingToyResult~=nil,
  totalLevel=Hub.totalLevel(self.ctx.state,petId),named=select(2,NameText.own(self.ctx.state,petId)),
  shownName=(NameText.own(self.ctx.state,petId))}
end

-- Preview well: a ViewportFrame with the pet (same set-up as the Wardrobe pane).
function Hub:buildWell(parent,x,y,w,h)
 local well=Kit.frame(parent,"PreviewWell","stage",UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),12);Kit.stroke(well);Kit.stage(well)
 local viewport=Kit.node("ViewportFrame",well,{Name="PetPreview",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=well.ZIndex+1});Kit.petLight(viewport)
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
  local pad=1.10
  self.camera.CFrame=CFrame.lookAt(box.Position+Vector3.new(0,.12,distance*pad),box.Position)
 end
end

local function chevron(parent,x,y,size)
 local c=Kit.icon(parent,"chevron",size,"soft");c.AnchorPoint=Vector2.new(.5,.5);c.Position=UDim2.fromOffset(x,y);return c
end
-- Icon disc: the focused row's disc turns accent with an ink icon.
local function disc(parent,icon,x,y,size)
 local d=Kit.frame(parent,"IconDisc",nil,UDim2.fromOffset(x,y),UDim2.fromOffset(size,size),999);d.BackgroundTransparency=0
 d.BackgroundColor3=Kit.Color.ink;Kit.setSurface(d,"dark") -- an ink disc on a cream row: its icon stays white
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
 local pane=Kit.card(body,"PetPane",nil,{pad=16,seam=not phone}) -- QA v685 U4: the seam read as a clipped border on phones
 -- Slice F: bond pips with the pet's name (nil while bond data is not in the snapshot).
 local bond=BondPips.info(self.ctx.state and self.ctx.state.bond,petId)
 self.pips=nil
 if phone then
  local ph=H-64-20
  pane.Position=UDim2.fromOffset(20,64);pane.Size=UDim2.fromOffset(200,ph)
  self:buildWell(pane,12,12,176,math.max(60,ph-80))
  -- Phone: the pips sit beside the name (no room under it above "Following you").
  local pipsW=if bond then BondPips.extent(BondPips.Size.compact)+8 else 0
  self.petName=txt(pane,"Title",(NameText.own(self.ctx.state,petId)),"text",12,ph-62,176-pipsW,24,{TextSize=18,TextTruncate=Enum.TextTruncate.AtEnd,AutoLocalize=false})
  self.following=txt(pane,"Small","Following you","soft",12,ph-34,176,18,{TextSize=12})
  if bond then
   self.pips=BondPips.new(pane,true);self.pips.root.Position=UDim2.fromOffset(12+176-self.pips.width,ph-62+2);self.pips.set(bond)
  end
 else
  pane.Position=UDim2.fromOffset(24,84);pane.Size=UDim2.fromOffset(328,452)
  -- Desktop: the pips go under the name; the preview well gives up their 22 px.
  local lift=if bond then 22 else 0
  self:buildWell(pane,16,16,296,248-lift)
  self.petName=txt(pane,"Title",(NameText.own(self.ctx.state,petId)),"text",16,276-lift,190,32,{TextSize=24,TextTruncate=Enum.TextTruncate.AtEnd,AutoLocalize=false})
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
 self.statsButton=nil;self.nameButton=nil
 local ctx=self:statusCtx()
 local defs=self.rowDefs
 for index,row in ipairs(defs)do
  local R=Hub.tileRect(index,#defs,W,H,phone)
  local x,y,w,h=R.x,R.y,R.w,R.h
  -- T2: pressable tile with a lip (in the grid gap).
  local button,tileState=Kit.tile(body,"Row_"..row.id,{selectable=false,radius=if phone then 12 else 14,compact=phone,
   position=UDim2.fromOffset(x,y),size=UDim2.fromOffset(w,h)})
  local stroke=tileState.stroke
  local s=Hub.status(row.id,ctx)
  -- Spencer 2026-11-20: the Name tile reads "Name your Bear" (the species, as the screen's title).
  -- Round 3 (Spencer): the tile is just "Name" (the naming screen keeps "Name your Bear").
  local title=row.name
  local name,line,status,d,icon,dot
  button:SetAttribute("AccessibleLabel",title..", "..row.line)
  if phone then
   -- Phone tile (about 290 x 88): disc left, name, one line, status under it.
   local discSize=math.min(Hub.Grid.phoneDisc,h-8)
   d,icon=disc(button,row.icon,12,(h-discSize)/2,discSize)
   local tx=12+discSize+10
   local roomy=h>=70
   name=txt(button,"Strong",title,"text",tx,if roomy then h/2-30 else h/2-20,w-tx-28,22,{TextSize=16})
   line=txt(button,"Small",row.line,"soft",tx,h/2-7,w-tx-28,16,{TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd,Visible=roomy})
   status=txt(button,"Label",s.text,s.tone,tx+(if s.dot then 12 else 0),if roomy then h/2+12 else h/2+2,w-tx-40,16,{Name="Status",TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd})
   if s.dot then dot=Kit.frame(button,"NewDot","stars",UDim2.fromOffset(tx,(if roomy then h/2+12 else h/2+2)+4),UDim2.fromOffset(8,8),999)end
   chevron(button,w-16,h/2,14)
  else
   -- Desktop tile (222 x 142): disc top left, the name under it, two lines of copy, status at the foot.
   local discSize=math.min(44,h-90)
   d,icon=disc(button,row.icon,16,14,discSize)
   local ny=14+discSize+6
   name=txt(button,"Heading",title,"text",16,ny,w-32,24,{TextSize=20,TextTruncate=Enum.TextTruncate.AtEnd})
   line=txt(button,"Body",row.line,"soft",16,ny+26,w-32,32,{TextSize=14,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextTruncate=Enum.TextTruncate.AtEnd})
   status=txt(button,"Label",s.text,s.tone,16+(if s.dot then 14 else 0),h-22,w-32-(if s.dot then 14 else 0),16,{Name="Status",TextSize=12,TextTruncate=Enum.TextTruncate.AtEnd})
   if s.dot then dot=Kit.frame(button,"NewDot","stars",UDim2.fromOffset(16,h-18),UDim2.fromOffset(8,8),999)end
   chevron(button,w-22,14+discSize/2,18)
  end
  Kit.paint(status,"TextColor3",function()return colorOf(s.tone,status,"TextColor3")end)
  if row.id=="pets"or row.id=="name"then Kit.fixedText(status)end -- the pet's name (stays as named)
  self.rows[index]={id=row.id,button=button,stroke=stroke,disc=d,icon=icon,name=name,line=line,status=status,dot=dot}
  button.Activated:Connect(function()self:focusRow(index);self:act()end)
 end
end

function Hub:buildSelector(body,W,H,phone)
 local cards=self:cards()
 self.headshots={}
 if not self.shotCache then
  self.shotCache=Headshot.newCache()
  self.shotCache.onDetach=function(holder)
   for _,h in ipairs(self.headshots or {})do if h.holder==holder and h.paw.Parent then h.paw.Visible=true end end
  end
 end
 local pw,ph,px,py,gx,gy,gw,gh,cardW,cardH,cols,gap
 if phone then
  pw=232;ph=H-84;px,py=W-20-pw,64;gx,gy=20,64;gw=W-52-pw;gh=H-84
  cols=if gw>=420 then 2 else 1;gap=8;cardH=64;cardW=math.floor((gw-6-(cols-1)*gap)/cols)
 else
  pw,ph,px,py=328,452,24,84;gx,gy,gw,gh=368,84,456,452;cols=2;gap=12;cardH=96;cardW=math.floor((gw-6-gap)/2)
 end
 self.cols=cols
 local pane=Kit.card(body,"PetPane",nil,{pad=16,seam=not phone});pane.Position=UDim2.fromOffset(px,py);pane.Size=UDim2.fromOffset(pw,ph)
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
  swatch.ClipsDescendants=true
  local appearance=if card.adopt then nil else self:appearanceOf(card.id)
  local backdrop=if card.adopt then Kit.color("tray")else Headshot.backdrop(card.id,appearance)
  Kit.paint(swatch,"BackgroundColor3",function()return if card.adopt then Kit.color("tray")else backdrop end)
  local paw=Kit.icon(swatch,"paw",math.floor(side*.5),"soft");paw.AnchorPoint=Vector2.new(.5,.5);paw.Position=UDim2.fromScale(.5,.5)
  if card.adopt then
   local lock=Kit.icon(b,"lock",14,"soft");lock.Name="Lock";lock.AnchorPoint=Vector2.new(1,1);lock.Position=UDim2.fromOffset(10+side-3,10+side-3);lock.ZIndex=swatch.ZIndex+4
  end
  self.headshots=self.headshots or {}
  table.insert(self.headshots,{holder=swatch,paw=paw,petId=card.id,appearance=appearance,locked=card.adopt==true})
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

-- Headshots on the visible pet cards (at most one new render per frame).
function Hub:pumpHeadshots()
 if not self.shotCache then return end
 local list=if self.page=="pets"then self.list else nil
 local cards={}
 for _,h in ipairs(if list then self.headshots or {}else {})do
  if h.holder.Parent then
   local y=h.holder.AbsolutePosition.Y-list.AbsolutePosition.Y
   local visible=y+h.holder.AbsoluteSize.Y>=-8 and y<=list.AbsoluteSize.Y+8
   table.insert(cards,Headshot.card(h.holder,h.petId,h.appearance,h.locked,visible))
  end
 end
 self.shotCache:pump(cards,function(holder)
  for _,h in ipairs(self.headshots or {})do if h.holder==holder then h.paw.Visible=false end end
 end)
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
-- The server's petAdopt answer (FaceplateResult kind "adopt"). Saved: the snapshot that follows
-- moves the pet into the owned cards. Returns a toast line for the caller, or nil.
function Hub:adoptResult(message)
 if type(message)~="table"or message.petId~=self.pendingAdopt then return nil end
 -- Only the answer to the press in flight (a late reply to an older press is ignored).
 if self.pendingAdoptId~=nil and message.id~=self.pendingAdoptId then return nil end
 self.pendingAdopt,self.pendingAdoptId=nil,nil;self:refresh()
 local pet=Pets.byId[message.petId]
 if message.status=="Saved"then return UICopy.get("v2.adopt.done",{pet=pet and pet.name or ""})end
 if message.status=="Retrying"then return UICopy.get("v2.adopt.retry")end
 return UICopy.get("v2.adopt.failed")
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
 Kit.paint(entry.button,"BackgroundColor3",function()return colorOf(if focused then "selected"else "raised",entry.button,"BackgroundColor3")end)
 entry.stroke.Thickness=if focused then 2 else 1;entry.stroke.Transparency=if focused then 0 else .86
 Kit.paint(entry.stroke,"Color",function()return Kit.color("ink")end) -- Toy Shell: the outline is always ink
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
   if card and card.adopt then text,tone=UICopy.get(if card.free then "v2.adopt.freeStatus"else "v2.adopt.status",{price=card.price}),"accent"end
   if self.pendingFollow==entry.id then text,tone="SAVING…","soft"end
   entry.status.Text=text;Kit.paint(entry.status,"TextColor3",function()return colorOf(tone,entry.status,"TextColor3")end)
   entry.button:SetAttribute("Following",card~=nil and card.following==true)
  end
  self:paintSelectorPane()
 else
  self.rowIndex=math.clamp(self.rowIndex,1,#self.rowDefs)
  for index,entry in ipairs(self.rows)do
   -- v850: opened by touch, no row is highlighted; the ring is for gamepad and keyboard.
   local focused=index==self.rowIndex and not self.touchMode
   paintRowFocus(entry,focused)
   Kit.paint(entry.disc,"BackgroundColor3",function()return if focused then Kit.color("accent")else Kit.Color.ink end)
   Kit.tintIcon(entry.icon,if focused then "ink"else "text")
  end
  self.focusPet=nil
  if self.visible then self:paintPreview(self:activePet())end
 end
 self.root:SetAttribute("FocusedRow",if self.page=="hub"then self.rowDefs[self.rowIndex].id else nil)
end
function Hub:paintSelectorPane()
 local entry=self.cardButtons[self.cardIndex]
 if not entry then
  self.paneName.Text="";self.paneLine.Text="";self.action.Visible=false
  if self.pips then self.pips.set(nil)end
  return
 end
 self.focusPet=entry.id
 local card=self:cards()[self.cardIndex]
 -- An adopt card has no bond yet: no hearts until the pet is yours.
 local adopting=card~=nil and card.id==entry.id and card.adopt==true
 if self.pips then self.pips.set(if adopting then nil else BondPips.info(self.ctx.state and self.ctx.state.bond,entry.id))end
 local pet=Pets.byId[entry.id];local following=entry.id==self.ctx.activeId
 self.paneName.Text=(NameText.own(self.ctx.state,entry.id))
 self.action.Visible=true
 Kit.setTappable(self.action,false) -- only a short adopt below takes a dim press
 if card and card.id==entry.id and card.adopt then
  local confirming=self.confirmAdopt~=nil and self.confirmAdopt.id==entry.id and os.clock()<self.confirmAdopt.untilAt
  local line,button,enabled=Hub.adoptPane(card,self.ctx.wallet,self.pendingAdopt~=nil,confirming)
  self.paneLine.Text=line;Kit.setText(self.action,button);Kit.setEnabled(self.action,enabled and not self.assign)
  Kit.setTappable(self.action,not card.free and not self.assign and self.pendingAdopt==nil and(self.ctx.wallet or 0)<card.price)
 elseif self.assign then
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
 self.rowIndex=math.clamp(index,1,#self.rowDefs);self:refresh()
 local entry=self.rows[self.rowIndex]
 if self.touchMode and self.page=="hub"then if self.ring then self.ring.hide()end;return end
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
 local nextIndex=Hub.step(self.rowIndex,dx,dy,#self.rowDefs,Hub.Cols)
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
  local row=self.rowDefs[self.rowIndex];if not row then return false end
  self.lastRow=self.rowIndex
  if row.id=="pets"then self:setPage("pets");return true end
  if self.callbacks.open then return self.callbacks.open(row.id,self:activePet())==true end
  return false
 end
 local entry=self.cardButtons[self.cardIndex];if not entry then return false end
 local card=self:cards()[self.cardIndex]
 if card and card.id==entry.id and card.adopt then
  -- v2 Bunny: 400 Stars is a big spend, so the first press arms a 3 s confirm and the second sends.
  -- An earned (free) card sends at once: nothing is spent.
  if self.assign or self.pendingAdopt then return false end
  if not card.free and(self.ctx.wallet or 0)<card.price then
   -- Stars store access: short of Stars opens the "need more Stars" card.
   local pet=Pets.byId[card.id]
   return require(script.Parent.StarsShort).ask({price=card.price,wallet=self.ctx.wallet,item=pet and pet.name or nil,from="companions"},self)
  end
  -- Round 3 (Spencer: "don't do press again to adopt, open a confirmation dialog"): a paid adopt
  -- asks in ConfirmDialog; the yes re-checks everything, as the hub may have changed meanwhile.
  if not card.free then
   local id,price=card.id,card.price
   local pet=Pets.byId[id]
   local vars={pet=pet and pet.name or "",price=price}
   self.confirmHandle=require(script.Parent.ConfirmDialog).ask({tone="spend",
    title=UICopy.get("confirm.adoptTitle",vars),line=UICopy.get("confirm.adoptLine",vars),confirm=UICopy.get("confirm.adoptYes",vars),
    onConfirm=function()
     self.confirmHandle=nil
     if not self.visible or self.page~="pets"or self.assign or self.pendingAdopt then return end
     local now=self:cards()[self.cardIndex]
     if not now or now.id~=id or not now.adopt or now.free or now.price~=price or(self.ctx.wallet or 0)<price then return end
     self:sendAdopt(now)
    end,onCancel=function()self.confirmHandle=nil end})
   return self.confirmHandle~=nil
  end
  return self:sendAdopt(card)
 end
 if self.assign then
  local assign=self.assign;self.assign=nil
  local ok=assign.choose and assign.choose(entry.id)==true
  if ok then require(script.Parent.UIClick).play("equip")end -- "Use now" lands on this pet
  self:close("assigned");return ok
 end
 if self.pendingFollow or entry.id==self.ctx.activeId then return false end
 if self.callbacks.follow and self.callbacks.follow(entry.id)==true then
  self.pendingFollow=entry.id;require(script.Parent.UIClick).play("equip");self:refresh();return true -- QA v775 note 10: Follow is an equip
 end
 return false
end
-- Sends one adopt (the free card at once, a paid one after the confirm dialog's yes).
function Hub:sendAdopt(card)
 do
  local sent=self.callbacks.adopt and self.callbacks.adopt(card.id,card.price)
  if sent then
   -- The callback returns the operation id (or true); replies and the timeout match on it.
   local opId=if type(sent)=="string"then sent else nil
   self.pendingAdopt,self.pendingAdoptId=card.id,opId;require(script.Parent.UIClick).play("equip");self:refresh()
   task.delay(12,function()if self.pendingAdopt==card.id and self.pendingAdoptId==opId then self.pendingAdopt,self.pendingAdoptId=nil,nil;self:refresh()end end)
   return true
  end
  return false
 end
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
 -- The first gamepad / keyboard press after a touch open shows the focus again.
 if self.touchMode then self.touchMode=false;self:refocus()
  if key==K.Left or key==K.A or key==K.DPadLeft or key==K.Right or key==K.D or key==K.DPadRight or key==K.Up or key==K.W or key==K.DPadUp or key==K.Down or key==K.S or key==K.DPadDown then return end
 end
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
 self.assign=options.assign;self.pendingFollow=nil;self.confirmAdopt=nil
 self.page=options.page or "hub";self.key=nil;self.slideFrom=nil
 self.rowIndex=self.lastRow or Hub.defaultIndex(self.rowDefs)
 self.touchMode=if options.touch~=nil then options.touch==true else Kit.lastInputTouch()
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
  if self.visible then self:pumpHeadshots()end
  local v=self.visual;if not self.visible or not v or v.destroyed then return end
  if GuiService.ReducedMotionEnabled then return end
  v.cosmeticTime=os.clock();v:update(math.min(dt,.1))
 end)
 self.sizeConnection=self.sizeConnection or self.host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.visible then self:fit(self.host.AbsoluteSize)end end)
 return true
end
function Hub:close(reason)
 if not self.visible then return false end
 if self.confirmHandle then self.confirmHandle.cancel("owner");self.confirmHandle=nil end
 self.visible=false;self.covered=false;self.root.Visible=false;Kit.shadeClose(self);if self.ring then self.ring.hide()end
 if self.clock then self.clock:Disconnect();self.clock=nil end
 if self.visual then self.visual:destroy();self.visual=nil end
 if self.shotCache then self.shotCache:clear()end
 if reason~="assigned"and reason~="cancel"then self.assign=nil end
 if self.callbacks.closed then self.callbacks.closed(reason)end
 return true
end
function Hub:destroy()self:close("destroy");if self.sizeConnection then self.sizeConnection:Disconnect()end;self.root:Destroy();self.shade:Destroy()end
return Hub
