-- The hill at night (WORLD-FINISH-LOOK section 5 "Day and night", slice F; HillNight holds the numbers): the den's
-- lantern panes brighten as daylight falls under .4 (without leaving their amber hue), their lamps get the garden's own
-- night grading (HollowClock's HollowLamp attributes, written on this client only), and the glow-caps on the path's lip,
-- at the turn and at the lookout come up through dusk. All local to this client: nothing replicates, nothing is saved.
--
-- Gate: the Alive `scene` switch (ceiling: the beta place or Studio; live never mounts this), the island's sculpt in
-- (workspace CliffDen) and, for the glow-caps (they stand on the hill), the tier open (Tier.on). The gate closing puts
-- the panes' and lamps' own values back and hides the caps. It watches the attributes, so a late CliffDen or a switch
-- flipped at runtime is followed. Steps at 4 Hz; writes only on change. The den's model is found by name
-- (EggDropLounge.PlayDen) through the lounge's ChildAdded, never a scan of the whole lounge.
--
-- Instance state for probes (execute_luau has its own module cache): the folder workspace.HillNightLocal carries the
-- attributes HillLift (the panes' lift now), HillCaps (the caps' opacity), HillOn.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Night=require(Shared:WaitForChild("HillNight"))
local Client={};Client.__index=Client
Client.Rate=.25
Client.Pane="W7_F_Lantern__pane"
Client.Den="PlayDen"

-- deps (specs): daylight() -> number, gate() -> bool (the scene switch and the sculpt), tierOn() -> bool, room() ->
-- EggDropLounge, parent (the caps' folder parent), heartbeat, now.
function Client.mount(deps)
	deps=deps or {}
	local Alive=require(Shared:WaitForChild("Alive"))
	if deps.gate==nil and not Alive.ceiling("scene")then return nil end
	local self=setmetatable({d=deps,panes={},lights={},caps={},clock=0,connections={}},Client)
	self.daylight=deps.daylight or function()return require(script.Parent.HollowClock).daylight()end
	self.gate=deps.gate or function()return Alive.on("scene")==true and workspace:GetAttribute("CliffDen")==true end
	self.tierOn=deps.tierOn or function()return require(Shared:WaitForChild("Tier")).on()==true end
	self.room=deps.room or function()return workspace:FindFirstChild("EggDropLounge")end
	local folder=Instance.new("Folder");folder.Name="HillNightLocal"
	folder.Parent=deps.parent or workspace
	self.folder=folder
	if deps.heartbeat~=false then
		table.insert(self.connections,(deps.heartbeat or RunService.Heartbeat):Connect(function(dt)
			local ok,problem=pcall(self.step,self,dt)
			if not ok then
				warn("[HillNight] stopped: "..tostring(problem))
				pcall(self.destroy,self)
			end
		end))
	end
	return self
end

-- The den's lanterns: the panes (their own colour kept) and the lamps in the den's rows.
function Client:bindDen(den,force)
	if self.den==den and not force then return end
	self:restore()
	self.den=den
	if not den then return end
	for _,item in ipairs(den:GetDescendants())do
		-- (Part and MeshPart named too: the offline mocks' IsA knows only the exact class.)
		if item.Name==Client.Pane and(item:IsA("BasePart")or item:IsA("Part")or item:IsA("MeshPart"))then
			self.panes[item]=item.Color
		elseif item:IsA("PointLight")and string.match(item.Parent and item.Parent.Name or "","^W7D_Lantern%d+$")then
			self.lights[item]={lamp=item:GetAttribute("HollowLamp"),day=item:GetAttribute("HollowDayBrightness"),
				night=item:GetAttribute("HollowNightBrightness"),brightness=item.Brightness}
		end
	end
end
-- Every pane and lamp back to its own values.
function Client:restore()
	for pane,colour in pairs(self.panes)do if pane.Parent then pane.Color=colour end end
	for light,was in pairs(self.lights)do
		if light.Parent then
			light:SetAttribute("HollowLamp",was.lamp);light:SetAttribute("HollowDayBrightness",was.day)
			light:SetAttribute("HollowNightBrightness",was.night);light.Brightness=was.brightness
		end
	end
	table.clear(self.panes);table.clear(self.lights)
	self.lift=nil
end

-- The glow-caps: a short stem and a dome cap each, two or three to a spot, built once on first need.
local function part(name,shape,size,cframe,colour,material,parent)
	local p=Instance.new("Part");p.Name=name;p.Shape=shape;p.Size=size;p.CFrame=cframe
	p.Color=Color3.fromHex(colour);p.Material=material
	p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
	p.Transparency=1
	p.Parent=parent
	return p
end
function Client:buildCaps()
	if self.capsBuilt then return end
	self.capsBuilt=true
	local folder=Instance.new("Folder");folder.Name="GlowCaps";folder.Parent=self.folder
	for i,spot in ipairs(self.d.spots or Night.glowCaps())do
		local r=Random.new(spot.seed)
		for k=1,spot.cluster do
			local a=r:NextNumber()*math.pi*2
			local d=if k==1 then 0 else r:NextNumber(.25,.55)
			local h=r:NextNumber(.18,.34)
			local w=r:NextNumber(.22,.36)
			local base=spot.position+Vector3.new(math.cos(a)*d,0,math.sin(a)*d)
			local tilt=CFrame.Angles(r:NextNumber(-.15,.15),0,r:NextNumber(-.15,.15))
			local root=CFrame.new(base)*tilt
			local stem=part("GlowCapStem"..i.."_"..k,Enum.PartType.Cylinder,Vector3.new(h,w*.32,w*.32),
				root*CFrame.new(0,h/2,0)*CFrame.Angles(0,0,math.pi/2),Night.CapStem,Enum.Material.SmoothPlastic,folder)
			local cap=part("GlowCap"..i.."_"..k,Enum.PartType.Ball,Vector3.new(w,w*.55,w),root*CFrame.new(0,h,0),
				Night.CapColour,Enum.Material.Neon,folder)
			table.insert(self.caps,{stem=stem,cap=cap})
		end
	end
end
function Client:showCaps(alpha)
	if alpha>0 then self:buildCaps()end
	if self.capAlpha~=nil and math.abs(self.capAlpha-alpha)<.01 then return end
	self.capAlpha=alpha
	for _,c in ipairs(self.caps)do
		c.cap.Transparency=1-(1-Night.CapTransparency)*alpha
		c.stem.Transparency=1-alpha
	end
	self.folder:SetAttribute("HillCaps",math.floor(alpha*100+.5)/100)
end

function Client:step(dt)
	self.clock+=dt or 0
	if self.clock<Client.Rate then return end
	self.clock=0
	local on=self.gate()==true
	if on~=self.on then self.on=on;self.folder:SetAttribute("HillOn",on)end
	if not on then
		self:bindDen(nil)
		self:showCaps(0)
		return
	end
	local room=self.room()
	local den=room and room:FindFirstChild(Client.Den)
	-- A new den model (or none: the old one let go); one still replicating (no pane found yet) is looked at again every
	-- 2 s, five times at most (a den without the finish art has no panes).
	local now=(self.d.now or os.clock)()
	if den~=self.den then
		self:bindDen(den)
		self.rescans,self.rescanAt=0,now+2
	elseif den and next(self.panes)==nil and(self.rescans or 0)<5 and now>=(self.rescanAt or 0)then
		self.rescans=(self.rescans or 0)+1;self.rescanAt=now+2
		self:bindDen(den,true)
	end
	local daylight=self.daylight()
	local lift=Night.lanternLift(daylight)
	if self.lift==nil or math.abs(self.lift-lift)>.005 then
		self.lift=lift
		for pane,colour in pairs(self.panes)do if pane.Parent then pane.Color=Night.paneColour(colour,lift)end end
		for light,_ in pairs(self.lights)do
			if light.Parent then
				-- HollowClock grades a HollowLamp between its day and night brightness by daylight; ours follows the lift.
				light:SetAttribute("HollowLamp",true)
				light:SetAttribute("HollowDayBrightness",Night.LightDay)
				light:SetAttribute("HollowNightBrightness",Night.lightAt(lift))
			end
		end
		self.folder:SetAttribute("HillLift",math.floor(lift*1000+.5)/1000)
	end
	self:showCaps(if self.tierOn()then Night.capAlpha(daylight)else 0)
end

function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,c in ipairs(self.connections)do c:Disconnect()end
	pcall(self.restore,self)
	if self.folder then self.folder:Destroy()end
end
return Client
