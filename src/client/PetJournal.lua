local GuiService=game:GetService("GuiService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Pets=require(ReplicatedStorage.Shared.PetCatalog)
local Art=require(script.Parent.DeckArt)
local Portrait=require(script.Parent.PetPortrait)
local SaveNotice=require(script.Parent.SaveNotice)
local Journal={};Journal.__index=Journal
local function visibleSelection(node)
	if not node or not node.Parent or not node:IsA("GuiObject") or not node.Selectable then return nil end
	local playerGui=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui or not node:IsDescendantOf(playerGui) then return nil end
	local ancestor=node
	while ancestor do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then return nil end
		if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return nil end
		ancestor=ancestor.Parent
	end
	return node
end
local function place(node,x,y,w,h)node.Position,node.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)end
local function text(parent,name,value,role,color)
	local node=Art.text(parent,name,value,UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),color or "text",16)
	Art.type(node,role);node.TextXAlignment=Enum.TextXAlignment.Left;return node
end
local function button(parent,name,value,action)
	local node=Instance.new("TextButton");node.Name,node.Text,node.Parent=name,value,parent
	node.BackgroundColor3,node.TextColor3,node.BorderSizePixel,node.ZIndex=Art.Raised,Art.Silver,0,parent.ZIndex+1
	Art.bind(node,{BackgroundColor3="raised",TextColor3="text"});Art.button(node,10);Art.type(node,"Action");node.Activated:Connect(action);return node
end
function Journal.new(gui,make,label,onVisit,onTrack,onGoals)
	local shade=Art.frame(gui,"PetJournal","ink",UDim2.fromScale(0,0),UDim2.fromScale(1,1),20)
	shade.BackgroundTransparency,shade.Active,shade.Visible=1,true,false
	local card=Art.frame(shade,"Card","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(680,500),21)
	card.AnchorPoint=Vector2.new(.5,.5);Art.panel(card,16)
	local scroll=Instance.new("ScrollingFrame");scroll.Name,scroll.Parent="Scroll",card
	scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ZIndex=1,0,22
	scroll.ScrollingDirection,scroll.ElasticBehavior=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never
	scroll.ScrollBarThickness,scroll.ScrollBarImageColor3=4,Art.Leaf
	local self=setmetatable({shade=shade,card=card,scroll=scroll,cards={},portraits={},onVisit=onVisit,onTrack=onTrack,onGoals=onGoals},Journal)
	self.title=text(card,"Title","Pet journal · 00/07","Heading")
	self.baseTitle=self.title.Text
	self.saveDetail=text(scroll,"SaveInstruction","","Body",Art.Amber);self.saveDetail.Visible=false
	self.moreCue=Art.frame(card,"MoreBelow","panel",UDim2.fromOffset(0,0),UDim2.fromOffset(12,20),40)
	self.moreCue.BackgroundTransparency=1;self.moreCue.Active=false;self.moreCue.Selectable=false
	for _,entry in ipairs({{1,45},{5,-45}})do
		local bar=Art.frame(self.moreCue,"Chevron",Art.Leaf,UDim2.fromOffset(entry[1],8),UDim2.fromOffset(7,2),41);bar.Rotation=entry[2]
	end
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()self:refreshScrollCue()end)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:refreshScrollCue()end)
	self.closeButton=Art.close(button(card,"Close","×",function()self:close("back")end))
	for index,pet in ipairs(Pets.collection)do
		local entry=button(scroll,pet.name,"",function()self:activatePet(index)end)
		local well=Art.frame(entry,"PortraitWell","inset",UDim2.fromOffset(8,8),UDim2.fromOffset(60,60),entry.ZIndex+1);Art.corner(well,8)
		text(entry,"Species",pet.name..(if pet.trial then " · Rare"else ""),"Action")
		text(entry,"Status","Hatch from eggs","Body","muted")
		text(entry,"ColorHint","","Supporting","muted")
		text(entry,"Track","Track & play","Supporting",Art.Leaf).Visible=false
		self.cards[index]=entry
	end
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:layout()end)
	Art.watchTextPreference(shade,function()return shade.Visible end,function()self:layout()end)
	self:layout();return self
end
function Journal:setColors(callback)
 self.onColors=callback
 if not self.colorsButton then self.colorsButton=button(self.card,"Colors","Body & accents",function()
  if not self.shade.Visible or not self.colorsButton.Interactable then return end
  local id=self.companionId;self:close("colors");if self.onColors then self.onColors(id)end
 end)end
 self.colorsButton.Visible=self.hasColorPets==true;self:layout()
end
function Journal:layout()
	if self.layingOut then return end;self.layingOut=true
	local size=self.shade.AbsoluteSize;local short=size.Y<220
	local width=math.max(1,math.min(680,size.X-24));local pad=if short then 8 else 16
	local usable=width-pad*2;local bodyW=usable-8
	self.title.Text=if self.saveNotice then self.saveNotice.short else self.baseTitle
	Art.type(self.title,if short or self.saveNotice then "Body"else "Heading",short)
	local titleH=Art.textHeight(self.title,usable-56,28);local header=math.max(44,titleH)+8
    local footerH=0;local footerButtons={}
    if self.goalsButton then table.insert(footerButtons,self.goalsButton)end
    if self.colorsButton and self.colorsButton.Visible then table.insert(footerButtons,self.colorsButton)end
    local footerColumns=if #footerButtons==2 and usable>=240 then 2 else 1
    local footerWidth=(usable-(footerColumns-1)*8)/footerColumns;local footerRow=44
    for _,n in ipairs(footerButtons)do Art.type(n,if short then "Body"else "Action",short);footerRow=math.max(footerRow,Art.actionHeight(n,footerWidth))end
    if #footerButtons>0 then footerH=math.ceil(#footerButtons/footerColumns)*(footerRow+8)-8 end
	local minColumn=240
	for index,entry in ipairs(self.cards)do
		Art.type(entry.Species,"Action",short);Art.type(entry.Status,"Body",short);Art.type(entry.ColorHint,"Supporting",short);Art.type(entry.Track,"Supporting",short)
		if not Pets.collection[index].trial then
			minColumn=math.max(minColumn,Art.textWidth(entry.Species)+96,Art.textWidth(entry.ColorHint)+96)
		end
	end
	local columns=if (bodyW-8)/2>=minColumn then 2 else 1
	self.columns=columns
	local y=4;local index=1
	self.saveDetail.Visible=self.saveNotice~=nil
	if self.saveNotice then
		Art.type(self.saveDetail,"Body",short);self.saveDetail.Text=self.saveNotice.detail
		local h=Art.textHeight(self.saveDetail,bodyW-8,24);place(self.saveDetail,4,y,bodyW-8,h);y+=h+12
	end
	while index<=#self.cards do
		local group=if columns==2 and not Pets.collection[index].trial then math.min(2,#Pets-index+1)else 1
		local rowW=if group==2 then (bodyW-12)/2 else bodyW-8
		local rowH=76
		for slot=index,index+group-1 do
			local entry=self.cards[slot];local textW=math.max(1,rowW-96)
			local nameH=Art.textHeight(entry.Species,textW,24);local statusH=Art.textHeight(entry.Status,textW,22)
			local rankH=if entry.ColorHint.Visible then Art.textHeight(entry.ColorHint,textW,20)else 0
			local trackH=if entry.Track.Visible then Art.textHeight(entry.Track,textW,20)else 0
			entry:SetAttribute("NameHeight",nameH);entry:SetAttribute("StatusHeight",statusH)
			entry:SetAttribute("RankHeight",rankH);entry:SetAttribute("TrackHeight",trackH)
			rowH=math.max(rowH,16+nameH+4+statusH+(if rankH>0 then rankH+4 else 0)+(if trackH>0 then trackH+4 else 0))
		end
		for slot=index,index+group-1 do
			local entry=self.cards[slot];local x=4+(slot-index)*(rowW+8);local textW=math.max(1,rowW-96)
			place(entry,x,y,rowW,rowH);place(entry.PortraitWell,8,8,60,60)
			local sy=8;place(entry.Species,80,sy,textW,entry:GetAttribute("NameHeight"));sy+=entry:GetAttribute("NameHeight")+4
			place(entry.Status,80,sy,textW,entry:GetAttribute("StatusHeight"));sy+=entry:GetAttribute("StatusHeight")+4
			local rankH=entry:GetAttribute("RankHeight");place(entry.ColorHint,80,sy,textW,rankH);sy+=if rankH>0 then rankH+4 else 0
			place(entry.Track,80,sy,textW,entry:GetAttribute("TrackHeight"))
		end
		y+=rowH+8;index+=group
	end
	local footer=if #footerButtons>0 then footerH+8 else 0
	local maximum=math.max(1,math.min(680,size.Y-(if short then 8 else 24)))
	local height=math.min(maximum,header+y+footer+8)
	self.card.Size=UDim2.fromOffset(width,height)
	place(self.title,pad,4,usable-56,titleH);place(self.closeButton,width-pad-44,4,44,44)
	place(self.scroll,pad,header,usable,math.max(44,height-header-footer-4))
	for i,n in ipairs(footerButtons)do place(n,pad+((i-1)%footerColumns)*(footerWidth+8),height-footerH-4+math.floor((i-1)/footerColumns)*(footerRow+8),footerWidth,footerRow)end
	self.scroll.CanvasSize=UDim2.fromOffset(0,y)
	place(self.moreCue,width-pad-12,header+self.scroll.Size.Y.Offset-20,12,20)
	self.scroll.CanvasPosition=Vector2.new(0,math.clamp(self.scroll.CanvasPosition.Y,0,math.max(0,y-self.scroll.Size.Y.Offset)))
	self:refreshScrollCue();self.layingOut=false
	local selected=GuiService.SelectedObject
	if selected and selected.Parent==self.scroll and self.shade.Visible then self:ensureVisible(selected)end
end
function Journal:setSaveNotice(notice)
	if SaveNotice.key(self.saveNotice)==SaveNotice.key(notice)then return false end
	self.saveNotice=notice;self:layout();return true
end
function Journal:refreshScrollCue()
	local height=self.scroll.AbsoluteSize.Y
	local overflow=self.scroll.CanvasSize.Y.Offset>height+1
	self.scroll.ScrollingEnabled=overflow;self.scroll.ScrollBarImageTransparency=if overflow then 0 else 1
	self.moreCue.Visible=overflow and self.scroll.CanvasPosition.Y+height<self.scroll.CanvasSize.Y.Offset-1
end
function Journal:ensureVisible(entry)
	local height=self.scroll.Size.Y.Offset;local top=entry.Position.Y.Offset;local current=self.scroll.CanvasPosition.Y
	local wanted=if entry.Size.Y.Offset>height or top<current then top elseif top+entry.Size.Y.Offset>current+height then top+entry.Size.Y.Offset-height else current
	self.scroll.CanvasPosition=Vector2.new(0,math.clamp(wanted,0,math.max(0,self.scroll.CanvasSize.Y.Offset-height)))
end
function Journal:activatePet(index)
	local entry=self.cards[index];if not self.shade.Visible or not entry or not entry.Interactable then return false end
	local pet=Pets.collection[index];local tracking=entry.Track.Visible
	if self.onAccepted then self.onAccepted("confirm")end;self:close();if tracking then self.onTrack(pet)else self.onVisit(pet)end;return true
end
function Journal:bumpControllerEpoch()
	self.shade:SetAttribute("ControllerEpoch",(self.shade:GetAttribute("ControllerEpoch")or 0)+1)
end
function Journal:getControllerTarget()
	local track
	for _,entry in ipairs(self.cards)do
		if entry.Selectable and entry.Interactable then
			if entry:GetAttribute("ControllerOwned")then return entry end
			if entry.Track.Visible and not track then track=entry end
		end
	end
	return track or self.closeButton
end
function Journal:getControllerFocus()
	if not self.shade.Visible then return nil end
	return{root=self.shade,epoch=self.shade:GetAttribute("ControllerEpoch")or 0,
		target=function()return self:getControllerTarget()end,fallback=self.closeButton,
		ensure=function(target)if target.Parent==self.scroll then self:ensureVisible(target)end end}
end
function Journal:open(owned,trials,companionId,selected,tracked,inventoryMask,masteryRanks)
    self.companionId=companionId
    self.hasColorPets=inventoryMask~=nil and (bit32.band(inventoryMask,3)~=0)
    if self.colorsButton then self.colorsButton.Visible=self.hasColorPets;self.colorsButton.Interactable=self.hasColorPets end
	self:bumpControllerEpoch()
	self.baseTitle=string.format("Pet journal · %02d/%02d",Pets.ownedCount(owned,trials,inventoryMask),#Pets.collection)
	local firstOwned,firstTrack
	for index,entry in ipairs(self.cards)do
		local pet=Pets.collection[index];local unlocked=Pets.isUnlocked(pet,owned,trials,inventoryMask)
		local equipped=unlocked and pet.id==companionId
		local trackable=inventoryMask==nil and pet.trial~=nil and not unlocked
		entry.Status.Text=if unlocked then (if equipped then "Equipped"else "Equip")elseif inventoryMask~=nil then "Hatch from eggs"elseif pet.trial then pet.trial.hint else pet.charge.." charge to hatch"
        entry.ColorHint.Text=if unlocked and(pet.id=="pip"or pet.id=="puddle")then "Body & accents in Colors"else ""
        entry.ColorHint.Visible=entry.ColorHint.Text~=""
		entry.Track.Visible=trackable;entry.Track.Text=if tracked==pet then "Tracked · Play"else "Track & play"
		Art.bind(entry.Status,{TextColor3=function()return if equipped then Art.Leaf else Art.paletteColor("muted") end})
		Art.bind(entry.Species,{TextColor3=function()return if pet.trial then Art.Amber elseif unlocked then Art.paletteColor("text") else Art.paletteColor("muted") end})
		if not self.portraits[index]or self.portraits[index].unlocked~=unlocked then
			if self.portraits[index]then self.portraits[index].sprite:Destroy()end
			self.portraits[index]={unlocked=unlocked,sprite=Portrait.create(entry.PortraitWell,pet,4,UDim2.fromScale(.5,.5),entry.ZIndex+3,not unlocked,self.appearanceFor and self.appearanceFor(pet.id))}
		end
        if self.appearanceFor and self.portraits[index]then Portrait.apply(self.portraits[index].sprite,self.appearanceFor(pet.id))end
		entry.Interactable,entry.Selectable=unlocked or trackable,unlocked or trackable
		entry:SetAttribute("ControllerOwned",unlocked)
		if unlocked and not firstOwned then firstOwned=entry elseif trackable and not firstTrack then firstTrack=entry end
	end
	self.previousSelection=GuiService.SelectedObject;self.shade.Visible=true;self.scroll.CanvasPosition=Vector2.zero;self:layout()
	self.openGeneration=(self.openGeneration or 0)+1;local generation=self.openGeneration
	if selected then
		local focus=firstOwned or firstTrack or self.closeButton;GuiService.SelectedObject=focus
		if focus.Parent==self.scroll then self:ensureVisible(focus)end
		task.defer(function()
			game:GetService("RunService").Heartbeat:Wait()
			if self.shade.Parent and self.shade.Visible and self.openGeneration==generation and GuiService.SelectedObject==focus and focus.Parent==self.scroll then self:ensureVisible(focus)end
		end)
	end
end
function Journal:close(reason)
	if self.shade.Visible then self:bumpControllerEpoch()end
	if not self.shade.Visible then return end
	if reason=="back"and self.onAccepted then self.onAccepted("back")end
	self.shade.Visible=false;self.openGeneration=(self.openGeneration or 0)+1
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then
		GuiService.SelectedObject=visibleSelection(self.previousSelection)
	end
end
return Journal
