-- Versioned, deterministic presentation. Never awards or mutates a profile.
local Activity = { Version = 1 }
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function Activity.pack(v) return {v.X,v.Y,v.Z} end
function Activity.vector(v)
    if type(v)~="table" or not finite(v[1]) or not finite(v[2]) or not finite(v[3]) then return nil end
    if math.abs(v[1])>10000 or math.abs(v[2])>10000 or math.abs(v[3])>10000 then return nil end
    return Vector3.new(v[1],v[2],v[3])
end
function Activity.sample(actor,now)
    if type(actor)~="table" or not finite(now) then return nil end
    local from,to=Activity.vector(actor.from),Activity.vector(actor.to)
    if not from or not to or not finite(actor.startTime) or not finite(actor.endTime) then return nil end
    local phase=math.clamp((now-actor.startTime)/math.max(.001,actor.endTime-actor.startTime),0,1)
    local move=phase*phase*(3-2*phase)
    local position=from:Lerp(to,move)
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
    local yaw=actor.yaw or 0
    local delta=direction
    if actor.action~="focus" and delta.Magnitude>.05 then
        local moving=math.atan2(delta.X,delta.Z)
        if actor.action=="greet"then
            local turn=math.atan2(math.sin(yaw-moving),math.cos(yaw-moving))
            yaw=moving+turn*move
        else yaw=moving end
    end
    local expression=if actor.action=="focus" then "curious" elseif actor.action=="greet" then "pleased"
        elseif actor.behavior=="rest" then "sleepy" elseif actor.behavior=="investigate" then "curious"
        elseif actor.behavior=="play" then (if phase>.43 and phase<.62 then "startled" else "pleased") else "neutral"
    return {position=position,yaw=yaw,phase=phase,actionPhase=phase,behavior=actor.behavior,action=actor.action,
        expression=expression,generation=actor.generation,actionId=actor.actionId,peerId=actor.peerId,mode=actor.mode}
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
