-- v2 Stat Eggs: the hatch result (a stand-in until the hatch redesign, V2-HATCH-REDESIGN). It
-- shows the snack the server's receipt names, spinning, with its stat rune and boost, and two
-- buttons: Feed now (primary; A / Enter) and Keep (B / Esc). Every hatched snack is already in
-- the pouch, so Keep only closes. Own ScreenGui above the menus and its own ContextAction.
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local K=require(Shared.StatEggCatalog)
local Stats=require(Shared.StatCatalog)
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local SnackModel=require(script.Parent.SnackModel)
local Reveal={}
Reveal.__index=Reveal
-- The rarity sting per size (existing hatch cues).
Reveal.Sting={nibble="rarity_common",snack="rarity_uncommon",feast="rarity_rare"}

-- Pure: the reveal's words for a receipt.
function Reveal.copy(receipt,petName)
	local size=K.size(receipt.size)or K.Sizes.nibble
	local statName=UICopy.get("stats.name."..tostring(receipt.stat))
	return{kind=UICopy.get("hatch.stat.reveal.kind"),
		name=UICopy.get("hatch.stat.reveal.name",{stat=statName,size=UICopy.get("stats.snacks.size."..size.id)}),
		boost=UICopy.get("hatch.stat.reveal.boost",{mult=size.mult,count=size.xp}),
		forPet=UICopy.get("hatch.stat.reveal.forPet",{pet=petName or "Bear"})}
end

function Reveal.new(playerGui,audio)
	local gui=Instance.new("ScreenGui");gui.Name="EggDropStatReveal";gui.ResetOnSpawn=false;gui.DisplayOrder=16
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ScreenInsets=Enum.ScreenInsets.None;gui.IgnoreGuiInset=true;gui.Enabled=false;gui.Parent=playerGui
	local shade=Instance.new("Frame");shade.Name="Shade";shade.Size=UDim2.fromScale(1,1);shade.BackgroundColor3=Color3.new(0,0,0);shade.BackgroundTransparency=.25;shade.Active=true;shade.Parent=gui
	local card=Kit.frame(shade,"RevealCard","panel",UDim2.fromScale(.5,.5),UDim2.fromOffset(420,380),16)
	card.AnchorPoint=Vector2.new(.5,.5);card.Active=true;Kit.stroke(card)
	local scale=Kit.node("UIScale",card,{Scale=1})
	local self=setmetatable({gui=gui,shade=shade,card=card,scale=scale,audio=audio,open=false},Reveal)
	self.kind=Kit.text(card,"Label","","accent",{Name="Kind",Position=UDim2.fromOffset(20,14),Size=UDim2.new(1,-40,0,18),TextXAlignment=Enum.TextXAlignment.Center})
	self.well=Kit.frame(card,"Well","well",UDim2.fromOffset(110,38),UDim2.fromOffset(200,170),14)
	self.rune=Kit.node("ImageLabel",card,{Name="Rune",BackgroundTransparency=1,Image=SnackModel.Atlas,ImageRectSize=Vector2.new(64,64),Size=UDim2.fromOffset(40,40),Position=UDim2.fromOffset(46,212),ZIndex=card.ZIndex+2})
	self.name=Kit.text(card,"Title","","text",{Name="SnackName",Position=UDim2.fromOffset(92,212),Size=UDim2.new(1,-112,0,30),TextSize=24})
	self.boost=Kit.text(card,"Body","","soft",{Name="Boost",Position=UDim2.fromOffset(92,242),Size=UDim2.new(1,-112,0,20)})
	self.pill=Kit.text(card,"Small","","dim",{Name="Pill",Position=UDim2.fromOffset(20,268),Size=UDim2.new(1,-40,0,18),TextXAlignment=Enum.TextXAlignment.Center})
	self.feedButton=Kit.button(card,"FeedNow",{text=UICopy.get("hatch.stat.reveal.feed"),variant="primary",glyph="A",size=Vector2.new(184,52),selectable=false})
	self.feedButton.Position=UDim2.fromOffset(216,306)
	self.keepButton=Kit.button(card,"Keep",{text=UICopy.get("hatch.stat.reveal.keep"),glyph="B",size=Vector2.new(176,52),selectable=false})
	self.keepButton.Position=UDim2.fromOffset(20,306)
	for _,b in ipairs({self.feedButton,self.keepButton})do for _,d in ipairs(b:GetDescendants())do if d:IsA("GuiObject")then d.ZIndex+=2 end end end
	self.feedButton.Activated:Connect(function()self:choose("feed")end)
	self.keepButton.Activated:Connect(function()self:choose("keep")end)
	shade:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:fit()end)
	return self
end
function Reveal:fit()
	local s=self.shade.AbsoluteSize
	if s.X<=0 then return end
	self.scale.Scale=math.clamp(math.min((s.X-24)/420,(s.Y-24)/380),.5,1.2)
end
function Reveal:isOpen()return self.open end
-- receipt: the server's buy receipt {snackId, stat, size, free}. info: {petName, pill}.
-- callbacks: feed(receipt), keep(receipt).
function Reveal:show(receipt,info,callbacks)
	self:close("replaced")
	info=info or {}
	self.receipt,self.callbacks=receipt,callbacks or {}
	local words=Reveal.copy(receipt,info.petName)
	self.kind.Text=words.kind.."  ·  "..words.forPet
	self.name.Text=words.name;Kit.paint(self.name,"TextColor3",(Stats.ById[receipt.stat]or Stats.ById.heart).color)
	self.boost.Text=words.boost
	self.pill.Text=info.pill or ""
	self.rune.ImageRectOffset=SnackModel.Rune[receipt.stat]or Vector2.zero
	if self.preview then self.preview.destroy()end
	self.preview=SnackModel.viewport(self.well,receipt.size,receipt.stat,{Size=UDim2.fromScale(1,1),ZIndex=self.well.ZIndex+1})
	self.open=true;self.gui.Enabled=true;self:fit()
	Kit.setEnabled(self.feedButton,info.canFeed~=false)
	self.card:SetAttribute("SnackId",receipt.snackId);self.card:SetAttribute("Stat",receipt.stat);self.card:SetAttribute("Size",receipt.size)
	if not Kit.reduced()then
		self.scale.Scale*=.6
		local goal=self.scale.Scale/.6
		Kit.tween(self.scale,.22,{Scale=goal})
	end
	if self.audio then pcall(function()self.audio:play(Reveal.Sting[receipt.size]or "rarity_common",1,.7)end)end
	self.clock=RunService.RenderStepped:Connect(function(dt)if self.preview and not Kit.reduced()then self.preview.step(dt)end end)
	ContextActionService:BindActionAtPriority("EggDropStatReveal",function(_,state,input)
		if not self.open or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
		if state==Enum.UserInputState.Begin then
			local k=input.KeyCode
			if k==Enum.KeyCode.ButtonA or k==Enum.KeyCode.Return or k==Enum.KeyCode.KeypadEnter or k==Enum.KeyCode.Space then self:choose("feed")
			elseif k==Enum.KeyCode.ButtonB or k==Enum.KeyCode.Escape or k==Enum.KeyCode.Backspace then self:choose("keep")end
		end
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value+830,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.Space,Enum.KeyCode.Escape,Enum.KeyCode.Backspace)
	return true
end
function Reveal:choose(choice)
	if not self.open then return end
	if choice=="feed"and not Kit.buttonState(self.feedButton).enabled then return end
	local receipt,callbacks=self.receipt,self.callbacks
	self:close(choice)
	local callback=callbacks and callbacks[choice]
	if callback then callback(receipt)end
end
function Reveal:close(reason)
	if not self.open then return false end
	self.open=false;self.gui.Enabled=false
	ContextActionService:UnbindAction("EggDropStatReveal")
	if self.clock then self.clock:Disconnect();self.clock=nil end
	if self.preview then self.preview.destroy();self.preview=nil end
	local _=reason
	return true
end
function Reveal:destroy()self:close("destroy");self.gui:Destroy()end
return Reveal
