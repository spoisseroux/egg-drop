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

-- Follow-up 2026-11-14 (round camera). The frozen camera used to stay wherever the roam
-- camera was: often behind the avatar, pushed against the island's invisible perimeter
-- wall, and that view shows faintly through the see-through deck. While the deck is up
-- the camera is parked instead: just above the avatar's head, looking in across the
-- garden toward the hub, with a slight downward tilt. The avatar is under and behind
-- the lens, and the view always points away from the island's edge.
Lock.ParkRise=4.5   -- studs above the HumanoidRootPart
Lock.ParkLead=1.5   -- studs toward the hub
Lock.ParkTilt=.15   -- downward slope of the look direction
Lock.ParkNear=10    -- closer to the hub than this: keep the current heading
-- Pure. origin: the avatar's root position. hub: a point in the middle of the garden.
-- look: the current camera look vector (used when the avatar stands at the hub).
-- Returns the parked CFrame, or nil when there is nothing sound to aim at.
function Lock.parkCFrame(origin,hub,look)
 if typeof(origin)~="Vector3"or typeof(hub)~="Vector3"then return nil end
 local flat=Vector3.new(hub.X-origin.X,0,hub.Z-origin.Z)
 if flat.Magnitude<Lock.ParkNear then
  flat=if typeof(look)=="Vector3"then Vector3.new(look.X,0,look.Z)else Vector3.zero
  if flat.Magnitude<.05 then flat=Vector3.new(0,0,-1)end
 end
 local dir=flat.Unit
 if dir~=dir then return nil end
 local position=origin+dir*Lock.ParkLead+Vector3.new(0,Lock.ParkRise,0)
 return CFrame.lookAt(position,position+dir-Vector3.new(0,Lock.ParkTilt,0))
end

-- Freezes `camera` (idempotent). Returns true when the camera is frozen after the call.
function Lock:freeze(camera)
 if not camera then return false end
 if self.frozen and self.camera==camera then return true end
 self:release()
 self.camera,self.previous,self.frozen=camera,camera.CameraType,true
 self.home=nil
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
 local camera,previous,home=self.camera,self.previous,self.home
 self.frozen,self.camera,self.previous,self.home=false,nil,nil,nil
 -- A parked camera goes back to the view it was frozen at before the type returns.
 if home and camera and camera.CameraType==Enum.CameraType.Scriptable then camera.CFrame=home end
 if camera and camera.CameraType==Enum.CameraType.Scriptable and previous and previous~=Enum.CameraType.Scriptable then
  camera.CameraType=previous
 end
 return true
end

-- Parks the frozen camera at Lock.parkCFrame (once per freeze; a camera that is not
-- ours any more is left alone). Returns true when the camera was moved.
function Lock:park(origin,hub)
 local camera=self.camera
 if not self.frozen or not camera or self.home or camera.CameraType~=Enum.CameraType.Scriptable then return false end
 local target=Lock.parkCFrame(origin,hub,camera.CFrame.LookVector)
 if not target then return false end
 self.home=camera.CFrame
 camera.CFrame=target
 return true
end

function Lock:isFrozen()return self.frozen==true end

return Lock
