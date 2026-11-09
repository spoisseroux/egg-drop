-- Production HUD with temporary LOCAL public presentation snapshots only.
-- Fresh empty settled field required; no requests, drops, awards or catalog selection.
return function(gui,board,onlySize)
 local Catalog=require(game.ReplicatedStorage.Shared.FieldObjectives);local Http=game:GetService("HttpService")
 assert(gui.Enabled and gui.Backdrop.Visible and board:GetAttribute("Mode")=="Board"and(board:GetAttribute("OwnedPets")or 0)>0,"settled field required")
 assert((board:GetAttribute("Drops")or 0)==0 and not board:GetAttribute("RoundOver"),"fresh empty field required")
 local sequence=board:GetAttribute("RunSequence");local root=gui.Backdrop;local oldSize,oldPosition=root.Size,root.Position
 local saved={};for _,key in ipairs({"FieldObjective","FieldStage","FieldPhase","SaveStatus"})do saved[key]={board:GetAttribute(key)}end
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function public(id,step,progress)
  local d=Catalog.create(id,17)
  return{sequence=sequence,templateId=id,title=d.title,dynamics={id=d.dynamics.id,label=d.dynamics.label},goals=d.goals,step=step,progress=progress or 0,
   target=if step==3 then 0 else d.goals[step].target,complete=step==3}
 end
 local function publish(view)
  board:SetAttribute("FieldObjective",Http:JSONEncode(view));board:SetAttribute("FieldStage",view.step-1);board:SetAttribute("FieldPhase","Playing");settle()
 end
 local function fit(label)assert(label.TextFits,label.Text.." "..tostring(label.AbsoluteSize).."/"..tostring(label.TextBounds));assert(not label.TextScaled)end
 local ok,err=pcall(function()
  for _,size in ipairs(if onlySize then {onlySize}else {Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
   root.Size,root.Position=UDim2.fromOffset(size.X,size.Y),UDim2.fromOffset(0,0);settle()
   test(tostring(size).." active public zones/counts preserve all input seats and exact remaining counter",function()
    local seats={};for _,node in ipairs({root.Customize,root.VisitRoom,root.DeckControls.Drop,root.DeckControls.DPad.Left,root.DeckControls.DPad.Right})do seats[node]={node.Position,node.Size}end
    local counter=root.HatchTrack.BallDispenser;local text,pulses=counter.Remaining.Text,counter:GetAttribute("AcceptedPulses")
    for _,id in ipairs(Catalog.Order)do for _,step in ipairs({1,2,3})do
     local view=public(id,step,if id=="lantern_chain"and step==2 then 1 else 0);publish(view)
     local quest=root.Status.ActiveQuest;assert(quest.Visible and counter.Visible);fit(quest.Instruction)
     local region=root.TrayOverlay:FindFirstChild("TargetRegions",true);local zone=if step==3 then "any"else view.goals[step].zone.kind
     assert(region.LeftRootPatch.Visible and region.RightRootPatch.Visible)
     assert(math.abs(region.LeftRootPatch.BackgroundTransparency-(if zone=="left"then .79 else .86))<.001)
     assert(math.abs(region.RightRootPatch.BackgroundTransparency-(if zone=="right"then .79 else .86))<.001)
     assert(region.CenterGoalRegion.Visible==(zone=="center"))
     if zone=="center"then
      assert(math.abs(region.CenterGoalRegion.BackgroundTransparency-.79)<.001 and region.CenterGoalRegion.BackgroundTransparency<region.LeftRootPatch.BackgroundTransparency and region.CenterGoalRegion.BackgroundTransparency<region.RightRootPatch.BackgroundTransparency,"active center must be distinct from neutral banks")
      assert(math.abs(region.CenterGoalRegion.Position.X.Scale-(.5-1.6/11.8))<.0001 and math.abs(region.CenterGoalRegion.Size.X.Scale-3.2/11.8)<.0001)
      assert(not region.CenterGoalRegion.Active and not region.CenterGoalRegion.Selectable)
     end
     assert(counter.Remaining.Text==text and counter:GetAttribute("AcceptedPulses")==pulses)
     for node,seat in pairs(seats)do assert(node.Position==seat[1]and node.Size==seat[2]and node.AbsoluteSize.X>=44 and node.AbsoluteSize.Y>=44)end
    end end
   end)
  end
  test("same current chain progress returns after save notice without a reset or callback",function()
   publish(public("lantern_chain",2,1));local quest=root.Status.ActiveQuest;local before=quest.Instruction:GetAttribute("AccessibleLabel")
   board:SetAttribute("SaveStatus","Retrying");settle();assert(not quest.Visible and root.Status.TextFits)
   board:SetAttribute("SaveStatus","Ready");settle();assert(quest.Visible);fit(quest.Instruction)
   assert(quest.Instruction:GetAttribute("AccessibleLabel")==before and quest.Instruction.Text:find("1/2",1,true))
   publish(public("lantern_chain",2,0));assert(quest.Instruction.Text:find("0/2",1,true))
  end)
 end)
 for key,value in pairs(saved)do board:SetAttribute(key,value[1])end;root.Size,root.Position=oldSize,oldPosition;settle()
 assert(ok,err);return cases
end
