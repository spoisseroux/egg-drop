-- Versioned, deterministic presentation. Never awards or mutates a profile.
local Activity = { Version = 1 }
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function Activity.pack(v) return {v.X,v.Y,v.Z} end
function Activity.vector(v)
    if type(v)~="table" or not finite(v[1]) or not finite(v[2]) or not finite(v[3]) then return nil end
    if math.abs(v[1])>10000 or math.abs(v[2])>10000 or math.abs(v[3])>10000 then return nil end
    return Vector3.new(v[1],v[2],v[3])
end
-- Cubic Bezier derivative controls bound speed over the whole leg, not just
-- selected sample frames. Incoming/outgoing velocities match at every retarget.
local ZERO=Vector3.zero
local function angle(a,b) return math.atan2(math.sin(b-a),math.cos(b-a)) end
function Activity.leg(from,to,v0,v1,speed,minimum,yaw)
    speed=math.max(.1,speed,v0.Magnitude,v1.Magnitude)
    local delta=to-from;local d2=delta:Dot(delta);local combined=v0+v1
    local duration=math.max(.25,minimum or 0)
    if d2>.000001 then
        local projection=delta:Dot(combined)
        local discriminant=projection*projection+d2*(speed*speed-combined:Dot(combined))
        if discriminant<0 then return nil end
        local maximum=(projection+math.sqrt(discriminant))/d2
        if maximum<.00001 then return nil end
        duration=math.max(duration,3/maximum)
    elseif v0.Magnitude>.001 or v1.Magnitude>.001 then return nil end
    -- Feasibility alone is insufficient for a nearly opposite incoming
    -- velocity: its solution can take minutes and leave the clearing.
    -- Every leg has an explicit duration and control-hull excursion budget.
    if duration>math.max(.25,minimum or 0)+3*delta.Magnitude/speed+.001
        or v0.Magnitude*duration/3>delta.Magnitude+v0.Magnitude*.125+.01
        or v1.Magnitude*duration/3>delta.Magnitude+v1.Magnitude*.125+.01 then return nil end
    if (3*delta/duration-combined).Magnitude>speed+.0001 then return nil end
    local heading=if delta.Magnitude>.02 then math.atan2(delta.X,delta.Z)else yaw
    local turn=angle(yaw,heading)
    return {from=Activity.pack(from),to=Activity.pack(to),v0=Activity.pack(v0),v1=Activity.pack(v1),duration=duration,
        yaw=yaw,turn=turn,turnDuration=math.max(.12,math.abs(turn)*1.5/12)}
end
local function legSample(leg,elapsed)
    local duration=leg.duration;local t=math.clamp(elapsed/duration,0,1);local u=1-t
    local a,b=Activity.vector(leg.from),Activity.vector(leg.to)
    local v0,v1=Activity.vector(leg.v0),Activity.vector(leg.v1)
    local delta=b-a
    -- Evaluate in local offsets. Subtracting world-space Bezier controls loses
    -- velocity precision in Roblox float32 Vector3s hundreds of studs out.
    local position=a+v0*(duration*u*u*t)+(delta-v1*duration/3)*(3*u*t*t)+delta*(t*t*t)
    local velocity=if elapsed>=duration then v1 else v0*(u*u-2*u*t)+v1*(t*t-2*u*t)+delta*(6*u*t/duration)
    local turn=math.clamp(elapsed/leg.turnDuration,0,1)
    if leg.pivot then return position,velocity,leg.yaw+leg.turn*turn*turn*(3-2*turn)end
    -- Heading follows the actual curve, including an incoming/outgoing tangent.
    -- At a stopped endpoint use its limiting tangent, then retain that heading.
    local tangent=velocity
    if Vector2.new(tangent.X,tangent.Z).Magnitude<.00001 and delta.Magnitude>.00001 then
        local near=if t>=1 then .9999 else .0001;local back=1-near
        tangent=v0*(back*back-2*back*near)+v1*(near*near-2*back*near)+delta*(6*back*near/duration)
    end
    local heading=if Vector2.new(tangent.X,tangent.Z).Magnitude>.00001 then math.atan2(tangent.X,tangent.Z)else leg.yaw
    local align=math.clamp(elapsed/.12,0,1)
    return position,velocity,leg.yaw+angle(leg.yaw,heading)*align*align*(3-2*align)
end
function Activity.plan(from,to,velocity,speed,minimum,yaw,via,terminalVelocity)
    local path={};local total=0
    local function pivot(target)
        local delta=target-from
        if velocity.Magnitude>.001 or Vector2.new(delta.X,delta.Z).Magnitude<.001 then return end
        local heading=math.atan2(delta.X,delta.Z);local turn=angle(yaw,heading)
        if math.abs(turn)<.12 then return end
        local duration=math.max(.12,math.abs(turn)*1.5/12)
        table.insert(path,{from=Activity.pack(from),to=Activity.pack(from),v0=Activity.pack(ZERO),v1=Activity.pack(ZERO),duration=duration,
            yaw=yaw,turn=turn,turnDuration=duration,pivot=true})
        total+=duration;yaw+=turn
    end
    local function brake()
        local stop=from+velocity*.125
        local leg=assert(Activity.leg(from,stop,velocity,ZERO,math.max(speed,velocity.Magnitude),.25,yaw))
        table.insert(path,leg);total+=leg.duration
        from,velocity,yaw=stop,ZERO,select(3,legSample(leg,leg.duration))
    end
    local function accelerate(target)
        -- A moving owner's look-ahead target can be a long chord. Spreading
        -- initial acceleration over that whole chord adds several studs of lag
        -- after a stationary pivot. Publish a short, velocity-continuous launch
        -- first; its derivative control hull still obeys the existing speed cap.
        if not terminalVelocity or terminalVelocity.Magnitude<.1 or velocity.Magnitude>=speed*.8 then return end
        local delta=target-from;if delta.Magnitude<.001 then return end
        local outgoing=delta.Unit*speed;local duration=.30
        local offset=(velocity+outgoing)*(duration*.5)
        if offset.Magnitude+.25>=delta.Magnitude or offset:Dot(delta)<=0 then return end
        local leg=Activity.leg(from,from+offset,velocity,outgoing,speed,duration,yaw)
        if not leg or leg.duration>duration+.0001 then return end
        table.insert(path,leg);total+=leg.duration
        from,velocity,yaw=from+offset,outgoing,select(3,legSample(leg,leg.duration))
    end
    local function append(target,v1,hold)
        local delta=target-from
        if velocity.Magnitude>.001 and delta.Magnitude>.001 then
            local horizontal=Vector2.new(velocity.X,velocity.Z);local desired=Vector2.new(delta.X,delta.Z)
            if horizontal.Magnitude>.001 and desired.Magnitude>.001 and horizontal:Dot(desired)/(horizontal.Magnitude*desired.Magnitude)<.5 then brake()end
        end
        pivot(target)
        accelerate(target)
        local leg=Activity.leg(from,target,velocity,v1,speed,hold,yaw)
        if not leg then
            -- An about-turn cannot preserve incoming velocity while staying on
            -- the new chord. Brake over a bounded quarter-second first; never
            -- inflate a duration until its control points escape the garden.
            brake();pivot(target)
            leg=Activity.leg(from,target,velocity,v1,speed,hold,yaw)
            if not leg then v1=ZERO;leg=assert(Activity.leg(from,target,velocity,v1,speed,hold,yaw))end
        end
        table.insert(path,leg);total+=leg.duration
        from,velocity,yaw=target,v1,select(3,legSample(leg,leg.duration))
    end
    if via and (via-from).Magnitude>.01 and (to-via).Magnitude>.01 then
        local chord=to-from
        local tangent=if chord.Magnitude>.01 then chord.Unit*math.min(speed*.4,(via-from).Magnitude,(to-via).Magnitude)else ZERO
        append(via,tangent,0);append(to,ZERO,0)
    else
        append(to,terminalVelocity or ZERO,minimum)
        -- Publish the finite stopping tail too: a delayed/lost snapshot settles
        -- within a quarter-second instead of extrapolating through the world.
        if velocity.Magnitude>.001 then append(to+velocity*.125,ZERO,.25)end
    end
    return path,total
end
function Activity.sample(actor,now)
    if type(actor)~="table" or not finite(now) then return nil end
    local from,to=Activity.vector(actor.from),Activity.vector(actor.to)
    if not from or not to or not finite(actor.startTime) or not finite(actor.endTime) then return nil end
    local phase=math.clamp((now-actor.startTime)/math.max(.001,actor.endTime-actor.startTime),0,1)
    local move=phase*phase*(3-2*phase)
    local position=from:Lerp(to,move)
    local velocity=Vector3.zero
    local direction=to-from
    if actor.via then
        local via=Activity.vector(actor.via)
        if via then
            local first,second=(via-from).Magnitude,(to-via).Magnitude
            local distance=(first+second)*move
            local firstLeg=distance<first and first>.001
            position=if firstLeg then from:Lerp(via,distance/first) else via:Lerp(to,math.clamp((distance-first)/math.max(.001,second),0,1))
            direction=if firstLeg then via-from else to-via
        end
    end
    local yaw=actor.yaw or 0;local pivoting,pivotPhase,pivotTurn=false,0,0
    local delta=direction
    if actor.action~="focus" and delta.Magnitude>.05 then
        local moving=math.atan2(delta.X,delta.Z)
        if actor.action=="greet"then
            local turn=math.atan2(math.sin(yaw-moving),math.cos(yaw-moving))
            yaw=moving+turn*move
        else yaw=moving end
    end
    if actor.path and actor.action~="focus" then
        local elapsed=math.max(0,now-actor.startTime)
        for i,leg in ipairs(actor.path)do
            if elapsed<=leg.duration or i==#actor.path then
                position,velocity,yaw=legSample(leg,elapsed);pivoting=leg.pivot==true
                if pivoting then pivotPhase=math.clamp(elapsed/leg.duration,0,1);pivotTurn=leg.turn end
                break
            end
            elapsed-=leg.duration
        end
        if actor.action=="greet"or actor.action=="shove"then
            local target=actor.yaw or yaw
            local settle=if actor.action=="shove"then math.clamp((now-actor.startTime)/math.max(.12,math.abs(angle(yaw,target))*1.5/12),0,1)else math.clamp((now-actor.startTime-(actor.endTime-actor.startTime)*.65)/math.max(.1,(actor.endTime-actor.startTime)*.35),0,1)
            yaw+=angle(yaw,target)*settle*settle*(3-2*settle)
        end
    end
    local expression=if actor.action=="focus" then "curious" elseif actor.action=="greet" then "pleased"
        elseif actor.behavior=="rest" then "sleepy" elseif actor.behavior=="investigate" then "curious"
        elseif actor.behavior=="play" then (if phase>.43 and phase<.62 then "startled" else "pleased") else "neutral"
    return {position=position,velocity=velocity,yaw=yaw,phase=phase,actionPhase=phase,behavior=actor.behavior,action=actor.action,
        expression=expression,generation=actor.generation,actionId=actor.actionId,peerId=actor.peerId,mode=actor.mode,pivot=pivoting,pivotPhase=pivotPhase,pivotTurn=pivotTurn}
end
function Activity.sampleToy(toy,now)
    if type(toy)~="table" then return nil end
    local position=Activity.vector(toy.position);if not position then return nil end
    local phase=if toy.startTime then math.clamp((now-toy.startTime)/math.max(.001,toy.endTime-toy.startTime),0,1) else 1
    local tilt=if toy.actionId and phase<1 then math.sin(phase*math.pi*4)*.40*math.sin(math.pi*phase) else 0
    local axis=Activity.vector(toy.axis)or Vector3.new(0,0,1)
    return {basePosition=position,position=position+axis*(tilt*.55/.40),tilt=tilt,rotation=tilt*.32,phase=phase,actionId=toy.actionId}
end
function Activity.validSnapshot(snapshot)
    return type(snapshot)=="table" and snapshot.version==Activity.Version and finite(snapshot.revision)
        and type(snapshot.actors)=="table" and type(snapshot.toy)=="table"
end
return Activity
