-- Resize the actual handheld; no remotes, inventory, or reward changes.
return function(gui, board)
	local b=gui.Backdrop
	local before={size=b.Size,position=b.Position,score=board:GetAttribute("Score")}
	local cases={}
	local function settle()game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()end
	local function bounds(node)
		local p,s=node.AbsolutePosition,node.AbsoluteSize
		return p.X,p.Y,p.X+s.X,p.Y+s.Y
	end
	local ok,problem=pcall(function()
		for _,size in ipairs({Vector2.new(568,160),Vector2.new(568,198),Vector2.new(350,279),Vector2.new(568,279),Vector2.new(568,280),Vector2.new(667,285),Vector2.new(844,300),Vector2.new(844,330),Vector2.new(844,390),Vector2.new(390,740)})do
			b.Position,b.Size=UDim2.fromOffset(30,30),UDim2.fromOffset(size.X,size.Y);settle()
			local x,y,right,bottom=bounds(b)
			assert(b.Tray.AbsoluteSize.X>=70 and b.Tray.AbsoluteSize.Y>=120,"tray too small "..tostring(size))
			assert(b.AimRail.GameReadout.AbsoluteSize.X>0 and b.AimRail.NextReadout.AbsoluteSize.X>0,"negative readout")
			local nodes={b.Customize,b.VisitRoom,b.DeckControls.DPad.Left,b.DeckControls.DPad.Right,b.DeckControls.Drop}
			for _,node in ipairs(nodes)do
				local a,c,d,e=bounds(node)
				assert(node.AbsoluteSize.X>=44 and node.AbsoluteSize.Y>=44,node.Name.." small hit area")
				assert(a>=x+4 and c>=y+4 and d<=right-4 and e<=bottom-4,node.Name.." outside safe bounds "..tostring(size))
			end
			if b:GetAttribute("CompactLandscape")then
				assert(b.AimRail.AbsoluteSize==b.Tray.AbsoluteSize and b.AimRail.BackgroundTransparency==1)
				assert(not b.EggGoal.Visible and not b.AimRail.ReadoutDivider.Visible)
			else assert(b.AimRail.AbsoluteSize.Y==44 and b.AimRail.ReadoutDivider.Visible)end
			if b:GetAttribute("SideGoalLayout")then assert(not b.EggGoal.Visible,"egg goal overlaps grip meter")end
			local meter=b.HatchTrack;local cells={}
			for _,cell in ipairs(meter:GetChildren())do if cell.Name=="Cell"then table.insert(cells,cell)end end
			assert(#cells==24)
			local initial={}
			for index,cell in ipairs(cells)do initial[index]={position=cell.Position,size=cell.Size}end
			-- Repeated authoritative HUD updates must not multiply/shrink cell scales.
			for index=1,6 do board:SetAttribute("Score",(before.score or 0)+index);settle()end
			for index,cell in ipairs(cells)do
				assert(cell.Position==initial[index].position and cell.Size==initial[index].size,"meter shrank on refresh")
				assert(cell.AbsoluteSize.X>=1 and cell.AbsolutePosition.X+cell.AbsoluteSize.X<=meter.MeterText.AbsolutePosition.X-1,"cell overlaps counter")
			end
			table.insert(cases,tostring(size).." usable tray, controls, readouts and stable 24-cell meter")
		end
	end)
	b.Size,b.Position=before.size,before.position;board:SetAttribute("Score",before.score);settle()
	assert(ok,problem)
	return{passed=#cases,cases=cases,persistentWrites=false}
end
