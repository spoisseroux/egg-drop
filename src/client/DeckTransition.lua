local TweenService = game:GetService("TweenService")
local Art = require(script.Parent.DeckArt)
local Policy = require(script.Parent.PresentationPolicy)

local Transition = {}
Transition.__index = Transition

local function tween(object, seconds, properties)
	local motion = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), properties)
	motion:Play()
	return motion
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

	local function align()
		local origin = tray.AbsolutePosition - shade.AbsolutePosition
		aperture.Position = UDim2.fromOffset(origin.X, origin.Y)
		aperture.Size = UDim2.fromOffset(tray.AbsoluteSize.X, tray.AbsoluteSize.Y)
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
	self.policy = Policy.new(function()
		return if self.presentationState then self.presentationState() else { mode = "Board", reduced = self.reduce() }
	end)
	return self
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

function Transition:cover(fromDeck, token)
	if not self:owns(token) then return false end
	self.shade.BackgroundTransparency = 1
	self.shade.Visible = true
	self.aperture.Visible = fromDeck
	if fromDeck then
		self.top.Size, self.bottom.Size = UDim2.fromScale(1, 0), UDim2.fromScale(1, 0)
		-- Both shutters share the same ownership token and cancellation set.
		if not self:motion(token,self.top,.14,{Size=UDim2.fromScale(1,.5)},self.bottom) then return false end
		self.scan.Visible = true
	end
	if not self:motion(token,self.shade,if fromDeck then .10 else .16,{BackgroundTransparency=0}) then return false end
	self.aperture.Visible, self.scan.Visible = false, false
	return true
end

function Transition:reveal(toDeck, token)
	if not self:owns(token) then return false end
	if toDeck then
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
		if not self:motion(token,self.shade,.28,{BackgroundTransparency=1}) then return false end
	end
	self:hide(token)
	return true
end

-- Re-evaluate synchronously when any overlay, round state or motion preference changes.
function Transition:refresh()
	local token=self.policy.active
	if token and not self:owns(token) then self:hide(token) end
end

function Transition:hide(token)
	if token and self.policy.active ~= token then return false end
	self.policy:cancel()
	for motion in pairs(self.motions) do motion:Cancel() end
	table.clear(self.motions)
	if self.audio and self.audio.cancelBoot then self.audio:cancelBoot() end
	self.logo.Visible=false
	self.shade.Visible=false
	self.aperture.Visible,self.scan.Visible=false,false
	return true
end

return Transition
