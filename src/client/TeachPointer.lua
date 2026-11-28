-- The lesson pointer (artifacts/qa-2026-11-27-beta40/ONBOARDING-P2-BRIEF.md section 2; Onboard "teach", and the free
-- egg in the Hatch eggs screen under Onboard "gifts"). One pointer at a time, on the real button. Beta 42 notes 1 and 4
-- (artifacts/qa-2026-11-27-beta42/POINTER-STORK-BRIEF.md section 1, Fable):
--   ring   concentric with the target: a true circle on round or square-ish targets (w/h <= 1.35, diameter max + 12),
--          on wider ones a ring 6 px out whose corner is the target's own corner + 6 (no UICorner: 14). Two strokes, no
--          fill: white 7 px at .35 under gift pink 4 px. It breathes in px (pad 6 to 12 and back every 1.2 s), never
--          by scale; Reduced Motion: still at pad 6.
--   hand   a white mitten with a pink cuff (56 x 64, GUI primitives, one ink outline under the fills and a soft shadow
--          3 px below on screen), rotating about its fingertip: from below-right (150 degrees) by default, from
--          above-left (-30) when the target sits within 80 px of the screen bottom (the Menu button), the label 48 px
--          higher then. The beat (1.2 s): hover 10 px back with a 2 px bob, dip to touch, press (x .92, the ring's top
--          stroke flashes white), lift with a 3 px overshoot, rest. A tap ripple (a pink circle, 28 to 76 px) at the
--          touch.
--   glide  a new target in the same ScreenGui: the tip glides .38 s (Quint Out) on an arc lifted 24 px, the hand x1.08
--          mid-flight; the old ring fades in .12 s, the new one pops at .26 (pad 20 to 6); the beat restarts at the dip,
--          so it taps on landing. Another ScreenGui: fade out .12 s, fade in .18 s there. First show: slides in 40 px
--          along its axis and fades in .2 s.
--   label  a white pill, ink, ExtraBold 16, above the target (below when there is no room); keyboard adds the key, the
--          gamepad its glyph. opts.noLabel: ring and hand only.
-- It never takes a tap or dims the garden: every piece is inactive and sits in the target's own ScreenGui, so it shares
-- its coordinates. Reduced Motion: the ring and the label, no hand, no glide. Gamepad: no hand; focus goes to each new
-- target once. Pure parts first (spec-checked: TeachLessons.spec), then the drawn pointer.
--   local p = Pointer.new({reduced = fn, input = fn -> "Touch" | "Keyboard" | "Gamepad"})
--   p:show(target, words, {key = "M", glyph = "Y", noLabel = bool});  p:hide();  p:step(dt) every frame;  p.target
local Pointer={};Pointer.__index=Pointer
Pointer.Pink=Color3.fromHex("#FF6FA8")
Pointer.Ink=Color3.fromHex("#1B2A4A")
Pointer.White=Color3.fromHex("#FFFFFF")
Pointer.Period=1.2   -- s, one beat (and one ring breath)
Pointer.Pad=6        -- px between the target and its ring at rest
Pointer.PadPulse=12  -- px at the top of the breath
Pointer.Round=1.35   -- w/h at or under this: a circle
Pointer.NoCorner=8   -- a target with no UICorner: ring corner 8 + pad (14 at rest)
Pointer.Hand=40      -- px the label keeps clear of the target for the hand (label rule, unchanged)
Pointer.LabelH=30    -- px
Pointer.Gap=10       -- px between the target and the label
Pointer.Back=10      -- px the hover sits back from the tip point
Pointer.Bob=2        -- px
Pointer.Press=.92
Pointer.Overshoot=3.4 -- Back Out constant: a 3 px overshoot on the 10 px lift
Pointer.Bottom=80    -- px: a target this close to the screen bottom is pointed at from above-left
Pointer.Lift=48      -- px the label rises when the hand comes from above
Pointer.Glide=.38
Pointer.GlideLift=24
Pointer.GlideScale=1.08
Pointer.RingOut=.12;Pointer.RingPopAt=.26;Pointer.RingPop=.18;Pointer.PopPad=20
Pointer.FadeOut=.12;Pointer.FadeIn=.18;Pointer.Enter=.2;Pointer.Slide=40
Pointer.Ripple=table.freeze({at=.70,seconds=.45,from=28,to=76,stroke=3,alpha=.1})
Pointer.Canvas=table.freeze({w=56,h=64})
Pointer.Small=500    -- px: a viewport under this tall draws the hand at .8
-- The mitten (POINTER-STORK-BRIEF 1b), rects x, y, w, h on the 56 x 64 canvas; fill order (later on top).
Pointer.Mitten=table.freeze({
	table.freeze({name="Palm",rect={8,8,40,30},corner=14,fill="white",ink=true}),
	table.freeze({name="Thumb",rect={41,16,13,20},corner=6.5,fill="white",ink=true,rotation=25}),
	table.freeze({name="KnuckleL",rect={9,31,13,13},corner=6.5,fill="white",ink=true}),
	table.freeze({name="KnuckleR",rect={34,31,13,13},corner=6.5,fill="white",ink=true}),
	table.freeze({name="Finger",rect={20,28,16,36},corner=8,fill="white",ink=true}),
	table.freeze({name="Cuff",rect={13,0,30,12},corner=6,fill="pink",ink=true,top=1}),
	table.freeze({name="CuffTrim",rect={13,9,30,3},corner=1.5,fill="trim",top=2}),
	table.freeze({name="PalmPad",rect={23,15,10,10},corner=5,fill="pad",top=2}),
})
Pointer.Fills=table.freeze({white=Color3.fromHex("#FFFFFF"),pink=Color3.fromHex("#FF6FA8"),trim=Color3.fromHex("#E0528C"),pad=Color3.fromHex("#FFB3CF")})
Pointer.InkGrow=2.5
Pointer.ShadowAlpha=.75
Pointer.ShadowDrop=3

-- ── Pure ────────────────────────────────────────────────────────────────────────────────────────────────────────────
-- Is a w x h target round (a circle ring)?
function Pointer.round(w,h)return h>0 and w/h<=Pointer.Round end
-- A UICorner's radius in screen px: scale resolves against min(w, h); offset carries the target's UIScale.
function Pointer.cornerPx(scale,offset,w,h,uiScale)
	return(scale or 0)*math.min(w,h)+(offset or 0)*(uiScale or 1)
end
-- The ring for a w x h target at `pad` (default Pad): {circle, w, h, corner} (corner in px).
function Pointer.shape(w,h,corner,pad)
	pad=pad or Pointer.Pad
	if Pointer.round(w,h)then
		local d=math.max(w,h)+pad*2
		return {circle=true,w=d,h=d,corner=d/2}
	end
	local rw,rh=w+pad*2,h+pad*2
	return {circle=false,w=rw,h=rh,corner=math.min((corner or Pointer.NoCorner)+pad,rh/2)}
end
-- The ring's pad at `t` s: a smooth 6 to 12 px and back every Period; 6 under Reduced Motion.
function Pointer.pad(t,reduced)
	if reduced then return Pointer.Pad end
	local u=(t%Pointer.Period)/Pointer.Period
	return Pointer.Pad+(Pointer.PadPulse-Pointer.Pad)*(1-math.cos(u*2*math.pi))/2
end
-- Where the fingertip goes for a target rect {x, y, w, h} on a screen {w, h}. -> x, y, rotation (the hand's Holder),
-- side ("belowRight" | "aboveLeft"). Round: the centre + (.2s, .2s); wide: (x + .68w, y + .6h), clear of the title and
-- the FREE badge. Near the bottom: from above-left, the tip mirrored about the centre.
function Pointer.tip(rect,screen)
	local cx,cy=rect.x+rect.w/2,rect.y+rect.h/2
	local dx,dy
	if Pointer.round(rect.w,rect.h)then
		local s=math.min(rect.w,rect.h);dx,dy=.2*s,.2*s
	else
		dx,dy=.18*rect.w,.1*rect.h
	end
	local h=type(screen)=="table"and screen.h or nil
	if h and h-(rect.y+rect.h)<=Pointer.Bottom then return cx-dx,cy-dy,-30,"aboveLeft"end
	return cx+dx,cy+dy,150,"belowRight"
end
-- The hand's direction away from the tip (screen px per px) for a Holder rotation in degrees.
function Pointer.axis(rotation)
	local r=math.rad(rotation)
	return math.sin(r),-math.cos(r)
end
local function backOut(p)
	local c=Pointer.Overshoot;local v=p-1
	return 1+(c+1)*v*v*v+c*v*v
end
-- The beat at `t` s (period 1.2): {back (px behind the tip), scale, flash (the ring's top stroke white), ripple (0..1
-- through the tap ripple, or nil)}. Reduced Motion: still at hover, no press, no ripple.
function Pointer.beat(t,reduced)
	local B=Pointer.Back
	local out={back=B,scale=1,flash=false,ripple=nil}
	if reduced then return out end
	local u=t%Pointer.Period
	if u<.55 then out.back=B+Pointer.Bob*math.sin(2*math.pi*u/.55)
	elseif u<.70 then local q=(u-.55)/.15;out.back=B*(1-q*q)
	elseif u<.80 then out.back=0;out.scale=Pointer.Press;out.flash=u<.78
	elseif u<1.0 then out.back=B*backOut((u-.80)/.20)end
	local r=u-Pointer.Ripple.at
	if r>=0 and r<Pointer.Ripple.seconds then out.ripple=r/Pointer.Ripple.seconds end
	return out
end
-- The tap ripple at `u` (0..1): diameter px and stroke transparency (Quad Out).
function Pointer.ripple(u)
	local e=1-(1-u)*(1-u)
	local R=Pointer.Ripple
	return R.from+(R.to-R.from)*e,R.alpha+(1-R.alpha)*e
end
-- The glide `age` s after it started, from (fx, fy) to (tx, ty): -> x, y, hand scale, eased progress, done.
function Pointer.glide(age,fx,fy,tx,ty)
	local p=math.clamp(age/Pointer.Glide,0,1)
	local e=1-(1-p)^5
	local lift=Pointer.GlideLift*4*e*(1-e)
	return fx+(tx-fx)*e,fy+(ty-fy)*e-lift,1+(Pointer.GlideScale-1)*math.sin(math.pi*e),e,p>=1
end
-- The rings while the target changes, `age` s in: the old ring's alpha, the new ring's alpha and pad.
function Pointer.ringSwap(age)
	local old=1-math.clamp(age/Pointer.RingOut,0,1)
	local q=math.clamp((age-Pointer.RingPopAt)/Pointer.RingPop,0,1)
	local e=1-(1-q)^3
	return old,if age<Pointer.RingPopAt then 0 else e,Pointer.PopPad+(Pointer.Pad-Pointer.PopPad)*e
end
-- The label's words: the lesson's words, then the key (keyboard) or the glyph (gamepad), never on touch.
function Pointer.words(text,kind,key,glyph)
	text=text or ""
	if kind=="Keyboard"and type(key)=="string"and key~=""then return text.."  ["..key.."]"end
	if kind=="Gamepad"and type(glyph)=="string"and glyph~=""then return text.."  ("..glyph..")"end
	return text
end
-- Where the label goes for a target rect {x, y, w, h} on a screen {w, h}: centred over it, or under it when the top has
-- no room, kept on the screen; `lift` px higher (the hand from above). -> x, y (the label's top left), side
function Pointer.labelSpot(rect,screen,width,height,lift)
	height=height or Pointer.LabelH
	local above=rect.y-Pointer.Gap-height-Pointer.Hand*.6-(lift or 0)
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
-- The target's corner in screen px: its own UICorner, else one on a child covering it (Kit.button's Fill); nil: none.
local function cornerOf(target)
	local size=target.AbsoluteSize
	local corner=target:FindFirstChildOfClass("UICorner")
	if not corner then
		for _,child in ipairs(target:GetChildren())do
			if child:IsA("GuiObject")and child.AbsoluteSize.X>=size.X*.9 and child.AbsoluteSize.Y>=size.Y*.8 then
				corner=child:FindFirstChildOfClass("UICorner")
				if not corner then
					for _,inner in ipairs(child:GetChildren())do
						if inner:IsA("GuiObject")and inner.AbsoluteSize.X>=size.X*.9 and inner.AbsoluteSize.Y>=size.Y*.8 then corner=inner:FindFirstChildOfClass("UICorner")end
						if corner then break end
					end
				end
			end
			if corner then break end
		end
	end
	if not corner then return nil end
	local s=target.Size
	local uiScale=if s.X.Scale==0 and s.X.Offset>0 then size.X/s.X.Offset else 1
	return Pointer.cornerPx(corner.CornerRadius.Scale,corner.CornerRadius.Offset,size.X,size.Y,uiScale)
end

-- ── The drawn pointer ─────────────────────────────────────────────────────────────────────────────────────────────
local function make(class,parent,props)
	local n=Instance.new(class)
	for k,v in pairs(props or {})do n[k]=v end
	n.Parent=parent
	return n
end
function Pointer.new(options)
	return setmetatable({options=options or {},time=0,clock=0,target=nil},Pointer)
end
function Pointer:reduced()return self.options.reduced~=nil and self.options.reduced()==true end
function Pointer:input()return self.options.input and self.options.input()or "Touch"end
-- One drawing in one ScreenGui: v = {root, gui, under, over, overStroke, ripple, hand, ..., fades}.
local function build(gui)
	local root=make("Frame",gui,{Name="EggDropTeachPointer",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Active=false,ZIndex=990,Selectable=false})
	local v={root=root,gui=gui,fades={ring={},hand={},label={}},alpha={ring=1,hand=1,label=1}}
	local function fade(group,object,property)table.insert(v.fades[group],{object,property,object[property]})end
	local function ring(name,color,thickness,transparency,z)
		local f=make("Frame",root,{Name=name,BackgroundTransparency=1,Active=false,ZIndex=z,AnchorPoint=Vector2.new(.5,.5)})
		local c=make("UICorner",f,{CornerRadius=UDim.new(.5,0)})
		local s=make("UIStroke",f,{Color=color,Thickness=thickness,Transparency=transparency,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
		fade("ring",s,"Transparency")
		return f,c,s
	end
	v.under,v.underCorner=ring("RingUnder",Pointer.White,7,.35,991)
	v.over,v.overCorner,v.overStroke=ring("Ring",Pointer.Pink,4,0,992)
	v.ripple=make("Frame",root,{Name="Ripple",BackgroundTransparency=1,Active=false,ZIndex=993,AnchorPoint=Vector2.new(.5,.5),Visible=false})
	make("UICorner",v.ripple,{CornerRadius=UDim.new(.5,0)})
	v.rippleStroke=make("UIStroke",v.ripple,{Color=Pointer.Pink,Thickness=Pointer.Ripple.stroke,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	-- the mitten: a Holder twice the canvas, the fingertip at its centre, so rotating it turns the hand about the tip
	local C=Pointer.Canvas
	local hand=make("Frame",root,{Name="Hand",BackgroundTransparency=1,Active=false,ZIndex=994,AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(C.w*2,C.h*2)})
	v.handScale=make("UIScale",hand,{Scale=1})
	local canvas=make("Frame",hand,{Name="Mitten",BackgroundTransparency=1,Active=false,ZIndex=994,Position=UDim2.fromOffset(C.w/2,0),Size=UDim2.fromOffset(C.w,C.h)})
	local shadow=make("Frame",canvas,{Name="Shadow",BackgroundTransparency=1,Active=false,ZIndex=995,Size=UDim2.fromScale(1,1)})
	local g=Pointer.InkGrow
	local function part(parent,name,p,color,transparency,z,grow)
		local r=p.rect
		local f=make("Frame",parent,{Name=name,BorderSizePixel=0,Active=false,ZIndex=z,BackgroundColor3=color,BackgroundTransparency=transparency,
			AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(r[1]+r[3]/2,r[2]+r[4]/2),Size=UDim2.fromOffset(r[3]+grow*2,r[4]+grow*2),Rotation=p.rotation or 0})
		make("UICorner",f,{CornerRadius=UDim.new(0,p.corner+grow)})
		fade("hand",f,"BackgroundTransparency")
		return f
	end
	for _,p in ipairs(Pointer.Mitten)do
		if p.ink then
			part(shadow,p.name.."Shadow",p,Pointer.Ink,Pointer.ShadowAlpha,995,g)
			part(canvas,p.name.."Ink",p,Pointer.Ink,0,996,g)
		end
	end
	for _,p in ipairs(Pointer.Mitten)do
		local f=part(canvas,p.name,p,Pointer.Fills[p.fill],0,997+(p.top or 0),0)
		if p.fill=="white"then
			make("UIGradient",f,{Rotation=90,Color=ColorSequence.new(Color3.fromHex("#FFFFFF"),Color3.fromHex("#E6ECF7"))})
		end
	end
	v.hand,v.shadow=hand,shadow
	local label=make("TextLabel",root,{Name="Label",BackgroundColor3=Pointer.White,Active=false,ZIndex=1000,AutomaticSize=Enum.AutomaticSize.X,
		Size=UDim2.fromOffset(0,Pointer.LabelH),Font=Enum.Font.BuilderSansExtraBold,TextSize=16,TextColor3=Pointer.Ink,Text=""})
	make("UICorner",label,{CornerRadius=UDim.new(.5,0)})
	local stroke=make("UIStroke",label,{Color=Pointer.Ink,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
	make("UIPadding",label,{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
	fade("label",label,"BackgroundTransparency");fade("label",label,"TextTransparency");fade("label",stroke,"Transparency")
	v.label=label
	return v
end
-- Every piece of a group at `alpha` (1 its own look, 0 gone); written only when it changes.
local function setAlpha(v,group,alpha)
	alpha=math.clamp(alpha,0,1)
	if v.alpha[group]==alpha then return end
	v.alpha[group]=alpha
	for _,f in ipairs(v.fades[group])do f[1][f[2]]=1-(1-f[3])*alpha end
end
function Pointer:build(gui)
	if self.v and self.v.root.Parent==gui then return end
	if self.v then self.v.root:Destroy()end
	self.v=build(gui)
	self.root=self.v.root -- (older callers read pointer.root)
end
-- A drawing in another ScreenGui fades out, then goes.
function Pointer:retire(v)
	if not v then return end
	if self.leaving then self.leaving.v.root:Destroy()end
	self.leaving={v=v,at=self.clock}
end
function Pointer:stepLeaving()
	local l=self.leaving
	if not l then return end
	local a=1-math.clamp((self.clock-l.at)/Pointer.FadeOut,0,1)
	if a<=0 or not l.v.root.Parent then l.v.root:Destroy();self.leaving=nil;return end
	setAlpha(l.v,"ring",a);setAlpha(l.v,"hand",a);setAlpha(l.v,"label",a)
end
-- Point at `target` with `words` (already localised). The same target and words: nothing new (the beat goes on). A new
-- target while shown: the glide (same ScreenGui) or a cross-fade (another one).
function Pointer:show(target,words,opts)
	opts=opts or {}
	if not Pointer.live(target)then self:hide();return false end
	local gui=screenGuiOf(target)
	if not gui then return false end
	if self.target~=target then
		local shown=self.target~=nil and self.v~=nil and self.v.root.Visible and self.tipX~=nil
		if shown and self.v.gui==gui and not self:reduced()then
			self.glideState={at=self.clock,fx=self.tipX,fy=self.tipY,frot=self.rot or 150}
			self.swap={at=self.clock,ring=self.ringNow}
			self.enter=nil
		elseif shown and self.v.gui~=gui then
			self:retire(self.v);self.v=nil;self.root=nil
			self.glideState,self.swap=nil,nil
			self.enter={at=self.clock+Pointer.FadeOut,seconds=Pointer.FadeIn}
		else
			self.glideState,self.swap=nil,nil
			self.enter={at=self.clock,seconds=Pointer.Enter,slide=true}
		end
		self.time=0;self.ringTime=0
		self.focused=false
	end
	self.target,self.words,self.opts=target,words,opts
	self:build(gui)
	self.v.root.Visible=true
	self:step(0)
	return true
end
function Pointer:hide()
	self.target=nil
	self.glideState,self.swap,self.tipX,self.tipY=nil,nil,nil,nil
	if self.v then self.v.root.Visible=false end
	-- Code review (beta 43): a drawing fading out of another ScreenGui goes now; left set, step() (which returns early with
	-- no target) never moves its fade on and it freezes half-visible
	if self.leaving then
		local root=self.leaving.v and self.leaving.v.root
		self.leaving=nil
		if root then pcall(root.Destroy,root)end
	end
end
function Pointer:destroy()
	self.target=nil
	if self.v then self.v.root:Destroy();self.v=nil;self.root=nil end
	if self.leaving then self.leaving.v.root:Destroy();self.leaving=nil end
end
local function placeRing(v,cx,cy,s)
	local size=UDim2.fromOffset(s.w,s.h)
	local pos=UDim2.fromOffset(cx,cy)
	local corner=if s.circle then UDim.new(.5,0)else UDim.new(0,s.corner)
	v.under.Position,v.under.Size,v.underCorner.CornerRadius=pos,size,corner
	v.over.Position,v.over.Size,v.overCorner.CornerRadius=pos,size,corner
end
function Pointer:step(dt)
	dt=dt or 0
	self.clock+=dt
	self:stepLeaving()
	local v=self.v
	if not self.target or not v then return end
	local target=self.target
	if not Pointer.live(target)then v.root.Visible=false;return end
	v.root.Visible=true
	local reduced=self:reduced()
	local kind=self:input()
	local origin=v.root.AbsolutePosition
	local at,size=target.AbsolutePosition-origin,target.AbsoluteSize
	local rect={x=at.X,y=at.Y,w=size.X,h=size.Y}
	local screenSize=v.root.AbsoluteSize
	local screen={w=screenSize.X,h=screenSize.Y}
	local tx,ty,trot,side=Pointer.tip(rect,screen)
	-- the entrance (first show: slide in and fade; another ScreenGui: fade in after the old one's fade out)
	local enter,slide=1,0
	local en=self.enter
	if en then
		local age=self.clock-en.at
		if reduced then enter=if age>=0 then 1 else 0
		else
			local p=math.clamp(age/en.seconds,0,1)
			local e=1-(1-p)*(1-p)
			enter=e
			if en.slide then slide=Pointer.Slide*(1-e)end
		end
		if age>=en.seconds then self.enter=nil end
	end
	-- the glide (the beat waits), else the beat
	local x,y,rot,glideScale=tx,ty,trot,1
	local g=self.glideState
	local b
	if g then
		local e,done
		x,y,glideScale,e,done=Pointer.glide(self.clock-g.at,g.fx,g.fy,tx,ty)
		rot=g.frot+(trot-g.frot)*e
		b={back=Pointer.Back,scale=1,flash=false}
		if done then self.glideState=nil;self.time=.55 end
	else
		self.time+=dt
		b=Pointer.beat(self.time,reduced)
	end
	self.tipX,self.tipY,self.rot=x,y,rot
	-- the ring: concentric, breathing; while the target changes the old one fades and the new one pops
	local corner=cornerOf(target)
	local cx,cy=rect.x+rect.w/2,rect.y+rect.h/2
	-- (its breath keeps its own phase: from pad 6 at a show or the end of a pop, so it never jumps)
	local pad=Pointer.pad(self.ringTime or 0,reduced)
	local ringAlpha=enter
	local sw=self.swap
	if sw then
		local age=self.clock-sw.at
		local old,new,popPad=Pointer.ringSwap(age)
		if old>0 and sw.ring then
			local r=sw.ring
			placeRing(v,r.x,r.y,r.shape);ringAlpha=old
		else
			placeRing(v,cx,cy,Pointer.shape(rect.w,rect.h,corner,popPad));ringAlpha=new
		end
		if age>=Pointer.RingPopAt+Pointer.RingPop then self.swap=nil;self.ringTime=0 end
	else
		self.ringTime=(self.ringTime or 0)+dt
		placeRing(v,cx,cy,Pointer.shape(rect.w,rect.h,corner,pad))
	end
	self.ringNow={x=cx,y=cy,shape=Pointer.shape(rect.w,rect.h,corner,Pointer.Pad)}
	setAlpha(v,"ring",ringAlpha)
	v.overStroke.Color=if b.flash then Pointer.White else Pointer.Pink
	-- the hand: along its own axis from the tip; Reduced Motion and the gamepad: none
	local handOn=not reduced and kind~="Gamepad"
	v.hand.Visible=handOn
	if handOn then
		local ax,ay=Pointer.axis(rot)
		local back=b.back+slide
		v.hand.Position=UDim2.fromOffset(x+ax*back,y+ay*back)
		v.hand.Rotation=rot
		local base=if screen.h<Pointer.Small then .8 else 1
		v.handScale.Scale=base*b.scale*glideScale
		-- the shadow falls down the screen whatever the hand's turn
		local r=math.rad(rot)
		v.shadow.Position=UDim2.fromOffset(Pointer.ShadowDrop*math.sin(r),Pointer.ShadowDrop*math.cos(r))
		setAlpha(v,"hand",enter)
	end
	-- the tap ripple at the touch
	if handOn and b.ripple then
		local d,alpha=Pointer.ripple(b.ripple)
		v.ripple.Visible=true
		v.ripple.Position=UDim2.fromOffset(x,y);v.ripple.Size=UDim2.fromOffset(d,d)
		v.rippleStroke.Transparency=1-(1-alpha)*enter
	else v.ripple.Visible=false end
	-- the label
	local o=self.opts or {}
	v.label.Text=Pointer.words(self.words,kind,o.key,o.glyph)
	v.label.Visible=o.noLabel~=true
	local width=math.max(60,v.label.AbsoluteSize.X)
	local lx,ly=Pointer.labelSpot(rect,screen,width,nil,if handOn and side=="aboveLeft"then Pointer.Lift else 0)
	v.label.Position=UDim2.fromOffset(lx,ly)
	setAlpha(v,"label",enter)
	-- Gamepad: focus lands on each new lit target once (A acts, B backs out as the screen already does)
	if kind=="Gamepad"and not self.focused and target.Selectable then
		self.focused=true
		pcall(function()game:GetService("GuiService").SelectedObject=target end)
	end
end
return Pointer
