-- Modal cursor (QA 2026-11-13 Q2.5). Alt-tabbing back while a menu screen was open
-- left the cursor hidden and the camera holding the mouse (a lost right-button
-- release or a locked MouseBehavior), so the player was stuck. While any modal UI is
-- open this keeps the cursor free: a hidden Modal button (Roblox's own "free the
-- mouse" switch), MouseBehavior Default and the icon on, re-applied after the camera
-- each frame and at once when the window regains focus. The right mouse button is
-- sunk while a screen is open so the camera never starts a drag under a menu.
-- Everything Roblox-facing is injected so the rules run in a spec.
--
-- Beta (17) U2: the "?" cards, Confirm and the arrival hatch were not in init.client's
-- hand-kept screen list, so the Napping egg card opened with the camera still holding
-- the mouse (shift lock or a right-drag) and "Got it" could not be clicked. Any card
-- with a button now registers itself here (Cursor.register(key, isOpen)) and the cursor
-- is free whenever one says it is open. A registered card frees the cursor and sinks the
-- right button; only the screen list (options.isOpen) also takes the "modal" movement
-- lock, so a card keeps its own key handling (and PetInspect still closes on walking away).
local Cursor={}
Cursor.__index=Cursor
Cursor.Action="EggDropModalCursor"

-- The registry: key (any value; a card instance is fine) -> isOpen() -> bool. Module
-- state, shared by every require on the client.
local cards={}
-- Registers (or replaces) a card. Returns a function that removes this registration.
function Cursor.register(key,isOpen)
 if key==nil or type(isOpen)~="function"then return function()end end
 cards[key]=isOpen
 return function()if cards[key]==isOpen then cards[key]=nil end end
end
function Cursor.unregister(key)if key~=nil then cards[key]=nil end end
-- True (and the key) when any registered card says it is open. A card that errors counts as closed.
function Cursor.cardOpen()
 for key,isOpen in pairs(cards)do
  local ok,open=pcall(isOpen)
  if ok and open==true then return true,key end
 end
 return false,nil
end
-- Specs: how many cards are registered.
function Cursor.registered()local n=0;for _ in pairs(cards)do n+=1 end;return n end

-- Pure: the MouseBehavior / icon a frame should end with (nil = leave it alone).
function Cursor.wanted(open,behavior,iconEnabled)
 if not open then return nil,nil end
 return(if behavior~=Enum.MouseBehavior.Default then Enum.MouseBehavior.Default else nil),(if iconEnabled~=true then true else nil)
end

-- options: isOpen() -> bool, input (UserInputService), run (RunService),
-- actions (ContextActionService), parent (PlayerGui; optional for the Modal button),
-- movement (MovementLock; optional): QA v2 R2.1/R2.2, the avatar cannot walk while a
-- modal screen is open; the lock is taken as reason "modal" on the open edge.
function Cursor.new(options)
 local self=setmetatable({isOpen=options.isOpen,input=options.input,run=options.run,actions=options.actions,movement=options.movement,open=false,free=false,connections={},refocused=0},Cursor)
 if options.parent then
  local gui=Instance.new("ScreenGui");gui.Name="EggDropModalCursor";gui.ResetOnSpawn=false;gui.DisplayOrder=0;gui.Enabled=true
  local button=Instance.new("TextButton");button.Name="Modal";button.Text="";button.BackgroundTransparency=1;button.Size=UDim2.fromOffset(1,1)
  button.Position=UDim2.fromOffset(0,0);button.Selectable=false;button.AutoButtonColor=false;button.Active=false;button.Modal=true;button.Visible=false
  button.Parent=gui;gui.Parent=options.parent
  self.gui,self.button=gui,button
 end
 if self.input then
  table.insert(self.connections,self.input.WindowFocused:Connect(function()self:windowFocused()end))
 end
 if self.run and self.run.BindToRenderStep then
  self.bound=true
  self.run:BindToRenderStep(Cursor.Action,Enum.RenderPriority.Camera.Value+1,function()self:step()end)
 end
 return self
end

-- The screen list's edge: the movement lock.
function Cursor:setOpen(open)
 open=open==true
 if self.open==open then return end
 self.open=open
 if self.movement then self.movement:set("modal",open)end
end
-- A screen or a registered card: the Modal button and the sunk right button.
function Cursor:setFree(free)
 free=free==true
 if self.free==free then return end
 self.free=free
 if self.button then self.button.Visible=free end
 if self.actions then
  if free then
   self.actions:BindActionAtPriority(Cursor.Action,function()return Enum.ContextActionResult.Sink end,false,Enum.ContextActionPriority.High.Value+900,Enum.UserInputType.MouseButton2)
  else self.actions:UnbindAction(Cursor.Action)end
 end
end

function Cursor:apply()
 if not self.input then return end
 local behavior,icon=Cursor.wanted(self.free,self.input.MouseBehavior,self.input.MouseIconEnabled)
 if behavior then self.input.MouseBehavior=behavior end
 if icon then self.input.MouseIconEnabled=icon end
end

function Cursor:step()
 if self.destroyed then return end
 local ok,open=pcall(self.isOpen)
 open=ok and open==true
 self:setOpen(open)
 self:setFree(open or Cursor.cardOpen())
 -- A lock taken before the PlayerModule loaded (the deck at boot) or controls another
 -- script re-enabled are disabled here; one cached read per frame when nothing is held.
 if self.movement then self.movement:enforce()end
 self:apply()
end

function Cursor:windowFocused()
 if self.destroyed then return end
 self.refocused+=1
 -- The camera may still think the right button is down: re-free the cursor now and
 -- again after the camera's next frames.
 self:step()
 task.defer(function()self:step()end)
 task.delay(.1,function()self:step()end)
end

function Cursor:destroy()
 if self.destroyed then return end
 self.destroyed=true
 for _,c in ipairs(self.connections)do c:Disconnect()end
 if self.bound then pcall(function()self.run:UnbindFromRenderStep(Cursor.Action)end)end
 if self.actions and self.free then self.actions:UnbindAction(Cursor.Action)end
 if self.movement then self.movement:release("modal")end
 if self.gui then self.gui:Destroy()end
end
return Cursor
