-- Bumble balls: the look, from Parts for now (GARDEN-PLAY-BRIEF section 1 "Look"; our own 300-tri meshes and 256 px
-- textures replace these later). Matte, believable, never a sports ball: Felt is wool felt with a cream seam band,
-- Wicker is woven rattan with two darker bands, Cork is speckled cork with a brass ring. A blob shadow under each.
-- Anchored, CanCollide/CanQuery/CanTouch off, client only (workspace.BumbleBallsLocal).
--
-- Squash: the body is a SpecialMesh sphere so it can squash along world up while the bands spin with travel.
-- Look.MeshSquash = false keeps a plain Ball part (no squash) if the mesh ever hides the material in Studio.
local Balls=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BumbleBalls"))
local Look={};Look.__index=Look
Look.MeshSquash=true
local function material(name,fallback)
	local ok,value=pcall(function()return Enum.Material[name]end)
	return if ok and value then value else fallback
end
-- band: offset along the spin axis (local X), width, colour, material.
Look.Kinds=table.freeze({
	felt=table.freeze({color="#E8785A",material="Fabric",bands={{offset=0,width=.12,color="#F4E8CF",material="Fabric"}}}),
	wicker=table.freeze({color="#C9A36B",material="WoodPlanks",bands={{offset=-.5,width=.16,color="#8A6A3C",material="Wood"},
		{offset=.5,width=.16,color="#8A6A3C",material="Wood"}}}),
	cork=table.freeze({color="#B98A5E",material="Cardboard",fallback="Sand",bands={{offset=0,width=.15,color="#D9B24C",material="Metal"}}}),
})
Look.ShadowColor="#2E2A20"
Look.ShadowAlpha=.55       -- transparency on the ground
Look.ShadowFade=8          -- studs over the ground at which it is faintest

local function part(name,shape,size,color,mat)
	local p=Instance.new("Part")
	p.Name=name;p.Shape=shape;p.Size=size;p.Color=Color3.fromHex(color);p.Material=mat
	p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
	p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
	return p
end

function Look.build(id,parent)
	local kind=Look.Kinds[id]
	local R=Balls.Radius
	local model=Instance.new("Model");model.Name="BumbleBall_"..id
	local body=part("Body",Enum.PartType.Ball,Vector3.one*R*2,kind.color,material(kind.material,material(kind.fallback or "Fabric",Enum.Material.Fabric)))
	body.Parent=model
	local mesh=nil
	if Look.MeshSquash then mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=body end
	local bands={}
	for i,band in ipairs(kind.bands)do
		-- A disc through the ball, a hair wider than the ball's section there: only its rim shows, as a band.
		local d=2*math.sqrt(math.max(0,R*R-band.offset*band.offset))+.05
		local size=Vector3.new(band.width,d,d)
		local p=part("Band"..i,Enum.PartType.Cylinder,size,band.color,material(band.material,Enum.Material.Wood))
		p.Parent=model
		table.insert(bands,{part=p,offset=CFrame.new(band.offset,0,0),size=size})
	end
	local shadow=part("Shadow",Enum.PartType.Cylinder,Vector3.new(.06,R*1.9,R*1.9),Look.ShadowColor,Enum.Material.SmoothPlastic)
	shadow.Transparency=Look.ShadowAlpha
	shadow.Parent=model
	local self=setmetatable({id=id,model=model,body=body,mesh=mesh,bands=bands,shadow=shadow,spin=CFrame.identity,turns=0,scale=1,parent=parent},Look)
	self.parts={body}
	for _,band in ipairs(bands)do table.insert(self.parts,band.part)end
	table.insert(self.parts,shadow)
	model.Parent=parent
	return self
end

-- Roll the bands with travel: `delta` is the drawn move since the last frame.
function Look:roll(delta)
	local along=Vector3.new(delta.X,0,delta.Z)
	local distance=along.Magnitude
	if distance<1e-4 then return end
	local axis=Vector3.yAxis:Cross(along/distance)
	self.spin=CFrame.fromAxisAngle(axis,distance/Balls.Radius)*self.spin
	self.turns+=1
	if self.turns>=120 then self.turns=0;self.spin=self.spin:Orthonormalize()end
end

-- Draw at `position` (the ball's centre), fade `scale`, vertical `squash` (0..), the ground's height under it.
function Look:draw(position,scale,squash,groundY)
	local R=Balls.Radius
	squash=if self.mesh then squash else 0
	if scale~=self.scale then
		self.scale=scale
		local s=math.max(.01,scale)
		if not self.mesh then self.body.Size=Vector3.one*R*2*s end
		for _,band in ipairs(self.bands)do band.part.Size=band.size*s end
		self.shadow.Size=Vector3.new(.06,R*1.9*s,R*1.9*s)
	end
	if self.mesh then
		local s=math.max(.01,scale)
		self.mesh.Scale=Vector3.new((1+squash*.5)*s,(1-squash)*s,(1+squash*.5)*s)
	end
	local centre=position-Vector3.new(0,R*squash*scale,0)
	local frames={CFrame.new(centre)}
	local turned=CFrame.new(centre)*self.spin
	for _,band in ipairs(self.bands)do table.insert(frames,turned*band.offset)end
	local lift=math.max(0,position.Y-R-groundY)
	table.insert(frames,CFrame.new(position.X,groundY+.04,position.Z)*CFrame.Angles(0,0,math.pi/2))
	self.shadow.Transparency=Look.ShadowAlpha+(1-Look.ShadowAlpha)*math.clamp(lift/Look.ShadowFade,0,.8)
	workspace:BulkMoveTo(self.parts,frames,Enum.BulkMoveMode.FireCFrameChanged)
end
function Look:show(on)
	local want=if on then self.parent else nil
	if self.model.Parent~=want then self.model.Parent=want end
end
function Look:destroy()self.model:Destroy()end
return Look
