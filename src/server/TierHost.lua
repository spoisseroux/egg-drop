-- The upper tier host (UPPER-TIER-BUILD-PLAN.md, architect verdict applied; the way up is the island's cliff path,
-- CLIFF-DEN-BUILD.md). mount() answers nil with the build ceiling off (live): nothing made, nothing connected, no world
-- data read. There is no remote and no client code: players walk up the cliff path; pets wait at its foot (Tier.covers
-- in the server's pet floor checks, and the pet-blocked footprints made here). The terrace opens only with the path in
-- (workspace CliffDen, set at start by CliffDenSwap); while it is closed the path's foot and notch are gated.
--
-- Mount (protected): the ring boxes that stand aside (Tier.ringAside) and the end closers (Tier.closers) from
-- WorldV7Data.perimeter; any failure, or no box found, keeps the tier closed with one warning.
-- Open (the switch on): every stood-aside box and both neighbours must exist in EggDropLounge.PerimeterWall, or the tier
-- stays closed with one warning. Then the greybox (TierGreybox rows) is built into EggDropLounge.Tier, the pet-blocked
-- footprints into EggDropLounge.PetRegions (GardenBlockedRegion set before parenting), the boxes stop colliding (each
-- one's own value kept), and `open` is true. `open` is what the pet floor checks and the island bounds read.
-- Close (the switch off, or MaxErrors errors), in one step, never yielding: everyone standing up there is moved to the
-- lawn by the foot (arrived() for the island bounds), the ring boxes that still exist get their value back, the model and
-- the footprints are destroyed, `open` is false. A rebuilt lounge drops all tier state (its parts went with the old one).
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Tier=require(Shared.Tier)
local Greybox=require(Shared.TierGreybox)
local GreyboxRows=require(Shared.GreyboxRows)

local Host={};Host.__index=Host

-- d: boards (player -> board), room() -> EggDropLounge, arrived(player, rootPosition) (island bounds), moved(player).
-- Specs may replace perimeter (the ring data), clock, heartbeat, read(board) -> view, place(board, view, cframe), warn.
function Host.mount(d)
	if not Tier.ceiling()then return nil end
	local self=setmetatable({d=d,open=false,errors=0,dead=false,tickAt=-math.huge,warned={},slot=0},Host)
	self.clock=d.clock or os.clock
	self.read=d.read or Host.read
	self.place=d.place or Host.place
	self.warn=d.warn or warn
	local ok,problem=pcall(function()
		local perimeter=d.perimeter or require(Shared.WorldV7Data).perimeter
		local aside,before,after=Tier.ringAside(perimeter)
		if #aside==0 or not before or not after then error("no ring box meets the tier")end
		-- Code review: one contiguous run, never wrapping past 1 / n (anything else is bad data: stay closed).
		if not Tier.ringRunOk(aside,#perimeter)then error("the ring boxes that meet the tier are not one run")end
		self.aside,self.neighbours=aside,{before,after}
		self.rows=Greybox.rows(Tier.closers(perimeter,before,after))
	end)
	if not ok then
		self.broken=true
		self:once("mount","[Tier] ring data: "..tostring(problem).."; the tier stays closed")
	end
	self.connection=(d.heartbeat or RunService.Heartbeat):Connect(function()
		if self.dead then return end
		local good,why=pcall(self.step,self)
		if not good then self:fail(why)end
	end)
	return self
end
function Host:once(key,text)
	if self.warned[key]then return end
	self.warned[key]=true
	pcall(self.warn,text)
end
-- Count an error (never reset by a success); at MaxErrors the tier closes on this server.
function Host:fail(problem)
	self.errors+=1
	pcall(self.warn,"[Tier] host: "..tostring(problem))
	if self.errors<Tier.MaxErrors or self.dead then return end
	self.dead=true
	pcall(function()self.connection:Disconnect()end)
	local ok,again=pcall(self.close,self)
	if not ok then pcall(self.warn,"[Tier] close: "..tostring(again))end
	pcall(self.gate,self,self:room(),Tier.cliff()) -- closed for good on this server: the path is gated
end
function Host:room()
	if self.d.room then return self.d.room()end
	return workspace:FindFirstChild("EggDropLounge")
end

function Host.read(board)
	local character=board.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or not character:IsDescendantOf(workspace)then return nil end
	local lift=humanoid.HipHeight+root.Size.Y/2+.1
	if humanoid.RigType==Enum.HumanoidRigType.R6 then
		local leg=character:FindFirstChild("Left Leg")
		if leg then lift+=leg.Size.Y end
	end
	return{character=character,root=root,position=root.Position,lift=lift}
end
function Host.place(_,view,cframe)
	view.character:PivotTo(cframe)
	view.root.AssemblyLinearVelocity=Vector3.zero
	view.root.AssemblyAngularVelocity=Vector3.zero
end

-- The pet-blocked footprints: the cliff path where it has left the lawn (Tier.PathLift), grown by Grow, one box per
-- PathBlock centre-line segments, as {name, cframe, size} at lawn height. Pure (spec'd: a catch-up spot on the path's
-- treads is refused). None without the path.
function Host.footprints(p)
	p=p or Tier.path()
	local out={}
	if not p then return out end
	local pts,n=p.points,#p.points
	local i=1
	while i<n do
		local j=math.min(i+Tier.PathBlock,n)
		if math.max(pts[i].Y,pts[j].Y)>=Tier.FootY+Tier.PathLift then
			local a,b=Vector3.new(pts[i].X,Tier.FootY+.5,pts[i].Z),Vector3.new(pts[j].X,Tier.FootY+.5,pts[j].Z)
			local w=0
			for k=i,j do w=math.max(w,p.widths[k])end
			local len=(b-a).Magnitude
			table.insert(out,{name=Tier.Blocked.."Path"..#out+1,cframe=CFrame.lookAt((a+b)/2,b),
				size=Vector3.new(w+2*Tier.Grow,1,len+2*Tier.Grow)})
		end
		i=j
	end
	return out
end

-- Open and close ----------------------------------------------------------------------------------------------
function Host:openUp(room)
	local ring=room:FindFirstChild(Tier.Ring)
	local refs={}
	for _,i in ipairs(self.aside)do
		local box=ring and ring:FindFirstChild("Wall"..i)
		if not box then
			self:once("ring","[Tier] "..Tier.Ring..".Wall"..i.." is missing; the tier stays closed")
			return false
		end
		table.insert(refs,box)
	end
	for _,i in ipairs(self.neighbours)do
		if not(ring and ring:FindFirstChild("Wall"..i))then
			self:once("ring","[Tier] "..Tier.Ring..".Wall"..i.." is missing; the tier stays closed")
			return false
		end
	end
	-- Code review: the model and the footprints are held before they are parented, so a throw part-way leaves nothing
	-- orphaned (the next step reuses them, or close() destroys them).
	self.builtIn=room
	if not self.model then
		self.model=GreyboxRows.build(self.rows,Tier.Model)
		-- The world finish art's terrace dress, only when its terrace slice is in this room's World (WorldFinishMount).
		local ok,problem=pcall(function()require(script.Parent.WorldFinishMount).dressTier(self.model,room)end)
		if not ok then warn("[WorldFinish] terrace dress: "..tostring(problem))end
	end
	self.model.Parent=room
	local regions=room:FindFirstChild("PetRegions")or room
	if not self.blocked then
		self.blocked={}
		for _,f in ipairs(Host.footprints())do
			local part=Instance.new("Part")
			table.insert(self.blocked,part)
			part.Name,part.CFrame,part.Size=f.name,f.cframe,f.size
			part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch=true,false,false,false
			part.Transparency,part.CastShadow=1,false
			part:SetAttribute("GardenBlockedRegion",true) -- before parenting: the garden scene's watcher reads it on arrival
		end
	end
	for _,part in ipairs(self.blocked)do part.Parent=regions end
	-- Each box's own value is recorded before it is changed, once (a retry after a throw keeps the first record).
	self.ring=self.ring or {}
	local held={}
	for _,entry in ipairs(self.ring)do held[entry.box]=true end
	for _,box in ipairs(refs)do
		if not held[box]then
			table.insert(self.ring,{box=box,collide=box.CanCollide})
			box.CanCollide=false
		end
	end
	self.open=true
	return true
end
-- Switch off with this player up there: to the lawn by the foot, held or not (the ground they stand on is going).
function Host:evacuate(player,board)
	local view=self.read(board)
	if not view or not(Tier.onIt(view.position)or Tier.onPathUp(view.position))then return false end
	self.slot=self.slot%#Tier.EvacuationOffsets+1
	local e=Tier.Evacuation
	local frame=CFrame.lookAt(e.at,Vector3.new(e.facing.X,e.at.Y,e.facing.Z))*CFrame.new(Tier.EvacuationOffsets[self.slot])
	local root=frame+Vector3.new(0,view.lift or 3,0)
	self.place(board,view,root)
	if self.d.arrived then self.d.arrived(player,root.Position)elseif self.d.moved then self.d.moved(player)end
	return true
end
function Host:close()
	if self.open then
		for player,board in pairs(self.d.boards)do
			if not board.closing then
				local ok,problem=pcall(self.evacuate,self,player,board)
				if not ok then pcall(self.warn,"[Tier] evacuate: "..tostring(problem))end
			end
		end
	end
	for _,entry in ipairs(self.ring or {})do
		if entry.box.Parent then entry.box.CanCollide=entry.collide end
	end
	self.ring=nil
	if self.model then self.model:Destroy()end
	for _,part in ipairs(self.blocked or {})do part:Destroy()end
	self.model,self.blocked,self.builtIn=nil,nil,nil
	self.open=false
end
function Host:step()
	local now=self.clock()
	if now-self.tickAt<Tier.Tick then return end
	self.tickAt=now
	local room=self:room()
	-- A rebuilt (or removed) lounge took the tier's parts with it: drop the state, never touch the old parts.
	if self.builtIn and room~=self.builtIn then
		self.ring,self.model,self.blocked,self.builtIn,self.open=nil,nil,nil,nil,false
	end
	local cliff=Tier.cliff()
	local on=not self.broken and cliff and Tier.on()and room~=nil
	if on and not self.open then self:openUp(room)
	elseif not on and(self.open or self.model)then self:close()end
	-- The path's foot and notch are gated while the terrace is closed (the path is part of the island: it stays).
	self:gate(room,cliff and room~=nil and not self.open)
end
-- The gates: built into the lounge while wanted, destroyed otherwise (a rebuilt lounge gets fresh ones).
function Host:gate(room,want)
	if want and self.gatesIn~=room then
		if self.gateModel then self.gateModel:Destroy()end
		self.gateModel,self.gatesIn=nil,nil
		local gates=Tier.gates()
		if not gates then return end
		local model=GreyboxRows.build(Greybox.gates(gates),Tier.Gates)
		self.gateModel=model
		model.Parent=room
		self.gatesIn=room
	elseif not want and self.gateModel then
		self.gateModel:Destroy()
		self.gateModel,self.gatesIn=nil,nil
	end
end
return Host
