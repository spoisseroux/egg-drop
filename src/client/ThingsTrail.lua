-- Show me (V3-THINGS-TO-DO-PLAN-2026-11-22): prints on the ground to a place in the garden, and a marker over it, for
-- Seconds. On this client only: pooled local parts that nothing can touch, stand on or click. PathfindingService finds
-- the way; a way that would cross water goes over the bridge instead, and with no dry way only the marker shows, never
-- a line over water. It ends on arrival, when its time is up, at a menu, a round, a race or a pet close-up, on death,
-- when the switch goes off, and when a new trail starts. Reduced Motion: no fades.
-- deps: world, root() -> position or nil, free() -> bool (still in the garden), busy() -> bool (a menu is up),
--   compute(from, to) -> points or nil (yields), reduced() -> bool, plus now, spawn, ground(point) and step for specs.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World=require(Shared:WaitForChild("HollowWorldLayout"))
local Walk=require(Shared:WaitForChild("GardenWalkability"))
local Trail={};Trail.__index=Trail
Trail.Seconds=20
Trail.Arrive=8
Trail.Parts=40
Trail.Step=3.2      -- studs between prints, more on a long way
Trail.Side=.5       -- left and right of the line
Trail.MenuGrace=.6  -- the menu that started it may take this long to close
Trail.Near=3        -- started on the spot: the marker shows this long
Trail.FadeIn=.25;Trail.FadeLag=.03;Trail.FadeOut=1
Trail.Clear=.15     -- how see-through a print is
-- The way up to the bridge's west end, from the measured race line: the navigation mesh has a seam there and goes round it
-- through the stream (Studio 2026-11-22). Outermost first.
Trail.West=table.freeze({Vector3.new(-18.95,4.4,14.33),Vector3.new(-13,4.4,21)})
Trail.Bank=1        -- the water boxes hold this much bank: a way that brushes the Bubble Spring's rim is dry (Studio 2026-11-22)
Trail.Color=Color3.fromHex("#FFF4DC")
Trail.Ink=Color3.fromHex("#24304F")
Trail.Agent=table.freeze({AgentRadius=2,AgentHeight=5,AgentCanJump=false,WaypointSpacing=4})

local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
-- Pure: up to `count` prints along a polyline: {position, yaw, side}. None under the player or under the marker.
function Trail.prints(points,count)
	local total=0
	for i=2,#points do total+=flat(points[i-1],points[i])end
	local out={}
	if total<Trail.Step*1.5 then return out end
	local gap=math.max(Trail.Step,total/(count+1))
	local walked,nextAt=0,gap
	for i=2,#points do
		local a,b=points[i-1],points[i]
		local length=flat(a,b)
		while length>1e-4 and nextAt<=walked+length and nextAt<total-1 and #out<count do
			local yaw=math.atan2(b.X-a.X,b.Z-a.Z)
			local side=if #out%2==0 then 1 else -1
			local at=a:Lerp(b,(nextAt-walked)/length)
			table.insert(out,{position=at+Vector3.new(math.cos(yaw)*side*Trail.Side,0,-math.sin(yaw)*side*Trail.Side),yaw=yaw})
			nextAt+=gap
		end
		walked+=length
	end
	return out
end
-- The garden's water as GardenWalkability reads it, from the same data the world is built with.
local wet
function Trail.wet()
	if wet then return wet end
	wet={}
	local function add(x,z,w,d,yaw)
		table.insert(wet,{Parent=true,CFrame=CFrame.new(x,0,z)*CFrame.Angles(0,yaw or 0,0),Size=Vector3.new(math.max(1,w-Trail.Bank*2),1,math.max(1,d-Trail.Bank*2)),GetAttribute=function()return false end})
	end
	if World.WorldVersion=="v7"then
		for _,entry in ipairs(require(Shared:WaitForChild("WorldV7Data")).wet or {})do
			local c,s=entry.center,entry.size
			add(c[1],c[3],s[1],s[3],entry.yaw)
		end
	end
	for _,entry in ipairs(World.Wet or {})do
		if typeof(entry.center)=="Vector2"then add(entry.center.X,entry.center.Y,entry.size.X,entry.size.Y,entry.yaw)end
	end
	return wet
end
function Trail.dry(points,list)
	list=list or Trail.wet()
	for i=2,#points do
		if not Walk.segmentAllowed(points[i-1],points[i],list)then return false end
	end
	return true
end
-- A dry way between a place and a bridge's end, or nil: straight, else by the west approach. Reversed: from the end out.
local function approach(compute,place,mouth,west,dry,reversed)
	local function way(inner)
		local points=if reversed then compute(inner,place)else compute(place,inner)
		return if points and #points>=2 and dry(points)then points else nil
	end
	local points=way(mouth)
	if points then return points end
	if not west then return nil end
	points=way(Trail.West[1])
	if not points then return nil end
	local all={}
	if reversed then
		for i=#Trail.West,1,-1 do table.insert(all,Trail.West[i])end
		for _,point in ipairs(points)do table.insert(all,point)end
	else
		all=table.clone(points)
		for _,point in ipairs(Trail.West)do table.insert(all,point)end
	end
	return if dry(all)then all else nil
end
-- A dry way, or nil: straight there, else over a bridge. compute may yield.
function Trail.route(compute,from,to,dry)
	dry=dry or Trail.dry
	local points=compute(from,to)
	if points and #points>=2 and dry(points)then return points end
	for _,span in pairs(World.WalkableSpans or {})do
		if span.crossing then
			local y=Walk.top(span)
			local half=Vector3.new(span.size.X*.5+1,0,0)
			local centre=Vector3.new(span.center.X,y,span.center.Z)
			local near,far=centre-half,centre+half
			if flat(from,far)<flat(from,near)then near,far=far,near end
			local first=approach(compute,from,near,near.X<centre.X,dry,false)
			local second=first and approach(compute,to,far,far.X<centre.X,dry,true)
			if first and second then
				local all=table.clone(first)
				table.insert(all,near);table.insert(all,far)
				for _,point in ipairs(second)do table.insert(all,point)end
				return all
			end
		end
	end
	return nil
end
-- PathfindingService, or nil for no path.
function Trail.pathfind(from,to)
	local path=game:GetService("PathfindingService"):CreatePath(table.clone(Trail.Agent))
	local ok=pcall(function()path:ComputeAsync(from,to)end)
	if not ok or path.Status~=Enum.PathStatus.Success then return nil end
	local out={}
	for _,waypoint in ipairs(path:GetWaypoints())do table.insert(out,waypoint.Position)end
	return out
end
-- Pure: a print's transparency `age` seconds in, with `left` seconds to go.
function Trail.alpha(index,age,left,reduced)
	if reduced then return Trail.Clear end
	local shown=math.clamp((age-index*Trail.FadeLag)/Trail.FadeIn,0,1)*math.clamp(left/Trail.FadeOut,0,1)
	return 1-(1-Trail.Clear)*shown
end

function Trail.new(deps)
	return setmetatable({d=deps,pool={},live={},generation=0,now=deps.now or os.clock},Trail)
end
function Trail:active()return self.target~=nil end
local function still(part)
	part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false;part.Massless=true
end
function Trail:ensure()
	if self.folder then return end
	local folder=Instance.new("Folder");folder.Name="EggDropShowMe"
	local anchor=Instance.new("Part");anchor.Name="Marker";anchor.Size=Vector3.new(.2,.2,.2);anchor.Transparency=1
	still(anchor)
	-- The pin: a pointer tucked under a name plate, over everything, so it can be found from any side.
	local gui=Instance.new("BillboardGui");gui.Name="Pin";gui.Adornee=anchor;gui.Size=UDim2.fromOffset(190,64);gui.SizeOffset=Vector2.new(0,.5)
	gui.StudsOffsetWorldSpace=Vector3.new(0,4,0);gui.AlwaysOnTop=true;gui.LightInfluence=0;gui.ResetOnSpawn=false;gui.Active=false
	local point=Instance.new("Frame");point.Name="Pointer";point.AnchorPoint=Vector2.new(.5,.5);point.Position=UDim2.new(.5,0,1,-18)
	point.Size=UDim2.fromOffset(18,18);point.Rotation=45;point.BackgroundColor3=Trail.Ink;point.BorderSizePixel=0;point.Parent=gui
	local plate=Instance.new("TextLabel");plate.Name="Name";plate.Size=UDim2.new(1,0,0,40);plate.BackgroundColor3=Trail.Color
	plate.TextColor3=Trail.Ink;plate.Font=Enum.Font.FredokaOne;plate.TextScaled=true;plate.TextWrapped=true;plate.ZIndex=2;plate.Parent=gui
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,14);corner.Parent=plate
	local stroke=Instance.new("UIStroke");stroke.Color=Trail.Ink;stroke.Thickness=2;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=plate
	local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,10);pad.PaddingRight=UDim.new(0,10);pad.PaddingTop=UDim.new(0,6);pad.PaddingBottom=UDim.new(0,6);pad.Parent=plate
	local size=Instance.new("UITextSizeConstraint");size.MinTextSize=10;size.MaxTextSize=20;size.Parent=plate
	gui.Parent=anchor
	anchor.Parent=folder
	self.folder,self.marker,self.plate=folder,anchor,plate
end
-- target = {position, name}. True when the marker is up (the prints follow once the way is known).
function Trail:start(target)
	self:stop("new")
	local root=self.d.root()
	if type(target)~="table"or typeof(target.position)~="Vector3"or not root or self.d.free()~=true then return false end
	self:ensure()
	self.target,self.age=target,0
	self.spot=flat(root,target.position)<=Trail.Arrive
	self.plate.Text=target.name or ""
	self.marker.CFrame=CFrame.new(target.position)
	self.folder:SetAttribute("Way","finding")
	self.folder.Parent=self.d.world or workspace
	local mine=self.generation
	if not self.spot then
		(self.d.spawn or task.spawn)(function()
			local ok,points=pcall(Trail.route,self.d.compute or Trail.pathfind,root,target.position)
			if self.generation~=mine or not self.target then return end
			if ok and points then self:lay(points)else self.folder:SetAttribute("Way","none")end
		end)
	end
	if self.d.step~=false then
		self.connection=RunService.Heartbeat:Connect(function(dt)
			local good,problem=pcall(self.step,self,dt)
			if not good then warn("[Things] trail: "..tostring(problem));self:stop("error")end
		end)
	end
	return true
end
function Trail:lay(points)
	self.folder:SetAttribute("Way","prints")
	self.laidAt=self.age
	local reduced=self.d.reduced~=nil and self.d.reduced()==true
	for index,entry in ipairs(Trail.prints(points,Trail.Parts))do
		local part=self.pool[index]
		if not part then
			part=Instance.new("Part");part.Name="Print";part.Size=Vector3.new(.7,.06,1);part.Color=Trail.Color
			part.Material=Enum.Material.SmoothPlastic
			still(part)
			local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=part
			self.pool[index]=part
		end
		local at=entry.position
		local y=self.d.ground and self.d.ground(at)
		if y and math.abs(y-at.Y)<=1.5 then at=Vector3.new(at.X,y,at.Z)end
		part.CFrame=CFrame.new(at+Vector3.new(0,.05,0))*CFrame.Angles(0,entry.yaw,0)
		part.Transparency=Trail.alpha(index,0,Trail.Seconds,reduced)
		part.Parent=self.folder
		table.insert(self.live,part)
	end
end
function Trail:step(dt)
	local target=self.target
	if not target then return end
	self.age+=dt
	local root=self.d.root()
	if not root or self.d.free()~=true then self:stop("left");return end
	if self.age>Trail.MenuGrace and self.d.busy()==true then self:stop("menu");return end
	local near=flat(root,target.position)<=Trail.Arrive
	if near and(not self.spot or self.age>=Trail.Near)then self:stop("arrived");return end
	local left=Trail.Seconds-self.age
	if left<=0 then self:stop("time");return end
	local reduced=self.d.reduced~=nil and self.d.reduced()==true
	local since=if self.laidAt then self.age-self.laidAt else 0
	-- Nothing to repaint between the fade in and the fade out.
	local settled=since>Trail.Parts*Trail.FadeLag+Trail.FadeIn+.2
	if not reduced and(not settled or left<=Trail.FadeOut or not self.painted)then
		for index,part in ipairs(self.live)do part.Transparency=Trail.alpha(index,since,left,false)end
		self.painted=settled
	end
end
-- Takes every part out of the world. The pool is kept for the next one.
function Trail:stop(reason)
	self.generation+=1
	if self.connection then self.connection:Disconnect();self.connection=nil end
	local was=self.target~=nil
	self.target,self.laidAt,self.painted,self.spot=nil,nil,nil,nil
	for _,part in ipairs(self.live)do part.Parent=nil end
	table.clear(self.live)
	if self.folder then self.folder.Parent=nil end
	if was then self.reason=reason end
	return was
end
function Trail:destroy()
	self:stop("destroy")
	for _,part in ipairs(self.pool)do part:Destroy()end
	table.clear(self.pool)
	if self.folder then self.folder:Destroy();self.folder=nil end
end
return Trail
