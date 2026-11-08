-- Pure bounded framing and greeting-camera lifetime helpers.
local Shot = { Fov = 43 }
local function inside(point, floor, margin)
	local p = floor.cf:PointToObjectSpace(point)
	return math.abs(p.X) <= floor.size.X * .5 - margin and math.abs(p.Z) <= floor.size.Z * .5 - margin
end

function Shot.fits(camera, center, size, aspect, fov, crestPixelReserve, viewportHeight, safeTopInset, safeBottomInset, safeLeftInset, safeRightInset)
	local vertical = math.tan(math.rad(fov or Shot.Fov) * .5) * .90
	local width=math.max(1,(viewportHeight or 1000)*aspect)
	local left=math.tan(math.rad(fov or Shot.Fov)*.5)*aspect*math.max(.1,.90-2*(safeLeftInset or 0)/width)
	local right=math.tan(math.rad(fov or Shot.Fov)*.5)*aspect*math.max(.1,.90-2*(safeRightInset or 0)/width)
	local reserve=(crestPixelReserve or 0)+(safeTopInset or 0)
	local top=if reserve>0 then math.tan(math.rad(fov or Shot.Fov)*.5)*math.max(.1,.90-2*reserve/math.max(1,viewportHeight or 1))else vertical
	local bottom=math.tan(math.rad(fov or Shot.Fov)*.5)*math.max(.1,.90-2*(safeBottomInset or 0)/math.max(1,viewportHeight or 1))
	for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
		local point = camera:PointToObjectSpace(center + Vector3.new(size.X*x,size.Y*y,size.Z*z)*.5)
		local depth = -point.Z
		if depth < .5 or point.X>depth*right or -point.X>depth*left or point.Y>depth*top or -point.Y>depth*bottom then return false end
	end end end
	return true
end

-- Height of the actual rest silhouette as a fraction of the full viewport.
-- Animation/crest padding is kept separate so it cannot masquerade as pet size.
function Shot.projectedHeight(camera,center,size,fov)
	local low,high=math.huge,-math.huge
	local tangent=math.tan(math.rad(fov or Shot.Fov)*.5)
	for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
		local p=camera:PointToObjectSpace(center+size*Vector3.new(x,y,z)*.5)
		if p.Z>=-.5 then return math.huge end
		local y=p.Y/(-p.Z*tangent)
		low,high=math.min(low,y),math.max(high,y)
	end end end
	return(high-low)*.5
end

-- Capture the renderer's existing piece list once per accepted/reframed shot.
-- An aggregate box adds empty corners above the sprig and below the slippers.
function Shot.captureSilhouette(pet,bounds)
	local points={}
	local basis=CFrame.new(bounds.Position)*CFrame.Angles(0,pet.yaw or 0,0)
	for _,entry in ipairs(pet.pieces or {})do
		local part=entry.part
		if part and part.Parent and part.Transparency<.99 and entry.role~="ripple"and entry.faceRole~="spark"then
			local transform=basis:ToObjectSpace(part.CFrame)
			local size=part.Size
			for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
				table.insert(points,transform:PointToWorldSpace(size*Vector3.new(x,y,z)*.5))
			end end end
		end
	end
	return if #points>0 then points else nil
end

function Shot.projectedPointsHeight(camera,points,rotation,fov)
	local transform=camera:ToObjectSpace(rotation or CFrame.identity)
	local low,high=math.huge,-math.huge
	local tangent=math.tan(math.rad(fov or Shot.Fov)*.5)
	for _,point in ipairs(points)do
		local p=transform:PointToWorldSpace(point)
		if p.Z>=-.5 then return math.huge end
		local y=p.Y/(-p.Z*tangent)
		low,high=math.min(low,y),math.max(high,y)
	end
	return(high-low)*.5
end

function Shot.maximumReach(size, aspect, crestPixelReserve, viewportHeight, safeTopInset, animationTopReserve)
	local horizontal=math.max(size.X,size.Z)+.5
	local reserve=(crestPixelReserve or 0)+(if (crestPixelReserve or 0)>0 then safeTopInset or 0 else 0)
	local topScale=if reserve>0 then math.max(.1,.90-reserve/math.max(1,viewportHeight or 1))else 1
	local pad=math.max(1.6,2*(animationTopReserve or 0))
	local start=math.max(4.6,(size.Y+pad)*.5/(math.tan(math.rad(Shot.Fov)*.5)*topScale),
		horizontal*.5/(math.tan(math.rad(Shot.Fov)*.5)*math.max(.1,aspect)))
	return start*1.12^8+2.8+size.Magnitude*.5+1
end

-- Finite segment against a conservatively padded oriented visual box. This
-- handles authored CanQuery=false signs/foliage without changing their physics.
function Shot.segmentBlocked(from, to, parts)
	local delta=to-from
	for _, part in ipairs(parts) do
		if not part.Parent then continue end
		local a=part.CFrame:PointToObjectSpace(from)
		local b=part.CFrame:VectorToObjectSpace(delta)
		local half=part.Size*.5+Vector3.new(.08,.08,.08)
		local enter,leave,hit=0,1,true
		for _,axis in ipairs({"X","Y","Z"}) do
			if math.abs(b[axis])<.00001 then
				if math.abs(a[axis])>half[axis] then hit=false;break end
			else
				local near,far=(-half[axis]-a[axis])/b[axis],(half[axis]-a[axis])/b[axis]
				if near>far then near,far=far,near end
				enter,leave=math.max(enter,near),math.min(leave,far)
				if enter>leave then hit=false;break end
			end
		end
		if hit then return true end
	end
	return false
end

function Shot.plan(args)
	if not args.floor or args.aspect <= 0 then return nil end
	local forward = Vector3.new(args.forward.X,0,args.forward.Z)
	if forward.Magnitude < .01 then forward = Vector3.new(0,0,-1) else forward = forward.Unit end
	local horizontalSize = math.max(args.size.X,args.size.Z) + (args.animationSideReserve or .35)
	local rise=args.animationTopReserve or .8
	-- Greetings rise above the rest hull. Reserving that same space below the
	-- feet used to make every pet unnecessarily distant.
	local padded = Vector3.new(horizontalSize,args.size.Y+rise+.08,horizontalSize)
	local envelopeCenter=Vector3.new(0,(rise-.08)*.5,0)
	local radius = Vector3.new(args.size.X,0,args.size.Z).Magnitude*.5 + .5
	local height=math.max(1,args.viewportHeight or 1000)
	local topInset,bottomInset=args.safeTopInset or 0,args.safeBottomInset or 0
	local leftInset,rightInset=args.safeLeftInset or 0,args.safeRightInset or 0
	local reserve=(args.crestPixelReserve or 0)+topInset
	local safeFraction=math.max(.1,1-(topInset+bottomInset)/height)
	local tangent=math.tan(math.rad(Shot.Fov)*.5)
	local start=math.max(2,padded.Y/(tangent*safeFraction),horizontalSize/(tangent*args.aspect))
	for index = 0, 7 do
		local angle = index * math.pi/4
		local direction = CFrame.Angles(0,angle,0):VectorToWorldSpace(forward)
		local yaw = math.atan2(-direction.X,-direction.Z)
		local rotation=CFrame.Angles(0,yaw,0)
		local offset = rotation:VectorToWorldSpace(args.centerOffset)
		local right=CFrame.lookAt(-direction,Vector3.zero).RightVector
		local function candidate(distance)
			local lift=(reserve-bottomInset)/height*distance*tangent+(rise-.08)*.5
			local shift=(rightInset-leftInset)/(height*args.aspect)*distance*tangent*args.aspect
			local target=Vector3.new(0,lift,0)+right*shift
			return CFrame.lookAt(-direction*distance+Vector3.new(0,.18,0)+target,target),target
		end
		local function fits(distance)
			local camera=candidate(distance)
			if not Shot.fits(camera,envelopeCenter,padded,args.aspect,Shot.Fov,args.crestPixelReserve,height,topInset,bottomInset,leftInset,rightInset)then return false end
			local occupancy=if args.silhouette then Shot.projectedPointsHeight(camera,args.silhouette,rotation)else Shot.projectedHeight(camera,Vector3.zero,args.size)
			return occupancy/safeFraction<=(if args.silhouette then .64 else .60)
		end
		local distance,framed=start,false
		for _=1,8 do if fits(distance)then framed=true;break end;distance*=1.25 end
		if not framed then continue end
		local low,high=.5,distance
		for _=1,22 do local mid=(low+high)*.5;if fits(mid)then high=mid else low=mid end end
		distance=high
		local _,targetOffset=candidate(distance)
		local origin = args.rootPosition + direction*(distance+2.8)
		if not inside(origin,args.floor,radius) then continue end
		local ground = args.ground(origin)
		if not ground then continue end
		origin = Vector3.new(origin.X,ground,origin.Z)
		local localOrigin=args.floor.cf:PointToObjectSpace(origin)
		local floorTop=args.floor.cf:PointToWorldSpace(Vector3.new(localOrigin.X,args.floor.size.Y*.5,localOrigin.Z)).Y
		if math.abs(ground-floorTop) > .65 then continue end
		local target=origin+offset+targetOffset
		local position=target-direction*distance+Vector3.new(0,.18,0)
		local camera=CFrame.lookAt(position,target)
		if inside(position,args.floor,.6) and (not args.clear or args.clear(position,target,origin)) then
			return {origin=origin,camera=camera,target=target,yaw=yaw,framingSize=padded,fov=Shot.Fov}
		end
	end
	return nil
end

function Shot.capture(camera, root)
	return {camera=camera,root=root,character=root and root.Parent,position=root and root.Position,
		transform=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView}
end

function Shot.restore(saved, camera, root)
	if not saved or saved.camera ~= camera or saved.root ~= root or not root or not root.Parent
		or saved.character ~= root.Parent then return false end
	local delta=root.Position-saved.position
	camera.CFrame=saved.transform+delta
	camera.Focus=saved.focus+delta
	camera.FieldOfView=saved.fov
	return true
end
return Shot
