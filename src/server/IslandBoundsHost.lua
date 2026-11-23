-- Island edges host (WORLD-PASS-2026-11-22 item 5, slice 1): the wall top-ups and the safe-spot return. mount() answers
-- nil with the build ceiling off: nothing made, nothing connected. While the runtime switch is off there are no walls
-- and no returns; turning it off destroys the folder and forgets every safe spot. FallCatch stays the last resort.
-- Everything runs on its own protected connection: an error here never reaches the round, the garden or a save.
--
-- Safe spot, per player, server memory only: sampled once a second, the root's position is kept when the humanoid is
-- alive and standing (FloorMaterial not Air), not seated, the root not anchored, over IslandGround's safe ground (grass,
-- soft ground or path, low, inside the ring, walkable with the walls up) and no higher than SafeTopY, and the server
-- has not moved the character in the last Quiet seconds (moved(player) from the server's own teleports; a new
-- character counts, and so does a leap between two samples no walker can make).
-- Return: when the root falls below FallY or leaves the ring by more than Margin, the character is put back at the
-- last safe spot (PivotTo, velocity zeroed), or the arrival spawn when there is none; at most once per Cooldown, and
-- never in the Quiet after a server move. Never while deck mode, a hatch or a Dash race holds the player, while
-- seated or anchored, or while the board is closing.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").Shared
local Bounds=require(Shared.IslandBounds)

local Host={};Host.__index=Host
Host.Tick=.1        -- the fall check's step
Host.MaxErrors=3    -- errors in a row before this server gives up on the feature (walls down)

-- d: boards (player -> board), spawnFrame(board, view) -> CFrame (the arrival dais).
-- Specs may replace clock(), heartbeat, parent (the folder's parent), read(board) -> view, place(board, view, cframe).
function Host.mount(d)
	if not Bounds.ceiling()then return nil end
	local self=setmetatable({d=d,records={},isOpen=false,errors=0,tickAt=-math.huge},Host)
	self.clock=d.clock or os.clock
	self.read=d.read or Host.read
	self.place=d.place or Host.place
	local beat;beat=(d.heartbeat or RunService.Heartbeat):Connect(function()
		local ok,problem=pcall(self.step,self)
		if ok then self.errors=0;return end
		self.errors+=1
		warn("[Bounds] host: "..tostring(problem))
		if self.errors>=Host.MaxErrors then
			self.dead=true
			beat:Disconnect()
			pcall(self.close,self)
		end
	end)
	self.connection=beat
	return self
end
function Host:on()return not self.dead and Bounds.on()end

-- The character as plain values, or nil when there is none in the world.
function Host.read(board)
	local character=board.player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or not character:IsDescendantOf(workspace)then return nil end
	return{character=character,root=root,humanoid=humanoid,position=root.Position,look=root.CFrame.LookVector,alive=humanoid.Health>0,
		grounded=humanoid.FloorMaterial~=Enum.Material.Air,anchored=root.Anchored,
		seated=humanoid.Sit or humanoid:GetState()==Enum.HumanoidStateType.Seated}
end
function Host.place(_,view,cframe)
	view.character:PivotTo(cframe)
	view.root.AssemblyLinearVelocity=Vector3.zero
	view.root.AssemblyAngularVelocity=Vector3.zero
end
-- Deck mode, a hatch on the save, or a Dash race: the same board fields init and DashHost read.
function Host.held(board)
	if board.closing or board.mode~="Room"or board.dashHeld then return true end
	local state=board.nursery and board.nursery.state
	return state~=nil and state.lastHatch~=nil
end

-- Walls ----------------------------------------------------------------------------------------------------------
function Host:open()
	self.isOpen=true
	if self.folder then return end
	local folder=Instance.new("Folder")
	folder.Name=Bounds.Folder
	for _,w in ipairs(Bounds.Walls)do
		local cframe,size=Bounds.box(w)
		local part=Instance.new("Part")
		part.Name=w.id
		part.Size,part.CFrame=size,cframe
		part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch=true,true,false,false
		part.Transparency,part.CastShadow=1,false
		part.Material=Enum.Material.SmoothPlastic
		part.Parent=folder
	end
	folder.Parent=self.d.parent or workspace
	self.folder=folder
end
function Host:close()
	self.isOpen=false
	if self.folder then self.folder:Destroy();self.folder=nil end
	self.records={}
end

-- The step --------------------------------------------------------------------------------------------------------
function Host:step()
	local on=self:on()
	if on~=self.isOpen then
		if on then self:open()else self:close()end
	end
	if not on then return end
	local now=self.clock()
	if now-self.tickAt<Host.Tick then return end
	self.tickAt=now
	local boards=self.d.boards
	for player,rec in pairs(self.records)do
		if boards[player]~=rec.board then self.records[player]=nil end
	end
	for player,board in pairs(boards)do
		if not board.closing then self:check(player,board,now)end
	end
end
function Host:record(player,board)
	local rec=self.records[player]
	if not rec or rec.board~=board then
		rec={board=board,movedAt=-math.huge,externalAt=-math.huge,returnedAt=-math.huge,sampledAt=-math.huge,returns=0}
		self.records[player]=rec
	end
	return rec
end
function Host:check(player,board,now)
	local view=self.read(board)
	if not view then return end
	local rec=self:record(player,board)
	if view.character~=rec.character then -- a new character: Lounge.spawn moves it
		rec.character,rec.safe,rec.last=view.character,nil,nil
		rec.movedAt,rec.externalAt=now,now
	end
	if not view.alive or Host.held(board)then rec.last=nil;return end
	if Bounds.gone(view.position)then
		self:rescue(board,view,rec,now)
		return
	end
	if now-rec.sampledAt<Bounds.SampleEvery then return end
	rec.sampledAt=now
	local at,last=view.position,rec.last
	rec.last=at
	if now-rec.movedAt<Bounds.Quiet then return end
	if last and(at-last).Magnitude>Bounds.Leap then rec.movedAt=now;return end
	if not view.grounded or view.seated or view.anchored or at.Y>Bounds.SafeTopY then return end
	if not Bounds.safeCell(at.X,at.Z)then return end
	rec.safe=at
end
function Host:rescue(board,view,rec,now)
	if view.seated or view.anchored then return end
	if now-rec.returnedAt<Bounds.Cooldown or now-rec.externalAt<Bounds.Quiet then return end
	local target
	if rec.safe then
		local look=Vector3.new(view.look.X,0,view.look.Z)
		local at=rec.safe+Vector3.new(0,Bounds.Lift,0)
		target=if look.Magnitude>1e-3 then CFrame.lookAt(at,at+look.Unit)else CFrame.new(at)
	elseif self.d.spawnFrame then
		target=self.d.spawnFrame(board,view)
	end
	if not target then return end
	rec.returnedAt,rec.movedAt,rec.last=now,now,nil
	rec.returns+=1
	self.place(board,view,target)
end

-- The server's own teleports (Lounge.spawn, FallCatch): no sample and no return for Quiet seconds.
function Host:moved(player)
	local rec=self.records[player]
	if not rec then return end
	local now=self.clock()
	rec.movedAt,rec.externalAt,rec.last=now,now,nil
end
-- closeBoard: the player is leaving.
function Host:leave(board)
	local player=board.player
	if player and self.records[player]and self.records[player].board==board then self.records[player]=nil end
end
return Host
