-- Difficulty picker inside the deck LCD (UI-SPEC-2026-11-12 section 5.2,
-- mockup 02). Presentation only: the server validates and stores the heat and
-- freezes it at the first drop; every "Win pays" number comes from the server's
-- HeatPays attribute. Focus is owned here: left / right choose (no wrap), A or
-- Start starts, B leaves, Menu opens the quest log. Touch: tap a card to select,
-- tap it again (or Start) to start.
local Shared=game:GetService("ReplicatedStorage").Shared
local Config=require(Shared.BoardConfig)
local Payout=require(Shared.HeatPayout)
local Kit=require(script.Parent.DeckKit)
local Picker={}
Picker.__index=Picker
local tones={easy="good",medium="stars",hard="danger"}

local function txt(parent,role,content,color,x,y,w,h,props)
 local t=Kit.text(parent,role,content,color,props);t.Position=UDim2.fromOffset(x,y);t.Size=UDim2.fromOffset(w,h);return t
end
-- Pure: next focus index (no wrap).
function Picker.step(index,direction)return math.clamp(index+direction,1,#Config.HeatOrder)end
-- Pure: "Win pays 9 to 12" from the server's pays table, or nil when unknown.
function Picker.paysText(pays,key)
 local pair=type(pays)=="table"and pays[key]
 if type(pair)~="table"or type(pair[1])~="number"or type(pair[2])~="number"then return nil end
 return "Win pays "..pair[1].." to "..pair[2]
end

function Picker.new(overlay,callbacks)
 local self=setmetatable({overlay=overlay,callbacks=callbacks or {},index=2,visible=false,cards={}},Picker)
 self:build(nil)
 overlay.onLayout=function(view)
  local key=if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"
  if key==self.key then return end
  self:build(view)
  if self.visible and self.data then self.visible=false;self:show(self.data)end
 end
 return self
end

-- Pure (UI-SPEC-COMPACT 6): what a compact card shows at cw x ch.
function Picker.compactCard(cw,ch)
 return{bullets=ch>=205 and cw>=200,tidy=ch>=244,hairline=if ch>=244 then ch-62 else ch-44}
end

function Picker:clear()
 if self.ring then self.ring.hide();self.ring.root:Destroy()end
 for _,child in ipairs(self.overlay.content:GetChildren())do if not(child:IsA("UIScale")or child:IsA("UIPadding"))then child:Destroy()end end
 self.cards={};self.questButton=nil
end

-- Compact (phone) picker: a menu sheet with three cards and an action row.
function Picker:buildCompact(v)
 local root=self.overlay.content
 local W,H,cw,ch=v.W,v.H,v.cw,v.ch
 local sheet=Kit.sheet(root,W,H)
 local body=Kit.frame(root,"Body",nil,UDim2.new(),UDim2.fromScale(1,1));body.ZIndex=sheet.ZIndex+3
 txt(body,"Title","Pick a difficulty","text",v.hx,18,300,24,{TextSize=20})
 self.wallet=Kit.wallet(body,32);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(W-66,14)
 local show=Picker.compactCard(cw,ch)
 for index,key in ipairs(Config.HeatOrder)do
  local heat=Config.Heat[key]
  local card=Kit.node("TextButton",body,{Name="Heat_"..key,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
   Position=UDim2.fromOffset(20+(index-1)*(cw+10),64),Size=UDim2.fromOffset(cw,ch),ZIndex=body.ZIndex+1})
  card:SetAttribute("AccessibleLabel",heat.name.." "..heat.nickname)
  Kit.corner(card,14);local stroke=Kit.stroke(card)
  local tone=tones[key]
  -- The tone eyebrow sits on a well chip so it never lands on `selected`.
  local chip=Kit.frame(card,"Tone","well",UDim2.fromOffset(12,10),UDim2.fromOffset(40,20),999);Kit.stroke(chip)
  local toneLabel=txt(chip,"Label",string.upper(heat.name),tone,0,0,40,20,{TextSize=12,TextXAlignment=Enum.TextXAlignment.Center})
  local tw=game:GetService("TextService"):GetTextSize(toneLabel.Text,12,Enum.Font.BuilderSansBold,Vector2.new(300,40)).X
  chip.Size=UDim2.fromOffset(tw+20,20);toneLabel.Size=UDim2.fromOffset(tw+20,20)
  for bar,h in ipairs({10,16,22})do
   local b=Kit.frame(card,"Bar"..bar,tone,UDim2.fromOffset(cw-12-24+(bar-1)*9,9+22-h),UDim2.fromOffset(6,h),2)
   b.BackgroundTransparency=if bar<=heat.index then 0 else .75
  end
  txt(card,"Title",heat.nickname,"text",12,35,cw-24,24,{TextSize=20})
  local reward=Kit.chip(card,"★ "..Payout.label(key).." STARS","gold",24);reward.label.TextSize=12;reward.set("★ "..Payout.label(key).." STARS","gold")
  reward.root.Position=UDim2.fromOffset(12,64)
  if show.bullets then
   for line,bullet in ipairs(heat.bullets)do
    local y=108+(line-1)*22
    Kit.frame(card,"Dot"..line,tone,UDim2.fromOffset(13,y-3),UDim2.fromOffset(6,6),999)
    txt(card,"Body",bullet,"soft",28,y-10,cw-40,20,{TextSize=14,TextTruncate=Enum.TextTruncate.AtEnd})
   end
  end
  local hair=Kit.frame(card,"Hairline",nil,UDim2.fromOffset(12,show.hairline),UDim2.fromOffset(cw-24,1));hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.9
  local pays=txt(card,"Strong","","text",12,show.hairline+10,cw-24,20,{TextSize=14})
  local tidy=txt(card,"Counter","","soft",12,show.hairline+32,cw-24,20,{TextSize=12,Visible=show.tidy})
  self.cards[index]={key=key,button=card,stroke=stroke,pays=pays,tidy=tidy}
  card.Activated:Connect(function()
   if self.index==index then self:confirm()else self:focus(index);if self.callbacks.select then self.callbacks.select(key)end end
  end)
 end
 -- Action row: Quests (left thumb, only while the caller routes it; QA Q5 moved the
 -- quest log to the garden hub, so the round picker has none), goal line, Start.
 local ay=v.actionY
 local gx=20
 if self.callbacks.quests then
  local quests=Kit.button(body,"Quests",{text="Quests",size=Vector2.new(148,48),textSize=15,selectable=false})
  quests.Position=UDim2.fromOffset(20,ay)
  local qs=Kit.buttonState(quests)
  local qicon=Kit.icon(qs.content,"quests",18,"text");qicon.LayoutOrder=1
  self.questDot=Kit.frame(quests,"ReadyDot","stars",UDim2.new(1,-12,0,4),UDim2.fromOffset(8,8),999);self.questDot.ZIndex=quests.ZIndex+6;self.questDot.Visible=false
  quests.Activated:Connect(function()if self.callbacks.quests then self.callbacks.quests()end end)
  self.questButton=quests;gx=180
 end
 local startW=if W<600 then 160 else 200
 self.start=Kit.button(body,"Start",{variant="primary",text="Start",glyph="A",size=Vector2.new(startW,48),textSize=16,selectable=false})
 self.start.Position=UDim2.fromOffset(W-20-startW,ay)
 self.start.Activated:Connect(function()self:confirm()end)
 local gw=W-20-startW-12-gx
 local target=Kit.icon(body,"target",18,"soft");target.Position=UDim2.fromOffset(gx,ay+15)
 self.goalText=txt(body,"Body","","soft",gx+26,ay,math.max(20,gw-26),48,{TextSize=14,TextWrapped=true})
 self.questText=nil
 self.ring=Kit.focusRing(self.overlay.layer)
end

function Picker:build(view)
 self:clear()
 self.key=if view then string.format("%dx%d:%d",view.W,view.H,view.hx)else "regular"
 self.phone=view~=nil
 if view then return self:buildCompact(view)end
 local root=self.overlay.content
 txt(root,"Label","EGG DROP","dim",24,16,200,16)
 txt(root,"Title","Pick a difficulty","text",24,34,400,34)
 self.wallet=Kit.wallet(root,40);self.wallet.root.AnchorPoint=Vector2.new(1,0);self.wallet.root.Position=UDim2.fromOffset(824,24)
 for index,key in ipairs(Config.HeatOrder)do
  local heat=Config.Heat[key]
  local x=24+(index-1)*272
  local card=Kit.node("TextButton",root,{Name="Heat_"..key,Text="",AutoButtonColor=false,BackgroundTransparency=0,Selectable=false,
   Position=UDim2.fromOffset(x,96),Size=UDim2.fromOffset(256,356),ZIndex=root.ZIndex+1})
  card:SetAttribute("AccessibleLabel",heat.name.." "..heat.nickname)
  Kit.corner(card,14);local stroke=Kit.stroke(card)
  local tone=tones[key]
  txt(card,"Label",string.upper(heat.name),tone,20,20,150,16)
  for bar,h in ipairs({10,16,22})do
   local b=Kit.frame(card,"Bar"..bar,tone,UDim2.fromOffset(256-46+(bar-1)*9,20+22-h),UDim2.fromOffset(6,h),2)
   b.BackgroundTransparency=if bar<=heat.index then 0 else .75
  end
  txt(card,"Title",heat.nickname,"text",20,40,220,34)
  local chip=Kit.chip(card,"★ "..Payout.label(key).." STARS","gold",32);chip.root.Position=UDim2.fromOffset(20,86)
  for line,bullet in ipairs(heat.bullets)do
   local y=150+(line-1)*32
   Kit.frame(card,"Dot"..line,tone,UDim2.fromOffset(22,y+8),UDim2.fromOffset(7,7),999)
   txt(card,"Body",bullet,"soft",38,y,200,24)
  end
  local hair=Kit.frame(card,"Hairline",nil,UDim2.fromOffset(20,268),UDim2.fromOffset(216,1));hair.BackgroundColor3,hair.BackgroundTransparency=Color3.new(1,1,1),.9
  local pays=txt(card,"Strong","","text",20,284,220,24,{TextSize=17})
  local tidy=txt(card,"Counter","","dim",20,312,220,18,{TextSize=13})
  self.cards[index]={key=key,button=card,stroke=stroke,pays=pays,tidy=tidy}
  card.Activated:Connect(function()
   if self.index==index then self:confirm()else self:focus(index);if self.callbacks.select then self.callbacks.select(key)end end
  end)
 end
 -- Info strip.
 local strip=Kit.frame(root,"InfoStrip","well",UDim2.fromOffset(24,468),UDim2.fromOffset(800,48),12);Kit.stroke(strip)
 local target=Kit.icon(strip,"target",20,"soft");target.Position=UDim2.fromOffset(14,14)
 self.goalText=txt(strip,"Small","","soft",44,0,380,48,{TextSize=15})
 self.questText=txt(strip,"Small","","soft",420,0,366,48,{TextSize=15,TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd})
 -- Hints and Start (QA Q5: MENU pauses; the quest log opens from the garden hub).
 local hints=Kit.frame(root,"Hints",nil,UDim2.fromOffset(24,548),UDim2.fromOffset(560,24))
 local x=0
 for _,pair in ipairs({{"◀▶","Choose"},{"MENU","Pause"},{"B","Garden"}})do
  local g=Kit.glyph(hints,pair[1],false,22,true);g.Position=UDim2.fromOffset(x,1)
  local w=g.Size.X.Offset
  txt(hints,"Small",pair[2],"soft",x+w+6,0,80,24)
  x+=w+6+game:GetService("TextService"):GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
 end
 self.start=Kit.button(root,"Start",{variant="primary",text="Start",glyph="A",size=Vector2.new(200,56),selectable=false})
 self.start.Position=UDim2.fromOffset(624,532)
 self.start.Activated:Connect(function()self:confirm()end)
 self.ring=Kit.focusRing(self.overlay.layer)
end

function Picker:focus(index)
 self.index=math.clamp(index,1,#self.cards)
 for i,card in ipairs(self.cards)do
  local on=i==self.index
  Kit.paint(card.button,"BackgroundColor3",if on then "selected"else "raised")
  card.stroke.Thickness=if on then 2 else 1;card.stroke.Transparency=if on then 0 else .86
  Kit.paint(card.stroke,"Color",function()return if on then Kit.color("accent")else Color3.new(1,1,1)end)
 end
 if self.visible then self.ring.attach(self.cards[self.index].button,14)end
 self.overlay.layer:SetAttribute("SelectedHeat",self.cards[self.index].key)
end

-- data = { selected = key, pays = {easy={5,6},...}, wallet, goal, quest }
function Picker:show(data)
 local opening=not self.visible
 self.data=data;self.visible=true;self.overlay.layer.Visible=true
 self.wallet.set(data.wallet or 0)
 for _,card in ipairs(self.cards)do
  card.pays.Text=Picker.paysText(data.pays,card.key)or "Win pays …"
  local pair=data.pays and data.pays[card.key]
  card.tidy.Text=if pair then "Tidy stack pays "..pair[2]else ""
 end
 self.goalText.Text="Goal this round: "..(data.goal or "…")
 if self.questText then self.questText.Text=if data.quest then "Quest: "..data.quest else ""end
 if self.questButton then
  Kit.setText(self.questButton,"Quests "..(data.questCount or ""))
  self.questDot.Visible=data.questReady==true
 end
 if opening then
  self:focus(table.find(Config.HeatOrder,data.selected or Config.DefaultHeat)or 2)
  if not Kit.reduced()then self.overlay.content.Position=UDim2.fromOffset(0,12);Kit.tween(self.overlay.content,Kit.Motion.screen,{Position=UDim2.new()})end
 end
 Kit.setGlyphVisible(self.start,not(self.phone and Kit.lastInputTouch()))
end
function Picker:hide()
 if not self.visible then return end
 self.visible=false;self.overlay.layer.Visible=false;self.ring.hide()
end
function Picker:move(direction)
 if not self.visible then return false end
 local nextIndex=Picker.step(self.index,direction)
 if nextIndex~=self.index then
  self:focus(nextIndex)
  if self.callbacks.select then self.callbacks.select(self.cards[nextIndex].key)end
 end
 return true
end
function Picker:selected()return self.cards[self.index].key end
function Picker:confirm()
 if not self.visible then return false end
 Kit.pulse(self.start)
 if self.callbacks.start then self.callbacks.start(self:selected())end
 return true
end
return Picker
