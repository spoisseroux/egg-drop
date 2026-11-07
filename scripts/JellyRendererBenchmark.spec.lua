-- Run in a real LocalScript + enabled ScreenGui, same Studio device/profile for every backend.
-- Baseline can be root's cloned frozen JellySprite ModuleScript via options.sprite.
-- Measures this isolated renderer's CPU; RenderStepped dt includes the entire running client/Studio.
return function(client,parent,options)
	options=options or {}
	assert(parent:IsA("ScreenGui") and parent.Enabled,"enabled ScreenGui required")
	local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local Sprite=require(options.sprite or client.JellySprite)
	local LCD=if options.lcd then require(options.lcd)else require(client.JellyLCD)
	local RunService=game:GetService("RunService")
	local backend=options.backend or "baseline"
	local procedural=backend=="baseline"or backend=="cheap"
	local count=24
	local root=Instance.new("Frame");root.Name="_RendererBenchmark_"..backend
	root.BackgroundColor3=Color3.fromHex("#C6DFA0");root.BorderSizePixel=0;root.ClipsDescendants=true
	local fitH=math.min(594,math.max(1,parent.AbsoluteSize.Y-40),math.max(1,parent.AbsoluteSize.X-40)*(Config.Height+.8)/(Config.Width+.8))
	root.Position,root.Size=UDim2.fromOffset(20,20),UDim2.fromOffset(fitH*(Config.Width+.8)/(Config.Height+.8),fitH);root.Parent=parent
	local spriteHost=Instance.new("Frame");spriteHost.BackgroundTransparency=1;spriteHost.Size=UDim2.fromScale(1,1);spriteHost.Parent=root
	local sources,gels,marks={},{},{}
	local worldW,worldH=Config.Width+.8,Config.Height+.8
	local function project(point)
		return Vector2.new(root.AbsoluteSize.X*(.5+point.X/worldW),root.AbsoluteSize.Y*(.5-(point.Y-Config.Height/2)/worldH)),root.AbsoluteSize.X/worldW
	end
	local function pixelPoint(point)
		return Vector2.new(LCD.Width*(.5+point.X/worldW),LCD.Height*(.5-(point.Y-Config.Height/2)/worldH))
	end
	for index=1,count do
		local tier=1+(index-1)%4;local source=Instance.new("Part")
		source.Name="BenchmarkGel"..index;source.Size=Vector3.one*(Config.Tiers[tier].radius*2)
		source.Color=Config.Tiers[tier].color;source.Position=Vector3.new((index%6-2.5)*1.4,1+math.floor((index-1)/6)*1.4,0)
		source:SetAttribute("EggId",index);sources[index]=source;gels[index]=Sprite.new(spriteHost,source,{gridWidth=LCD.Width})
		local mark=Instance.new("TextLabel");mark.BackgroundTransparency=1;mark.Size=UDim2.fromOffset(26,24);mark.AnchorPoint=Vector2.new(.5,.5)
		mark.Font,mark.TextSize,mark.Text,mark.ZIndex=Enum.Font.GothamBold,12,Config.Tiers[tier].mark,10;mark.Parent=root;marks[index]=mark
	end
	local lcd
	if not procedural then
		lcd=LCD.new(root,{backend=backend,maxSpans=options.maxSpans or 4096})
		assert(lcd,"requested LCD backend unavailable: "..backend)
	end
	local function percentile(samples,p)
		if #samples==0 then return 0 end
		local ordered=table.clone(samples);table.sort(ordered);return ordered[math.clamp(math.ceil(#ordered*p),1,#ordered)]
	end
	local function distribution(samples)return{p50=percentile(samples,.50),p95=percentile(samples,.95),max=percentile(samples,1)}end
	local reports={};local drawElapsed=1/30;local fallback=false
	local fixtureSize=root.Size
	local scenarios=options.scenarios or {"idle","falling","pile24","multiMerge"}
	local measuredFrames=options.frames or 150;local warmup=options.warmupFrames or 30
	local function stats()
		return if lcd and lcd.getStats then lcd:getStats()else{}
	end
	local ok,problem=pcall(function()
		for _,scenario in ipairs(scenarios)do
			local cpu,paintCpu,frameMs,rasterMs,scanMs,commitMs={},{},{},{},{},{}
			local peakUsed,peakAllocated,peakStatic,peakWrites,peakDemand=0,0,0,0,0
			local startCreated,postWarmCreated,painted,failures=0,0,0,0
			for frame=1,warmup+measuredFrames do
				local dt=RunService.RenderStepped:Wait();local t=frame/60
				local used=if scenario=="idle"then 1 else count
				for index,source in ipairs(sources)do
					local column,row=(index-1)%6,math.floor((index-1)/6)
					local x,y=(column-2.5)*1.4,1+row*1.4
					if scenario=="falling"then y=1+(18-(t*5+index*.7)%18);x+=(math.sin(t+index)*.2)
					elseif scenario=="multiMerge"and index<=8 then
						local pair=math.floor((index-1)/2);local cycle=(t*.7)%1
						x=(pair-1.5)*2.2+(if index%2==0 then 1 else -1)*(.8*(1-cycle));y=8+math.sin(cycle*math.pi)*.3
					end
					source.Position=Vector3.new(x,y,0)
					local shown=index<=used;if marks[index].Visible~=shown then marks[index].Visible=shown end
					if gels[index].body.Visible~=shown then gels[index].body.Visible=shown end
				end
				spriteHost.Visible=procedural or fallback
				local start=os.clock();drawElapsed+=dt
				local draw=lcd~=nil and not fallback and drawElapsed>=1/30
				if draw then drawElapsed%=1/30;lcd:beginFrame()end
				local markWrites,spriteWrites=0,0
				for index,gel in ipairs(gels)do
					if index<=used then
						local position,sx,sy,angle,ripple=gel:render(sources[index].Position,dt,t,project,procedural or fallback,false)
						if procedural or fallback then spriteWrites+=gel.propertyWrites or 4 end
						if procedural or fallback or draw then local p=project(Vector2.new(position.X,position.Y));marks[index].Position=UDim2.fromOffset(p.X,p.Y);markWrites+=1 end
						if draw and not(scenario=="multiMerge"and index<=8)then
							local radius=sources[index].Size.X/2*LCD.Width/worldW
							lcd:draw(pixelPoint(Vector2.new(position.X,position.Y)),radius*sx,radius*sy,angle,sources[index].Color,ripple)
						end
					end
				end
				if draw then
					if scenario=="multiMerge"then for pair=1,4 do
						local a,b=sources[pair*2-1],sources[pair*2];local midpoint=(a.Position+b.Position)/2
						lcd:merge(pixelPoint(Vector2.new(a.Position.X,a.Position.Y)),pixelPoint(Vector2.new(b.Position.X,b.Position.Y)),pixelPoint(Vector2.new(midpoint.X,midpoint.Y)),a.Size.X/2*LCD.Width/worldW,b.Size.X*.6*LCD.Width/worldW,b.Color,(t*.7%1)*LCD.MergeDuration)
					end end
					if not lcd:finishFrame()then failures+=1;fallback=true;lcd.label.Visible=false else lcd.label.Visible=true end
				end
				local milliseconds=(os.clock()-start)*1000
				local sample=stats()
				if frame==warmup then startCreated=sample.dynamicCreated or 0 end
				if frame>warmup then
					table.insert(cpu,milliseconds);table.insert(frameMs,dt*1000)
					if draw then table.insert(paintCpu,milliseconds);painted+=1;table.insert(rasterMs,sample.rasterMs or 0);table.insert(scanMs,sample.scanMs or 0);table.insert(commitMs,sample.commitMs or 0)end
					peakUsed=math.max(peakUsed,sample.spansUsed or 0);peakAllocated=math.max(peakAllocated,sample.dynamicAllocated or 0)
					peakStatic=math.max(peakStatic,sample.staticAllocated or 0);peakDemand=math.max(peakDemand,sample.lastDemand or sample.peakDemand or 0)
					peakWrites=math.max(peakWrites,(if procedural or fallback then spriteWrites else sample.propertyWrites or 0)+markWrites)
					postWarmCreated=math.max(postWarmCreated,(sample.dynamicCreated or 0)-startCreated)
				end
			end
			local report={scenario=scenario,rendererAtEnd=if fallback then "procedural-fallback"else backend,backend=backend,frames=measuredFrames,paintedFrames=painted,cpuAllMs=distribution(cpu),cpuPaintMs=distribution(paintCpu),rasterCpuMs=distribution(rasterMs),spanScanCpuMs=distribution(scanMs),spanCommitCpuMs=distribution(commitMs),wholeClientFrameMs=distribution(frameMs),peakUsed=peakUsed,peakAllocated=peakAllocated,staticAllocated=peakStatic,peakDemand=peakDemand,peakPropertyWrites=peakWrites,createdAfterWarmup=postWarmCreated,failures=failures,fallback=fallback}
			table.insert(reports,report);if options.progress then options.progress(report)end
		end
	end)
	local finalStats=table.clone(stats());if lcd then lcd:destroy()end
	for _,gel in ipairs(gels)do gel:destroy()end;for _,source in ipairs(sources)do source:Destroy()end;root:Destroy()
	assert(ok,problem)
	return{backend=backend,fixtureSize=tostring(fixtureSize),deviceViewport=tostring(workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize),logicalGrid={LCD.Width,LCD.Height},renderHz=30,sampleFrameClock="RenderStepped dt: whole client + Studio; not renderer-only",cpuClock="os.clock around renderer animation/paint only; excludes deterministic scene setup",baselineWrites="issued writes inferred from frozen Sprite render(4) +mark(1), not native property event instrumentation",reports=reports,finalStats=finalStats}
end
