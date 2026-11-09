-- Bounded cosmetic arm overlay, restored before the next animator evaluation.
-- AnimationConstraint.Transform shares the Motor6D animation seam. Attachment
-- frames and all physics/kinematic settings remain owned by the avatar rig.
local Pose={};Pose.__index=Pose
local function supported(joint)return joint and(joint:IsA("AnimationConstraint")or joint:IsA("Motor6D"))end
local function findJoint(parent,name,legacy)
 if not parent then return nil end
 local motor
 for _,child in ipairs(parent:GetChildren())do if child.Name==name or child.Name==legacy then
  if child:IsA("AnimationConstraint")then return child elseif child:IsA("Motor6D")then motor=child end
 end end
 return motor
end
local function frames(joint)
 if not supported(joint)then return nil end
 if joint:IsA("AnimationConstraint")then
  local a,b=joint.Attachment0,joint.Attachment1
  if not a or not b or not a.Parent or not b.Parent or not a.Parent:IsA("BasePart")or not b.Parent:IsA("BasePart")then return nil end
  return a.Parent,b.Parent,a.CFrame,b.CFrame
 end
 if joint.Part0 and joint.Part1 then return joint.Part0,joint.Part1,joint.C0,joint.C1 end
end
local function held(base,rotation)return CFrame.new(base.Position)*rotation end
function Pose.new()return setmetatable({active={},wanted={}},Pose)end
function Pose:restore()
 for motor,base in pairs(self.active)do if motor.Parent then motor.Transform=base end end;table.clear(self.active)
end
function Pose:hold(character,targets)
 if not character or not character.Parent then return end
 for side,target in ipairs(targets)do
  local label=if side==1 then "Left"else "Right"
  local torso=character:FindFirstChild("UpperTorso")or character:FindFirstChild("Torso")
  local upper=character:FindFirstChild(label.."UpperArm")
  local shoulder=findJoint(upper,label.."Shoulder",label.." Shoulder")or findJoint(torso,label.."Shoulder",label.." Shoulder")
  local part0,_,c0,c1=frames(shoulder)
  if part0 then
   local base=self.active[shoulder]or shoulder.Transform
   -- Carry owns arm rotations, rather than correcting a capped amount from the
   -- current walk swing. The animator base remains restoration-only.
   local joint=part0.CFrame*c0*CFrame.new(base.Position);local vector=joint:VectorToObjectSpace(target-joint.Position)
   if vector.Magnitude>.001 then
    local rest=c1:VectorToObjectSpace(Vector3.new(0,-1,0)).Unit;local desired=vector.Unit
    local dot=math.clamp(rest:Dot(desired),-1,1);local axis=rest:Cross(desired);local rotation=CFrame.identity
    if axis.Magnitude<.000001 and dot<0 then axis=rest:Cross(if math.abs(rest.X)<.8 then Vector3.xAxis else Vector3.zAxis)end
    if axis.Magnitude>=.000001 then rotation=CFrame.fromAxisAngle(axis.Unit,math.min(math.rad(64),math.acos(dot)))end
    self.active[shoulder]=base;shoulder.Transform=held(base,rotation)
   end
  end
  local lower=character:FindFirstChild(label.."LowerArm");local elbow=findJoint(lower,label.."Elbow",label.." Elbow")
  if frames(elbow)then local base=self.active[elbow]or elbow.Transform;self.active[elbow]=base;elbow.Transform=held(base,CFrame.Angles(math.rad(-48),0,0))end
 end
end
function Pose:destroy()self:restore()end
return Pose
