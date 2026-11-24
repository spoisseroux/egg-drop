-- The Hush on this client (HUSH-GREYBOX-BUILD-PLAN.md section 4 and 7). mount() answers nil with the build ceiling off.
--   * The passage: walking into a door's trigger (Hush.Doors) while the garden is free and the Hush is open fades the
--     screen to black at once and asks the server (HushPassage {kind="go", door, seq}); one ask per entry (leave the box
--     to ask again). "arrived": hold black until the root is at the arrival and there is ground under it (at most
--     GroundWait), then fade in. "refused" or no answer in ClientTimeout: fade straight back in. "out" (the owner's
--     /hush go and home): fade out and wait the same way. "evacuated" (the switch went off): fade in if dark.
--     Controls are never taken. Reduced Motion: the same plain fade.
--   * In the Hush (from the root's position, every EffectsEvery): the world music ducked out for DuckFor seconds,
--     refreshed each pass (so a crash or a stall gives it back), and Lighting.HushGrade, a cool tint. Leaving, a new
--     character, the switch off or destroy() take both away.
-- d: remotes (Folder), player, audio (BoardAudio: duck), root() -> BasePart?, character() -> Model?, free() -> bool,
-- lighting (Lighting), gui (the PlayerGui). Specs may replace heartbeat, clock, open() -> bool, ground(position) -> bool.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Hush=require(Shared:WaitForChild("Hush"))

local Client={};Client.__index=Client
Client.GradeTint=Color3.fromHex("#E6F2EC")
Client.GradeSaturation=-.08

function Client.mount(d)
	if not Hush.ceiling()then return nil end
	local self=setmetatable({d=d,seq=0,inside={},alpha=0,target=0,effectsAt=-math.huge},Client)
	self.clock=d.clock or os.clock
	self.open=d.open or function()return workspace:GetAttribute(Hush.Attribute)==true end
	self.ground=d.ground or function(position)return Client.ground(self,position)end
	pcall(self.remote,self)
	local beat=d.heartbeat or game:GetService("RunService").Heartbeat
	self.beat=beat:Connect(function(dt)
		local ok,problem=pcall(self.step,self,dt)
		if not ok and not self.warned then self.warned=true;warn("[Hush] client: "..tostring(problem))end
	end)
	return self
end
function Client.ground(self,position)
	local params=RaycastParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	local character=self.d.character and self.d.character()
	params.FilterDescendantsInstances=if character then{character}else{}
	params.RespectCanCollide=true
	return workspace:Raycast(position,Vector3.new(0,-12,0),params)~=nil
end

-- The black ---------------------------------------------------------------------------------------------------
function Client:curtain()
	if self.frame and self.frame.Parent then return self.frame end
	local gui=Instance.new("ScreenGui")
	gui.Name="HushFade"
	gui.IgnoreGuiInset,gui.ResetOnSpawn,gui.DisplayOrder=true,false,90
	local frame=Instance.new("Frame")
	frame.Name="Black"
	frame.Size=UDim2.fromScale(1,1)
	frame.BackgroundColor3=Color3.new(0,0,0)
	frame.BorderSizePixel=0
	frame.BackgroundTransparency=1
	frame.Visible=false
	frame.Parent=gui
	gui.Parent=self.d.gui
	self.screen,self.frame=gui,frame
	return frame
end
function Client:fadeOut()self.target=1;self:curtain()end
function Client:fadeIn()self.target=0;self.arrival=nil;self.pending=nil end
function Client:paint(dt)
	if self.alpha==self.target then return end
	local rate=if self.target>self.alpha then 1/Hush.FadeOut else 1/Hush.FadeIn
	self.alpha=if self.target>self.alpha then math.min(self.target,self.alpha+rate*dt)else math.max(self.target,self.alpha-rate*dt)
	local frame=self:curtain()
	frame.BackgroundTransparency=1-self.alpha
	frame.Visible=self.alpha>0
end

-- The passage -------------------------------------------------------------------------------------------------
function Client:remote()
	if self.link then return self.link end
	local remote=self.d.remotes and self.d.remotes:FindFirstChild(Hush.Remote)
	if not remote then return nil end
	self.link=remote
	self.listen=remote.OnClientEvent:Connect(function(packet)
		local ok,problem=pcall(self.receive,self,packet)
		if not ok and not self.warned then self.warned=true;warn("[Hush] client: "..tostring(problem))end
	end)
	return remote
end
function Client:ask(door)
	local remote=self:remote()
	if not remote then return false end
	self.seq+=1
	self.pending={seq=self.seq,at=self.clock()}
	self:fadeOut()
	remote:FireServer({kind="go",door=door,seq=self.seq})
	return true
end
function Client:receive(packet)
	if type(packet)~="table"then return end
	local kind=packet.kind
	if kind=="out"then
		self.pending={seq=packet.seq,at=self.clock()}
		self:fadeOut()
	elseif kind=="arrived"then
		if not self.pending or packet.seq~=self.pending.seq then return end
		self.pending=nil
		self.arrival={at=self.clock(),to=if typeof(packet.at)=="Vector3"then packet.at else nil}
	elseif kind=="refused"then
		if self.pending and packet.seq==self.pending.seq then self:fadeIn()end
	elseif kind=="evacuated"then
		if self.target>0 then self:fadeIn()end
	end
end

-- The pass ----------------------------------------------------------------------------------------------------
function Client:step(dt)
	self:remote()
	local now=self.clock()
	local root=self.d.root()
	local position=root and root.Position
	local open=self.open()
	-- Doors: one ask per entry, only while free and open.
	for id,door in pairs(Hush.Doors)do
		local inside=open and position~=nil and Hush.inBox(door.trigger,position)
		if inside and not self.inside[id]then
			self.inside[id]=true
			if not self.pending and not self.arrival and self.d.free()then self:ask(id)end
		elseif not inside then
			self.inside[id]=nil
		end
	end
	-- Waiting: no answer, or the far side under our feet.
	if self.pending and now-self.pending.at>Hush.ClientTimeout then self:fadeIn()end
	if self.arrival and self.alpha>=1 then
		local there=position~=nil and(self.arrival.to==nil or(position-self.arrival.to).Magnitude<=Hush.Near)
		if(there and self.ground(position))or now-self.arrival.at>=Hush.GroundWait then self:fadeIn()end
	end
	self:paint(dt)
	-- Region effects.
	local character=self.d.character and self.d.character()
	if character~=self.character then
		self.character=character
		self:clearGrade()
		self.effectsAt=-math.huge
	end
	if now-self.effectsAt>=Hush.EffectsEvery then
		self.effectsAt=now
		local inHush=open and position~=nil and Hush.regionAt(position)=="hush"
		self.inHushNow=inHush
		if inHush then
			if self.d.audio and self.d.audio.duck then self.d.audio:duck(Hush.Duck,Hush.DuckFor,0)end
			self.ducked=true
			self:grade()
		else
			self:release()
		end
	end
end
-- For other modules (a garden life or ambience quiet hook): is this client in the Hush now?
function Client:inHush()return self.inHushNow==true end
function Client:grade()
	local lighting=self.d.lighting
	if not lighting then return end
	local grade=lighting:FindFirstChild(Hush.Grade)
	if not grade then
		grade=Instance.new("ColorCorrectionEffect")
		grade.Name=Hush.Grade
		grade.TintColor,grade.Saturation=Client.GradeTint,Client.GradeSaturation
		grade.Parent=lighting
	end
	self.gradeEffect=grade
end
function Client:clearGrade()
	local lighting=self.d.lighting
	local grade=self.gradeEffect or(lighting and lighting:FindFirstChild(Hush.Grade))
	if grade then grade:Destroy()end
	self.gradeEffect=nil
end
function Client:release()
	if self.ducked and self.d.audio and self.d.audio.duck then self.d.audio:duck(Hush.Duck,0,1)end
	self.ducked=false
	self.inHushNow=false
	self:clearGrade()
end
function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true
	if self.beat then self.beat:Disconnect()end
	if self.listen then self.listen:Disconnect()end
	pcall(self.release,self)
	if self.screen then self.screen:Destroy()end
end
return Client
