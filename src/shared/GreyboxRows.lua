-- Greybox rows (the upper tier T0; the Hush's row shapes, for the tier only): pure rows from a local frame, and the
-- server's builder that turns rows into anchored matte Parts. A frame is a CFrame whose local X runs "a", local -Z
-- runs "b", and world heights are given directly. Row: {name, size, cframe, color (hex), material (an Enum.Material name,
-- default SmoothPlastic), collide, visible, shadow, tilted, light = {color, range, brightness}}.
local Rows={}

function Rows.new(prefix)
	local self={prefix=prefix or "",rows={}}
	local function add(row)table.insert(self.rows,table.freeze(row));return row end
	-- A box between (a1, b1, y1) and (a2, b2, y2) in `frame`.
	function self.block(name,frame,a1,b1,y1,a2,b2,y2,color,options)
		options=options or {}
		local mid=Vector3.new((a1+a2)/2,(y1+y2)/2-frame.Position.Y,-(b1+b2)/2)
		return add({name=self.prefix..name,size=Vector3.new(math.abs(a2-a1),math.abs(y2-y1),math.abs(b2-b1)),
			cframe=frame*CFrame.new(mid),color=color,material=options.material,collide=options.collide~=false,
			visible=options.visible~=false,shadow=options.shadow==true})
	end
	-- An invisible wall (players only).
	function self.wall(name,frame,a1,b1,y1,a2,b2,y2)
		return self.block(name,frame,a1,b1,y1,a2,b2,y2,"#FFFFFF",{visible=false})
	end
	-- A slab tilted along a: its top runs from height ya at a1 to yb at a2 (over b1..b2), `thick` deep.
	function self.slab(name,frame,a1,a2,b1,b2,ya,yb,thick,color,options)
		options=options or {}
		local run,rise=a2-a1,yb-ya
		local length=math.sqrt(run*run+rise*rise)
		local mid=Vector3.new((a1+a2)/2,(ya+yb)/2-frame.Position.Y,-(b1+b2)/2)
		local turn=CFrame.Angles(0,0,math.atan2(rise,run))
		return add({name=self.prefix..name,size=Vector3.new(length,thick,math.abs(b2-b1)),
			cframe=frame*CFrame.new(mid)*turn*CFrame.new(0,-thick/2,0),color=color,material=options.material,collide=true,visible=true,
			shadow=false,tilted=true})
	end
	-- A wall 1 thick along a plan segment (from, to: Vector3, heights ignored), from y1 to y2.
	function self.segment(name,from,to,y1,y2,options)
		options=options or {}
		local a,b=Vector3.new(from.X,(y1+y2)/2,from.Z),Vector3.new(to.X,(y1+y2)/2,to.Z)
		return add({name=self.prefix..name,size=Vector3.new(1,y2-y1,math.max((b-a).Magnitude,.2)),cframe=CFrame.lookAt((a+b)/2,b),
			color=options.color or "#FFFFFF",collide=true,visible=options.visible==true,shadow=false,tilted=true})
	end
	function self.light(name,position,color,range,brightness)
		return add({name=self.prefix..name,size=Vector3.new(.2,.2,.2),cframe=CFrame.new(position),color="#FFFFFF",collide=false,
			visible=false,shadow=false,light=table.freeze({color=color,range=range,brightness=brightness})})
	end
	return self
end

-- Server: the rows as anchored matte Parts in a Model called `name` (Persistent streaming). Every part is WorldMesh, so
-- bounds-based scans skip it as they skip the island meshes (rays still hit it); CanTouch off; CanQuery only on visible
-- solids (invisible walls block players, not rays, like the perimeter ring).
function Rows.build(rows,name)
	local model=Instance.new("Model")
	model.Name=name
	pcall(function()model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent end)
	for _,row in ipairs(rows)do
		local part=Instance.new("Part")
		part.Name=row.name
		part.Size,part.CFrame=row.size,row.cframe
		part.Anchored,part.CanCollide,part.CanTouch=true,row.collide,false
		part.CanQuery=row.collide and row.visible
		part.Transparency=if row.visible then 0 else 1
		part.CastShadow=row.shadow
		local ok,material=pcall(function()return Enum.Material[row.material or "SmoothPlastic"]end)
		part.Material=if ok and material then material else Enum.Material.SmoothPlastic
		part.Color=Color3.fromHex(row.color)
		part.TopSurface,part.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
		-- A cylinder row (size X = its height along its own X axis; the row's CFrame turns it upright).
		if row.shape=="cylinder"then pcall(function()part.Shape=Enum.PartType.Cylinder end)end
		part:SetAttribute("WorldMesh",true)
		if row.light then
			local l=Instance.new("PointLight")
			l.Color,l.Range,l.Brightness,l.Shadows=Color3.fromHex(row.light.color),row.light.range,row.light.brightness,false
			l.Parent=part
		end
		part.Parent=model
	end
	return model
end
return table.freeze(Rows)
