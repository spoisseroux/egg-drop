-- Injected authority tests: no Players, profile writes, real remotes or rewards.
return function(server)
    local Garden=require(server.GardenState)
    local Activity=require(game.ReplicatedStorage.Shared.GardenActivity)
    local Layout=require(game.ReplicatedStorage.Shared.GardenLayout)
    local cases={};local function test(name,run)run();table.insert(cases,name)end
    local function fixture(count,nearToy)
        local c={now=0,writes=0,inputs={}}
        for id=1,count do
            local at=if nearToy then Layout.Lawn+Vector3.new((id-1)*2,0,2)else Vector3.new((id-1)*2,4.025,-2)
            c.inputs[id]={petId=if id%2==1 then "pip"else "puddle",owned=true,alive=true,characterId=1,mode="Room",
                position=Vector3.new(at.X,if nearToy then at.Y+3 else 7,at.Z),anchor=at,yaw=0,charmVisible=true}
        end
        c.garden=Garden.new({now=function()return c.now end,publish=function(snapshot)c.writes+=1;c.snapshot=snapshot end,
            validFocus=function()return true end,award=function()error("garden cannot award")end})
        function c:step(dt)self.now+=dt;self.garden:step(dt,self.inputs)end
        c:step(.5);return c
    end
    test("solo garden investigates, shoves twice, rests and returns without a reward path",function()
        local c=fixture(1,true);local observed={};local positive,negative=false,false
        for _=1,160 do
            c:step(.5);local actor=c.garden.actors[1];observed[actor.behavior]=true
            if actor.action=="shove"then
                assert(c.garden.toy.ownerId==1 and c.garden.toy.actionId==actor.actionId)
                for _,phase in ipairs({.125,.375,.625,.875})do
                    local toy=Activity.sampleToy(c.garden.toy,actor.startTime+phase*(actor.endTime-actor.startTime))
                    positive=positive or toy.tilt>0;negative=negative or toy.tilt<0
                end
            end
        end
        assert(observed.follow and observed.investigate and observed.play and observed.rest and positive and negative)
    end)
    test("a distant owner rests locally instead of repeatedly starting an unreachable central toy trip",function()
        local c=fixture(1)
        c.inputs[1].position=Vector3.new(-23.293,7,-25.510)
        c.inputs[1].anchor=Vector3.new(-20.693,4.025,-22.510)
        local rested=false
        for _=1,100 do
            c:step(.5);local actor=c.garden.actors[1]
            assert(actor.behavior~="investigate"and actor.behavior~="play"and not c.garden.toy.ownerId)
            rested=rested or actor.behavior=="rest"
            -- The old3s deadline assumed a .6s unbounded dash. Smooth recovery
            -- must be inside the22stud leash after this finite planned trip,
            -- and may not start an unreachable toy while closing the gap.
            if c.now>=3.5 then
                local position=c.garden:position(actor,c.now)
                assert(Vector2.new(position.X-c.inputs[1].position.X,position.Z-c.inputs[1].position.Z).Magnitude<=22)
            end
        end
        assert(rested,"far garden pet should remain active through local rest")
    end)
    test("paired greeting is one atomic action and focus cancels both reservations",function()
        local c=fixture(2);local a,b=c.garden.actors[1],c.garden.actors[2]
        assert(a.action=="greet"and b.action=="greet"and a.actionId==b.actionId and a.startTime==b.startTime)
        assert(a.peerId==2 and b.peerId==1 and c.snapshot.actors["1"].actionId==c.snapshot.actors["2"].actionId)
        assert(c.garden:focus(1,{kind="focus",seq=1,petId="pip",position=Activity.pack(c.inputs[1].anchor),yaw=0}))
        assert(a.mode=="Focus"and a.action=="focus"and not a.pairId and not b.pairId and b.action~="greet")
        assert(next(c.garden.pairs)==nil)
    end)
    test("v859 leash: past LeashRadius from its owner a pet ends a greeting and walks back",function()
        local c=fixture(2);local a,b=c.garden.actors[1],c.garden.actors[2]
        assert(a.pairId and b.pairId)
        -- The owner is far away without a fresh owner-moved release (sync's .65 stud rule).
        local far=c.inputs[1].position+Vector3.new(Layout.LeashRadius+3,0,0)
        c.inputs[1].position=far;c.inputs[1].anchor=Vector3.new(far.X,4.025,far.Z);a.lastOwner=far
        c:step(.5);c:step(.5)
        assert(not a.pairId and not b.pairId and next(c.garden.pairs)==nil,"the greeting outlived the leash")
        assert(a.behavior=="follow"and(Activity.vector(a.to)-c.inputs[1].anchor).Magnitude<.5,"the pet did not head back")
        -- A trip toward the shared toy only starts when every waypoint is inside the leash margin.
        assert(Layout.LeashRadius>=18 and Layout.LeashRadius<=20 and Layout.LeashMargin>0)
    end)
    test("v859 review: wander targets stay inside the leash margin; a missing heading cannot error",function()
        local input={position=Vector3.new(0,7,0),anchor=Vector3.new(0,4.025,0)}
        assert(Garden.insideLeash(input,Vector3.new(Layout.LeashRadius-Layout.LeashMargin-.1,4,0)))
        assert(not Garden.insideLeash(input,Vector3.new(Layout.LeashRadius-Layout.LeashMargin+.1,4,0)))
        assert(not Garden.insideLeash(input,nil))
        -- validWander pushing every candidate far away: the pet never starts that wander.
        local c={now=0,inputs={{petId="pip",owned=true,alive=true,characterId=1,mode="Room",position=Vector3.new(0,7,-2),anchor=Vector3.new(0,4.025,-2),yaw=0,charmVisible=true}}}
        c.garden=Garden.new({now=function()return c.now end,publish=function()end,validFocus=function()return true end,sharedToyEnabled=false,
            validWander=function(_,candidate)return candidate+Vector3.new(Layout.LeashRadius,0,0)end})
        for _=1,60 do c.now+=.5;c.garden:step(.5,c.inputs);assert(c.garden.actors[1].action~="wander"and c.garden.actors[1].action~="nookApproach","a far wander started")end
        -- A far pet with no stored heading walks back instead of erroring.
        local actor=c.garden.actors[1];c.garden:release(actor)
        actor.to=nil;actor.behavior,actor.action="follow",nil;actor.idleSince,actor.nextWanderAt=c.now,c.now+100
        c.inputs[1].position=Vector3.new(40,7,-2);c.inputs[1].anchor=Vector3.new(40,4.025,-2);actor.lastOwner=c.inputs[1].position
        c.now+=.5;c.garden:step(.5,c.inputs);c.now+=.5;c.garden:step(.5,c.inputs)
        assert(actor.behavior=="follow"and Activity.vector(actor.to)~=nil,"no walk back without a heading")
    end)
    test("Board is observable and cannot acquire focus, toy or an automatic reward",function()
        local c=fixture(1);c.inputs[1].mode="Board"
        for _=1,60 do c:step(.5)end
        local a=c.garden.actors[1]
        assert(a.mode=="Board"and a.behavior=="rest"and not c.garden.toy.ownerId)
        assert(c.snapshot.actors["1"].mode=="Board")
        assert(not c.garden:focus(1,{kind="focus",seq=1,petId="pip",position=Activity.pack(c.inputs[1].anchor)}))
    end)
    test("focus is owner/pet/range/generation validated and its lease expires",function()
        local c=fixture(1);local target=Activity.pack(c.inputs[1].anchor)
        assert(not c.garden:focus(2,{kind="focus",seq=1,petId="pip",position=target}))
        assert(not c.garden:focus(1,{kind="focus",seq=1,petId="puddle",position=target}))
        assert(c.garden:focus(1,{kind="focus",seq=1,petId="pip",position=target}))
        assert(not c.garden:focus(1,{kind="focus",seq=1,petId="pip",position=target}))
        assert(not c.garden:focus(1,{kind="focusPulse",seq=2,petId="pip"}))
        c:step(2);assert(c.garden.actors[1].mode=="Room")
        assert(not c.garden:focus(1,{kind="focusPulse",seq=1,petId="pip"}))
    end)
    test("moved owners and replaced character cannot refresh a stale focus hold",function()
        local c=fixture(1);local packet={kind="focus",seq=1,petId="pip",position=Activity.pack(c.inputs[1].anchor)}
        assert(c.garden:focus(1,packet))
        c.inputs[1].position+=Vector3.new(10,0,0);c.inputs[1].anchor+=Vector3.new(10,0,0)
        assert(not c.garden:focus(1,{kind="focusPulse",seq=1,petId="pip"})and c.garden.actors[1].mode=="Room")
        c:step(8);packet.seq=2;packet.position=Activity.pack(c.inputs[1].anchor);assert(c.garden:focus(1,packet))
        c.inputs[1].characterId=2
        assert(not c.garden:focus(1,{kind="focusPulse",seq=2,petId="pip"}))
    end)
    test("a superseded participant generation explicitly retires the paired greeting",function()
        local c=fixture(2);c.garden.actors[1].generation+=1
        c:step(.5)
        assert(next(c.garden.pairs)==nil and not c.garden.actors[1].pairId and not c.garden.actors[2].pairId)
        assert(c.garden.actors[1].action~="greet"and c.garden.actors[2].action~="greet")
    end)
    test("equip, character replacement and leave invalidate old generations exactly once",function()
        local c=fixture(2);local old=c.garden.actors[1].generation
        c.inputs[1].petId="puddle";c:step(.5)
        assert(c.garden.actors[1].petId=="puddle"and c.garden.actors[1].generation>old)
        old=c.garden.actors[1].generation;c.inputs[1].characterId=2;c:step(.5)
        assert(c.garden.actors[1].characterId==2 and c.garden.actors[1].generation>old)
        assert(c.garden:remove(1));local writes=c.writes
        assert(not c.garden:remove(1)and c.writes==writes and not c.snapshot.actors["1"])
    end)
    test("a delayed first acquisition cannot revive the same alias after equip-away and back",function()
        local c=fixture(1)
        local stale={kind="focus",seq=20,petId="pip",position=Activity.pack(c.inputs[1].anchor),characterId=1,petGeneration=0}
        c.inputs[1].petId="puddle";c.inputs[1].petGeneration=1;c:step(.5)
        c.inputs[1].petId="pip";c.inputs[1].petGeneration=2;c:step(.5)
        assert(not c.garden:focus(1,stale)and c.garden.actors[1].mode=="Room")
        stale.petGeneration=2;assert(c.garden:focus(1,stale))
        c.inputs[1].characterId=2;c:step(.5)
        stale.seq=21;assert(not c.garden:focus(1,stale))
    end)
    test("only one toy reservation exists and another waiting pet gets a turn",function()
        local c=fixture(3,true)
        c.inputs[2].anchor=Layout.Lawn+Vector3.new(11,0,2);c.inputs[2].position=c.inputs[2].anchor+Vector3.new(0,3,0)
        c.inputs[3].anchor=Layout.Lawn+Vector3.new(-11,0,2);c.inputs[3].position=c.inputs[3].anchor+Vector3.new(0,3,0)
        local owners={}
        for _=1,160 do
            c:step(.5);local playing=0
            for id,a in pairs(c.garden.actors)do if a.action=="shove"then playing+=1;owners[id]=true;assert(c.garden.toy.ownerId==id)end end
            assert(playing<=1)
        end
        local count=0;for _ in pairs(owners)do count+=1 end;assert(count>=2)
    end)
    test("decision budget is2Hz and stationary Board snapshots perform no recurring writes",function()
        local c=fixture(1);c.inputs[1].mode="Board";c:step(.5)
        local reads=0;local function inputs()reads+=1;return c.inputs end
        for _=1,3 do c.garden:step(.125,inputs)end;assert(reads==0)
        c.garden:step(.125,inputs);assert(reads==1)
        local writes=c.writes;for _=1,8 do c.now+=.5;c.garden:step(.5,inputs)end
        assert(c.writes==writes)
    end)
    test("late join samples the current shared path, not a replayed beginning",function()
        local c=fixture(1,true)
        while c.garden.actors[1].behavior~="investigate"do c:step(.5)end
        local snapshot=c.garden:snapshot();local a=snapshot.actors["1"]
        local now=(a.startTime+a.endTime)*.5
        local first,second=Activity.sample(a,now),Activity.sample(a,now)
        assert((first.position-second.position).Magnitude<1e-6 and math.abs(first.phase-.5)<1e-9)
        assert((first.position-Activity.vector(a.from)).Magnitude>.1)
        local payload=game:GetService("HttpService"):JSONEncode(snapshot)
        assert(#payload<4096,"small authoritative snapshot exceeded its bounded payload")
    end)
    -- Beta (12) QA G1: pets catch up. A one-pet garden on the shared lawn; options.catchup / landing injected.
    local Catchup=require(game.ReplicatedStorage.Shared.PetCatchup)
    local function hopper(on,landing,extra)
        local c={now=0,inputs={},calls=0,warned={}}
        local at=Vector3.new(0,4.025,-2)
        c.inputs[1]={petId="pip",owned=true,alive=true,characterId=1,mode="Room",position=at+Vector3.new(0,3,0),anchor=at,yaw=0,charmVisible=true}
        local options={now=function()return c.now end,publish=function(snapshot)c.snapshot=snapshot end,validFocus=function()return true end,sharedToyEnabled=false,
            warn=function(text)table.insert(c.warned,text)end}
        if on~=nil then
            options.catchup=function()return c.on end
            options.landing=function(input,racing)c.calls+=1;c.racing=racing;if landing then return landing(input,racing)end;return input.anchor+Vector3.new(0,0,2.5)end
        end
        for k,v in pairs(extra or {})do options[k]=v end
        c.on=on
        c.garden=Garden.new(options)
        function c:step(dt)self.now+=dt;self.garden:step(dt,self.inputs)end
        function c:move(by)local input=self.inputs[1];input.position+=by;input.anchor+=by end
        c:step(.5);return c
    end
    local function flatGap(c)
        local actor=c.garden.actors[1];local p=c.garden:position(actor,c.now)
        return Vector2.new(p.X-c.inputs[1].anchor.X,p.Z-c.inputs[1].anchor.Z).Magnitude
    end
    test("G1 far: the owner 120 studs off; a hop after FarHold (not before), at the landing at once, hop seq and from on the snapshot",function()
        local c=hopper(true)
        c:step(.5)
        local before=c.garden:position(c.garden.actors[1],c.now)
        c:move(Vector3.new(120,0,0))
        c:step(.5);c:step(.5);c:step(.5)
        assert(c.garden.actors[1].hop==nil,"no hop before FarHold")
        c:step(.5)
        local actor=c.garden.actors[1]
        assert(actor.hop and actor.hop.seq==1 and actor.hop.why=="far","hopped")
        assert(actor.action=="catchup"and actor.path==nil,"a prepared hold, never a stroll path")
        local p=c.garden:position(actor,c.now)
        assert((p-(c.inputs[1].anchor+Vector3.new(0,0,2.5))).Magnitude<1e-6,"at the landing at once")
        assert(flatGap(c)<=4.01)
        local snap=c.snapshot.actors["1"]
        assert(snap.hop.seq==1 and Activity.vector(snap.hop.from)and(Activity.vector(snap.hop.from)-before).Magnitude<60,"from is where it was")
        assert(c.racing==false)
        -- The rest ends, the pet follows; the seq stays for late clients.
        for _=1,4 do c:step(.5)end
        assert(c.garden.actors[1].behavior=="follow"and c.snapshot.actors["1"].hop.seq==1)
    end)
    test("G1 stuck: a pet that cannot move toward its owner for StuckSeconds hops; cooldown between hops",function()
        local c=hopper(true,nil,{resolveTarget=function(_,from)return from,true end})
        c:move(Vector3.new(15,0,0))
        local t0=c.now
        while c.garden.actors[1].hop==nil and c.now-t0<10 do c:step(.5)end
        local actor=c.garden.actors[1]
        assert(actor.hop and actor.hop.why=="stuck","stuck hop")
        assert(c.now-t0>=Catchup.StuckSeconds and c.now-t0<=Catchup.StuckSeconds+1.5,tostring(c.now-t0))
        local at=c.now
        c:move(Vector3.new(15,0,0))
        while c.garden.actors[1].hop.seq==1 and c.now-at<20 do c:step(.5)end
        assert(c.garden.actors[1].hop.seq==2 and c.now-at>=Catchup.Cooldown,"cooldown "..tostring(c.now-at))
    end)
    test("G1 skips: a deck round (Board), a race; no landing waits Retry and changes nothing",function()
        local c=hopper(true)
        c.inputs[1].mode="Board";c:step(.5)
        c:move(Vector3.new(120,0,0));for _=1,10 do c:step(.5)end
        assert(c.garden.actors[1].hop==nil and c.calls==0,"Board")
        c=hopper(true)
        c.garden:setRacer(1,"race-1")
        c:move(Vector3.new(120,0,0));for _=1,10 do c:step(.5)end
        assert(c.garden.actors[1].hop==nil and c.calls==0,"racing")
        c=hopper(true,function()return nil end)
        c:move(Vector3.new(120,0,0));for _=1,4 do c:step(.5)end
        assert(c.calls==1 and c.garden.actors[1].hop==nil,"asked once")
        c:step(.5);c:step(.5);c:step(.5)
        assert(c.calls==1,"Retry wait");c:step(.5);c:step(.5)
        assert(c.calls==2,"asked again after Retry")
        -- Someone else racing: landing is told so (the course and pad are refused there).
        c=hopper(true);c.garden.racers={[2]="race-2"}
        c:move(Vector3.new(120,0,0));for _=1,4 do c:step(.5)end
        assert(c.racing==true and c.garden.actors[1].hop)
    end)
    test("G1 code review 2: a sit (settle, then its rest) or a nook rest 8-19 studs from the anchor never counts as stuck",function()
        for _,case in ipairs({{"settle",14},{"nookRest",6}})do
            local c=hopper(true)
            local actor=c.garden.actors[1]
            local far=c.inputs[1].anchor+Vector3.new(12,0,0)
            c.garden:transition(actor,"rest",far,case[2],case[1])
            actor.from=Activity.pack(far);actor.to=Activity.pack(far);actor.path=nil
            for _=1,math.ceil((case[2]+6)/.5)do c:step(.5);assert(c.garden.actors[1].hop==nil,case[1].." poofed at "..c.now)end
        end
        -- A wanderPause far from the anchor does count (the pet is not getting back).
        local c=hopper(true,nil,{resolveTarget=function(_,from)return from,true end})
        local actor=c.garden.actors[1]
        local far=c.inputs[1].anchor+Vector3.new(12,0,0)
        c.garden:transition(actor,"rest",far,30,"wanderPause")
        actor.from=Activity.pack(far);actor.to=Activity.pack(far);actor.path=nil
        for _=1,12 do c:step(.5)end
        assert(c.garden.actors[1].hop and c.garden.actors[1].hop.why=="stuck","a far wanderPause")
    end)
    test("G1 off: the switch off writes no actor field; with no options the snapshot is today's",function()
        local plain=hopper(nil);local off=hopper(false)
        for _,c in ipairs({plain,off})do c:move(Vector3.new(120,0,0));for _=1,12 do c:step(.5)end end
        local actor=off.garden.actors[1]
        assert(actor.catch==nil and actor.hop==nil and off.calls==0,"off touched the actor")
        local Http=game:GetService("HttpService")
        assert(Http:JSONEncode(plain.snapshot)==Http:JSONEncode(off.snapshot),"off parity")
        assert(off.snapshot.actors["1"].hop==nil)
        -- Turning it on later starts the hold fresh (no stale far time).
        off.on=true;off:step(.5)
        assert(off.garden.actors[1].hop==nil,"no instant hop on a switch flip")
    end)
    return {passed=#cases,cases=cases}
end
