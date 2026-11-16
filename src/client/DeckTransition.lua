local TweenService = game:GetService("TweenService")
local Art = require(script.Parent.DeckArt)
local Policy = require(script.Parent.PresentationPolicy)

local Transition = {}
Transition.__index = Transition

local function tween(object, seconds, properties, style, direction)
	local motion = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.InOut), properties)
	motion:Play()
	return motion
end

-- QA v735 D2: opening and closing the deck is one motion.
-- Open: one full-screen shade fades in over the garden (Cover), the swap happens under
-- it, then the shade lifts while the handheld rises from below and settles (Rise) with
-- its screen dark; the power-on then plays to its last frame, every time (taps do not
-- skip it), and the lit screen fades in over Lit seconds.
-- Close: the screen shutters off (Shutter), the handheld sinks as the shade fades in
-- (Sink), the swap happens under it and the shade lifts off the garden (Lift).
Transition.Timing = { Cover = .26, Rise = .46, Uncover = .30, Lit = .22, Shutter = .16, Sink = .30, Lift = .32, Drop = .42 }
-- Studio only: PlayerGui attribute "DeckHandoffSlow" (a number) stretches every phase so a
-- capture can land inside one. It never applies outside Studio.
local function timing()
	local T = Transition.Timing
	if not game:GetService("RunService"):IsStudio() then return T end
	local player = game:GetService("Players").LocalPlayer
	local slow = player and player:FindFirstChild("PlayerGui") and player.PlayerGui:GetAttribute("DeckHandoffSlow")
	if type(slow) ~= "number" or slow <= 1 then return T end
	local out = {}
	for key, value in pairs(T) do out[key] = if key == "Drop" then value else value * slow end
	return out
end

function Transition.new(gui, tray, audio, reduceEffects)
	local shade = Instance.new("Frame")
	shade.Name = "DeckHandoff"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Art.Backdrop
	shade.BorderSizePixel = 0
	shade.BackgroundTransparency = 1
	shade.Active = true
	shade.Visible = false
	shade.ZIndex = 50
	shade.Parent = gui

	local aperture = Art.frame(shade, "LCDAperture", Art.Ink, UDim2.fromOffset(0, 0), UDim2.fromOffset(0, 0), 51)
	aperture.BackgroundTransparency = 1
	aperture.ClipsDescendants = true
	local top = Art.frame(aperture, "LCDTop", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0), 51)
	local bottom = Art.frame(aperture, "LCDBottom", Art.Ink, UDim2.fromScale(0, 1), UDim2.fromScale(1, 0), 51)
	bottom.AnchorPoint = Vector2.new(0, 1)
	local scan = Art.frame(aperture, "Scan", Art.Cyan, UDim2.new(0, 0, 0.5, -1), UDim2.new(1, 0, 0, 2), 52)
	scan.Visible = false

	-- The shutters cover the whole lit screen when the deck has one (the boot host sits
	-- on it), else the board tray; they follow it while the handheld moves.
	local screen
	local function align()
		local target = if screen and screen.Parent and screen.AbsoluteSize.X > 0 then screen else tray
		local origin = target.AbsolutePosition - shade.AbsolutePosition
		aperture.Position = UDim2.fromOffset(origin.X, origin.Y)
		aperture.Size = UDim2.fromOffset(target.AbsoluteSize.X, target.AbsoluteSize.Y)
	end
	tray:GetPropertyChangedSignal("AbsolutePosition"):Connect(align)
	tray:GetPropertyChangedSignal("AbsoluteSize"):Connect(align)
	shade:GetPropertyChangedSignal("AbsolutePosition"):Connect(align)
	align()

	local logo=Art.frame(aperture,"BootLogo",Art.Ink,UDim2.fromScale(0,0),UDim2.fromScale(1,1),54)
	logo.BackgroundTransparency=1;logo.Visible=false
 local wordmark=Art.wordmark(logo,55);local mark=wordmark.root
 local function markLayout()
  local w,h=wordmark:layout(math.max(1,aperture.AbsoluteSize.X-16),math.max(1,aperture.AbsoluteSize.Y*.5),30)
  mark.Position=UDim2.new(.5,-w/2,.5,-h/2)
 end
 aperture:GetPropertyChangedSignal("AbsoluteSize"):Connect(markLayout);markLayout()
 Art.watchTextPreference(shade,function()return logo.Visible end,markLayout)
	local dots={}
	for index=1,7 do
		local dot=Art.frame(logo,"SeedDot",Art.Leaf,UDim2.new(.5,(index%3-1)*5-2,.5,-28+math.floor(index/3)*5),UDim2.fromOffset(4,4),55)
		Art.corner(dot,2);dots[index]=dot
	end
	local self = setmetatable({ shade=shade,aperture=aperture,top=top,bottom=bottom,scan=scan,logo=logo,mark=mark,dots=dots,audio=audio,reduce=reduceEffects,boots=0,motions={} },Transition)
	-- The handheld (board, shell and HUD share the Backdrop's position; the deck host mirrors it).
	self.device = gui:FindFirstChild("Backdrop")
	self.align = function()
		local boot = self.deckBoot
		if boot and boot.host ~= screen then
			screen = boot.host
			screen:GetPropertyChangedSignal("AbsolutePosition"):Connect(align)
			screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(align)
		end
		align()
	end
	self.policy = Policy.new(function()
		return if self.presentationState then self.presentationState() else { mode = "Board", reduced = self.reduce() }
	end)
	return self
end

-- Data readiness covers even a reduced-motion handoff; animation policy cannot
-- reveal an old generation while independent replication events are settling.
function Transition:setContentCover(covered)
 if not self.contentCover then
  local node=Instance.new("Frame");node.Name="BoardContentBarrier";node.BackgroundColor3=Art.Backdrop;node.BorderSizePixel=0
  node.Size=UDim2.fromScale(1,1);node.ZIndex=60;node.Active=true;node.Visible=false;node.Parent=self.shade.Parent;self.contentCover=node
 end
 self.contentCover.Visible=covered==true
end

function Transition:begin(toDeck, route)
	self:hide()
	return self.policy:begin(toDeck, route)
end

function Transition:owns(token)
	return self.policy:owns(token)
end

function Transition:motion(token, object, seconds, properties, companion)
	if not self:owns(token) then return false end
	local motion = tween(object, seconds, properties)
	self.motions[motion] = true
	local paired=if companion then tween(companion,seconds,properties) else nil
	if paired then self.motions[paired]=true end
	motion.Completed:Wait()
	self.motions[motion] = nil
	if paired then self.motions[paired]=nil end
	return self:owns(token)
end

-- The handheld's rest position is kept while a rise or a sink moves it; Transition:hide
-- (every cancel path) puts it back.
function Transition:moveDevice(seconds, offset, style, direction)
	local device = self.device
	if not device then return nil end
	self.home = self.home or device.Position
	local motion = tween(device, seconds, { Position = self.home + UDim2.fromOffset(0, offset) }, style, direction)
	self.motions[motion] = true
	self.deviceMotion = motion
	return motion
end
function Transition:restDevice()
	-- Stop the move first: a tween on its last step would write its goal after this.
	local motion = self.deviceMotion
	if motion then self.deviceMotion = nil; self.motions[motion] = nil; motion:Cancel() end
	if self.home and self.device then self.device.Position = self.home end
	self.home = nil
end
function Transition:dropDistance()
	return if self.device then math.floor(self.device.AbsoluteSize.Y * Transition.Timing.Drop) else 0
end

function Transition:cover(fromDeck, token)
	if not self:owns(token) then return false end
	local T = timing()
	self.shade.BackgroundTransparency = 1
	self.shade.Visible = true
	self.aperture.Visible = fromDeck
	if fromDeck then
		self.align()
		self.top.Size, self.bottom.Size = UDim2.fromScale(1, 0), UDim2.fromScale(1, 0)
		-- Both shutters share the same ownership token and cancellation set.
		if not self:motion(token,self.top,T.Shutter,{Size=UDim2.fromScale(1,.5)},self.bottom) then return false end
		-- The closed shutters hand over to the deck's own dark screen, which is part of the
		-- handheld and goes under the shade with it (the shutters sit on top of the shade
		-- and would be left floating on it).
		local boot = self.deckBoot
		if boot and boot.host.Parent and self.deckVisible and self.deckVisible() then
			boot:hold(Art.Ink);self.heldBoot=boot
			self.aperture.Visible = false
		else
			self.scan.Visible = true
		end
		-- The handheld sinks while the shade closes over it.
		self:moveDevice(T.Sink, self:dropDistance(), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if not self:motion(token,self.shade,T.Sink,{BackgroundTransparency=0}) then return false end
		self.sunk = true -- stays down under the opaque shade until the swap hides it (Transition:reveal / hide)
	elseif not self:motion(token,self.shade,T.Cover,{BackgroundTransparency=0}) then return false end
	self.aperture.Visible, self.scan.Visible = false, false
	return true
end

function Transition:reveal(toDeck, token)
	if not self:owns(token) then return false end
	-- A sink ended under the opaque shade; the swap has hidden the deck, so it can rest again.
	if self.sunk then
		self.sunk = nil; self:restDevice()
		if self.heldBoot then self.heldBoot:release();self.heldBoot=nil end
	end
	if toDeck and self.deckBoot and self.deckBoot.host.Parent and self.deckVisible and self.deckVisible() then
		-- QA v735 D2: the handheld comes up from under the shade with its screen dark,
		-- settles, then powers on.
		self.boots += 1; self.shade:SetAttribute("Boots",self.boots)
		local T = timing()
		local boot=self.deckBoot
		boot:hold();self.heldBoot=boot
		if self.device then
			self.home = self.home or self.device.Position
			self.device.Position = self.home + UDim2.fromOffset(0, self:dropDistance())
		end
		local rise = self:moveDevice(T.Rise, 0, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		if not self:motion(token,self.shade,T.Uncover,{BackgroundTransparency=1}) then return false end
		self.shade.Visible=false
		if rise and rise.PlaybackState==Enum.PlaybackState.Playing then rise.Completed:Wait() end
		if rise then self.motions[rise]=nil end
		if not self:owns(token) then return false end
		self:restDevice()
		if self.onSettled then self.onSettled() end
		-- The power-on always reaches its last frame: no input skips it, and only leaving
		-- the deck (or a newer transition) ends it early.
		local function onDeck() return self.policy.active==token and self.policy.read().mode=="Board" end
		self.heldBoot=nil
		boot:play({owns=onDeck,noSkip=true,linger=true})
		self.activeBoot=boot
		boot:wait()
		self.activeBoot=nil
		-- The last frame stays up until the fade takes over (no lit frame in between).
		boot:fade(T.Lit,onDeck)
		if not onDeck() or not self:owns(token) then return false end
	elseif toDeck then
		self.boots += 1; self.shade:SetAttribute("Boots",self.boots)
		self.logo.Visible=true;self.mark.GroupTransparency=1

		for index,dot in ipairs(self.dots) do
			dot.BackgroundTransparency=1
			task.delay(index*.025,function()
				if self:owns(token) and self.logo.Visible then dot.BackgroundTransparency=0 end
			end)
		end
		if self.audio and self.audio.boot and self:owns(token) then
			self.audio:boot(function() return self:owns(token) end)
		end
		self.top.Size,self.bottom.Size=UDim2.fromScale(1,.5),UDim2.fromScale(1,.5)
		self.aperture.Visible,self.scan.Visible=true,true
		if not self:motion(token,self.shade,.10,{BackgroundTransparency=1}) then return false end
		self.scan.Visible=false
		if not self:motion(token,self.mark,.12,{GroupTransparency=0}) then return false end
		task.wait(.20)
		if not self:owns(token) then return false end
		self.logo.Visible=false
		if not self:motion(token,self.top,.16,{Size=UDim2.fromScale(1,0)},self.bottom) then return false end
	else
		if not self:motion(token,self.shade,timing().Lift,{BackgroundTransparency=1}) then return false end
	end
	self:hide(token)
	return true
end

-- Reduced Motion has no presentation token, so it gets the still logo:
-- frame 21 for 0.4 s with deck_boot at 0 ms, on a real arrival only.
function Transition:stillBoot(route)
	local boot=self.deckBoot
	if not boot or not boot.host.Parent or not (self.deckVisible and self.deckVisible()) then return false end
	local state=table.clone(self.presentationState and self.presentationState() or {mode="Board",reduced=self.reduce()})
	if state.reduced~=true then return false end
	state.reduced=false
	if not Policy.canBoot(state,route) then return false end
	self.boots += 1; self.shade:SetAttribute("Boots",self.boots)
	boot:play({reduced=true})
	boot:wait()
	return true
end

-- Re-evaluate synchronously when any overlay, round state or motion preference changes.
function Transition:refresh()
	local token=self.policy.active
	-- A power-on in progress is only cut by leaving the deck (QA v735 D2).
	if token and self.activeBoot and self.policy.read().mode=="Board" then return end
	if token and not self:owns(token) then self:hide(token) end
end

function Transition:hide(token)
	if token and self.policy.active ~= token then return false end
	self.policy:cancel()
	for motion in pairs(self.motions) do motion:Cancel() end
	table.clear(self.motions)
	if self.audio and self.audio.cancelBoot then self.audio:cancelBoot() end
	if self.activeBoot then self.activeBoot:finish(false);self.activeBoot=nil end
	if self.heldBoot then self.heldBoot:release();self.heldBoot=nil end
	self.sunk = nil
	self:restDevice()
	self.logo.Visible=false
	self.shade.Visible=false
	self.aperture.Visible,self.scan.Visible=false,false
	return true
end

return Transition
