-- Same activation route as the native44px control; no remote sends or profile writes.
return function(client,parentGui)
 local Focus=require(client.PetFocusUI);local Gui=game:GetService("GuiService")
 local changes,contacts,cases={},{},{};local owner=true
 local focus=Focus.new(parentGui,{back=function()end,canOwnInput=function()return owner end,canReact=function()return true end,
  petContact=function(active)table.insert(contacts,active)end,charmToggle=function(visible)table.insert(changes,visible)end})
 local function test(name,run)run();table.insert(cases,name)end
 local previous=Gui.SelectedObject
 local ok,err=pcall(function()
  focus:setActive(true);focus.windowActive=true
  test("confirmed on/off/pending state and44px accessible control",function()
   focus:setCharmVisible(true,false,Color3.fromHex("#F52C88"));assert(focus.charm.Visible and focus.charm.Size.X.Offset>=160 and focus.charm.Size.Y.Offset>=44)
   assert(focus.charm.Text=="Hide charm"and focus.charm:GetAttribute("AccessibleLabel")=="Hide charm"and focus.charmDot.BackgroundTransparency==0)
   assert(focus:toggleCharm()and changes[1]==false and focus.charmVisible==true,"request must not optimistically repaint")
   focus:setCharmVisible(false,true);assert(not focus:toggleCharm()and #changes==1 and not focus.charm.Interactable and focus.charm.Text=="Saving…")
   focus:setCharmVisible(false,false);assert(focus.charm:GetAttribute("AccessibleLabel")=="Show charm"and focus:toggleCharm()and changes[2])
  end)
  test("toggling cancels active contact and relinquishes gamepad A to selected control",function()
   focus.contactAttempted=true;focus.pointer={UserInputType=Enum.UserInputType.Touch};focus.contactDeadline=os.clock()+1
   assert(focus:toggleCharm()and contacts[#contacts]==false and focus.pointer==nil)
   Gui.SelectedObject=focus.charm;focus.openingADevice=nil
   assert(focus:handleMove(Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.ButtonA,UserInputType=Enum.UserInputType.Gamepad1})==Enum.ContextActionResult.Pass)
  end)
  test("unsupported, hidden owner and inactive controls cannot send",function()
   local count=#changes;focus:setCharmVisible(nil);assert(not focus.charm.Visible and not focus:toggleCharm())
   focus:setCharmVisible(true);owner=false;assert(not focus:toggleCharm());owner=true;focus:setActive(false);assert(not focus:toggleCharm()and #changes==count)
  end)
 end)
 focus:destroy();Gui.SelectedObject=previous;assert(ok,err);return cases
end
