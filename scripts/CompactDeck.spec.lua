-- Resize the actual handheld; no remotes, inventory, drops or reward changes.
return function(gui,board)
	local Config=require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
	local b=gui.Backdrop
	local before={size=b.Size,position=b.Position,score=board:GetAttribute("Score")}
	local cases={}
	local function settle()game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()end
	local function bounds(node)
		local p,s=node.AbsolutePosition,node.AbsoluteSize
		return p.X,p.Y,p.X+s.X,p.Y+s.Y
	end
	local function inside(node,host)
		local x,y,r,d=bounds(node);local hx,hy,hr,hd=bounds(host)
		return x>=hx-.1 and y>=hy-.1 and r<=hr+.1 and d<=hd+.1
	end
	local function overlaps(first,second)
		local ax,ay,ar,ad=bounds(first);local bx,by,br,bd=bounds(second)
		return ax<br-.1 and bx<ar-.1 and ay<bd-.1 and by<ad-.1
	end
	local ok,problem=pcall(function()
		for _,size in ipairs({Vector2.new(568,160),Vector2.new(568,198),Vector2.new(350,279),Vector2.new(568,279),Vector2.new(568,280),Vector2.new(667,285),Vector2.new(844,300),Vector2.new(844,330),Vector2.new(844,390),Vector2.new(390,740),Vector2.new(385,703),Vector2.new(733,307)})do
			b.Position,b.Size=UDim2.fromOffset(30,30),UDim2.fromOffset(size.X,size.Y);settle()
			local x,y,right,bottom=bounds(b)
			assert(b.Tray.AbsoluteSize.X>=70 and b.Tray.AbsoluteSize.Y>=120,"tray too small "..tostring(size))
			local expectedWidth=b.Tray.AbsoluteSize.Y*(Config.Width+.8)/(Config.Height+.8)
			assert(math.abs(b.Tray.AbsoluteSize.X-expectedWidth)<=1,"rounded tray aspect: actual "..tostring(b.Tray.AbsoluteSize)..", expected width "..expectedWidth)
			assert(inside(b.LCDBezel,b.CartridgeShell),"LCD protrudes shell")
			local nodes={b.Customize,b.VisitRoom,b.DeckControls.DPad.Left,b.DeckControls.DPad.Right,b.DeckControls.Drop}
			for _,node in ipairs(nodes)do
				local a,c,d,e=bounds(node)
				assert(node.AbsoluteSize.X>=44 and node.AbsoluteSize.Y>=44,node.Name.." small hit area")
				assert(a>=x+4 and c>=y+4 and d<=right-4 and e<=bottom-4,node.Name.." outside safe bounds "..tostring(size))
				assert(not overlaps(node,b.LCDBezel),node.Name.." covers LCD")
			end
			assert(not overlaps(b.Customize,b.VisitRoom) and not overlaps(b.Customize,b.DeckControls.DPad) and not overlaps(b.VisitRoom,b.DeckControls.DPad),"physical targets overlap")
			assert(b.AimRail.AbsoluteSize==b.Tray.AbsoluteSize and b.AimRail.BackgroundTransparency==1 and not b.AimRail.ReadoutDivider.Visible)
			local queue=b.PieceQueue
			assert(queue.AbsoluteSize.X>0 and queue.AbsoluteSize.Y>0 and not overlaps(queue,b.LCDBezel))
			local inline=queue:GetAttribute("InlineTiers")==true
			local combined=queue:GetAttribute("CombinedTiers")==true
			for index,slot in ipairs({queue.Dropping,queue.Next})do
				assert(slot.Caption.TextFits and slot.Caption.TextSize>=12 and not slot.Caption.TextScaled,"queue caption clipped "..tostring(size))
				if combined then
					assert(queue.Dropping.Caption.Text=="Now "..queue.Dropping.Piece.Mark.Text.."/Next "..queue.Next.Piece.Mark.Text and not queue.Next.Caption.Visible,"combined queue lost actual tiers")
				elseif inline then
					assert(slot.Caption.Text==(if index==1 then "Now " else "Next ")..slot.Piece.Mark.Text and not slot.Piece.Visible,"inline queue lost actual tier")
				else
					assert(slot.Piece.Visible and inside(slot.Piece,slot) and slot.Piece.AbsoluteSize.X>=18,"queue piece clipped")
					assert(slot.Piece.Mark.TextFits and not slot.Piece.Mark.TextScaled,"tier mark clipped "..tostring(size))
				end
			end
			assert(b.AimRail.GameReadout.TextFits,"exact wallet/score clipped "..tostring(size))
			if b.Status.ActiveQuest.Visible then assert(b.Status.ActiveQuest.Instruction.TextFits,"active field instruction clipped "..tostring(size)) end
			local dispenser=b.HatchTrack.BallDispenser
			local channel,count=dispenser.Channel,dispenser.Remaining
			assert(count.TextFits and count.TextSize>=12 and not count.TextScaled,"remaining counter clipped "..tostring(size))
			assert(inside(count,dispenser) and (not channel.Visible or inside(channel,dispenser)),"dispenser outside meter")
			assert(not channel.Visible or channel.AbsolutePosition.Y+channel.AbsoluteSize.Y<=count.AbsolutePosition.Y+.1,"dispenser covers remaining count")
			local caption=b.DeckControls.DropCaption
            assert(not caption.Visible,"A-adjacent caption must stay absent")
			if caption.Visible then
				local a=b.DeckControls.Drop
				local offset=math.abs(caption.AbsolutePosition.X+caption.AbsoluteSize.X/2-a.AbsolutePosition.X-a.AbsoluteSize.X/2)
				assert(offset<=math.max(1,(caption.AbsoluteSize.X-a.AbsoluteSize.X)/2),"drop caption detached from A")
				assert(caption.TextFits and inside(caption,b.CartridgeShell) and not overlaps(caption,a))
				for _,other in ipairs({b.Customize,b.VisitRoom,b.LCDBezel,b.HatchTrack,b.PieceQueue})do assert(not overlaps(caption,other),"caption covers "..other.Name)end
			end
			local stable={queue,queue.Dropping.Caption,queue.Next.Caption,queue.Dropping.Piece,queue.Next.Piece,channel,count}
			for index=1,8 do
				local ball=channel:FindFirstChild("Ball"..index)
				assert(ball and inside(ball,channel),"dispenser ball clipped")
				table.insert(stable,ball)
			end
			local initial={}
			for _,node in ipairs(stable)do initial[node]={position=node.Position,size=node.Size}end
			local pulses,remaining=dispenser:GetAttribute("AcceptedPulses"),count.Text
			-- Score-only snapshots cannot pulse, shrink or reflow the current drop presentation.
			for index=1,6 do board:SetAttribute("Score",(before.score or 0)+index);settle()end
			for node,value in pairs(initial)do assert(node.Position==value.position and node.Size==value.size,"HUD refresh changed "..node.Name)end
			assert(dispenser:GetAttribute("AcceptedPulses")==pulses and count.Text==remaining,"score refresh invented accepted drops")
			table.insert(cases,tostring(size).." safe tray and44px controls; readable queue and stable dispenser")
		end
	end)
	b.Size,b.Position=before.size,before.position;board:SetAttribute("Score",before.score);settle()
	assert(ok,problem)
	return{passed=#cases,cases=cases,persistentWrites=false}
end
