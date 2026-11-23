-- Garden Dash sheets' stage (DASH-DECK-UI-LOOK U3 and U6): the player's pet in a little spotlight at the left of the
-- mode picker (running on the spot on a cream pedestal) and of the results (hopping on a podium step). A well with a
-- lemon glow, a soft white wedge of light and the pet in its own ViewportFrame (a clone, PetInspect's set-up), made
-- when the sheet opens and destroyed with it. No clone: the pet's portrait on the pedestal instead.
--   Stage.new(parent, rect, options) options: {kind = "pedestal" | "podium", pet (PetCatalog entry), appearance,
--     pedestal = {x, y, w, h} (on the stage), place (podium), z}
--   stage:step(dt, reduced) once a frame while the sheet is open; stage:dropIn() the podium landing; stage:destroy()
local Shared=game:GetService("ReplicatedStorage").Shared
local TweenService=game:GetService("TweenService")
local Kit=require(script.Parent.DeckKit)
local Pose=require(script.Parent.DashPose)
local Stage={};Stage.__index=Stage
Stage.Cream=Color3.fromHex("#FFF4DC")
Stage.CreamLip=Color3.fromHex("#D6C196")
Stage.Lemon=Color3.fromHex("#FFE14D")
Stage.Ink=Color3.fromHex("#15143A")
Stage.Fov=30
Stage.Turn=math.rad(20) -- front three-quarter, 20 degrees right of head-on
Stage.Down=math.rad(10)
Stage.Fill=.6           -- the pet fills this share of the stage's width
Stage.LightTop=36
Stage.Slices=12

local function node(class,parent,props)
	local item=Instance.new(class)
	for key,value in pairs(props)do item[key]=value end
	item.Parent=parent
	return item
end
local function round(parent,radius)return node("UICorner",parent,{CornerRadius=radius or UDim.new(.5,0)})end

-- Pure: the camera for a pet of `size` (Vector3) centred at height `centre`, in a w x h stage whose feet line is
-- `feetY` px from its top. Answers the eye and the look point.
function Stage.camera(size,centre,w,h,feetY)
	local tanV=math.tan(math.rad(Stage.Fov)/2)
	local tanH=tanV*math.max(.2,w/math.max(1,h))
	local wide=math.max(size.X,size.Z)
	local distance=math.max(wide/Stage.Fill*.5/tanH,size.Y*.5/(tanV*.8))+wide*.5
	-- Move the look point so the feet land on the pedestal: up by d moves the pet down d / (distance tanV) half-heights.
	local feetPx=h/2+(size.Y/2)/(distance*tanV)*(h/2)
	local d=(feetY-feetPx)*(distance*tanV)/(h/2)
	local look=Vector3.new(0,centre+d,0)
	local dir=Vector3.new(math.sin(Stage.Turn)*math.cos(Stage.Down),math.sin(Stage.Down),math.cos(Stage.Turn)*math.cos(Stage.Down))
	return look+dir*distance,look
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
	-- The glow under the pedestal, the wedge of light from the top, the pedestal (an ellipse) or the podium step.
	local glow=node("Frame",well,{Name="Glow",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(rect.w/2,ped.y+ped.h/2+4),
		Size=UDim2.fromOffset(math.min(rect.w-8,ped.w+36),ped.h+4),BackgroundColor3=Stage.Lemon,BackgroundTransparency=.82,BorderSizePixel=0,ZIndex=z+1})
	round(glow)
	local light=node("Frame",well,{Name="Spotlight",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=z+1})
	local bottomW=math.min(rect.w-12,ped.w+25)
	for i=1,Stage.Slices do
		local t=(i-.5)/Stage.Slices
		local sw=Stage.LightTop+(bottomW-Stage.LightTop)*t
		local sh=ped.y/Stage.Slices
		node("Frame",light,{Name="Slice",AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromOffset(rect.w/2,(i-1)*sh),Size=UDim2.fromOffset(sw,math.ceil(sh)),
			BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.9,BorderSizePixel=0,ZIndex=z+1})
	end
	self.light=light
	local lipH=if podium then 8 else 6
	local lip=node("Frame",well,{Name="PedestalLip",Position=UDim2.fromOffset(ped.x,ped.y+lipH),Size=UDim2.fromOffset(ped.w,ped.h),BackgroundColor3=Stage.CreamLip,
		BorderSizePixel=0,ZIndex=z+2})
	local top=node("Frame",well,{Name="Pedestal",Position=UDim2.fromOffset(ped.x,ped.y),Size=UDim2.fromOffset(ped.w,ped.h),BackgroundColor3=Stage.Cream,
		BorderSizePixel=0,ZIndex=z+3})
	for _,piece in ipairs({lip,top})do if podium then round(piece,UDim.new(0,8))else round(piece)end end
	-- The pet.
	local viewport=node("ViewportFrame",well,{Name="PetViewport",BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),ZIndex=z+4,Active=false})
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
	self.viewport.Position=UDim2.fromOffset(0,-12)
	pcall(function()
		TweenService:Create(self.viewport,TweenInfo.new(.3,Enum.EasingStyle.Bounce,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(0,0)}):Play()
	end)
end
function Stage:step(dt,reduced)
	local visual=self.visual
	if not visual or visual.destroyed then return end
	if self.kind=="podium"then Pose.podium(visual,self.state,dt,self.place,reduced)
	else Pose.treadmill(visual,self.state,dt,reduced)end
	visual.poseDirty=true
	visual:update(dt)
	if not self.fitted then
		local ok,box,size=pcall(function()return require(script.Parent.PetRigBounds).get(visual)end)
		if ok and box and size then
			self.fitted=true
			-- The pet stands at the origin: its rest height from the bounds, without the hop of this frame.
			local eye,look=Stage.camera(size,box.Position.Y-visual.origin.Y,self.w,self.h,self.feetY)
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
