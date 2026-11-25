-- v2 pet names: the Names Egg hatch on the v2 Pop-Out Stage (HatchItemStage, kind "name").
-- The egg shakes, cracks and pops in the well, and a cream name key (the piece, with the egg
-- mark) springs out of it. The result card says the piece is yours for every pet, shows the pool
-- it came from in the open (the egg card's odds, or the fixed order), and ends on Use it
-- (primary: puts the piece in the next free slot of the naming screen) and Done.
-- Own ScreenGui above the naming screen, its own ContextAction and its own hatch clock.
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Names=require(Shared.NameCatalog)
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local Stage=require(script.Parent.HatchItemStage)
local Pose=require(script.Parent.HatchDisplayPose)
local Rarity=require(script.Parent.HatchRarityCue)
local Asmr=require(script.Parent.HatchAsmr)
local Reveal={}
Reveal.__index=Reveal
Reveal.Kind="name"
Reveal.Pink=Color3.fromHex("#FF86C8")

-- A scene for the stage: the 2D egg, then the name key.
local function nameScene(receipt)
	local root=Instance.new("Frame");root.Name="NameEggScene";root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1)
	local a=Stage.Art.egg
	local egg=Instance.new("ImageLabel");egg.Name="NameEgg";egg.BackgroundTransparency=1;egg.Image=Stage.Art[a[1]]
	egg.ImageRectOffset=Vector2.new(a[2],a[3]);egg.ImageRectSize=Vector2.new(a[4],a[5]);egg.AnchorPoint=Vector2.new(.5,1)
	egg.ImageColor3=Color3.fromHex("#FFD6EA")
	egg.Position=UDim2.fromScale(.5,.8);egg.Size=UDim2.fromScale(.46,.575);egg.ZIndex=root.ZIndex;egg.Parent=root
	local cracks={}
	for i=1,4 do
		local bar=Instance.new("Frame");bar.Name="Crack"..i;bar.BackgroundColor3=Kit.Color.ink;bar.BorderSizePixel=0
		bar.AnchorPoint=Vector2.new(.5,.5);bar.Position=UDim2.fromScale(.2+(i-.5)*.15,.42);bar.Size=UDim2.fromScale(.17,.022)
		bar.Rotation=if i%2==0 then -32 else 32;bar.Visible=false;bar.Parent=egg;cracks[i]=bar
	end
	-- The hero: a cream key with the piece's name (a proper name: never auto-translated).
	local holder=Instance.new("Frame");holder.Name="NameKeyHolder";holder.BackgroundTransparency=1;holder.AnchorPoint=Vector2.new(.5,.5)
	holder.Position=UDim2.fromScale(.5,.52);holder.Size=UDim2.fromScale(.86,.26);holder.Parent=root
	local scale=Instance.new("UIScale");scale.Parent=holder
	local lip=Instance.new("Frame");lip.Name="Lip";lip.BackgroundColor3=Kit.Color.ink;lip.Position=UDim2.fromScale(0,.08);lip.Size=UDim2.fromScale(1,1);lip.Parent=holder
	Kit.corner(lip,999)
	local key=Instance.new("Frame");key.Name="NameKey";key.BackgroundColor3=Kit.Color.cream;key.Size=UDim2.fromScale(1,1);key.ZIndex=2;key.Parent=holder
	Kit.corner(key,999)
	local stroke=Instance.new("UIStroke");stroke.Color=Kit.Color.ink;stroke.Thickness=3;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=key
	local mark=Instance.new("Frame");mark.Name="EggMark";mark.BackgroundColor3=Reveal.Pink;mark.AnchorPoint=Vector2.new(0,.5)
	mark.Position=UDim2.new(.06,0,.5,0);mark.Size=UDim2.fromScale(.11,.62);mark.ZIndex=3;mark.Parent=key
	Kit.corner(mark,999);local ms=Instance.new("UIStroke");ms.Color=Kit.Color.ink;ms.Thickness=2;ms.Parent=mark
	local text=Instance.new("TextLabel");text.Name="Piece";text.BackgroundTransparency=1;text.Position=UDim2.fromScale(.2,.08);text.Size=UDim2.fromScale(.74,.84)
	text.FontFace=Kit.DisplayFace or Kit.Type.Strong[3];text.TextScaled=true;text.TextColor3=Kit.Color.ink;text.AutoLocalize=false;text.ZIndex=3
	text.Text=Names.text(receipt.piece)or "?";text.Parent=key
	local scene={ready=true,root=root}
	function scene:borrow(seat)root.Parent=seat;return root end
	function scene:release(token)if token==root then root.Parent=nil end end
	function scene:setBare()end
	function scene:setVeil()end
	function scene:layout()end
	function scene:setSpin()return false end
	function scene:render(sample)
		local shell=sample.shellAlpha or 0
		egg.Visible=shell>.01
		egg.ImageTransparency=1-shell
		egg.Rotation=math.deg(sample.rock or 0)
		egg.Size=UDim2.fromScale(.46*(sample.eggSX or 1)*(.4+.6*(sample.shellScale or 1)),.575*(sample.eggSY or 1)*(.4+.6*(sample.shellScale or 1)))
		egg.Position=UDim2.fromScale(.5,.8-.05*(sample.eggLift or 0))
		for i,bar in ipairs(cracks)do bar.Visible=(sample.crack or 0)>=(i-1)/4+.01 end
		local hero=sample.heroAlpha or 0
		holder.Visible=hero>.01
		key.BackgroundTransparency=1-hero;lip.BackgroundTransparency=1-hero;mark.BackgroundTransparency=1-hero
		text.TextTransparency=1-hero;stroke.Transparency=1-hero;ms.Transparency=1-hero
		scale.Scale=math.max(.01,sample.heroScale or 1)
	end
	function scene:destroy()self.destroyed=true;root:Destroy()end
	return scene
end
Reveal.scene=nameScene

-- Pure: the card's words.
function Reveal.copy(receipt)
	return {name=Names.text(receipt.piece)or "?",effect=UICopy.get("names.reveal.line"),
		sticker=UICopy.get("names.reveal.sticker")}
end

function Reveal.new(playerGui,audio)
	local gui=Instance.new("ScreenGui");gui.Name="EggDropNameReveal";gui.ResetOnSpawn=false;gui.DisplayOrder=16
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ScreenInsets=Enum.ScreenInsets.None;gui.IgnoreGuiInset=true;gui.Enabled=false;gui.Parent=playerGui
	local host=Instance.new("Frame");host.Name="StageHost";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
	local done=Instance.new("TextButton");done.Name="Done";done.Size=UDim2.fromOffset(0,0);done.BackgroundTransparency=1;done.TextTransparency=1;done.Parent=gui
	local use=Instance.new("TextButton");use.Name="UseIt";use.Size=UDim2.fromOffset(0,0);use.BackgroundTransparency=1;use.TextTransparency=1;use.Parent=gui
	done.Text=UICopy.get("names.reveal.done");use.Text=UICopy.get("names.reveal.use")
	local self=setmetatable({gui=gui,host=host,doneSource=done,useSource=use,audio=audio,open=false},Reveal)
	-- Beta (17) U2: the reveal's buttons need a free PC cursor (ModalCursor's registry).
	self.unregisterCursor=require(script.Parent.ModalCursor).register(self,function()return self.open==true end)
	return self
end
function Reveal:isOpen()return self.open end
-- receipt: the server's Names Egg receipt {piece, cost, mode}. info: {odds(), pity(), again()}.
-- callbacks: use(receipt), done(receipt).
function Reveal:show(receipt,info,callbacks)
	local handover=self.againPressed==true;self.againPressed=nil
	self:close("replaced",handover)
	info=info or {}
	self.receipt,self.callbacks=receipt,callbacks or {}
	local words=Reveal.copy(receipt)
	local tier="Neutral"
	self.tier=tier
	self.open=true;self.gui.Enabled=true
	local reduced=Kit.reduced()
	self.scene=nameScene(receipt)
	self.age=0;self.reducedStart=reduced
	self.timing=Rarity.timing(tier,Reveal.Kind,reduced)
	self.cue=Rarity.new(Reveal.Kind,receipt,self.timing.ready,reduced,Asmr.layer(Reveal.Kind,receipt,reduced))
	self.owner={}
	local stage=Stage.show(self.host,{scene=self.scene,kind=Reveal.Kind,tier=tier,result=receipt,cover=false,fullScreen=true,zIndex=20,lid=not handover,
		reduced=function()return self.reducedStart end,owns=function()return self.open end,
		name=function()return words.name end,effect=function()return words.effect end,
		description=function()return info.pill or ""end,
		sticker=function()return words.sticker end,
		stoneColors=function()return {Reveal.Pink,Kit.Color.lemon,Kit.Color.cream}end,
		odds=info.odds,wonId=receipt.piece,pity=info.pity,again=info.again and function()
			local state=info.again()
			if not state then return nil end
			local act=state.act
			return {text=state.text,enabled=state.enabled,reason=state.reason,pending=state.pending or self.againPressed==true,act=function()
				self.againPressed=true
				local ok=act()==true
				if not ok then self.againPressed=nil end
				return ok
			end}
		end or nil,
		actions=function()return {{source=self.doneSource,primary=false,act=function()self:choose("done")end},
			{source=self.useSource,primary=true,act=function()self:choose("use")end}}end,
		onSkip=function()self:skip()end,onClose=function()self:choose("done")end})
	self.stage=stage
	stage.root:SetAttribute("NamePiece",receipt.piece)
	self.clock=RunService.RenderStepped:Connect(function(dt)self:step(dt)end)
	self:step(0)
	ContextActionService:BindActionAtPriority("EggDropNameReveal",function(_,state,input)
		if not self.open or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
		if state==Enum.UserInputState.Begin then
			local k=input.KeyCode
			local settled=self.stage and self.stage:inputOpen()
			if k==Enum.KeyCode.ButtonA or k==Enum.KeyCode.Return or k==Enum.KeyCode.KeypadEnter or k==Enum.KeyCode.Space then
				if settled then self:choose("use")else self:skip()end
			elseif k==Enum.KeyCode.ButtonB or k==Enum.KeyCode.Escape or k==Enum.KeyCode.Backspace then
				if settled then self:choose("done")else self:skip()end
			elseif k==Enum.KeyCode.ButtonX or k==Enum.KeyCode.X or k==Enum.KeyCode.H then
				if settled and self.stage then self.stage:hatchAnother()end
			end
		end
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value+835,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.ButtonX,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.Space,Enum.KeyCode.Escape,Enum.KeyCode.Backspace,Enum.KeyCode.X,Enum.KeyCode.H)
	return true
end
function Reveal:step(dt)
	local stage=self.stage;if not stage or stage.destroyed or not self.open then return end
	if not stage:holdsClock()then self.age+=math.clamp(dt,0,.1)end
	local T=self.timing
	if self.age>T.duration then self.age=T.duration end
	local sample=Pose.sample(self.age,Reveal.Kind,self.reducedStart,self.tier)
	self.scene:render(sample)
	stage:updateExternal(self.age,sample)
	if self.cue and self.audio then
		for _,event in ipairs(self.cue:due(self.age,true,true))do
			pcall(function()self.audio:play(event.cue,event.speed,event.gain,self.owner)end)
			Asmr.fire(event)
		end
	end
end
function Reveal:skip()
	if not self.stage or self.stage:inputOpen()or not self.stage.skippable then return false end
	if self.cue then self.cue:cancel()end
	if self.audio and self.audio.stopOwner then pcall(function()self.audio:stopOwner(self.owner)end)end
	self.age=self.timing.duration
	return true
end
function Reveal:choose(choice)
	if not self.open then return end
	local receipt,callbacks=self.receipt,self.callbacks
	self.againPressed=nil
	self:close(choice)
	local callback=callbacks and callbacks[choice]
	if callback then callback(receipt)end
end
function Reveal:close(reason,handover)
	if not self.open then return false end
	self.open=false
	ContextActionService:UnbindAction("EggDropNameReveal")
	if self.clock then self.clock:Disconnect();self.clock=nil end
	if self.cue then self.cue:cancel()end
	if self.audio and self.audio.stopOwner and self.owner then pcall(function()self.audio:stopOwner(self.owner)end)end
	local stage,scene=self.stage,self.scene
	self.stage,self.scene=nil,nil
	if stage then
		local function gone()if scene then scene:destroy()end end
		if not stage:dismiss(gone,{handover=handover,pending=function()return self.againPressed==true end})then stage:destroy();gone()end
	end
	self.gui.Enabled=false
	local _=reason
	return true
end
function Reveal:destroy()self:close("destroy");if self.unregisterCursor then self.unregisterCursor()end;self.gui:Destroy()end
return Reveal
