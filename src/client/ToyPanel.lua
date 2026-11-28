local ReceiptLayout=require(script.Parent.ItemReceiptLayout)
local Shared=game:GetService("ReplicatedStorage").Shared
local OddsText=require(Shared.OddsText);local NextItem=require(script.Parent.NextItemText);local Catalog=require(Shared.ToyCatalog);local Art=require(script.Parent.DeckArt);local EggArt=require(script.Parent.EggArt)
local Reveal=require(script.Parent.HueItemReveal);local ItemArt=require(script.Parent.RewardItemArt)
local Copy=require(Shared.UICopy)
local SkinLook=require(script.Parent.ToySkinLook);local Swatches=require(script.Parent.WardrobeSwatches)
require(script.Parent.ToyTabIcon) -- registers the "toy" card icon (QA v2 R4.5)
local Panel={};Panel.__index=Panel
-- Lane B owns the words (UICopy); until its keys land the brief's English shows.
local function words(key,fallback)local text=Copy.get(key);return if text==key then fallback else text end
local function place(n,x,y,w,h)n.Position,n.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)end
local function label(parent,name,copy,role)
 local n=Art.text(parent,name,copy,UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),"text",16);Art.type(n,role or "Body");n.TextXAlignment=Enum.TextXAlignment.Left;return n
end
local function button(parent,name,copy,callback)
 local n=Instance.new("TextButton");n.Name,n.Text,n.Parent=name,copy,parent;n.BorderSizePixel=0;n.ZIndex=parent.ZIndex+1
 Art.button(n,10);Art.type(n,"Action");Art.bind(n,{BackgroundColor3="raised",TextColor3="text"});n.Activated:Connect(callback);return n
end
function Panel.new(parent,intent,options)
 local root=Art.frame(parent,"Toys","panel",UDim2.fromOffset(0,0),UDim2.fromOffset(100,100),parent.ZIndex+1);root.BackgroundTransparency=1;root.Visible=false
 local self=setmetatable({root=root,intent=intent,options=options or {},rows={}},Panel)
 self.title=label(root,"Heading","Toys","Heading");self.note=label(root,"Description","Choose one toy for this pet.","Body")
 self.art=Art.frame(root,"ToyResultArt","inset",UDim2.fromOffset(0,0),UDim2.fromOffset(140,140),root.ZIndex+1);self.art.BackgroundTransparency=1
 self.reveal=Reveal.new(self.art,{audio=self.options.audio,reduceEffects=self.options.reduceEffects,recipeId="toy",resultBuilder=ItemArt.create,
  onIdentityReady=function()self:paintReceiptIdentity();if self.options.identityChanged then self.options.identityChanged()end end})
 self.pool=label(root,"AvailableOdds","","Body");self.status=label(root,"Status","","Body")
 self.useNow=button(root,"UseNow","Use now",function()self:useResult()end)
 self.shop=button(root,"ToyEggShop","Toy Egg · "..Catalog.Cost.." Stars",function()if self.options.shop then self.options.shop()end end)
 -- QA v775 note 8: in Customize a tap on a toy card first selects it (the pane's pet plays
 -- with it), and a second tap or the pane's Wear button equips it, as Hue and Charm cards
 -- do. `options.tap(id)` owns that; without it (or when it answers nil) a tap equips.
 for _,id in ipairs(Catalog.Order)do
  self.rows[id]=button(root,"Toy_"..id,Catalog.ById[id].name,function()
   if self.options.tap and self.options.tap(id)~=nil then return end
   self:choose(id)
  end)
 end
 -- Toy colours (ROTATION-2-BRIEF 1): under the cards, the focused toy's swatch row (28 px, 8 px gap, a ring on the worn
 -- colour; the original first, then the owned colours) and the egg line. A tap wears that colour through
 -- `options.wearSkin(order)` ({id, action = "toySkinWear", toyId, skinId | "none"}); one wear in flight, the last tap
 -- wins (WardrobeSwatches via ToySkinLook.queue); answers come back through Panel:result.
 self.skinQueue=SkinLook.queue({id=function()return game:GetService("HttpService"):GenerateGUID(false)end,
  send=function(order)if self.options.wearSkin then self.options.wearSkin(order)end end})
 local rowH=Swatches.Size+Swatches.Ring*2+4
 self.swatchRow=Instance.new("ScrollingFrame");self.swatchRow.Name="ToySwatches";self.swatchRow.BackgroundTransparency=1;self.swatchRow.BorderSizePixel=0
 self.swatchRow.ScrollingDirection=Enum.ScrollingDirection.X;self.swatchRow.ScrollBarThickness=0;self.swatchRow.Size=UDim2.fromOffset(100,rowH)
 self.swatchRow.ZIndex=root.ZIndex+1;self.swatchRow.Visible=false;self.swatchRow.Selectable=false;self.swatchRow.Parent=root
 self.swatchButtons={};self.swatchKey=nil
 self.moreColours=label(root,"MoreToyColours",words("rack.toy.more","More colours come from the Toy Colour Egg."),"Supporting");self.moreColours.Visible=false
 return self
end
-- {toyId = skinId} as drawn now: the server's worn colours with the answered saves and every open wear on top (the
-- owner's appearance `toySkins`, so the pet and the pane show a tap at once).
function Panel:shownSkins(state)
 local s=state or self.state
 return self.skinQueue:shown(SkinLook.wornMap(s))
end
function Panel:wornSkin(toyId)return self:shownSkins()[toyId]or SkinLook.None end
function Panel:changed()if self.options.identityChanged then self.options.identityChanged()end end
-- A swatch tap: wear `skinId` ("none" = the original) on `toyId`, an owned colour of an owned toy.
function Panel:wearSkin(toyId,skinId)
 if not self.root.Visible or self.mode~="choices"or not SkinLook.on(self.state)then return false end
 if self.options.canEquip and not self.options.canEquip()then return false end
 if not Catalog.owns(self.state.toyUnlocks,toyId)or toyId==Catalog.Default then return false end
 if skinId~=SkinLook.None and not SkinLook.owned(self.state)[skinId]then return false end
 if not self.skinQueue:tap(toyId,skinId,SkinLook.wornMap(self.state))then return false end
 pcall(function()require(script.Parent.UIClick).play("equip")end)
 self:changed();return true
end
-- Gamepad / keyboard: the next owned colour of the focused toy (wraps).
function Panel:cycleSkin(delta)
 local toyId=self.focusedToy;local list=toyId and SkinLook.swatches(self.state,toyId)
 if not list or #list<2 then return false end
 local worn,at=self:wornSkin(toyId),1
 for i,row in ipairs(list)do if row.id==worn then at=i end end
 return self:wearSkin(toyId,list[(at-1+(delta or 1))%#list+1].id)
end
-- A WearableResult message: true when it answered this panel's toy colour wear.
function Panel:result(message)
 if not self.skinQueue:result(message,SkinLook.wornMap(self.state))then return false end
 self:changed();return true
end
-- The swatch row for `toyId` (nil hides it). Rebuilt only when the list changes; the ring follows the shown colour.
function Panel:paintSwatches(toyId,list,width)
 local row=self.swatchRow
 local ids={};for _,item in ipairs(list or {})do table.insert(ids,item.id)end
 local key=if list then tostring(toyId)..":"..table.concat(ids,",")..":"..width else nil
 if key~=self.swatchKey then
  self.swatchKey=key;self.swatchButtons={}
  for _,child in ipairs(row:GetChildren())do child:Destroy()end
  if list then
   local xs,canvas=Swatches.layout(#list,width)
   row.CanvasSize=UDim2.fromOffset(canvas,0)
   for index,item in ipairs(list)do
    local b=Instance.new("TextButton");b.Name="ToySwatch_"..item.id;b.Text="";b.AutoButtonColor=false;b.BorderSizePixel=0;b.Selectable=false
    b.Size=UDim2.fromOffset(Swatches.Size,Swatches.Size);b.Position=UDim2.fromOffset(xs[index],Swatches.Ring+2);b.ZIndex=row.ZIndex+1
    b.BackgroundColor3=item.color;Art.corner(b,Swatches.Size)
    local edge=Instance.new("UIStroke");edge.Thickness=1;edge.Transparency=.55;edge.Color=Color3.new(0,0,0);edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;edge.Parent=b
    local ring=Instance.new("Frame");ring.Name="Worn";ring.BackgroundTransparency=1;ring.AnchorPoint=Vector2.new(.5,.5);ring.Position=UDim2.fromScale(.5,.5)
    ring.Size=UDim2.new(1,Swatches.Ring*2+2,1,Swatches.Ring*2+2);ring.ZIndex=b.ZIndex+1;ring.Visible=false;ring.Parent=b;Art.corner(ring,Swatches.Size)
    local stroke=Instance.new("UIStroke");stroke.Thickness=Swatches.Ring;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=ring;Art.bind(stroke,{Color="text"})
    b.Activated:Connect(function()self:wearSkin(toyId,item.id)end)
    self.swatchButtons[index]={button=b,ring=ring,item=item}
   end
  end
 end
 local worn=toyId and self:wornSkin(toyId)
 for _,entry in ipairs(self.swatchButtons)do
  local on=entry.item.id==worn
  entry.ring.Visible=on
  entry.button:SetAttribute("AccessibleLabel",Swatches.label(entry.item,on))
 end
 row.Visible=list~=nil
end
function Panel:choose(id)
 if not self.root.Visible or self.mode~="choices"then return false end
 if self.options.canEquip and not self.options.canEquip()then return false end
 return self.intent~=nil and self.intent:equip(self.petId,id)or false
end
function Panel:useResult()
 local result=self.state and self.state.pendingToyResult
 if not result or not self.root.Visible or self.mode~="receipt"or(self.options.receiptOpen and not self.options.receiptOpen(result))then return false end
 if self.reveal:consumeSkipInput()or self.reveal:skip()then return false end
 if self.options.storeFirst and self.options.storeFirst(result)then return true end
 if self.options.useNow then self.options.useNow(result);return true end;return false
end
function Panel:paintReceiptIdentity()
 local result=self.state and self.state.pendingToyResult;if self.mode~="receipt"or not result then return end
 local ready=self.reveal:identityReady(result)
 self.title.Text=if ready then Catalog.ById[result.toyId].name.." unlocked!"else Copy.get("hatch.display.wait")
 self.note.Text=if ready then "Choose a pet for this toy."else Copy.get("hatch.display.line")
 self.title:SetAttribute("AccessibleLabel",self.title.Text);self.title:SetAttribute("ResultIdentityReady",ready)
 self.root:SetAttribute("ResultIdentityReady",ready)
end
function Panel:refresh(state,petId,mode,animate)
 self.state,self.petId,self.mode=state or {},petId,mode;self.root.Visible=mode~=nil
 -- Toy colours: answered saves the snapshot now shows stop being overlaid; off (no `rack.toy`) drops every open wear.
 if SkinLook.on(self.state)then self.skinQueue:sync(SkinLook.wornMap(self.state))else self.skinQueue:clear()end
 if mode~="choices"then self.swatchRow.Visible=false;self.moreColours.Visible=false end
 self.useNow.Visible=mode=="receipt"and self.state.pendingToyResult~=nil
 if mode~="receipt"and self.reveal.resultId then self.reveal:clear()end
 if not mode then return end
 local receipt,buy=mode=="receipt",mode=="buy";local result=self.state.pendingToyResult
 self.title.Text=if receipt then Copy.get("hatch.display.wait")elseif buy then "Toy Egg"else "Toys"
 self.note.Text=if receipt then Copy.get("hatch.display.line")elseif buy then Catalog.Cost.." Stars · one new toy. No duplicates."else "Choose one toy for this pet. Quiet garden play gives no rewards."
 self.art.Visible=receipt or buy
 if receipt and result then self.reveal:show(result,animate==true)
 elseif buy and not self.art:FindFirstChild("ToyEgg")then for _,n in ipairs(self.art:GetChildren())do n:Destroy()end;EggArt.create(self.art,"toy",UDim2.fromScale(0,0),UDim2.fromScale(1,1),self.art.ZIndex+1,"ToyEgg")end
 self:paintReceiptIdentity()
 local selected=(self.state.petToys or {})[petId]or Catalog.Default
 for id,n in pairs(self.rows)do
  local owned=Catalog.owns(self.state.toyUnlocks,id);n.Visible=not receipt and not buy and owned
  n.Text=(if selected==id then "✓ "else "")..Catalog.ById[id].name;n.Interactable=self.intent~=nil and not self.intent.pending and selected~=id
  Art.tab(n,selected==id,n.Interactable)
 end
 local odds,rounded={},false
 for _,entry in ipairs(Catalog.odds(self.state.toyUnlocks))do local text,r=OddsText.format(entry.probability);rounded=rounded or r==true;table.insert(odds,Catalog.ById[entry.id].name.." · "..text)end
 -- Paid random items: rounded odds say so (LISTING.md section 7).
 if rounded then table.insert(odds,require(game:GetService("ReplicatedStorage").Shared.UICopy).get("hatch.odds.rounded"))end
 -- Restricted players get the fixed next toy, never a roll (F1 policy): no odds list.
 self.pool.Visible=buy;self.pool.Text=if NextItem.restricted(self.state)then NextItem.line("toy",self.state)elseif #odds==0 then "All toys owned"else table.concat(odds,"\n")
 self.shop.Visible=not receipt and not buy;self.shop.Text=if #odds==0 then "All toys owned"else "Toy Egg · "..Catalog.Cost.." Stars"
 self.shop.Interactable=#odds>0 and self.intent~=nil and not self.intent.pending;self.useNow.Interactable=self.intent~=nil and not self.intent.pending
 self.status.Text=self.intent and self.intent.message or "";self.status.Visible=self.status.Text~=""
end
function Panel:layout(width,compact,availableHeight)
 self.swatchRow.Visible=false;self.moreColours.Visible=false -- the colour row lives under the Customize cards only
 if self.mode=="receipt"then
  self.title.Visible=false
  local height=ReceiptLayout.layout(self.art,self.note,width,availableHeight,compact)
  if self.status.Visible then Art.type(self.status,"Body",compact);local h=Art.textHeight(self.status,width-8,24);place(self.status,4,height,width-8,h);height+=h+8 end
  self.root.Size=UDim2.fromOffset(width,height);return height
 end
 local y=0
 local function copy(n,role)if not n.Visible then return end;Art.type(n,role);local h=Art.textHeight(n,math.max(1,width-8),24);place(n,4,y,width-8,h);y+=h+8 end
 local function action(n)if not n.Visible or n.Parent~=self.root then return end;Art.type(n,"Action");local h=Art.actionHeight(n,width-8);place(n,4,y,width-8,h);y+=h+8 end
 self.title.Visible=not(compact and self.mode=="choices");self.note.Visible=self.title.Visible;copy(self.title,"Heading")
 if self.art.Visible then local side=math.min(if self.mode=="receipt"then 112 else 140,math.max(44,width-16));place(self.art,(width-side)/2,y,side,side);y+=side+8 end
 copy(self.note,"Body");copy(self.pool,"Body");for _,id in ipairs(Catalog.Order)do action(self.rows[id])end;action(self.useNow);action(self.shop);copy(self.status,"Body")
 self.root.Size=UDim2.fromOffset(width,y);return y
end
-- Card grid for the Customize Toys tab (redesign 2.3): the owned toys
-- as cards (None first), WEARING on this pet's saved toy. Returns the used
-- height and the focus list ({button, id, act}).
function Panel:layoutCards(width,cols,cardH,gap,focusIndex,compact)
 local Cards=require(script.Parent.CustomizeCards)
 self.title.Visible=false;self.note.Visible=false;self.pool.Visible=false;self.art.Visible=false;self.useNow.Visible=false
 local selected=(self.state and self.state.petToys or {})[self.petId]or Catalog.Default
 local live={}
 for _,id in ipairs(Catalog.Order)do if self.rows[id].Visible then table.insert(live,id)end end
 local rects,h=Cards.rects(#live,width,cols,cardH,gap,3)
 local focus={}
 for i,id in ipairs(live)do
  local node=self.rows[id];Cards.place(node,rects[i])
  local wearing=selected==id
  Cards.dress(node,{name=Catalog.ById[id].name,status=if wearing then "WEARING"else "Owned",tone=if wearing then "accent"else "soft",icon=if id=="none"then "none"else "toy",focused=i==focusIndex,compact=compact,isNew=self.options.isNew~=nil and self.options.isNew(id)==true and not wearing})
  table.insert(focus,{button=node,id=id,wearing=wearing,name=Catalog.ById[id].name,act=function()return self:choose(id)end})
 end
 local y=h+12
 -- Toy colours: the focused toy's swatches (only when it has an owned colour) and the egg line (switch on, a real toy).
 local focusedToy=live[math.clamp(focusIndex or 1,1,math.max(1,#live))]
 local skinnable=focusedToy~=nil and focusedToy~=Catalog.Default and SkinLook.on(self.state)and SkinLook.Original[focusedToy]~=nil
 self.focusedToy=if skinnable then focusedToy else nil
 local list=if skinnable then SkinLook.swatches(self.state,focusedToy,words("rack.toy.original","Original"))else nil
 if list and #list<2 then list=nil end
 self:paintSwatches(self.focusedToy,list,math.max(1,width-6))
 if list then local rowH=Swatches.Size+Swatches.Ring*2+4;place(self.swatchRow,3,y,width-6,rowH);y+=rowH+6 end
 self.moreColours.Visible=skinnable
 if skinnable then Art.type(self.moreColours,"Supporting",compact);local mh=Art.textHeight(self.moreColours,width-6,20);place(self.moreColours,3,y,width-6,mh);y+=mh+8 end
 -- QA v2 R4.5: no egg row under the cards in Customize (the screen shows one
 -- "More from eggs" line instead); the egg row stays on the receipt / buy pages.
 self.shop.Visible=false
 if self.shop.Visible then
  Art.type(self.shop,"Action");local sh=math.max(44,Art.actionHeight(self.shop,width-6));place(self.shop,3,y,width-6,sh);y+=sh+8
 end
 if self.status.Visible then Art.type(self.status,"Body",compact);local sh=Art.textHeight(self.status,width-6,24);place(self.status,3,y,width-6,sh);y+=sh+8 end
 self.root.Size=UDim2.fromOffset(width,y);return y,focus
end
function Panel:destroy()self.reveal:destroy();self.root:Destroy()end
return Panel
