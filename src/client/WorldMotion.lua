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

function Motion.new(world)
	local self=setmetatable({world=world or workspace,entries={},beams={},skins={},emitters={},connections={},elapsed=0,still=false},Motion)
	return self
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
					far=part:GetAttribute("WorldMotionFar")==true,transparency=part.Transparency})
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

function Motion:rest()
	local parts,frames={},{}
	for _,e in ipairs(self.entries)do
		if e.part.Parent then
			if e.kind=="pulse"then e.part.Transparency=e.transparency
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
		for _,emitter in ipairs(self.emitters)do emitter.Enabled=true end
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
	for _,e in ipairs(self.entries)do
		local part=e.part
		if not part.Parent then continue end
		if eye and not e.far and(e.rest.Position-eye).Magnitude>Motion.Range+part.Size.Magnitude*.5 then continue end
		if e.kind=="pulse"then
			part.Transparency=e.transparency+e.amp*(.5+.5*math.sin(TAU*(t/e.period+e.phase)))
		else
			table.insert(parts,part);table.insert(frames,Motion.pose(e.kind,e.rest,e.pivot,e.amp,e.period,e.phase,t))
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
	return self
end

return Motion
