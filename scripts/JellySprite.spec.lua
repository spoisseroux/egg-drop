-- True client ScreenGui checks for the bounded last-resort stepped renderer.
return function(client,parent)
	assert(parent:IsA("ScreenGui") and parent.Enabled,"enabled ScreenGui required")
	local Sprite=require(client.JellySprite);local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local Palette=require(game.ReplicatedStorage.Shared.JellyPalette)
	local root=Instance.new("Frame");root.Name="_JellySpriteSpec";root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(354,594);root.Parent=parent
	local RunService=game:GetService("RunService");local cases,views,sources={},{},{}
	local function settle()RunService.Heartbeat:Wait();RunService.Heartbeat:Wait()end
	local function test(name,run)run();table.insert(cases,name)end
	local function project(point)return Vector2.new(root.AbsoluteSize.X*(.5+point.X/(Config.Width+.8)),root.AbsoluteSize.Y*(.5-(point.Y-Config.Height/2)/(Config.Height+.8))),root.AbsoluteSize.X/(Config.Width+.8)end
	local function fixture(tier)
		local source=Instance.new("Part");source.Name="Fixture"..tier;source.Size=Vector3.one*Config.Tiers[tier].radius*2;source.Color=Config.Tiers[tier].color
		source.Position=Vector3.new(0,8,0);source:SetAttribute("EggId",tier)
		local view=Sprite.new(root,source);table.insert(views,view);table.insert(sources,source);return view,source
	end
	local function inside(glint,fill)
		return glint.x>=fill.x and glint.y>=fill.y and glint.x+glint.w<=fill.x+fill.w and glint.y+glint.h<=fill.y+fill.h
	end
	local ok,problem=pcall(function()
		settle()
		test("all five sprite fallbacks use shared vivid roles in the existing bands",function()
			for tier=1,#Config.Tiers do
				local view,source=fixture(tier);local colors=Palette.byTier[tier]
				-- No dark outline (redesign 6.1): top silhouette rows are body, the lower third deep.
				assert(view.rims[1].node.BackgroundColor3==colors.body and view.rims[#view.rims].node.BackgroundColor3==colors.deep and view.glint.BackgroundColor3==colors.glint)
				local upper,body,lower=false,false,false
				for _,fill in ipairs(view.fills)do
					local gradient=fill.node:FindFirstChildOfClass("UIGradient")
					if fill.node.BackgroundColor3==colors.lower then lower=true elseif fill.node.BackgroundColor3==colors.body then body=true
					elseif gradient.Color.Keypoints[1].Value==colors.light then upper=true end
				end
				assert(upper and body and lower,"missing sprite material role tier "..tier)
				local count=#view.body:GetDescendants();view:impact(Vector2.new(1,0),20)
				for frame=1,20 do view:render(source.Position,1/60,frame/60,project,true,false)end
				assert(#view.body:GetDescendants()==count and source.Color==Config.Tiers[tier].color,"feedback rewrote source or grew the pool")
			end
		end)
		test("smallest and largest tier keep upper-left mathematically inset unrotated light",function()
			for _,tier in ipairs({1,#Config.Tiers})do
				local view,source=fixture(tier);local allocated=#view.body:GetDescendants()
				for _,angle in ipairs({0,math.pi/4,math.pi/2,-math.pi/4})do
					view.position=source.Position;view.axis=Vector2.new(math.sin(angle),math.cos(angle));view.strength=.3;view.age=0
					view:render(source.Position,0,0,project,true,false);settle()
					assert(view.body.Rotation==0 and view.glint.Visible,"missing fixed light tier"..tier.." angle"..angle)
					for _,glint in ipairs(view.glints)do if glint.shown then
						assert(glint.node.Rotation==0 and glint.x+glint.w/2<0 and glint.y+glint.h/2<0,"light left screen upper-left")
						local contained=false;for _,fill in ipairs(view.fills)do if fill.shown and inside(glint,fill)then contained=true;break end end
						assert(contained,"light requires unsupported rotated clipping")
					end end
				end
				assert(#view.body:GetDescendants()==allocated)
			end
		end)
		test("logical center quantizes display without changing returned continuous pose",function()
			local view,source=fixture(2);view.strength=0;view.age=10
			for index=1,8 do
				source.Position=Vector3.new(index*.19,8,0);local center=view:render(source.Position,1/60,index/60,project,true,true)
				local point=project(Vector2.new(center.X,center.Y));local cellX=root.AbsoluteSize.X/view.gridWidth;local cellY=root.AbsoluteSize.Y/view.gridHeight
				assert(math.abs(view.body.Position.X.Offset-point.X)<=cellX/2+1 and math.abs(view.body.Position.Y.Offset-point.Y)<=cellY/2+1)
				assert(view.propertyWrites<=1 or index==1,"falling/moving stable pose repainted bands")
			end
		end)
		test("covered pose sampling creates no GUI writes and reduced rest stays static",function()
			local view,source=fixture(1);view:render(source.Position,0,0,project,true,true);local position=view.body.Position
			for index=1,4 do view:render(source.Position+Vector3.new(index,0,0),1/60,index,project,false,false);assert(view.propertyWrites==0 and view.body.Position==position)end
			view.position=source.Position;view:render(source.Position,0,1,project,true,true)
			local count=#view.body:GetDescendants();view:render(source.Position,0,999,project,true,true)
			assert(view.propertyWrites==0 and #view.body:GetDescendants()==count)
		end)
		test("floor and angled bank remain occlusion boundaries for stepped bands",function()
			local view,source=fixture(2);source.Position=Vector3.new(4,1.2,0);view.position=source.Position;view.strength=0
			view:render(source.Position,0,0,project,true,true)
			local scale=view.gridWidth/(Config.Width+.8);local cx,cy=math.round(project(Vector2.new(source.Position.X,source.Position.Y)).X/(root.AbsoluteSize.X/view.gridWidth)),math.round(project(Vector2.new(source.Position.X,source.Position.Y)).Y/(root.AbsoluteSize.Y/view.gridHeight))
			local worldX=(cx/view.gridWidth-.5)*(Config.Width+.8);local worldY=Config.Height/2-(cy/view.gridHeight-.5)*(Config.Height+.8)
			for _,rim in ipairs(view.rims)do if rim.shown then
				local bottom=worldY-(rim.y+rim.h)/(root.AbsoluteSize.Y/view.gridHeight)/scale
				local right=worldX+(rim.x+rim.w)/(root.AbsoluteSize.X/view.gridWidth)/scale
				assert(bottom>=-1/scale and right<=Config.Width/2-math.max(0,Config.Bank-bottom)+1/scale,"gel painted outside bank/floor")
			end end
		end)
		test("sparse fallback grain is static passive and only forty marks",function()
			local host=Sprite.texture(root);assert(#host:GetChildren()==40 and not host.Active and not host.Selectable)
			for _,mark in ipairs(host:GetChildren())do assert(not mark.Active and not mark.Selectable and mark.Rotation==0)end
			host:Destroy()
		end)
	end)
	for _,view in ipairs(views)do view:destroy();view:destroy()end;for _,source in ipairs(sources)do source:Destroy()end
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases,cheapGridWidth=Sprite.GridWidth}
end
