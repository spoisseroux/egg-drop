local TweenService = game:GetService("TweenService")
local Art = require(script.Parent.DeckArt)

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
	local mark=Art.text(logo,"Name","POCKET\nDECK",UDim2.new(0,2,.5,0),UDim2.new(1,-4,0,34),Art.Silver,14)
	Art.fitText(mark,14,8,0,true)
	local dots={}
	for index=1,7 do
		local dot=Art.frame(logo,"SeedDot",Art.Leaf,UDim2.new(.5,(index%3-1)*5-2,.5,-28+math.floor(index/3)*5),UDim2.fromOffset(4,4),55)
		Art.corner(dot,2);dots[index]=dot
	end
	return setmetatable({ shade=shade,aperture=aperture,top=top,bottom=bottom,scan=scan,logo=logo,mark=mark,dots=dots,audio=audio,reduce=reduceEffects,epoch=0,boots=0 },Transition)
end

function Transition:cover(fromDeck)
	self.shade.BackgroundTransparency = 1
	self.shade.Visible = true
	self.aperture.Visible = fromDeck
	if fromDeck then
		self.top.Size, self.bottom.Size = UDim2.fromScale(1, 0), UDim2.fromScale(1, 0)
		tween(self.bottom, 0.14, { Size = UDim2.fromScale(1, 0.5) })
		tween(self.top, 0.14, { Size = UDim2.fromScale(1, 0.5) }).Completed:Wait()
		self.scan.Visible = true
	end
	tween(self.shade, if fromDeck then 0.10 else 0.16, { BackgroundTransparency = 0 }).Completed:Wait()
	self.aperture.Visible, self.scan.Visible = false, false
end

function Transition:reveal(toDeck)
	self.epoch+=1;local epoch=self.epoch
	if toDeck then
		self.boots+=1;self.shade:SetAttribute("Boots",self.boots)
		self.logo.Visible=true;self.mark.TextTransparency=1
		for index,dot in ipairs(self.dots)do dot.BackgroundTransparency=1;task.delay(index*.025,function()
			if self.epoch==epoch and self.logo.Visible then dot.BackgroundTransparency=0 end
		end)end
		if self.audio and self.audio.boot then self.audio:boot()end
		self.top.Size, self.bottom.Size = UDim2.fromScale(1, 0.5), UDim2.fromScale(1, 0.5)
		self.aperture.Visible, self.scan.Visible = true, true
		tween(self.shade, 0.10, { BackgroundTransparency = 1 }).Completed:Wait()
		self.scan.Visible = false
		tween(self.mark,.12,{TextTransparency=0})
		task.wait(.32)
		if self.epoch~=epoch then return end
		self.logo.Visible=false
		tween(self.bottom, 0.16, { Size = UDim2.fromScale(1, 0) })
		tween(self.top, 0.16, { Size = UDim2.fromScale(1, 0) }).Completed:Wait()
	else
		tween(self.shade, 0.28, { BackgroundTransparency = 1 }).Completed:Wait()
	end
	self:hide()
end

function Transition:hide()
	self.epoch+=1
	self.logo.Visible=false
	self.shade.Visible = false
	self.aperture.Visible, self.scan.Visible = false, false
end

return Transition
