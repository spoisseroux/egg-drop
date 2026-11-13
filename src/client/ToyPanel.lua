local ReceiptLayout=require(script.Parent.ItemReceiptLayout)
local Shared=game:GetService("ReplicatedStorage").Shared
local OddsText=require(Shared.OddsText);local Catalog=require(Shared.ToyCatalog);local Art=require(script.Parent.DeckArt);local EggArt=require(script.Parent.EggArt)
local Reveal=require(script.Parent.HueItemReveal);local ItemArt=require(script.Parent.RewardItemArt)
local Panel={};Panel.__index=Panel
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
 self.reveal=Reveal.new(self.art,{audio=self.options.audio,reduceEffects=self.options.reduceEffects,recipeId="toy",resultBuilder=ItemArt.create})
 self.pool=label(root,"AvailableOdds","","Body");self.status=label(root,"Status","","Body")
 self.useNow=button(root,"UseNow","Use now",function()self:useResult()end)
 self.shop=button(root,"ToyEggShop","Toy Egg · 8 Stars",function()if self.options.shop then self.options.shop()end end)
 for _,id in ipairs(Catalog.Order)do self.rows[id]=button(root,"Toy_"..id,Catalog.ById[id].name,function()self:choose(id)end)end
 return self
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
 if self.options.useNow then self.options.useNow(result);return true end;return false
end
function Panel:refresh(state,petId,mode,animate)
 self.state,self.petId,self.mode=state or {},petId,mode;self.root.Visible=mode~=nil
 self.useNow.Visible=mode=="receipt"and self.state.pendingToyResult~=nil
 if mode~="receipt"and self.reveal.resultId then self.reveal:clear()end
 if not mode then return end
 local receipt,buy=mode=="receipt",mode=="buy";local result=self.state.pendingToyResult
 self.title.Text=if receipt and result then Catalog.ById[result.toyId].name.." unlocked!"elseif buy then "Toy Egg"else "Toys"
 self.note.Text=if receipt then "Choose a pet for this toy."elseif buy then "8 Stars · one new toy. No duplicates."else "Choose one toy for this pet. Quiet garden play gives no rewards."
 self.art.Visible=receipt or buy
 if receipt and result then self.reveal:show(result,animate==true)
 elseif buy and not self.art:FindFirstChild("ToyEgg")then for _,n in ipairs(self.art:GetChildren())do n:Destroy()end;EggArt.create(self.art,"toy",UDim2.fromScale(0,0),UDim2.fromScale(1,1),self.art.ZIndex+1,"ToyEgg")end
 local selected=(self.state.petToys or {})[petId]or Catalog.Default
 for id,n in pairs(self.rows)do
  local owned=Catalog.owns(self.state.toyUnlocks,id);n.Visible=not receipt and not buy and owned
  n.Text=(if selected==id then "✓ "else "")..Catalog.ById[id].name;n.Interactable=self.intent~=nil and not self.intent.pending and selected~=id
  Art.tab(n,selected==id,n.Interactable)
 end
 local odds={};for _,entry in ipairs(Catalog.odds(self.state.toyUnlocks))do table.insert(odds,Catalog.ById[entry.id].name.." · "..OddsText.format(entry.probability))end
 self.pool.Visible=buy;self.pool.Text=if #odds==0 then "All toys owned"else table.concat(odds,"\n")
 self.shop.Visible=not receipt and not buy;self.shop.Text=if #odds==0 then "All toys owned"else "Toy Egg · 8 Stars"
 self.shop.Interactable=#odds>0 and self.intent~=nil and not self.intent.pending;self.useNow.Interactable=self.intent~=nil and not self.intent.pending
 self.status.Text=self.intent and self.intent.message or "";self.status.Visible=self.status.Text~=""
end
function Panel:layout(width,compact,availableHeight)
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
  Cards.dress(node,{name=Catalog.ById[id].name,status=if wearing then "WEARING"else "Owned",tone=if wearing then "accent"else "soft",icon=if id=="none"then "none"else "ball",focused=i==focusIndex,compact=compact})
  table.insert(focus,{button=node,id=id,wearing=wearing,name=Catalog.ById[id].name,act=function()return self:choose(id)end})
 end
 local y=h+12
 if self.shop.Visible then
  Art.type(self.shop,"Action");local sh=math.max(44,Art.actionHeight(self.shop,width-6));place(self.shop,3,y,width-6,sh);y+=sh+8
 end
 if self.status.Visible then Art.type(self.status,"Body",compact);local sh=Art.textHeight(self.status,width-6,24);place(self.status,3,y,width-6,sh);y+=sh+8 end
 self.root.Size=UDim2.fromOffset(width,y);return y,focus
end
function Panel:destroy()self.reveal:destroy();self.root:Destroy()end
return Panel
