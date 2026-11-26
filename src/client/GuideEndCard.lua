-- Onboarding v2 step 5's end (Onboard "guide", ONBOARDING-V2.md): after the third prompt, a centre card for 2.5 s, a
-- tap closes it: "You're all set!" over three icons (Deck, Ball, Eggs). The exhale, no confetti. The ball and the egg
-- machine are then found through Things to do, as today. Presentation only.
--   GuideEndCard.show(playerGui, {copy, play(cue, speed, gain), reduced()}) -> card ({close()})
local V2=require(script.Parent.OnboardV2)
local Card={};Card.__index=Card
Card.Icons=table.freeze({{icon="deck",label="onb2.guide.deckIcon"},{icon="ball",label="onb2.guide.ballIcon"},{icon="egg",label="onb2.guide.eggsIcon"}})

local function node(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent;return n
end
function Card.show(parent,deps)
	deps=deps or {}
	local copy=function(key)local ok,t=pcall(deps.copy,key);return if ok and type(t)=="string"then t else ""end
	local gui=node("ScreenGui",parent,{Name="EggDropAllSet",ResetOnSpawn=false,DisplayOrder=14,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
		ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets})
	local self=setmetatable({gui=gui,open=true},Card)
	local hit=node("TextButton",gui,{Name="TapToClose",Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),AutoButtonColor=false,ZIndex=1})
	local card=node("Frame",gui,{Name="Card",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(300,176),
		BackgroundColor3=V2.Guide.fill,BorderSizePixel=0,ZIndex=2})
	node("UICorner",card,{CornerRadius=UDim.new(0,22)})
	node("UIStroke",card,{Color=V2.Guide.ink,Thickness=2.5})
	node("UISizeConstraint",card,{MaxSize=Vector2.new(360,200)})
	self.scale=node("UIScale",card,{Scale=1})
	node("TextLabel",card,{Name="Title",BackgroundTransparency=1,Position=UDim2.fromOffset(0,16),Size=UDim2.new(1,0,0,40),
		Font=Enum.Font.BuilderSansExtraBold,TextSize=30,TextColor3=V2.Guide.ink,Text=copy("onb2.guide.allSet"),ZIndex=3})
	local ok,Bubble=pcall(require,script.Parent.NeedBubble)
	for i,entry in ipairs(Card.Icons)do
		local x=(i-2)*92
		local disc=node("Frame",card,{Name="Icon"..i,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,x,0,70),Size=UDim2.fromOffset(60,60),
			BackgroundColor3=Color3.fromHex("#F3F6FB"),BorderSizePixel=0,ZIndex=3})
		node("UICorner",disc,{CornerRadius=UDim.new(.5,0)})
		node("UIStroke",disc,{Color=V2.Guide.ink,Thickness=2})
		local id=ok and Bubble.IconIds[entry.icon]
		if id then
			node("ImageLabel",disc,{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.72,.72),
				Image="rbxassetid://"..id,ZIndex=4})
		else
			node("TextLabel",disc,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),TextScaled=true,Text=ok and Bubble.Glyph[entry.icon]or "?",ZIndex=4})
		end
		node("TextLabel",card,{Name="Label"..i,BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,x,0,134),
			Size=UDim2.fromOffset(84,22),Font=Enum.Font.BuilderSansBold,TextSize=16,TextColor3=V2.Guide.ink,Text=copy(entry.label),ZIndex=3})
	end
	hit.Activated:Connect(function()self:close()end)
	card.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self:close()end
	end)
	if deps.play then pcall(function()
		local Asmr=require(script.Parent.HatchAsmr)
		local l=Asmr.Layers.exhale
		deps.play(l.cue.."_"..Asmr.pick("exhale",math.random()),1,l.gain*2)
	end)end
	if not(deps.reduced and deps.reduced())then
		self.scale.Scale=.85
		game:GetService("TweenService"):Create(self.scale,TweenInfo.new(.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	end
	task.delay(V2.Guide.endCard,function()self:close()end)
	return self
end
function Card:close()
	if not self.open then return end
	self.open=false
	self.gui:Destroy()
end
return Card
