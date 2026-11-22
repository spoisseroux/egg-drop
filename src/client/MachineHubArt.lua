-- Machine hub tile art (QA 2026-11-14 U2, "the Pocket menu is too empty"). Each hub
-- tile carries a small glass well with a live picture of what the machine holds, all
-- from art the game already draws elsewhere:
--   hatch       three shells (EggArt: companion, toy and hue eggs)
--   style       the mini deck in this week's shelf faceplate (else the equipped plate),
--               or this week's shelf balls (JellySprite previews)
--   companions  the player's pet in its own colours (PetPortrait), plus this week's
--               shelf wearable from the book atlas when it has a cell
--   quests      the stamp card as seven slots and the reward Star (WalletStar)
--   book        up to three owned items from the book atlas, fanned like stickers
--   settings    three sliders drawn from Kit frames
-- A locked tile (before the first pet) shows its icon, dimmed.
--
-- QA v775 note 9: the four machine tiles move instead of standing still.
--   hatch       the three eggs in 3D (EggPreview3D's shells), each turning slowly
--   style       the mini deck rocks a little while a ball drops down its screen and
--               the A button dips (or this week's shelf balls hop)
--   companions  the player's own pet in a small 3D portrait, waving every few seconds
--               (the visitor hello's wave, PetHelloPose)
--   book        the fanned stickers (or the book icon) float and tip gently
-- Cheap by rule: at most one ViewportFrame per tile; nothing is created per frame; the
-- owner (MachineHub) steps the art only while the hub is open and on top, through
-- `Art.step`, and calls `Art.still` instead under Reduced Effects (one posed frame).
--
-- Presentation only. `Art.key(id, ctx)` is a pure signature: MachineHub rebuilds a
-- well only when its key changes (a snapshot that moves nothing redraws nothing).
local Kit=require(script.Parent.DeckKit)
local Shared=game:GetService("ReplicatedStorage").Shared
local Pets=require(Shared.PetCatalog)
local DeckThemes=require(Shared.DeckThemes)
local Stamp=require(Shared.StampCard)
local Deal=require(script.Parent.ShelfDeal)
local Art={}
-- Motion (note 9). Each animated art root has one entry here: {step(now, dt), still()}.
local animators=setmetatable({},{__mode="k"})
Art.Animated=table.freeze({hatch=true,style=true,companions=true,book=true})
Art.WaveEvery=3.6      -- s between the Companions pet's waves
Art.EggTurn=.55        -- rad/s, the Hatch eggs' slow turn
Art.DeckLoop=2.6       -- s, one ball drop on the mini deck
local function animate(root,step,still)animators[root]={step=step,still=still}end
-- Advance one tile's art. No-op for art without motion (and for a destroyed root).
function Art.step(root,now,dt)
 local entry=root and animators[root]
 if entry and root.Parent then entry.step(now,dt)end
end
-- The resting frame (Reduced Effects, or the hub going quiet).
function Art.still(root)
 local entry=root and animators[root]
 if entry and entry.still and root.Parent then entry.still()end
end
function Art.animated(root)return root~=nil and animators[root]~=nil end
-- Pure: the mini deck's ball over one loop, phase 0..1: its height on the screen (0 top,
-- 1 resting on the floor), its opacity, and how far the A button is pressed (0..1).
function Art.deckBall(phase)
 phase=phase%1
 local y
 if phase<.34 then local u=phase/.34;y=u*u -- falls
 elseif phase<.50 then local u=(phase-.34)/.16;y=1-.22*math.sin(u*math.pi) -- one small bounce
 else y=1 end
 local alpha=if phase<.06 then phase/.06 elseif phase>.84 then math.max(0,(1-phase)/.16)else 1
 local press=if phase<.10 then math.sin(phase/.10*math.pi)else 0
 return y,alpha,press
end
-- Pure: when the wave now showing began, for a pet that first waves `lead` s after
-- `since` and then every Art.WaveEvery; nil before the first wave.
function Art.waveAt(now,since,lead)
 lead=lead or .5
 local elapsed=now-since-lead
 if elapsed<0 then return nil end
 return since+lead+math.floor(elapsed/Art.WaveEvery)*Art.WaveEvery
end

local function stateOf(ctx)return type(ctx)=="table"and type(ctx.state)=="table"and ctx.state or {}end
local function weekOf(ctx)
 if type(ctx)=="table"and ctx.week~=nil then return ctx.week end
 return Deal.week(stateOf(ctx))
end
-- Pure: this week's first shelf slot of one kind ({kind, id, ...}) or nil.
function Art.shelfSlot(ctx,kind)
 local week=weekOf(ctx)
 if not week then return nil end
 for _,slot in ipairs(Deal.slots(week))do
  if type(slot)=="table"and slot.kind==kind and type(slot.id)=="string"then return slot end
 end
 return nil
end
-- Pure: stamps on the current card (0..Length-1) and whether today's is waiting.
function Art.stampCard(state)
 state=type(state)=="table"and state or {}
 local stamps=tonumber(state.stamps)or 0
 if stamps~=stamps or stamps<0 then stamps=0 end
 return Stamp.onCard(math.floor(stamps)),Stamp.Length,state.dailyAvailable==true
end
-- Pure: up to `count` book items to picture, owned ones first: {{id, owned}}.
function Art.bookCells(book,count,rectOf)
 local out,seen={},{}
 local pages=type(book)=="table"and type(book.pages)=="table"and book.pages or {}
 for _,page in ipairs(pages)do
  for _,id in ipairs(type(page)=="table"and type(page.ownedIds)=="table"and page.ownedIds or {})do
   if #out>=count then return out end
   if not seen[id]and rectOf(id,true)then seen[id]=true;table.insert(out,{id=id,owned=true})end
  end
 end
 return out
end
-- The pet a tile pictures: the player's current companion, else the first active pet.
function Art.pet()
 local ok,petId,appearance=pcall(function()return require(script.Parent.PetPeek).current()end)
 if ok and type(petId)=="string"and Pets.byId[petId]then return Pets.byId[petId],appearance,true end
 return Pets.active[1],nil,false
end
-- The equipped faceplate: the deck's current theme and its id (themes carry no id of their own).
function Art.equippedPlate()
 local theme=require(script.Parent.DeckArt).getTheme()
 if not theme then return nil,nil end
 for id,candidate in pairs(DeckThemes.ById)do if candidate==theme then return theme,id end end
 return nil,nil
end
local function appearanceKey(appearance)
 if type(appearance)~="table"then return "-"end
 local parts={}
 for key,value in pairs(appearance)do
  local kind=typeof(value)
  if kind=="string"or kind=="number"or kind=="boolean"or kind=="Color3"then table.insert(parts,tostring(key).."="..tostring(value))end
 end
 table.sort(parts)
 return table.concat(parts,";")
end
-- Pure enough (reads the current pet and theme): what a tile's well shows, as a string.
function Art.key(id,ctx,locked)
 if locked then return "locked"end
 local state=stateOf(ctx)
 if id=="style"then
  local plate,ball=Art.shelfSlot(ctx,"faceplate"),Art.shelfSlot(ctx,"ball")
  local _,equipped=Art.equippedPlate()
  return "style:"..(plate and plate.id or "-")..":"..(ball and ball.id or "-")..":"..tostring(equipped or "-")
 elseif id=="companions"then
  local pet,appearance=Art.pet()
  local wear=Art.shelfSlot(ctx,"wearable")
  return "pet:"..tostring(pet and pet.id)..":"..appearanceKey(appearance)..":"..(wear and wear.id or "-")
 elseif id=="quests"then
  local on,_,today=Art.stampCard(state)
  return "stamps:"..on..":"..tostring(today)
 elseif id=="book"then
  local ids={}
  for _,cell in ipairs(Art.bookCells(state.book,3,require(script.Parent.BookView).atlasRect))do table.insert(ids,cell.id)end
  return "book:"..table.concat(ids,",")
 end
 return id
end

local function holder(well,w,h)
 local old=well:FindFirstChild("Art");if old then old:Destroy()end
 local root=Kit.node("Frame",well,{Name="Art",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(w,h),ZIndex=well.ZIndex+1,Active=false,ClipsDescendants=true})
 return root
end

local builders={}
-- The three eggs of the Hatch tile, back row first: {type, x, z, scale, turn offset}.
Art.Eggs=table.freeze({table.freeze({"toy",-.56,-.42,.74,1.9}),table.freeze({"hue",.56,-.42,.74,3.6}),table.freeze({"companion",0,.3,1,0})})
function builders.hatch(root,w,h)
 local Egg=require(script.Parent.EggArt)
 -- The flat shells stay until the 3D ones are ready (and for good if the meshes fail).
 local flat=Kit.node("Frame",root,{Name="FlatEggs",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=root.ZIndex+1,Active=false})
 local big=math.floor(math.min(h-8,w*.5))
 local small=math.floor(big*.74)
 local cx,base=w/2,h-4
 local spread=math.min(w/2-small/2-2,big*.62)
 Egg.create(flat,"toy",UDim2.fromOffset(math.floor(cx-spread-small/2),math.floor(base-small)),UDim2.fromOffset(small,small),flat.ZIndex+1,"EggToy")
 Egg.create(flat,"hue",UDim2.fromOffset(math.floor(cx+spread-small/2),math.floor(base-small)),UDim2.fromOffset(small,small),flat.ZIndex+1,"EggHue")
 Egg.create(flat,"companion",UDim2.fromOffset(math.floor(cx-big/2),math.floor(base-big)),UDim2.fromOffset(big,big),flat.ZIndex+3,"EggCompanion")
 local Preview=require(script.Parent.EggPreview3D)
 local Models=require(Shared.EggModels)
 local viewport=Kit.node("ViewportFrame",root,{Name="Eggs3D",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=root.ZIndex+2,Active=false,Visible=false,
  Ambient=Color3.fromRGB(150,160,165),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(.5,-.8,-.6)})
 local world=Kit.node("WorldModel",viewport,{});local camera=Kit.node("Camera",viewport,{FieldOfView=20})
 viewport.CurrentCamera=camera
 -- The three eggs span 1.9 studs across and 1.35 up; fit both into the well, close.
 local half=math.tan(math.rad(10));local aspect=math.max(.2,w/math.max(1,h))
 local distance=math.max(.72/half,1.08/(half*aspect))+.45
 camera.CFrame=CFrame.lookAt(Vector3.new(0,1.05,distance),Vector3.new(0,.66,0))
 local eggs={}
 local function pose(yaw)
  for _,egg in ipairs(eggs)do
   local frame=CFrame.new(egg.x,0,egg.z)*CFrame.Angles(0,yaw+egg.offset,0)
   for _,piece in ipairs(egg.pieces)do piece.part.CFrame=frame*CFrame.new(piece.centre)end
  end
 end
 local function build()
  if not root.Parent or #eggs>0 then return end
  local maps={}
  for _,spec in ipairs(Art.Eggs)do
   local kind=Models.Types[spec[1]]or Models.Types.toy
   local copies=Preview.cloneTemplates();if not copies then return end
   local egg={x=spec[2],z=spec[3],offset=spec[5],pieces={}}
   for _,key in ipairs({"BottomShell","TopShell"})do
    local part=copies[key];local model=Models.Egg[key]
    part.Name=spec[1]..key;part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
    part.Size=model.size*spec[4];part.Material=Enum.Material.SmoothPlastic;part.Reflectance=.08;part.TextureID=kind.colorMap
    part.Parent=world
    table.insert(egg.pieces,{part=part,centre=model.center*spec[4]})
   end
   if copies.Core then copies.Core:Destroy()end -- a closed shell hides the core
   table.insert(eggs,egg);table.insert(maps,kind.colorMap)
  end
  pose(.5)
  -- Swap the flat shells out only once the three colour maps are in (never a grey egg).
  require(script.Parent.UIAssetWarmup).shared:request(maps,function(ok)
   if not root.Parent or not ok then return end
   viewport.Visible=true;flat.Visible=false;root:SetAttribute("Eggs3D",true)
  end,1)
 end
 root:SetAttribute("Eggs3D",false)
 Preview.loadTemplates(function(ok)if ok then pcall(build)end end)
 animate(root,function(now)if viewport.Visible then pose(now*Art.EggTurn)end end,function()pose(.5)end)
end
function builders.style(root,w,h,ctx)
 local plate,ball=Art.shelfSlot(ctx,"faceplate"),Art.shelfSlot(ctx,"ball")
 if not plate and ball then
  -- This week's shelf balls: small, middle and biggest tier, standing on the well floor.
  local LCD=require(script.Parent.JellyLCD)
  local Sprite=require(script.Parent.JellySprite)
  local tiers={1,3,5}
  local sizes,total={},0
  local cells={}
  local ok=pcall(function()for i,tier in ipairs(tiers)do sizes[i]=LCD.ballRuns(ball.id,tier,"idle",0,false).size;total+=sizes[i]end end)
  if ok and total>0 then
   local gap=4
   local px=math.min((h-8)/sizes[#sizes],(w-12-gap*(#sizes-1))/total)
   local x=(w-(total*px+gap*(#sizes-1)))/2
   for i,tier in ipairs(tiers)do
    local d=sizes[i]*px
    local cell=Kit.frame(root,"Ball"..tier,nil,UDim2.fromOffset(math.floor(x),math.floor(h-4-d)),UDim2.fromOffset(d,d))
    Sprite.preview(cell).set(ball.id,tier,"idle",0,false)
    table.insert(cells,{node=cell,x=math.floor(x),y=math.floor(h-4-d),hop=math.max(0,math.min(6,h-8-d))})
    x+=d+gap
   end
   root:SetAttribute("Shows","ball:"..ball.id)
   -- The shelf balls hop one after another.
   animate(root,function(now)
    for i,cell in ipairs(cells)do
     local u=(now*.7-i*.22)%1
     local lift=if u<.4 then math.sin(u/.4*math.pi)*cell.hop else 0
     cell.node.Position=UDim2.fromOffset(cell.x,math.floor(cell.y-lift+.5))
    end
   end,function()for _,cell in ipairs(cells)do cell.node.Position=UDim2.fromOffset(cell.x,cell.y)end end)
   return
  end
 end
 local theme=plate and DeckThemes.ById[plate.id]
 local id=plate and plate.id
 if not theme then
  theme,id=Art.equippedPlate()
 end
 if not theme or not id then theme=DeckThemes.ById.sherbet;id="sherbet"end
 if not theme then return end
 local width=math.floor(math.min(2*(h-10),w-10))
 local deck=require(script.Parent.FaceplateShop).miniDeck(root,width,UDim2.fromOffset(math.floor((w-width)/2),math.floor((h-width/2)/2)))
 deck.set(theme,id)
 root:SetAttribute("Shows","plate:"..id)
 -- The loop: a ball drops down the little screen as the A button dips, and the deck rocks.
 local lcd=deck.root:FindFirstChild("LCD");local buttonA=deck.root:FindFirstChild("A")
 if not lcd then return end
 local lh=lcd.Size.Y.Offset
 local size=math.max(3,math.floor(lh*.26))
 local ball=Kit.node("Frame",lcd,{Name="DemoBall",BorderSizePixel=0,BackgroundColor3=theme.accent or Color3.new(1,1,1),AnchorPoint=Vector2.new(.5,0),
  Size=UDim2.fromOffset(size,size),ZIndex=lcd.ZIndex+1,Active=false})
 Kit.node("UICorner",ball,{CornerRadius=UDim.new(.5,0)})
 lcd.ClipsDescendants=true
 local homeA=buttonA and buttonA.Position
 local dip=math.max(1,math.floor(width*.012+.5))
 local columns={.5,.3,.68}
 local function show(phase,loop)
  local y,alpha,press=Art.deckBall(phase)
  ball.Position=UDim2.new(columns[loop%#columns+1],0,0,math.floor(1+y*(lh-size-2)+.5))
  ball.BackgroundTransparency=1-alpha
  if buttonA then buttonA.Position=homeA+UDim2.fromOffset(0,math.floor(press*dip+.5))end
 end
 animate(root,function(now)
  local t=now/Art.DeckLoop
  show(t%1,math.floor(t))
  deck.root.Rotation=math.sin(now*1.3)*1.5
 end,function()show(.6,0);deck.root.Rotation=0 end)
 show(.6,0)
end
function builders.companions(root,w,h,ctx)
 local Portrait=require(script.Parent.PetPortrait)
 local pet,appearance,owned=Art.pet()
 if not pet then return end
 local wear=Art.shelfSlot(ctx,"wearable")
 local rect
 if wear then
  local atlasRect=require(script.Parent.BookView).atlasRect
  rect=atlasRect(wear.id,true)
  if not rect then
   for _,candidate in ipairs(Pets.active)do rect=rect or atlasRect(candidate.id..":"..wear.id,true)end
  end
 end
 local thumb=if rect then math.floor(math.min(h*.5,w*.34))else 0
 -- Note 9: the player's own pet in 3D (its hue, charm and clothes), waving. Without a
 -- pet of their own, or if the rig cannot be built, the pixel portrait stands in.
 local live=false
 if owned then
  live=pcall(function()
   local Factory=require(script.Parent.PetFactory);local Bounds=require(script.Parent.PetRigBounds)
   local viewport=Kit.node("ViewportFrame",root,{Name="PetPortrait3D",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(w-thumb,h),ZIndex=root.ZIndex+1,Active=false});Kit.petLight(viewport)
   local world=Kit.node("WorldModel",viewport,{});local camera=Kit.node("Camera",viewport,{FieldOfView=30})
   viewport.CurrentCamera=camera
   local visual=Factory.new(world,Vector3.zero,pet,nil,appearance)
   visual.yaw=-.2;visual.reducedEffects=true
   if visual.applyAppearance then visual:applyAppearance(appearance)end
   visual:update(0)
   local function fit()
    if visual.destroyed then return end
    local box,size=Bounds.get(visual)
    local a=math.max(.1,(w-thumb)/math.max(1,h));local half=math.tan(math.rad(camera.FieldOfView/2))
    -- A portrait with headroom: the pet stands in the lower four fifths of the well, so
    -- the "this week" sticker over the well's top edge never sits on its face.
    local distance=math.max(size.Y*.5/half,size.X*.62/(half*a))+size.Z*.5+.3
    local lift=size.Y*.13
    camera.CFrame=CFrame.lookAt(box.Position+Vector3.new(0,lift+size.Y*.04,distance*1.16),box.Position+Vector3.new(0,lift,0))
   end
   fit()
   visual.onRigChanged=function()if root.Parent then fit()end end
   root.Destroying:Connect(function()if not visual.destroyed then visual:destroy()end end)
   local since,last=nil,nil
   animate(root,function(now,dt)
    if visual.destroyed then return end
    since=since or now
    local at=Art.waveAt(now,since,.5)
    if at and at~=last then last=at;visual.hello={at=at,from=0};visual.helloTarget=Vector3.new(0,0,6)end
    visual.reducedEffects=false;visual.cosmeticTime=now;visual:update(dt or 0)
   end,function()
    if visual.destroyed then return end
    since,last=nil,nil;visual.hello=nil
    visual.reducedEffects=true;visual.poseDirty=true;visual:update(0)
   end)
   root:SetAttribute("Portrait","3d")
  end)
  if not live then local broken=root:FindFirstChild("PetPortrait3D");if broken then broken:Destroy()end end
 end
 if not live then
  -- Measure the sprite at 1 px a cell, then draw it as large as the well allows.
  local probe=Portrait.create(root,pet,1,UDim2.fromScale(.5,.5),root.ZIndex+1,not owned,appearance)
  local cols,rows=probe.Size.X.Offset,probe.Size.Y.Offset
  probe:Destroy()
  local unit=math.max(1,math.floor(math.min((h-6)/rows,(w-6-thumb)/cols)))
  local sprite=Portrait.create(root,pet,unit,UDim2.fromOffset(math.floor((w-thumb)/2),math.floor(h/2)),root.ZIndex+1,not owned,appearance)
  sprite.Name="PetPortrait"
  root:SetAttribute("Portrait","sprite")
 end
 if rect then
  local image=Kit.node("ImageLabel",root,{Name="ShelfWearable",BackgroundTransparency=1,Image=rect.image,ImageRectOffset=rect.offset,ImageRectSize=rect.size,
   AnchorPoint=Vector2.new(1,1),Position=UDim2.fromOffset(w-4,h-4),Size=UDim2.fromOffset(thumb,thumb),ZIndex=root.ZIndex+3,Active=false})
  image:SetAttribute("ItemId",wear.id)
 end
 root:SetAttribute("Shows","pet:"..pet.id)
end
function builders.quests(root,w,h,ctx)
 local on,length,today=Art.stampCard(stateOf(ctx))
 local wide=w>=130
 local cols=if wide then length else math.ceil(length/2)
 local rowsN=math.ceil(length/cols)
 local gap=4
 local d=math.floor(math.min((w-12-gap*(cols-1))/cols,(h-12-gap*(rowsN-1))/rowsN,20))
 local gridW,gridH=cols*d+(cols-1)*gap,rowsN*d+(rowsN-1)*gap
 local x0,y0=math.floor((w-gridW)/2),math.floor((h-gridH)/2)
 for index=1,length do
  local c,r=(index-1)%cols,(index-1)//cols
  local slot=Kit.frame(root,"Stamp"..index,nil,UDim2.fromOffset(x0+c*(d+gap),y0+r*(d+gap)),UDim2.fromOffset(d,d),999)
  local stamped=index<=on
  local next=index==on+1
  slot.BackgroundTransparency=if stamped then 0 else .55
  Kit.paint(slot,"BackgroundColor3",function()return if stamped then Kit.Tint.quests else Kit.color("raised")end)
  local ring=Kit.stroke(slot)
  if next and today then ring.Thickness=2;ring.Transparency=0;ring.Color=Kit.Color.stars end
  if stamped then
   local mark=Kit.icon(slot,"check",math.floor(d*.8),"ink");mark.AnchorPoint=Vector2.new(.5,.5);mark.Position=UDim2.fromScale(.5,.5)
  end
  slot:SetAttribute("Stamped",stamped);slot:SetAttribute("Today",next and today)
 end
 -- The last slot of a two-row card is free: the reward Star sits there (3D once its mesh loads).
 if not wide and cols*rowsN>length then
  local size=math.max(16,d)
  local pill=Kit.frame(root,"RewardStar",nil,UDim2.fromOffset(x0+(cols-1)*(d+gap)+math.floor((d-size)/2),y0+(rowsN-1)*(d+gap)+math.floor((d-size)/2)),UDim2.fromOffset(size,size))
  local icon=Kit.icon(pill,"star",size)
  pcall(function()require(script.Parent.WalletStar).attach(pill,icon,size)end)
 end
 root:SetAttribute("Shows","stamps:"..on)
end
function builders.book(root,w,h,ctx)
 local View=require(script.Parent.BookView)
 local cells=Art.bookCells(stateOf(ctx).book,3,View.atlasRect)
 if #cells==0 then
  local icon=Kit.icon(root,"book",math.floor(math.min(w,h)*.6),"soft");icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5)
  -- An empty book still breathes: the icon floats and tips a little.
  animate(root,function(now)
   icon.Position=UDim2.new(.5,0,.5,math.floor(math.sin(now*1.5)*2+.5));icon.Rotation=math.sin(now*.9)*3
  end,function()icon.Position=UDim2.fromScale(.5,.5);icon.Rotation=0 end)
  return
 end
 local n=#cells
 local size=math.floor(math.min(h-8,(w-8)/(.55+.45*n)))
 local step=math.floor(size*.45)
 local total=size+step*(n-1)
 local x0=math.floor((w-total)/2)
 -- Fanned like stickers on a page: each overlaps the last and tips a little.
 local tilts={-7,0,7}
 local stickers={}
 for index,cell in ipairs(cells)do
  local rect=View.atlasRect(cell.id,true)
  local image=Kit.node("ImageLabel",root,{Name="Cell"..index,BackgroundTransparency=1,Image=rect.image,ImageRectOffset=rect.offset,ImageRectSize=rect.size,
   Position=UDim2.fromOffset(x0+(index-1)*step,math.floor((h-size)/2)),Size=UDim2.fromOffset(size,size),ZIndex=root.ZIndex+index,Active=false,
   Rotation=if n>1 then tilts[index+(3-n)]or 0 else 0})
  image:SetAttribute("ItemId",cell.id)
  table.insert(stickers,{node=image,x=x0+(index-1)*step,y=math.floor((h-size)/2),tilt=image.Rotation})
 end
 root:SetAttribute("Shows","book:"..n)
 -- The stickers float and tip gently, each a beat behind the last (the top one most).
 local room=math.max(0,math.min(3,(h-size)/2-1))
 animate(root,function(now)
  for index,sticker in ipairs(stickers)do
   local phase=now*1.4-index*.9
   sticker.node.Position=UDim2.fromOffset(sticker.x,math.floor(sticker.y-math.sin(phase)*room+.5))
   sticker.node.Rotation=sticker.tilt+math.sin(phase*.7+.6)*(2+index)
  end
 end,function()
  for _,sticker in ipairs(stickers)do sticker.node.Position=UDim2.fromOffset(sticker.x,sticker.y);sticker.node.Rotation=sticker.tilt end
 end)
end
function builders.settings(root,w,h)
 local rowsN=3
 local trackH=6
 local knob=math.floor(math.min(16,(h-12)/rowsN-2))
 local gap=(h-rowsN*knob)/(rowsN+1)
 local left,right=10,w-10
 local levels={.72,.38,.56}
 local tints={Kit.Tint.book,Kit.Tint.style,Kit.Tint.hatch}
 for index=1,rowsN do
  local cy=math.floor(gap*index+knob*(index-.5))
  local track=Kit.frame(root,"Track"..index,"raised",UDim2.fromOffset(left,cy-trackH/2),UDim2.fromOffset(right-left,trackH),999)
  track.BackgroundTransparency=0
  local x=left+math.floor((right-left-knob)*levels[index])
  local fill=Kit.frame(root,"Fill"..index,nil,UDim2.fromOffset(left,cy-trackH/2),UDim2.fromOffset(x-left+knob/2,trackH),999)
  fill.BackgroundTransparency=0;fill.BackgroundColor3=tints[index]
  local cap=Kit.frame(root,"Knob"..index,nil,UDim2.fromOffset(x,cy-knob/2),UDim2.fromOffset(knob,knob),999)
  cap.BackgroundTransparency=0;cap.BackgroundColor3=Kit.Color.text;cap.ZIndex=root.ZIndex+2
  Kit.stroke(cap,"dim",1,.4)
 end
end

-- Draw tile `id` into `well` (w x h). Returns the art root. `icon` is the tile's icon
-- name (the locked look, and the fallback if a builder fails).
function Art.fill(well,id,ctx,w,h,locked,icon)
 local root=holder(well,w,h)
 root:SetAttribute("TileId",id);root:SetAttribute("Locked",locked==true)
 local ok,problem=true,nil
 if not locked and builders[id]then ok,problem=pcall(builders[id],root,w,h,ctx)end
 if locked or not ok or not builders[id]then
  if not ok then
   warn("MachineHubArt "..tostring(id)..": "..tostring(problem))
   root:ClearAllChildren()
  end
  local mark=Kit.icon(root,icon or "settings",math.floor(math.min(w,h)*.5),"dim");mark.AnchorPoint=Vector2.new(.5,.5);mark.Position=UDim2.fromScale(.5,.5)
  root:SetAttribute("Shows","icon")
 end
 return root
end
return Art
