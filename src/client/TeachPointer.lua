-- The lesson pointer (artifacts/qa-2026-11-27-beta40/ONBOARDING-P2-BRIEF.md section 2; Onboard "teach", and the free
-- egg's tile in the Hatch eggs screen under Onboard "gifts"). One pointer at a time, on the real button:
--   ring   3 px gift pink round the target, pulsing 1.0 to 1.12 every 1.2 s
--   hand   a 40 px white hand (ink edge) over the target, dipping 6 px toward it on the same beat
--   label  a white pill, ink, ExtraBold 16, above the target (below when there is no room); keyboard adds the key, the
--          gamepad its glyph
-- It never takes a tap or dims the garden: every piece is inactive and sits in the target's own ScreenGui, so it shares
-- its coordinates. Reduced Motion: a still ring and the label, no hand. Gamepad: no hand; focus goes to the target once.
-- Pure parts first (spec-checked: TeachLessons.spec), then the drawn pointer.
--   local p = Pointer.new({reduced = fn, input = fn -> "Touch" | "Keyboard" | "Gamepad"})
--   p:show(target, words, {key = "M", glyph = "Y"});  p:hide();  p:step(dt) every frame;  p.target
local Pointer={};Pointer.__index=Pointer
Pointer.Pink=Color3.fromHex("#FF6FA8")
Pointer.Ink=Color3.fromHex("#1B2A4A")
Pointer.White=Color3.fromHex("#FFFFFF")
Pointer.Period=1.2   -- s, one pulse
Pointer.Grow=.12     -- the ring's pulse, 1.0 to 1.12
Pointer.Dip=6        -- px the hand dips toward the target
Pointer.Hand=40      -- px
Pointer.Ring=3       -- px
Pointer.Pad=4        -- px between the target and its ring
Pointer.LabelH=30    -- px
Pointer.Gap=10       -- px between the target and the label

-- ── Pure ────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- The ring's scale at `t` s (a smooth 1.0 to 1.12 and back every Period); 1 under Reduced Motion.
function Pointer.pulse(t,reduced)
	if reduced then return 1 end
	local u=(t%Pointer.Period)/Pointer.Period
	return 1+Pointer.Grow*(1-math.cos(u*2*math.pi))/2
end
-- The hand's dip toward the target in px at `t` s (0 at rest, Dip at the bottom of the beat).
function Pointer.dip(t,reduced)
	if reduced then return 0 end
	local u=(t%Pointer.Period)/Pointer.Period
	return Pointer.Dip*(1-math.cos(u*2*math.pi))/2
end
-- The label's words: the lesson's words, then the key (keyboard) or the glyph (gamepad), never on touch.
function Pointer.words(text,kind,key,glyph)
	text=text or ""
	if kind=="Keyboard"and type(key)=="string"and key~=""then return text.."  ["..key.."]"end
	if kind=="Gamepad"and type(glyph)=="string"and glyph~=""then return text.."  ("..glyph..")"end
	return text
end
-- Where the label goes for a target rect {x, y, w, h} on a screen {w, h}: centred over it, or under it when the top has
-- no room, kept on the screen. -> x, y (the label's top left), side ("above" | "below")
function Pointer.labelSpot(rect,screen,width,height)
	height=height or Pointer.LabelH
	local above=rect.y-Pointer.Gap-height-Pointer.Hand*.6
	local side=if above>=4 then "above"else "below"
	local y=if side=="above"then above else rect.y+rect.h+Pointer.Gap
	local x=rect.x+rect.w/2-width/2
	x=math.clamp(x,4,math.max(4,(screen.w or 0)-width-4))
	y=math.clamp(y,4,math.max(4,(screen.h or 0)-height-4))
	return x,y,side
end
-- Is this target live (on screen, visible all the way up, inside a shown ScreenGui)?
function Pointer.live(target)
	if typeof(target)~="Instance"or not target:IsA("GuiObject")or not target.Parent then return false end
	local node=target
	while node do
		if node:IsA("GuiObject")and not node.Visible then return false end
		if node:IsA("LayerCollector")then return node.Enabled~=false end
		node=node.Parent
	end
	return false
end
local function screenGuiOf(target)
	local node=target
	while node and not node:IsA("LayerCollector")do node=node.Parent end
	return node
end

-- ── The drawn pointer ─────────────────────────────────────────────────────────────────────────────────────────────
local function make(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent
	return n
end
function Pointer.new(options)
	return setmetatable({options=options or {},time=0,target=nil},Pointer)
end
function Pointer:reduced()return self.options.reduced~=nil and self.options.reduced()==true end
function Pointer:input()return self.options.input and self.options.input()or "Touch"end
function Pointer:build(gui)
	if self.root and self.root.Parent==gui then return end
	if self.root then self.root:Destroy()end
	local root=make("Frame",gui,{Name="EggDropTeachPointer",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false,ZIndex=990,Selectable=false})
	local ring=make("Frame",root,{Name="Ring",BackgroundTransparency=1,Active=false,ZIndex=991,AnchorPoint=Vector2.new(.5,.5)})
	make("UICorner",ring,{CornerRadius=UDim.new(0,14)})
	make("UIStroke",ring,{Color=Pointer.Pink,Thickness=Pointer.Ring,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	local ringScale=make("UIScale",ring,{Scale=1})
	-- the hand: a palm and one finger pointing down, white with an ink edge
	local hand=make("Frame",root,{Name="Hand",BackgroundTransparency=1,Active=false,ZIndex=993,AnchorPoint=Vector2.new(.5,1),Size=UDim2.fromOffset(Pointer.Hand,Pointer.Hand)})
	local palm=make("Frame",hand,{Name="Palm",BackgroundColor3=Pointer.White,Active=false,ZIndex=993,Position=UDim2.fromOffset(6,0),Size=UDim2.fromOffset(28,22)})
	make("UICorner",palm,{CornerRadius=UDim.new(0,9)});make("UIStroke",palm,{Color=Pointer.Ink,Thickness=2})
	local finger=make("Frame",hand,{Name="Finger",BackgroundColor3=Pointer.White,Active=false,ZIndex=994,Position=UDim2.fromOffset(15,14),Size=UDim2.fromOffset(10,26)})
	make("UICorner",finger,{CornerRadius=UDim.new(.5,0)});make("UIStroke",finger,{Color=Pointer.Ink,Thickness=2})
	local label=make("TextLabel",root,{Name="Label",BackgroundColor3=Pointer.White,Active=false,ZIndex=995,AutomaticSize=Enum.AutomaticSize.X,
		Size=UDim2.fromOffset(0,Pointer.LabelH),Font=Enum.Font.BuilderSansExtraBold,TextSize=16,TextColor3=Pointer.Ink,Text=""})
	make("UICorner",label,{CornerRadius=UDim.new(.5,0)});make("UIStroke",label,{Color=Pointer.Ink,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	make("UIPadding",label,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
	self.root,self.ring,self.ringScale,self.hand,self.label=root,ring,ringScale,hand,label
end
-- Point at `target` with `words` (already localised). The same target and words: nothing new (the beat goes on).
function Pointer:show(target,words,opts)
	opts=opts or {}
	if not Pointer.live(target)then self:hide();return false end
	local gui=screenGuiOf(target)
	if not gui then return false end
	local fresh=self.target~=target
	self.target,self.words,self.opts=target,words,opts
	self:build(gui)
	if fresh then
		self.time=0
		self.focused=false
	end
	self.root.Visible=true
	self:step(0)
	return true
end
function Pointer:hide()
	self.target=nil
	if self.root then self.root.Visible=false end
end
function Pointer:destroy()
	self.target=nil
	if self.root then self.root:Destroy();self.root=nil end
end
function Pointer:step(dt)
	if not self.target or not self.root then return end
	self.time+=dt or 0
	local target=self.target
	if not Pointer.live(target)then self.root.Visible=false;return end
	self.root.Visible=true
	local origin=self.root.AbsolutePosition
	local at,size=target.AbsolutePosition-origin,target.AbsoluteSize
	local reduced=self:reduced()
	local kind=self:input()
	self.ring.Position=UDim2.fromOffset(at.X+size.X/2,at.Y+size.Y/2)
	self.ring.Size=UDim2.fromOffset(size.X+Pointer.Pad*2,size.Y+Pointer.Pad*2)
	self.ringScale.Scale=Pointer.pulse(self.time,reduced)
	local o=self.opts or {}
	self.label.Text=Pointer.words(self.words,kind,o.key,o.glyph)
	local width=math.max(60,self.label.AbsoluteSize.X)
	local screen=self.root.AbsoluteSize
	local x,y,side=Pointer.labelSpot({x=at.X,y=at.Y,w=size.X,h=size.Y},{w=screen.X,h=screen.Y},width)
	self.label.Position=UDim2.fromOffset(x,y)
	-- the hand over the target's centre (under it when the label went below), dipping toward it
	local handOn=not reduced and kind~="Gamepad"
	self.hand.Visible=handOn
	if handOn then
		local d=Pointer.dip(self.time,reduced)
		if side=="above"then
			self.hand.Rotation=0;self.hand.AnchorPoint=Vector2.new(.5,1)
			self.hand.Position=UDim2.fromOffset(at.X+size.X/2,at.Y+size.Y*.35+d)
		else
			self.hand.Rotation=180;self.hand.AnchorPoint=Vector2.new(.5,0)
			self.hand.Position=UDim2.fromOffset(at.X+size.X/2,at.Y+size.Y*.65-d)
		end
	end
	-- Gamepad: focus lands on the lit target once (A acts, B backs out as the screen already does)
	if kind=="Gamepad"and not self.focused and target.Selectable then
		self.focused=true
		pcall(function()game:GetService("GuiService").SelectedObject=target end)
	end
end
return Pointer
