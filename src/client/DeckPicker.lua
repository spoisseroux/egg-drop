local Shared=game:GetService("ReplicatedStorage").Shared
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Palette=require(Shared.DeckPalette)
local Themes=require(Shared.DeckThemes)
local Stickers=require(Shared.DeckStickers)
local Trials=require(Shared.PocketTrials)
local Art=require(script.Parent.DeckArt)
local SaveNotice=require(script.Parent.SaveNotice)
local Picker={};Picker.__index=Picker
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
local function text(parent,name,value,role)
	local node=Art.text(parent,name,value,UDim2.fromOffset(0,0),UDim2.fromOffset(100,24),Art.Silver,16)
	Art.type(node,role);node.TextXAlignment=Enum.TextXAlignment.Left;return node
end
local function button(parent,name,value,action)
	local node=Instance.new("TextButton");node.Name,node.Text,node.Parent=name,value,parent
	node.BackgroundColor3,node.TextColor3,node.BorderSizePixel,node.ZIndex=Art.Raised,Art.Silver,0,parent.ZIndex+1
	Art.button(node,10);Art.type(node,"Action");node.Activated:Connect(action);return node
end
local function panel(parent,name,color)
	local node=Art.frame(parent,name,color,UDim2.fromOffset(0,0),UDim2.fromOffset(100,44),parent.ZIndex+1)
	Art.corner(node,8);return node
end
function Picker.new(gui,make,label,onPreview,onClose,onApply,onSetting)
	local shade=Art.frame(gui,"DeckPicker",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),20)
	shade.BackgroundTransparency,shade.Active,shade.Visible=1,true,false
	local card=panel(shade,"Card",Art.Surface);card.AnchorPoint=Vector2.new(.5,0);card.Position=UDim2.fromScale(.5,.5);Art.panel(card,16)
	local scroll=Instance.new("ScrollingFrame");scroll.Name,scroll.Parent="Scroll",card
	scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ZIndex=1,0,card.ZIndex+1
	scroll.ScrollingDirection,scroll.ElasticBehavior=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never
	scroll.ScrollBarThickness,scroll.ScrollBarImageColor3=4,Art.Leaf
	local self=setmetatable({shade=shade,card=card,scroll=scroll,tabs={},choices={Shell={},Sticker={}},rows={},
		onPreview=onPreview,onClose=onClose,onApply=onApply,onSetting=onSetting,active="Shell"},Picker)
	self.heading=text(card,"Heading","Deck style","Heading")
	self.saveMarker=text(card,"SaveStatus","","Supporting");self.saveMarker.TextColor3=Art.Amber;self.saveMarker.TextYAlignment=Enum.TextYAlignment.Top;self.saveMarker.Visible=false
	self.saveDetail=text(scroll,"SaveInstruction","","Body");self.saveDetail.TextColor3=Art.Amber;self.saveDetail.Visible=false
	self.moreCue=Art.frame(card,"MoreBelow",Art.Surface,UDim2.fromOffset(0,0),UDim2.fromOffset(12,20),40)
	self.moreCue.BackgroundTransparency=1;self.moreCue.Active=false;self.moreCue.Selectable=false
	for _,entry in ipairs({{1,45},{5,-45}})do
		local bar=Art.frame(self.moreCue,"Chevron",Art.Leaf,UDim2.fromOffset(entry[1],8),UDim2.fromOffset(7,2),41);bar.Rotation=entry[2]
	end
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()self:refreshScrollCue()end)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:refreshScrollCue()end)
	self.cancel=Art.close(button(card,"Close","×",function()self:close()end));self.closeButton=self.cancel
	self.apply=button(card,"Apply","Equip",function()self:applyPreview()end);self.apply.BackgroundColor3,self.apply.TextColor3=Art.Leaf,Art.Ink
	for _,tab in ipairs({"Shell","Sticker","Club"})do
		self.tabs[tab]=button(card,tab.."Tab",tab,function()self:showTab(tab)end)
	end
	self.display=panel(scroll,"Display",Art.Inset)
	self.previewName=text(self.display,"PreviewName","Scout","Action")
	self.previewNote=text(self.display,"PreviewNote","Preview · Equip to save","Supporting");self.previewNote.TextColor3=Art.Muted
	self.shell=panel(self.display,"Preview",Palette.Shell);place(self.shell,12,12,102,68)
	self.face=panel(self.shell,"Face",Palette.Shell);place(self.face,4,4,94,60)
	self.bezel=panel(self.face,"Bezel",Palette.Rim);place(self.bezel,25,4,44,52)
	local screen=panel(self.bezel,"Screen",Palette.Tray);place(screen,4,3,36,46)
	local small=panel(screen,"SmallEgg",Palette.JellyBlue);place(small,6,31,8,8)
	local big=panel(screen,"BigEgg",Palette.Ember);place(big,17,26,13,13)
	local rocker=panel(self.face,"AimRocker",Palette.Ink);place(rocker,5,24,16,7)
	self.buttonA=panel(self.face,"A",Palette.Primary);place(self.buttonA,76,23,13,13)
	self.sticker=Art.text(self.face,"Sticker","",UDim2.fromOffset(75,40),UDim2.fromOffset(14,14),Art.Amber,12);self.sticker.Rotation=-11
	-- These are graphic marks inside miniature hardware, not readable UI words.
	Art.fitText(self.sticker,12,10,0,false)
	local stickerInset=self.sticker:FindFirstChildOfClass("UIPadding");stickerInset.PaddingTop,stickerInset.PaddingBottom=UDim.new(0,0),UDim.new(0,0)
	for _,tab in ipairs({"Shell","Sticker"})do
		local catalog=if tab=="Shell"then Themes else Stickers
		for _,id in ipairs(catalog.Order)do
			local option=catalog.ById[id]
			local swatch=button(scroll,id,"",function()self:activateChoice(tab,id)end)
			local chip=panel(swatch,"Chip",if tab=="Shell"then option.shell else Art.Inset)
			if tab=="Shell"then
				local face=panel(chip,"Face",option.face or option.shell);place(face,3,3,36,24)
				local accent=panel(face,"Accent",option.buttons);place(accent,25,6,8,8)
			else
				chip.BackgroundTransparency=1
				local mark=Art.text(chip,"Mark",option.mark or "–",UDim2.fromScale(0,0),UDim2.fromScale(1,1),option.color or Art.Muted,24)
				mark.Font=Enum.Font.GothamBold;Art.fitText(mark,24,18,0,false)
				local inset=mark:FindFirstChildOfClass("UIPadding");inset.PaddingTop,inset.PaddingBottom=UDim.new(0,0),UDim.new(0,0)
			end
			text(swatch,"Caption",option.name,"Body")
			local stroke=Instance.new("UIStroke");stroke.Name,stroke.Color,stroke.Thickness,stroke.Enabled,stroke.Parent="Selection",Art.Amber,2,false,swatch
			self.choices[tab][id]=stroke
		end
	end
	self.clubHeader=text(scroll,"TrialHeading","Pocket trials","Heading")
	for index,goal in ipairs(Trials.Goals)do
		local row=panel(scroll,"Trial"..goal.bit,Art.Raised)
		local title=text(row,"Goal",goal.hint,"Body")
		local status=text(row,"Progress","","Supporting");status.TextColor3=Art.Muted
		local track=panel(row,"Track",Art.Ink);local fill=panel(track,"Fill",Art.Leaf)
		self.rows[index]={frame=row,title=title,status=status,fill=fill}
	end
	self.reward=text(scroll,"Reward","Finish all three to earn the Club sticker","Supporting");self.reward.TextColor3=Art.Muted
	self.sound=button(scroll,"SoundSetting","SFX: On",function()self:changeSetting("sound")end)
	self.motion=button(scroll,"MotionSetting","Motion: Full",function()self:changeSetting("motion")end)
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:layout()end)
	Art.watchTextPreference(shade,function()return shade.Visible end,function()self.safeTop=nil;self:layout()end)
	self:showTab("Shell");return self
end
function Picker:layout()
	if self.layingOut then return end;self.layingOut=true
	local size=self.shade.AbsoluteSize;local short=size.Y<220
	local width=math.max(1,math.min(620,size.X-24));local pad=if short then 8 else 16
	local usable=width-pad*2
	Art.type(self.saveMarker,"Supporting",short)
	local markerW=0
	if short and self.saveNotice then
		local limit=usable*.42
		self.saveMarker.Text=SaveNotice.caption(self.saveNotice,function(value)return Art.textWidth(self.saveMarker,value)+16<=limit end)
		markerW=math.min(limit,Art.textWidth(self.saveMarker)+16)
	end
	local scrollW=usable-(if markerW>0 then markerW+12 else 0);local bodyW=scrollW-8
	self.heading.Text=if self.saveNotice then self.saveNotice.short else "Deck style"
	Art.type(self.heading,if self.saveNotice then "Body"else "Heading",false)
	self.heading.Visible=not short
	local headingH=Art.textHeight(self.heading,usable-56,32)
	local tabsY=if short then 4 else math.max(44,headingH)+12
	local tabW=if short then (usable-64)/3 else (usable-12)/3
	local tabH=44
	for _,tab in pairs(self.tabs)do
		Art.type(tab,if short then "Body" else "Action",short)
		tabH=math.max(tabH,Art.textHeight(tab,tabW,0)+(if short then 8 else 12))
	end
	local header=tabsY+tabH+4
	Art.type(self.apply,if short then "Body"else "Action",short)
	local footerH=math.max(44,Art.textHeight(self.apply,usable,0)+(if short then 8 else 12))
	local footer=if self.active=="Club"then 0 else footerH+8
	local maximum=math.max(1,size.Y-(if short then 8 else 24))
	local bodyBudget=math.max(44,maximum-header-footerH-12)
	local function layoutBody(active)
	local y=4
	if self.saveNotice then
		Art.type(self.saveDetail,"Body",short);self.saveDetail.Text=self.saveNotice.detail
		local h=Art.textHeight(self.saveDetail,bodyW-8,24)
		place(self.saveDetail,4,y,bodyW-8,h);y+=h+12
	end
	if active~="Club"then
		Art.type(self.previewName,"Action",short);Art.type(self.previewNote,"Supporting",short)

		local catalog=if active=="Shell"then Themes else Stickers
		local minW=150
		for _,id in ipairs(catalog.Order)do local caption=self.choices[active][id].Parent.Caption;Art.type(caption,"Body",short);minW=math.max(minW,Art.textWidth(caption)+76)end
		local columns=math.max(1,math.min(3,math.floor((bodyW+8)/(minW+8))))
		local swatchW=(bodyW-8-(columns-1)*8)/columns;local rowH=44
		local labelPad=if short then 4 else 8
		for _,id in ipairs(catalog.Order)do rowH=math.max(rowH,Art.textHeight(self.choices[active][id].Parent.Caption,swatchW-68,0)+labelPad*2)end
		local nameW=math.max(1,bodyW-148)
		local nameH=Art.textHeight(self.previewName,nameW,24)
		local noteH=Art.textHeight(self.previewNote,nameW,22)
		local fullHeight=math.max(92,nameH+noteH+28)
		local compactNameW=math.max(1,bodyW-96)
		local compactNameH=Art.textHeight(self.previewName,compactNameW,24)
		local compactHeight=math.max(48,compactNameH+8)
		local mode,displayH,gap="hidden",0,0
		y=if self.saveNotice then y else (if bodyBudget>=rowH+8 then 4 else 0)
		if not self.saveNotice and y+fullHeight+12+rowH+4<=bodyBudget then mode,displayH,gap="full",fullHeight,12
		elseif not self.saveNotice and y+compactHeight+8+rowH+4<=bodyBudget then mode,displayH,gap="compact",compactHeight,8 end
		if active==self.active then
			self.previewMode=mode;self.display.Visible=mode~="hidden";self.previewNote.Visible=mode=="full"
			local scale=self.shell:FindFirstChild("PreviewScale")
			if not scale then scale=Instance.new("UIScale");scale.Name,scale.Parent="PreviewScale",self.shell end
			scale.Scale=if mode=="compact"then .5 else 1
			self.shell.Position=if mode=="compact"then UDim2.fromOffset(10,(displayH-34)/2)else UDim2.fromOffset(12,12)
			place(self.display,4,y,bodyW-8,displayH)
			if mode=="compact"then place(self.previewName,78,4,compactNameW,compactNameH)
			else place(self.previewName,130,12,nameW,nameH);place(self.previewNote,130,16+nameH,nameW,noteH)end
		end
		y+=displayH+gap

		for index,id in ipairs(catalog.Order)do
			local swatch=self.choices[active][id].Parent
			place(swatch,4+(index-1)%columns*(swatchW+8),y+math.floor((index-1)/columns)*(rowH+8),swatchW,rowH)
			place(swatch.Chip,10,(rowH-30)/2,42,30);place(swatch.Caption,60,labelPad,swatchW-68,rowH-labelPad*2)
		end
		y+=math.ceil(#catalog.Order/columns)*(rowH+8)
	else
		Art.type(self.clubHeader,"Heading",short);local h=Art.textHeight(self.clubHeader,bodyW-8,28)
		place(self.clubHeader,4,y,bodyW-8,h);y+=h+12
		for _,row in ipairs(self.rows)do
			Art.type(row.title,"Body",short);Art.type(row.status,"Supporting",short)
			local th=Art.textHeight(row.title,bodyW-32,24);local sh=Art.textHeight(row.status,bodyW-32,22)
			local h=th+sh+30;place(row.frame,4,y,bodyW-8,h)
			place(row.title,12,8,bodyW-32,th);place(row.status,12,12+th,bodyW-32,sh)
			place(row.fill.Parent,12,h-10,bodyW-32,4);row.fill.Size=UDim2.fromScale(row.fill:GetAttribute("Progress") or 0,1)
			y+=h+8
		end
		Art.type(self.reward,"Supporting",short);local h=Art.textHeight(self.reward,bodyW-8,24)
		place(self.reward,4,y,bodyW-8,h);y+=h+12
		for _,control in ipairs({self.sound,self.motion})do
			Art.type(control,"Action",short);local h=Art.actionHeight(control,bodyW-8)
			place(control,4,y,bodyW-8,h);y+=h+8
		end
	end
	return y
	end
	local heights={Shell=layoutBody("Shell"),Sticker=layoutBody("Sticker"),Club=layoutBody("Club")}
	local y=heights[self.active]

	if self.safeTop==nil or self.layoutRootSize~=size then
		local tallest=header+math.max(heights.Shell+footerH+8,heights.Sticker+footerH+8,heights.Club)+8
		self.safeTop=math.max(0,(size.Y-math.min(maximum,tallest))/2);self.layoutRootSize=size
	end
	local height=math.min(maximum,math.max(1,size.Y-self.safeTop-4),header+y+footer+8)
	self.card.Position,self.card.Size=UDim2.new(.5,0,0,self.safeTop),UDim2.fromOffset(width,height)
	place(self.heading,pad,4,usable-56,headingH);place(self.cancel,width-pad-44,4,44,44)
	for index,tab in ipairs({"Shell","Sticker","Club"})do place(self.tabs[tab],pad+(index-1)*(tabW+6),tabsY,tabW,tabH)end
	self.saveMarker.Visible=markerW>0;self.saveDetail.Visible=self.saveNotice~=nil
	place(self.saveMarker,pad,header,markerW,math.max(44,height-header-footer-4))
	place(self.scroll,pad+(if markerW>0 then markerW+12 else 0),header,scrollW,math.max(44,height-header-footer-4))
	place(self.apply,pad,height-footerH-4,usable,footerH)
	self.scroll.CanvasSize=UDim2.fromOffset(0,y)
	place(self.moreCue,width-pad-12,header+self.scroll.Size.Y.Offset-20,12,20)
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
function Picker:showTab(active)
	if not self.tabs[active]then return end
	self.active=active;local club=active=="Club"
	self.display.Visible,self.apply.Visible=not club,not club
	self.clubHeader.Visible,self.reward.Visible,self.sound.Visible,self.motion.Visible=club,club,club,club
	for _,row in ipairs(self.rows)do row.frame.Visible=club end
	for tab,control in pairs(self.tabs)do control.BackgroundColor3=if tab==active then Art.Inset else Art.Raised;control.TextColor3=if tab==active then Art.Leaf else Art.Silver end
	for tab,choices in pairs(self.choices)do for _,stroke in pairs(choices)do stroke.Parent.Visible=tab==active end end
	self.scroll.CanvasPosition=Vector2.zero;self:layout()
end
function Picker:activateChoice(tab,id)
	local stroke=self.choices[tab]and self.choices[tab][id]
	if not self.shade.Visible or self.active~=tab or not stroke or not stroke.Parent.Interactable then return false end
	self:select(if tab=="Shell"then id else self.themeId,if tab=="Sticker"then id else self.stickerId);return true
end
function Picker:applyPreview()
	if not self.shade.Visible or self.active=="Club"then return false end
	local themeId,stickerId=self.themeId,self.stickerId
	self:close();self.onApply(themeId,stickerId);return true
end
function Picker:changeSetting(key)
	local control=if key=="sound"then self.sound elseif key=="motion"then self.motion else nil
	if not self.shade.Visible or self.active~="Club"or not control or not control.Interactable then return false end
	self.onSetting(key);return true
end
function Picker:select(themeId,stickerId)
	local theme=Themes.ById[themeId];if not theme or not Stickers.ById[stickerId]then return false end
	self.themeId,self.stickerId=themeId,stickerId;self.previewName.Text=theme.name
	self.shell.BackgroundColor3,self.face.BackgroundColor3=theme.shell,theme.face or theme.shell
	self.face.AimRocker.BackgroundColor3=theme.rocker or Palette.Ink
	self.bezel.BackgroundColor3,self.buttonA.BackgroundColor3=theme.trim,theme.buttons
	Stickers.paint(self.sticker,stickerId)
	for id,stroke in pairs(self.choices.Shell)do stroke.Enabled=id==themeId end
	for id,stroke in pairs(self.choices.Sticker)do stroke.Enabled=id==stickerId end
	self.onPreview(themeId,stickerId);self:layout();return true
end
function Picker:updateClub(owned,mask,peak,score,sound,reduced,systemReduced,inventoryMask)
	self.sound.Text="SFX: "..sound
	self.motion.Text=if systemReduced then "Motion: Roblox"elseif reduced then "Motion: Low"else "Motion: Full"
	self.motion.Interactable,self.motion.Selectable=not systemReduced,not systemReduced
	local count=0
	for index,goal in ipairs(Trials.Goals)do
		local done=bit32.band(mask,goal.bit)~=0;local current=if index==1 then peak elseif index==2 then score else 0
		local row=self.rows[index]
		row.title.Text=if goal==Trials.HighRoller then (if done then "High score trial complete"else "High score · Score "..goal.target)elseif done then goal.name else goal.hint
		row.status.Text=if done then "✓ Complete"elseif index==3 then "0/1"else string.format("%d/%d",current,goal.target)
		row.status.TextColor3=if done then Art.Leaf else Art.Muted
		row.fill:SetAttribute("Progress",if done then 1 else math.min(1,current/goal.target));row.fill.BackgroundColor3=if done then Art.Amber else Art.Leaf
		count+=if done then 1 else 0
	end
	self.clubHeader.Text=string.format("Pocket trials · %d/%d",count,#Trials.Goals)
	self.reward.Text=if Trials.clubComplete(mask)then "Club sticker ready in the Sticker tab"else "Finish all three to earn the Club sticker"
	for id,stroke in pairs(self.choices.Sticker)do
		local available=Stickers.canEquip(id,owned,mask,inventoryMask);local swatch=stroke.Parent;local option=Stickers.ById[id]
		swatch.Interactable,swatch.Selectable=available,available
		swatch.Caption.Text=if available then option.name elseif option.trials then "Club trials"else "Hatch "..option.name
		swatch.Caption.TextColor3=if available then Art.Silver else Art.Muted
		if swatch.Chip:FindFirstChild("Mark")then swatch.Chip.Mark.TextColor3=if available then option.color or Art.Muted else Art.Muted end
	end
	local signature={self.sound.Text,self.motion.Text,self.clubHeader.Text,self.reward.Text}
	for _,row in ipairs(self.rows)do table.insert(signature,row.title.Text..row.status.Text)end
	for _,id in ipairs(Stickers.Order)do table.insert(signature,self.choices.Sticker[id].Parent.Caption.Text)end
	local key=table.concat(signature,"|")
	if self.shade.Visible and self.clubLayoutKey~=key then self:layout()end
	self.clubLayoutKey=key
end
function Picker:open(themeId,stickerId)
	self.previousSelection=GuiService.SelectedObject;self.safeTop=nil;self.shade.Visible=true;self:showTab("Shell");self:select(themeId,stickerId)
	if string.match(UserInputService:GetLastInputType().Name,"^Gamepad")then GuiService.SelectedObject=self.tabs.Shell end
end
function Picker:close()
	if not self.shade.Visible then return end
	self.shade.Visible=false;self.onClose()
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then
		GuiService.SelectedObject=visibleSelection(self.previousSelection)
	end
end
return Picker
