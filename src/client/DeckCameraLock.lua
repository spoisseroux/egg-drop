-- World camera freeze while the Pocket Deck is up (QA 2026-11-13 Q1 item 1).
-- In Board mode the world camera stays the player's Custom camera behind the deck,
-- so a right-drag, the scroll wheel or a touch pan beside the board still turned and
-- zoomed it. While the deck is up the camera is Scriptable (it holds its CFrame and
-- ignores every camera input); leaving the deck puts the previous type back. Mouse
-- aim, taps and keys are GUI / ContextAction input and are not affected.
-- Owned by RoomView: freeze in show("Board"), release before show("Room") restores
-- the roaming camera.
local UserInputService=game:GetService("UserInputService")
local Lock={}
Lock.__index=Lock

function Lock.new()
 return setmetatable({frozen=false},Lock)
end

-- Freezes `camera` (idempotent). Returns true when the camera is frozen after the call.
function Lock:freeze(camera)
 if not camera then return false end
 if self.frozen and self.camera==camera then return true end
 self:release()
 self.camera,self.previous,self.frozen=camera,camera.CameraType,true
 if camera.CameraType~=Enum.CameraType.Scriptable then camera.CameraType=Enum.CameraType.Scriptable end
 -- A held right-drag or shift lock must not leave the mouse locked behind the deck.
 pcall(function()
  if UserInputService.MouseBehavior~=Enum.MouseBehavior.Default then UserInputService.MouseBehavior=Enum.MouseBehavior.Default end
 end)
 return true
end

-- Puts the previous camera type back. A camera someone else has since taken over
-- (its type is no longer the Scriptable we set) is left alone.
function Lock:release()
 if not self.frozen then return false end
 local camera,previous=self.camera,self.previous
 self.frozen,self.camera,self.previous=false,nil,nil
 if camera and camera.CameraType==Enum.CameraType.Scriptable and previous and previous~=Enum.CameraType.Scriptable then
  camera.CameraType=previous
 end
 return true
end

function Lock:isFrozen()return self.frozen==true end

return Lock
