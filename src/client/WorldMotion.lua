-- Client-only ambient motion for the v7 island: islets, drifting rocks and the
-- cloud sea bob, chimes, pennants and the hatch-tree lantern sway, the distant
-- castle flags wave, the cradle mobile turns, glow parts pulse, the falls beams
-- and the water skins scroll and the foam throws spray. Cheap (about 55 parts at
-- 30 Hz, one BulkMoveTo) and fully still while Reduced Motion is on.
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")

local Motion={}
Motion.__index=Motion
Motion.Rate=1/30
Motion.Range=900
-- Alive step 4: how far a full gust widens a mover. Amplitude only, so the phase never jumps; every
-- other mover, and all of them with no wind, keep today's pose exactly (WindClient sets motion.gust).
Motion.FlagGust,Motion.ChimeGust=1.8,2.5

local TAU=math.pi*2

function Motion.pose(kind,rest,pivot,amp,period,phase,t)
	local wave=math.sin(TAU*(t/period+phase))
	if kind=="bob"then return rest+Vector3.new(0,amp*wave,0)end
	if kind=="flag"then
		-- A pennant waves about its vertical pole: two sines so the beat never repeats exactly.
		local flap=(wave+.35*math.sin(TAU*(t/period*2.3+phase*1.7)))/1.35
		local at=pivot or rest.Position
		return CFrame.new(at)*CFrame.Angles(0,math.rad(amp)*flap,0)*CFrame.new(-at)*rest
	end
	if kind=="sway"or kind=="spin"then
		local angle=math.rad(amp)*wave
		local turn=if kind=="spin"then CFrame.Angles(0,angle,0)else CFrame.Angles(angle,0,angle*.35)
		local at=pivot or rest.Position
		return CFrame.new(at)*turn*CFrame.new(-at)*rest
	end
	return rest
end

-- Beta 14 QA W3 row 2 (WORLD-AND-NEST-LOOK section 1): with the Alive `scene` switch on (the beta place and Studio:
-- its ceiling), the five arrival chimes swing along the wind about their hanging point:
-- angle = (3 + 11 g) * sin(2 pi .45 t + 1.3 k) degrees, g the gust (or the big breath) where they hang, k the chime's
-- number; written at 15 Hz (8 at budget level 1) and only within 70 studs of the camera. Off: today's sway exactly.
-- [check] in Studio that W7_Chime_1..5 are separate movers after the re-export (Fable saw them still); their saturation
-- x .75 is the island session's (a palette texture).
Motion.Chime=table.freeze({rest=3,gust=11,hz=.45,phase=1.3,range=70,rate=15,slowRate=8,sceneEvery=1})
local Wind=require(script.Parent.Wind)
local Side=Vector3.new(-Wind.Direction.Z,0,Wind.Direction.X)
function Motion.chimeNumber(region)
	if type(region)~="string"or region:sub(1,6)~="Chime_"then return nil end
	return tonumber(region:sub(7))
end
function Motion.chimePose(rest,pivot,g,t,k)
	local C=Motion.Chime
	g=if type(g)=="number"and g==g then math.clamp(g,0,1)else 0
	local angle=math.rad((C.rest+C.gust*g)*math.sin(TAU*C.hz*t+k*C.phase))
	local at=pivot or rest.Position
	return CFrame.new(at)*CFrame.fromAxisAngle(Side,angle)*CFrame.new(-at)*rest
end

function Motion.gustGain(kind,region)
	if kind=="flag"then return Motion.FlagGust end
	if kind~="sway"or type(region)~="string"then return nil end
	if region:sub(1,6)=="Chime_"then return Motion.ChimeGust end
	if region:sub(1,8)=="Pennant_"then return Motion.FlagGust end
	return nil
end
function Motion.gusted(amp,gain,gust)
	if type(gust)~="number"or gust~=gust or gust<=0 then return amp end
	return amp*(1+(gain-1)*math.min(gust,1))
end

function Motion.new(world)
	local self=setmetatable({world=world or workspace,entries={},beams={},skins={},emitters={},connections={},elapsed=0,still=false},Motion)
	return self
end

-- A part's own transparency: a part the egg corner hides keeps it in CornerWas ("<transparency>|...").
function Motion.restTransparency(part)
	if part:GetAttribute("WorldHidden")==true then
		local was=part:GetAttribute("CornerWas")
		local t=type(was)=="string"and tonumber(string.match(was,"^([^|]+)"))
		if t then return t end
	end
	return part.Transparency
end

function Motion:bind(room)
	table.clear(self.entries);table.clear(self.beams);table.clear(self.skins);table.clear(self.emitters)
	self.room=room
	if not room then return end
	local meshes=room:FindFirstChild("World")
	if meshes then
		for _,part in ipairs(meshes:GetChildren())do
			local kind=part:IsA("BasePart")and part:GetAttribute("WorldMotion")
			if kind then
				table.insert(self.entries,{part=part,kind=kind,rest=part:GetAttribute("WorldRestCFrame")or part.CFrame,
					pivot=part:GetAttribute("WorldPivot"),amp=part:GetAttribute("WorldMotionAmp")or 0,
					period=math.max(part:GetAttribute("WorldMotionPeriod")or 1,.1),phase=part:GetAttribute("WorldMotionPhase")or 0,
					gain=Motion.gustGain(kind,part:GetAttribute("WorldRegion")),
					chime=if kind=="sway"then Motion.chimeNumber(part:GetAttribute("WorldRegion"))else nil,chimeAt=0,
					far=part:GetAttribute("WorldMotionFar")==true,transparency=Motion.restTransparency(part)})
			end
		end
		-- Scrolling water skins (Texture on the water meshes, LoungeWorldV7Art.WaterSkins).
		for _,skin in ipairs(meshes:GetDescendants())do
			if skin:IsA("Texture")and skin:GetAttribute("WorldFlowU")then table.insert(self.skins,skin)end
		end
	end
	local flow=room:FindFirstChild("WaterFlow")
	if flow then
		for _,beam in ipairs(flow:GetDescendants())do
			if beam:IsA("Beam")then table.insert(self.beams,beam)
			elseif beam:IsA("ParticleEmitter")then table.insert(self.emitters,beam)end
		end
	end
	self.still=nil
end

function Motion:reduced()
	return GuiService.ReducedMotionEnabled
end
-- The Alive `scene` switch, read at most once a second (false on the live place: the ceiling). Specs replace it.
function Motion:sceneOn(t)
	if self.sceneAt and t<self.sceneAt then return self.scene==true end
	self.sceneAt=t+Motion.Chime.sceneEvery
	local ok,on=pcall(function()
		local Alive=self.alive or require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Alive"))
		return Alive.on("scene")
	end)
	self.scene=ok and on==true
	return self.scene
end
-- Budget level 1 or more (the chimes' slower rate).
function Motion:slow()
	local ok,level=pcall(function()return require(script.Parent.AliveBudget).level()end)
	return ok and type(level)=="number"and level>=1
end

function Motion:rest()
	local parts,frames={},{}
	for _,e in ipairs(self.entries)do
		if e.part.Parent then
			-- The egg corner hides the old station's halo (WorldHidden, EggCornerWorld): a pulse never shows it again.
			if e.kind=="pulse"then if e.part:GetAttribute("WorldHidden")~=true then e.part.Transparency=e.transparency end
			else table.insert(parts,e.part);table.insert(frames,e.rest)end
		end
	end
	if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
	for _,beam in ipairs(self.beams)do beam.TextureSpeed=0 end
	for _,emitter in ipairs(self.emitters)do emitter.Enabled=false end
end

function Motion:apply(t)
	local reduced=self:reduced()
	if reduced then
		if self.still~=true then self:rest();self.still=true end
		return
	end
	if self.still~=false then
		for _,beam in ipairs(self.beams)do beam.TextureSpeed=beam:GetAttribute("WorldFlowSpeed")or .15 end
		-- The Hidden Grove's hidden backdrop (GroveWorld, attribute GroveHidden) stays off. When the grove gives one back
		-- it returns in the Reduced Motion state of that moment (GroveWorld.settleBackdrop, this rule: on unless
		-- reduced), so skipping it here never leaves it off with motion on, nor on under Reduced Motion.
		for _,emitter in ipairs(self.emitters)do if emitter:GetAttribute("GroveHidden")~=true then emitter.Enabled=true end end
		self.still=false
	end
	for _,skin in ipairs(self.skins)do
		if skin.Parent then
			skin.OffsetStudsU=((skin:GetAttribute("WorldFlowU")or 0)*t)%skin.StudsPerTileU
			skin.OffsetStudsV=((skin:GetAttribute("WorldFlowV")or 0)*t)%skin.StudsPerTileV
		end
	end
	local camera=workspace.CurrentCamera
	local eye=camera and camera.CFrame.Position
	local parts,frames={},{}
	local scene=self:sceneOn(t)
	for _,e in ipairs(self.entries)do
		local part=e.part
		if not part.Parent then continue end
		if eye and not e.far and(e.rest.Position-eye).Magnitude>Motion.Range+part.Size.Magnitude*.5 then continue end
		-- ARCH-REVIEW-GROVE 2: a part the Hidden Grove hides (GroveWorld) stops stepping until it shows again. After the
		-- cheap range check, so an out-of-range mover never reads its attribute.
		if part:GetAttribute("GroveHidden")==true then continue end
		if e.chime and scene then
			-- Beta 14 W3 row 2: the chime's own swing, at its own rate, near the camera only.
			if t<e.chimeAt or(eye and(e.rest.Position-eye).Magnitude>Motion.Chime.range)then continue end
			e.chimeAt=t+1/(if self:slow()then Motion.Chime.slowRate else Motion.Chime.rate)
			local gust=0
			if self.gust then
				local ok,value=pcall(self.gust,e)
				if ok then gust=value else self.gust=nil end
			end
			table.insert(parts,part);table.insert(frames,Motion.chimePose(e.rest,e.pivot,gust,t,e.chime))
			continue
		end
		if e.kind=="pulse"then
			if part:GetAttribute("WorldHidden")==true then continue end
			part.Transparency=e.transparency+e.amp*(.5+.5*math.sin(TAU*(t/e.period+e.phase)))
		else
			local amp=e.amp
			if e.gain and self.gust then
				local ok,gust=pcall(self.gust,e)
				if ok then amp=Motion.gusted(amp,e.gain,gust)else self.gust=nil end
			end
			table.insert(parts,part);table.insert(frames,Motion.pose(e.kind,e.rest,e.pivot,amp,e.period,e.phase,t))
		end
	end
	if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
end

function Motion:step(dt)
	self.elapsed+=dt
	if self.elapsed<Motion.Rate then return end
	self.elapsed=0
	-- Late replication: retry the scan a few times until the island's movers arrive.
	if self.room and #self.entries==0 and(self.rescans or 0)<20 and os.clock()>=(self.rescanAt or 0)then
		self.rescans=(self.rescans or 0)+1;self.rescanAt=os.clock()+2;self:bind(self.room)
	end
	self:apply(os.clock())
end

function Motion:destroy()
	for _,c in ipairs(self.connections)do c:Disconnect()end
	table.clear(self.connections)
	self.destroyed=true
	if self.wind then self.wind:destroy();self.wind=nil end
	if self.room then self:rest()end
end

function Motion.start()
	local self=Motion.new(workspace)
	local function watch(room)
		if room and room.Name=="EggDropLounge"then
			-- The server builds the island before parenting the lounge.
			self:bind(room)
		end
	end
	table.insert(self.connections,workspace.ChildAdded:Connect(watch))
	table.insert(self.connections,workspace.ChildRemoved:Connect(function(item)if item==self.room then self:bind(nil)end end))
	watch(workspace:FindFirstChild("EggDropLounge"))
	table.insert(self.connections,RunService.Heartbeat:Connect(function(dt)self:step(dt)end))
	-- The wind is paint: whatever happens to it, the movers above keep going and boot never waits.
	task.spawn(function()
		local ok,wind=pcall(function()
			local Alive=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Alive"))
			-- Not on this place at all (the live game): nothing is loaded or connected.
			if not Alive.ceiling("wind")then return nil end
			return require(script.Parent.WindClient).start({motion=self})
		end)
		if not ok then warn("[Wind] not started: "..tostring(wind));return end
		if not wind then return end
		if self.destroyed then wind:destroy()else self.wind=wind end
	end)
	return self
end

return Motion
