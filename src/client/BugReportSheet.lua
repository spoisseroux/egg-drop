-- Settings > "Report a bug / Suggest something" (v1 track B). A small Kit sheet in its
-- own ScreenGui (the caller makes it, DisplayOrder 14, above the Collection book):
-- Bug / Suggestion, one category chip (required), an optional 200-character note, Send.
-- Context (place version on the server; device, viewport, mode, screen, the last few
-- warnings and errors from LogService on this client) is attached automatically. No
-- names, chat, friends or contact details are collected, and the note never reaches
-- another player. The rules live in Shared.BugReportForm; the server re-checks
-- everything (server/BugReportStore).
--
-- options = {send(packet), context() -> table, closed(reason), accepted(kind)}
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local LogService=game:GetService("LogService")
local HttpService=game:GetService("HttpService")
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").Shared
local Kit=require(script.Parent.DeckKit)
local Form=require(Shared.BugReportForm)
local UICopy=require(Shared.UICopy)

local Sheet={}
Sheet.__index=Sheet
Sheet.Action="EggDropBugReport"
-- Above the Collection book (High+810): the sheet owns Back while it is open.
Sheet.Priority=Enum.ContextActionPriority.High.Value+820
Sheet.BackKeys={Enum.KeyCode.ButtonB,Enum.KeyCode.Escape,Enum.KeyCode.Backspace}

local function gamepad()return string.match(UserInputService:GetLastInputType().Name,"^Gamepad")~=nil end

-- Pure: the sheet rect for a root size. Phone (Kit.compactRule): full width under the
-- Roblox controls. Regular: up to 560 wide, centred.
function Sheet.layoutFor(size,kh)
	if Kit.compactRule(size.X,size.Y)then
		local top=(kh or 58)+2
		return{phone=true,x=0,y=top,W=math.floor(size.X),H=math.max(120,math.floor(size.Y)-top),pad=16}
	end
	local W=math.max(280,math.min(560,math.floor(size.X)-24))
	return{phone=false,W=W,maxH=math.max(200,math.floor(size.Y)-24),pad=24}
end

function Sheet.new(root,options)
	local self=setmetatable({root=root,options=options or {},kindButtons={},chipButtons={},
		form={kind="bug",category=nil,note="",sending=false,sentAt=nil,nonce=nil},openState=false},Sheet)
	self.shade=Kit.modalShade(root,"ReportShade",30)
	local panel=Kit.frame(root,"ReportSheet","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(520,360),18)
	panel.AnchorPoint=Vector2.new(.5,.5);panel.ZIndex=31;panel.Visible=false;panel.Active=true;panel.ClipsDescendants=true
	self.panel=panel;self.stroke=Kit.stroke(panel)
	local scroll=Instance.new("ScrollingFrame");scroll.Name="Body";scroll.Parent=panel
	scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ZIndex=1,0,panel.ZIndex+2
	scroll.ScrollingDirection,scroll.ElasticBehavior=Enum.ScrollingDirection.Y,Enum.ElasticBehavior.Never
	scroll.ScrollBarThickness=4;scroll.CanvasSize=UDim2.new();scroll.Selectable=false
	self.scroll=scroll
	for _,id in ipairs(Form.Kinds)do
		local button=Kit.button(scroll,"Kind_"..id,{text=UICopy.get("report.kind."..id),size=Vector2.new(160,40),compact=true})
		button.Activated:Connect(function()self:setKind(id)end)
		self.kindButtons[id]=button
	end
	self.about=Kit.text(scroll,"Label",UICopy.get("report.about"),"dim",{Name="About"})
	for _,id in ipairs(Form.Categories)do
		local button=Kit.button(scroll,"Cat_"..id,{text=UICopy.get("report.category."..id),size=Vector2.new(110,36),compact=true,textSize=16})
		button.Activated:Connect(function()self:setCategory(id)end)
		self.chipButtons[id]=button
	end
	local well=Kit.frame(scroll,"NoteWell","well",UDim2.new(),UDim2.fromOffset(200,64),10);Kit.stroke(well)
	self.well=well
	local box=Instance.new("TextBox");box.Name="Note";box.Parent=well
	box.BackgroundTransparency=1;box.ClearTextOnFocus=false;box.MultiLine=false;box.TextWrapped=true
	box.TextXAlignment,box.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Top
	box.FontFace=Kit.Type.Body[3];box.TextSize=Kit.Type.Body[1];box.Text="";box.PlaceholderText=UICopy.get("report.note.placeholder")
	box.TextColor3=Kit.Color.text;box.PlaceholderColor3=Kit.Color.dim;box.ZIndex=well.ZIndex+1
	box.Position=UDim2.fromOffset(12,8);box.Size=UDim2.new(1,-24,1,-16);box.Selectable=true
	box:SetAttribute("AccessibleLabel",UICopy.get("report.note.placeholder"))
	self.box=box
	self.counter=Kit.fixedText(Kit.text(scroll,"Small","","dim",{Name="Counter",TextXAlignment=Enum.TextXAlignment.Right}))
	self.privacy=Kit.text(scroll,"Small",UICopy.get("report.note.privacy"),"dim",{Name="Privacy",TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
	self.status=Kit.text(scroll,"Small","","dangerText",{Name="Status",TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
	self.send=Kit.button(scroll,"Send",{variant="primary",text=UICopy.get("report.send"),size=Vector2.new(220,48)})
	self.send.Activated:Connect(function()self:submit()end)
	self.header=Kit.header(panel,{title=UICopy.get("report.title"),eyebrow=UICopy.get("report.eyebrow"),wallet=false,compact=false,width=520,
		onBack=function()self:close("back")end})
	self.header.root.ZIndex=panel.ZIndex+3
	self.connections={
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local clipped=Form.clip(box.Text)
			if clipped~=box.Text then box.Text=clipped;return end
			self.form.note=clipped;self:refresh()
		end),
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()if self.openState then self:layout()end end),
	}
	self.toaster=Kit.toaster(root)
	self.toaster.placement=function()
		local size=root.AbsoluteSize;local _,kh=Kit.keepOut()
		local compact=Kit.compactRule(size.X,size.Y)
		return nil,(if compact then kh+6 else 30),compact
	end
	self:refresh()
	return self
end

function Sheet:isOpen()return self.openState end

-- The phone header is compact; rebuilt only when that changes.
function Sheet:ensureHeader(compact,W)
	if self.header.compact~=compact then
		self.header.root:Destroy()
		self.header=Kit.header(self.panel,{title=UICopy.get(if compact then "report.titleShort"else "report.title"),eyebrow=UICopy.get("report.eyebrow"),
			wallet=false,compact=compact,width=W,onBack=function()self:close("back")end})
		self.header.root.ZIndex=self.panel.ZIndex+3
	end
	self.header.layout(W,if compact then 16 else 24)
	return self.header
end

function Sheet:layout()
	local size=self.root.AbsoluteSize
	local _,kh=Kit.keepOut()
	local l=Sheet.layoutFor(size,kh)
	local header=self:ensureHeader(l.phone,l.W)
	local headerH=if l.phone then 60 else 84
	local pad=l.pad
	local bodyW=l.W-pad*2-6
	local y=4
	-- Bug / Suggestion.
	local kindW=math.min(180,math.floor((bodyW-8)/2))
	for index,id in ipairs(Form.Kinds)do
		local button=self.kindButtons[id]
		button.Position=UDim2.fromOffset((index-1)*(kindW+8),y);button.Size=UDim2.fromOffset(kindW,40)
	end
	y+=40+14
	self.about.Position=UDim2.fromOffset(0,y);self.about.Size=UDim2.fromOffset(bodyW,16);y+=22
	-- Category chips, wrapping.
	local widths={}
	for index,id in ipairs(Form.Categories)do
		widths[index]=math.min(bodyW,math.ceil(Kit.measure(UICopy.get("report.category."..id),"Button",16).X)+28)
	end
	local spots,chipsH=Form.flow(widths,bodyW,8,36)
	for index,id in ipairs(Form.Categories)do
		local button=self.chipButtons[id]
		button.Position=UDim2.fromOffset(spots[index].x,y+spots[index].y);button.Size=UDim2.fromOffset(widths[index],36)
	end
	y+=chipsH+16
	-- Note, counter, privacy line.
	local noteH=if l.phone then 52 else 72
	self.well.Position=UDim2.fromOffset(0,y);self.well.Size=UDim2.fromOffset(bodyW,noteH);y+=noteH+4
	self.counter.Position=UDim2.fromOffset(bodyW-70,y);self.counter.Size=UDim2.fromOffset(70,18)
	local privacyH=math.ceil(Kit.measure(self.privacy.Text,"Small",self.privacy.TextSize,bodyW-80).Y)+2
	self.privacy.Position=UDim2.fromOffset(0,y);self.privacy.Size=UDim2.fromOffset(bodyW-80,privacyH);y+=math.max(18,privacyH)+12
	-- Send and the status line.
	local sendW=math.min(240,bodyW);local sendH=if l.phone then 44 else 48
	self.send.Position=UDim2.fromOffset(0,y);self.send.Size=UDim2.fromOffset(sendW,sendH)
	local statusX=sendW+12;local statusW=bodyW-statusX
	if statusW<140 then
		y+=sendH+8;statusX=0;statusW=bodyW
		self.status.Position=UDim2.fromOffset(0,y);self.status.Size=UDim2.fromOffset(bodyW,32);y+=32
	else
		self.status.Position=UDim2.fromOffset(statusX,y+4);self.status.Size=UDim2.fromOffset(statusW,sendH)
		y+=sendH+8
	end
	local contentH=y+8
	local panelH
	if l.phone then
		self.panel.AnchorPoint=Vector2.zero;self.panel.Position=UDim2.fromOffset(l.x,l.y)
		panelH=l.H;Kit.corner(self.panel,16)
		Kit.setShadeAlpha(self.shade,1)
	else
		self.panel.AnchorPoint=Vector2.new(.5,.5);self.panel.Position=UDim2.fromScale(.5,.5)
		panelH=math.min(l.maxH,headerH+contentH+pad)
		Kit.corner(self.panel,22)
		Kit.setShadeAlpha(self.shade,Kit.ShadeAlpha)
	end
	self.panel.Size=UDim2.fromOffset(l.W,panelH)
	self.scroll.Position=UDim2.fromOffset(pad,headerH);self.scroll.Size=UDim2.fromOffset(l.W-pad*2,math.max(40,panelH-headerH-8))
	self.scroll.CanvasSize=UDim2.fromOffset(0,contentH)
	self.panel:SetAttribute("Layout",if l.phone then "phone"else "regular")
	self.lastLayout=l
	return l
end

function Sheet:refresh()
	local form=self.form
	for id,button in pairs(self.kindButtons)do Kit.setSelected(button,form.kind==id)end
	for id,button in pairs(self.chipButtons)do Kit.setSelected(button,form.category==id)end
	self.counter.Text=UICopy.get("report.note.count",{count=Form.length(form.note)})
	local now=os.clock()
	local cooling=form.sentAt~=nil and now-form.sentAt<Form.Cooldown
	local label=if form.sending then UICopy.get("report.sending")elseif cooling then UICopy.get("report.wait")else UICopy.get("report.send")
	Kit.setText(self.send,label)
	-- Send stays pressable without a category so it can say "Pick what it's about".
	Kit.setEnabled(self.send,not form.sending and not cooling)
end

function Sheet:setKind(id)
	if not self.openState or self.form.sending then return false end
	self.form.kind=id;self:refresh();self:accept("confirm");return true
end
function Sheet:setCategory(id)
	if not self.openState or self.form.sending then return false end
	self.form.category=id;self.status.Text="";self:refresh();self:accept("confirm");return true
end
function Sheet:accept(kind)if self.options.accepted then self.options.accepted(kind)end end

function Sheet:open(context)
	if self.openState then return false end
	self.context=if type(context)=="table"then context else {}
	local form=self.form
	form.kind="bug";form.category=Form.defaultCategory(self.context);form.note="";form.sending=false;form.nonce=nil
	self.box.Text="";self.status.Text=""
	self.openState=true;self.panel.Visible=true
	Kit.shadeOpen(self,self.shade,function(covered)self.panel.Interactable=not covered end)
	self:layout();self:refresh()
	self.scroll.CanvasPosition=Vector2.zero
	ContextActionService:BindActionAtPriority(Sheet.Action,function(_,state)
		if not self.openState or UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
		if state==Enum.UserInputState.Begin then self:close("back")end
		return Enum.ContextActionResult.Sink
	end,false,Sheet.Priority,table.unpack(Sheet.BackKeys))
	self.previousSelection=GuiService.SelectedObject
	if gamepad()then GuiService.SelectedObject=self.kindButtons.bug end
	return true
end

function Sheet:close(reason)
	if not self.openState then return false end
	self.openState=false
	ContextActionService:UnbindAction(Sheet.Action)
	if self.box:IsFocused()then self.box:ReleaseFocus(false)end
	self.panel.Visible=false;Kit.shadeClose(self)
	local selected=GuiService.SelectedObject
	if selected and selected:IsDescendantOf(self.root)then
		local previous=self.previousSelection
		GuiService.SelectedObject=if previous and previous.Parent and previous:IsDescendantOf(game)then previous else nil
	end
	if reason=="back"then self:accept("back")end
	if self.options.closed then self.options.closed(reason or "forced")end
	return true
end

-- The last warnings and errors this client logged (names scrubbed).
function Sheet.clientErrors()
	local ok,history=pcall(LogService.GetLogHistory,LogService)
	if not ok or type(history)~="table"then return {}end
	local player=Players.LocalPlayer
	local names=if player then {player.Name,player.DisplayName}else {}
	return Form.recentErrors(history,names,Form.MaxErrors)
end

function Sheet:submit()
	local form=self.form
	if not self.openState or form.sending then return false end
	if form.category==nil then self.status.Text=UICopy.get("report.pick");self:accept("back");return false end
	if not Form.canSend(form,os.clock())then return false end
	if self.box:IsFocused()then self.box:ReleaseFocus(false)end
	local nonce=HttpService:GenerateGUID(false)
	form.sending=true;form.nonce=nonce;self.status.Text=""
	local context=self.options.context and self.options.context()or self.context
	local packet=Form.packet(form,context,Sheet.clientErrors(),nonce)
	self:refresh();self:accept("confirm")
	if self.options.send then self.options.send(packet)end
	task.delay(Form.ReplyTimeout,function()
		if self.form.sending and self.form.nonce==nonce then self:receive(nil,nonce)end
	end)
	return true
end

-- A reply from the server (nil = timed out for `nonce`).
function Sheet:receive(reply,nonce)
	local form=self.form
	local id=if type(reply)=="table"then reply.nonce else nonce
	if not form.sending or id~=form.nonce then return false end
	form.sending=false;form.nonce=nil
	local key=Form.replyKey(reply,form.kind)
	local status=if type(reply)=="table"then reply.status else nil
	if status=="Sent"or status=="Duplicate"or status=="Queued"then
		form.sentAt=os.clock()
		self:close("sent")
		self.toaster.show(UICopy.get(key))
	else
		-- A timeout may still have landed: hold Send for the cooldown so it is not sent twice.
		if status==nil or status=="Limited"then form.sentAt=os.clock()end
		self.status.Text=UICopy.get(key)
		self:accept("back")
	end
	self:refresh()
	task.delay(Form.Cooldown+.1,function()self:refresh()end)
	return true
end

function Sheet:destroy()
	if self.openState then self:close("forced")end
	for _,connection in ipairs(self.connections)do connection:Disconnect()end
	self.panel:Destroy();self.shade:Destroy()
end

return Sheet
