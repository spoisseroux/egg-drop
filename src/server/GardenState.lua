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
-- Extra rest anchors that come and go (beta only: the Sleepy Nest landmark's straw mat, set by EggCornerWorld while the
-- landmark stands). nil (live): Layout.RestAnchors alone, exactly as before.
Garden.extraRests=nil
-- Pets go up (WORLD-FINISH-LOOK slice A): the rest spots on the terrace and at the path's turn while the server's
-- TierPets gate is open (init.server sets it; nil on live).
Garden.tierRests=nil
function Garden.restAnchors()
    local extra=Garden.extraRests and Garden.extraRests()
    local up=Garden.tierRests and Garden.tierRests()
    if(type(extra)~="table"or #extra==0)and(type(up)~="table"or #up==0)then return Layout.RestAnchors end
    local all=table.clone(Layout.RestAnchors)
    if type(extra)=="table"then for _,rest in ipairs(extra)do table.insert(all,rest)end end
    if type(up)=="table"then for _,rest in ipairs(up)do table.insert(all,rest)end end
    return all
end
function Garden:position(actor,now)
    local sample=Activity.sample(actor,now);return sample and sample.position or self.inputs[actor.ownerId].anchor
end
function Garden:transition(actor,behavior,target,duration,action,actionId,via,prepared)
    local now=self.options.now();local sample=Activity.sample(actor,now)
    local from=sample and sample.position or self.inputs[actor.ownerId].anchor
    local continuing=actor.behavior==behavior and actor.action==action and behavior=="follow"
    -- any other action ends the first hatch's stand (and the lead's jump-spin holds the same way)
    if action~="firstStand"and action~="leadCheer"then actor.standUntil=nil end
    local previousTarget=Activity.vector(actor.to)
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
    local base=target
    if terminal.Magnitude>.1 then
        speed=math.min(Layout.LeashSpeed,math.max(speed,terminal.Magnitude+math.clamp(separation/10,0,1)*2))
        target+=terminal*.5
    end
    if behavior=="follow"and self.options.resolveTarget then
        -- `base` (the anchor before the owner's look-ahead): the cliff path's floor is the anchor's, not the look-ahead's.
        local resolved,clamped=self.options.resolveTarget(target,from,base)
        if resolved then target=resolved;if clamped then terminal=Vector3.zero end end
    end
    local planner=self.options.planPath or Activity.plan
    if prepared then actor.path,duration=prepared.path,prepared.duration
    else actor.path,duration=planner(from,target,velocity,speed,if separation<.01 or action=="greet"then duration else 0,yaw,via,terminal)end
    actor.startTime,actor.endTime=now,now+duration
    -- Travel back to the owner is not settled idle. Preserve the existing
    -- deadline when an unchanged follow target is merely sampled again.
    if behavior=="follow"and(not continuing or not previousTarget or(target-previousTarget).Magnitude>.2)then actor.idleSince=actor.endTime end
    actor.from,actor.to,actor.via=Activity.pack(from),Activity.pack(target),if via then Activity.pack(via)else nil

    actor.peerId=nil;self.dirty=true
end
-- Garden Dash (DashHost): the owner's pet is racing. It leaves every other garden activity and stands still
-- here while the race draws it; decide, greeting, focus, care, hello and the parks skip it. `racers` is nil
-- until the first race, and actor.dash is nil for everybody else (the snapshot key is then absent).
function Garden:setRacer(id,raceId)
    self.racers=self.racers or {}
    self.racers[id]=raceId
    local actor,input=self.actors[id],self.inputs[id]
    if not actor or actor.dash==raceId then return end
    self:release(actor);actor.dash=raceId
    if raceId then
        actor.park=nil
        self:transition(actor,"rest",self:position(actor,self.options.now()),.05,"dash")
    elseif input then self:reset(actor,input)
    else self.dirty=true end
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
    -- Pet Park (FeatureFlags.Park): frees the pet's playground slot; membership stays with the director.
    if self.park then self.park:release(actor)end
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
    self:release(actor);actor.mode=input.mode;actor.focusUntil=nil;actor.lead=nil
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
                startTime=now,endTime=now+.5,idleSince=now+.5,lastOwner=input.position,yaw=input.yaw or 0,
                dash=self.racers and self.racers[id]or nil}
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
        -- The first hatch's stand (Garden:stand) holds until its beat is over. The owner's walk during the hold is not
        -- taken in (lastOwner stays put), so the first sync after it still sees them moved and the pet follows, whether
        -- or not they stand still by then (beta 38 review 3); the rest's own end follows too.
        local standing=actor.standUntil~=nil and self.options.now()<actor.standUntil
        if not standing and distance(actor.lastOwner,input.position)>.65 then
            actor.lastOwner,actor.idleSince=input.position,self.options.now()
            actor.wanderCount,actor.nextWanderAt=0,nil
            -- Park pets stay in the playground while their owner walks around the kerb.
            -- The lead to the nest (Garden:lead) runs ahead on its own rules.
            if actor.mode=="Room" and actor.behavior~="follow" and not actor.park and not actor.dash and not actor.lead then self:release(actor);self:transition(actor,"follow",input.anchor,.5) end
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
    if actor.mode=="Carried"or actor.mode=="Docked"or actor.dash then return false end
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
        -- Park pets greet only through the park director (6 s cadence, 45 s per pair).
        if first.mode~="Room" or first.pairId or first.park or first.dash or first.action=="firstStand" or first.lead or first.action=="leadCheer" or(first.behavior~="follow" and first.behavior~="rest") then continue end
        for delta=1,#ordered-1 do
            local second=ordered[(i+delta-1)%#ordered+1]
            if second.mode~="Room" or second.pairId or second.park or second.dash or second.action=="firstStand" or second.lead or second.action=="leadCheer" or(second.behavior~="follow" and second.behavior~="rest") then continue end
            local a,b=self:position(first,now),self:position(second,now)
            if distance(a,b)>9 then continue end
            -- Pets go up: never across floors (a pet on the cliff path and one on the lawn under it). nil: as before.
            if self.options.canMeet and not self.options.canMeet(a,b)then continue end
            self:greetPair(first,second,now)
            self.greetingCursor=i
            return
        end
    end
end
-- One atomic paired greeting (shared by the global greeting and the park director).
function Garden:greetPair(first,second,now)
    local a,b=self:position(first,now),self:position(second,now)
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
    return token
end

-- v859 review: every wander or nook target stays LeashMargin inside the leash, so a target
-- validWander moved (or a far anchor) can never start a wander -> leash -> wander loop.
function Garden.insideLeash(input,target)
    return typeof(target)=="Vector3"and distance(target,input.position)<=Layout.LeashRadius-Layout.LeashMargin
end
-- Bounded authoritative choices reuse the same planner and decision cadence.
function Garden:wander(actor,input,now)
    if not self.options.validWander or(actor.park and actor.park.session)then return false end
    local from=self:position(actor,now)
    if now>=(actor.nextNookAt or 0)then
        local eligible={}
        for _,rest in ipairs(Garden.restAnchors())do
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
            if typeof(target)~="Vector3"or(target-rest.position).Magnitude>=.1 or not Garden.insideLeash(input,target)then continue end
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
        if typeof(target)=="Vector3"and distance(target,input.anchor)<=4.1 and math.abs(target.Y-input.anchor.Y)<=.7 and Garden.insideLeash(input,target)then
            self:transition(actor,"investigate",target,0,"wander")
            actor.wanderCount=(actor.wanderCount or 0)+1
            return true
        end
    end
    return false
end
function Garden:decide()
    local now=self.options.now();local ordered={}
    if self.options.sharedToyEnabled==false then self:retireSharedToy()else ToyReturn.step(self,now)end
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
        -- The lead ends when anything else takes the pet (care, a race, the park, the deck).
        if actor.lead and(actor.care or actor.dash or actor.park or actor.mode~="Room")then actor.lead=nil;self.dirty=true end
        if actor.care or actor.dash then continue end
        -- Park pets (actor.park, set only by ParkDirector) skip follow, wander and the 22-stud recall.
        if actor.park and self.park then self.park:tick(actor,input,now) continue end
        if actor.mode=="Board" then
            if distance(self:position(actor,now),input.anchor)>.4 then self:transition(actor,"rest",input.anchor,.5) end
            continue
        end
        local position=self:position(actor,now)
        -- The lead to the nest (onboarding v3 brief section 1): its own rules, never the catch-up, leash or wander.
        if actor.lead then self:leadStep(actor,input,position,now);continue end
        -- Beta (12) QA G1: a pet too far behind, or stuck, hops to a landing by the owner (Room mode only).
        if actor.mode=="Room"and self:catchUp(actor,input,position,now)then continue end
        -- v859 leash: too far from the owner ends any play or interaction (release frees a toy
        -- return, a greeting partner, a rest nook) and the pet walks back.
        local heading=Activity.vector(actor.to)
        if distance(position,input.position)>Layout.LeashRadius and(actor.behavior~="follow"or actor.toyActionId~=nil or actor.pairId~=nil
            or heading==nil or distance(heading,input.anchor)>.2)then
            self:release(actor);actor.idleSince=now;self:transition(actor,"follow",input.anchor,.6)
            continue
        end
        if actor.toyActionId then continue end
        if actor.pairId then
            if now>=actor.endTime then local prior=self:release(actor);self:resume(actor,input,prior)end
            continue
        end
        if actor.behavior=="follow" then
            local target=if actor.ownerId%2==0 then Layout.ToyWest else Layout.ToyEast
            local reachable=true
            for _,waypoint in ipairs({Layout.Lawn,target,Layout.Rest})do
                if distance(input.position,waypoint)>Layout.LeashRadius-Layout.LeashMargin then reachable=false;break end
            end
            local wanderTurn=self.options.sharedToyEnabled==false or self.options.validWander~=nil and ((actor.wanderCount or 0)%2==0 or not reachable or self.toy.ownerId~=nil)
            if now-actor.idleSince>=3.5 and now>=(actor.nextWanderAt or 0) and wanderTurn then
                actor.nextWanderAt=now+7
                if self.options.sharedToyEnabled==false and Layout.SitEvery and(actor.wanderCount or 0)%Layout.SitEvery==Layout.SitEvery-1
                    and(not self.options.canSettle or self.options.canSettle(position))then
                    -- R9: a long sit in place instead of this wander (Layout.SitRest). Only in the
                    -- live garden (shared toy retired); the old toy/wander alternation is unchanged.
                    actor.wanderCount=(actor.wanderCount or 0)+1
                    self:transition(actor,"rest",position,Layout.SitRest,"settle")
                elseif not self:wander(actor,input,now)then
                    actor.wanderCount=(actor.wanderCount or 0)+1
                    self:transition(actor,"rest",position,1.5,"wanderPause")
                end
            elseif self.options.sharedToyEnabled~=false and now-actor.idleSince>=3 and not self.toy.ownerId and reachable and not wanderTurn then
                local duration=math.clamp((position-Layout.Lawn).Magnitude/3+(Layout.Lawn-target).Magnitude/3,1.6,8)
                self.toy={kind="solo",position=Activity.pack(Layout.Toy),ownerId=actor.ownerId,reservation=self:token()}
                actor.toyReservation=self.toy.reservation
                self:transition(actor,"investigate",target,duration,nil,nil,Layout.Lawn)
            elseif heading==nil or distance(heading,input.anchor)>.2 then self:transition(actor,"follow",input.anchor,.5)
            elseif not reachable and now-actor.idleSince>=5 then self:transition(actor,"rest",position,2,"wanderPause")end
        elseif now>=actor.endTime then
            if actor.action=="nookApproach"then
                self:transition(actor,"rest",position,6,"nookRest")
                local direction=input.position-position
                local heading=math.atan2(direction.X,direction.Z)
                local yaw=Activity.sample(actor,now).yaw;local turn=(heading-yaw+math.pi)%(math.pi*2)-math.pi
                local duration=Activity.turnSeconds(turn)
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
    if self.park then self.park:schedule(now,ordered)end
    self:greeting(now,ordered)
end
-- Pets catch up (beta (12) QA G1, PetCatchup). options.catchup() says the switch is on; options.landing(input, racing)
-- answers a checked landing by input.anchor or nil. Off (or no options): returns before touching the actor, so the
-- decide and the snapshot are today's. On a hop the pet stands at the landing at once (a prepared hold, never the
-- planner's stroll), rests Rest seconds, then follows; `hop` = {seq, from} stays on the actor so every client plays
-- the poof once when seq changes, whatever the sync does to the action meanwhile.
function Garden:catchUp(actor,input,position,now)
    local catchup,landing=self.options.catchup,self.options.landing
    if not catchup or not landing or catchup()~=true then return false end
    local Catchup=self.Catchup or require(Shared.PetCatchup)
    self.Catchup=Catchup
    actor.catch=actor.catch or {}
    local gap=distance(position,input.anchor)
    -- Pets go up (WORLD-FINISH-LOOK slice A): between floors the gap is along the cliff path's route (routeGap answers
    -- nil on the lawn and on live, so this is today's flat gap there).
    local route=self.options.routeGap and self.options.routeGap(position,input.anchor)
    if type(route)=="number"then gap=route end
    -- Stuck counts only while following or in a wanderPause: a sit (settle and its rest), a nook rest or a greeting
    -- far from the anchor is play, not stuck (code review 2).
    local tracking=actor.pairId==nil and(actor.behavior=="follow"or actor.action=="wanderPause")
    local still=(actor.ownerVelocity or Vector3.zero).Magnitude<.5
    local why=Catchup.step(actor.catch,now,gap,position,tracking,type(route)=="number",still)
    if not why then return false end
    local racing=false
    for _,race in pairs(self.racers or {})do if race then racing=true;break end end
    local spot=landing(input,racing,position)
    if typeof(spot)~="Vector3"then Catchup.done(actor.catch,now,false);return false end
    if Catchup.done(actor.catch,now,true)=="burst"and self.options.warn then
        pcall(self.options.warn,"[Catchup] pet of "..tostring(actor.ownerId).." hopped "..Catchup.Burst.." times in a minute; quiet for "..Catchup.BurstQuiet.." s")
    end
    self:release(actor)
    actor.idleSince=now
    self:transition(actor,"rest",spot,Catchup.Rest,"catchup",nil,nil,{path=nil,duration=Catchup.Rest})
    actor.from=Activity.pack(spot);actor.to=Activity.pack(spot)
    actor.hop={seq=(actor.hop and actor.hop.seq or 0)+1,from=Activity.pack(position),why=why}
    return true
end
-- The Hush passage (HushHost): the owner was just moved, so the pet comes in the same step, the catch-up move without
-- its rules (a prepared rest hold at `spot`, then follow; `hop` with why "passage" so every client poofs and snaps).
-- No actor: nothing. A pet in the park, in care, racing or holding the toy is refused (the passage refuses those first).
-- `leavePark` (the tier closing under a Top Lawn pet, architect B6): the pet leaves the park first, then comes.
function Garden:carry(id,spot,leavePark)
    local actor=self.actors[id]
    if not actor or typeof(spot)~="Vector3"or not self.inputs[id]then return false end
    if leavePark==true and actor.park and self.park and not actor.care and not actor.dash and not actor.toyReservation then
        self.park:leave(actor,nil,self.options.now())
    end
    if actor.park or actor.care or actor.dash or actor.toyReservation then return false end
    local Catchup=self.Catchup or require(Shared.PetCatchup)
    self.Catchup=Catchup
    local now=self.options.now()
    local sample=Activity.sample(actor,now)
    local position=sample and sample.position or spot
    self:release(actor)
    actor.idleSince=now
    self:transition(actor,"rest",spot,Catchup.Rest,"catchup",nil,nil,{path=nil,duration=Catchup.Rest})
    actor.from=Activity.pack(spot);actor.to=Activity.pack(spot)
    actor.hop={seq=(actor.hop and actor.hop.seq or 0)+1,from=Activity.pack(position),why="passage"}
    actor.catch={}
    return true
end
-- Beta (37) note 1, the first hatch (Onboarding v2 "stork"): the Bear stands where its egg opened. The pet rests at
-- `spot` facing `yaw` for `hold` seconds (at most StandMax), no path, no hop (nothing poofs: the client keeps it hidden
-- until it is drawn there, where the story's own Bear stands), and an owner who moves during the hold does not pull it
-- away (the owner-moved release in sync waits for standUntil). Then the rest ends and it follows as usual. A pet in
-- the park, in care, racing, holding the toy or in Focus is refused (it stays where it is, as before).
Garden.StandMax=10
function Garden:stand(id,spot,yaw,hold)
    local actor=self.actors[id]
    if not actor or typeof(spot)~="Vector3"or not self.inputs[id]or type(hold)~="number"or hold~=hold then return false end
    -- a pet in Focus (the close-up: mode "Focus", Garden:focus) is refused by the mode check (the spec covers it)
    if actor.park or actor.care or actor.dash or actor.toyReservation or actor.mode~="Room"then return false end
    hold=math.clamp(hold,.05,Garden.StandMax)
    local now=self.options.now()
    self:release(actor)
    actor.idleSince=now+hold
    self:transition(actor,"rest",spot,hold,"firstStand",nil,nil,{path=nil,duration=hold})
    actor.from=Activity.pack(spot);actor.to=Activity.pack(spot)
    actor.yaw=if type(yaw)=="number"and yaw==yaw then yaw else actor.yaw
    actor.standUntil=now+hold
    actor.catch={}
    return true
end
-- ── The lead to the nest (onboarding v3 brief section 1, switch Onboard "lead"; PetLead's rules) ─────────────────────
-- The owner's pet runs ahead along `points` (the client's trail route, checked by init.server with PetLead.clean) to
-- `goal` (3 studs short of the nest's prompt), arcs round 22 studs ahead and looks back, runs on when the owner comes
-- within 14 (or comes on fast), trots on looking back while the owner keeps following (beta 40: PetLead.decide's
-- "pace", never a stop), arrives and bounces facing `nest` until the lead ends (leadEnd, leadCheer, or anything else
-- taking the pet). A
-- nudge (leadBack) runs it back along its route to about 5 studs from the owner, or poofs it to them when no route
-- point is near (lost: the client sends a new route). Stuck while running (a safety hold): a poof to the next route
-- point. The snapshot carries {seq, phase, lost} for the client's words; every screen draws the run, hops and spin.
local ZERO=Vector3.zero
local function leadModule()return require(Shared.PetLead)end
local function holdLeg(at,yaw,seconds)
    return {from=Activity.pack(at),to=Activity.pack(at),v0={0,0,0},v1={0,0,0},duration=seconds,yaw=yaw,turn=0}
end
-- Pure: brake from a walk (a quarter second, as the planner's), turn to `face`, hold `hold` s; `before` s of standing
-- first (the start's hops). path, seconds, where it ends, its heading.
function Garden.leadSettle(from,velocity,yaw,face,hold,before)
    local path,total={},0
    if before and before>0 then table.insert(path,holdLeg(from,yaw,before));total+=before end
    if velocity.Magnitude>.05 then
        local stop=from+velocity*.125
        local leg=Activity.leg(from,stop,velocity,ZERO,math.max(velocity.Magnitude,.1),.25,yaw)
        if leg then table.insert(path,leg);total+=leg.duration;from=stop;yaw=select(3,Activity.legPose(leg,leg.duration))end
    end
    if typeof(face)=="Vector3"then
        local d=face-from
        if Vector2.new(d.X,d.Z).Magnitude>.05 then
            local heading=math.atan2(d.X,d.Z)
            local turn=math.atan2(math.sin(heading-yaw),math.cos(heading-yaw))
            if math.abs(turn)>=.12 then
                local seconds=Activity.turnSeconds(turn)
                table.insert(path,{from=Activity.pack(from),to=Activity.pack(from),v0={0,0,0},v1={0,0,0},duration=seconds,yaw=yaw,turn=turn,turnDuration=seconds,pivot=true})
                total+=seconds
            end
            yaw=heading
        end
    end
    hold=math.max(.05,hold or .05)
    table.insert(path,holdLeg(from,yaw,hold));total+=hold
    return path,total,from,yaw
end
-- Beta (40), Spencer: "it takes too long to turn back around and run again, needs to be smoother". The stop was a
-- quarter-second brake, a pivot (|turn| / 6 s: half a second for an about-turn), then the hold. Now (PetLead.Arc): ease
-- down to 40% of the speed, curve round through a small radius (arcLegs: speed-capped cubics), stop
-- facing `face` and hold `hold` s. nil when it is too slow to arc or a leg does not fit (the caller settles as before).
local function angleTo(a,b)return math.atan2(math.sin(b-a),math.cos(b-a))end
-- Pieces of at least Arc.leg s each (a garden cubic's floor), a semicircle in one at most .35 s: the hull keeps it
-- near the circle and the speed near `keep` (capped at twice it).
local function arcLegs(path,from,velocity,heading,turn,keep,radius,seconds)
    local sweep=math.abs(turn)
    local pieces=math.clamp(math.floor(seconds/leadModule().Arc.leg),1,4)
    local start,v=from,velocity
    local yaw=heading
    for i=1,pieces do
        local q,h=leadModule().arcPoint(from,heading,turn,radius,sweep*i/pieces)
        local vq=Vector3.new(math.sin(h),0,math.cos(h))*keep
        local leg=Activity.leg(start,q,v,vq,keep*2,seconds/pieces,yaw)
        if not leg then return nil end
        table.insert(path,leg)
        start,v,yaw=q,vq,select(3,Activity.legPose(leg,leg.duration))
    end
    return start,v,yaw
end
function Garden.leadArc(from,velocity,yaw,face,hold)
    local Lead=leadModule()
    local A=Lead.Arc
    local flatV=Vector3.new(velocity.X,0,velocity.Z)
    local speed=flatV.Magnitude
    if typeof(face)~="Vector3"or speed<A.min then return nil end
    local u=flatV.Unit
    local heading=math.atan2(u.X,u.Z)
    local keep=math.max(A.min,speed*A.keep)
    local path,total={},0
    -- ease down along the way
    local eased=from+u*((speed+keep)*.5*A.slow)
    local leg=Activity.leg(from,eased,flatV,u*keep,speed,A.slow,yaw)
    if not leg then return nil end
    table.insert(path,leg)
    local at,v=eased,u*keep
    heading=select(3,Activity.legPose(leg,leg.duration))
    -- the curve round to the owner
    local d=face-at
    if Vector2.new(d.X,d.Z).Magnitude>.05 then
        local turn=angleTo(heading,math.atan2(d.X,d.Z))
        if math.abs(turn)>=.12 then
            local _,radius,arcTime=Lead.arcFor(turn,speed)
            local endAt,endV,endYaw=arcLegs(path,at,v,heading,turn,keep,radius,arcTime)
            if not endAt then return nil end
            at,v,heading=endAt,endV,endYaw
        end
    end
    -- the stop, facing them
    local stopAt=at+v*(A.stop*.5)
    leg=Activity.leg(at,stopAt,v,ZERO,math.max(v.Magnitude,.1),A.stop,heading)
    if not leg then return nil end
    table.insert(path,leg)
    at,heading=stopAt,select(3,Activity.legPose(leg,leg.duration))
    -- what is left of the turn (the owner moved meanwhile) on the spot, short
    d=face-at
    if Vector2.new(d.X,d.Z).Magnitude>.05 then
        local want=math.atan2(d.X,d.Z)
        local turn=angleTo(heading,want)
        if math.abs(turn)>=.12 then
            local seconds=Activity.turnSeconds(turn)
            table.insert(path,{from=Activity.pack(at),to=Activity.pack(at),v0={0,0,0},v1={0,0,0},duration=seconds,yaw=heading,turn=turn,turnDuration=seconds,pivot=true})
        end
        heading=want
    end
    table.insert(path,holdLeg(at,heading,math.max(.05,hold or .05)))
    for _,step in ipairs(path)do total+=step.duration end
    return path,total,at,heading
end
-- From rest facing the owner to the run (beta 40): set off the way it faces, curve round to the route through the same
-- small arc, then run on through the route ahead of the arc's end. nil when the turn is small (the run's own short
-- pivot is fine), or it does not fit.
Garden.LaunchTurn=1 -- radians: a smaller turn to the route pivots as before
function Garden.leadLaunch(from,yaw,points,goal,speed,accept)
    local Lead=leadModule()
    local A=Lead.Arc
    local first=Lead.ahead(points,from,goal)[1]
    local d=first-from
    if Vector2.new(d.X,d.Z).Magnitude<2 then return nil end
    local turn=angleTo(yaw,math.atan2(d.X,d.Z))
    if math.abs(turn)<Garden.LaunchTurn then return nil end
    local keep=math.max(A.min,speed*A.keep)
    local u=Vector3.new(math.sin(yaw),0,math.cos(yaw))
    local path={}
    local off=from+u*(keep*.5*A.slow)
    local leg=Activity.leg(from,off,ZERO,u*keep,keep,A.slow,yaw)
    if not leg then return nil end
    table.insert(path,leg)
    local heading=select(3,Activity.legPose(leg,leg.duration))
    d=first-off
    local sweep=angleTo(heading,math.atan2(d.X,d.Z))
    local _,radius,arcTime=Lead.arcFor(sweep,speed)
    local at,v,endYaw=arcLegs(path,off,u*keep,heading,sweep,keep,radius,arcTime)
    if not at then return nil end
    for _,step in ipairs(path)do if accept and not accept(step)then return nil end end
    local rest,seconds=Activity.through(at,Lead.ahead(points,at,goal),v,speed/Activity.ThroughPace,endYaw,accept)
    if not rest then return nil end
    local total=seconds
    for _,step in ipairs(path)do total+=step.duration end
    for _,step in ipairs(rest)do table.insert(path,step)end
    return path,total
end
-- Can this pet lead (or cheer) now? In the garden, and nothing else has it (a greeting gives way: release ends it).
function Garden:leadFree(actor)
    return actor~=nil and actor.mode=="Room"and not actor.park and not actor.care and not actor.dash and not actor.toyReservation
end
function Garden:lead(id,points,goal,nest)
    local actor,input=self.actors[id],self.inputs[id]
    if not input or not self:leadFree(actor)or typeof(goal)~="Vector3"then return false end
    if type(points)~="table"then points={}end
    for _,p in ipairs(points)do if typeof(p)~="Vector3"then return false end end
    local Lead=leadModule()
    local now=self.options.now()
    local sample=Activity.sample(actor,now)
    local at=sample and sample.position or input.anchor
    self:release(actor)
    actor.leadSeq=(actor.leadSeq or 0)+1
    actor.lead={seq=actor.leadSeq,points=points,goal=goal,nest=if typeof(nest)=="Vector3"then nest else nil,phase="start"}
    -- the start: one hop (PetLead.pose) while it turns to the way, then it runs (the onboarding fun pass: the run starts
    -- within 0.6 s; it was two hops, then the turn)
    local face=goal
    for _,p in ipairs(points)do if Lead.flat(p,at)>1.5 then face=p;break end end
    local path,seconds=Garden.leadSettle(at,ZERO,sample and sample.yaw or actor.yaw or 0,face,.05)
    local short=Lead.startHops()+.05-seconds
    if short>0 then path[#path].duration+=short;seconds+=short end
    -- "investigate", not "rest": a lead's long holds never sit or doze (PetSitPose, PetExpression), its face curious
    self:transition(actor,"investigate",at,seconds,"leadStart",nil,nil,{path=path,duration=seconds})
    actor.from,actor.to=Activity.pack(at),Activity.pack(at)
    actor.catch={};actor.idleSince=now
    return true
end
-- The leading pet's walks keep its keep-outs (beta 40: validLeadPath, the lead's plants as well as the water and the
-- solid props), else the everyday check. Beta 41 review: a plant the walk starts in (`from`: the pet stands in a bush)
-- or the lead's goal or nest stands in is not counted, as Lead.clean allows (it fell back to the straight planner).
function Garden.leadExempt(from,lead)
    local out={}
    if typeof(from)=="Vector3"then table.insert(out,from)end
    if type(lead)=="table"then
        if typeof(lead.goal)=="Vector3"then table.insert(out,lead.goal)end
        if typeof(lead.nest)=="Vector3"then table.insert(out,lead.nest)end
    end
    return out
end
function Garden:leadAccept(from,lead)
    local check=self.options.validLeadPath or self.options.validToyPath
    local exempt=Garden.leadExempt(from,lead)
    return function(leg)return check==nil or check({leg},exempt)end
end
-- Run on along the route: "run" at Lead.Run, or "pace" (beta 40: a following owner, looked back at) at Lead.Pace. From
-- rest facing the owner it arcs round to the way (leadLaunch).
function Garden:leadRun(actor,position,now,pace)
    local Lead=leadModule()
    local lead=actor.lead
    local sample=Activity.sample(actor,now)
    local moving=sample~=nil and now<actor.endTime
    local velocity=if moving then sample.velocity else ZERO
    local yaw=sample and sample.yaw or actor.yaw or 0
    local speed=if pace then Lead.Pace else Lead.Run
    local accept=self:leadAccept(position,lead)
    local path,seconds=nil,nil
    if velocity.Magnitude<.5 then path,seconds=Garden.leadLaunch(position,yaw,lead.points,lead.goal,speed,accept)end
    if not path then
        local targets=Lead.ahead(lead.points,position,lead.goal)
        path,seconds=Activity.through(position,targets,velocity,speed/Activity.ThroughPace,yaw,accept)
    end
    if not path then
        -- no smooth walk fits: the server's own planner, straight to the goal round the water and the props
        local planner=self.options.planPath or Activity.plan
        path,seconds=planner(position,lead.goal,velocity,speed*3,0,yaw,nil,ZERO)
    end
    lead.phase,lead.stuckAt,lead.stuckFrom,lead.nudged=if pace then "pace"else "run",nil,nil,nil
    self:transition(actor,"investigate",lead.goal,0,if pace then "leadPace"else "leadRun",nil,nil,{path=path,duration=seconds})
end
function Garden:leadHold(actor,position,now,face,action,phase)
    local Lead=leadModule()
    local sample=Activity.sample(actor,now)
    local moving=sample and now<actor.endTime
    local velocity=if moving then sample.velocity else ZERO
    local yaw=sample and sample.yaw or actor.yaw or 0
    -- beta 40: a running pet arcs round to face them (never a brake and a pivot), when the arc keeps its keep-outs;
    -- an arrival stops on its goal as before (an arc would carry it off the spot by the nest)
    local path,seconds,at=nil,nil,nil
    if moving and phase=="wait"then
        path,seconds,at=Garden.leadArc(position,velocity,yaw,face,Lead.Hold)
        if path then
            local check=self.options.validLeadPath or self.options.validToyPath
            if check and not check(path,Garden.leadExempt(position,actor.lead))then path=nil end
        end
    end
    if not path then path,seconds,at=Garden.leadSettle(position,velocity,yaw,face,Lead.Hold)end
    actor.lead.phase=phase
    self:transition(actor,"investigate",at,seconds,action,nil,nil,{path=path,duration=seconds})
    actor.from,actor.to=Activity.pack(position),Activity.pack(at)
end
-- Pure: how fast the owner comes toward the pet (studs a second; negative: away), from the owner's sampled velocity.
function Garden.leadClosing(pet,owner,ownerVelocity)
    local toPet=Vector3.new(pet.X-owner.X,0,pet.Z-owner.Z)
    if toPet.Magnitude<1e-3 or typeof(ownerVelocity)~="Vector3"then return 0 end
    return Vector3.new(ownerVelocity.X,0,ownerVelocity.Z):Dot(toPet.Unit)
end
function Garden:leadStep(actor,input,position,now)
    local Lead=leadModule()
    local lead=actor.lead
    -- far past any nudge (a teleport, a lost owner): the lead ends and it follows; the client asks again
    if Lead.flat(position,input.position)>Lead.MaxGap then
        actor.lead=nil;actor.idleSince=now;self:transition(actor,"follow",input.anchor,.6);return
    end
    -- arrived at the nest, or lost and waiting by the owner, while the owner walks off (the client stopped asking): the
    -- lead ends past Lead.Far and it follows (beta 38 review C2)
    if(lead.phase=="arrive"or lead.lost)and Lead.flat(position,input.position)>Lead.Far then
        actor.lead=nil;actor.idleSince=now;self.dirty=true;self:transition(actor,"follow",input.anchor,.6);return
    end
    local nest=lead.nest or lead.goal
    -- beta 40: the owner coming on (following) never makes it stop; a waiting pet runs on at once
    local closing=Garden.leadClosing(position,input.position,actor.ownerVelocity)
    -- poofed off its route: it waits by the owner for the client's new route (never a run off the route)
    local next=if lead.lost then nil else Lead.decide(lead,{now=now,pet=position,owner=input.position,goal=lead.goal,moving=now<actor.endTime,closing=closing})
    if next=="run"then self:leadRun(actor,position,now)
    elseif next=="pace"then self:leadRun(actor,position,now,true)
    elseif next=="wait"then self:leadHold(actor,position,now,input.position,"leadWait","wait")
    elseif next=="arrive"then self:leadHold(actor,position,now,nest,"leadArrive","arrive")
    elseif next=="poof"then
        local spot=Lead.ahead(lead.points,position,lead.goal)[1]
        actor.hop={seq=(actor.hop and actor.hop.seq or 0)+1,from=Activity.pack(position),why="lead"}
        actor.from,actor.to=Activity.pack(spot),Activity.pack(spot);actor.path=nil
        actor.startTime,actor.endTime=now,now
        self:leadRun(actor,spot,now,lead.phase=="pace")
    elseif(lead.phase=="wait"or lead.phase=="arrive")and now>=actor.endTime-.05 then
        -- a long wait or arrival: held again, facing the same way
        self:leadHold(actor,position,now,if lead.phase=="wait"then input.position else nest,actor.action,lead.phase)
    end
end
-- A nudge: back along the route to about 5 studs from the owner, or a poof to them. False when it is not leading.
function Garden:leadBack(id)
    local actor,input=self.actors[id],self.inputs[id]
    local lead=actor and actor.lead
    if not lead or not input or actor.mode~="Room"or lead.phase=="start"or lead.phase=="arrive"or lead.phase=="back"then return false end
    local Lead=leadModule()
    local now=self.options.now()
    local sample=Activity.sample(actor,now)
    local position=sample and sample.position or input.anchor
    local yaw=sample and sample.yaw or actor.yaw or 0
    local velocity=if sample and now<actor.endTime then sample.velocity else ZERO
    local way=Lead.backWay(lead.points,position,input.position)
    if way then
        local path,seconds=Activity.through(position,way,velocity,Lead.Run/Activity.ThroughPace,yaw,self:leadAccept(position,lead))
        if not path then
            local planner=self.options.planPath or Activity.plan
            path,seconds=planner(position,way[#way],velocity,Lead.Run*3,0,yaw,nil,ZERO)
        end
        lead.phase,lead.nudged="back",true
        self:transition(actor,"investigate",way[#way],0,"leadBack",nil,nil,{path=path,duration=seconds})
        return true
    end
    -- off the route: it poofs to a landing by the owner and the client sends a new route from there
    local landing=self.options.landing and self.options.landing(input,false,position)
    if typeof(landing)~="Vector3"then return false end
    actor.hop={seq=(actor.hop and actor.hop.seq or 0)+1,from=Activity.pack(position),why="lead"}
    actor.from,actor.to=Activity.pack(landing),Activity.pack(landing);actor.path=nil
    actor.startTime,actor.endTime=now,now
    self:leadHold(actor,landing,now,input.position,"leadWait","wait")
    lead.lost=true
    return true
end
-- The lead is over (parked, paused, the prompt done): it follows as usual.
function Garden:leadEnd(id)
    local actor,input=self.actors[id],self.inputs[id]
    if not actor or not actor.lead or not input then return false end
    actor.lead=nil;actor.idleSince=self.options.now();self.dirty=true
    -- petted (Focus) or on the deck meanwhile: only the lead goes; that mode keeps the pet
    if actor.mode=="Room"then self:transition(actor,"follow",input.anchor,.5)end
    return true
end
-- The jump-spin (tucked in, all set) where it stands, then it follows as usual. Ends a lead.
function Garden:leadCheer(id)
    local actor,input=self.actors[id],self.inputs[id]
    if not input or not self:leadFree(actor)then return false end
    local Lead=leadModule()
    local now=self.options.now()
    local sample=Activity.sample(actor,now)
    local at=sample and sample.position or input.anchor
    local velocity=if sample and now<actor.endTime then sample.velocity else ZERO
    actor.lead=nil
    self:release(actor)
    local path,seconds,stop=Garden.leadSettle(at,velocity,sample and sample.yaw or actor.yaw or 0,nil,Lead.Cheer.hold)
    self:transition(actor,"rest",stop,seconds,"leadCheer",nil,nil,{path=path,duration=seconds})
    actor.from,actor.to=Activity.pack(at),Activity.pack(stop)
    actor.standUntil=now+seconds;actor.idleSince=now+seconds
    return true
end
function Garden:remove(id)
    local actor=self.actors[id]
    if actor then self:release(actor);self.actors[id]=nil;self.inputs[id]=nil;self.dirty=true end
    if self.toyRequests then self.toyRequests[id]=nil end
    if self.racers then self.racers[id]=nil end
    if self.care then self.care.requests[id]=nil;self.care.equips[id]=nil;self.care.equipProofs[id]=nil end
    return self:publish()
end
function Garden:retireSharedToy()
 -- Retire only this activity; generic Garden:release also releases care bays.
 for _,actor in pairs(self.actors)do
  local retired=actor.toyReservation~=nil or actor.toyActionId~=nil or actor.action=="shove"or actor.action=="toyReturn"
  actor.toyReservation,actor.toyActionId,actor.toyRole,actor.toyStartTime=nil,nil,nil,nil
  if retired and not actor.care and actor.mode~="Focus"then
   local input=self.inputs[actor.ownerId]
   if input then actor.idleSince=self.options.now();self:transition(actor,if input.mode=="Board"then "rest"else "follow",input.anchor,.5)end
  end
 end
 if self.toy.ownerId or self.toy.returnAction then self.toy={position=Activity.pack(Layout.Toy)};self.dirty=true end
end
function Garden:toyRequest(id,packet)
 if self.options.sharedToyEnabled==false then return {kind=packet.kind,seq=packet.seq,status="Rejected",reason="ActivityRetired",actionId=packet.actionId}end
 return ToyReturn.request(self,id,packet)
end
function Garden:toyReplay(id,packet)return ToyReturn.replay(self,id,packet)end
function Garden:snapshot()
    local actors={}
    for id,actor in pairs(self.actors) do
        actors[tostring(id)]={ownerId=id,petId=actor.petId,characterId=actor.characterId,petGeneration=actor.petGeneration,generation=actor.generation,mode=actor.mode,
            behavior=actor.behavior,action=actor.action,actionId=actor.actionId,peerId=actor.peerId,startTime=actor.startTime,endTime=actor.endTime,
            from=actor.from,to=actor.to,via=actor.via,path=actor.path,yaw=actor.yaw,charmVisible=actor.charmVisible~=false,requestGeneration=actor.lastFocusSeq or 0,
            parkId=actor.park and actor.park.parkId or nil,toyRole=actor.toyRole,toyStartTime=actor.toyStartTime,care=actor.care and table.clone(actor.care)or nil,dash=actor.dash,
            hop=actor.hop and{seq=actor.hop.seq,from=actor.hop.from}or nil,
            lead=actor.lead and{seq=actor.lead.seq,phase=actor.lead.phase,lost=actor.lead.lost}or nil}
    end
    -- park is nil unless FeatureFlags.Park attached a director (then the snapshot is unchanged).
    return {version=Activity.Version,revision=self.revision,actors=actors,toy=table.clone(self.toy),careBay=self.care and self.care:snapshot()or nil,
        park=self.park and self.park:snapshot()or nil}
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
