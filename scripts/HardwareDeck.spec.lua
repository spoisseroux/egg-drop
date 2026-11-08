-- Actual enabled GUI layout with temporary LOCAL presentation attributes only.
-- No requests, awards, purchases or acknowledgements. Run after Ready load on Board with no pending reveal.
return function(gui,board)
	local RunService,HttpService=game:GetService("RunService"),game:GetService("HttpService")
	assert(gui:IsA("ScreenGui") and gui.Enabled and board:GetAttribute("Mode")=="Board","ready enabled Board GUI required")
	local raw=board:GetAttribute("HatchState");local state=HttpService:JSONDecode(raw)
	assert(state.status=="Ready" and state.lastHatch==nil,"Ready snapshot without pending result required")
	local b=gui.Backdrop;local size,position=b.Size,b.Position
	local attrs={};for _,key in ipairs({"OwnedPets","HatchActive","FieldStage","FieldPhase","Score"})do attrs[key]={board:GetAttribute(key)}end
	local cases={};local function test(name,run)run();table.insert(cases,name)end
	local function settle()for _=1,3 do RunService.Heartbeat:Wait()end end
	local function readable(n)assert(n.TextFits,n.Name.." text="..n.Text.." box="..tostring(n.AbsoluteSize).." bounds="..tostring(n.TextBounds));assert(not n.TextScaled)end
	local function overlaps(a,c)local p,s,q,t=a.AbsolutePosition,a.AbsoluteSize,c.AbsolutePosition,c.AbsoluteSize;return p.X<q.X+t.X-.1 and q.X<p.X+s.X-.1 and p.Y<q.Y+t.Y-.1 and q.Y<p.Y+s.Y-.1 end
	local ok,problem=pcall(function()
		board:SetAttribute("HatchActive",true);board:SetAttribute("OwnedPets",math.max(1,board:GetAttribute("OwnedPets")or 0));board:SetAttribute("FieldStage",0);board:SetAttribute("FieldPhase","Playing");settle()
		for _,root in ipairs({Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703),Vector2.new(350,279)})do
			test(tostring(root).." exact wallets inset queue count and targets fit",function()
				b.Position,b.Size=UDim2.fromOffset(30,30),UDim2.fromOffset(root.X,root.Y);settle()
				local controls={b.Customize,b.VisitRoom,b.DeckControls.DPad.Left,b.DeckControls.DPad.Right,b.DeckControls.Drop}
				local seats={};for _,n in ipairs(controls)do seats[n]={n.Position,n.Size};assert(n.AbsoluteSize.X>=44 and n.AbsoluteSize.Y>=44)end
				for _,amount in ipairs({0,20,1000000})do
					local snapshot=table.clone(state);snapshot.nectar=amount;board:SetAttribute("HatchState",HttpService:JSONEncode(snapshot));settle()
					local value,face=b.AimRail.GameReadout,b.AimRail.WalletInstrument
					assert(value.Text==tostring(amount) and value.TextXAlignment==Enum.TextXAlignment.Right);readable(value)
					assert(value.AbsolutePosition.X>=face.AbsolutePosition.X and value.AbsolutePosition.X+value.AbsoluteSize.X<=face.AbsolutePosition.X+face.AbsoluteSize.X-1.9)
					assert(not face.Active and face.ClipsDescendants and not overlaps(face,b.LCDBezel),"wallet touches tray")
					for n,seat in pairs(seats)do assert(n.Position==seat[1] and n.Size==seat[2],"wallet moved input seat");assert(not overlaps(face,n),"wallet touches input")end
				end
				for _,slot in ipairs({b.PieceQueue.Dropping,b.PieceQueue.Next})do
					if slot.Caption.Visible then readable(slot.Caption)end
					if slot.Piece.Visible then readable(slot.Piece.Mark);assert(slot.Piece.AbsolutePosition.Y+slot.Piece.AbsoluteSize.Y<=b.PieceQueue.AbsolutePosition.Y+b.PieceQueue.AbsoluteSize.Y-1.9,"queue bottom clipping")end
				end
				local drops=b.HatchTrack.BallDispenser;readable(drops.Remaining)
				if drops.Channel.Visible then
					local first,last=drops.Channel.Ball1,drops.Channel.Ball8
					assert(math.abs(first.Position.X.Offset-(drops.Channel.AbsoluteSize.X-last.Position.X.Offset-last.Size.X.Offset))<=1,"train not centered")
				end
				local quest=b.Status.ActiveQuest;readable(quest.Instruction)
				if quest.Steps.Visible then readable(quest.Steps);assert(quest.Steps.Position.Y.Offset-quest.Instruction.Position.Y.Offset-quest.Instruction.Size.Y.Offset==3)end
			end)
		end
		test("qualified bank regions use only faint phase-owned fill; score refresh preserves pulses",function()
			local regions=b.TrayOverlay.TargetRegions;local left,right=regions.LeftRootPatch,regions.RightRootPatch
			for _,zone in ipairs({left,right})do
				assert(#zone:GetChildren()==0 and not zone.Active and not zone.Selectable,"bank owns competing decoration/input")
				assert(zone.Size.X.Scale>0 and zone.Size.X.Scale<.5)
				assert(zone.BackgroundColor3==Color3.fromHex("#466853"),"bank must share the neutral LCD tint")
			end
			for stage=0,2 do
				board:SetAttribute("FieldStage",stage);settle()
				assert(left.Visible and right.Visible)
				assert(math.abs(left.BackgroundTransparency-(if stage==0 then .79 else .86))<.001)
				assert(math.abs(right.BackgroundTransparency-(if stage==1 then .79 else .86))<.001)
				readable(b.Status.ActiveQuest.Instruction)
			end
			local dispenser=b.HatchTrack.BallDispenser;local pulses=dispenser:GetAttribute("AcceptedPulses");local counter=dispenser.Remaining.Text
			for index=1,3 do board:SetAttribute("Score",(attrs.Score[1]or 0)+index);settle()end
			assert(dispenser:GetAttribute("AcceptedPulses")==pulses and dispenser.Remaining.Text==counter)
		end)
	end)
	-- Restore Ready snapshot and all local model fields even on assertion failure.
	board:SetAttribute("OwnedPets",attrs.OwnedPets[1]);settle()
	for _,key in ipairs({"HatchActive","FieldStage","FieldPhase","Score"})do board:SetAttribute(key,attrs[key][1])end
	board:SetAttribute("HatchState",raw);b.Size,b.Position=size,position;settle()
	assert(ok,problem)
	return{passed=#cases,cases=cases,localPresentationOnly=true}
end
