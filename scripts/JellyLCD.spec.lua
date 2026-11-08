-- Real LocalScript + ScreenGui, explicit pooled backend. No EditableImage permission required.
return function(client,parent)
	assert(parent:IsA("ScreenGui") and parent.Enabled,"enabled ScreenGui required")
	local LCD=require(client.JellyLCD);local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local Palette=require(game.ReplicatedStorage.Shared.JellyPalette)
	local root=Instance.new("Frame");root.Name="_JellyLCDSpec";root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(354,594);root.Parent=parent
	local RunService=game:GetService("RunService");local cases,instances={},{ }
	local function test(name,run)run();table.insert(cases,name)end
	local function settle()RunService.Heartbeat:Wait();RunService.Heartbeat:Wait()end
	local function fixture(limit)
		local lcd=assert(LCD.new(root,{backend="span",maxSpans=limit or 1536}));table.insert(instances,lcd);settle();return lcd
	end
	local function bounds(lcd,tone)
		local x0,y0,x1,y1,count=LCD.Width,LCD.Height,-1,-1,0
		for y=0,LCD.Height-1 do for x=0,LCD.Width-1 do
			local offset=(y*LCD.Width+x)*4;local pixel=buffer.readu32(lcd.pixels,offset)
			if (tone and pixel==tone)or(not tone and pixel~=buffer.readu32(lcd.background,offset))then
				x0,y0,x1,y1,count=math.min(x0,x),math.min(y0,y),math.max(x1,x),math.max(y1,y),count+1
			end
		end end
		return{x0=x0,y0=y0,x1=x1,y1=y1,count=count,w=x1-x0+1,h=y1-y0+1}
	end
	local function rgba(c)return math.floor(c.R*255+.5)+math.floor(c.G*255+.5)*256+math.floor(c.B*255+.5)*65536+4278190080 end
	local ok,problem=pcall(function()
		local lcd=fixture()
		test("all five tier hues retain rim lower body upper and tight cream light at authored small size",function()
			local center=Vector2.new(LCD.Width/2,LCD.Height*.45)
			for tier,entry in ipairs(Config.Tiers)do
				local radius=entry.radius*LCD.Width/(Config.Width+.8);lcd:beginFrame();lcd:draw(center,radius,radius,0,entry.color,0)
				local roles=Palette.byTier[tier]
				for _,role in ipairs({"rim","lower","body","upper","glint"})do assert(bounds(lcd,rgba(roles[role])).count>0,"missing "..role.." in tiny tier "..tier)end
				local light=bounds(lcd,rgba(roles.glint));local gel=bounds(lcd)
				assert(light.count<gel.count*.12 and light.x1<center.X and light.y1<center.Y,"cream light covers mark center or dominates tier "..tier)
			end
		end)
		test("automatic backend proves a writable first frame before selecting its owner",function()
			local automatic=assert(LCD.new(root));table.insert(instances,automatic);settle()
			assert(automatic.backend=="span"or automatic.backend=="image")
			automatic:beginFrame();automatic:draw(Vector2.new(LCD.Width/2,LCD.Height*.45),6,6,0,Config.Tiers[1].color,0)
			assert(automatic:finishFrame() and not automatic.failed,"default renderer claimed an inaccessible image")
			automatic:destroy()
		end)
		test("logical grid follows tray aspect with near-square native cells",function()
			assert(LCD.Width==64 and LCD.Height==math.round(64*(Config.Height+.8)/(Config.Width+.8)))
			assert(math.abs((root.AbsoluteSize.X/LCD.Width)/(root.AbsoluteSize.Y/LCD.Height)-1)<=.5/LCD.Height+.0001)
		end)
		test("standing circles and rotated squash extents match common tray projection within one cell",function()
			local center=Vector2.new(LCD.Width/2,LCD.Height*.45);local radius=Config.Tiers[2].radius*LCD.Width/(Config.Width+.8)
			for _,shape in ipairs({{1,1,0},{1.35,.65,0},{1.35,.65,math.pi/4},{1.35,.65,math.pi/2},{1.35,.65,-math.pi/4}})do
				lcd:beginFrame();lcd:draw(center,radius*shape[1],radius*shape[2],shape[3],Config.Tiers[2].color,0);local box=bounds(lcd)
				local c,s=math.cos(shape[3]),math.sin(shape[3]);local rx,ry=radius*shape[1],radius*shape[2]
				local expectedW,expectedH=2*math.sqrt((rx*c)^2+(ry*s)^2),2*math.sqrt((rx*s)^2+(ry*c)^2)
				assert(math.abs(box.w-expectedW)<=1.01 and math.abs(box.h-expectedH)<=1.01,"ellipse projection: "..box.w.."x"..box.h.." vs "..expectedW.."x"..expectedH)
			end
		end)
		test("two physically touching circles retain neighboring silhouettes",function()
			local center=Vector2.new(LCD.Width/2,math.floor(LCD.Height*.45));local radius=7
			lcd:beginFrame();lcd:draw(center-Vector2.new(radius,0),radius,radius,0,Config.Tiers[1].color,0);local a=bounds(lcd)
			lcd:beginFrame();lcd:draw(center+Vector2.new(radius,0),radius,radius,0,Config.Tiers[2].color,0);local b=bounds(lcd)
			assert(a.x1+1==b.x0 and a.h==b.h,"touching pieces visually overlap or separate")
		end)
		test("light stays in upper-left tray quadrant through sideways deformation and final merge",function()
			local color=Config.Tiers[2].color;local bright=rgba(Palette.resolve(color).glint);local center=Vector2.new(LCD.Width/2,LCD.Height*.45)
			for _,angle in ipairs({0,math.pi/4,math.pi/2,-math.pi/4})do
				lcd:beginFrame();lcd:draw(center,13,9,angle,color,0);local light=bounds(lcd,bright)
				assert(light.count>0 and (light.x0+light.x1)/2<center.X and (light.y0+light.y1)/2<center.Y,"painted light rotated with shape")
			end
			lcd:beginFrame();lcd:merge(center-Vector2.new(9,0),center+Vector2.new(9,0),center,10,13,color,LCD.MergeDuration)
			local light=bounds(lcd,bright);assert(light.count>0 and (light.x0+light.x1)/2<center.X and (light.y0+light.y1)/2<center.Y)
		end)
		test("shared rounded cell edges stay contiguous through fractional native resizing",function()
			for _,size in ipairs({Vector2.new(354,594),Vector2.new(203,341),Vector2.new(71,120)})do
				root.Size=UDim2.fromOffset(size.X,size.Y);settle();lcd:beginFrame();lcd:draw(Vector2.new(LCD.Width/2,LCD.Height*.45),12,12,0,Config.Tiers[1].color,0);assert(lcd:finishFrame())
				local surface=lcd.surface;settle()
				assert(surface.root.ClipsDescendants,"outer renderer clip must remain")
				assert(surface.edgesX[0]==0 and surface.edgesX[LCD.Width]==root.AbsoluteSize.X)
				assert(surface.edgesY[0]==0 and surface.edgesY[LCD.Height]==root.AbsoluteSize.Y)
				for x=1,LCD.Width do assert(surface.edgesX[x]>=surface.edgesX[x-1])end
				for y=1,LCD.Height do
					assert(surface.edgesY[y]>=surface.edgesY[y-1])
					local row=surface.rowHosts[y];assert(not row.ClipsDescendants,"row clip can introduce scaled seams")
					if y<LCD.Height then
						local gap=surface.rowHosts[y+1].AbsolutePosition.Y-row.AbsolutePosition.Y-row.AbsoluteSize.Y
						assert(math.abs(gap)<.01,"native row edge gap/overlap: "..gap.." row="..y.." size="..tostring(size))
					end
				end
			end
		end)
		test("pooled repeated rows reuse instances and clear every stale span after disappearance",function()
			local created=lcd:getStats().dynamicCreated;local allocated=#lcd.surface.root:GetDescendants()
			for index=1,12 do lcd:beginFrame();lcd:draw(Vector2.new(LCD.Width*.45+index*.25,LCD.Height*.45),12,9,index*.04,Config.Tiers[3].color,0);assert(lcd:finishFrame())end
			assert(lcd:getStats().dynamicCreated==created and #lcd.surface.root:GetDescendants()==allocated)
			lcd:beginFrame();assert(lcd:finishFrame());assert(lcd:getStats().spansUsed==0 and lcd:getStats().visibleSpans==0)
		end)
		test("GUI paint exceptions become sticky failure and release every resize connection",function()
			local broken=fixture(128);local surface=broken.surface
			surface.paint=function()error("fixture paint fault")end
			broken:beginFrame();assert(not broken:finishFrame() and broken.failed and not broken.label.Visible and surface.stats.failure=="paint-error")
			broken:destroy();broken:destroy();assert(surface.connection==nil and surface.destroyed)
		end)
		test("hard cap fails before partial paint and stays failed without rebuilding a pool",function()
			local small=fixture(1);local created=small:getStats().dynamicCreated
			small:beginFrame();small:draw(Vector2.new(LCD.Width/2,LCD.Height*.45),12,12,0,Config.Tiers[1].color,0)
			assert(not small:finishFrame() and small.failed and not small.label.Visible and small:getStats().failure=="span-cap")
			assert(small:getStats().lastDemand>1 and small:getStats().dynamicCreated==created)
			for _=1,3 do small:beginFrame();assert(not small:finishFrame() and small:getStats().dynamicCreated==created)end
		end)
	end)
	for _,lcd in ipairs(instances)do lcd:destroy()end
	assert(#root:GetChildren()==0,"renderer leaked its own GUI root");root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases,grid={LCD.Width,LCD.Height}}
end
