-- Actual initialized client: same signature as CompactDeck(gui,board).
-- Changes/restores only client-local presentation attributes; no inputs, remotes, mode or inventory changes.
-- Run from a quiet settled Board/Room with no open sheet or pending result.
return function(gui,board)
	local Http=game:GetService("HttpService");local GuiService=game:GetService("GuiService")
	assert(not GuiService.MenuIsOpen,"close native menu before ownership fixture")
	local oldProfile,oldHatch=board:GetAttribute("SaveStatus"),board:GetAttribute("HatchState")
	local base=Http:JSONDecode(oldHatch);assert(not base.lastHatch,"acknowledge pending result before ownership fixture")
	local cases={};local function test(name,run)run();table.insert(cases,name)end
	local function settle()for _=1,4 do game:GetService("RunService").Heartbeat:Wait()end end
	local function visibleNotice(code)
		settle();assert(gui:GetAttribute("SaveNoticeCode")==code,"wrong resolver source: "..tostring(gui:GetAttribute("SaveNoticeCode")))
		local owner=gui:GetAttribute("SaveNoticeOwner");local label
		if owner=="board"then label=gui.Backdrop.Status;assert(not label.ActiveQuest.Visible)
		elseif owner=="roam"or owner=="focus"then
			local focus=game.Players.LocalPlayer.PlayerGui:FindFirstChild("EggDropPetFocus")
			assert(focus,"missing room focus presentation")
			label=if owner=="roam"then focus.SafeContent.RoamPetHint else focus.SafeContent.FocusControls.PettingHint
		else error("quiet settled route required; current owner "..tostring(owner))end
		assert(label.Visible and label.TextFits and not label.TextScaled and not label.Active and not label.Selectable,
			string.format("%s text=%q box=%s bounds=%s",label:GetFullName(),label.Text,tostring(label.AbsoluteSize),tostring(label.TextBounds)))
		assert(not gui:FindFirstChild("SaveNotice"),"old global banner duplicates local notice")
		return label,owner
	end
	local function hatch(status)
		local copy=table.clone(base);copy.status=status;board:SetAttribute("HatchState",Http:JSONEncode(copy))
	end
	local ok,problem=pcall(function()
		test("profile retry survives every neutral hatch status in the actual current owner",function()
			for _,profile in ipairs({"Temporary","Retrying"})do
				board:SetAttribute("SaveStatus",profile)
				for _,status in ipairs({"Ready","Busy","Pending","Released"})do
					hatch(status);local label=visibleNotice(profile)
					assert(not label.Text:lower():find("rejoin",1,true))
				end
			end
		end)
		test("recognized blocking hatch source and Ready recovery replace and clear one passive owner",function()
			board:SetAttribute("SaveStatus","Temporary")
			for _,status in ipairs({"Unavailable","Locked","Retrying","SessionLost","InvalidData"})do hatch(status);visibleNotice(status)end
			board:SetAttribute("SaveStatus","Retrying");hatch("FutureStatus");visibleNotice("Retrying")
			board:SetAttribute("SaveStatus",nil);hatch("Ready");settle()
			assert(gui:GetAttribute("SaveNoticeOwner")=="" and gui:GetAttribute("SaveNoticeCode")=="")
			if board:GetAttribute("Mode")=="Board"then
				assert(gui.Backdrop.Status.Visible and gui.Backdrop.Status:GetAttribute("AccessibleLabel")==nil)
				if (board:GetAttribute("OwnedPets")or 0)>0 and board:GetAttribute("HatchActive")==true then assert(gui.Backdrop.Status.ActiveQuest.Visible,"Ready did not restore objective")end
			end
			local after=Http:JSONDecode(board:GetAttribute("HatchState"))
			assert(after.nectar==base.nectar and after.revision==base.revision and after.inventoryMask==base.inventoryMask and after.lastHatch==nil)
		end)
	end)
	board:SetAttribute("HatchState",oldHatch);board:SetAttribute("SaveStatus",oldProfile);settle();assert(ok,problem)
	return{passed=#cases,cases=cases,clientLocalOnly=true}
end
