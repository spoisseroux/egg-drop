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
 local root=overlay.content
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
 -- Hints and Start.
 local hints=Kit.frame(root,"Hints",nil,UDim2.fromOffset(24,548),UDim2.fromOffset(560,24))
 local x=0
 for _,pair in ipairs({{"◀▶","Choose"},{"MENU","Quests"},{"B","Garden"}})do
  local g=Kit.glyph(hints,pair[1],false,22);g.Position=UDim2.fromOffset(x,1)
  local w=g.Size.X.Offset
  txt(hints,"Small",pair[2],"soft",x+w+6,0,80,24)
  x+=w+6+game:GetService("TextService"):GetTextSize(pair[2],14,Enum.Font.BuilderSans,Vector2.new(500,30)).X+18
 end
 self.start=Kit.button(root,"Start",{variant="primary",text="Start",glyph="A",size=Vector2.new(200,56),selectable=false})
 self.start.Position=UDim2.fromOffset(624,532)
 self.start.Activated:Connect(function()self:confirm()end)
 self.ring=Kit.focusRing(overlay.layer)
 return self
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
 self.questText.Text=if data.quest then "Quest: "..data.quest else ""
 if opening then
  self:focus(table.find(Config.HeatOrder,data.selected or Config.DefaultHeat)or 2)
  if not Kit.reduced()then self.overlay.content.Position=UDim2.fromOffset(0,12);Kit.tween(self.overlay.content,Kit.Motion.screen,{Position=UDim2.new()})end
 end
 Kit.setGlyphVisible(self.start,true)
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
