-- Deck style owner (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 4; build plan
-- "Architect review changes" 1). The picker object and the fields init.client.lua
-- reads stay: `shade` is the Deck style root, `tabs` maps Shell / Background to the
-- two style tab buttons, and `active`, `sound`, `music`, `cancel` keep their meaning.
-- Faceplates and Backgrounds are the two tabs of the Deck style screen
-- (FaceplateShop + BackgroundShop, under Kit.header); this module opens it on a tab
-- and relays equip / use / buy / save notices. Settings stays here as a Kit panel under
-- the shared header (no Stars capsule). Pocket Trials are retired (QA 2026-11-13 Q5):
-- no page, no route; the saved TrialMask is left untouched.
local Shared=game:GetService("ReplicatedStorage").Shared
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Themes=require(Shared.DeckThemes)
local Backgrounds=require(Shared.DeckBackgrounds)
local AppearanceCatalog=require(Shared.AppearanceCatalog)
local catalogs={Shell=Themes,Background=Backgrounds}
local slots={Shell="theme",Background="background"}
local Shop=require(script.Parent.FaceplateShop)
-- Balls (batch 2026-11-13 R1) is a style tab but not an appearance slot: ball
-- themes are bought and equipped through the hatching save (BallShop).
local TabOrder={"Shell","Background","Balls"}
local styleTab={Shell=1,Background=2,Balls=3}
local Art=require(script.Parent.DeckArt)
local Kit=require(script.Parent.DeckKit)
local AppearanceIntent=require(script.Parent.AppearanceIntent)
local SaveNotice=require(script.Parent.SaveNotice)
local Picker={};Picker.__index=Picker
Picker.TabOrder=TabOrder
local ControllerFocus=require(script.Parent.ControllerFocus)
local function visibleSelection(node)
 if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox()then return nil end
 local playerGui=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
 return if ControllerFocus.live(node,nil,playerGui,true)then node else nil
end
local function place(node,x,y,w,h)node.Position,node.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)end
local function text(parent,name,value,role)
 local node=Art.text(parent,name,value,UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),"text",16)
 Art.type(node,role);node.TextXAlignment=Enum.TextXAlignment.Left;return node
end
local function button(parent,name,value,action)
 local node=Instance.new("TextButton");node.Name,node.Text,node.Parent=name,value,parent
 node.BackgroundColor3,node.TextColor3,node.BorderSizePixel,node.ZIndex=Art.Raised,Art.Silver,0,parent.ZIndex+1
 Art.bind(node,{BackgroundColor3="raised",TextColor3="text"});Art.button(node,10);Art.type(node,"Action");node.Activated:Connect(action);return node
end
-- Appearance intent words for a slot ("Saved" says nothing: the card already does).
-- QA Q2.4: a change shows as worn the moment it is chosen (optimistic), so Pending and
-- Applied say nothing; only a refusal or a lost reply speaks up.
local Words={Rejected="Not applied",Retry="Reply delayed - Retry"}
local function retryable(status)
 return status~=nil and(status.status=="Retry"or(status.status=="Rejected"and status.reason~="Superseded"and status.reason~="Locked"and status.reason~="InvalidChoice"and status.reason~="Invalid"))
end

function Picker.new(gui,make,label,onPreview,onClose,onApply,onSetting)
 local shade=Art.frame(gui,"DeckPicker","ink",UDim2.fromScale(0,0),UDim2.fromScale(1,1),20)
 shade.BackgroundTransparency,shade.Active,shade.Visible=1,true,false
 -- Settings card: a Kit panel with the shared header on top.
 local card=Kit.frame(shade,"Card","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(100,44),30)
 card.AnchorPoint=Vector2.new(.5,0);card.Active=true;Kit.stroke(card)
 local scroll=Instance.new("ScrollingFrame");scroll.Name,scroll.Parent="Scroll",card
 scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ZIndex=1,0,card.ZIndex+1
 scroll.ScrollingDirection,scroll.ElasticBehavior=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never
 scroll.ScrollBarThickness=4;Art.bind(scroll,{ScrollBarImageColor3="accent"})
 local self=setmetatable({shade=shade,card=card,scroll=scroll,tabs={},choices={Shell={},Background={}},rows={},
  onPreview=onPreview,onClose=onClose,onApply=onApply,available={},confirmed={},onSetting=onSetting,active="Shell"},Picker)
 -- Accepted marks per choice (read by specs and the old callers; the cards draw them).
 for tab,catalog in pairs(catalogs)do for _,id in ipairs(catalog.Order)do self.choices[tab][id]={Enabled=false,id=id}end end
 self.saveMarker=text(card,"SaveStatus","","Supporting");Art.bind(self.saveMarker,{TextColor3="reward"});self.saveMarker.TextYAlignment=Enum.TextYAlignment.Top;self.saveMarker.Visible=false
 self.saveDetail=text(scroll,"SaveInstruction","","Body");Art.bind(self.saveDetail,{TextColor3="reward"});self.saveDetail.Visible=false
 self.moreCue=Art.frame(card,"MoreBelow","panel",UDim2.fromOffset(0,0),UDim2.fromOffset(12,20),40)
 self.moreCue.BackgroundTransparency=1;self.moreCue.Active=false;self.moreCue.Selectable=false
 for _,entry in ipairs({{1,45},{5,-45}})do
  local bar=Art.frame(self.moreCue,"Chevron","accent",UDim2.fromOffset(entry[1],8),UDim2.fromOffset(7,2),41);bar.Rotation=entry[2]
 end
 scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()self:refreshScrollCue()end)
 scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:refreshScrollCue()end)
 self:ensureHeader(false)
 self.sound=button(scroll,"SoundSetting","SFX: On",function()self:changeSetting("sound")end)
 self.music=button(scroll,"MusicSetting","Music: On",function()self:changeSetting("music")end)
 self.motion=button(scroll,"MotionSetting","Motion: Full",function()self:changeSetting("motion")end)
 -- v1 track B: opens the bug report / suggestion sheet (init.client sets `onReport`).
 self.reportButton=button(scroll,"ReportSetting",require(Shared.UICopy).get("report.entry"),function()self:openReport()end)
 shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:layout()end)
 Art.watchTextPreference(shade,function()return shade.Visible end,function()self.safeTop=nil;self:layout()end)
 self.shop=Shop.new(shade,{
  equip=function(id)if self.shade.Visible and self.onApply then self.onApply("theme",id);if self.onAccepted then self.onAccepted("confirm")end end end,
  buy=function(order)if self.onBuy then self.onBuy(order)end;if self.onAccepted then self.onAccepted("confirm")end end,
  bought=function(id)if self.onBought then self.onBought(id)end end,
  back=function()self:back()end,
  tab=function(index)return self:activateTab(TabOrder[index])end,
  use=function(id)self:useBackground(id)end,
  retry=function(slot)self:retry(slot)end,
  rebuilt=function(shop)self:syncTabs(shop)end,
  ballBought=function(id)if self.onBallBought then self.onBallBought(id)end end,
  ballEquipped=function(id)if self.onBallEquipped then self.onBallEquipped(id)end end,
 })
 self:syncTabs(self.shop)
 self:showTab("Shell");return self
end
-- `tabs.Shell` / `tabs.Background` are the Deck style tab buttons (rebuilt with the view).
function Picker:syncTabs(shop)
 local row=shop and shop.tabs;if not row then return end
 for index,tab in ipairs(TabOrder)do self.tabs[tab]=row.buttons[index]end
 local background=self.tabs.Background;if background then background:SetAttribute("AccessibleLabel","Background patterns")end
end
-- The shared header for Settings (rebuilt when compactness changes).
function Picker:ensureHeader(compact)
 if self.header and self.header.compact==compact then return self.header end
 local selected=self.cancel~=nil and GuiService.SelectedObject==self.cancel
 if self.header then self.header.root:Destroy()end
 local header=Kit.header(self.card,{title="Settings",eyebrow="Pocket deck",wallet=false,compact=compact,width=math.max(200,self.card.Size.X.Offset),onBack=function()self:back()end})
 self.header=header;self.heading=header.title
 self.cancel=header.back.root;self.closeButton=self.cancel
 self.cancel.Selectable=true;self.cancel.ZIndex=60
 if selected then GuiService.SelectedObject=self.cancel end
 return header
end
-- Owned faceplates and the wallet come from the nursery snapshot.
-- ballThemes = { owned, equipped } and the snapshot revision (hatching v11).
function Picker:setShopState(wallet,faceplates,ballThemes,revision)
 self.faceplates=faceplates or {};self.wallet=wallet or 0
 local balls=if type(ballThemes)=="table"then ballThemes else {}
 self.shop.balls:setContext({wallet=self.wallet,owned=balls.owned or {},equipped=balls.equipped,revision=revision})
 if self.facts then self.facts.faceplates=self.faceplates end
 self.shop:setContext({wallet=self.wallet,facts=self.facts or {faceplates=self.faceplates}})
 self.shop.backgrounds:setContext({facts=self.facts or {faceplates=self.faceplates}})
end
-- True while the Deck style screen (either tab) owns input.
function Picker:shopOpen()return self.shade.Visible and styleTab[self.active]~=nil end
function Picker:layout()
 if self.layingOut then return end;self.layingOut=true
 local size=self.shade.AbsoluteSize;local short=size.Y<220
 if self.shop then self.shop:fit(size)end
 self.roomy=size.X>=1000 and size.Y>=650
 local function styleType(n,r,c)return Art.roomyType(n,r,c,self.roomy)end
 local compact=Kit.compactRule(size.X,size.Y)
 local width=math.max(1,math.min(if self.roomy then 720 else 620,size.X-24));local pad=if short then 8 else 16
 local usable=width-pad*2
 local header=self:ensureHeader(compact)
 local headerH=if compact then 60 else 84
 styleType(self.saveMarker,"Supporting",short)
 local markerW=0
 if short and self.saveNotice then
  local limit=usable*.42
  self.saveMarker.Text=SaveNotice.caption(self.saveNotice,function(value)return Art.textWidth(self.saveMarker,value)+16<=limit end)
  markerW=math.min(limit,Art.textWidth(self.saveMarker)+16)
 end
 local scrollW=usable-(if markerW>0 then markerW+12 else 0);local bodyW=scrollW-8
 header.setTitle(if self.saveNotice then self.saveNotice.short else "Settings","Pocket deck")
 header.layout(width,24)
 local maximum=math.max(1,size.Y-(if short then 8 else 24))
 local function layoutBody()
  local y=4
  if self.saveNotice then
   styleType(self.saveDetail,"Body",short);self.saveDetail.Text=self.saveNotice.detail
   local h=Art.textHeight(self.saveDetail,bodyW-8,24)
   place(self.saveDetail,4,y,bodyW-8,h);y+=h+12
  end
  for _,control in ipairs({self.sound,self.music,self.motion,self.reportButton})do
   styleType(control,"Action",short);local h=Art.actionHeight(control,bodyW-8)
   place(control,4,y,bodyW-8,h);y+=h+8
  end
  return y
 end
 local y=layoutBody()
 if self.safeTop==nil or self.layoutRootSize~=size then
  local tallest=headerH+y+8
  self.safeTop=math.max(0,(size.Y-math.min(maximum,tallest))/2);self.layoutRootSize=size
  -- Phones: the card starts under the Roblox controls when there is room (QA 2026-11-12).
  if compact and not short then local _,kh=Kit.keepOut();if size.Y-(kh+2)>=headerH+96 then self.safeTop=math.max(self.safeTop,kh+2)end end
 end
 local height=math.min(maximum,math.max(1,size.Y-self.safeTop-4),headerH+y+8)
 self.card.Position,self.card.Size=UDim2.new(.5,0,0,self.safeTop),UDim2.fromOffset(width,height)
 Kit.corner(self.card,if compact then 16 else 30)
 self.saveMarker.Visible=markerW>0;self.saveDetail.Visible=self.saveNotice~=nil
 place(self.saveMarker,pad,headerH,markerW,math.max(44,height-headerH-4))
 place(self.scroll,pad+(if markerW>0 then markerW+12 else 0),headerH,scrollW,math.max(44,height-headerH-4))
 self.scroll.CanvasSize=UDim2.fromOffset(0,y)
 place(self.moreCue,width-pad-12,headerH+self.scroll.Size.Y.Offset-20,12,20)
 self.scroll.CanvasPosition=Vector2.new(0,math.clamp(self.scroll.CanvasPosition.Y,0,math.max(0,y-self.scroll.Size.Y.Offset)))
 self:refreshScrollCue();self.layingOut=false
end
function Picker:refreshScrollCue()
 local height=self.scroll.AbsoluteSize.Y
 local overflow=self.scroll.CanvasSize.Y.Offset>height+1
 self.scroll.ScrollingEnabled=overflow;self.scroll.ScrollBarImageTransparency=if overflow then 0 else 1
 self.moreCue.Visible=overflow and self.scroll.CanvasPosition.Y+height<self.scroll.CanvasSize.Y.Offset-1
end
function Picker:setSaveNotice(notice)
 if SaveNotice.key(self.saveNotice)==SaveNotice.key(notice)then return false end
 self.saveNotice=notice;self:layout();return true
end
-- A style tab press (tab row, Q / E, LB / RB): Shell <-> Background only.
function Picker:activateTab(active)
 if not self.shade.Visible or self.active==active or not styleTab[active]then return false end
 if self:showTab(active)~=true then return false end
 if self.onAccepted then self.onAccepted("tab")end;return true
end
-- Q / E and LB / RB on the Deck style screen.
function Picker:shiftStyleTab(delta)
 if not self:shopOpen()then return false end
 return self.shop:shiftTab(delta)
end
function Picker:showTab(active)
 -- Pocket Trials ("Trials", the old "Club") are retired (QA Q5): never a tab now.
 if self.customizationEntry==false and active~="Settings"then return false end
 if not styleTab[active]and active~="Settings"then return false end
 if not self.returningFromInner and active~=self.active then self.inspectId,self.inspectSlot=nil,nil end
 local changed=self.active~=active;self.active=active
 local style=styleTab[active]~=nil
 local shopping=style and self.shade.Visible
 self.card.Visible=not style
 self:refreshAppearance()
 if shopping then
  local tabIndex=styleTab[active]
  if self.shop.visible then self.shop:setTab(tabIndex)
  else self.shop:open(self.confirmed and self.confirmed.theme,tabIndex,self.returningFromInner==true)end
 else self.shop:close()end
 local settings=active=="Settings"
 self.sound.Visible,self.music.Visible,self.motion.Visible=settings,settings,settings
 self.reportButton.Visible=settings and self.onReport~=nil
 self.scroll.CanvasPosition=Vector2.zero;self:layout()
 if changed then
  self:bumpControllerEpoch();local selected=GuiService.SelectedObject
  if shopping then GuiService.SelectedObject=nil
  elseif not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()and string.match(UserInputService:GetLastInputType().Name,"^Gamepad")then GuiService.SelectedObject=if active=="Settings"then self.sound else self.cancel
  elseif selected and selected:IsDescendantOf(self.shade)then GuiService.SelectedObject=nil end
 end
 return true
end
-- Choosing a card. Locked choices are inspected (shown with their unlock rule, never
-- sent); unlocked ones go to the appearance intent at once.
function Picker:activateChoice(tab,id)
 if self.customizationEntry==false then return false end
 local catalog=catalogs[tab]
 if not self.shade.Visible or self.active~=tab or not catalog or not catalog.ById[id]then return false end
 if self.shop.visible then
  if tab=="Background"then self.shop.backgrounds:focusId(id)else self.shop:focusId(id)end
 end
 if not AppearanceCatalog.canEquip(slots[tab],id,self.facts)then
  if self.inspectId==id and self.inspectSlot==slots[tab]then return false end
  self.inspectId,self.inspectSlot=id,slots[tab];self:refreshAppearance();if self.onAccepted then self.onAccepted("confirm")end;return true
 end
 local wasInspect=self.inspectId~=nil;self.inspectId,self.inspectSlot=nil,nil
 local applied=if self.onApply then self.onApply(slots[tab],id)else false
 if wasInspect then self:refreshAppearance()end
 if (wasInspect or applied~=false)and self.onAccepted then self.onAccepted("confirm")end
 return true
end
-- The Backgrounds pane's Use.
function Picker:useBackground(id)
 if not self.shade.Visible or self.active~="Background"then return false end
 return self:activateChoice("Background",id)
end
function Picker:retry(slot)
 if not self.shade.Visible or not self.onRetry then return false end
 if self.onRetry(slot or slots[self.active]or "theme")~=false then if self.onAccepted then self.onAccepted("confirm")end;return true end
 return false
end
-- Settings > Report a bug / Suggest something: the sheet opens over Settings, which
-- stays open underneath (Back on the sheet returns here).
function Picker:openReport()
 if not self.shade.Visible or self.active~="Settings"or not self.onReport then return false end
 if self.onReport()==false then return false end
 if self.onAccepted then self.onAccepted("confirm")end;return true
end
function Picker:changeSetting(key)
 local control=if key=="sound"then self.sound elseif key=="music"then self.music elseif key=="motion"then self.motion else nil
 if not self.shade.Visible or self.active~="Settings"or not control or not control.Interactable then return false end
 self.onSetting(key);if self.onAccepted then self.onAccepted("confirm")end;return true
end
-- The Deck style screen previews plates itself; kept for old callers.
function Picker:preview(themeId)return Themes.ById[themeId]~=nil end
function Picker:select(themeId,stickerId,backgroundId)
 self.themeId,self.stickerId,self.backgroundId=themeId,stickerId,backgroundId or Backgrounds.Default;self.confirmed={theme=themeId,sticker=stickerId,background=backgroundId or Backgrounds.Default};self:refreshAppearance();self:layout();return true
end
function Picker:setAppearance(state)
 self.appearance=state;self.themeId,self.stickerId,self.backgroundId=state.themeId,state.stickerId,state.backgroundId or Backgrounds.Default
 self.confirmed={theme=state.confirmedTheme,sticker=state.confirmedSticker,background=state.confirmedBackground or Backgrounds.Default};self:refreshAppearance();if self.shade.Visible then self:layout()end
end
-- What the appearance intent says about a slot: words, retryable, raw status.
function Picker:slotNote(slot)
 local status=self.appearance and self.appearance.slots and self.appearance.slots[slot]
 local fallback=self.appearance and self.appearance.fallbacks and self.appearance.fallbacks[slot]
 local note=if status and Words[status.status]then Words[status.status]..(if status.reason then " - "..status.reason else "")else nil
 if fallback then
  local catalog=if slot=="background"then Backgrounds else Themes;local id=self.confirmed[slot]
  local name=catalog.ById[id]and catalog.ById[id].name or "default"
  note="Previous "..(if slot=="theme"then "shell"else slot).." unavailable - using "..name..(if status and status.status=="Pending"then " - Applying..."else "")
 end
 return note,retryable(status),status
end
-- One line for the active style tab: the inspected unlock rule, else the intent's words.
function Picker:appearanceText()
 local slot=slots[self.active]or "theme"
 if self.inspectId and self.inspectSlot==slot then
  local inspected=AppearanceCatalog.describeRequirement(self.inspectSlot,self.inspectId,self.facts)
  return if inspected.unlocked then "Available - Select to wear"else "Locked - "..inspected.text..string.format(" (%d/%d)",inspected.progress,inspected.target)
 end
 return (self:slotNote(slot))or "Select to wear immediately."
end
function Picker:refreshAppearance()
 -- Optimistic (QA Q2.4): the choice in flight shows as worn; a refusal shows the confirmed one again.
 local shown={}
 for _,slot in ipairs({"theme","sticker","background"})do shown[slot]=AppearanceIntent.shown(self.appearance,slot)or self.confirmed[slot]end
 self.shown=shown
 for tab,choices in pairs(self.choices)do for id,mark in pairs(choices)do mark.Enabled=shown[slots[tab]]==id end end
 if not self.shop then return end
 local themeNote,themeRetry=self:slotNote("theme")
 local backgroundNote,backgroundRetry=self:slotNote("background")
 self.shop:setContext({equipped=shown.theme or Themes.Default,facts=self.facts,chosen=self.themeId or false,note=themeNote or false,retry=themeRetry})
 self.shop.backgrounds:setContext({confirmed=shown.background or Backgrounds.Default,facts=self.facts or {},themeId=shown.theme or Themes.Default,
  chosen=self.backgroundId or false,note=backgroundNote or false,retry=backgroundRetry})
end
function Picker:updateClub(owned,mask,peak,score,sound,reduced,systemReduced,inventoryMask,musicEnabled,totalWins,masteryRanks)
 self.facts={rank=owned,trials=mask,inventoryMask=inventoryMask,totalWins=totalWins or 0,masteryRanks=masteryRanks or {},faceplates=self.faceplates}
 self.sound.Text="SFX: "..sound
 self.music.Text=if musicEnabled==false then "Music: Off"else "Music: On"
 self.motion.Text=if systemReduced then "Motion: Roblox"elseif reduced then "Motion: Low"else "Motion: Full"
 self.motion.Interactable,self.motion.Selectable=not systemReduced,not systemReduced
 -- `mask` (the saved TrialMask) still feeds the background unlock facts; Pocket
 -- Trials have no page any more (QA Q5), so `peak` and `score` go unused here.
 self:refreshAppearance()
 local key=table.concat({self.sound.Text,self.music.Text,self.motion.Text},"|")
 if self.shade.Visible and self.clubLayoutKey~=key then self:layout()end
 self.clubLayoutKey=key
end
function Picker:bumpControllerEpoch()
 self.shade:SetAttribute("ControllerEpoch",(self.shade:GetAttribute("ControllerEpoch")or 0)+1)
end
function Picker:getControllerFocus()
 if not self.shade.Visible then return nil end
 -- The Deck style screen owns its focus ring; the coordinator selects nothing native.
 if styleTab[self.active]then return{root=self.shade,epoch=self.shade:GetAttribute("ControllerEpoch")or 0,target=function()return nil end}end
 return{root=self.shade,epoch=self.shade:GetAttribute("ControllerEpoch")or 0,
  target=function()return if self.active=="Settings"then self.sound else self.cancel end,fallback=self.cancel}
end
function Picker:open(themeId,stickerId,mode)
 self:bumpControllerEpoch();self.previousSelection=GuiService.SelectedObject;self.safeTop=nil;self.innerReturn=nil;self.inspectId,self.inspectSlot=nil,nil
 self.shade.Visible=true;if not self.appearance then self:select(themeId,stickerId)end
 self:showTab(mode or "Shell")
 if self:shopOpen()then GuiService.SelectedObject=nil
 elseif string.match(UserInputService:GetLastInputType().Name,"^Gamepad")then GuiService.SelectedObject=if self.active=="Settings"then self.sound else self.cancel end
end
function Picker:back()
 if not self.shade.Visible then return false end
 if self.onAccepted then self.onAccepted("back")end
 if self.innerReturn then
  local saved=self.innerReturn;self.innerReturn=nil
  self.returningFromInner=true;self:showTab(saved.active);self.returningFromInner=nil
  return
 end
 self:close("back")
end
function Picker:close(reason)
 self.shop:close() -- returns the borrowed background renderer in the same step
 if not self.shade.Visible then return end
 self:bumpControllerEpoch();self.shade.Visible=false;self.card.Visible=true;self.innerReturn=nil;self.onClose(reason or "forced")
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then GuiService.SelectedObject=visibleSelection(self.previousSelection)end
end
return Picker
