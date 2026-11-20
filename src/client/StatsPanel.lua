-- v2 S3: the pet stats panel (V2-SCOPE-2026-11-19 sections 2, 3 and 9.1). Same frame as the
-- Companions hub (shade, 848x608 glass panel or the phone sheet, shared header) and its
-- preview well. Left: the pet, its Keeper tier, the total level and a bar to the next
-- Keeper tier. Right: six stat tiles in a fixed 3 x 2 grid (Heart, Power, Energy / Jump,
-- Speed, Smarts) and a detail strip saying what trains the selected stat.
-- Data is the snapshot's `petStats` ({pets = {[petId] = {xp, level, total}}, bonus}).
-- Focus is owned here: arrows / WASD / d-pad move, B / Backspace / Escape goes back.
-- A tap or A on a tile selects it (the detail strip follows the selection).
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local TextService=game:GetService("TextService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Catalog=require(Shared.StatCatalog)
local Pets=require(Shared.PetCatalog)
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local Hub=require(script.Parent.CompanionsHub)
-- v2 Stat Snacks: the pouch (a second view of the grid area, "Stats · Snacks") and the boost line.
local SnackTray=require(script.Parent.SnackTray)
local StatEggCatalog=require(Shared.StatEggCatalog)
-- v2 pet names: the title is "<name>'s stats" (the species while the pet has no name).
local NameText=require(script.Parent.PetNameText)
local Panel={}
Panel.__index=Panel
Panel.Cols=3
Panel.Order=Catalog.Order -- Heart, Power, Energy / Jump, Speed, Smarts
-- Pocket Buddies stat icons (assets/ui/stat-icons, asset-ids.json and icon-atlas-512x128.json; same
-- rects as the retired rune atlas).
Panel.Atlas="rbxassetid://113812710946093"
Panel.Tag2x="rbxassetid://91664096410906"
Panel.Icon={heart=Vector2.new(8,8),power=Vector2.new(80,8),energy=Vector2.new(152,8),jump=Vector2.new(224,8),speed=Vector2.new(296,8),smarts=Vector2.new(368,8)}
Panel.IconSmall={heart=Vector2.new(8,80),power=Vector2.new(40,80),energy=Vector2.new(72,80),jump=Vector2.new(104,80),speed=Vector2.new(136,80),smarts=Vector2.new(168,80)}
local TierKey={Seedling="seedling",Sprout="sprout",Bloom="bloom",["Full Bloom"]="fullBloom",Starbloom="starbloom"}

-- Pure: localised stat name, tier word and Keeper tier.
function Panel.statName(id)return UICopy.get("stats.name."..id)end
function Panel.tierWord(level)
 local name=Catalog.tier(level)
 return if TierKey[name]then UICopy.get("stats.tier."..TierKey[name])else name
end
function Panel.keeperWord(total)
 if total>=Catalog.GardenStarTotal then return UICopy.get("stats.gardenStar")end
 local name=Catalog.Tiers[1].name
 for _,tier in ipairs(Catalog.Tiers)do if total>=tier.total then name=tier.name end end
 return UICopy.get("stats.keeper",{name=if TierKey[name]then UICopy.get("stats.tier."..TierKey[name])else name})
end
-- Pure: the next Keeper tier above `total` ({name, total, from}) or nil at Garden Star.
function Panel.nextKeeper(total)
 local from=0
 for _,tier in ipairs(Catalog.Tiers)do
  if total<tier.total then return{name=Panel.keeperWord(tier.total),total=tier.total,from=from}end
  from=tier.total
 end
 if total<Catalog.GardenStarTotal then return{name=UICopy.get("stats.gardenStar"),total=Catalog.GardenStarTotal,from=from}end
 return nil
end
-- Pure: the view model for one pet. `petStats` is the snapshot field (may be nil).
-- Returns {stats = {{id, level, xp, into, need, tier, bonus}...} in Panel.Order, total}.
function Panel.model(petStats,petId)
 local entry=type(petStats)=="table"and type(petStats.pets)=="table"and petStats.pets[petId]or nil
 local bonus=type(petStats)=="table"and type(petStats.bonus)=="table"and petStats.bonus or {}
 local xp=entry and type(entry.xp)=="table"and entry.xp or {}
 local boosts=entry and type(entry.boosts)=="table"and entry.boosts or {}
 local out={stats={},total=0,known=entry~=nil,boosts=boosts}
 for _,id in ipairs(Panel.Order)do
  local p=Catalog.progress(tonumber(xp[id])or 0)
  local left=tonumber(bonus[id])or 0
  local b=boosts[id]
  table.insert(out.stats,{id=id,level=p.level,xp=p.xp,into=p.into,need=p.need,tier=Panel.tierWord(p.level),bonus=math.max(0,math.floor(left)),
   boost=if type(b)=="table"and type(b.mult)=="number"and type(b.left)=="number"then b else nil})
  out.total+=p.level
 end
 return out
end
-- Pure: "2x · 80 XP left" (and "+120" for boosts queued behind it), or nil.
function Panel.boostText(stat)
 local b=stat and stat.boost;if not b then return nil end
 local more=math.max(0,(b.queued or b.left)-b.left)
 if more>0 then return UICopy.get("stats.boostMore",{mult=b.mult,count=b.left,more=more})end
 return UICopy.get("stats.boost",{mult=b.mult,count=b.left})
end
-- Pure: grid focus movement over Panel.Cols columns.
function Panel.step(index,dx,dy,count)return Hub.step(index,dx,dy,count or #Panel.Order,Panel.Cols)end
-- Pure: "83 XP to 42", or the top-level line.
function Panel.toNext(stat)
 if stat.need<=0 then return UICopy.get("stats.max")end
 return UICopy.get("stats.toNext",{count=stat.need-stat.into,target=stat.level+1})
end

local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
-- A stat icon (64 px sprite, or the 24 px chip at 24 px and under).
function Panel.icon(parent,id,size)
 local small=size<=24
 local image=Kit.node("ImageLabel",parent,{Name="Icon_"..id,BackgroundTransparency=1,Image=Panel.Atlas,
  ImageRectOffset=(if small then Panel.IconSmall else Panel.Icon)[id]or Vector2.zero,ImageRectSize=if small then Vector2.new(24,24)else Vector2.new(64,64),
  Size=UDim2.fromOffset(size,size),ZIndex=parent.ZIndex+1,Active=false})
 return image
end
-- A stat bar: well track, fill in the stat colour.
local function bar(parent,x,y,w,h,color)
 local track=Kit.frame(parent,"Bar","well",UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),999);Kit.stroke(track)
 local fill=Kit.frame(track,"Fill",nil,UDim2.new(),UDim2.new(0,0,1,0),999);fill.BackgroundTransparency=0;fill.BackgroundColor3=color
 Kit.node("UISizeConstraint",fill,{MinSize=Vector2.new(h,0)})
 return{root=track,fill=fill,set=function(ratio,animate)
  ratio=math.clamp(ratio or 0,0,1);fill.Visible=ratio>0
  local goal=UDim2.new(ratio,0,1,0)
  if animate and not Kit.reduced()then fill.Size=UDim2.new(0,0,1,0);Kit.tween(fill,Kit.Motion.progress,{Size=goal})else fill.Size=goal end
 end}
end
-- "2x BONUS" tag: the 2x sticker art and the word beside it (translatable).
local function bonusTag(parent,h)
 local holder=Kit.frame(parent,"Bonus",nil,UDim2.new(),UDim2.fromOffset(10,h))
 local tag=Kit.node("ImageLabel",holder,{Name="Tag2x",BackgroundTransparency=1,Image=Panel.Tag2x,Size=UDim2.fromOffset(math.floor(h*4/3),h),ZIndex=holder.ZIndex+1})
 local word=Kit.text(holder,"Label",UICopy.get("stats.bonus"),"accent",{Name="Word",TextSize=if h<22 then 11 else 12})
 local ww=math.ceil(Kit.measure(word.Text,"Label",word.TextSize).X)+2
 word.Position=UDim2.fromOffset(tag.Size.X.Offset+2,0);word.Size=UDim2.fromOffset(ww,h)
 holder.Size=UDim2.fromOffset(tag.Size.X.Offset+2+ww,h)
 holder:SetAttribute("FullWidth",tag.Size.X.Offset+2+ww);holder:SetAttribute("TagWidth",tag.Size.X.Offset)
 return holder,word
end
-- Pure: where the bonus tag goes in a tile and whether its word fits. Desktop: after the tier
-- word; phone: bottom left, beside the "XP to" line. `room` is the free width there.
function Panel.bonusFit(fullW,tagW,room)
 if fullW<=room then return true,true end
 return tagW<=room,false
end

-- host: a full-screen Frame. callbacks: appearance(petId) -> appearance, back(from), closed(reason).
function Panel.new(host,callbacks)
 local self=setmetatable({host=host,callbacks=callbacks or {},index=1,visible=false,ctx={wallet=0,state={},activeId=nil}},Panel)
 self.shade=Kit.modalShade(host,"StatsShade",30)
 local root=Kit.frame(host,"StatsPanel","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(848,608),30)
 root.AnchorPoint=Vector2.new(.5,.5);root.Active=true;root.ClipsDescendants=true;root.ZIndex=31;root.Visible=false;self.rootStroke=Kit.stroke(root)
 local gradient=Kit.frame(root,"Gradient",nil,UDim2.new(),UDim2.fromScale(1,1));gradient.BackgroundTransparency=0;gradient.BackgroundColor3=Color3.new(1,1,1)
 Kit.node("UIGradient",gradient,{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(0,0,0)),Transparency=NumberSequence.new(.97,.88)})
 self.gradient=gradient;self.root=root
 self.scale=Kit.node("UIScale",root,{Scale=1})
 return self
end
-- The preview well is the Companions hub's (same ViewportFrame set-up and camera fit).
Panel.buildWell=Hub.buildWell
Panel.paintPreview=Hub.paintPreview
Panel.appearanceOf=Hub.appearanceOf

function Panel:petId()return self.petOverride or self.ctx.activeId or Hub.firstOwned(self.ctx.state)end
function Panel:viewModel()return Panel.model(self.ctx.state and self.ctx.state.petStats,self:petId())end

function Panel:build(view)
 if self.content then self.content:Destroy()end
 if self.ring then self.ring.hide();self.ring.root:Destroy();self.ring=nil end
 if self.visual then self.visual:destroy();self.visual=nil end
 self.world=nil
 self.view=view;self.key=if view then string.format("%dx%d",view.W,view.H)else "regular"
 local root=self.root;local phone=view~=nil
 root.BackgroundTransparency=if phone then 1 else 0;self.gradient.Visible=not phone;self.rootStroke.Enabled=not phone;root.ClipsDescendants=not phone
 Kit.setShadeAlpha(self.shade,Kit.ShadeAlpha)
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
 self.header=Kit.header(body,{title=UICopy.get("stats.title",{pet=(NameText.own(self.ctx.state,self:petId()))}),eyebrow=UICopy.get("stats.eyebrow"),tint="companions",
  compact=phone,width=W,left=if phone then view.hx else 24,onBack=function()self:back()end})
 self.header.root.Name="StatsHeader"
 if self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
 self:buildLeft(body,W,H,phone)
 self:buildGrid(body,W,H,phone)
 if not phone then
  local hints=Kit.frame(content,"Hints",nil,UDim2.fromOffset(24,566),UDim2.fromOffset(400,24))
  local x=0
  for _,pair in ipairs({{"+",UICopy.get("stats.hint.browse")},{"B",UICopy.get("stats.hint.back")}})do
   local g=Kit.glyph(hints,pair[1],false,22,true);g.Position=UDim2.fromOffset(x,1)
   txt(hints,"Small",pair[2],"soft",x+28,0,120,24).AutomaticSize=Enum.AutomaticSize.X
   x+=28+TextService:GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
  end
  txt(content,"Small",UICopy.get("stats.footer"),"dim",324,566,500,24,{Name="Promise",TextXAlignment=Enum.TextXAlignment.Right})
 end
 self.ring=Kit.focusRing(self.root)
 self:paint(false)
end

function Panel:buildLeft(body,W,H,phone)
 local pane=Kit.card(body,"PetPane",nil,{pad=16,seam=not phone})
 local pw,ph,pad
 if phone then pw=if W>=760 then 176 else 156;ph=H-84;pad=10;pane.Position=UDim2.fromOffset(20,64)
 else pw,ph,pad=272,452,16;pane.Position=UDim2.fromOffset(24,84)end
 pane.Size=UDim2.fromOffset(pw,ph);self.leftW=pw
 local wellH=if phone then math.max(60,ph-pad-84)else 300
 local well=self:buildWell(pane,pad,pad,pw-pad*2,wellH)
 self.previewWell=well
 local chip=Kit.chip(well,"",nil,if phone then 22 else 26);chip.root.AnchorPoint=Vector2.new(0,1);chip.root.Position=UDim2.fromOffset(8,wellH-8)
 chip.root.ZIndex=well.ZIndex+4;chip.label.ZIndex=chip.root.ZIndex+1;self.keeperChip=chip
 local y=pad+wellH+(if phone then 4 else 16)
 self.totalLabel=txt(pane,"Label",UICopy.get("stats.total"),"dim",pad,y,pw-pad*2,16,{TextSize=if phone then 11 else 13})
 y+=if phone then 14 else 20
 self.totalValue=txt(pane,"CounterL","","text",pad,y,120,if phone then 26 else 44,{Name="TotalLevel",TextSize=if phone then 22 else 38})
 self.totalOf=txt(pane,"Counter","","dim",pad+60,y,100,if phone then 26 else 44,{Name="TotalOf",TextSize=if phone then 12 else 16})
 y+=if phone then 28 else 52
 self.keeperBar=bar(pane,pad,y,pw-pad*2,if phone then 6 else 10,Kit.color("accent"))
 Kit.paint(self.keeperBar.fill,"BackgroundColor3","accent")
 y+=if phone then 9 else 18
 self.keeperLine=txt(pane,"Small","","soft",pad,y,pw-pad*2,if phone then 14 else 20,{Name="NextKeeper",TextSize=if phone then 11 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
end

function Panel:buildGrid(body,W,H,phone)
 local gx,gy,gw,gap,detailH
 if phone then gx=20+self.leftW+12;gy=64;gw=W-20-gx;gap=8;detailH=54
 else gx,gy,gw,gap,detailH=312,84,512,12,116 end
 local bottom=if phone then H-20 else 536
 local detailY=bottom-detailH
 local tileW=math.floor((gw-gap*(Panel.Cols-1))/Panel.Cols)
 local tileH=math.floor((detailY-gap-gy-gap)/2)
 self.tiles={}
 for index,id in ipairs(Panel.Order)do
  local col,row=(index-1)%Panel.Cols,math.floor((index-1)/Panel.Cols)
  local color=Catalog.ById[id].color
  local button,state=Kit.tile(body,"Stat_"..id,{selectable=false,radius=12,compact=phone,
   position=UDim2.fromOffset(gx+col*(tileW+gap),gy+row*(tileH+gap)),size=UDim2.fromOffset(tileW,tileH)})
  button:SetAttribute("StatId",id)
  local e={id=id,button=button,state=state,color=color}
  local p=if phone then 10 else 14
  local iconSize=if phone then 28 else 34
  e.icon=Panel.icon(button,id,iconSize);e.icon.Position=UDim2.fromOffset(p-2,p-4)
  local levelW=if phone then 46 else 62
  e.level=txt(button,"CounterL","","text",tileW-p-levelW,p-6,levelW,if phone then 30 else 40,{Name="Level",TextSize=if phone then 24 else 32,TextXAlignment=Enum.TextXAlignment.Right})
  if phone then
   local nx=p+iconSize+6
   e.name=txt(button,"Strong",Panel.statName(id),"text",nx,p-4,tileW-nx-levelW-p,20,{Name="StatName",TextSize=15,TextTruncate=Enum.TextTruncate.AtEnd})
   -- Toy Shell 3.8: stat tiles are cream keys; the stat's colour stays on its stone and bar,
   -- and words on cream are soft ink (stat colours never carry text on cream).
   e.tier=txt(button,"Label","","soft",nx,p+16,tileW-nx-p,14,{Name="Tier",TextSize=11})
   e.tierX,e.tierY,e.tagH=nx,p+14,18
   -- Short phones (under 84 px tiles): the tier word gives its row to the bar.
   e.tier.Visible=tileH>=84
  else
   e.name=txt(button,"Heading",Panel.statName(id),"text",p,p+36,tileW-p*2,24,{Name="StatName",TextSize=19,TextTruncate=Enum.TextTruncate.AtEnd})
   e.tier=txt(button,"Label","","soft",p,p+62,tileW-p*2,16,{Name="Tier",TextSize=12})
   e.tierX,e.tierY,e.tagH=p,p+59,22
  end
  e.bonus,e.bonusWord=bonusTag(button,e.tagH);e.bonus.Visible=false
  -- The boost line ("2x · 80 XP left") with its small flame, in the stat's colour. Phones show
  -- it in the tier word's place.
  if not phone then
   e.boostLine=txt(button,"Label","","soft",p,p+82,tileW-p*2,16,{Name="Boost",TextSize=12,Visible=false,TextTruncate=Enum.TextTruncate.AtEnd})
  end
  e.tileW,e.tileH,e.pad,e.phone=tileW,tileH,p,phone
  e.bar=bar(button,p,tileH-(if phone then 32 else 40),tileW-p*2,if phone then 7 else 9,color)
  e.toNext=txt(button,"Counter","","soft",p,tileH-(if phone then 22 else 28),tileW-p*2,if phone then 16 else 20,{Name="ToNext",TextSize=if phone then 11 else 13,TextXAlignment=Enum.TextXAlignment.Right})
  self.tiles[index]=e
  button.Activated:Connect(function()self:select(index,true)end)
 end
 -- Detail strip: the selected stat's icon, name and what trains it.
 local strip=Kit.card(body,"Detail",nil,{pad=12});strip.Position=UDim2.fromOffset(gx,detailY);strip.Size=UDim2.fromOffset(gw,detailH)
 self.detail=strip
 local snackW=if phone then 92 else 140
 if phone then
  self.detailIcon=nil;self.detailIconAt={x=10,y=11,size=24}
  self.detailName=txt(strip,"Strong","","text",42,3,180,20,{Name="DetailName",TextSize=14})
  self.detailBonus=txt(strip,"Small","","accent",200,3,gw-210-snackW,20,{Name="DetailBonus",TextSize=11,TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd})
  self.detailLine=txt(strip,"Small","","soft",42,21,gw-52-snackW,30,{Name="DetailLine",TextSize=11,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,TextTruncate=Enum.TextTruncate.AtEnd})
 else
  self.detailIconAt={x=16,y=16,size=44}
  self.detailName=txt(strip,"Heading","","text",72,14,240,26,{Name="DetailName",TextSize=20})
  self.detailBonus=txt(strip,"Small","","accent",260,16,gw-276-snackW,22,{Name="DetailBonus",TextSize=13,TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd})
  self.detailLine=txt(strip,"Body","","soft",72,44,gw-88-snackW,detailH-52,{Name="DetailLine",TextSize=15,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
 end
 -- "Snacks · 3" opens the pouch view in place of the grid (X on a gamepad).
 local snackH=if phone then 40 else 44
 local snacks=Kit.button(strip,"SnacksButton",{text=UICopy.get("stats.snacks.open"),glyph="X",showGlyph=false,size=Vector2.new(snackW-12,snackH),selectable=false})
 snacks.Position=UDim2.fromOffset(gw-snackW,math.floor((detailH-snackH)/2))
 for _,d in ipairs(snacks:GetDescendants())do if d:IsA("GuiObject")then d.ZIndex+=2 end end
 snacks.Activated:Connect(function()self:setMode("snacks")end)
 self.snacksButton=snacks
 self:buildSnacks(body,gx,gy,gw,bottom-gy,phone)
end

-- The Snacks view: the pouch tray, today's eggs and the way to Hatch eggs. It feeds in place:
-- the pet in the preview well eats (V2-FEEDING-RUNES 2), and the well is the drop target.
function Panel:buildSnacks(body,x,y,w,h,phone)
 local view=Kit.card(body,"SnacksView",nil,{pad=12});view.Position=UDim2.fromOffset(x,y);view.Size=UDim2.fromOffset(w,h);view.Visible=false
 self.snackView=view
 local pad=if phone then 10 else 16
 local trayH=if phone then 128 else 150
 local trayHost=Kit.frame(view,"TrayHost",nil,UDim2.fromOffset(pad,pad),UDim2.fromOffset(w-pad*2,trayH))
 if self.tray then self.tray:destroy()end
 self.tray=SnackTray.new(trayHost,{compact=phone,carryLayer=self.root,
  petName=function()local pet=Pets.byId[self:petId()];return pet and pet.name or "Bear"end,
  dropTarget=function()local well=self.previewWell;if well and well.Parent then return well.AbsolutePosition,well.AbsoluteSize end;return nil end,
  onFeed=function(group)return self:feedGroup(group)end})
 local ey=pad+trayH+(if phone then 4 else 12)
 self.eggLine=txt(view,"Small","","soft",pad,ey,w-pad*2,if phone then 16 else 20,{Name="EggLine",TextSize=if phone then 11 else 14,TextTruncate=Enum.TextTruncate.AtEnd})
 local bh=if phone then 40 else 48
 local by=h-pad-bh
 local back=Kit.button(view,"StatsBack",{text=UICopy.get("stats.snacks.back"),glyph="B",showGlyph=false,size=Vector2.new(if phone then 96 else 140,bh),selectable=false})
 back.Position=UDim2.fromOffset(pad,by);back.Activated:Connect(function()self:setMode("stats")end)
 local eggW=if phone then 150 else 200
 local eggs=Kit.button(view,"GoHatch",{text=UICopy.get("stats.snacks.eggs"),glyph="Y",showGlyph=false,size=Vector2.new(eggW,bh),selectable=false})
 eggs.Position=UDim2.fromOffset(w-pad-eggW,by);eggs.Activated:Connect(function()self:openEggs()end)
 for _,b in ipairs({back,eggs})do for _,d in ipairs(b:GetDescendants())do if d:IsA("GuiObject")then d.ZIndex+=2 end end end
 self.snackBack,self.snackEggs=back,eggs
 self:setMode(self.mode or "stats",true)
end
function Panel:openEggs()
 if not self.callbacks.openEggs then return end
 self:close("eggs");self.callbacks.openEggs()
end
-- Pure: why this panel can't feed right now (Feed greys with one line), or nil. The server
-- checks again; this is only the hint.
function Panel.feedLock(ctx,petId)
 local name=(Pets.byId[petId]or{name="Bear"}).name
 if ctx and ctx.activeId~=nil and petId~=ctx.activeId then return UICopy.get("stats.snacks.reason.PetNotOut",{pet=name})end
 if ctx and ctx.inRound then return UICopy.get("stats.snacks.reason.InRound",{pet=name})end
 return nil
end
function Panel:snackModel()
 local state=self.ctx.state or {}
 local egg=type(state.statEgg)=="table"and state.statEgg or {}
 local m=self.lastModel or self:viewModel()
 return{pouch=egg.pouch or {},boosts=m.boosts,total=egg.pouchSize or StatEggCatalog.PouchSize,locked=Panel.feedLock(self.ctx,self:petId()),select=self.pickSnack}
end
function Panel:paintSnackButton()
 if not self.snacksButton then return end
 local egg=type((self.ctx.state or {}).statEgg)=="table"and self.ctx.state.statEgg or {}
 local n=#(egg.pouch or {})
 Kit.setText(self.snacksButton,if n>0 then UICopy.get("stats.snacks.open").." · "..n else UICopy.get("stats.snacks.open"))
end
function Panel:paintSnacks()
 if not self.tray then return end
 self.tray:set(self:snackModel());self.pickSnack=nil
 if self.feeding then self.tray:setBusy(true)end
 self.eggLine.Text=require(script.Parent.StatEggOdds).stockLine(self.ctx.state or {})
 self:paintSnackButton()
end
function Panel:setMode(mode,quiet)
 self.mode=if mode=="snacks"then "snacks"else "stats"
 local snacks=self.mode=="snacks"
 if self.snackView then self.snackView.Visible=snacks end
 for _,e in ipairs(self.tiles or {})do e.button.Visible=not snacks end
 if self.detail then self.detail.Visible=not snacks end
 if self.ring then if snacks then self.ring.hide()else self:paintSelection()end end
 self.root:SetAttribute("StatsMode",self.mode)
 if snacks then self:paintSnacks()end
 if not quiet and snacks and self.snackView then Kit.boing(self.snackView)end
end
function Panel:feedGroup(group)
 if self.feeding or not group or not group.ids[1]or not self.callbacks.feed then return false end
 local accepted=self.callbacks.feed(group.ids[1],{visual=self.visual,overlay=self.previewWell,onBusy=function(busy)
  self.feeding=busy==true
  if self.tray then self.tray:setBusy(busy)end
 end})
 return accepted==true
end

-- Paint values (no rebuild). `animate`: the bars fill from empty (screen open).
function Panel:paint(animate)
 if not self.tiles then return end
 local m=self:viewModel()
 self.lastModel=m
 for index,e in ipairs(self.tiles)do
  local s=m.stats[index]
  e.level.Text=tostring(s.level)
  e.tier.Text=string.upper(s.tier)
  local tw=math.ceil(Kit.measure(e.tier.Text,"Label",e.tier.TextSize).X)
  e.bar.set(if s.need>0 then s.into/s.need else 1,animate)
  e.toNext.Text=Panel.toNext(s)
  -- The 2x tag never runs into the level, the tile edge or the "XP to" line (667 px phones).
  local fullW,tagW=e.bonus:GetAttribute("FullWidth"),e.bonus:GetAttribute("TagWidth")
  local x,y,room
  if e.phone then
   local nextW=math.ceil(Kit.measure(e.toNext.Text,"Counter",e.toNext.TextSize).X)
   x,y=e.pad,e.tileH-(e.tagH+5);room=e.tileW-e.pad*2-nextW-6
  else x,y=e.tierX+tw+8,e.tierY;room=e.tileW-e.pad-x end
  local show,word=Panel.bonusFit(fullW,tagW,room)
  e.bonus.Visible=s.bonus>0 and s.need>0 and show
  e.bonusWord.Visible=word
  e.bonus.Position=UDim2.fromOffset(x,y)
  local boost=Panel.boostText(s)
  if e.boostLine then e.boostLine.Text=if boost then "▲ "..boost else "";e.boostLine.Visible=boost~=nil
  elseif boost then e.tier.Text="▲ "..string.upper(boost)end
  e.button:SetAttribute("Boost",boost or "")
  e.button:SetAttribute("AccessibleLabel",string.format("%s %d, %s",Panel.statName(s.id),s.level,Panel.toNext(s))..(if boost then ", "..boost else ""))
  e.button:SetAttribute("Level",s.level)
 end
 self.totalValue.Text=tostring(m.total)
 local tw=math.ceil(Kit.measure(self.totalValue.Text,"CounterL",self.totalValue.TextSize).X)
 self.totalOf.Text=UICopy.get("stats.of",{total=Catalog.GardenStarTotal});self.totalOf.Position=UDim2.new(0,self.totalValue.Position.X.Offset+tw+6,0,self.totalValue.Position.Y.Offset+(if self.view then 4 else 8))
 self.keeperChip.set(Panel.keeperWord(m.total),nil);Kit.paint(self.keeperChip.label,"TextColor3","accent")
 local nextTier=Panel.nextKeeper(m.total)
 if nextTier then
  self.keeperBar.set((m.total-nextTier.from)/math.max(1,nextTier.total-nextTier.from),animate)
  self.keeperLine.Text=UICopy.get("stats.nextKeeper",{name=nextTier.name,count=nextTier.total})
 else self.keeperBar.set(1,false);self.keeperLine.Text=UICopy.get("stats.topKeeper")end
 self.root:SetAttribute("TotalLevel",m.total);self.root:SetAttribute("PetId",self:petId())
 self:paintSelection()
 if self.mode=="snacks"then self:paintSnacks()else self:paintSnackButton()end
end
function Panel:paintSelection()
 if not self.tiles or self.mode=="snacks"then return end
 self.index=math.clamp(self.index,1,#self.tiles)
 for index,e in ipairs(self.tiles)do e.state.setSelected(index==self.index,false)end
 local m=self.lastModel or self:viewModel()
 local s=m.stats[self.index];local id=s.id
 if self.detailIcon then self.detailIcon:Destroy()end
 local at=self.detailIconAt
 self.detailIcon=Panel.icon(self.detail,id,at.size);self.detailIcon.Position=UDim2.fromOffset(at.x,at.y)
 self.detailName.Text=Panel.statName(id);Kit.paint(self.detailName,"TextColor3","text") -- Toy Shell 3.8: the stone beside it carries the colour (Heart pink measured 4.3:1 on a tray)
 self.detailLine.Text=UICopy.get("stats.train."..id)
 self.detailBonus.Text=if s.need<=0 then ""elseif s.bonus>0 then UICopy.get("stats.bonusLeft",{count=s.bonus})else UICopy.get("stats.bonusUsed")
 Kit.paint(self.detailBonus,"TextColor3",if s.bonus>0 then "accent"else "dim")
 self.root:SetAttribute("SelectedStat",id)
 local e=self.tiles[self.index]
 if self.ring and e then self.ring.attach(e.button,12)end
end
function Panel:select(index,tapped)
 local was=self.index
 self.index=math.clamp(index,1,#Panel.Order)
 self:paintSelection()
 if tapped and self.tiles and self.tiles[self.index]and was~=self.index then Kit.boing(self.tiles[self.index].button)end
end
function Panel:move(dx,dy)
 local nextIndex=Panel.step(self.index,dx,dy)
 if nextIndex==self.index then return false end
 self:select(nextIndex);return true
end

function Panel:fit(size)
 if Kit.compactRule(size.X,size.Y)then
  local _,kh=Kit.keepOut();local top=kh+2
  local view={phone=true,W=math.floor(size.X),H=math.floor(size.Y)-top,hx=24}
  self.root.AnchorPoint=Vector2.zero;self.root.Position=UDim2.fromOffset(0,top);self.root.Size=UDim2.fromOffset(view.W,view.H);self.scale.Scale=1
  if self.key~=string.format("%dx%d",view.W,view.H)then self:build(view)end
  return
 end
 self.root.AnchorPoint=Vector2.new(.5,.5);self.root.Size=UDim2.fromOffset(848,608)
 if self.key~="regular"then self:build(nil)end
 self.root.Position=UDim2.fromScale(.5,.5)
 self.scale.Scale=math.max(.1,math.min(1.2,(size.X-24)/848,(size.Y-24)/608))
end
function Panel:setContext(ctx)
 if ctx.wallet then self.ctx.wallet=ctx.wallet end
 if ctx.state then self.ctx.state=ctx.state end
 if ctx.activeId~=nil then self.ctx.activeId=ctx.activeId end
 if ctx.inRound~=nil then self.ctx.inRound=ctx.inRound end
 if self.visible then
  if self.header and self.header.wallet then self.header.wallet.set(self.ctx.wallet or 0)end
  self:paint(false)
  if self.visual then self:paintPreview(self:petId())end
 end
end
function Panel:back()
 local from=self.from
 self:close("back")
 if self.callbacks.back then self.callbacks.back(from)end
 return "close"
end
function Panel:input(key)
 local K=Enum.KeyCode
 if self.mode=="snacks"then
  if key==K.ButtonB or key==K.Backspace or key==K.Escape or key==K.ButtonX then self:setMode("stats")
  elseif key==K.ButtonY then self:openEggs()
  elseif self.tray then self.tray:input(key)end
  return
 end
 if key==K.ButtonX then self:setMode("snacks");return end
 if key==K.Left or key==K.A or key==K.DPadLeft then self:move(-1,0)
 elseif key==K.Right or key==K.D or key==K.DPadRight then self:move(1,0)
 elseif key==K.Up or key==K.W or key==K.DPadUp then self:move(0,-1)
 elseif key==K.Down or key==K.S or key==K.DPadDown then self:move(0,1)
 elseif key==K.ButtonB or key==K.Backspace or key==K.Escape then self:back()
 elseif key==K.Return or key==K.KeypadEnter or key==K.Space or key==K.ButtonA then
  local e=self.tiles and self.tiles[self.index];if e then Kit.boing(e.button)end
 end
end
function Panel:isOpen()return self.visible end
-- options: stat (an id to select), petId, from ("hub" | "focus" | "rail" | ...).
function Panel:open(ctx,options)
 options=options or {}
 if ctx then
  if ctx.wallet then self.ctx.wallet=ctx.wallet end
  if ctx.state then self.ctx.state=ctx.state end
  if ctx.activeId~=nil then self.ctx.activeId=ctx.activeId end
 end
 self.petOverride=options.petId;self.from=options.from
 self.mode=if options.snacks then "snacks"else "stats";self.pickSnack=options.snack
 local feedNow=if options.feedNow then options.snack else nil
 self.index=table.find(Panel.Order,options.stat or "")or self.index or 1
 self.visible=true;self.root.Visible=true;self.key=nil
 Kit.shadeOpen(self,self.shade,function(covered)if self.visible then self.root.Visible=not covered end end)
 self:fit(self.host.AbsoluteSize)
 self:setMode(self.mode,true)
 self:paint(true)
 self:paintPreview(self:petId())
 if options.slideFrom and self.body then Kit.slideIn(self.body,options.slideFrom,Kit.headerSkip(self.header))
 elseif not self.view and not Kit.reduced()then
  self.root.Position=UDim2.new(.5,0,.5,8);Kit.tween(self.root,Kit.Motion.screen,{Position=UDim2.fromScale(.5,.5)})
 end
 if self.clock then self.clock:Disconnect()end
 self.clock=RunService.RenderStepped:Connect(function(dt)
  if not self.visible then return end
  local v=self.visual
  if v and not v.destroyed and not GuiService.ReducedMotionEnabled then v.cosmeticTime=os.clock();v:update(math.min(dt,.1))end
  -- The eating sequence poses on top of this frame's pose (with Reduced Motion too: one bite).
  -- Stepped even without a preview pet, so a feed always finishes (code review).
  if self.callbacks.step then self.callbacks.step(math.min(dt,.1))end
 end)
 -- "Feed now" from the Stat Egg reveal: feed that snack once the preview pet exists.
 if feedNow then
  -- Wait (up to about a second) for the preview pet, so the bites show (code review).
  task.spawn(function()
   for _=1,60 do
    if not self.visible or self.mode~="snacks"or not self.tray then return end
    if self.visual and not self.visual.destroyed then break end
    RunService.Heartbeat:Wait()
   end
   if not self.visible or self.mode~="snacks"or not self.tray then return end
   for _,g in ipairs(self.tray.groups)do if table.find(g.ids,feedNow)then
    self:feedGroup({key=g.key,stat=g.stat,size=g.size,count=g.count,known=g.known,ids={feedNow}});break
   end end
  end)
 end
 self.sizeConnection=self.sizeConnection or self.host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
  if self.visible then local key=self.key;self:fit(self.host.AbsoluteSize);if self.key~=key then self:paintPreview(self:petId())end end
 end)
 return true
end
function Panel:close(reason)
 if not self.visible then return false end
 self.visible=false;self.root.Visible=false;Kit.shadeClose(self);if self.ring then self.ring.hide()end
 if self.callbacks.cancelFeed then self.callbacks.cancelFeed()end
 if self.clock then self.clock:Disconnect();self.clock=nil end
 if self.visual then self.visual:destroy();self.visual=nil end
 if self.callbacks.closed then self.callbacks.closed(reason,self.from)end
 return true
end
function Panel:destroy()self:close("destroy");if self.sizeConnection then self.sizeConnection:Disconnect()end;self.root:Destroy();self.shade:Destroy()end
return Panel
