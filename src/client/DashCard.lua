-- Garden Dash cards (V3-DASH-BUILD-PLAN-2026-11-22, slice S7): one small Toy Shell card over a shade, used by the gate
-- (pick a race) and the results. One is open at a time; its ScreenGui is made for it and goes with it.
--   Card.open({playerGui, name, title, lines={text}, buttons={{name, text, act(), primary?}}, back()}) -> card, or nil
--   when it could not be drawn (nothing is left behind: no shade, no binding, no gui)
--   low=true: in the bottom of the screen, so what is behind it (the pet, the course) stays in view; selected=n: the
--   button Enter and a gamepad start on (the first one by itself).
--   strip=<TomorrowStrip model> (Onboarding v3 slice E): the See you tomorrow strip between the lines and the buttons.
-- Enter / A press the first (or the selected) button; B, Backspace or the round key go back.
-- Beta 12 U3 / U6: sheet="gate" | "results" draws DashGateSheet or DashResultsSheet on this shell instead (the shade,
-- the binding, the close and the rebuild on a resize stay here); a sheet may set card.sheetStep (once a frame while
-- open), card.stage (destroyed with the card) and card.inputAt (no press before it).
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Kit=require(script.Parent.DeckKit)
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Card={};Card.__index=Card
Card.Action="EggDropDashCard"
Card.DisplayOrder=15
Card.Priority=Enum.ContextActionPriority.High.Value+820

-- Pure: the card for a W x H screen. `lineH` = the measured height of each line. `strip` (optional): room for the
-- See you tomorrow strip under the lines (44 + 8, 36 + 6 compact); its top is `stripY`.
function Card.layout(W,H,lineH,buttons,strip)
	local compact=H<=430 or W<=700
	local pad=if compact then 14 else 20
	local w=math.min(if compact then 440 else 500,W-24)
	local titleH=if compact then 28 else 34
	local bh=if compact then 46 else 52
	local y=pad+titleH+6
	local lines={}
	for index,height in ipairs(lineH)do lines[index]={y=y,h=height};y+=height+2 end
	y+=10
	local stripY,stripH=nil,0
	if strip then stripY,stripH=y,if compact then 36 else 44;y+=stripH+(if compact then 6 else 8)end
	local gap=10
	local bw=math.floor((w-pad*2-gap*(buttons-1))/math.max(1,buttons))
	return{compact=compact,pad=pad,w=w,h=math.min(H-8,y+bh+pad),titleH=titleH,lineW=w-pad*2,lines=lines,buttonY=y,bw=bw,bh=bh,gap=gap,text=if compact then 15 else 17,
		stripY=stripY,stripH=stripH}
end

-- Pure: the low card. Small enough for the bottom of the screen: the last lines go before it passes a third of it.
function Card.lowLayout(W,H,lineH,buttons)
	local compact=H<=430 or W<=700
	local pad=if compact then 8 else 14
	local w=math.min(if compact then 520 else 600,W-24)
	local titleH=if compact then 26 else 32
	local bh=if compact then 44 else 48
	local shown=#lineH
	local function height(count)
		local h=pad+titleH+2
		for index=1,count do h+=lineH[index]+2 end
		return h+4+bh+pad
	end
	while shown>1 and height(shown)>H/3 do shown-=1 end
	if shown==1 and height(1)>H*.4 then shown=0 end
	local y=pad+titleH+2
	local lines={}
	for index=1,shown do lines[index]={y=y,h=lineH[index]};y+=lineH[index]+2 end
	local gap=10
	local bw=math.floor((w-pad*2-gap*(buttons-1))/math.max(1,buttons))
	return{compact=compact,pad=pad,w=w,h=y+4+bh+pad,titleH=titleH,lineW=w-pad*2,lines=lines,buttonY=y+4,bw=bw,bh=bh,gap=gap,text=if compact then 14 else 17,low=8}
end

function Card.open(options)
	local self=setmetatable({options=options,buttons={},lines={}},Card)
	local gui=Instance.new("ScreenGui")
	gui.Name="EggDropDash"..options.name;gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder=Card.DisplayOrder;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ClipToDeviceSafeArea=false
	local root=Instance.new("Frame")
	root.Name="Root";root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Parent=gui
	gui.Parent=options.playerGui
	self.gui,self.root=gui,root
	local ok,problem=pcall(function()
		self.shade=Kit.modalShade(root,"DashShade",10)
		Kit.shadeOpen(self,self.shade)
		self:build()
		self.connection=root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local drawn,trouble=pcall(self.build,self)
			if not drawn then warn("[Dash] card: "..tostring(trouble));self:back()end
		end)
	end)
	if not ok then
		warn("[Dash] card: "..tostring(problem))
		self:close()
		return nil
	end
	if options.sheet then
		self.stepConnection=RunService.RenderStepped:Connect(function(dt)
			local step=self.sheetStep
			if not step or self.closed then return end
			local fine,trouble=pcall(step,dt)
			if not fine then warn("[Dash] sheet: "..tostring(trouble));self.sheetStep=nil end
		end)
	end
	ContextActionService:BindActionAtPriority(Card.Action,function(_,state,input)
		local Confirm=require(script.Parent.ConfirmDialog)
		if Confirm.isOpen()then return Enum.ContextActionResult.Pass end
		if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		if input.KeyCode==Enum.KeyCode.Return or input.KeyCode==Enum.KeyCode.KeypadEnter then self:press(options.selected or 1)
		else self:back()end
		return Enum.ContextActionResult.Sink
	end,false,Card.Priority,Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter)
	return self
end
function Card:reduced()
	local value=self.options.reduced
	return(type(value)=="function"and value()==true)or Kit.reduced()==true
end
function Card:rebuild()
	if self.closed then return end
	local ok,problem=pcall(self.build,self)
	if not ok then warn("[Dash] card: "..tostring(problem));self:back()end
end
-- A results sheet takes a newer model (the saved receipt).
function Card:update(model)
	if self.closed or self.options.sheet~="results"then return end
	require(script.Parent.DashResultsSheet).update(self,model)
end
function Card:build()
	local options=self.options
	if self.stage then pcall(self.stage.destroy,self.stage);self.stage=nil end
	if self.strip and self.strip.destroy then pcall(self.strip.destroy,self.strip)end
	self.strip=nil
	if self.panel then self.panel:Destroy();self.panel=nil end
	table.clear(self.buttons);table.clear(self.lines)
	local size=self.root.AbsoluteSize
	local W,H=math.max(320,size.X),math.max(240,size.Y)
	if options.sheet then
		self.sheetStep=nil
		require(script.Parent[if options.sheet=="gate"then "DashGateSheet"else "DashResultsSheet"]).build(self,W,H)
		return
	end
	local layout=if options.low then Card.lowLayout else Card.layout
	-- The strip rides the centred card only (the low card has no room for it).
	local strip=if not options.low then options.strip else nil
	local probe=layout(W,H,{},#options.buttons,strip~=nil)
	local heights={}
	for index,text in ipairs(options.lines)do heights[index]=math.max(20,math.ceil(Kit.measure(text,"Body",probe.text,probe.lineW).Y)+4)end
	local g=layout(W,H,heights,#options.buttons,strip~=nil)
	local panel=Kit.frame(self.root,"DashCard","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(g.w,g.h),if g.compact then 16 else 22)
	panel.AnchorPoint=Vector2.new(.5,.5);panel.Active=true;panel.ZIndex=20
	if g.low then panel.AnchorPoint=Vector2.new(.5,1);panel.Position=UDim2.new(.5,0,1,-g.low)end
	Kit.stroke(panel)
	self.panel=panel
	Kit.text(panel,"Title",options.title,"text",{Name="Title",Position=UDim2.fromOffset(g.pad,g.pad),Size=UDim2.fromOffset(g.lineW-44,g.titleH),
		TextSize=if g.compact then 22 else 26,TextTruncate=Enum.TextTruncate.AtEnd})
	local closeSize=if g.compact then 32 else 36
	local close=Kit.closeKey(panel,"Close",closeSize,UICopy.get("confirm.cancel"))
	close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.fromOffset(g.w-g.pad+4,g.pad-4);close.ZIndex=panel.ZIndex+2
	close.Activated:Connect(function()self:back()end)
	for index,text in ipairs(options.lines)do
		if not g.lines[index]then break end
		self.lines[index]=Kit.text(panel,"Body",text,"soft",{Name="Line"..index,Position=UDim2.fromOffset(g.pad,g.lines[index].y),Size=UDim2.fromOffset(g.lineW,g.lines[index].h),
			TextSize=g.text,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
	end
	if strip and g.stripY then
		local ok,problem=pcall(function()
			local Strip=require(script.Parent.TomorrowStrip)
			local view=Strip.new(panel,{phone=g.compact,short=g.w<Strip.NarrowCard,z=panel.ZIndex+2})
			view.root.Position=UDim2.fromOffset(g.pad,g.stripY)
			view:set(strip,g.lineW)
			view:enter(.3,Kit.reduced and Kit.reduced())
			self.strip=view
		end)
		if not ok then warn("[Dash] strip: "..tostring(problem))end
	end
	for index,spec in ipairs(options.buttons)do
		local button=Kit.button(panel,spec.name,{variant=if spec.primary then "primary"else "secondary",text=spec.text,size=Vector2.new(g.bw,g.bh),
			textSize=if g.compact then 15 else 17,compact=g.compact})
		button.Position=UDim2.fromOffset(g.pad+(index-1)*(g.bw+g.gap),g.buttonY);button.ZIndex=panel.ZIndex+2
		button.Activated:Connect(function()self:press(index)end)
		self.buttons[index]=button
	end
	if string.sub(UserInputService:GetLastInputType().Name,1,7)=="Gamepad"then GuiService.SelectedObject=self.buttons[options.selected or 1]end
end
-- New words on an open card (a saved receipt); same number of lines, no rebuild.
function Card:setLine(index,text)
	self.options.lines[index]=text
	local label=self.lines[index]
	if label and label.Text~=text then label.Text=text end
end
function Card:press(index)
	local spec=self.options.buttons[index]
	if self.closed or not spec then return end
	if self.inputAt and os.clock()<self.inputAt then return end
	self:close()
	spec.act()
end
function Card:back()
	if self.closed then return end
	self:close()
	if self.options.back then self.options.back()end
end
function Card:close()
	if self.closed then return end
	self.closed=true
	ContextActionService:UnbindAction(Card.Action)
	if self.connection then self.connection:Disconnect()end
	if self.stepConnection then self.stepConnection:Disconnect();self.stepConnection=nil end
	self.sheetStep=nil
	if self.stage then pcall(self.stage.destroy,self.stage);self.stage=nil end
	pcall(Kit.shadeClose,self)
	local selected=GuiService.SelectedObject
	if selected and selected:IsDescendantOf(self.gui)then GuiService.SelectedObject=nil end
	self.gui:Destroy()
end
return Card
