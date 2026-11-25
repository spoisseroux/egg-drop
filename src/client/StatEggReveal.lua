-- v2 Stat Eggs: the hatch, on the v2 Pop-Out Stage (V2-HATCH-REDESIGN-2026-11-19 2.4, H4).
-- The egg (a cream shell with a belt of six stat stones) shakes, cracks and bursts in the
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
local Stage=require(script.Parent.HatchItemStage)
local Pose=require(script.Parent.HatchDisplayPose)
local Rarity=require(script.Parent.HatchRarityCue)
local Reveal={}
Reveal.__index=Reveal
-- The rarity sting per size (existing hatch cues).
Reveal.Sting={nibble="rarity_common",snack="rarity_uncommon",feast="rarity_rare"}

-- Pure: the reveal's words for a receipt.
-- Spencer 2026-11-20: snacks go to the account pouch and Feed now feeds the pet that is out,
-- so the card names no pet at all (no "For Bear" line, the button stays "Feed now").
function Reveal.copy(receipt)
	local size=K.size(receipt.size)or K.Sizes.nibble
	local statName=UICopy.get("stats.name."..tostring(receipt.stat))
	return{kind=UICopy.get("hatch.stat.reveal.kind"),
		name=UICopy.get("hatch.stat.reveal.name",{stat=statName,size=UICopy.get("stats.snacks.size."..size.id)}),
		boost=UICopy.get("hatch.stat.reveal.boost",{mult=size.mult,count=size.xp})}
end
function Reveal.tier(receipt)return Rarity.tier("stat",receipt)end
-- The six stat colours in StatCatalog.Order (the roulette and the Feast's orbit stones).
function Reveal.stoneRow()
	local out={}
	for _,id in ipairs(Stats.Order)do table.insert(out,Stats.ById[id].color)end
	return out
end

-- Round 3 (Spencer: "I want the 3D model like the other eggs, but more exciting"): the scene is
-- the same HatchDisplayScene every item hatch uses (kind "stat": the Stat Egg's own shell from
-- EggModels.Types.stat, split halves, one camera and light), with the 3D Stat Snack as its hero
-- (HatchDisplayItem). It lives in a hidden home frame until the stage borrows it.
local function snackScene(receipt,reduced,home)
	local Scene=require(script.Parent.HatchDisplayScene)
	local owned=home==nil
	if owned then
		home=Instance.new("Frame");home.Name="StatSceneHome";home.BackgroundTransparency=1;home.Size=UDim2.fromOffset(844,390);home.Visible=false
	end
	local scene=Scene.new(home,{kind="stat",result=receipt,reduced=reduced==true})
	local destroy=scene.destroy
	function scene:destroy()destroy(self);if owned then home:Destroy()end end
	return scene
end
-- Pure (Fable brief 1.3): the snack's pop after the burst, `u` seconds past it: 0.55 at +0.12,
-- Back Out to the tier's peak at +0.34, settled to 1 by +0.50; and one extra yaw turn over 0.60 s
-- (Expo Out) from +0.12. Returns heroScale, extra yaw (radians); nil before +0.12.
Reveal.Peak={Common=1.08,Uncommon=1.12,Rare=1.18,Neutral=1.08}
function Reveal.pop(u,tier)
	if u<.12 then return nil,0 end
	local peak=Reveal.Peak[tier]or 1.08
	local scale
	if u<.34 then
		local x=(u-.12)/.22;local c=2.2;local v=x-1
		scale=.55+(peak-.55)*(1+(c+1)*v*v*v+c*v*v)
	elseif u<.50 then
		local x=(u-.34)/.16;scale=peak+(1-peak)*x*x*(3-2*x)
	else scale=1 end
	local turn=math.clamp((u-.12)/.60,0,1)
	return scale,math.pi*2*(if turn>=1 then 1 else 1-2^(-10*turn))
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
	local self=setmetatable({gui=gui,host=host,keepSource=keep,feedSource=feed,audio=audio,open=false,seen=false},Reveal)
	-- Beta (17) U2: the reveal's buttons need a free PC cursor (ModalCursor's registry).
	self.unregisterCursor=require(script.Parent.ModalCursor).register(self,function()return self.open==true end)
	return self
end
function Reveal:isOpen()return self.open end
function Reveal:reduced()return Kit.reduced()end
-- receipt: the server's buy receipt {snackId, stat, size, free}. info: {pill, canFeed,
-- odds(), pity(), again()}. callbacks: feed(receipt), keep(receipt).
function Reveal:show(receipt,info,callbacks)
	local handover=self.againPressed==true;self.againPressed=nil
	self:close("replaced",handover)
	info=info or {}
	self.receipt,self.callbacks,self.info=receipt,callbacks or {},info
	local words=Reveal.copy(receipt)
	local tier=Reveal.tier(receipt)
	self.tier=tier
	self.feedSource.Interactable=info.canFeed~=false
	self.open=true;self.gui.Enabled=true
	local reduced=self:reduced()
	local fresh=true
	self.home=self.home or(function()
		local f=Instance.new("Frame");f.Name="StatSceneHome";f.BackgroundTransparency=1;f.Size=UDim2.fromScale(1,1);f.Visible=false;f.Parent=self.gui
		return f
	end)()
	self.scene=snackScene(receipt,reduced,self.home)
	self.age=0;self.reducedStart=reduced
	local T=Rarity.timing(tier,"stat",reduced)
	self.timing=T
	self.cue=Rarity.new("stat",receipt,T.ready,reduced)
	self.owner={}
	local stat=Stats.ById[receipt.stat]
	local stage=Stage.show(self.host,{scene=self.scene,kind="stat",tier=tier,result=receipt,cover=false,fullScreen=true,zIndex=20,lid=not handover,
		instant=not fresh,reduced=function()return self.reducedStart end,owns=function()return self.open end,
		name=function()return words.name end,effect=function()return words.boost end,
		description=function()return info.pill or ""end,
		sticker=function()return Stage.bannerText(tier,"stat")end,
		stoneColors=function()return {stat and stat.color or Color3.new(1,1,1)}end,
		-- Round 3 (Fable brief 1.3): the won stat's colour from the burst; the six stones before it.
		accent=function()return stat and stat.color or nil end,
		orbitColors=function()return Reveal.stoneRow()end,roulette=function()return Reveal.stoneRow()end,
		ready=function()return self.scene~=nil and self.scene.ready==true end,
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
	-- The clock (and its sounds) wait for the 3D egg (Hatch another and Reduced Motion have no
	-- lid to hold it); the scene times itself out at 3.5 s and then shows its settled frame.
	local ready=self.scene.ready==true
	if ready and not stage:holdsClock()then self.age+=math.clamp(dt,0,.1)end
	local reduced=self.reducedStart
	local T=self.timing
	if self.age>T.duration then self.age=T.duration end
	local sample=Pose.sample(self.age,"stat",reduced,self.tier)
	if not reduced then
		local scale,turn=Reveal.pop(self.age-T.burst,self.tier)
		if scale then sample.heroScale=scale;sample.toyYaw=(sample.toyYaw or 0)+turn end
	end
	self.scene:render(sample)
	stage:updateExternal(self.age,sample)
	if not ready then return end
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
function Reveal:destroy()self:close("destroy");if self.unregisterCursor then self.unregisterCursor()end;self.gui:Destroy()end
return Reveal
