-- Garden camera clamp (QA v2 R2.3): the camera clipped through the island's ground and
-- rocks. The island's visible meshes do not collide; its collision is the invisible
-- W7C_* meshes (Transparency 1), and Roblox's Zoom occlusion (Poppercam) ignores parts
-- that are not opaque, so nothing stopped the camera. After the camera module runs,
-- one sphere cast from the camera focus toward the camera, against the lounge's
-- colliding geometry only, pulls the camera in front of the first hit. Cheap: one cast
-- a frame, only while the garden camera is a Custom (player-driven) camera.
local Clamp={}
Clamp.__index=Clamp
Clamp.Action="EggDropCameraClamp"
Clamp.Radius=.5 -- sphere radius (near plane plus a margin)
Clamp.Pad=.1 -- extra pull-in past the sphere's touch point
Clamp.MinDistance=.5 -- never closer to the focus than this (first person is left alone)

-- Pure. focus, camera: Vector3. hitDistance: how far the cast travelled before touching
-- (nil = nothing in the way). Returns the clamped camera position, or nil when the
-- camera can stay where it is.
function Clamp.resolve(focus,camera,hitDistance,pad,minDistance)
 if type(hitDistance)~="number"then return nil end
 pad=pad or Clamp.Pad;minDistance=minDistance or Clamp.MinDistance
 local offset=camera-focus
 local length=offset.Magnitude
 if length<=minDistance then return nil end
 local allowed=math.max(minDistance,hitDistance-pad)
 if allowed>=length then return nil end
 return focus+offset.Unit*allowed
end

-- options: active() -> bool (garden roam), world() -> Instance (the lounge root) or nil,
-- run (RunService), cast(origin, radius, direction, params) -> RaycastResult (optional).
function Clamp.new(options)
 local self=setmetatable({active=options.active,world=options.world,run=options.run,cast=options.cast,clamped=0},Clamp)
 self.params=RaycastParams.new()
 self.params.FilterType=Enum.RaycastFilterType.Include
 self.params.RespectCanCollide=true
 if self.run and self.run.BindToRenderStep then
  self.bound=true
  -- After the camera module (Camera) and the modal cursor (Camera + 1).
  self.run:BindToRenderStep(Clamp.Action,Enum.RenderPriority.Camera.Value+2,function()self:step()end)
 end
 return self
end

-- Code review: only the static world (W7 meshes and their W7C_ colliders) stops the
-- camera; machines, doors and pets under the lounge never pull it in.
function Clamp.isWorld(instance)
 return instance~=nil and string.sub(instance.Name,1,2)=="W7"
end
function Clamp:castFrom(origin,direction)
 if self.cast then return self.cast(origin,Clamp.Radius,direction,self.params)end
 local ok,result=pcall(workspace.Spherecast,workspace,origin,Clamp.Radius,direction,self.params)
 if not ok then result=workspace:Raycast(origin,direction,self.params)end
 if result and not Clamp.isWorld(result.Instance)then return nil end
 return result
end

function Clamp:step()
 if self.destroyed then return false end
 local okActive,active=pcall(self.active)
 if not okActive or active~=true then return false end
 local camera=workspace.CurrentCamera
 if not camera or camera.CameraType~=Enum.CameraType.Custom then return false end
 local root=self.world and self.world()
 if not root then return false end
 if self.root~=root then self.root=root;self.params.FilterDescendantsInstances={root}end
 local cframe=camera.CFrame
 local focus=camera.Focus.Position
 local offset=cframe.Position-focus
 if offset.Magnitude<=Clamp.MinDistance then return false end
 local hit=self:castFrom(focus,offset)
 local clamped=Clamp.resolve(focus,cframe.Position,hit and hit.Distance)
 if not clamped then return false end
 camera.CFrame=cframe.Rotation+clamped
 self.clamped+=1
 return true
end

function Clamp:destroy()
 if self.destroyed then return end
 self.destroyed=true
 if self.bound then pcall(function()self.run:UnbindFromRenderStep(Clamp.Action)end)end
end

return Clamp
