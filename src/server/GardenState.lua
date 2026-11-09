-- One authoritative coordinator for the toy, paired greetings and focus priority.
-- Injected clock/state/publication keep this separate from rewards and persistence.
local Shared=game:GetService("ReplicatedStorage").Shared
local Activity=require(Shared.GardenActivity)
local Layout=require(Shared.GardenLayout)
local ToyReturn=require(script.Parent.GardenToyReturn)
local Garden={};Garden.__index=Garden
local function distance(a,b) return Vector2.new(a.X-b.X,a.Z-b.Z).Magnitude end
function Garden.new(options)
    return setmetatable({options=options,actors={},inputs={},serial=0,revision=0,accumulator=0,dirty=false,
        toy={position=Activity.pack(Layout.Toy)},pairs={},nextGreeting=0},Garden)
end
function Garden:token() self.serial+=1;return self.serial end
function Garden:position(actor,now)
    local sample=Activity.sample(actor,now);return sample and sample.position or self.inputs[actor.ownerId].anchor
end
function Garden:transition(actor,behavior,target,duration,action,actionId,via,prepared)
    local now=self.options.now();local sample=Activity.sample(actor,now)
    local from=sample and sample.position or self.inputs[actor.ownerId].anchor
    local continuing=actor.behavior==behavior and actor.action==action and behavior=="follow"
    if not continuing then actor.generation+=1 end
    actor.behavior,actor.action=behavior,action
    if action~="nookApproach"and action~="nookRest"then actor.restAnchorId=nil end
    actor.actionId=actionId or (continuing and actor.actionId)or self:token()
    local velocity=sample and sample.velocity or Vector3.zero
    local yaw=sample and sample.yaw or actor.yaw or 0
    local separation=(target-from).Magnitude
    local speed=if behavior=="follow"then Layout.WalkSpeed+math.clamp((separation-4)/8,0,1)*(Layout.CatchupSpeed-Layout.WalkSpeed)else Layout.StrollSpeed
    -- A continuously walking16stud/s avatar outruns a9stud/s pet. Only the
    -- sustained outer leash uses gradual18 recovery; near walking stays4.
    if behavior=="follow"and separation>16 then speed=Layout.CatchupSpeed+math.clamp((separation-16)/14,0,1)*(Layout.LeashSpeed-Layout.CatchupSpeed)end
    local terminal=if behavior=="follow"then actor.ownerVelocity or Vector3.zero else Vector3.zero
    if terminal.Magnitude>.1 then
        speed=math.min(Layout.LeashSpeed,math.max(speed,terminal.Magnitude+math.clamp(separation/10,0,1)*2))
        target+=terminal*.5
    end
    if behavior=="follow"and self.options.resolveTarget then
        local resolved,clamped=self.options.resolveTarget(target,from)
        if resolved then target=resolved;if clamped then terminal=Vector3.zero end end
    end
    local planner=self.options.planPath or Activity.plan
    if prepared then actor.path,duration=prepared.path,prepared.duration
    else actor.path,duration=planner(from,target,velocity,speed,if separation<.01 or action=="greet"then duration else 0,yaw,via,terminal)end
    actor.startTime,actor.endTime=now,now+duration
    actor.from,actor.to,actor.via=Activity.pack(from),Activity.pack(target),if via then Activity.pack(via)else nil

    actor.peerId=nil;self.dirty=true
end
function Garden:resume(actor,input,prior)
    local now=self.options.now()
    -- Spring slots can be claimed by a third owner during a greeting. Resume
    -- ordinary follow; any later rest requires a fresh free-slot preflight.
    if prior and prior.behavior=="rest"and prior.endTime>now and not(prior.restAnchorId and prior.restAnchorId~="creek_nook")then self:transition(actor,"rest",Activity.vector(prior.to),prior.endTime-now)
    else self:transition(actor,"follow",input.anchor,.5)end
end
function Garden:release(actor)
    if self.care then self.care:release(actor)end
    actor.restAnchorId=nil
    if actor.toyActionId then ToyReturn.release(self,actor.toyActionId,actor.ownerId);actor.toyActionId=nil end
    if not self.toy.returnAction and self.toy.ownerId==actor.ownerId and actor.toyReservation==self.toy.reservation then
        self.toy={position=Activity.pack(Layout.Toy)};self.dirty=true
    end
    actor.toyReservation=nil
    local pair=actor.pairId and self.pairs[actor.pairId]
    actor.pairId=nil
    if pair then
        self.pairs[pair.id]=nil
        for _,id in ipairs(pair.owners) do
            local other=self.actors[id]
            if other and other~=actor and other.pairId==pair.id then
                other.pairId=nil
                local input=self.inputs[id]
                if input then self:resume(other,input,pair.prior[other.ownerId]) end
            end
        end
        return pair.prior[actor.ownerId]
    end
end
function Garden:reset(actor,input)
    self:release(actor);actor.mode=input.mode;actor.focusUntil=nil
    actor.wanderCount,actor.nextWanderAt,actor.idleSince=0,nil,self.options.now()
    self:transition(actor,if input.mode=="Board" then "rest" else "follow",input.anchor,.5)
end
function Garden:sync(inputs,freshOwnerId)
    self.inputs=inputs
    for id,actor in pairs(self.actors) do
        local input=inputs[id]
        if not input or not input.alive or not input.owned or input.petId~=actor.petId or input.characterId~=actor.characterId or(input.petGeneration or 0)~=actor.petGeneration then
            self:release(actor);self.actors[id]=nil;self.dirty=true
        end
    end
    for id,input in pairs(inputs) do
        if not input.alive or not input.owned then continue end
        local actor=self.actors[id]
        if not actor then
            local now=self.options.now()
            actor={ownerId=id,petId=input.petId,characterId=input.characterId,petGeneration=input.petGeneration or 0,generation=self:token(),mode=input.mode,
                behavior="follow",actionId=self:token(),from=Activity.pack(input.anchor),to=Activity.pack(input.anchor),
                startTime=now,endTime=now+.5,idleSince=now,lastOwner=input.position,yaw=input.yaw or 0}
            self.actors[id]=actor;self.dirty=true
            if input.mode=="Board" then self:reset(actor,input) end
        elseif input.mode~=(if actor.mode=="Focus"or(actor.care~=nil)then "Room"else actor.mode)then self:reset(actor,input)end
        if freshOwnerId==nil or freshOwnerId==id then
        local sampledAt=self.options.now()
        if actor.ownerSampleAt and sampledAt>actor.ownerSampleAt then
            local moved=input.position-actor.ownerSample
            moved=Vector3.new(moved.X,0,moved.Z)/(sampledAt-actor.ownerSampleAt)
            -- Teleport observations are discontinuities, never predicted travel.
            actor.ownerVelocity=if moved.Magnitude<=20 and moved.Magnitude>.001 then moved.Unit*math.min(moved.Magnitude,Layout.LeashSpeed)else Vector3.zero
        end
        actor.ownerSample,actor.ownerSampleAt=input.position,sampledAt
        end
        if actor.charmVisible~=input.charmVisible then actor.charmVisible=input.charmVisible;self.dirty=true end
        if distance(actor.lastOwner,input.position)>.65 then
            actor.lastOwner,actor.idleSince=input.position,self.options.now()
            actor.wanderCount,actor.nextWanderAt=0,nil
            if actor.mode=="Room" and actor.behavior~="follow" then self:release(actor);self:transition(actor,"follow",input.anchor,.5) end
        end
        if actor.care and self.care then self.care:tick(actor,input)end
    end
end
function Garden:syncOne(id,input)
    -- Other participants retain their last2Hz sample; focus never raycasts them.
    local cached=table.clone(self.inputs);cached[id]=input;self:sync(cached,id)
end

function Garden:focus(id,packet)
    local actor,input=self.actors[id],self.inputs[id]
    if type(packet)~="table" or type(packet.seq)~="number" or packet.seq%1~=0 or packet.seq<1 or packet.seq>2147483647
        or type(packet.petId)~="string" or not actor or not input or not input.alive or not input.owned
        or input.mode~="Room" or packet.petId~=actor.petId or input.petId~=actor.petId or input.characterId~=actor.characterId
        or(input.petGeneration or 0)~=actor.petGeneration or(packet.characterId~=nil and packet.characterId~=input.characterId)
        or(packet.petGeneration~=nil and packet.petGeneration~=actor.petGeneration)then return false end
    if actor.mode=="Carried"or actor.mode=="Docked"then return false end
    local now=self.options.now()
    if packet.kind=="focusEnd" then
        if actor.focusSeq==packet.seq and actor.mode=="Focus" then self:reset(actor,input);return true end
        return false
    end
    if packet.kind=="focusPulse" then
        if actor.focusSeq==packet.seq and actor.mode=="Focus" then
            local target=Activity.vector(actor.to)
            if not target or (target-input.position).Magnitude>7 or math.abs(target.Y-input.anchor.Y)>1 then self:reset(actor,input);return false end
            actor.focusUntil=now+1.6;return true
        end
        return false
    end
    if packet.kind~="focus" or packet.seq<=(actor.lastFocusSeq or 0) or now-(actor.lastFocusAt or -math.huge)<.25 then return false end
    local pose=Activity.sample(actor,now)
    local target=pose and pose.position
    if not target or (target-input.position).Magnitude>7 or math.abs(target.Y-input.anchor.Y)>1
        or (self.options.validFocus and not self.options.validFocus(input,target)) then return false end
    self:release(actor);actor.lastFocusSeq,actor.focusSeq,actor.lastFocusAt=packet.seq,packet.seq,now
    actor.mode,actor.focusUntil="Focus",now+1.6
    self:transition(actor,"rest",target,.05,"focus")
    actor.from=Activity.pack(target);actor.to=Activity.pack(target);actor.path=nil;actor.yaw=pose.yaw
    return true
end
function Garden:focusAnchor(id,petId,characterId,petGeneration,position)
    local actor=self.actors[id]
    if typeof(position)~="Vector3"or not actor or actor.mode~="Focus"or actor.petId~=petId or actor.characterId~=characterId or actor.petGeneration~=petGeneration
        or self.options.now()>actor.focusUntil then return nil end
    local target=Activity.vector(actor.to)
    return if target and(target-position).Magnitude<=7 then target else nil
end

function Garden:greeting(now,ordered)
    if now<self.nextGreeting or #ordered<2 then return end
    self.nextGreeting=now+12
    for offset=1,#ordered do
        local i=((self.greetingCursor or 0)+offset-1)%#ordered+1
        local first=ordered[i]
        if first.mode~="Room" or first.pairId or(first.behavior~="follow" and first.behavior~="rest") then continue end
        for delta=1,#ordered-1 do
            local second=ordered[(i+delta-1)%#ordered+1]
            if second.mode~="Room" or second.pairId or(second.behavior~="follow" and second.behavior~="rest") then continue end
            local a,b=self:position(first,now),self:position(second,now)
            if distance(a,b)>9 then continue end
            local prior={}
            for _,actor in ipairs({first,second})do prior[actor.ownerId]={behavior=actor.behavior,to=actor.to,endTime=actor.endTime,restAnchorId=actor.restAnchorId}end
            local center=(a+b)*.5;local token=self:token()
            self:transition(first,"investigate",center+Vector3.new(-.9,0,0),2.6,"greet",token)
            self:transition(second,"investigate",center+Vector3.new(.9,0,0),2.6,"greet",token)
            local finish=math.max(first.endTime,second.endTime)
            for _,actor in ipairs({first,second})do
                local remaining=finish-actor.endTime
                if remaining>.0001 then
                    local target=Activity.vector(actor.to);local last=actor.path[#actor.path]
                    local hold=assert(Activity.leg(target,target,Vector3.zero,Vector3.zero,Layout.StrollSpeed,remaining,last.yaw+last.turn))
                    -- A hold can be shorter than the moving-leg minimum.
                    hold.duration=remaining;table.insert(actor.path,hold)
                end
                actor.endTime=finish
            end
            first.peerId,second.peerId=second.ownerId,first.ownerId;first.pairId,second.pairId=token,token
            first.yaw,second.yaw=math.pi*.5,-math.pi*.5
            self.pairs[token]={id=token,owners={first.ownerId,second.ownerId},generations={first.generation,second.generation},prior=prior}
            self.greetingCursor=i
            return
        end
    end
end

-- Bounded authoritative choices reuse the same planner and decision cadence.
function Garden:wander(actor,input,now)
    if not self.options.validWander then return false end
    local from=self:position(actor,now)
    if now>=(actor.nextNookAt or 0)then
        local eligible={}
        for _,rest in ipairs(Layout.RestAnchors)do
            local gap=distance(input.position,rest.position)
            if gap<=4 and math.abs(input.position.Y-rest.position.Y)<=6 and(from-rest.position).Magnitude<=8 then
                table.insert(eligible,{rest=rest,gap=gap})
            end
        end
        table.sort(eligible,function(a,b)return if a.gap==b.gap then a.rest.id<b.rest.id else a.gap<b.gap end)
        for _,candidate in ipairs(eligible)do
            local rest=candidate.rest
            local occupied=false
            if rest.exclusive then
                for _,other in pairs(self.actors)do
                    if other==actor then continue end
                    if(other.restAnchorId==rest.id and(other.action=="nookApproach"or other.action=="nookRest"))
                        or(other.mode=="Focus"and distance(self:position(other,now),rest.position)<2)then occupied=true;break end
                end
            end
            if occupied then continue end
            local target=self.options.validWander(input,rest.position,from)
            if typeof(target)~="Vector3"or(target-rest.position).Magnitude>=.1 then continue end
            -- Preflight before changing actor identity/state. A blocked rest
            -- must not become a phantom arrival or consume its cooldown.
            local sample=Activity.sample(actor,now)
            local planner=self.options.planPath or Activity.plan
            local path,seconds=planner(from,target,sample and sample.velocity or Vector3.zero,Layout.StrollSpeed,0,sample and sample.yaw or actor.yaw or 0,nil,Vector3.zero)
            local last=path and path[#path];local valid=last~=nil and(Activity.vector(last.to)-target).Magnitude<.1
            for _,leg in ipairs(path or {})do if leg.safetyStop then valid=false;break end end
            if valid and rest.exclusive and self.options.validRestPath and not self.options.validRestPath(path)then valid=false end
            if valid then
                self:transition(actor,"investigate",target,0,"nookApproach",nil,nil,{path=path,duration=seconds})
                actor.restAnchorId=rest.id;actor.nextNookAt=now+18
                actor.wanderCount=(actor.wanderCount or 0)+1;return true
            end
        end
    end
    for attempt=1,6 do
        local seed=(actor.ownerId*17+self.serial*37+attempt*101)%997
        local angle=seed/997*math.pi*2
        local radius=2+(seed%3)
        local candidate=input.anchor+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
        if distance(candidate,Layout.Toy)<3 or distance(candidate,Layout.Rest)<2 then continue end
        local target=self.options.validWander(input,candidate,from)
        if typeof(target)=="Vector3"and distance(target,input.anchor)<=4.1 and math.abs(target.Y-input.anchor.Y)<=.7 then
            self:transition(actor,"investigate",target,0,"wander")
            actor.wanderCount=(actor.wanderCount or 0)+1
            return true
        end
    end
    return false
end
function Garden:decide()
    local now=self.options.now();local ordered={}
    ToyReturn.step(self,now)
    -- Reservations bind both participant generations; any superseded half ends
    -- the pair before another action can observe or reuse its token.
    local retired={}
    for id,pair in pairs(self.pairs)do
        local a,b=self.actors[pair.owners[1]],self.actors[pair.owners[2]]
        if not a or not b or a.pairId~=id or b.pairId~=id or a.generation~=pair.generations[1]or b.generation~=pair.generations[2]then table.insert(retired,id)end
    end
    for _,id in ipairs(retired)do
        local pair=self.pairs[id];self.pairs[id]=nil
        for _,owner in ipairs(pair.owners)do
            local actor,input=self.actors[owner],self.inputs[owner]
            if actor and actor.pairId==id then actor.pairId=nil;if input then self:transition(actor,"follow",input.anchor,.5)end end
        end
    end
    for _,actor in pairs(self.actors) do table.insert(ordered,actor) end
    table.sort(ordered,function(a,b)return a.ownerId<b.ownerId end)
    for _,actor in ipairs(ordered) do
        local input=self.inputs[actor.ownerId]
        if actor.mode=="Focus" then
            if now>actor.focusUntil then self:reset(actor,input) end
            continue
        end
        if actor.care then continue end
        if actor.mode=="Board" then
            if distance(self:position(actor,now),input.anchor)>.4 then self:transition(actor,"rest",input.anchor,.5) end
            continue
        end
        if actor.toyActionId then continue end
        if actor.pairId then
            if now>=actor.endTime then local prior=self:release(actor);self:resume(actor,input,prior)end
            continue
        end
        local position=self:position(actor,now)
        if distance(position,input.position)>22 and(actor.behavior~="follow"or distance(Activity.vector(actor.to),input.anchor)>.2)then self:release(actor);self:transition(actor,"follow",input.anchor,.6)
        elseif actor.behavior=="follow" then
            local target=if actor.ownerId%2==0 then Layout.ToyWest else Layout.ToyEast
            local reachable=true
            for _,waypoint in ipairs({Layout.Lawn,target,Layout.Rest})do
                if distance(input.position,waypoint)>20 then reachable=false;break end
            end
            local wanderTurn=self.options.validWander~=nil and ((actor.wanderCount or 0)%2==0 or not reachable or self.toy.ownerId~=nil)
            if now-actor.idleSince>=3.5 and now>=(actor.nextWanderAt or 0) and wanderTurn then
                actor.nextWanderAt=now+7
                if not self:wander(actor,input,now)then
                    actor.wanderCount=(actor.wanderCount or 0)+1
                    self:transition(actor,"rest",position,1.5,"wanderPause")
                end
            elseif now-actor.idleSince>=3 and not self.toy.ownerId and reachable and not wanderTurn then
                local duration=math.clamp((position-Layout.Lawn).Magnitude/3+(Layout.Lawn-target).Magnitude/3,1.6,8)
                self.toy={kind="solo",position=Activity.pack(Layout.Toy),ownerId=actor.ownerId,reservation=self:token()}
                actor.toyReservation=self.toy.reservation
                self:transition(actor,"investigate",target,duration,nil,nil,Layout.Lawn)
            elseif distance(Activity.vector(actor.to),input.anchor)>.2 then self:transition(actor,"follow",input.anchor,.5)
            elseif not reachable and now-actor.idleSince>=5 then self:transition(actor,"rest",position,2,"wanderPause")end
        elseif now>=actor.endTime then
            if actor.action=="nookApproach"then
                self:transition(actor,"rest",position,6,"nookRest")
                local direction=input.position-position
                local heading=math.atan2(direction.X,direction.Z)
                local yaw=Activity.sample(actor,now).yaw;local turn=(heading-yaw+math.pi)%(math.pi*2)-math.pi
                local duration=math.max(.12,math.abs(turn)*1.5/12)
                actor.path={{from=Activity.pack(position),to=Activity.pack(position),v0={0,0,0},v1={0,0,0},duration=duration,yaw=yaw,turn=turn,turnDuration=duration,pivot=true},
                    {from=Activity.pack(position),to=Activity.pack(position),v0={0,0,0},v1={0,0,0},duration=6-duration,yaw=heading,turn=0,turnDuration=0}}
            elseif actor.action=="wander"then
                self:transition(actor,"rest",position,1.5,"wanderPause")
            elseif actor.behavior=="investigate"and not self.toy.returnAction and self.toy.ownerId==actor.ownerId and actor.toyReservation==self.toy.reservation then
                self:transition(actor,"play",position,2.8,"shove")
                actor.yaw=math.atan2(Layout.Toy.X-position.X,Layout.Toy.Z-position.Z)
                local axis=Vector3.new(Layout.Toy.X-position.X,0,Layout.Toy.Z-position.Z)
                self.toy.axis=Activity.pack(if axis.Magnitude>.01 then axis.Unit else Vector3.new(0,0,1))
                self.toy.actionId,self.toy.startTime,self.toy.endTime=actor.actionId,now,now+2.8;self.dirty=true
            elseif actor.behavior=="play" then
                actor.wanderCount=(actor.wanderCount or 0)+1
                self:release(actor);self:transition(actor,"rest",Layout.Rest,math.clamp(distance(position,Layout.Rest)/2.8,1,4),"settle")
            elseif actor.action=="settle" then self:transition(actor,"rest",position,5)
            else actor.idleSince=now;self:transition(actor,"follow",input.anchor,1) end
        end
    end
    self:greeting(now,ordered)
end
function Garden:remove(id)
    local actor=self.actors[id]
    if actor then self:release(actor);self.actors[id]=nil;self.inputs[id]=nil;self.dirty=true end
    if self.toyRequests then self.toyRequests[id]=nil end
    if self.care then self.care.requests[id]=nil;self.care.equips[id]=nil;self.care.equipProofs[id]=nil end
    return self:publish()
end
function Garden:toyRequest(id,packet)return ToyReturn.request(self,id,packet)end
function Garden:toyReplay(id,packet)return ToyReturn.replay(self,id,packet)end
function Garden:snapshot()
    local actors={}
    for id,actor in pairs(self.actors) do
        actors[tostring(id)]={ownerId=id,petId=actor.petId,characterId=actor.characterId,petGeneration=actor.petGeneration,generation=actor.generation,mode=actor.mode,
            behavior=actor.behavior,action=actor.action,actionId=actor.actionId,peerId=actor.peerId,startTime=actor.startTime,endTime=actor.endTime,
            from=actor.from,to=actor.to,via=actor.via,path=actor.path,yaw=actor.yaw,charmVisible=actor.charmVisible~=false,requestGeneration=actor.lastFocusSeq or 0,
            toyRole=actor.toyRole,toyStartTime=actor.toyStartTime,care=actor.care and table.clone(actor.care)or nil}
    end
    return {version=Activity.Version,revision=self.revision,actors=actors,toy=table.clone(self.toy),careBay=self.care and self.care:snapshot()or nil}
end
function Garden:publish()
    if not self.dirty then return false end
    self.dirty=false;self.revision+=1
    if self.options.publish then self.options.publish(self:snapshot()) end
    return true
end
function Garden:step(dt,inputs)
    self.accumulator+=math.max(0,dt)
    if self.accumulator<Layout.DecisionInterval then return false end
    self.accumulator%=Layout.DecisionInterval
    self:sync(if type(inputs)=="function"then inputs()else inputs);self:decide();return self:publish()
end
return Garden
