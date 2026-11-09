-- Petting retains Back/rubbing input without a charm toggle or reserved layout.
return function(client,parentGui)
 local Focus=require(client.PetFocusUI);local Gui=game:GetService("GuiService");local previous=Gui.SelectedObject
 local focus=Focus.new(parentGui,{back=function()end,canOwnInput=function()return true end,canReact=function()return true end,petContact=function()end})
 local cases={};local ok,err=pcall(function()
  focus:setActive(true);focus.windowActive=true;focus:setCharmVisible(true,false,Color3.new(1,0,0))
  assert(not focus.panel:FindFirstChild("CharmToggle")and focus.charm==nil);table.insert(cases,"petting has no charm control or binding")
  focus:layoutActions();assert(focus.controlHeight==44);table.insert(cases,"removed charm reserves no extra headroom")
  Gui.SelectedObject=focus.back;focus.openingADevice=nil
  assert(focus:handleMove(Enum.UserInputState.Begin,{KeyCode=Enum.KeyCode.ButtonA,UserInputType=Enum.UserInputType.Gamepad1})==Enum.ContextActionResult.Pass);table.insert(cases,"Back retains native controller activation")
 end)
 focus:destroy();Gui.SelectedObject=previous;assert(ok,err);return cases
end
