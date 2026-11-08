local Shared=game:GetService("ReplicatedStorage").Shared
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Palette=require(Shared.DeckPalette)
local Themes=require(Shared.DeckThemes)
local Stickers=require(Shared.DeckStickers)
local Backgrounds=require(Shared.DeckBackgrounds)
local AppearanceCatalog=require(Shared.AppearanceCatalog)
local catalogs={Shell=Themes,Sticker=Stickers,Background=Backgrounds}
local slots={Shell="theme",Sticker="sticker",Background="background"}
local Trials=require(Shared.PocketTrials)
local Art=require(script.Parent.DeckArt)
local SaveNotice=require(script.Parent.SaveNotice)
local Picker={};Picker.__index=Picker
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
local function panel(parent,name,color)
	local node=Art.frame(parent,name,color,UDim2.fromOffset(0,0),UDim2.fromOffset(100,44),parent.ZIndex+1)
	Art.corner(node,8);return node
end
function Picker.new(gui,make,label,onPreview,onClose,onApply,onSetting)
	local shade=Art.frame(gui,"DeckPicker","ink",UDim2.fromScale(0,0),UDim2.fromScale(1,1),20)
	shade.BackgroundTransparency,shade.Active,shade.Visible=1,true,false
	local card=panel(shade,"Card","panel");card.AnchorPoint=Vector2.new(.5,0);card.Position=UDim2.fromScale(.5,.5);Art.panel(card,16)
	local scroll=Instance.new("ScrollingFrame");scroll.Name,scroll.Parent="Scroll",card
	scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ZIndex=1,0,card.ZIndex+1
	scroll.ScrollingDirection,scroll.ElasticBehavior=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never
	scroll.ScrollBarThickness,scroll.ScrollBarImageColor3=4,Art.Leaf
	local self=setmetatable({shade=shade,card=card,scroll=scroll,tabs={},choices={Shell={},Sticker={},Background={}},rows={},
		onPreview=onPreview,onClose=onClose,onApply=onApply,available={},confirmed={},onSetting=onSetting,active="Shell"},Picker)
	self.heading=text(card,"Heading","Deck style","Heading")
	self.saveMarker=text(card,"SaveStatus","","Supporting");Art.bind(self.saveMarker,{TextColor3=function()return Art.Amber end});self.saveMarker.TextYAlignment=Enum.TextYAlignment.Top;self.saveMarker.Visible=false
	self.saveDetail=text(scroll,"SaveInstruction","","Body");Art.bind(self.saveDetail,{TextColor3=function()return Art.Amber end});self.saveDetail.Visible=false
	self.moreCue=Art.frame(card,"MoreBelow","panel",UDim2.fromOffset(0,0),UDim2.fromOffset(12,20),40)
	self.moreCue.BackgroundTransparency=1;self.moreCue.Active=false;self.moreCue.Selectable=false
	for _,entry in ipairs({{1,45},{5,-45}})do
		local bar=Art.frame(self.moreCue,"Chevron",Art.Leaf,UDim2.fromOffset(entry[1],8),UDim2.fromOffset(7,2),41);bar.Rotation=entry[2]
	end
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()self:refreshScrollCue();self:refreshBackgroundPreview()end)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:refreshScrollCue();self:refreshBackgroundPreview()end)
	self.cancel=Art.bareClose(button(card,"Close","×",function()self:back()end));self.closeButton=self.cancel;self.cancel.ZIndex=60
	self.appearanceStatus=text(scroll,"AppearanceStatus","Select to wear immediately.","Supporting")
 self.retryButton=button(scroll,"RetryAppearance","Retry",function()if self.onRetry then self.onRetry(slots[self.active]or "theme")end end)
 self.trialsLink=button(scroll,"ViewTrials","View Pocket Trials",function()self.innerReturn={active=self.active,scroll=self.scroll.CanvasPosition,focus=GuiService.SelectedObject};self:showTab("Trials")end)
 for _,tab in ipairs({"Shell","Sticker","Background"})do self.tabs[tab]=button(card,tab.."Tab",if tab=="Sticker"then "Stickers"elseif tab=="Background"then "Background"else tab,function()self:showTab(tab)end)end

	self.display=panel(scroll,"Display","inset")
	self.previewName=text(self.display,"PreviewName","Scout","Action")
	self.previewName.ZIndex=40
	self.previewNote=text(self.display,"PreviewNote","Selection applies immediately","Supporting");Art.bind(self.previewNote,{TextColor3="muted"});self.previewNote.ZIndex=40
	self.shell=panel(self.display,"Preview",Palette.Shell);place(self.shell,12,12,102,68)
	self.face=panel(self.shell,"Face",Palette.Shell);place(self.face,4,4,94,60)
	self.bezel=panel(self.face,"Bezel",Palette.Rim);place(self.bezel,25,4,44,52)
	local screen=panel(self.bezel,"Screen",Palette.Tray);self.screen=screen;place(screen,4,3,36,46)
	local small=panel(screen,"SmallEgg",Palette.JellyBlue);place(small,6,31,8,8)
	local big=panel(screen,"BigEgg",Palette.Ember);place(big,17,26,13,13)
	local rocker=panel(self.face,"AimRocker",Palette.Ink);place(rocker,5,24,16,7)
	self.buttonA=panel(self.face,"A",Palette.Primary);place(self.buttonA,76,23,13,13)
	self.sticker=Art.frame(self.face,"Sticker",Art.Amber,UDim2.fromOffset(70,37),UDim2.fromOffset(23,23),self.face.ZIndex+1);self.sticker.BackgroundTransparency=1
	self.backgroundPreview=Art.frame(self.display,"BackgroundPreview","inset",UDim2.fromOffset(12,12),UDim2.fromOffset(102,68),self.display.ZIndex+1);self.backgroundPreview.ClipsDescendants=true;self.backgroundPreview.Visible=false
	for _,tab in ipairs({"Shell","Sticker","Background"})do
		local catalog=catalogs[tab]
		for _,id in ipairs(catalog.Order)do
			local option=catalog.ById[id]
			local swatch=button(scroll,id,"",function()self:activateChoice(tab,id)end)
			local chip=panel(swatch,"Chip",if tab=="Shell"then option.shell else "inset")
			if tab=="Shell"then
				local face=panel(chip,"Face",option.face or option.shell);place(face,3,3,36,24)
				local accent=panel(face,"Accent",option.buttons);place(accent,25,6,8,8)
			elseif tab=="Sticker"then
				chip.BackgroundTransparency=1
				Stickers.paint(chip,id)
   else
    Art.backgroundThumbnail(chip,id,Themes.ById[Themes.Default])
			end
			text(swatch,"Caption",option.name,"Body")
			local border=swatch:FindFirstChildOfClass("UIStroke")
   border.ZIndex=0
   swatch.SelectionGained:Connect(function()border.Thickness=4 end)
   swatch.SelectionLost:Connect(function()border.Thickness=1 end)
   local stroke=Instance.new("UIStroke")
   stroke.Name,stroke.ApplyStrokeMode,stroke.ZIndex="Selection",Enum.ApplyStrokeMode.Border,1
   stroke.Color,stroke.Thickness,stroke.Enabled,stroke.Parent=Art.Amber,2,false,swatch
			self.choices[tab][id]=stroke
		end
	end
	self.clubHeader=text(scroll,"TrialHeading","Pocket trials","Heading")
	for index,goal in ipairs(Trials.Goals)do
		local row=panel(scroll,"Trial"..goal.bit,"raised")
		local title=text(row,"Goal",goal.hint,"Body")
		local status=text(row,"Progress","","Supporting");Art.bind(status,{TextColor3="muted"})
		local track=panel(row,"Track","ink");local fill=panel(track,"Fill",Art.Leaf)
		self.rows[index]={frame=row,title=title,status=status,fill=fill}
	end
	self.reward=text(scroll,"Reward","Finish all three to earn the Trial crest","Supporting");Art.bind(self.reward,{TextColor3="muted"})
	self.sound=button(scroll,"SoundSetting","SFX: On",function()self:changeSetting("sound")end)
	self.music=button(scroll,"MusicSetting","Music: On",function()self:changeSetting("music")end)
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
	if short and (self.saveNotice or self.appearanceCaption)then
		local limit=usable*.42
		self.saveMarker.Text=if self.saveNotice then SaveNotice.caption(self.saveNotice,function(value)return Art.textWidth(self.saveMarker,value)+16<=limit end)else self.appearanceCaption
		markerW=math.min(limit,Art.textWidth(self.saveMarker)+16)
	end
	local scrollW=usable-(if markerW>0 then markerW+12 else 0);local bodyW=scrollW-8
	self.heading.Text=if self.saveNotice then self.saveNotice.short elseif self.appearanceCaption and not short and (slots[self.active]~=nil)then "Style · "..self.appearanceCaption elseif self.active=="Trials"then "Pocket Trials"elseif self.active=="Settings"then "Settings"else "Deck style"
	Art.type(self.heading,if self.saveNotice or short then "Body"else "Heading",short)
	self.heading.Visible=not short or self.active=="Trials"or self.active=="Settings"
	local headingH=Art.textHeight(self.heading,usable-56,32)
	local tabsY=if short then 4 else math.max(44,headingH)+12
	local tabW=if short then (usable-56)/3 else (usable-12)/3
	local tabH=44
	for key,tab in pairs(self.tabs)do
		Art.type(tab,if short then "Body" else "Action",short)
		if key=="Background"then tab.Text="Background";tab:SetAttribute("AccessibleLabel","Background patterns");if Art.textWidth(tab)>tabW-12 then tab.Text="Scenes"end end
		tabH=math.max(tabH,Art.textHeight(tab,tabW,0)+(if short then 8 else 12))
	end
	local leaf=self.active=="Trials"or self.active=="Settings"
 local header=if leaf then (if short then math.max(44,headingH)+4 else math.max(44,headingH)+12)else tabsY+tabH+4
 local footerH,footer=0,0
	local maximum=math.max(1,size.Y-(if short then 8 else 24))
	local bodyBudget=math.max(44,maximum-header-4)
	local function layoutBody(active)
	local y=4
	if self.saveNotice then
		Art.type(self.saveDetail,"Body",short);self.saveDetail.Text=self.saveNotice.detail
		local h=Art.textHeight(self.saveDetail,bodyW-8,24)
		place(self.saveDetail,4,y,bodyW-8,h);y+=h+12
	end
	if slots[active]then
		Art.type(self.previewName,"Action",short);Art.type(self.previewNote,"Supporting",short)

		local catalog=catalogs[active]
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
  Art.type(self.appearanceStatus,"Supporting",short);local sh=Art.textHeight(self.appearanceStatus,bodyW-8,24)
  if active==self.active then place(self.appearanceStatus,4,y,bodyW-8,sh)end;y+=sh+8
  for _,control in ipairs({self.retryButton,self.trialsLink})do if control.Visible then local h=Art.actionHeight(control,bodyW-8);if active==self.active then place(control,4,y,bodyW-8,h)end;y+=h+8 end end
	elseif active=="Trials"then
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
	else
		for _,control in ipairs({self.sound,self.music,self.motion})do
			Art.type(control,"Action",short);local h=Art.actionHeight(control,bodyW-8)
			place(control,4,y,bodyW-8,h);y+=h+8
		end
	end
	return y
	end
	local heights={Shell=layoutBody("Shell"),Sticker=layoutBody("Sticker"),Background=layoutBody("Background"),Trials=layoutBody("Trials"),Settings=layoutBody("Settings")}
	local y=heights[self.active]

	if self.safeTop==nil or self.layoutRootSize~=size then
		local tallest=header+math.max(heights.Shell+footerH+8,heights.Sticker+footerH+8,heights.Background+8,heights.Trials,heights.Settings)+8
		self.safeTop=math.max(0,(size.Y-math.min(maximum,tallest))/2);self.layoutRootSize=size
	end
	local height=math.min(maximum,math.max(1,size.Y-self.safeTop-4),header+y+footer+8)
	self.card.Position,self.card.Size=UDim2.new(.5,0,0,self.safeTop),UDim2.fromOffset(width,height)
	place(self.heading,pad,4,usable-56,headingH);place(self.cancel,width-pad-44,4,44,44)
	for index,tab in ipairs({"Shell","Sticker","Background"})do place(self.tabs[tab],pad+(index-1)*(tabW+6),tabsY,tabW,tabH)end
	self.saveMarker.Visible=markerW>0;self.saveDetail.Visible=self.saveNotice~=nil
	place(self.saveMarker,pad,header,markerW,math.max(44,height-header-footer-4))
	place(self.scroll,pad+(if markerW>0 then markerW+12 else 0),header,scrollW,math.max(44,height-header-footer-4))

	self.scroll.CanvasSize=UDim2.fromOffset(0,y)
	place(self.moreCue,width-pad-12,header+self.scroll.Size.Y.Offset-20,12,20)
	self.scroll.CanvasPosition=Vector2.new(0,math.clamp(self.scroll.CanvasPosition.Y,0,math.max(0,y-self.scroll.Size.Y.Offset)))
	self:refreshScrollCue();self.layingOut=false;self:refreshBackgroundPreview()
end
function Picker:refreshBackgroundPreview()
 if not self.backgroundPreview then return end
 local active=self.shade.Visible and self.active=="Background"and self.display.Visible
 self.shell.Visible=self.active~="Background"
 if active then
  local compact=self.previewMode=="compact";local height=if compact then 34 else 68
  self.backgroundPreview.Position=if compact then UDim2.fromOffset(10,(self.display.Size.Y.Offset-height)/2)else UDim2.fromOffset(12,12)
  self.backgroundPreview.Size=UDim2.fromOffset(if compact then 52 else 102,height)
 end
 local top=self.display.Position.Y.Offset+self.backgroundPreview.Position.Y.Offset-self.scroll.CanvasPosition.Y
 active=active and top+self.backgroundPreview.Size.Y.Offset>0 and top<self.scroll.Size.Y.Offset
 self.backgroundPreview.Visible=active
 Art.setBackgroundPreview(self.backgroundPreview,if self.inspectSlot=="background"then self.inspectId else self.backgroundId or Backgrounds.Default,Themes.ById[self.confirmed.theme or Themes.Default],active)
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
 if active=="Club"then active="Trials"end -- Compatibility for old callers, never a public tab.
 if not self.tabs[active]and active~="Trials"and active~="Settings"then return end
 if not self.returningFromTrials and active~=self.active and active~="Trials"then self.inspectId,self.inspectSlot=nil,nil end
 local changed=self.active~=active;self.active=active
 local style=slots[active]~=nil;local trials=active=="Trials";local settings=active=="Settings"
 self.display.Visible,self.appearanceStatus.Visible=style,style
 self.clubHeader.Visible,self.reward.Visible=trials,trials
 self.sound.Visible,self.music.Visible,self.motion.Visible=settings,settings,settings
 for _,row in ipairs(self.rows)do row.frame.Visible=trials end
 for tab,control in pairs(self.tabs)do control.Visible=style;Art.bind(control,{BackgroundColor3=function()return if tab==active then Art.paletteColor("selected") else Art.paletteColor("raised") end,TextColor3="text"}) end
 for tab,choices in pairs(self.choices)do for _,stroke in pairs(choices)do stroke.Parent.Visible=tab==active end end
 self:refreshAppearance();self.scroll.CanvasPosition=Vector2.zero;self:layout()
 if changed then
  self:bumpControllerEpoch();local selected=GuiService.SelectedObject
  if not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()and string.match(UserInputService:GetLastInputType().Name,"^Gamepad")then GuiService.SelectedObject=self.tabs[active]or (if active=="Settings"then self.sound else self.cancel)
  elseif selected and selected:IsDescendantOf(self.shade)then GuiService.SelectedObject=nil end
 end
end
function Picker:activateChoice(tab,id)
 local stroke=self.choices[tab]and self.choices[tab][id]
 if not self.shade.Visible or self.active~=tab or not stroke then return false end
 if not AppearanceCatalog.canEquip(slots[tab],id,self.facts)then self.inspectId,self.inspectSlot=id,slots[tab];self:refreshAppearance();self:layout();return true end
 local wasInspect=self.inspectId~=nil;self.inspectId,self.inspectSlot=nil,nil
 if self.onApply then self.onApply(slots[tab],id)end
 if wasInspect then self:refreshAppearance();self:layout()end
 return true
end
function Picker:changeSetting(key)
 local control=if key=="sound"then self.sound elseif key=="music"then self.music elseif key=="motion"then self.motion else nil
 if not self.shade.Visible or self.active~="Settings"or not control or not control.Interactable then return false end
 self.onSetting(key);return true
end
function Picker:preview(themeId,stickerId)
 local theme=Themes.ById[themeId];if not theme or not Stickers.ById[stickerId]then return false end
 self.previewName.Text=if self.active=="Sticker"then Stickers.ById[stickerId].name else theme.name
 self.shell.BackgroundColor3,self.face.BackgroundColor3=theme.shell,theme.face or theme.shell
 self.face.AimRocker.BackgroundColor3=theme.rocker or Palette.Ink
 self.bezel.BackgroundColor3,self.buttonA.BackgroundColor3=theme.trim,theme.buttons
 self.screen.BackgroundColor3=theme.lcd.base
 Stickers.paint(self.sticker,stickerId);return true
end
function Picker:select(themeId,stickerId,backgroundId)
 self.themeId,self.stickerId,self.backgroundId=themeId,stickerId,backgroundId or Backgrounds.Default;self.confirmed={theme=themeId,sticker=stickerId,background=backgroundId or Backgrounds.Default};self:refreshAppearance();self:layout();return true
end
function Picker:setAppearance(state)
 self.appearance=state;self.themeId,self.stickerId,self.backgroundId=state.themeId,state.stickerId,state.backgroundId or Backgrounds.Default
 self.confirmed={theme=state.confirmedTheme,sticker=state.confirmedSticker,background=state.confirmedBackground or Backgrounds.Default};self:refreshAppearance();if self.shade.Visible then self:layout()end
end
function Picker:refreshAppearance()
 local style=slots[self.active]~=nil;local slot=slots[self.active]or "theme"
 local status=self.appearance and self.appearance.slots[slot]
 local inspected=self.inspectId and AppearanceCatalog.describeRequirement(self.inspectSlot,self.inspectId,self.facts)
 self.previewNote.Text=if inspected then (if inspected.unlocked then "Available preview"else "Locked preview")else "Selection applies immediately"
 local fallback=self.appearance and self.appearance.fallbacks and self.appearance.fallbacks[slot]
 self.appearanceCaption=if inspected then (if inspected.unlocked then "Available"else "Locked")elseif status then ({Pending="Applying",Applied="Saving",Saved="Saved",Rejected="Not applied",Retry="Retry"})[status.status]else nil
 if fallback and not self.appearanceCaption then self.appearanceCaption="Using default"end
 local words={Pending="Applying...",Applied="Worn - saving...",Saved="Worn - saved",Rejected="Not applied",Retry="Reply delayed - Retry"}
 self.appearanceStatus.Text=if status and words[status.status]then words[status.status]..(if status.reason then " - "..status.reason else "")else "Select to wear immediately."
 if fallback then
  local catalog=catalogs[self.active]or Themes;local id=self.confirmed[slot]
  local name=catalog.ById[id]and catalog.ById[id].name or "default"
  local notice="Previous "..(if slot=="theme"then "shell"else slot).." unavailable - using "..name
  self.appearanceStatus.Text=notice..(if status and status.status=="Pending"then " - Applying..."else "")
 end
 if inspected then
  self.appearanceStatus.Text=if inspected.unlocked then "Available - Select to wear"else "Locked - "..inspected.text..string.format(" (%d/%d)",inspected.progress,inspected.target)
 end
 self.retryButton.Visible=style and status~=nil and (status.status=="Retry"or(status.status=="Rejected"and status.reason~="Superseded"and status.reason~="Locked"and status.reason~="InvalidChoice"and status.reason~="Invalid"))
 self.trialsLink.Visible=style and inspected~=nil and not inspected.unlocked and (inspected.rule=="trials"or inspected.rule=="highRoller"or inspected.rule=="chain3")
 for tab,choices in pairs(self.choices)do for id,stroke in pairs(choices)do
  local accepted=self.confirmed[slots[tab]]==id
  stroke.Enabled=accepted;local option=catalogs[tab].ById[id]
  local unlocked=AppearanceCatalog.canEquip(slots[tab],id,self.facts)
  Art.bind(stroke.Parent.Caption,{TextColor3=if unlocked then "text"else "muted"})
  if tab=="Background"then Art.backgroundThumbnail(stroke.Parent.Chip,id,Themes.ById[self.confirmed.theme or Themes.Default])end
  stroke.Parent.Caption.Text=option.name..(if accepted then " \u{2713}"elseif not AppearanceCatalog.canEquip(slots[tab],id,self.facts)then " - Locked"else "")
 end end
 self:preview(if self.inspectSlot=="theme"then self.inspectId else self.themeId or Themes.Default,if self.inspectSlot=="sticker"then self.inspectId else self.stickerId or Stickers.Default)
 if self.active=="Background"then self.previewName.Text=Backgrounds.ById[if self.inspectSlot=="background"then self.inspectId else self.backgroundId or Backgrounds.Default].name end
end
function Picker:updateClub(owned,mask,peak,score,sound,reduced,systemReduced,inventoryMask,musicEnabled,totalWins,masteryRanks)
 self.facts={rank=owned,trials=mask,inventoryMask=inventoryMask,totalWins=totalWins or 0,masteryRanks=masteryRanks or {}}
	self.sound.Text="SFX: "..sound
	self.music.Text=if musicEnabled==false then "Music: Off"else "Music: On"
	self.motion.Text=if systemReduced then "Motion: Roblox"elseif reduced then "Motion: Low"else "Motion: Full"
	self.motion.Interactable,self.motion.Selectable=not systemReduced,not systemReduced
	local count=0
	for index,goal in ipairs(Trials.Goals)do
		local done=bit32.band(mask,goal.bit)~=0;local current=if index==1 then peak elseif index==2 then score else 0
		local row=self.rows[index]
		row.title.Text=if goal==Trials.HighRoller then (if done then "High score trial complete"else "High score · Score "..goal.target)elseif done then goal.name else goal.hint
		row.status.Text=if done then "✓ Complete"elseif index==3 then "0/1"else string.format("%d/%d",current,goal.target)
		Art.bind(row.status,{TextColor3=function()return if done then Art.Leaf else Art.paletteColor("muted") end})
		row.fill:SetAttribute("Progress",if done then 1 else math.min(1,current/goal.target));row.fill.BackgroundColor3=if done then Art.Amber else Art.Leaf
		count+=if done then 1 else 0
	end
	self.clubHeader.Text=string.format("Pocket trials · %d/%d",count,#Trials.Goals)
	self.reward.Text=if Trials.clubComplete(mask)then "Trial crest ready in Stickers"else "Finish all three to earn the Trial crest"
	for id,stroke in pairs(self.choices.Sticker)do
		local available=Stickers.canEquip(id,owned,mask,inventoryMask);local swatch=stroke.Parent;local option=Stickers.ById[id]
		self.available[id]=available;swatch.Interactable,swatch.Selectable=true,true
  Art.bind(swatch.Caption,{TextColor3=function()return if available then Art.paletteColor("text") else Art.paletteColor("muted") end})
	end
	self:refreshAppearance()
	local signature={self.sound.Text,self.music.Text,self.motion.Text,self.clubHeader.Text,self.reward.Text}
	for _,row in ipairs(self.rows)do table.insert(signature,row.title.Text..row.status.Text)end
	for _,id in ipairs(Stickers.Order)do table.insert(signature,self.choices.Sticker[id].Parent.Caption.Text)end
	local key=table.concat(signature,"|")
	if self.shade.Visible and self.clubLayoutKey~=key then self:layout()end
	self.clubLayoutKey=key
end
function Picker:bumpControllerEpoch()
	self.shade:SetAttribute("ControllerEpoch",(self.shade:GetAttribute("ControllerEpoch")or 0)+1)
end
function Picker:getControllerFocus()
	if not self.shade.Visible then return nil end
	return{root=self.shade,epoch=self.shade:GetAttribute("ControllerEpoch")or 0,
		target=function()return self.tabs[self.active]or (if self.active=="Settings"then self.sound else self.cancel)end,fallback=self.cancel}
end
function Picker:open(themeId,stickerId,mode)
 self:bumpControllerEpoch();self.previousSelection=GuiService.SelectedObject;self.safeTop=nil;self.innerReturn=nil;self.inspectId,self.inspectSlot=nil,nil
 self.shade.Visible=true;if not self.appearance then self:select(themeId,stickerId)end;self:showTab(mode or "Shell")
 if string.match(UserInputService:GetLastInputType().Name,"^Gamepad")then GuiService.SelectedObject=self.tabs[self.active]or (if self.active=="Settings"then self.sound else self.cancel)end
end
function Picker:back()
 if self.innerReturn then local saved=self.innerReturn;self.innerReturn=nil;self.returningFromTrials=true;self:showTab(saved.active);self.returningFromTrials=nil;self.scroll.CanvasPosition=saved.scroll;GuiService.SelectedObject=visibleSelection(saved.focus);return end
 self:close("back")
end
function Picker:close(reason)
 Art.setBackgroundPreview(self.backgroundPreview,nil,nil,false)
 if not self.shade.Visible then return end
 self:bumpControllerEpoch();self.shade.Visible=false;self.innerReturn=nil;self.onClose(reason or "forced")
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.shade)then GuiService.SelectedObject=visibleSelection(self.previousSelection)end
end
return Picker
