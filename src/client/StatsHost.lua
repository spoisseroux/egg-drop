-- v2 S3: wires the stats panel and the level-up line into the client (init.client.lua
-- passes its few shared pieces in `deps`, so that file only gains a mount call and the
-- hooks that open the panel). Its own ScreenGui (DisplayOrder 13, like the book) and its
-- own ContextAction while open.
--
-- deps: parent (PlayerGui), insetProbe (Frame), state() -> nursery snapshot,
--   activeId() -> companion pet id, appearance(petId), canOpen() -> bool,
--   prepare() (close other screens), held() -> bool (a round is on: hold the line),
--   reopenHub() (Back to the Companions hub), closed(reason)
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Kit=require(script.Parent.DeckKit)
local Panel=require(script.Parent.StatsPanel)
local Toasts=require(script.Parent.StatToasts)
local Rail=require(script.Parent.NotificationRail)
local Host={}

function Host.mount(deps)
 local gui=Instance.new("ScreenGui")
 gui.Name="EggDropStats";gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=13
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ClipToDeviceSafeArea=false;gui.Parent=deps.parent
 local host=Instance.new("Frame");host.Name="StatsHost";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
 local function syncInsets()
  local wanted=Kit.compactInsets(deps.insetProbe.AbsoluteSize)
  if gui.ScreenInsets~=wanted then gui.ScreenInsets=wanted end
 end
 local connections={deps.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInsets)}
 local function context()
  local state=deps.state()
  return{wallet=state and state.nectar or 0,state=state or {},activeId=deps.activeId()}
 end
 local api={}
 local panel=Panel.new(host,{
  appearance=function(petId)return deps.appearance(petId)end,
  back=function(from)if from=="hub"and deps.reopenHub then deps.reopenHub()end end,
  closed=function(reason,from)if deps.closed then deps.closed(reason,from)end end})
 api.panel=panel
 -- options: stat, petId, from ("hub" | "focus" | "rail"), slideFrom.
 function api.open(options)
  if panel:isOpen()or not deps.state()or not deps.canOpen()then return false end
  deps.prepare()
  if GuiService.SelectedObject then GuiService.SelectedObject=nil end
  syncInsets()
  return panel:open(context(),options)
 end
 function api.isOpen()return panel:isOpen()end
 function api.close(reason)return panel:close(reason or "close")end
 local toasts=Toasts.new({rail=Rail,owner=host,held=deps.held,
  open=function(stat,petId)api.open({stat=stat,petId=petId,from="rail"})end})
 api.toasts=toasts
 function api.sync(state)
  if type(state)~="table"then return end
  toasts:update(state.petStats)
  if panel:isOpen()then panel:setContext(context())end
 end
 -- Held lines flush once the round's results show (checked each frame; cheap).
 table.insert(connections,game:GetService("RunService").Heartbeat:Connect(function()if toasts.pending then toasts:flush()end end))
 local K=Enum.KeyCode
 local keys={K.Left,K.Right,K.Up,K.Down,K.A,K.D,K.W,K.S,K.Q,K.E,K.X,K.ButtonX,K.ButtonL1,K.ButtonR1,K.DPadLeft,K.DPadRight,K.DPadUp,K.DPadDown,
  K.Space,K.Return,K.KeypadEnter,K.ButtonA,K.ButtonB,K.Backspace,K.Escape,K.M,K.ButtonY,K.ButtonStart}
 -- Above the Companions hub (High+790) and the Wardrobe (High+800): the panel owns input while open.
 ContextActionService:BindActionAtPriority("EggDropStats",function(_,state,input)
  if not panel:isOpen()or UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
  if state==Enum.UserInputState.Begin then panel:input(input.KeyCode)end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+805,table.unpack(keys))
 syncInsets()
 function api.destroy()
  ContextActionService:UnbindAction("EggDropStats")
  for _,c in ipairs(connections)do c:Disconnect()end
  panel:destroy();gui:Destroy()
 end
 return api
end
return Host
