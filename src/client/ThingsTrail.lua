-- Show me (V3-THINGS-TO-DO-PLAN-2026-11-22): prints on the ground to a place in the garden, and a marker over it, for
-- Seconds. On this client only: pooled local parts that nothing can touch, stand on or click. PathfindingService finds
-- the way; a way that would cross water goes over the bridge instead, and with no dry way only the marker shows, never
-- a line over water. It ends on arrival, when its time is up, at a menu, a round, a race or a pet close-up, on death,
-- when the switch goes off, and when a new trail starts. Reduced Motion: no fades.
-- deps: world, root() -> position or nil, free() -> bool (still in the garden), busy() -> bool (a menu is up),
--   compute(from, to) -> points or nil (yields), reduced() -> bool, plus now, spawn, ground(point) and step for specs.
--   glow() -> bool (optional): Glow steps (ONBOARDING-V3-BRIEF section 2, switch Onboard "trail2"), read at each start.
-- Glow steps: the prints are GlowSteps' glowing paws with the wave toward the target, a gold ring at the target, and:
--   target.guide = true      a guide trail (its prompt is open): no Seconds end, and a menu or a trip out of the garden
--                            hides it instead of ending it (it comes back after). The caller stops it (trail:stop).
--   trail:leadBy(petModel)   when a pet leads: the route's prints hide and the pet's own pop in under its feet with a
--                            soft `pat`, the player's steps pop them with 2 sparkles, at most 12. leadBy(nil) ends it.
--   trail:leadHold(on)       lay no new prints while on (the pet runs back to the player); pops go on.
--   trail.points             the dry way once laid (the route a leading pet can run along), else nil.
-- With glow off (or deps.glow missing) every line below runs as before; leadBy returns false.
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
Trail.Bank=1        -- the Bubble Spring's box holds this much rim: a way that brushes it is dry (Studio 2026-11-22). Never the stream's boxes: shrunk, they part at the joints
Trail.Color=Color3.fromHex("#FFF4DC")
Trail.Ink=Color3.fromHex("#24304F")
Trail.Agent=table.freeze({AgentRadius=2,AgentHeight=5,AgentCanJump=false,WaypointSpacing=4})
-- Beta 14 QA Q1 (WORLD-AND-NEST-LOOK 4): the pin shows only near the end (a fixed-pixel tag 90 studs off stood over the
-- arch): full from PinFull in, fading out to PinNear, none further; the paw prints lead until then. With no dry way the
-- pin is the only guide, so it shows at any distance. Smaller too, for every destination.
Trail.PinNear=28
Trail.PinFull=22
Trail.PinSize=Vector2.new(150,48)
Trail.PinText=15
Trail.PlateHeight=34
Trail.Pointer=14

local function flat(a,b)return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
-- Beta (44) #17 ("the footprints ... are sometimes not facing the right way"): a print faces along the way's smoothed
-- tangent, from the point Tangent studs behind it to the one Tangent studs ahead (clamped to the ends), so the prints
-- turn through a corner instead of kinking at it, and the left / right offset turns with them.
Trail.Tangent=1.5
-- Pure: the point `s` flat studs along a polyline (clamped to its ends).
function Trail.along(points,s)
	local n=#points
	if n==0 then return nil end
	if s<=0 then return points[1]end
	local walked=0
	for i=2,n do
		local a,b=points[i-1],points[i]
		local length=flat(a,b)
		if length>1e-4 and s<=walked+length then return a:Lerp(b,(s-walked)/length)end
		walked+=length
	end
	return points[n]
end
-- Pure: the way's heading (yaw, +Z turned to it) at `s` studs along, from Trail.Tangent either side; nil when flat.
function Trail.heading(points,s,total)
	local back=Trail.along(points,math.max(0,s-Trail.Tangent))
	local ahead=Trail.along(points,math.min(total,s+Trail.Tangent))
	if not back or not ahead then return nil end
	local d=Vector2.new(ahead.X-back.X,ahead.Z-back.Z)
	if d.Magnitude<1e-4 then return nil end
	return math.atan2(d.X,d.Y)
end
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
			local yaw=Trail.heading(points,nextAt,total)or math.atan2(b.X-a.X,b.Z-a.Z)
			local side=if #out%2==0 then 1 else -1
			local at=a:Lerp(b,(nextAt-walked)/length)
			table.insert(out,{position=at+Vector3.new(math.cos(yaw)*side*Trail.Side,0,-math.sin(yaw)*side*Trail.Side),yaw=yaw})
			nextAt+=gap
		end
		walked+=length
	end
	return out
end
-- Beta (44) #17 ("they need to pathfind around objects"): the way round the garden's bushes, reeds and props the
-- navmesh cannot see, with the same keep-out list and detours the lead uses (GardenKeepOut.lead, PetLead.around), each
-- detour leg kept dry (`dry(a, b)`). The pathfinder's close points are thinned first (PetLead.simplify) so the server's
-- route caps fit. Returns the way round, or `points` unchanged when nothing is in the way or it cannot be cleared.
function Trail.around(points,list,dry)
	if type(points)~="table"or #points<2 or type(list)~="table"or #list==0 then return points end
	local Lead=require(Shared:WaitForChild("PetLead"))
	local blocked=false
	for i=2,#points do
		if Lead.blocker(points[i-1],points[i],list,Lead.Body,i==2,i==#points)then blocked=true;break end
	end
	if not blocked then return points end
	local thin=Lead.simplify(points)
	local cleared=Lead.around(thin,list,dry,points)
	return cleared or points
end
-- The keep-out list (deps.keepOut() when given; else GardenKeepOut.lead with the Alive switches, as the lead's).
function Trail:keepOut()
	if type(self.d.keepOut)=="function"then
		local ok,list=pcall(self.d.keepOut)
		return if ok and type(list)=="table"then list else nil
	end
	local ok,list=pcall(function()
		local KeepOut=require(Shared:WaitForChild("GardenKeepOut"))
		local Alive=require(Shared:WaitForChild("Alive"))
		return KeepOut.lead(function(feature)return Alive.on(feature)end)
	end)
	return if ok and type(list)=="table"then list else nil
end
-- The garden's water as GardenWalkability reads it, from the same data the world is built with.
local wet
function Trail.wet()
	if wet then return wet end
	wet={}
	local function add(x,z,w,d,yaw,bank)
		bank=(bank or 0)*2
		table.insert(wet,{Parent=true,CFrame=CFrame.new(x,0,z)*CFrame.Angles(0,yaw or 0,0),Size=Vector3.new(math.max(1,w-bank),1,math.max(1,d-bank)),GetAttribute=function()return false end})
	end
	if World.WorldVersion=="v7"then
		for _,entry in ipairs(require(Shared:WaitForChild("WorldV7Data")).wet or {})do
			local c,s=entry.center,entry.size
			add(c[1],c[3],s[1],s[3],entry.yaw)
		end
	end
	for _,entry in ipairs(World.Wet or {})do
		if typeof(entry.center)=="Vector2"then add(entry.center.X,entry.center.Y,entry.size.X,entry.size.Y,entry.yaw,if entry.name=="BubbleSpring"then Trail.Bank else 0)end
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
	if not west or World.WorldVersion~="v7"then return nil end
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
-- Pure: the pin's see-through (0 shown .. 1 gone) at `distance` flat studs from the end; `way` is the folder's Way.
function Trail.pinAlpha(distance,way)
	if way=="none"then return 0 end
	if type(distance)~="number"or distance~=distance then return 1 end
	return math.clamp((distance-Trail.PinFull)/(Trail.PinNear-Trail.PinFull),0,1)
end
-- Pure: a target's pin text; `name` may be a function (asked each step, for a pin that changes, the nest's "Hatch!").
function Trail.label(target)
	local name=type(target)=="table"and target.name
	if type(name)=="function"then
		local ok,text=pcall(name)
		name=if ok then text else nil
	end
	return if type(name)=="string"then name else ""
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
	local gui=Instance.new("BillboardGui");gui.Name="Pin";gui.Adornee=anchor;gui.Size=UDim2.fromOffset(Trail.PinSize.X,Trail.PinSize.Y);gui.SizeOffset=Vector2.new(0,.5)
	gui.StudsOffsetWorldSpace=Vector3.new(0,4,0);gui.AlwaysOnTop=true;gui.LightInfluence=0;gui.ResetOnSpawn=false;gui.Active=false
	local point=Instance.new("Frame");point.Name="Pointer";point.AnchorPoint=Vector2.new(.5,.5);point.Position=UDim2.new(.5,0,1,-Trail.Pointer)
	point.Size=UDim2.fromOffset(Trail.Pointer,Trail.Pointer);point.Rotation=45;point.BackgroundColor3=Trail.Ink;point.BorderSizePixel=0;point.Parent=gui
	local plate=Instance.new("TextLabel");plate.Name="Name";plate.Size=UDim2.new(1,0,0,Trail.PlateHeight);plate.BackgroundColor3=Trail.Color
	plate.TextColor3=Trail.Ink;plate.Font=Enum.Font.FredokaOne;plate.TextScaled=false;plate.TextSize=Trail.PinText;plate.TextWrapped=true;plate.ZIndex=2;plate.Parent=gui
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,14);corner.Parent=plate
	local stroke=Instance.new("UIStroke");stroke.Color=Trail.Ink;stroke.Thickness=2;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=plate
	local pad=Instance.new("UIPadding");pad.PaddingLeft=UDim.new(0,10);pad.PaddingRight=UDim.new(0,10);pad.PaddingTop=UDim.new(0,4);pad.PaddingBottom=UDim.new(0,4);pad.Parent=plate
	gui.Parent=anchor
	anchor.Parent=folder
	self.folder,self.marker,self.plate,self.pin,self.pointer,self.pinStroke=folder,anchor,plate,gui,point,stroke
end
-- The switch for this trail, read when it starts.
function Trail:glowOn()
	local glow=self.d.glow
	if type(glow)~="function"then return false end
	local ok,value=pcall(glow)
	return ok and value==true
end
-- target = {position, name, guide}. True when the marker is up (the prints follow once the way is known).
function Trail:start(target)
	self:stop("new")
	local root=self.d.root()
	if type(target)~="table"or typeof(target.position)~="Vector3"or not root or self.d.free()~=true then return false end
	self:ensure()
	self.target,self.age=target,0
	self.glow=self:glowOn()
	self.startedAt=self.now()
	self.guide=self.glow and target.guide==true
	if self.glow then
		if not self.steps then self.steps=require(script.Parent.GlowSteps).new({parent=self.folder,play=self.d.play})end
		self.steps:target(target.position)
	end
	-- target.pinAt: where the pin stands, when not over the end of the way (the Sleepy Nest landmark's: 8.2 over the
	-- bowl's centre, while the prints end at its prompt). Default: 4 over the target.
	local pinAt=if typeof(target.pinAt)=="Vector3"then target.pinAt else nil
	self.pin.StudsOffsetWorldSpace=if pinAt then Vector3.zero else Vector3.new(0,4,0)
	self.spot=flat(root,target.position)<=Trail.Arrive
	self.plate.Text=Trail.label(target)
	self.marker.CFrame=CFrame.new(pinAt or target.position)
	self.pinAlphaShown=nil
	self.folder:SetAttribute("Way","finding")
	self:paintPin(flat(root,target.position))
	self.folder.Parent=self.d.world or workspace
	local mine=self.generation
	if not self.spot then
		(self.d.spawn or task.spawn)(function()
			local base=self.d.compute or Trail.pathfind
			local function compute(from,to) -- a trail that is over asks for no more ways
				if self.generation~=mine or not self.target then return nil end
				return base(from,to)
			end
			local ok,points=pcall(Trail.route,compute,root,target.position)
			if self.generation~=mine or not self.target then return end
			-- beta (44) #17: round the keep-outs, dry (deps.keepOut false: off)
			if ok and points and self.d.keepOut~=false then
				local list=self:keepOut()
				if list then
					local good,round=pcall(Trail.around,points,list,function(a,b)return Walk.segmentAllowed(a,b,Trail.wet())end)
					if good and type(round)=="table"and #round>=2 then points=round end
				end
			end
			if ok and points then self:lay(points)
			-- beta 44 note 23: a target may carry a straight fallback, laid when it stays dry
			elseif type(target.fallback)=="table"and #target.fallback>=2 and Trail.dry(target.fallback)then self:lay(target.fallback)
			else self.folder:SetAttribute("Way","none")end
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
	self.points=points
	if self.glow then self:layGlow(points);return end
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
-- Glow steps: the route's prints as GlowSteps paws (toes along the way), fading in one after the other.
function Trail:layGlow(points)
	local steps=self.steps
	local count=0
	for index,entry in ipairs(Trail.prints(points,Trail.Parts))do
		local at=entry.position
		local y=self.d.ground and self.d.ground(at)
		if y and math.abs(y-at.Y)<=1.5 then at=Vector3.new(at.X,y,at.Z)end
		-- entry.yaw turns a part's +Z along the way; the paw's toes are its -Z, so half a turn more.
		steps:place(index,CFrame.new(at+Vector3.new(0,.04,0))*CFrame.Angles(0,entry.yaw+math.pi+steps.Glow.TopFaceYaw,0))
		count=index
	end
	steps:show(count)
	self.glowCount=count
	self:stepGlow(0,Trail.Seconds)
end
-- A guide trail out of view (a menu, a trip out of the garden): hidden, kept, back when it can show again.
function Trail:hideGuide(hidden)
	if self.hidden==hidden then return end
	self.hidden=hidden
	if self.folder then self.folder.Parent=if hidden then nil else(self.d.world or workspace)end
end
-- Glow steps each step: the fade in (and out, unless a guide), the wave, the ring, and a leading pet's prints.
function Trail:stepGlow(since,left)
	local steps=self.steps
	if not steps then return end
	local reduced=self.d.reduced~=nil and self.d.reduced()==true
	local now=self.now()
	if self.leader then
		local model=self.leader
		local pet=nil
		if typeof(model)=="Instance"and model.Parent~=nil then
			local ok,pivot=pcall(model.GetPivot,model)
			if ok and pivot then pet=pivot.Position end
		end
		steps:leadStep(now,pet,self.d.root(),reduced,function(at)return self:groundUnder(at)end)
	elseif self.glowCount then
		local out=if self.guide then 1 else math.clamp(left/Trail.FadeOut,0,1)
		for index=1,self.glowCount do
			local shown=if reduced then 1 else math.clamp((since-index*Trail.FadeLag)/Trail.FadeIn,0,1)*out
			steps:fade(index,1-shown)
		end
	end
	steps:animate(now-(self.startedAt or now),reduced,workspace.CurrentCamera)
end
-- Under a leading pet: the ground with the pet and everyone's characters left out (one ray a print, not a frame).
function Trail:groundUnder(at)
	if self.d.groundUnder then return self.d.groundUnder(at,self.leader)end
	local params=self.leadParams
	if not params then params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;self.leadParams=params end
	local skip={self.leader}
	for _,other in ipairs(game:GetService("Players"):GetPlayers())do if other.Character then table.insert(skip,other.Character)end end
	params.FilterDescendantsInstances=skip
	local hit=workspace:Raycast(at+Vector3.new(0,2.5,0),Vector3.new(0,-7,0),params)
	return hit and hit.Position.Y
end
-- When a pet leads (glow only): the pet's own prints instead of the route's. nil ends it. True when it took.
function Trail:leadBy(model)
	if not self.glow or not self.target or not self.steps then return false end
	if model~=nil and typeof(model)~="Instance"then return false end
	self.leader=model
	self.steps:lead(model~=nil)
	return true
end
function Trail:leadHold(on)
	if self.steps then self.steps:hold(on)end
end
function Trail:step(dt)
	local target=self.target
	if not target then return end
	self.age+=dt
	local root=self.d.root()
	if not root or self.d.free()~=true then
		if self.guide then self:hideGuide(true);return end
		self:stop("left");return
	end
	if self.age>Trail.MenuGrace and self.d.busy()==true then
		if self.guide then self:hideGuide(true);return end
		self:stop("menu");return
	end
	if self.guide then self:hideGuide(false)end
	local distance=flat(root,target.position)
	local near=distance<=Trail.Arrive
	if near and(not self.spot or self.age>=Trail.Near)then self:stop("arrived");return end
	self:paintPin(distance)
	local left=Trail.Seconds-self.age
	if self.glow then
		if left<=0 and not self.guide then self:stop("time");return end
		self:stepGlow(if self.laidAt then self.age-self.laidAt else 0,left)
		return
	end
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
-- The pin by distance (Q1), written only when it changes; the name too, for a pin that changes (Trail.label).
function Trail:paintPin(distance)
	if not self.pin then return end
	local alpha=Trail.pinAlpha(distance,self.folder:GetAttribute("Way"))
	local text=Trail.label(self.target)
	if self.plate.Text~=text then self.plate.Text=text end
	if self.pinAlphaShown==alpha then return end
	self.pinAlphaShown=alpha
	self.pin.Enabled=alpha<1
	self.plate.BackgroundTransparency=alpha;self.plate.TextTransparency=alpha
	self.pointer.BackgroundTransparency=alpha;self.pinStroke.Transparency=alpha
end
-- Takes every part out of the world. The pool is kept for the next one.
function Trail:stop(reason)
	self.generation+=1
	if self.connection then self.connection:Disconnect();self.connection=nil end
	local was=self.target~=nil
	self.target,self.laidAt,self.painted,self.spot=nil,nil,nil,nil
	self.points,self.leader,self.glowCount,self.guide,self.hidden=nil,nil,nil,nil,nil
	if self.steps then self.steps:lead(false);self.steps:hold(false);self.steps:show(0);self.steps:target(nil)end
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
	if self.steps then self.steps:destroy();self.steps=nil end
	if self.folder then self.folder:Destroy();self.folder=nil end
end
return Trail
