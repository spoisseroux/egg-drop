-- Actual handheld GUI contract. Client-local attributes are restored; no requests or avatar movement.
-- Run from a real LocalScript (same calling convention as CompactDeck) at Medium and Largest.
return function(gui,board)
	local Http=game:GetService("HttpService")
	local client=game:GetService("Players").LocalPlayer.PlayerScripts:WaitForChild("Client")
	local SaveNotice=require(client:WaitForChild("SaveNotice"))
	local b=gui.Backdrop;local cases={}
	local previous={size=b.Size,position=b.Position,ready=board:GetAttribute("FieldReady"),phase=board:GetAttribute("FieldPhase"),state=board:GetAttribute("HatchState")}
	local state=Http:JSONDecode(previous.state)
	assert(not state.lastHatch,"run caption fixture after pending-result QA is acknowledged")
	assert(SaveNotice.resolve(board:GetAttribute("SaveStatus"),{status="Ready"})==nil,"run caption fixture after profile load/retry settles")
	local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
	local function test(name,run)run();table.insert(cases,name)end
	local function snapshot(status)
		local copy=table.clone(state);copy.status=status;board:SetAttribute("HatchState",Http:JSONEncode(copy))
	end
	local caption=b.DeckControls.DropCaption
	local function expectBlocked(word,saveCode)
		settle();assert(not caption.Visible,"A-adjacent blocked caption returned")
        assert(b.DeckControls.Drop:GetAttribute("AccessibleLabel")~=nil,"A lost accessible action description")
		if saveCode then
			local notice=SaveNotice.resolve(board:GetAttribute("SaveStatus"),{status=saveCode})
			assert(caption.Text==word and not caption.Visible,"persistent save notice must own the blocked explanation")
			assert(gui:GetAttribute("SaveNoticeOwner")=="board" and gui:GetAttribute("SaveNoticeCode")==notice.code,"wrong save notice owner/code")
			assert(b.Status.Visible and b.Status.TextFits and (b.Status.Text==notice.short or b.Status.Text==notice.narrow or b.Status.Text==notice.tiny),"wrong/clipped persistent save copy: "..b.Status.Text)
			assert(b.Status:GetAttribute("AccessibleLabel")==notice.detail,"missing full save instruction")
			assert(not b.Status.ActiveQuest.Visible,"save notice must have one rendering owner")
		elseif caption.Visible then
			assert(caption.Text==word and caption.TextFits and not caption:GetAttribute("BlockedCaption"))
		else
			assert(caption:GetAttribute("BlockedCaption")==word and b.Status.Text~="" and b.Status.TextFits)
			assert(not b.Status.ActiveQuest.Visible,"blocked status must have one rendering owner")
		end
		assert(b.PieceQueue.Dropping.Caption.TextFits and b.PieceQueue.Next.Caption.TextFits)
	end
	local function expectReady()
		settle();assert(caption.Text=="DROP" and not caption:GetAttribute("BlockedCaption")and not caption.Visible)
        assert(b.DeckControls.Drop:GetAttribute("AccessibleLabel")=="Drop jelly")
		assert(gui:GetAttribute("SaveNoticeOwner")=="" and gui:GetAttribute("SaveNoticeCode")=="","Ready retained obsolete save ownership")
		if (board:GetAttribute("OwnedPets") or 0)>0 then assert(b.Status.ActiveQuest.Visible and b.Status.ActiveQuest.Instruction.TextFits,"objective did not restore")
		else assert(b.Status.Text~="" and b.Status.TextFits,"welcome instruction did not restore")end
	end
	local ok,problem=pcall(function()
		for _,size in ipairs({Vector2.new(568,160),Vector2.new(480,160),Vector2.new(385,703)})do
			b.Position,b.Size=UDim2.fromOffset(0,0),UDim2.fromOffset(size.X,size.Y);snapshot("Ready")
			board:SetAttribute("FieldReady",true);board:SetAttribute("FieldPhase","Playing");settle()
			test(tostring(size).." drop states stay readable and restore objective without moving controls",function()
				local controls={b.Customize,b.VisitRoom,b.DeckControls.Drop,b.DeckControls.DPad}
				local positions={};for _,node in ipairs(controls)do positions[node]={node.Position,node.Size}end
				expectReady();board:SetAttribute("FieldReady",false);expectBlocked("FALLING")
				board:SetAttribute("FieldReady",true);expectReady()
				board:SetAttribute("FieldPhase","Settling");expectBlocked("SETTLE")
				board:SetAttribute("FieldPhase","Playing");expectReady()
				snapshot("Retrying");expectBlocked("SAVING","Retrying");snapshot("Ready");expectReady()
				snapshot("Locked");expectBlocked("SAVE WAIT","Locked");snapshot("Ready");expectReady()
				for node,geometry in pairs(positions)do assert(node.Position==geometry[1] and node.Size==geometry[2],"status displaced "..node.Name)end
			end)
		end
		test("resizing while falling transfers status ownership and restores readiness",function()
			board:SetAttribute("FieldReady",false);expectBlocked("FALLING")
			b.Size=UDim2.fromOffset(568,160);expectBlocked("FALLING")
			b.Size=UDim2.fromOffset(385,703);expectBlocked("FALLING")
			board:SetAttribute("FieldReady",true);expectReady()
		end)
	end)
	board:SetAttribute("HatchState",previous.state);board:SetAttribute("FieldReady",previous.ready);board:SetAttribute("FieldPhase",previous.phase)
	b.Size,b.Position=previous.size,previous.position;settle();assert(ok,problem)
	return{passed=#cases,cases=cases,persistentWrites=false}
end
