-- The Garden Dash line's rope ring and its edge (beta 14 QA F2; WORLD-AND-NEST-LOOK section 5, NEST-AND-RACE-LINE-
-- BUILD-PLAN section 4 and its architect review). Client only. DashClient owns one while Dash is on.
--   * The ring: 10 wooden stakes with chalk caps, 10 sagging rope beams and a trampled ground ring round the waiting pad,
--     local parts nothing can touch, stand on or query. Everyone sees it while DashRing.wanted(roster): it rises when
--     wanted (stakes up out of the lawn one after another, then the rope), and sinks DashRing.SinkAfter after it is not.
--     Reduced Motion and AliveBudget level 2: a plain fade, no rise.
--   * The edge: no wall parts (they would catch the pet's taps and raycasts). While this player waits (the line or a
--     gather seat) and once their root has been inside DashRing.Enter, Stepped puts the root back on that circle and
--     takes away the outward part of its velocity. Pushing on it sways the two nearest spans and calls onPush (the
--     rail line pulses), at most every PushEvery. The server's stray rule (DashHost) has the last word.
-- deps: root() -> BasePart?, humanoid() -> Humanoid?, reduced(), level() (AliveBudget), onPush(), ground(at) -> y?,
--   world (default workspace), stepped (a signal; false: specs call :clampStep), clock (default os.clock).
local RunService=game:GetService("RunService")
local Ring=require(game:GetService("ReplicatedStorage").Shared.DashRing)
local Line={};Line.__index=Line
Line.Folder="EggDropDashLine"
Line.Color=table.freeze({stake=Color3.fromHex("#6B4A2B"),chalk=Color3.fromHex("#E9E2C8"),rope=Color3.fromHex("#B79A66")})
-- Script-drawn textures (scripts/draw_race_line_textures.py), their ids once uploaded; nil draws without them (the rope
-- plain #B79A66, no ground ring).
Line.Art=table.freeze({rope=nil,ring=nil})
Line.RopeTile=.6 -- studs of rope a texture repeat
local N=Ring.Stakes
Line.Total=Ring.Rise+(N-1)*Ring.RiseLag+Ring.RopeFade

local function easeOut(x)x=math.clamp(x,0,1);return 1-(1-x)*(1-x)end
-- Pure: stake k's rise (0 under the lawn .. 1 up) and the rope's and plate's see-through (0 shown .. 1 gone) at `e`
-- seconds into the rise (counted back down as it sinks). Plain: everything at full height, all fading over ReducedFade.
function Line.pose(e,k,plain)
	if plain then
		local shown=math.clamp(e/Ring.ReducedFade,0,1)
		return 1,1-shown,1-shown
	end
	local rise=easeOut((e-(k-1)*Ring.RiseLag)/Ring.Rise)
	local rope=math.clamp((e-(Ring.Rise+(N-1)*Ring.RiseLag))/Ring.RopeFade,0,1)
	return rise,if rise>0 then 0 else 1,1-rope
end
-- Pure: the sag at `t` seconds into a sway (nil: none).
function Line.sag(t)
	if t==nil or t<0 or t>=Ring.Sway then return Ring.Sag end
	return Ring.Sag+(Ring.SwaySag-Ring.Sag)*math.sin(t/Ring.Sway*math.pi)
end
-- Pure: the two spans nearest an outward direction (span k runs from stake k to stake k + 1).
function Line.nearSpans(out)
	local a=math.atan2(out.Z,out.X)%(2*math.pi)
	local step=2*math.pi/N
	local k=math.floor(a/step)%N+1 -- the span this direction crosses
	local other=if(a/step)%1<.5 then(k-2)%N+1 else k%N+1
	return k,other
end
-- Pure: a stake's turn by its number (no two the same).
function Line.yaw(k)return((k*2654435761)%360)/360*2*math.pi end

function Line.new(deps)
	local self=setmetatable({d=deps,e=0,state="down",waiting=false,entered=false,sway={},pushAt=-math.huge},Line)
	self.clock=deps.clock or os.clock
	return self
end
function Line:plain()
	local d=self.d
	if d.reduced and d.reduced()==true then return true end
	return d.level~=nil and d.level()>=2
end
-- Builds the parts once, the first time the ring is wanted.
function Line:build()
	if self.folder then return end
	local d=self.d
	local folder=Instance.new("Folder");folder.Name=Line.Folder
	local centre=Ring.centre()
	self.centre=centre
	local function still(p)
		p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Massless=true
		return p
	end
	self.stakes={}
	for k=1,N do
		local a,foot=Ring.stake(k,centre)
		local y=centre.Y
		if d.ground then
			local ok,hit=pcall(d.ground,foot)
			if ok and type(hit)=="number"and math.abs(hit-centre.Y)<=1 then y=hit end
		end
		local stake=still(Instance.new("Part"));stake.Name="Stake"..k;stake.Size=Ring.StakeSize;stake.Color=Line.Color.stake
		stake.Material=Enum.Material.Wood;stake.Transparency=1
		local cap=still(Instance.new("Part"));cap.Name="Cap"..k;cap.Size=Vector3.new(Ring.StakeSize.X+.01,Ring.CapHeight,Ring.StakeSize.Z+.01)
		cap.Color=Line.Color.chalk;cap.Material=Enum.Material.SmoothPlastic;cap.Transparency=1
		-- Upright frame at the foot: lean out StakeLean about the tangent, turned by its hash about its own axis.
		local out=Vector3.new(math.cos(a),0,math.sin(a))
		local base=CFrame.new(foot.X,y,foot.Z)*CFrame.fromAxisAngle(Vector3.new(-out.Z,0,out.X),math.rad(Ring.StakeLean))
		local top=Instance.new("Attachment");top.Name="Top"
		-- The attachment's axis (its X) points down, so positive CurveSize sags the rope.
		top.CFrame=CFrame.new(0,Ring.StakeSize.Y/2,0)*CFrame.Angles(0,0,-math.pi/2)
		top.Parent=stake
		stake.Parent=folder;cap.Parent=folder
		self.stakes[k]={stake=stake,cap=cap,base=base,yaw=Line.yaw(k),top=top}
	end
	self.beams={}
	for k=1,N do
		local beam=Instance.new("Beam");beam.Name="Rope"..k
		beam.Attachment0=self.stakes[k].top;beam.Attachment1=self.stakes[k%N+1].top
		beam.Width0=Ring.RopeWidth;beam.Width1=Ring.RopeWidth;beam.Segments=8;beam.FaceCamera=true
		beam.Color=ColorSequence.new(Line.Color.rope);beam.LightEmission=0;beam.LightInfluence=1
		if Line.Art.rope then beam.Texture=Line.Art.rope;beam.TextureMode=Enum.TextureMode.Wrap;beam.TextureLength=Line.RopeTile end
		beam.CurveSize0=Ring.curve(Ring.Sag);beam.CurveSize1=-Ring.curve(Ring.Sag)
		beam.Transparency=NumberSequence.new(1);beam.Enabled=false
		beam.Parent=self.stakes[k].stake
		self.beams[k]=beam
	end
	if Line.Art.ring then
		local plate=still(Instance.new("Part"));plate.Name="Ground";plate.Size=Vector3.new(Ring.PlateSize,.05,Ring.PlateSize);plate.Transparency=1
		plate.CFrame=CFrame.new(centre.X,centre.Y+.04,centre.Z)
		local decal=Instance.new("Decal");decal.Face=Enum.NormalId.Top;decal.Texture=Line.Art.ring;decal.Transparency=1;decal.Parent=plate
		plate.Parent=folder
		self.decal=decal
	end
	self.painted=nil
	folder.Parent=d.world or workspace
	self.folder=folder
end
-- Every frame (DashClient's step): `wanted` is DashRing.wanted(roster), `now` any clock in seconds.
function Line:frame(dt,wanted,now)
	if wanted then
		self.emptyAt=nil
		if self.state=="down"or self.state=="sinking"then self:build();self.state="rising"end
	elseif self.state=="rising"or self.state=="up"then
		self.emptyAt=self.emptyAt or now
		if now-self.emptyAt>=Ring.SinkAfter then self.state="sinking"end
	end
	local plain=self:plain()
	local total=if plain then Ring.ReducedFade else Line.Total
	if self.plainWas~=plain then self.plainWas=plain;self.e=math.min(self.e,total);self.painted=nil end
	if self.state=="rising"then
		self.e=math.min(total,self.e+dt)
		if self.e>=total then self.state="up"end
	elseif self.state=="sinking"then
		self.e=math.max(0,self.e-dt)
		if self.e<=0 then self.state="down"end
	end
	local swaying=next(self.sway)~=nil
	if self.folder and(self.painted~=self.e or swaying)then self:paint(plain)end
	if self.state=="down"and self.folder then self.folder.Parent=nil elseif self.folder and self.folder.Parent==nil then self.folder.Parent=self.d.world or workspace end
end
function Line:paint(plain)
	self.painted=self.e
	local clock=self.clock()
	local h=Ring.StakeSize.Y
	local ropeAlpha=1
	for k,s in ipairs(self.stakes)do
		local rise,alpha,rope=Line.pose(self.e,k,plain)
		ropeAlpha=rope
		local sink=(1-rise)*(h+Ring.CapHeight)
		local frame=s.base*CFrame.new(0,h/2-Ring.StakeSink-sink,0)*CFrame.Angles(0,s.yaw,0)
		s.stake.CFrame=frame
		s.cap.CFrame=frame*CFrame.new(0,h/2-Ring.CapHeight/2+.005,0)
		if s.stake.Transparency~=alpha then s.stake.Transparency=alpha;s.cap.Transparency=alpha end
	end
	for k,beam in ipairs(self.beams)do
		local started=self.sway[k]
		local t=started and clock-started
		if t and t>=Ring.Sway then self.sway[k]=nil;t=nil end
		local c=Ring.curve(Line.sag(t))
		beam.CurveSize0=c;beam.CurveSize1=-c
		beam.Enabled=ropeAlpha<1
		beam.Transparency=NumberSequence.new(ropeAlpha)
	end
	if self.decal then self.decal.Transparency=ropeAlpha end
end
-- Is this player waiting (DashClient: in the line or holding a gather seat, not held by a race)?
function Line:setWaiting(waiting)
	waiting=waiting==true
	if waiting==self.waiting then return end
	self.waiting=waiting
	if not waiting then
		self.entered=false
		if self.stepConn then self.stepConn:Disconnect();self.stepConn=nil end
		return
	end
	local stepped=self.d.stepped
	if stepped==nil then stepped=RunService.Stepped end
	if stepped then
		self.stepConn=stepped:Connect(function()
			local ok,problem=pcall(self.clampStep,self)
			if not ok then warn("[Dash] line: "..tostring(problem))end
		end)
	end
end
-- Stepped while waiting: the root back on the Enter circle, no outward speed; a push sways the rope.
function Line:clampStep()
	if not self.waiting then return false end
	local root=self.d.root and self.d.root()
	if not root then return false end
	-- A new character (a respawn on the dais) has not walked in: the latch starts again for it.
	if root~=self.rootRef then self.rootRef=root;self.entered=false end
	local centre=self.centre or Ring.centre()
	local at=root.Position
	local distance=Ring.distance(at,centre)
	if distance<=Ring.Enter then self.entered=true end
	if not self.entered then return false end
	-- Further than the stray reach is a teleport, not a walk: never drag it back (the server's stray rule decides).
	if distance>Ring.Stray then self.entered=false;return false end
	local back,out=Ring.clamp(at,centre,Ring.Enter)
	if not back then return false end
	root.CFrame=root.CFrame+(back-at)
	local v=root.AssemblyLinearVelocity
	local outward=v:Dot(out)
	if outward>0 then root.AssemblyLinearVelocity=v-out*outward end
	local humanoid=self.d.humanoid and self.d.humanoid()
	local move=humanoid and humanoid.MoveDirection
	if typeof(move)=="Vector3"and move:Dot(out)>Ring.PushDot then self:push(out)end
	return true
end
function Line:push(out)
	local now=self.clock()
	if now-self.pushAt<Ring.PushEvery then return false end
	self.pushAt=now
	if not self:plain()and self.beams then
		local a,b=Line.nearSpans(out)
		self.sway[a]=now;self.sway[b]=now
	end
	if self.d.onPush then pcall(self.d.onPush)end
	return true
end
function Line:destroy()
	self:setWaiting(false)
	if self.folder then self.folder:Destroy();self.folder=nil end
	self.stakes,self.beams,self.decal=nil,nil,nil
	self.state,self.e="down",0
end
return Line
