-- The garden understory on this client (GARDEN-B38-BRIEF 4b, P1; Shared.Understory has the why, the rules and the
-- numbers): the round and flowering bushes and the reed clumps as MeshParts cloned from one runtime copy of each uploaded
-- mesh (AssetService:CreateMeshPartAsync: MeshId is not scriptable), textured from the one atlas, each bush over a soft
-- blob decal. All anchored and inert (no collide, query or touch, no shadow); bushes and reeds always draw (the engine
-- culls what is off screen), only the motion is near the camera.
--
-- Motion: reeds lean downwind with Wind.swayAt (breeze, gusts, the big breath) and wobble on their own period; bushes
-- shiver only on a strong blow (Wind.blow over Understory.Motion.bush.strong). One loop at 20 Hz within 120 studs of the
-- camera (60 on a phone), stepped with BulkMoveTo; budget level 1: 10 Hz within 40; level 2, Reduced Motion or out of the
-- garden (Mode not Room): every plant back at rest and the loop idles.
--
-- Gate: the Alive `scene` switch (beta and Studio only); off, nothing is built, and turning it off takes it all down. A
-- mesh or the atlas still pending upload (UnderstoryArt id nil) draws nothing of that kind.
--
-- Probe: workspace.UnderstoryLocal (attributes UnderstoryParts, UnderstoryBlobs, UnderstoryMoving).
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local U=require(Shared:WaitForChild("Understory"))
local Wind=require(Shared:WaitForChild("Wind"))

local Client={};Client.__index=Client
Client.Folder="UnderstoryLocal"

local function inert(p)
	p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
	return p
end
local function material(name)
	local ok,value=pcall(function()return(Enum.Material::any)[name]end)
	return if ok and value~=nil then value else Enum.Material.Plastic
end
-- One runtime copy of an uploaded mesh, or nil (no id yet, a failed download).
local function createMesh(id)
	local AssetService=game:GetService("AssetService")
	local ok,part=pcall(function()return AssetService:CreateMeshPartAsync(Content.fromUri(id))end)
	if ok and part then return part end
	ok,part=pcall(function()return AssetService:CreateMeshPartAsync(id)end)
	return if ok then part else nil
end

-- deps (specs): alive, art (UnderstoryArt), mesh(kind, id) -> MeshPart?, parent, heartbeat (false: the spec steps),
-- now() (server time), camera() -> Vector3?, reduced(), phone(), level(), mode(), move(parts, frames), worldVersion.
function Client.mount(deps)
	deps=deps or {}
	local alive=deps.alive or require(Shared:WaitForChild("Alive"))
	if not alive.ceiling(U.Feature)then return nil end
	local version=deps.worldVersion
	if version==nil then
		local ok,World=pcall(function()return require(Shared:WaitForChild("HollowWorldLayout"))end)
		version=ok and World.WorldVersion
	end
	if version~="v7"then return nil end
	local self=setmetatable({d=deps,alive=alive,art=deps.art or U.Art,built=false,records={},connections={},clock=0,
		moving=false,generation=0,cache={}},Client)
	self.now=deps.now or function()return workspace:GetServerTimeNow()end
	self.camera=deps.camera or function()
		local camera=workspace.CurrentCamera
		return camera and camera.CFrame.Position
	end
	self.reduced=deps.reduced or function()return game:GetService("GuiService").ReducedMotionEnabled==true end
	self.phone=deps.phone or function()
		local input=game:GetService("UserInputService")
		return input.TouchEnabled==true and input.KeyboardEnabled~=true
	end
	self.level=deps.level or function()
		local ok,level=pcall(function()return require(script.Parent.AliveBudget).level()end)
		return if ok and type(level)=="number"then level else 0
	end
	self.mode=deps.mode or function()return "Room"end
	self.mesh=deps.mesh or function(_,id)return createMesh(id)end
	self.move=deps.move or function(parts,frames)workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
	table.insert(self.connections,alive.changed(U.Feature):Connect(function()self:sync()end))
	if deps.heartbeat~=false then
		table.insert(self.connections,game:GetService("RunService").Heartbeat:Connect(function(dt)self:step(dt)end))
	end
	self:sync()
	return self
end

function Client:sync()
	if self.destroyed then return end
	local on=self.alive.on(U.Feature)==true
	if on==self.built then return end
	self.generation+=1
	if on then
		-- The meshes download (CreateMeshPartAsync yields): build off the caller's thread, and drop the result if the
		-- switch went off (or on again) meanwhile.
		self.built=true
		local generation=self.generation
		task.spawn(function()
			local ok,problem=pcall(self.build,self,generation)
			if not ok then
				warn("[Understory] build failed: "..tostring(problem))
				if self.generation==generation then self:teardown()end
			end
		end)
	else
		self:teardown()
	end
end

-- One template a kind, kept for the session (a switch flip never downloads twice); nil while its uploads are pending.
function Client:template(kind)
	local art=self.art
	if not art.ready(kind,art)then return nil end
	local cached=self.cache[kind]
	if cached==nil then
		cached=self.mesh(kind,art.Meshes[kind].id)or false
		if cached then inert(cached)end
		self.cache[kind]=cached
	end
	return cached or nil
end

function Client:build(generation)
	local templates={}
	for _,kind in ipairs(U.Kinds)do templates[kind]=self:template(kind)end
	if self.destroyed or self.generation~=generation or not self.built then return end
	local folder=Instance.new("Folder");folder.Name=Client.Folder
	self.folder=folder
	local art,look=self.art,U.Look
	local parts,blobs=0,0
	local blobTexture=if art.filled(art.Blob)then art.Blob else nil
	for _,kind in ipairs(U.Kinds)do
		local template=templates[kind]
		if not template then continue end
		for index,row in ipairs(U.rows(kind))do
			local frame,size,foot=U.frame(kind,row,art)
			local p=inert(template:Clone())
			p.Name=kind.."_"..index
			p.Size=size;p.CFrame=frame
			p.TextureID=art.Atlas
			p.Color=Color3.new(1,1,1);p.Material=material(look.material);p.Reflectance=0
			p:SetAttribute("UnderstorySite",row[#row])
			p.Parent=folder
			parts+=1
			local phase,period=U.phase(#self.records+1)
			table.insert(self.records,{part=p,rest=frame,foot=foot,kind=kind,phase=phase,period=period,posed=false})
			if kind~="reeds"and blobTexture then
				local across=row[4]*look.blobScale
				local plate=inert(Instance.new("Part"))
				plate.Name=kind.."_blob_"..index
				plate.Transparency=1
				plate.Size=Vector3.new(across,.05,across)
				plate.CFrame=CFrame.new(foot+Vector3.new(0,.12+look.blobLift,0))*CFrame.Angles(0,row[6],0)
				local decal=Instance.new("Decal")
				decal.Name="Blob";decal.Face=Enum.NormalId.Top;decal.Texture=blobTexture
				decal.Color3=look.blobColour;decal.Transparency=look.blobTransparency
				decal.Parent=plate
				plate.Parent=folder
				blobs+=1
			end
		end
	end
	folder:SetAttribute("UnderstoryParts",parts)
	folder:SetAttribute("UnderstoryBlobs",blobs)
	folder:SetAttribute("UnderstoryMoving",false)
	folder.Parent=self.d.parent or workspace
end

function Client:teardown()
	self.built=false
	table.clear(self.records)
	self.moving=false
	if self.folder then pcall(function()self.folder:Destroy()end)end
	self.folder=nil
end

-- Every plant back at rest (once: only the posed ones are written).
function Client:rest()
	local parts,frames={},{}
	for _,r in ipairs(self.records)do
		if r.posed then r.posed=false;table.insert(parts,r.part);table.insert(frames,r.rest)end
	end
	if #parts>0 then pcall(self.move,parts,frames)end
	if self.moving then
		self.moving=false
		if self.folder then self.folder:SetAttribute("UnderstoryMoving",false)end
	end
end

function Client:step(dt)
	if self.destroyed or not self.built or #self.records==0 then return end
	local level=self.level()
	local still=level>=2 or self.reduced()==true or self.mode()~="Room"
	if still then self:rest();return end
	local M=U.Motion
	local rate=if level>=1 then M.slowRate else M.rate
	self.clock+=dt
	if self.clock<rate then return end
	self.clock=0
	local camera=self.camera()
	if typeof(camera)~="Vector3"then self:rest();return end
	local range=if level>=1 then M.range.slow elseif self.phone()then M.range.phone else M.range.desktop
	local time=self.now()
	local parts,frames={},{}
	local any=false
	for _,r in ipairs(self.records)do
		local d=r.foot-camera
		if d.X*d.X+d.Z*d.Z<=range*range then
			local degrees
			if r.kind=="reeds"then
				degrees=U.reedLean(Wind.swayAt(r.foot,time),time,r.phase,r.period)
			else
				degrees=U.bushShiver(Wind.blow(r.foot,time),time,r.phase)
			end
			if degrees~=0 or r.posed then
				table.insert(parts,r.part);table.insert(frames,U.pose(r.rest,r.foot,degrees,Wind.Direction))
				r.posed=degrees~=0
				any=any or r.posed
			end
		elseif r.posed then
			r.posed=false
			table.insert(parts,r.part);table.insert(frames,r.rest)
		end
	end
	if #parts>0 then pcall(self.move,parts,frames)end
	if any~=self.moving then
		self.moving=any
		if self.folder then self.folder:SetAttribute("UnderstoryMoving",any)end
	end
end

function Client:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,c in ipairs(self.connections)do c:Disconnect()end
	table.clear(self.connections)
	self:teardown()
	for _,template in pairs(self.cache)do if template then pcall(function()template:Destroy()end)end end
	table.clear(self.cache)
end

return Client
