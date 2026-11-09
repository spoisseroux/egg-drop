-- Real constructors with real ScreenGui/Frame ancestry. No live profile or sends.
return function(client,parentGui)
 local Players=game:GetService("Players");local Replicated=game:GetService("ReplicatedStorage")
 local Run=game:GetService("RunService");local Focus=require(client.PetFocusUI);local Care=require(client.GardenCareClient);local Room=require(client.RoomView)
 local cases={};local cleanups={};local errors={}
 local output=game:GetService("LogService").MessageOut:Connect(function(message,kind)if kind==Enum.MessageType.MessageError then table.insert(errors,message)end end)
 local function test(name,run)run();table.insert(cases,name)end
 local function screen()
  local gui=Instance.new("ScreenGui");gui.Name="_CareConstructorSmoke";gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=parentGui or Players.LocalPlayer:WaitForChild("PlayerGui")
  table.insert(cleanups,function()gui:Destroy()end);return gui
 end
 local function settle()for _=1,4 do Run.RenderStepped:Wait()end end
 local function audio()
  return {deviceActive=true,group={Volume=1},play=function()error("startup must not play a care cue")end,stopOwner=function()end,petSpeechBusy=function()return false end}
 end
 local ok,problem=pcall(function()
  test("actual Care.new accepts production ScreenGui and owns a full safe Frame for notice and setdown",function()
   local gui=screen();local focus=Focus.new(gui,{canOwnInput=function()return false end,canReact=function()return false end})
   table.insert(cleanups,function()if not focus.destroyed then focus:destroy()end end)
   local room={focusUI=focus,mode="Board",target="Board",shownPet={id="pip",name="Zivvi"},garden={get=function()return nil end,snapshot={}},overlayOpen=function()return false end}
   local care=Care.new(room,gui);table.insert(cleanups,function()if not care.destroyed then care:destroy()end end)
   settle();care:step()
   assert(care.gui:IsA("ScreenGui")and care.uiRoot:IsA("Frame")and care.uiRoot.Parent==gui)
   assert(care.notice.Parent==care.uiRoot and care.setDown.Parent==care.uiRoot and care.uiRoot.Size==UDim2.fromScale(1,1)and not care.uiRoot.Active)
   assert(care.pickup.Parent==focus.panel and not care.notice.Visible and not care.setDown.Visible)
   focus.gui.Enabled=false;care:step();assert(care.uiRoot.Parent==gui,"carry controls borrowed the retiring focus GUI")
   care:destroy();assert(care.controls.Parent==nil and care.notice.Parent==nil and care.pickup.Parent==nil);focus:destroy()
  end)
  test("actual Room.new and render steps complete with production ScreenGui before any companion or profile action",function()
   local gui=screen();local board=Instance.new("Frame");board.Name="Backdrop";board.Size=UDim2.fromScale(1,1);board.Parent=gui
   local tray=Instance.new("Frame");tray.Name="Tray";tray.Size=UDim2.fromOffset(300,200);tray.Parent=board
   local boards=Instance.new("Folder");boards.Name="_CareStartupBoards";boards.Parent=Replicated;table.insert(cleanups,function()boards:Destroy()end)
   local progress=Instance.new("Folder");progress.Name=tostring(Players.LocalPlayer.UserId);progress:SetAttribute("Mode","Board");progress:SetAttribute("InventoryMask",0);progress.Parent=boards
   local sent=0;local room=Room.new(gui,board,progress,audio(),function()sent+=1 end,function()sent+=1 end,function()sent+=1 end,function()return false end,function()return true end)
   table.insert(cleanups,function()if not room.destroyed then room:destroy()end end)
   room.garden.remote={FireServer=function()sent+=1 end}
   settle();assert(room.care and room.care.controls:IsDescendantOf(gui)and room.care.notice.Parent==room.care.controls)
   assert(room.mode=="Board"and room.pet==nil and sent==0 and not room.care.pickup.Visible and not room.care.setDown.Visible)
   room:destroy();assert(room.destroyed and gui:FindFirstChild("GardenCareControls")==nil)
   settle();assert(sent==0,"constructor/teardown emitted an unrelated operation")
  end)
 end)
 for i=#cleanups,1,-1 do pcall(cleanups[i])end;output:Disconnect()
 assert(ok,problem);assert(#errors==0,"constructor/render emitted errors: "..table.concat(errors," | "))
 return {passed=#cases,cases=cases}
end
