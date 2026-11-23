-- Garden Dash sheets' stage (DASH-DECK-UI-LOOK U3 and U6): the player's pet in a little spotlight at the left of the
-- mode picker (running on the spot on a cream pedestal) and of the results (hopping on a podium step). A well with a
-- lemon glow, a soft white wedge of light and the pet in its own ViewportFrame (a clone, PetInspect's set-up), made
-- when the sheet opens and destroyed with it. No clone: the pet's portrait on the pedestal instead.
--   Stage.new(parent, rect, options) options: {kind = "pedestal" | "podium", pet (PetCatalog entry), appearance,
--     pedestal = {x, y, w, h} (on the stage), place (podium), z, frame = {height, hop, shift, clear} (pt; podium)}
-- FABLE-REVIEW-R1 4: the spotlight is one wedge image (DashIcons spotWedge; nothing until it is uploaded, never the
-- old stacked bars) and the glow under the pedestal the soft firefly dot, lemon.
--   stage:step(dt, reduced) once a frame while the sheet is open; stage:dropIn() the podium landing; stage:destroy()
local Shared=game:GetService("ReplicatedStorage").Shared
local TweenService=game:GetService("TweenService")
local Kit=require(script.Parent.DeckKit)
local Pose=require(script.Parent.DashPose)
local Icons=require(script.Parent.DashIcons)
local LifeArt=require(Shared.LifeArt)
local Stage={};Stage.__index=Stage
Stage.Cream=Color3.fromHex("#FFF4DC")
Stage.CreamLip=Color3.fromHex("#D6C196")
Stage.Lemon=Color3.fromHex("#FFE14D")
Stage.Ink=Color3.fromHex("#15143A")
Stage.Fov=30
Stage.Turn=math.rad(20) -- front three-quarter, 20 degrees right of head-on
Stage.Down=math.rad(10)
Stage.Fill=.6           -- the pet fills this share of the stage's width
Stage.Wedge=.9          -- FABLE-REVIEW-R1 4: the spotlight wedge image's transparency
Stage.WedgeBottom=.8    -- its bottom edge's share of the image width (the top edge is .18)
Stage.GlowSize=Vector2.new(190,40)
Stage.GlowTransparency=.55
Stage.Headroom=14       -- px kept clear over the pet's highest point (ears, horns, hats, a charm) at the top of a hop
Stage.Side=6            -- px kept clear at either side

local function node(class,parent,props)
	local item=Instance.new(class)
	for key,value in pairs(props)do item[key]=value end
	item.Parent=parent
	return item
end
local function round(parent,radius)return node("UICorner",parent,{CornerRadius=radius or UDim.new(.5,0)})end

-- Pure: where a world point lands in a w x h stage seen from `eye` looking at `look` (px from the top left).
function Stage.project(eye,look,point,w,h)
	local tanV=math.tan(math.rad(Stage.Fov)/2)
	local tanH=tanV*math.max(.2,w/math.max(1,h))
	local f=(look-eye).Unit
	local right=f:Cross(Vector3.new(0,1,0)).Unit
	local up=right:Cross(f)
	local rel=point-eye
	local depth=rel:Dot(f)
	return w/2+rel:Dot(right)/(depth*tanH)*(w/2),h/2-rel:Dot(up)/(depth*tanV)*(h/2)
end
-- Pure: the camera for a pet whose bounding box is `size` (Vector3) centred at height `centre`, in a w x h stage whose
-- feet line is `feetY` px from its top, hopping up to `lift` studs. Answers the eye and the look point. The feet land
-- on the line exactly; the camera then backs away until every corner of the box, at rest and at the top of the hop,
-- is inside the stage with Stage.Headroom above it (Studio check beta 12: the ears were cut off by the stage's top).
-- `frame` (optional, the podium): {height = the pet's box in pt, shift = pt the viewport sits right of the middle,
-- clear = pt kept over the top of the hop}; the camera first sets the box to `height`, then backs away only if needed.
function Stage.camera(size,centre,w,h,feetY,lift,frame)
	lift=lift or 0
	frame=frame or {}
	local shift=frame.shift or 0
	local tanV=math.tan(math.rad(Stage.Fov)/2)
	local tanH=tanV*math.max(.2,w/math.max(1,h))
	local wide=math.max(size.X,size.Z)
	local distance=math.max(wide/Stage.Fill*.5/tanH,size.Y*.5/(tanV*.8))+wide*.5
	local dir=Vector3.new(math.sin(Stage.Turn)*math.cos(Stage.Down),math.sin(Stage.Down),math.cos(Stage.Turn)*math.cos(Stage.Down))
	local foot=Vector3.new(0,centre-size.Y/2,0)
	local s=(h/2-feetY)/(h/2) -- the feet line as a share of the half-height above the middle
	local top=frame.clear or math.max(Stage.Headroom,math.floor(h*.06))
	local eye,look
	local function place()
		look=Vector3.new(0,centre,0);eye=look+dir*distance
		-- Raise the look point (and the eye with it) by d so the feet land on the line: solve in the camera's frame.
		local f=(look-eye).Unit
		local right=f:Cross(Vector3.new(0,1,0)).Unit
		local up=right:Cross(f)
		local rel=foot-eye
		local d=(s*tanV*rel:Dot(f)-rel:Dot(up))/(s*tanV*f.Y-up.Y)
		look+=Vector3.new(0,d,0);eye+=Vector3.new(0,d,0)
	end
	if frame.height then
		-- The box's height on screen, feet to the top of its middle, set to `height` (a few steps: perspective).
		for _=1,8 do
			place()
			local _,feet=Stage.project(eye,look,foot,w,h)
			local _,crown=Stage.project(eye,look,Vector3.new(0,centre+size.Y/2,0),w,h)
			local now=feet-crown
			if now<=0 then break end
			distance*=now/frame.height
		end
	end
	for _=1,80 do
		place()
		local fits=true
		for _,rise in ipairs({0,lift})do
			for _,sx in ipairs({-1,1})do for _,sy in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
				local x,y=Stage.project(eye,look,Vector3.new(sx*size.X/2,centre+rise+sy*size.Y/2,sz*size.Z/2),w,h)
				if y<top or x+shift<Stage.Side or x+shift>w-Stage.Side then fits=false end
			end end end
		end
		if fits then break end
		distance*=1.05
	end
	return eye,look
end

function Stage.new(parent,rect,options)
	local self=setmetatable({options=options,state={},kind=options.kind or"pedestal",place=options.place or 1},Stage)
	local z=options.z or parent.ZIndex+1
	local well=Kit.frame(parent,"Stage","well",UDim2.fromOffset(rect.x,rect.y),UDim2.fromOffset(rect.w,rect.h),14)
	well.ClipsDescendants=true;well.ZIndex=z
	Kit.stroke(well,Stage.Ink,2)
	self.root=well
	local ped=options.pedestal
	local podium=self.kind=="podium"
	-- The glow under the pedestal (the soft firefly dot, lemon), the wedge of light from the top to the pedestal's
	-- middle (one image; none until it is uploaded), the pedestal (an ellipse) or the podium step.
	local dot=LifeArt.id("fireflyDot")
	if dot then
		node("ImageLabel",well,{Name="Glow",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(rect.w/2,ped.y+ped.h/2+4),
			Size=UDim2.fromOffset(math.min(Stage.GlowSize.X,rect.w),Stage.GlowSize.Y),BackgroundTransparency=1,BorderSizePixel=0,
			Image=dot,ImageColor3=Stage.Lemon,ImageTransparency=Stage.GlowTransparency,ZIndex=z+1})
	end
	local wedge=Icons.image("spotWedge")
	if wedge then
		local ww=math.min(rect.w,math.floor((ped.w+25)/Stage.WedgeBottom))
		self.light=node("ImageLabel",well,{Name="Spotlight",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromOffset(rect.w/2,0),
			Size=UDim2.fromOffset(ww,ped.y+ped.h/2),BackgroundTransparency=1,BorderSizePixel=0,Image=wedge,
			ScaleType=Enum.ScaleType.Stretch,ImageTransparency=Stage.Wedge,ZIndex=z+1})
	end
	local lipH=if podium then 8 else 6
	local lip=node("Frame",well,{Name="PedestalLip",Position=UDim2.fromOffset(ped.x,ped.y+lipH),Size=UDim2.fromOffset(ped.w,ped.h),BackgroundColor3=Stage.CreamLip,
		BorderSizePixel=0,ZIndex=z+2})
	local top=node("Frame",well,{Name="Pedestal",Position=UDim2.fromOffset(ped.x,ped.y),Size=UDim2.fromOffset(ped.w,ped.h),BackgroundColor3=Stage.Cream,
		BorderSizePixel=0,ZIndex=z+3})
	for _,piece in ipairs({lip,top})do if podium then round(piece,UDim.new(0,8))else round(piece)end end
	-- The pet.
	self.frame=options.frame
	self.shift=options.frame and options.frame.shift or 0
	local viewport=node("ViewportFrame",well,{Name="PetViewport",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),
		Position=UDim2.fromOffset(self.shift,0),ZIndex=z+4,Active=false})
	Kit.petLight(viewport)
	local world=node("WorldModel",viewport,{})
	local lens=node("Camera",viewport,{FieldOfView=Stage.Fov})
	viewport.CurrentCamera=lens
	self.viewport,self.world,self.lens,self.w,self.h,self.feetY=viewport,world,lens,rect.w,rect.h,ped.y+ped.h*.45
	local ok,visual=pcall(function()
		return require(script.Parent.PetFactory).new(world,Vector3.zero,options.pet,nil,options.appearance)
	end)
	if ok and visual then
		self.visual=visual
		visual.yaw=0
		if visual.model then visual.model:SetAttribute("DashStage",true)end
	else
		if not ok then warn("[Dash] stage pet: "..tostring(visual))end
		pcall(function()
			local Portrait=require(script.Parent.PetPortrait)
			local sprite=Portrait.create(well,options.pet,4,UDim2.fromOffset(rect.w/2,ped.y-40),z+4,false,options.appearance)
			self.portrait=sprite
		end)
	end
	return self
end
-- The podium landing (U6): the pet drops 12 pt onto the step and squashes. Reduced Motion: nothing.
function Stage:dropIn(reduced)
	if reduced or not self.viewport then return end
	self.viewport.Position=UDim2.fromOffset(self.shift,-12)
	pcall(function()
		TweenService:Create(self.viewport,TweenInfo.new(.3,Enum.EasingStyle.Bounce,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(self.shift,0)}):Play()
	end)
end
function Stage:step(dt,reduced)
	local visual=self.visual
	if not visual or visual.destroyed then return end
	local k=(visual.worldScale or Pose.StudScale)/Pose.StudScale
	if self.kind=="podium"then
		Pose.podium(visual,self.state,dt,self.place,reduced)
		-- FABLE-REVIEW-R1 7: on the card the hop is `frame.hop` pt, not the race pose's 1.2 studs.
		if self.hopStuds then visual.origin=Vector3.new(0,visual.origin.Y/(Pose.JumpHeight*k)*self.hopStuds,0)end
	else Pose.treadmill(visual,self.state,dt,reduced)end
	visual.poseDirty=true
	visual:update(dt)
	if not self.fitted then
		local ok,box,size=pcall(function()return require(script.Parent.PetRigBounds).get(visual)end)
		if ok and box and size then
			self.fitted=true
			-- The pet stands at the origin: its rest height from the bounds (the whole rig: ears, horns, hats, a charm),
			-- without the hop of this frame; the camera leaves room for the highest hop.
			local lift=Pose.JumpHeight*k
			local frame=self.frame
			if frame and frame.height and frame.hop and size.Y>0 then
				self.hopStuds=frame.hop*size.Y/frame.height
				lift=self.hopStuds
			end
			local eye,look=Stage.camera(size,box.Position.Y-visual.origin.Y,self.w,self.h,self.feetY,lift,frame)
			self.lens.CFrame=CFrame.lookAt(eye,look)
		end
	end
end
function Stage:destroy()
	if self.visual and not self.visual.destroyed then pcall(function()self.visual:destroy()end)end
	self.visual=nil
	if self.root then self.root:Destroy();self.root=nil end
end
return Stage
