-- Real upgraded avatar joints. No Motor6D, attachment edits, physics/settings change.
return function(client)
 local Pose=require(client.AvatarCarePose);local cases={};local folder=Instance.new("Folder");folder.Parent=workspace
 local function test(name,run)run();table.insert(cases,name)end
 local function close(a,b)
  local x,y={a:GetComponents()},{b:GetComponents()};for i=1,12 do if math.abs(x[i]-y[i])>1e-7 then return false end end;return true
 end
 local function difference(a,b)
  local x,y={a:GetComponents()},{b:GetComponents()};local maximum=0
  for i=1,12 do maximum=math.max(maximum,math.abs(x[i]-y[i]))end
  local delta=a:ToObjectSpace(b);local _,angle=delta:ToAxisAngle();return maximum,delta.Position.Magnitude,angle
 end
 local function nativeWrite(joint,frame)
  local control=Instance.new("AnimationConstraint");control.Attachment0=joint.Attachment0;control.Attachment1=joint.Attachment1;control.Parent=joint.Parent;control.Transform=frame
  local readback=control.Transform;control:Destroy();return readback
 end
 local function fixture()
  local model=Instance.new("Model");model.Parent=folder
  local function part(name,position)local p=Instance.new("Part");p.Name=name;p.Size=Vector3.new(1,1.5,1);p.Anchored=true;p.CanCollide=false;p.Position=position;p.Parent=model;return p end
  local torso=part("UpperTorso",Vector3.new(0,7,0));local joints={};local original={};local attachments={}
  local function joint(name,a,b,offset)
   local a0=Instance.new("Attachment");a0.Name=name.."RigAttachment";a0.CFrame=CFrame.new(offset)*CFrame.Angles(.02,.03,.04);a0.Parent=a
   local a1=Instance.new("Attachment");a1.Name=name.."RigAttachment";a1.CFrame=CFrame.new(0,.6,0)*CFrame.Angles(.2,-.11,.27);a1.Parent=b
   local c=Instance.new("AnimationConstraint");c.Name=name;c.Attachment0=a0;c.Attachment1=a1;c.IsKinematic=true;c.Transform=CFrame.new(.03,.02,-.01)*CFrame.Angles(.12,-.05,.04);c.Parent=b
   table.insert(joints,c);original[c]=c.Transform;attachments[a0]=a0.CFrame;attachments[a1]=a1.CFrame;return c
  end
  for _,label in ipairs({"Left","Right"})do local side=if label=="Left"then -1 else 1
   local upper=part(label.."UpperArm",Vector3.new(side*1.3,7,0));local lower=part(label.."LowerArm",Vector3.new(side*1.3,5.7,0))
   joint(label.."Shoulder",torso,upper,Vector3.new(side,1,0));joint(label.."Elbow",upper,lower,Vector3.new(0,-.6,0))
  end
  return model,joints,original,attachments
 end
 local targets={Vector3.new(-.4,5.8,-1.2),Vector3.new(.4,5.7,-1.2)}
 local ok,problem=pcall(function()
  test("zero-Motor R15 AnimationConstraint shoulders and elbows receive a visible procedural transform",function()
   local model,joints,original,attachments=fixture();local pose=Pose.new()
   for _,n in ipairs(model:GetDescendants())do assert(not n:IsA("Motor6D"))end
   local settings={};for _,c in ipairs(joints)do settings[c]={c.Enabled,c.IsKinematic,c.MaxForce,c.MaxTorque}end
   pose:hold(model,targets)
   for _,c in ipairs(joints)do
    assert(pose.active[c]and not close(c.Transform,original[c]),c.Name.." silently received no pose")
    assert((c.Transform.Position-original[c].Position).Magnitude<1e-7,"animator translation changed")
    local s=settings[c];assert(c.Enabled==s[1]and c.IsKinematic==s[2]and c.MaxForce==s[3]and c.MaxTorque==s[4])
    if c.Name:find("Shoulder",1,true)then
     local target=targets[if c.Name:find("Left",1,true)then 1 else 2]
     local joint=c.Attachment0.WorldCFrame*CFrame.new(original[c].Position)
     local actual=(c.Attachment0.WorldCFrame*c.Transform*c.Attachment1.CFrame:Inverse()):VectorToWorldSpace(Vector3.new(0,-1,0)).Unit
     assert(actual:Dot((target-joint.Position).Unit)>.99999,"rotated child attachment used the wrong coordinate frame")
    end
   end
   for a,frame in pairs(attachments)do assert(close(a.CFrame,frame),"rig attachment was edited")end
   local captured=table.clone(pose.active)
   pose:restore();for _,c in ipairs(joints)do
    local maximum,position,angle=difference(original[c],c.Transform)
    local captureMaximum,capturePosition,captureAngle=difference(original[c],assert(captured[c],"joint was not captured"))
    -- Same class and attached frame, but an independent one-write control. Never
    -- rewrite the measured subject before capture or its normalization is hidden.
    local controlRead=nativeWrite(c,captured[c])
    local setterMaximum,setterPosition,setterAngle=difference(captured[c],controlRead)
    local extraMaximum,extraPosition,extraAngle=difference(controlRead,c.Transform)
    assert(close(captured[c],original[c]),"first capture lost the unmodified animator base")
    assert(position<=1e-7,"restoration translated the original joint")
    assert(close(c.Transform,controlRead),string.format("%s animator restore differs from native one-write control: original maxcomponent %.12g position %.12g angle %.12g; firstcapture maxcomponent %.12g position %.12g angle %.12g; native-noopsetter maxcomponent %.12g position %.12g angle %.12g; restore-vs-control maxcomponent %.12g position %.12g angle %.12g; initial %s captured %s restored %s control %s",c:GetFullName(),maximum,position,angle,captureMaximum,capturePosition,captureAngle,setterMaximum,setterPosition,setterAngle,extraMaximum,extraPosition,extraAngle,tostring(original[c]),tostring(captured[c]),tostring(c.Transform),tostring(controlRead)))
   end
   pose:destroy()
  end)
  test("repeated hold in one frame captures first base once and cannot accumulate its own overlay",function()
   local model,joints,original=fixture();local pose=Pose.new();pose:hold(model,targets);local first={}
   for _,c in ipairs(joints)do first[c]=c.Transform end
   pose:hold(model,targets)
   for _,c in ipairs(joints)do assert(close(c.Transform,first[c])and close(pose.active[c],original[c]))end
   pose:restore();for _,c in ipairs(joints)do assert(close(c.Transform,nativeWrite(c,original[c])))end
  end)
  test("fresh animator base next frame is layered and restored rather than an old capture",function()
   local model,joints=fixture();local pose=Pose.new();pose:hold(model,targets);pose:restore();local changed={}
   for _,c in ipairs(joints)do c.Transform=CFrame.new(-.02,.04,.01)*CFrame.Angles(-.06,.04,.11);changed[c]=c.Transform end
   pose:hold(model,targets);for _,c in ipairs(joints)do assert(close(pose.active[c],changed[c]))end
   pose:restore();for _,c in ipairs(joints)do assert(close(c.Transform,nativeWrite(c,changed[c])))end
  end)
  test("removed attachment and destroyed joint cannot transfer stale restore into a replacement",function()
   local model,joints=fixture();local pose=Pose.new();pose:hold(model,targets)
   local old=joints[1];local part=old.Parent;local a0,a1=old.Attachment0,old.Attachment1;local name=old.Name;old:Destroy()
   local replacement=Instance.new("AnimationConstraint");replacement.Name=name;replacement.Attachment0=a0;replacement.Attachment1=a1;replacement.Transform=CFrame.Angles(.2,.1,.3);replacement.Parent=part
   local base=replacement.Transform;pose:restore();assert(close(replacement.Transform,base))
   replacement.Attachment0=nil;pose:hold(model,targets);assert(not pose.active[replacement]);pose:destroy()
  end)
  test("opposing animated run swings cannot alter carried shoulders elbows or untouched leg locomotion",function()
   local model,joints=fixture();local pose=Pose.new();local heldFrames={}
   local leg=Instance.new("AnimationConstraint");leg.Name="LeftHip";leg.Parent=model
   local phases={CFrame.Angles(math.rad(115),.2,-.3),CFrame.Angles(math.rad(-105),-.4,.5),CFrame.Angles(.03,.2,-.1),CFrame.identity}
   for phase,rotation in ipairs(phases)do
    local before={}
    for i,c in ipairs(joints)do c.Transform=CFrame.new(.03,.02,-.01)*(if i%2==0 then rotation:Inverse()else rotation);before[c]=c.Transform end
    leg.Transform=CFrame.new(0,.01,0)*CFrame.Angles(phase*.2,-.03,.07);local legFrame=leg.Transform
    pose:hold(model,targets)
    for _,c in ipairs(joints)do
     assert(close(pose.active[c],before[c]),"run base was not captured exactly")
     if phase==1 then heldFrames[c]=c.Transform else assert(close(c.Transform,heldFrames[c]),c.Name.." retained animated run swing")end
     assert((c.Transform.Position-before[c].Position).Magnitude<1e-7)
    end
    assert(close(leg.Transform,legFrame),"carry adapter overrode leg locomotion")
    pose:restore();for _,c in ipairs(joints)do assert(close(c.Transform,nativeWrite(c,before[c])),"distinct run animation base not restored")end
   end
  end)
  test("a near-axis carry target explicitly replaces a nonneutral animated shoulder pose",function()
   local model,joints=fixture();local pose=Pose.new();local a=joints[1];local base=CFrame.new(.03,.02,-.01)*CFrame.Angles(1.4,.3,-.2);a.Transform=base;base=a.Transform
   local neutral=a.Attachment0.WorldCFrame*CFrame.new(base.Position)
   local down=a.Attachment1.CFrame:VectorToObjectSpace(Vector3.new(0,-1,0)).Unit
   local aligned={neutral.Position+neutral:VectorToWorldSpace(down)*2,targets[2]}
   pose:hold(model,aligned);assert(pose.active[a]and close(a.Transform,nativeWrite(a,CFrame.new(base.Position))),"parallel target left the walk transform active")
   pose:restore();assert(close(a.Transform,nativeWrite(a,base)))
   pose:hold(model,{neutral.Position-neutral:VectorToWorldSpace(down)*2,targets[2]})
   local _,turn=a.Transform.Rotation:ToAxisAngle()
   assert(turn>math.rad(63.9)and turn<math.rad(64.1),"antiparallel target was mistaken for aligned or escaped the bind limit")
   pose:restore();assert(close(a.Transform,nativeWrite(a,base)))
  end)
 end)
 folder:Destroy();assert(ok,problem);return {passed=#cases,cases=cases}
end
