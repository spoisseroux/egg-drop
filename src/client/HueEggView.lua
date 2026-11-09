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
local function motif(parent,id,color)
 local host=Art.frame(parent,"HueEgg","inset",UDim2.fromOffset(8,6),UDim2.fromOffset(35,44),parent.ZIndex+1)
 host.BackgroundTransparency=1;EggArt.create(host,"meadow",UDim2.fromScale(0,0),UDim2.fromScale(1,1),host.ZIndex+1)
 local egg=host:FindFirstChild("Egg");egg.Pattern:Destroy()
 local function stroke(name,x,y,w,h,rotation)
  local n=Art.frame(host,name,color,UDim2.fromScale(x,y),UDim2.fromScale(w,h),host.ZIndex+6);n.Rotation=rotation or 0;Art.corner(n,5)
 end
 if id=="rose"then stroke("PetalL",.29,.43,.12,.23,-28);stroke("PetalR",.56,.43,.12,.23,28)
 elseif id=="tide"then for i=0,1 do stroke("Wave",.28,.43+i*.16,.43,.045,-12)end
 elseif id=="citrus"then for i=0,3 do stroke("Ray",.32+i*.08,.46,.055,.20,(i-1.5)*22)end
 else stroke("FacetL",.31,.41,.10,.28,-25);stroke("FacetR",.56,.41,.10,.28,25)end
 return host
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
 self.title=text(card,"Title","Hue Eggs","Heading");self.wallet=text(card,"Wallet","0 Stars","Counter")
 self.walletHost=Art.frame(card,"WalletHost","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(120,44),22)
 self.wallet.Parent=self.walletHost
 self.walletStar=EggArt.stars(self.walletHost,UDim2.fromOffset(0,0),UDim2.fromOffset(18,24),23)
 self.closeButton=Art.bareClose(button(card,"Close","×",function()self:close("back")end))
 self.action=button(card,"Action","Feed Rose · 8 Stars",function()self:activate()end)
 for i,id in ipairs({"pip","puddle"})do self.targets[i]=button(body,"Target_"..id, Pets.byId[id].name,function()self:choosePet(id)end)end
 self.buyTab=button(body,"BuyTab","Hue Eggs",function()self:setPage("buy")end)
 self.paletteTab=button(body,"PaletteTab","Body & accents",function()self:setPage("palette")end)
 self.current=preview(body,"Current");self.after=preview(body,"After")
 self.currentText=text(body,"CurrentPalette","","Body");self.quote=text(body,"Quote","","Body")
 self.offerTitle=text(body,"OfferTitle","Choose a direction","Action")
 for _,offer in ipairs(Hues.Order)do
  local id=offer.id;local n=button(body,"Offer_"..id,"",function()self:chooseHue(id)end)
  local icon=motif(n,id,offer.color);local title=text(n,"Name",offer.name,"Action");local rank=text(n,"Grades","○○○","Supporting")
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
 self.petId=id;self.paletteChoice=if self.paletteKind=="body"then Hues.get(self.state.hues,id).body else Hues.get(self.state.hues,id).secondary
 self:refresh();return true
end
function View:chooseHue(id)if self.intent.pending or not Hues.ById[id]then return false end;self.hue=id;self:refresh();return true end
function View:setPage(page)if self.intent.pending then return false end;self.page=page;self:refresh();return true end
function View:choosePalette(kind,id)
 if self.intent.pending then return false end
 local r=Hues.get(self.state.hues,self.petId)
 if id~="original"and id~="default"and(r.ranks[id]or 0)<1 then return false end
 self.paletteKind,self.paletteChoice=kind,id;self:refresh();return true
end
function View:activate()
 if not self.shade.Visible or not self.action.Interactable then return false end
 if self.intent.status=="Retrying"then return self.intent:retry()end
 if self.page=="buy"then
  local record=Hues.get(self.state.hues,self.petId);local offer=Hues.ById[self.hue]
  if(record.ranks[self.hue]or 0)<3 and(self.state.nectar or 0)<offer.cost then
   self:close("earn");if self.options.earn then self.options.earn()end;return true
  end
  return self.intent:buy(self.petId,self.hue)
 end
 return self.intent:equip(self.petId,self.paletteKind,self.paletteChoice)
end
function View:appearance(after)
 local token=Hues.appearance(self.state.hues,self.petId)
 local base=self.options.appearance and self.options.appearance(self.petId)
 token=table.clone(token);token.charmVisible=not(base and base.charmVisible==false)
 if after then
  if self.page=="buy"then token.body=self.hue;token.bodyRank=math.min(Hues.MaxRank,(Hues.get(self.state.hues,self.petId).ranks[self.hue]or 0)+1)
  elseif self.paletteKind=="body"then token.body=self.paletteChoice;token.bodyRank=if token.body=="original"then 0 else Hues.get(self.state.hues,self.petId).ranks[token.body]or 0
  else token.secondary=self.paletteChoice end
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
function View:refresh()
 self.state=self.intent.state or self.state
 local pending=self.intent.pending~=nil
 if self.pendingEpoch~=pending then self.pendingEpoch=pending;self.epoch+=1;self.shade:SetAttribute("ControllerEpoch",self.epoch)end
 if not self.shade.Visible then return end
 if self.state.lastHatch then self:close("pendingHatch");if self.options.pendingHatch then self.options.pendingHatch()end;return end
 local record=Hues.get(self.state.hues,self.petId);local offer=Hues.ById[self.hue];local rank=record.ranks[self.hue]or 0
 self.wallet.Text=Stars.amount(self.state.nectar or 0);self.wallet:SetAttribute("AccessibleLabel",self.wallet.Text)
 local bodyName=if record.body=="original"then "Original"else direction(record.body).." "..record.ranks[record.body]
 local secondary=if record.secondary=="default"then "Default"else direction(record.secondary)
 self.current.title.Text="Current · "..bodyName.." / "..secondary
 local afterToken=self:appearance(true)
 local afterBody=if afterToken.body=="original"then "Original"else direction(afterToken.body).." "..afterToken.bodyRank
 local afterSecondary=if afterToken.secondary=="default"then "Default"else direction(afterToken.secondary)
 self.after.title.Text="After · "..afterBody.." / "..afterSecondary
 self.currentText.Text="Body: "..bodyName.." · Accents: "..secondary
 local balance=self.state.nectar or 0
 if self.page=="buy"then
  local progress=direction(self.hue).." "..rank.." → "..math.min(3,rank+1)
  local spend=if rank>=3 then "Max rank. Stars unchanged."elseif balance<offer.cost then "8 Stars · need "..(offer.cost-balance).." more."else Stars.amount(balance).." → "..Stars.amount(balance-offer.cost)
  self.quote.Text=progress.." · "..spend.."\nAccents stay "..secondary..(if rank==0 then ". First use unlocks this accent separately."else ". This accent is already unlocked.")
 else self.quote.Text="Body and accents save independently. Every unlocked choice is free."end
 for i,id in ipairs({"pip","puddle"})do local n=self.targets[i];n.Interactable=self:owned(id)and not self.intent.pending;n.Selectable=n.Interactable;Art.control(n,id==self.petId,n.Interactable)end
 for _,entry in pairs(self.offers)do entry.button.Visible=self.page=="buy"end
 for id,entry in pairs(self.offers)do
  local grade=record.ranks[id]or 0;entry.title.Text=Hues.ById[id].name;entry.rank.Text=string.rep("●",grade)..string.rep("○",3-grade).." · "..grade.."/3"
  entry.button:SetAttribute("AccessibleLabel",Hues.ById[id].name.." Hue Egg, rank "..grade.." of 3, 8 Stars")
  entry.button.Interactable=not self.intent.pending;entry.button.Selectable=entry.button.Interactable;Art.control(entry.button,id==self.hue,entry.button.Interactable)
  Art.bind(entry.title,{TextColor3=entry.ink});Art.bind(entry.rank,{TextColor3=entry.ink})
 end
 for kind,choices in pairs({body=self.bodyChoices,secondary=self.secondaryChoices})do
  for id,n in pairs(choices)do
   n.Visible=self.page=="palette";local unlocked=id=="original"or id=="default"or(record.ranks[id]or 0)>0
   n.Interactable=unlocked and not self.intent.pending;n.Selectable=n.Interactable
   Art.control(n,self.paletteKind==kind and self.paletteChoice==id,n.Interactable)
  end
 end
 self.buyTab.Interactable,self.paletteTab.Interactable=not self.intent.pending,not self.intent.pending
 Art.control(self.buyTab,self.page=="buy",self.buyTab.Interactable);Art.control(self.paletteTab,self.page=="palette",self.paletteTab.Interactable)
 self.offerTitle.Visible=self.page=="buy";self.bodyTitle.Visible=self.page=="palette";self.secondaryTitle.Visible=self.page=="palette"
 local receipt=self.intent.receipt;local hasReceipt=receipt and receipt.petId==self.petId
 self.receipt.Visible=hasReceipt==true;self.equipAccent.Visible=hasReceipt==true and receipt.action=="hue"and receipt.secondaryUnlocked==true
 if hasReceipt then
  self.receipt.Text=if receipt.action=="hue"then string.format("Saved · %s · %s %d → %d\n%d Stars spent · wallet %d → %d",Pets.byId[receipt.petId].name,direction(receipt.hue),receipt.oldRank,receipt.newRank,receipt.cost,receipt.balanceBefore,receipt.balanceAfter)else "Saved · "..Pets.byId[receipt.petId].name.." colors equipped"
  if self.equipAccent.Visible then self.equipAccent.Text="Equip "..direction(receipt.hue).." accents";self.equipAccent.Interactable=not self.intent.pending and record.secondary~=receipt.hue end
 end
 self.status.Text=if self.saveNotice then self.saveNotice.detail else self.intent.message or "";self.status.Visible=self.status.Text~=""
 local ready,reason=self.intent:ready(self.petId)
 if self.intent.status=="Retrying"and self.intent.pending then self.action.Text="Retry same save";self.action.Interactable=true
 elseif self.intent.pending then self.action.Text="Saving…";self.action.Interactable=false
 elseif self.page=="buy"then
  self.action.Text=if rank>=3 then "Max rank"elseif(self.state.nectar or 0)<offer.cost then "Earn "..(offer.cost-(self.state.nectar or 0)).." more "..Stars.name(offer.cost-(self.state.nectar or 0))else "Feed "..offer.direction.." egg · 8 Stars"
  self.action.Interactable=ready and rank<3
  self.action:SetAttribute("AccessibleLabel",if(self.state.nectar or 0)<offer.cost then "Play to earn "..Stars.amount(offer.cost-(self.state.nectar or 0)).." for "..offer.name else self.action.Text)
 else
  local same=record[self.paletteKind]==self.paletteChoice
  self.action.Text=if same then "Equipped"else "Equip "..(if self.paletteChoice=="original"then "Original"elseif self.paletteChoice=="default"then "Default"else direction(self.paletteChoice))..(if self.paletteKind=="body"then " body"else " accents")
  self.action.Interactable=ready and not same
 end
 if not ready and not self.intent.pending and self.status.Text==""then self.status.Text=reason;self.status.Visible=true end
 Art.control(self.action,true,self.action.Interactable)
 if self.intent.pending or self.page~="buy"or rank>=3 or(self.state.nectar or 0)>=offer.cost then self.action:SetAttribute("AccessibleLabel",self.action.Text)end
 self.action.Selectable=self.action.Interactable;self:layout();self:paintPreview()
end
function View:layout()
 if self.layingOut then return end;self.layingOut=true
 local size=self.shade.AbsoluteSize;local compactLandscape=size.X>=560 and size.Y<=390;local short=size.Y<280 or compactLandscape;self.compactLandscape=compactLandscape;local width=math.max(1,math.min(720,size.X-16));local height=math.max(1,math.min(700,size.Y-(if short then 8 else 16)));local pad=12;local usable=width-24
 self.card.Size=UDim2.fromOffset(width,height)
 self.walletHost.Visible=true
 local header=Art.sheetHeader(width,self.title,self.walletHost,self.wallet,self.walletStar,self.closeButton,{pad=12,top=0,amount=self.state.nectar or 0,title=if self.page=="buy"then "Hue Eggs"else "Body & accents",shortTitle=if self.page=="buy"then "Hue Eggs"else "Colors"})
 self.headerPlan=header
 Art.type(self.action,"Action",short);local footer=math.max(44,Art.actionHeight(self.action,usable));place(self.action,pad,height-footer-(if short then 4 else 8),usable,footer)
 local top=header.height+4;local viewH=math.max(1,height-top-footer-(if short then 8 else 12));place(self.body,pad,top,usable,viewH)
 local w=usable-10;local y=0;local gap=8
 local function row(nodes,columns)
  local cw=(w-(columns-1)*gap)/columns;local h=44
  for _,n in ipairs(nodes)do Art.type(n,"Action",short);h=math.max(h,Art.actionHeight(n,cw))end
  for i,n in ipairs(nodes)do place(n,((i-1)%columns)*(cw+gap),y+math.floor((i-1)/columns)*(h+gap),cw,h)end
  y+=math.ceil(#nodes/columns)*(h+gap)
 end
 local function copy(n)
  Art.type(n,if n==self.offerTitle or n==self.bodyTitle or n==self.secondaryTitle then "Action"else "Body",short)
  local h=Art.textHeight(n,w,20);place(n,0,y,w,h);y+=h+8
 end
 self.paletteTab.Text=if compactLandscape then "Colors"else "Body & accents"
 if compactLandscape then
  local buttons={self.targets[1],self.targets[2],self.buyTab,self.paletteTab};local cw=(w-34)/4;local rh=44
  for _,n in ipairs(buttons)do Art.type(n,"Action",true);rh=math.max(rh,Art.actionHeight(n,cw))end
  local x=0;for i,n in ipairs(buttons)do place(n,x,y,cw,rh);x+=cw+(if i==2 then 18 else 8)end
  y+=rh+8
 else row(self.targets,2);row({self.buyTab,self.paletteTab},if w<300 then 1 else 2)end
 local previewH=if compactLandscape then math.clamp(viewH-y-8,105,135)elseif short then 120 else 190
 local stacked=GuiService.PreferredTextSize==Enum.PreferredTextSize.Largest and w<400
 local pw=if stacked then w else(w-gap)/2
 for i,item in ipairs({self.current,self.after})do
  local py=y+(if stacked then(i-1)*(previewH+gap)else 0)
  place(item.host,if stacked then 0 else(i-1)*(pw+gap),py,pw,previewH)
  Art.type(item.title,"Supporting",short);local th=Art.textHeight(item.title,pw-20,20)
  place(item.title,8,2,pw-16,th);place(item.viewport,4,th+4,pw-8,previewH-th-8);place(item.swatch,pw-24,th+8,14,14)
 end
 y+=(if stacked then previewH*2+gap else previewH)+8
 copy(self.currentText);copy(self.quote)
 if self.page=="buy"then
  copy(self.offerTitle)
  local columns=if w>=450 then 2 else 1;local cw=(w-(columns-1)*gap)/columns;local rh=58
  for _,offer in ipairs(Hues.Order)do local e=self.offers[offer.id];Art.type(e.title,"Action",short);Art.type(e.rank,"Supporting",short);rh=math.max(rh,Art.textHeight(e.title,cw-88,20)+Art.textHeight(e.rank,cw-62,18)+12)end
  for i,offer in ipairs(Hues.Order)do
   local e=self.offers[offer.id];place(e.button,((i-1)%columns)*(cw+gap),y+math.floor((i-1)/columns)*(rh+gap),cw,rh)
   place(e.title,52,4,cw-80,rh*.5-4);place(e.rank,52,rh*.5,cw-58,rh*.5-4);place(e.swatch,cw-24,8,14,14)
  end
  y+=math.ceil(4/columns)*(rh+gap)
 else
  copy(self.bodyTitle);local nodes={self.bodyChoices.original};for _,offer in ipairs(Hues.Order)do table.insert(nodes,self.bodyChoices[offer.id])end;row(nodes,if w>=450 then 2 else 1)
  copy(self.secondaryTitle);nodes={self.secondaryChoices.default};for _,offer in ipairs(Hues.Order)do table.insert(nodes,self.secondaryChoices[offer.id])end;row(nodes,if w>=450 then 2 else 1)
 end
 if self.receipt.Visible then copy(self.receipt)end
 if self.equipAccent.Visible then row({self.equipAccent},1)end
 if self.status.Visible then copy(self.status)end
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
  petId=pending.value.petId;page=if pending.action=="hue"then "buy"else "palette"
  if pending.value.hue then self.hue=pending.value.hue end
 end
 self.page=page or "buy"
 local eligible=if petId and Hues.Supported[petId]and self:owned(petId)then petId elseif Hues.Supported[self.petId]and self:owned(self.petId)then self.petId elseif self:owned("pip")then "pip"elseif self:owned("puddle")then "puddle"else nil
 if not eligible then return false end
 self.petId=eligible
 if pending and pending.action=="hueEquip"then
  self.paletteKind=if pending.value.body then "body"else "secondary";self.paletteChoice=pending.value[self.paletteKind]
 else self.paletteKind="body";self.paletteChoice=Hues.get(self.state.hues,self.petId).body end
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
