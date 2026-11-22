-- Garden Dash cards (V3-DASH-BUILD-PLAN-2026-11-22, slice S7): one small Toy Shell card over a shade, used by the gate
-- (pick a race) and the results. One is open at a time; its ScreenGui is made for it and goes with it.
--   Card.open({playerGui, name, title, lines={text}, buttons={{name, text, act(), primary?}}, back()}) -> card, or nil
--   when it could not be drawn (nothing is left behind: no shade, no binding, no gui)
-- Enter / A press the first (or the selected) button; B, Backspace or the round key go back.
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Kit=require(script.Parent.DeckKit)
local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Card={};Card.__index=Card
Card.Action="EggDropDashCard"
Card.DisplayOrder=15
Card.Priority=Enum.ContextActionPriority.High.Value+820

-- Pure: the card for a W x H screen. `lineH` = the measured height of each line.
function Card.layout(W,H,lineH,buttons)
	local compact=H<=430 or W<=700
	local pad=if compact then 14 else 20
	local w=math.min(if compact then 440 else 500,W-24)
	local titleH=if compact then 28 else 34
	local bh=if compact then 46 else 52
	local y=pad+titleH+6
	local lines={}
	for index,height in ipairs(lineH)do lines[index]={y=y,h=height};y+=height+2 end
	y+=10
	local gap=10
	local bw=math.floor((w-pad*2-gap*(buttons-1))/math.max(1,buttons))
	return{compact=compact,pad=pad,w=w,h=math.min(H-8,y+bh+pad),titleH=titleH,lineW=w-pad*2,lines=lines,buttonY=y,bw=bw,bh=bh,gap=gap,text=if compact then 15 else 17}
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
	ContextActionService:BindActionAtPriority(Card.Action,function(_,state,input)
		local Confirm=require(script.Parent.ConfirmDialog)
		if Confirm.isOpen()then return Enum.ContextActionResult.Pass end
		if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		if input.KeyCode==Enum.KeyCode.Return or input.KeyCode==Enum.KeyCode.KeypadEnter then self:press(1)
		else self:back()end
		return Enum.ContextActionResult.Sink
	end,false,Card.Priority,Enum.KeyCode.ButtonB,Enum.KeyCode.Backspace,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter)
	return self
end
function Card:build()
	local options=self.options
	if self.panel then self.panel:Destroy();self.panel=nil end
	table.clear(self.buttons);table.clear(self.lines)
	local size=self.root.AbsoluteSize
	local W,H=math.max(320,size.X),math.max(240,size.Y)
	local probe=Card.layout(W,H,{},#options.buttons)
	local heights={}
	for index,text in ipairs(options.lines)do heights[index]=math.max(20,math.ceil(Kit.measure(text,"Body",probe.text,probe.lineW).Y)+4)end
	local g=Card.layout(W,H,heights,#options.buttons)
	local panel=Kit.frame(self.root,"DashCard","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(g.w,g.h),if g.compact then 16 else 22)
	panel.AnchorPoint=Vector2.new(.5,.5);panel.Active=true;panel.ZIndex=20
	Kit.stroke(panel)
	self.panel=panel
	Kit.text(panel,"Title",options.title,"text",{Name="Title",Position=UDim2.fromOffset(g.pad,g.pad),Size=UDim2.fromOffset(g.lineW-44,g.titleH),
		TextSize=if g.compact then 22 else 26,TextTruncate=Enum.TextTruncate.AtEnd})
	local closeSize=if g.compact then 32 else 36
	local close=Kit.closeKey(panel,"Close",closeSize,UICopy.get("confirm.cancel"))
	close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.fromOffset(g.w-g.pad+4,g.pad-4);close.ZIndex=panel.ZIndex+2
	close.Activated:Connect(function()self:back()end)
	for index,text in ipairs(options.lines)do
		self.lines[index]=Kit.text(panel,"Body",text,"soft",{Name="Line"..index,Position=UDim2.fromOffset(g.pad,g.lines[index].y),Size=UDim2.fromOffset(g.lineW,g.lines[index].h),
			TextSize=g.text,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
	end
	for index,spec in ipairs(options.buttons)do
		local button=Kit.button(panel,spec.name,{variant=if spec.primary then "primary"else "secondary",text=spec.text,size=Vector2.new(g.bw,g.bh),
			textSize=if g.compact then 15 else 17,compact=g.compact})
		button.Position=UDim2.fromOffset(g.pad+(index-1)*(g.bw+g.gap),g.buttonY);button.ZIndex=panel.ZIndex+2
		button.Activated:Connect(function()self:press(index)end)
		self.buttons[index]=button
	end
	if string.sub(UserInputService:GetLastInputType().Name,1,7)=="Gamepad"then GuiService.SelectedObject=self.buttons[1]end
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
	pcall(Kit.shadeClose,self)
	local selected=GuiService.SelectedObject
	if selected and selected:IsDescendantOf(self.gui)then GuiService.SelectedObject=nil end
	self.gui:Destroy()
end
return Card
