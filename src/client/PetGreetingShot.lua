-- Pure bounded framing and greeting-camera lifetime helpers.
local Shot = { Fov = 43 }
local function inside(point, floor, margin)
	local p = floor.cf:PointToObjectSpace(point)
	return math.abs(p.X) <= floor.size.X * .5 - margin and math.abs(p.Z) <= floor.size.Z * .5 - margin
end

function Shot.fits(camera, center, size, aspect, fov, crestPixelReserve, viewportHeight, safeTopInset)
	local vertical = math.tan(math.rad(fov or Shot.Fov) * .5) * .90
	local horizontal = vertical * math.max(.1, aspect)
	local reserve=(crestPixelReserve or 0)+(if (crestPixelReserve or 0)>0 then safeTopInset or 0 else 0)
	local top=if reserve>0 then math.tan(math.rad(fov or Shot.Fov)*.5)*math.max(.1,.90-2*reserve/math.max(1,viewportHeight or 1))else vertical
	for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
		local point = camera:PointToObjectSpace(center + Vector3.new(size.X*x,size.Y*y,size.Z*z)*.5)
		local depth = -point.Z
		if depth < .5 or math.abs(point.X) > depth*horizontal or point.Y>depth*top or -point.Y>depth*vertical then return false end
	end end end
	return true
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
	local horizontalSize = math.max(args.size.X,args.size.Z) + .5
	local padded = Vector3.new(horizontalSize,args.size.Y+math.max(1.6,2*(args.animationTopReserve or 0)),horizontalSize)
	local radius = Vector3.new(args.size.X,0,args.size.Z).Magnitude*.5 + .5
	local reserve=(args.crestPixelReserve or 0)+(if (args.crestPixelReserve or 0)>0 then args.safeTopInset or 0 else 0)
	local topScale=if reserve>0 then math.max(.1,.90-reserve/math.max(1,args.viewportHeight or 1))else 1
	local start = math.max(4.6, padded.Y*.5/(math.tan(math.rad(Shot.Fov)*.5)*topScale),
		horizontalSize*.5/(math.tan(math.rad(Shot.Fov)*.5)*args.aspect))
	for index = 0, 7 do
		local angle = index * math.pi/4
		local direction = CFrame.Angles(0,angle,0):VectorToWorldSpace(forward)
		local yaw = math.atan2(-direction.X,-direction.Z)
		local offset = CFrame.Angles(0,yaw,0):VectorToWorldSpace(args.centerOffset)
		local distance, framed = start, false
		-- Solve the distance in pure math before this candidate's world queries.
		local lift=0
		for _ = 1, 8 do
			-- Center a ranked subject in the band below the native topbar/plate.
			-- This exact target lift also applies to the final candidate below.
			lift=if reserve>0 then .4+reserve/math.max(1,args.viewportHeight or 1)*distance*math.tan(math.rad(Shot.Fov)*.5)else 0
			local target=Vector3.new(0,lift,0)
			local camera=CFrame.lookAt(-direction*distance+Vector3.new(0,.65,0)+target,target)
			if Shot.fits(camera,Vector3.zero,padded,args.aspect,Shot.Fov,args.crestPixelReserve,args.viewportHeight,args.safeTopInset) then framed=true;break end
			distance *= 1.12
		end
		if not framed then continue end
		local origin = args.rootPosition + direction*(distance+2.8)
		if not inside(origin,args.floor,radius) then continue end
		local ground = args.ground(origin)
		if not ground then continue end
		origin = Vector3.new(origin.X,ground,origin.Z)
		local localOrigin=args.floor.cf:PointToObjectSpace(origin)
		local floorTop=args.floor.cf:PointToWorldSpace(Vector3.new(localOrigin.X,args.floor.size.Y*.5,localOrigin.Z)).Y
		if math.abs(ground-floorTop) > .65 then continue end
		local target=origin+offset+Vector3.new(0,if reserve>0 then lift else .4,0)
		local position=target-direction*distance+Vector3.new(0,.65,0)
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
