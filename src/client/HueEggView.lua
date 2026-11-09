-- One explicit saved-color shop. Two stopped rigs; no render clock or hatch ack.
local GuiService=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Hues=require(Shared.HueCatalog)
local Eggs=require(Shared.EggCatalog)
local Pets=require(Shared.PetCatalog)
local Palette=require(Shared.PetPalette)
local Art=require(script.Parent.DeckArt)
local EggArt=require(script.Parent.EggArt)
local Factory=require(script.Parent.PetFactory)
local Bounds=require(script.Parent.PetRigBounds)
local Stars=require(script.Parent.StarText)
local View={};View.__index=View
local function direction(id)return Hues.ById[id].direction end
local function place(n,x,y,w,h)n.Position,n.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)end
local function text(parent,name,copy,role)
 local n=Art.text(parent,name,copy,UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),"text",16)
 Art.type(n,role or "Body");n.TextXAlignment=Enum.TextXAlignment.Left;return n
end
local function button(parent,name,copy,callback)
 local n=Instance.new("TextButton");n.Name,n.Text,n.Parent=name,copy,parent;n.BorderSizePixel=0;n.ZIndex=parent.ZIndex+1
 Art.bind(n,{BackgroundColor3="raised",TextColor3="text"});Art.button(n,8);Art.type(n,"Action");n.Activated:Connect(callback);return n
end
local function preview(parent,name)
 local host=Art.frame(parent,name,"inset",UDim2.fromOffset(0,0),UDim2.fromOffset(180,180),parent.ZIndex+1);Art.corner(host,10)
 local title=text(host,"Label",name,"Supporting");title.TextXAlignment=Enum.TextXAlignment.Center
 local viewport=Instance.new("ViewportFrame");viewport.Name="Pet";viewport.BackgroundTransparency=1;viewport.BorderSizePixel=0;viewport.ZIndex=host.ZIndex+1;viewport.Parent=host
 viewport.Ambient=Color3.fromRGB(96,96,96);viewport.LightColor=Color3.fromRGB(168,168,168);viewport.LightDirection=Vector3.new(-1,-1.4,-3)
 local world=Instance.new("WorldModel");world.Parent=viewport
 local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
 local swatch=Art.frame(host,"BodySwatch",Art.Silver,UDim2.fromOffset(0,0),UDim2.fromOffset(14,14),host.ZIndex+2);Art.corner(swatch,3)
 return {host=host,title=title,viewport=viewport,world=world,camera=camera,swatch=swatch}
end
function View.new(parent,intent,options)
 local shade=Art.frame(parent,"HueEggView","ink",UDim2.fromScale(0,0),UDim2.fromScale(1,1),20);shade.Visible=false;shade.Active=true;shade.BackgroundTransparency=1
 local card=Art.frame(shade,"Card","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(680,580),21);card.AnchorPoint=Vector2.new(.5,.5);Art.panel(card,16)
 local body=Instance.new("ScrollingFrame");body.Name,body.Parent="Body",card;body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ZIndex=22
 body.ScrollingDirection,body.ElasticBehavior=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never;body.ScrollBarThickness=4;Art.bind(body,{ScrollBarImageColor3="accent"})
 local self=setmetatable({shade=shade,card=card,body=body,intent=intent,options=options or {},state={},petId="pip",hue="rose",page="buy",paletteKind="body",paletteChoice="original",targets={},offers={},bodyChoices={},secondaryChoices={},previewKey=nil,epoch=0},View)
 self.title=text(card,"Title","Hue Egg","Heading");self.wallet=text(card,"Wallet","0 Stars","Counter")
 self.walletHost=Art.frame(card,"WalletHost","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(120,44),22)
 self.wallet.Parent=self.walletHost
 self.walletStar=EggArt.stars(self.walletHost,UDim2.fromOffset(0,0),UDim2.fromOffset(18,24),23)
 self.closeButton=Art.bareClose(button(card,"Close","×",function()self:close("back")end))
 self.action=button(card,"Action","Hatch Hue Egg - 8 Stars",function()self:activate()end)
 self.mixChip=Art.frame(self.action,"MixResultSwatch",Art.Silver,UDim2.new(0,10,.5,0),UDim2.fromOffset(22,22),self.action.ZIndex+2)
 self.mixChip.AnchorPoint=Vector2.new(0,.5);self.mixChip.Visible=false;Art.corner(self.mixChip,5)
 for i,id in ipairs({"pip","puddle"})do self.targets[i]=button(body,"Target_"..id, Pets.byId[id].name,function()self:choosePet(id)end)end
 self.buyTab=button(body,"BuyTab","Hue Egg",function()self:setPage("buy")end)
 self.paletteTab=button(body,"PaletteTab","Colors",function()self:setPage("palette")end)
 self.paletteGroup="body";self.colorTabs={}
 for _,item in ipairs({{"body","Body"},{"secondary","Accents"},{"mix","Mix"}})do
  local key=item[1];self.colorTabs[key]=button(body,"ColorsTab_"..key,item[2],function()self:setColorsGroup(key)end)
 end
 self.current=preview(body,"Current");self.after=preview(body,"After")
 self.currentText=text(body,"CurrentPalette","","Body");self.quote=text(body,"Quote","","Body")
 self.offerTitle=text(body,"OfferTitle","Choose a direction","Action")
 for _,offer in ipairs(Hues.Order)do
  local id=offer.id;local n=button(body,"Offer_"..id,"",function()self:chooseHue(id)end)
  local icon=Art.frame(n,"HueSwatch",offer.color,UDim2.fromOffset(8,8),UDim2.fromOffset(32,36),n.ZIndex+2);Art.corner(icon,7);local title=text(n,"Name",offer.name,"Action");local rank=text(n,"Grades","○○○","Supporting")
  local swatch=Art.frame(n,"Swatch",offer.color,UDim2.fromOffset(0,0),UDim2.fromOffset(14,14),n.ZIndex+2);Art.corner(swatch,3)
  self.offers[id]={button=n,title=title,rank=rank,icon=icon,swatch=swatch}
  self.offers[id].ink=function()
   return Art.paletteColor(if n:GetAttribute("PrimaryAction")and n:GetAttribute("ActionEnabled")then "ink"elseif n:GetAttribute("ActionEnabled")==false then "muted"else "text")
  end
 end
 self.bodyTitle=text(body,"BodyTitle","Body · free saved choice","Action")
 self.secondaryTitle=text(body,"SecondaryTitle","Accents · independent free choice","Action")
 local function choice(kind,id,name)
  return button(body,kind.."_"..id,name,function()self:choosePalette(kind,id)end)
 end
 self.bodyChoices.original=choice("body","original","Original body")
 self.secondaryChoices.default=choice("secondary","default","Default accents")
 for _,offer in ipairs(Hues.Order)do self.bodyChoices[offer.id]=choice("body",offer.id,offer.direction.." body");self.secondaryChoices[offer.id]=choice("secondary",offer.id,offer.direction.." accents")end
 self.mixTitle=text(body,"MixTitle","Mix body - choose two learned bases","Action")
 self.mixChoices={};self.mixBases={}
 for _,offer in ipairs(Hues.Order)do
  local id=offer.id;self.mixChoices[id]=button(body,"Mix_"..id,offer.direction,function()self:chooseMix(id)end)
 end
 self.resetAction=button(body,"ResetColors","Reset to original colors",function()
  if self.resetAction.Interactable then self.intent:reset(self.petId)end
 end)
 self.generic=Art.frame(body,"GenericHueEgg","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(120,140),23);self.generic.BackgroundTransparency=1
 self.genericEgg=EggArt.create(self.generic,"meadow",UDim2.new(.5,-42,0,4),UDim2.fromOffset(84,108),24);self.genericEgg.Pattern:Destroy()
 for i,offer in ipairs(Hues.Order)do
  Art.frame(self.genericEgg,"Band_"..offer.id,offer.color,UDim2.fromScale(.19+(i-1)*.155,.51),UDim2.fromScale(.155,.16),29)
 end
 self.eggCaption=text(self.generic,"EggCaption","Hue Egg - 8 Stars","Body");self.eggCaption.TextXAlignment=Enum.TextXAlignment.Center
 self.receipt=text(body,"SavedReceipt","","Body")
 self.equipAccent=button(body,"EquipAccents","Equip accents",function()
  local r=self.intent.receipt
  if r and r.petId==self.petId and r.hue then self.intent:equip(self.petId,"secondary",r.hue)end
 end)
 self.status=text(body,"Status","","Body")
 shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if shade.Visible then self:layout()end end)
 Art.watchTextPreference(shade,function()return shade.Visible end,function()self:layout()end)
 shade.Destroying:Connect(function()self:destroy(true)end)
 return self
end
function View:isOpen()return self.shade.Visible end
function View:owned(id)return Eggs.isOwned(self.state.inventoryMask or 0,id)end
function View:choosePet(id)
 if self.intent.pending or not Hues.Supported[id]or not self:owned(id)then return false end
 self.petId=id;self.mixBases={};self.paletteKind,self.paletteGroup="body","body";self.paletteChoice=if self.paletteKind=="body"then Hues.get(self.state.hues,id).body else Hues.get(self.state.hues,id).secondary
 self:refresh();return true
end
function View:chooseHue(id)if self.intent.pending or not Hues.ById[id]then return false end;self.hue=id;self:refresh();return true end
function View:setPage(page)if self.intent.pending then return false end;self.page=page;self:refresh();return true end
function View:choosePalette(kind,id)
 if self.intent.pending then return false end
 local r=Hues.get(self.state.hues,self.petId)
 if id~="original"and id~="default"and(r.ranks[id]or 0)<1 then return false end
 self.paletteKind,self.paletteGroup,self.paletteChoice=kind,kind,id;self:refresh();return true
end
function View:setColorsGroup(group)
 if self.intent.pending or not self.colorTabs[group]then return false end
 local record=Hues.get(self.state.hues,self.petId)
 self.paletteGroup,self.paletteKind=group,group
 if group=="mix"then
  local mix=Hues.Mixes[record.mix];self.mixBases=if mix then{mix.a,mix.b}else{}
 else self.paletteChoice=record[group]end
 self.body.CanvasPosition=Vector2.zero;self:refresh();return true
end
function View:chooseMix(id)
 local record=Hues.get(self.state.hues,self.petId)
 if self.intent.pending or(record.ranks[id]or 0)<1 then return false end
 local at=table.find(self.mixBases,id)
 if at then table.remove(self.mixBases,at)
 else if #self.mixBases==2 then table.remove(self.mixBases,1)end;table.insert(self.mixBases,id)end
 self.paletteKind,self.paletteGroup="mix","mix";self:refresh();return true
end
function View:activate()
 if not self.shade.Visible or not self.action.Interactable then return false end
 if self.intent.status=="Retrying"then return self.intent:retry()end
 if self.page=="buy"then
  if self.state.heldHueEgg then return self.intent:apply(self.petId,self.hue)end
  local play=self.options.play or self.options.earn
  local ready=self.intent:ready()
  if ready and Hues.capacity(self.state)and(self.state.nectar or 0)<Hues.Cost and type(play)=="function"then
   self:close("earn");play();return true
  end
  return self.intent:hatch()
 end
 if self.paletteKind=="mix"then return self.intent:mix(self.petId,self.mixBases[1],self.mixBases[2])end
 return self.intent:equip(self.petId,self.paletteKind,self.paletteChoice)
end
function View:appearance(after)
 local token=Hues.appearance(self.state.hues,self.petId)
 local base=self.options.appearance and self.options.appearance(self.petId)
 token=table.clone(token);token.charmVisible=not(base and base.charmVisible==false)
 local record=Hues.get(self.state.hues,self.petId)
 if after then
  if self.page=="buy"and self.state.heldHueEgg then token.body=self.hue;token.bodyMix=nil;token.bodyRank=math.min(Hues.MaxRank,record.ranks[self.hue]+1)
  elseif self.page=="palette"then
   if self.paletteKind=="body"then token.body=self.paletteChoice;token.bodyMix=nil;token.bodyRank=record.ranks[token.body]or 0
   elseif self.paletteKind=="secondary"then token.secondary=self.paletteChoice
   elseif self.paletteKind=="mix"then
    local pair=Hues.pair(self.mixBases[1],self.mixBases[2]);local mix=Hues.Mixes[pair]
    if mix then token.bodyMix=pair;token.bodyRank=math.min(record.ranks[mix.a],record.ranks[mix.b])end
   end
  end
 end
 return token
end
function View:paintPreview()
 for _,item in ipairs({self.current,self.after})do
  local token=self:appearance(item==self.after)
  if item.petId~=self.petId then
   if item.visual then item.visual:destroy()end
   item.visual=Factory.new(item.world,Vector3.zero,Pets.byId[self.petId],nil,token)
   item.visual.idleMotionFrozen=true;item.visual.reducedEffects=true;item.visual.time=0;item.visual.greeting=2;item.visual.expression="neutral";item.petId=self.petId
  end
  item.visual:applyAppearance(token);item.visual:update(0)
  item.swatch.BackgroundColor3=Palette.resolve(self.petId,token).body
 end
 self:fitPreviews()
end
function View:fitPreviews()
 local item=self.current;if not item.visual then return end
 local key=item.petId..":"..tostring(item.visual.charmVisible)..":"..tostring(item.viewport.Size)
 if self.fitKey==key then return end;self.fitKey=key
 local cf,size=Bounds.getBody(item.visual);local center=cf.Position
 local full,body={},{}
 for _,entry in ipairs(item.visual.pieces)do if entry.part.Transparency<1 then
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
   local point=entry.part.CFrame:PointToWorldSpace(entry.part.Size*Vector3.new(x,y,z)*.5)
   table.insert(full,point);if entry.role~="charm"then table.insert(body,point)end
  end end end
 end end
 local aspect=math.max(.1,item.viewport.Size.X.Offset/math.max(1,item.viewport.Size.Y.Offset));local tan=math.tan(math.rad(15))
 local function projected(distance)
  local camera=CFrame.lookAt(center+Vector3.new(0,0,distance),center)
  local minimum,maximum=math.huge,-math.huge
  for _,point in ipairs(body)do local p=camera:PointToObjectSpace(point);local depth=-p.Z;if depth<=.01 then return math.huge,false end;local y=p.Y/(depth*tan);minimum,maximum=math.min(minimum,y),math.max(maximum,y)end
  for _,point in ipairs(full)do local p=camera:PointToObjectSpace(point);local depth=-p.Z
   if depth<=.01 or math.abs(p.X)/(depth*tan*aspect)>.92 or math.abs(p.Y)/(depth*tan)>.92 then return(maximum-minimum)*.5,false end
  end
  return(maximum-minimum)*.5,true
 end
 local low,high=.05,math.max(size.Magnitude,1)
 for _=1,16 do local fraction,safe=projected(high);if safe and fraction<=.64 then break end;high*=2 end
 for _=1,24 do local middle=(low+high)*.5;local fraction,safe=projected(middle);if safe and fraction<=.64 then high=middle else low=middle end end
 self.previewBodyFraction,self.previewContained=projected(high)
 self.current.camera.CFrame=CFrame.lookAt(center+Vector3.new(0,0,high),center);self.after.camera.CFrame=self.current.camera.CFrame
end
local function bodyName(token)
 local mix=Hues.Mixes[token.bodyMix]
 return if mix then mix.name.." "..token.bodyRank elseif token.body=="original"then "Original"else direction(token.body).." "..token.bodyRank
end
function View:refresh()
 self.state=self.intent.state or self.state
 local pending=self.intent.pending~=nil
 if self.pendingEpoch~=pending then self.pendingEpoch=pending;self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch)end
 if not self.shade.Visible then return end
 if self.state.lastHatch then self:close("pendingHatch");if self.options.pendingHatch then self.options.pendingHatch()end;return end
 local held=self.state.heldHueEgg;local assigning=self.page=="buy"and held~=nil
 local desktop=self.shade.AbsoluteSize.X>=760 and self.shade.AbsoluteSize.Y>=560
 local showPet=self.page=="palette"or assigning;local owned=self:owned(self.petId)
 local record=Hues.get(self.state.hues,self.petId);local rank=record.ranks[self.hue]
 self.wallet.Text=Stars.amount(self.state.nectar or 0);self.wallet:SetAttribute("AccessibleLabel",self.wallet.Text)
 local secondary=if record.secondary=="default"then "Default"else direction(record.secondary)
 self.current.title.Text="Current - "..bodyName(self:appearance(false)).." / "..secondary
 local afterToken=self:appearance(true)
 self.after.title.Text="Preview - "..bodyName(afterToken).." / "..(if afterToken.secondary=="default"then "Default"else direction(afterToken.secondary))
 self.currentText.Text="Saved body: "..bodyName(self:appearance(false)).." / Accent: "..secondary
 if self.page=="buy"then
  self.quote.Text=if assigning then(if rank>=3 then "Already at grade III. Your egg stays held."else direction(self.hue).." "..rank.." to "..(rank+1).." - uses your held egg, no more Stars. Accent stays "..secondary..".")
   else "Hatch first, then choose a hue and an owned baby. One use stays saved until you apply it."
 else
  local pair=Hues.pair(self.mixBases[1],self.mixBases[2]);local mix=Hues.Mixes[pair]
  self.quote.Text=if self.paletteKind=="mix"then(if mix then mix.name.." - equal parts - grade "..math.min(record.ranks[mix.a],record.ranks[mix.b]).." - free"else "Choose two different learned bases to preview a mix.")else "Preview a learned body or independent accent, then save for free."
 end
 self.generic.Visible=self.page=="buy";self.eggCaption.Text=if held then "Hatched - choose hue and baby"else "Hue Egg - 8 Stars"
 local crown=self.genericEgg.Shell.Crown;crown.Position=if held then UDim2.fromScale(.29,-.04)else UDim2.fromScale(.25,.08);crown.Rotation=if held then 14 else 0
 self.genericEgg.ShellGlint.Visible=not held
 self.current.host.Visible,self.after.host.Visible=showPet and owned,showPet and owned;self.currentText.Visible=showPet and owned and not desktop
 for i,id in ipairs({"pip","puddle"})do
  local n=self.targets[i];n.Visible=showPet and self:owned(id);n.Interactable=n.Visible and not pending;n.Selectable=n.Interactable;Art.control(n,id==self.petId,n.Interactable)
 end
 for id,entry in pairs(self.offers)do
  local grade=record.ranks[id];entry.button.Visible=assigning;entry.title.Text=Hues.ById[id].direction
  entry.rank.Text=grade.." / III learned"
  entry.button:SetAttribute("AccessibleLabel",Hues.ById[id].direction..", grade "..grade.." of 3")
  entry.button.Interactable=not pending;entry.button.Selectable=entry.button.Interactable;Art.control(entry.button,id==self.hue,entry.button.Interactable)
  Art.bind(entry.title,{TextColor3=entry.ink});Art.bind(entry.rank,{TextColor3=entry.ink})
 end
 for kind,choices in pairs({body=self.bodyChoices,secondary=self.secondaryChoices})do for id,n in pairs(choices)do
  n.Visible=self.page=="palette"and self.paletteGroup==kind;local unlocked=id=="original"or id=="default"or(record.ranks[id]or 0)>0
  n.Interactable=owned and unlocked and not pending;n.Selectable=n.Interactable
  n:SetAttribute("SavedSelection",record[kind]==id and(kind~="body"or not record.mix))
  Art.control(n,self.paletteKind==kind and self.paletteChoice==id,n.Interactable)
 end end
 self.mixTitle.Visible=self.page=="palette"and self.paletteGroup=="mix"
 for id,n in pairs(self.mixChoices)do n.Visible=self.page=="palette"and self.paletteGroup=="mix";n.Interactable=owned and record.ranks[id]>0 and not pending;n.Selectable=n.Interactable;Art.control(n,self.paletteKind=="mix"and table.find(self.mixBases,id)~=nil,n.Interactable)end
 self.resetAction.Visible=self.page=="palette";self.resetAction.Interactable=owned and not pending and(record.body~="original"or record.secondary~="default"or record.mix~=nil)
 self.resetAction.Selectable=self.resetAction.Interactable;Art.control(self.resetAction,false,self.resetAction.Interactable)
 self.buyTab.Interactable,self.paletteTab.Interactable=not pending,not pending
 for _,entry in ipairs({{self.buyTab,"buy"},{self.paletteTab,"palette"}})do
  local tab,key=entry[1],entry[2];local active=self.page==key;tab:SetAttribute("SelectedTab",active);Art.control(tab,active,not pending)
  local edge=tab:FindFirstChild("ActiveTabEdge");if not edge then edge=Art.frame(tab,"ActiveTabEdge","accent",UDim2.new(0,4,1,-4),UDim2.new(1,-8,0,3),tab.ZIndex+2)end;edge.Visible=active
 end
 self.offerTitle.Visible=assigning;self.bodyTitle.Visible=self.page=="palette"and self.paletteGroup=="body";self.secondaryTitle.Visible=self.page=="palette"and self.paletteGroup=="secondary"
 local receipt=self.intent.receipt;local hasReceipt=receipt~=nil
 self.receipt.Visible=self.page=="buy"and not held and hasReceipt and receipt.action~="hueBuy";self.equipAccent.Visible=self.page=="buy"and not held and hasReceipt and receipt.petId==self.petId and(receipt.action=="hueApply"or receipt.action=="hue")and receipt.secondaryUnlocked==true
 if hasReceipt then
  self.receipt.Text=if receipt.action=="hueBuy"then "Saved - Hue Egg hatched - 8 Stars spent"elseif receipt.action=="hueApply"or receipt.action=="hue"then direction(receipt.hue).." "..({"I","II","III"})[receipt.newRank].." applied to "..Pets.byId[receipt.petId].name else "Colors saved for "..(Pets.byId[receipt.petId]and Pets.byId[receipt.petId].name or "your baby")
  if self.equipAccent.Visible then self.equipAccent.Text="Equip "..direction(receipt.hue).." accents";self.equipAccent.Interactable=not pending and record.secondary~=receipt.hue;self.equipAccent.Selectable=self.equipAccent.Interactable end
 end
 self.status.Text=if self.saveNotice then self.saveNotice.detail elseif self.intent.status=="Saved"or self.intent.message=="Saved"then ""else self.intent.message or "";self.status.Visible=self.status.Text~=""
 self.resultLead=self.page=="buy"and not held and self.receipt.Visible
 self.quote.TextXAlignment=if self.page=="buy"and not held then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
 if self.resultLead then self.quote.Text="Another egg adds one grade to a hue you choose."end
 local ready,reason=self.intent:ready(if self.page=="buy"and not held then nil else self.petId)
 if self.intent.status=="Retrying"and pending then self.action.Text="Retry same save";self.action.Interactable=true
 elseif pending then self.action.Text="Saving...";self.action.Interactable=false
 elseif self.page=="buy"then
  if held then self.action.Text=if rank>=3 then "Already at grade III"else "Apply to "..Pets.byId[self.petId].name;self.action.Interactable=ready and owned and rank<3
  else
   local another=self.state.hueLastPurchase~=nil
   self.action.Text=if another then "Hatch another Hue Egg - 8 Stars"else "Hatch Hue Egg - 8 Stars"
   local capacity=Hues.capacity(self.state);local shortfall=math.max(0,Hues.Cost-(self.state.nectar or 0));local play=self.options.play or self.options.earn
   self.action.Interactable=ready and capacity and(shortfall==0 or type(play)=="function")
   if ready and capacity and shortfall>0 and type(play)=="function"then self.action.Text="Earn "..shortfall.." more "..Stars.name(shortfall)end
   if ready then
    if not capacity then reason="No owned supported baby can learn another grade."elseif shortfall>0 then reason="Earn "..Stars.amount(shortfall).." in a field round."end
   end
  end
 elseif self.paletteKind=="mix"then
  local pair=Hues.pair(self.mixBases[1],self.mixBases[2]);self.action.Text=if pair and record.mix==pair then Hues.Mixes[pair].name.." applied"elseif pair then "Apply "..Hues.Mixes[pair].name.." - free"else "Choose two bases";self.action.Interactable=ready and pair~=nil and record.mix~=pair
 else
  local same=record[self.paletteKind]==self.paletteChoice and(self.paletteKind~="body"or not record.mix)
  self.action.Text=if same then "Equipped"else "Apply "..(if self.paletteChoice=="original"then "Original body"elseif self.paletteChoice=="default"then "Default accent"else direction(self.paletteChoice).." "..self.paletteKind).." - free"
  self.action.Interactable=ready and not same
 end
 -- A previous success must never mask why this next purchase is unavailable.
 if reason and not pending and(self.page=="buy"and not held or not self.action.Interactable)then
  if self.saveNotice then self.status.Text=self.saveNotice.detail else self.status.Text=reason end
  self.status.Visible=true
 end
 for key,tab in pairs(self.colorTabs)do
  tab.Visible=self.page=="palette";tab.Interactable=not pending;tab.Selectable=tab.Visible and not pending
  local selected=self.paletteGroup==key;tab:SetAttribute("SelectedTab",selected);Art.control(tab,selected,not pending)
 end
 local pair=if self.page=="palette"and self.paletteGroup=="mix"then Hues.pair(self.mixBases[1],self.mixBases[2])else nil
 self.mixChip.Visible=pair~=nil
 if pair then self.mixChip.BackgroundColor3=Palette.resolve(self.petId,afterToken).body end
 local inset=self.action:FindFirstChildOfClass("UIPadding")
 if inset then inset.PaddingLeft=UDim.new(0,if pair then 38 else 8)end
 Art.control(self.action,true,self.action.Interactable);self.action:SetAttribute("AccessibleLabel",self.action.Text);self.action.Selectable=self.action.Interactable
 self:layout();if showPet and owned then self:paintPreview()end
end
function View:layout()
 if self.layingOut then return end;self.layingOut=true
 local size=self.shade.AbsoluteSize;local short=size.Y<390
 local desktop=size.X>=760 and size.Y>=560
 local contentSized=desktop and self.page=="buy"and not self.state.heldHueEgg
 local heldDesktop=desktop and self.page=="buy"and self.state.heldHueEgg~=nil
 local width=math.max(1,math.min(if contentSized then 540 else 720,size.X-16))
 local height=math.max(1,math.min(700,size.Y-(if short then 8 else 16)));local pad=12;local usable=width-24
 self.card.Size=UDim2.fromOffset(width,height)
 local header=Art.sheetHeader(width,self.title,self.walletHost,self.wallet,self.walletStar,self.closeButton,{pad=12,top=0,amount=self.state.nectar or 0,title="Hue Egg",shortTitle="Hue Egg"});self.headerPlan=header
 Art.type(self.action,"Action",short);local footer=math.max(44,Art.actionHeight(self.action,usable));place(self.action,pad,height-footer-(if short then 4 else 8),usable,footer)
 local top=header.height+4;local viewH=math.max(1,height-top-footer-(if short then 8 else 12));place(self.body,pad,top,usable,viewH)
 local w=usable-10;local y=0;local gap=8
 local function row(nodes,columns)
  if #nodes==0 then return end
  local cw=(w-(columns-1)*gap)/columns;local h=44
  for _,n in ipairs(nodes)do Art.type(n,"Action",short);h=math.max(h,Art.actionHeight(n,cw))end
  for i,n in ipairs(nodes)do place(n,((i-1)%columns)*(cw+gap),y+math.floor((i-1)/columns)*(h+gap),cw,h)end
  y+=math.ceil(#nodes/columns)*(h+gap)
 end
 local function copy(n)
  if not n.Visible then return end
  Art.type(n,if n==self.offerTitle or n==self.bodyTitle or n==self.secondaryTitle or n==self.mixTitle or(n==self.receipt and self.resultLead)then "Action"else "Body",short)
  local h=Art.textHeight(n,w,20);place(n,0,y,w,h);y+=h+8
 end
 row({self.buyTab,self.paletteTab},2)
 if self.resultLead then copy(self.receipt)end
 if self.generic.Visible then
  Art.type(self.eggCaption,"Body",short)
  local gh
  if heldDesktop then
   place(self.genericEgg,0,0,52,64);self.eggCaption.TextXAlignment=Enum.TextXAlignment.Left
   local captionH=Art.textHeight(self.eggCaption,w-72,24);gh=math.max(64,captionH)
   place(self.eggCaption,72,(gh-captionH)/2,w-72,captionH)
  else
   local eggW,eggH=if contentSized then 72 else 84,if contentSized then 92 else 108
   self.genericEgg.Position,self.genericEgg.Size=UDim2.new(.5,-eggW/2,0,4),UDim2.fromOffset(eggW,eggH)
   self.eggCaption.TextXAlignment=Enum.TextXAlignment.Center
   local captionH=Art.textHeight(self.eggCaption,w,24);local captionY=eggH+8;gh=captionY+captionH
   place(self.eggCaption,0,captionY,w,captionH)
  end
  place(self.generic,0,y,w,gh);y+=gh+8
 end
 local targets={};for _,n in ipairs(self.targets)do if n.Visible then table.insert(targets,n)end end;row(targets,math.max(1,#targets))
 if self.current.host.Visible then
  local previewH=if short then 140 elseif desktop then 160 else 190
  local stacked=GuiService.PreferredTextSize==Enum.PreferredTextSize.Largest and w<400
  local pw=if stacked then w else(w-gap)/2
  for i,item in ipairs({self.current,self.after})do
   place(item.host,if stacked then 0 else(i-1)*(pw+gap),y+(if stacked then(i-1)*(previewH+gap)else 0),pw,previewH)
   Art.type(item.title,"Supporting",short);local th=Art.textHeight(item.title,pw-20,20)
   place(item.title,8,2,pw-16,th);place(item.viewport,4,th+4,pw-8,math.max(36,previewH-th-8));place(item.swatch,pw-24,th+8,14,14)
  end
  y+=(if stacked then previewH*2+gap else previewH)+8
 end
 copy(self.currentText)
 if self.page=="palette"then row({self.colorTabs.body,self.colorTabs.secondary,self.colorTabs.mix},3)end
 copy(self.quote)
 if self.page=="buy"and self.state.heldHueEgg then
  copy(self.offerTitle)
  local columns=if w>=450 then 2 else 1;local cw=(w-(columns-1)*gap)/columns;local rh=58
  for _,offer in ipairs(Hues.Order)do local e=self.offers[offer.id];Art.type(e.title,"Action",short);Art.type(e.rank,"Supporting",short);rh=math.max(rh,Art.textHeight(e.title,cw-88,20)+Art.textHeight(e.rank,cw-62,18)+12)end
  for i,offer in ipairs(Hues.Order)do local e=self.offers[offer.id]
   place(e.button,((i-1)%columns)*(cw+gap),y+math.floor((i-1)/columns)*(rh+gap),cw,rh)
   place(e.title,52,4,cw-80,rh*.5-4);place(e.rank,52,rh*.5,cw-58,rh*.5-4);place(e.swatch,cw-24,8,14,14)
  end
  y+=math.ceil(4/columns)*(rh+gap)
 elseif self.page=="palette"then
  local nodes={};local columns=if w>=450 then 2 else 1
  if self.paletteGroup=="body"then
   copy(self.bodyTitle);nodes={self.bodyChoices.original};for _,offer in ipairs(Hues.Order)do table.insert(nodes,self.bodyChoices[offer.id])end;row(nodes,columns)
  elseif self.paletteGroup=="secondary"then
   copy(self.secondaryTitle);nodes={self.secondaryChoices.default};for _,offer in ipairs(Hues.Order)do table.insert(nodes,self.secondaryChoices[offer.id])end;row(nodes,columns)
  else
   copy(self.mixTitle);for _,offer in ipairs(Hues.Order)do table.insert(nodes,self.mixChoices[offer.id])end;row(nodes,2)
  end
  row({self.resetAction},1)
 end
 if self.receipt.Visible and not self.resultLead then copy(self.receipt)end
 if self.equipAccent.Visible then row({self.equipAccent},1)end
 if self.status.Visible then copy(self.status)end
 if contentSized or heldDesktop then
  height=math.min(size.Y-16,math.max(if contentSized then 320 else 620,top+y+4+footer+16))
  self.card.Size=UDim2.fromOffset(width,height)
  place(self.action,pad,height-footer-8,usable,footer)
  viewH=math.max(44,height-top-footer-16);place(self.body,pad,top,usable,viewH)
 end
 self.body.CanvasSize=UDim2.fromOffset(0,y+4);self.body.ScrollingEnabled=y+4>viewH
 self.body.CanvasPosition=Vector2.new(0,math.clamp(self.body.CanvasPosition.Y,0,math.max(0,y+4-viewH)))
 self.layingOut=false;self:fitPreviews()
end
function View:setSaveNotice(notice)
 self.saveNotice=notice;if self.shade.Visible then self:refresh()end
end
function View:open(state,page,petId)
 self.intent:update(state);self.state=state or {}
 if self.state.lastHatch then if self.options.pendingHatch then self.options.pendingHatch()end;return false end
 local pending=self.intent.pending
 if pending then
  petId=pending.value.petId;page=if pending.action=="hueBuy"or pending.action=="hueApply"or pending.action=="hue"then "buy"else "palette"
  if pending.value.hue then self.hue=pending.value.hue end
 end
 self.page=page or "buy"
 local eligible=if petId and Hues.Supported[petId]and self:owned(petId)then petId elseif Hues.Supported[self.petId]and self:owned(self.petId)then self.petId elseif self:owned("pip")then "pip"elseif self:owned("puddle")then "puddle"else nil
 if not eligible and self.page=="palette"then return false end
 self.petId=eligible or "pip"
 if pending and pending.action=="hueMix"then
  local mix=Hues.Mixes[pending.value.pair];self.paletteKind,self.paletteGroup="mix","mix";self.mixBases={mix.a,mix.b}
 elseif pending and pending.action=="hueEquip"then
  self.paletteKind=if pending.value.body then "body"else "secondary";self.paletteGroup=self.paletteKind;self.paletteChoice=pending.value[self.paletteKind]
 else self.paletteKind,self.paletteGroup="body","body";self.paletteChoice=Hues.get(self.state.hues,self.petId).body;self.mixBases={}end
 self.previousSelection=GuiService.SelectedObject;self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch);self.shade.Visible=true;self:refresh();return true
end
function View:close(reason)
 if not self.shade.Visible then return end
 self.shade.Visible=false;self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch)
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then GuiService.SelectedObject=nil end
 if self.options.closed then self.options.closed(reason)end
end
function View:ensure(target)
 if not target:IsDescendantOf(self.body)then return end
 local y=target.AbsolutePosition.Y-self.body.AbsolutePosition.Y+self.body.CanvasPosition.Y
 local scroll=self.body.CanvasPosition.Y;local h=self.body.Size.Y.Offset
 if y<scroll then scroll=y elseif y+target.AbsoluteSize.Y>scroll+h then scroll=y+target.AbsoluteSize.Y-h end
 self.body.CanvasPosition=Vector2.new(0,math.clamp(scroll,0,math.max(0,self.body.CanvasSize.Y.Offset-h)))
end
function View:getControllerFocus()
 if not self.shade.Visible then return nil end
 return{root=self.shade,epoch=self.epoch,target=function()return if self.action.Interactable then self.action else self.closeButton end,fallback=self.closeButton,ensure=function(n)self:ensure(n)end}
end
function View:destroy(fromSignal)
 if self.destroyed then return end;self.destroyed=true
 for _,item in ipairs({self.current,self.after})do if item.visual then item.visual:destroy();item.visual=nil end end
 if not fromSignal then self.shade:Destroy()end
end
return View
