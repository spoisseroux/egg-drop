-- v2 Stat Eggs: the hatch, on the v2 Pop-Out Stage (V2-HATCH-REDESIGN-2026-11-19 2.4, H4).
-- The egg (a cream shell with a belt of six rune stones) shakes, cracks and bursts in the
-- tier's well (Nibble Common, Snack Uncommon, Feast Rare: a Feast is a jackpot), and the 3D
-- Stat Snack pops with its stat's stones as the confetti. The result card names the snack,
-- its boost, the odds and the Feast promise in the open, and ends on two buttons: Feed now
-- (primary; A / Enter) and Keep (B / Esc). Every hatched snack is already in the pouch, so
-- Keep only closes; Feed now leaves for pet focus with that snack picked (the eating plays
-- there, never here). Hatch another buys the next Stat Egg while the shell stays up.
-- Own ScreenGui above the menus, its own ContextAction and its own hatch clock.
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local K=require(Shared.StatEggCatalog)
local Stats=require(Shared.StatCatalog)
local UICopy=require(Shared.UICopy)
local Kit=require(script.Parent.DeckKit)
local SnackModel=require(script.Parent.SnackModel)
local Stage=require(script.Parent.HatchItemStage)
local Pose=require(script.Parent.HatchDisplayPose)
local Rarity=require(script.Parent.HatchRarityCue)
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
function Reveal.tier(receipt)return Rarity.tier("stat",receipt)end

-- A scene for the stage: the 2D Stat Egg, then the 3D snack. The stage borrows it like the
-- hatch's native scene (borrow / release / layout / setSpin) and this host renders it from
-- HatchDisplayPose on the stage's clock.
local function snackScene(receipt)
	local root=Instance.new("Frame");root.Name="StatSnackScene";root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1)
	local a=Stage.Art.statEgg
	local egg=Instance.new("ImageLabel");egg.Name="StatEgg";egg.BackgroundTransparency=1;egg.Image=Stage.Art[a[1]]
	egg.ImageRectOffset=Vector2.new(a[2],a[3]);egg.ImageRectSize=Vector2.new(a[4],a[5]);egg.AnchorPoint=Vector2.new(.5,1)
	egg.Position=UDim2.fromScale(.5,.8);egg.Size=UDim2.fromScale(.46,.575);egg.ZIndex=root.ZIndex;egg.Parent=root
	-- The crack: a zigzag of four ink strokes drawn left to right as it grows.
	local cracks={}
	for i=1,4 do
		local bar=Instance.new("Frame");bar.Name="Crack"..i;bar.BackgroundColor3=Color3.fromHex("#15143A");bar.BorderSizePixel=0
		bar.AnchorPoint=Vector2.new(.5,.5);bar.Position=UDim2.fromScale(.2+(i-.5)*.15,.42);bar.Size=UDim2.fromScale(.17,.022)
		bar.Rotation=if i%2==0 then -32 else 32;bar.Visible=false;bar.Parent=egg;cracks[i]=bar
	end
	-- At 80% of the seat, so a three-layer Feast stands inside the well.
	local holder=Instance.new("Frame");holder.Name="SnackHolder";holder.BackgroundTransparency=1;holder.AnchorPoint=Vector2.new(.5,.5)
	holder.Position=UDim2.fromScale(.5,.5);holder.Size=UDim2.fromScale(.8,.8);holder.Parent=root
	local scale=Instance.new("UIScale");scale.Parent=holder
	local preview=SnackModel.viewport(holder,receipt.size,receipt.stat,{Size=UDim2.fromScale(1,1),Position=UDim2.fromScale(0,-.04),ImageTransparency=1})
	local scene={ready=true,root=root,preview=preview}
	function scene:borrow(seat)root.Parent=seat;return root end
	function scene:release(token)if token==root then root.Parent=nil end end
	function scene:setBare()end
	function scene:setVeil()end
	function scene:layout()end
	function scene:setSpin(radians)self.spin=radians;return radians~=0 end
	function scene:render(sample)
		local shell=sample.shellAlpha or 0
		egg.Visible=shell>.01
		egg.ImageTransparency=1-shell
		egg.Rotation=math.deg(sample.rock or 0)
		egg.Size=UDim2.fromScale(.46*(sample.eggSX or 1)*(.4+.6*(sample.shellScale or 1)),.575*(sample.eggSY or 1)*(.4+.6*(sample.shellScale or 1)))
		egg.Position=UDim2.fromScale(.5,.8-.05*(sample.eggLift or 0))
		for i,bar in ipairs(cracks)do bar.Visible=(sample.crack or 0)>=(i-1)/4+.01 end
		preview.viewport.ImageTransparency=1-(sample.heroAlpha or 0)
		scale.Scale=math.max(.01,sample.heroScale or 1)
	end
	function scene:destroy()self.destroyed=true;preview.destroy();root:Destroy()end
	return scene
end

Reveal.scene=snackScene -- (scripts/RevealCaptureFixture.lua draws the Stat Egg with it)
function Reveal.new(playerGui,audio)
	local gui=Instance.new("ScreenGui");gui.Name="EggDropStatReveal";gui.ResetOnSpawn=false;gui.DisplayOrder=16
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ScreenInsets=Enum.ScreenInsets.None;gui.IgnoreGuiInset=true;gui.Enabled=false;gui.Parent=playerGui
	local host=Instance.new("Frame");host.Name="StageHost";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
	-- The stage mirrors two hidden receipt buttons (their text, visibility and enabled state).
	local keep=Instance.new("TextButton");keep.Name="Keep";keep.Visible=true;keep.Size=UDim2.fromOffset(0,0);keep.BackgroundTransparency=1;keep.TextTransparency=1;keep.Parent=gui
	local feed=Instance.new("TextButton");feed.Name="FeedNow";feed.Visible=true;feed.Size=UDim2.fromOffset(0,0);feed.BackgroundTransparency=1;feed.TextTransparency=1;feed.Parent=gui
	keep.Text=UICopy.get("hatch.stat.reveal.keep");feed.Text=UICopy.get("hatch.stat.reveal.feed")
	return setmetatable({gui=gui,host=host,keepSource=keep,feedSource=feed,audio=audio,open=false,seen=false},Reveal)
end
function Reveal:isOpen()return self.open end
function Reveal:reduced()return Kit.reduced()end
-- receipt: the server's buy receipt {snackId, stat, size, free}. info: {petName, pill, canFeed,
-- odds(), pity(), again()}. callbacks: feed(receipt), keep(receipt).
function Reveal:show(receipt,info,callbacks)
	local handover=self.againPressed==true;self.againPressed=nil
	self:close("replaced",handover)
	info=info or {}
	self.receipt,self.callbacks,self.info=receipt,callbacks or {},info
	local words=Reveal.copy(receipt,info.petName)
	local tier=Reveal.tier(receipt)
	self.tier=tier
	self.feedSource.Interactable=info.canFeed~=false
	self.open=true;self.gui.Enabled=true
	local reduced=self:reduced()
	local fresh=true
	self.scene=snackScene(receipt)
	self.age=0;self.reducedStart=reduced
	local T=Rarity.timing(tier,"stat",reduced)
	self.timing=T
	self.cue=Rarity.new("stat",receipt,T.ready,reduced)
	self.owner={}
	local stat=Stats.ById[receipt.stat]
	local stage=Stage.show(self.host,{scene=self.scene,kind="stat",tier=tier,result=receipt,cover=false,zIndex=20,lid=not handover,
		instant=not fresh,reduced=function()return self.reducedStart end,owns=function()return self.open end,
		name=function()return words.name end,effect=function()return words.boost end,
		description=function()return words.forPet..(if info.pill and info.pill~=""then "  ·  "..info.pill else "")end,
		sticker=function()return Stage.bannerText(tier,"stat")end,
		stoneColors=function()return {stat and stat.color or Color3.new(1,1,1)}end,
		odds=info.odds,wonId=receipt.size,pity=info.pity,again=info.again and function()
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
		actions=function()return {{source=self.keepSource,primary=false,act=function()self:choose("keep")end},
			{source=self.feedSource,primary=true,act=function()self:choose("feed")end}}end,
		onSkip=function()self:skip()end,onClose=function()self:choose("keep")end})
	self.stage=stage
	self.card=stage.root
	stage.root:SetAttribute("SnackId",receipt.snackId);stage.root:SetAttribute("Stat",receipt.stat);stage.root:SetAttribute("Size",receipt.size)
	self.clock=RunService.RenderStepped:Connect(function(dt)self:step(dt)end)
	self:step(0)
	ContextActionService:BindActionAtPriority("EggDropStatReveal",function(_,state,input)
		if not self.open or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
		if state==Enum.UserInputState.Begin then
			local k=input.KeyCode
			local settled=self.stage and self.stage:inputOpen()
			if k==Enum.KeyCode.ButtonA or k==Enum.KeyCode.Return or k==Enum.KeyCode.KeypadEnter or k==Enum.KeyCode.Space then
				if settled then self:choose("feed")else self:skip()end
			elseif k==Enum.KeyCode.ButtonB or k==Enum.KeyCode.Escape or k==Enum.KeyCode.Backspace then
				if settled then self:choose("keep")else self:skip()end
			elseif k==Enum.KeyCode.ButtonX or k==Enum.KeyCode.X or k==Enum.KeyCode.H then
				if settled and self.stage then self.stage:hatchAnother()end
			end
		end
		return Enum.ContextActionResult.Sink
	end,false,Enum.ContextActionPriority.High.Value+830,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonB,Enum.KeyCode.ButtonX,Enum.KeyCode.Return,Enum.KeyCode.KeypadEnter,
		Enum.KeyCode.Space,Enum.KeyCode.Escape,Enum.KeyCode.Backspace,Enum.KeyCode.X,Enum.KeyCode.H)
	return true
end
-- The hatch clock (one clock, sampled every frame; the stage's lid holds it at zero).
function Reveal:step(dt)
	local stage=self.stage;if not stage or stage.destroyed or not self.open then return end
	if not stage:holdsClock()then self.age+=math.clamp(dt,0,.1)end
	local reduced=self.reducedStart
	local T=self.timing
	if self.age>T.duration then self.age=T.duration end
	local sample=Pose.sample(self.age,"stat",reduced,self.tier)
	self.scene:render(sample)
	if self.scene.preview and not reduced and(self.scene.spin or 0)~=0 then self.scene.preview.step(dt)end
	stage:updateExternal(self.age,sample)
	if self.cue and self.audio then
		for _,event in ipairs(self.cue:due(self.age,true,true))do
			pcall(function()self.audio:play(event.cue,event.speed,event.gain,self.owner)end)
		end
	end
end
-- A skip lands on the settled card (the first Stat Egg plays in full: the stage decides).
function Reveal:skip()
	if not self.stage or self.stage:inputOpen()or not self.stage.skippable then return false end
	if self.cue then self.cue:cancel()end
	if self.audio and self.audio.stopOwner then pcall(function()self.audio:stopOwner(self.owner)end)end
	self.age=self.timing.duration
	return true
end
function Reveal:choose(choice)
	if not self.open then return end
	if choice=="feed"and not self.feedSource.Interactable then return end
	local receipt,callbacks=self.receipt,self.callbacks
	self.againPressed=nil
	self:close(choice)
	local callback=callbacks and callbacks[choice]
	if callback then callback(receipt)end
end
-- Close: the stage leaves by its iris (or, for Hatch another, stays up until the next egg's
-- stage takes over); this gui is free at once.
function Reveal:close(reason,handover)
	if not self.open then return false end
	self.open=false
	ContextActionService:UnbindAction("EggDropStatReveal")
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
function Reveal:destroy()self:close("destroy");self.gui:Destroy()end
return Reveal
