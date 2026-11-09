-- Injected authority tests: no Players, profile writes, real remotes or rewards.
return function(server)
    local Garden=require(server.GardenState)
    local Activity=require(game.ReplicatedStorage.Shared.GardenActivity)
    local Layout=require(game.ReplicatedStorage.Shared.GardenLayout)
    local cases={};local function test(name,run)run();table.insert(cases,name)end
    local function fixture(count)
        local c={now=0,writes=0,inputs={}}
        for id=1,count do c.inputs[id]={petId=if id%2==1 then "pip"else "puddle",owned=true,alive=true,characterId=1,mode="Room",
            position=Vector3.new((id-1)*2,7,-2),anchor=Vector3.new((id-1)*2,4.025,-2),yaw=0,charmVisible=true}end
        c.garden=Garden.new({now=function()return c.now end,publish=function(snapshot)c.writes+=1;c.snapshot=snapshot end,
            validFocus=function()return true end,award=function()error("garden cannot award")end})
        function c:step(dt)self.now+=dt;self.garden:step(dt,self.inputs)end
        c:step(.5);return c
    end
    test("solo garden investigates, shoves twice, rests and returns without a reward path",function()
        local c=fixture(1);local observed={};local positive,negative=false,false
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
            if c.now>=3 then
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
        assert(not c.garden:focus(1,{kind="focus",seq=1,petId="pip",position={100,4,100}}))
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
        c.now+=.5;packet.seq=2;packet.position=Activity.pack(c.inputs[1].anchor);assert(c.garden:focus(1,packet))
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
        local c=fixture(3);c.inputs[2].position=Vector3.new(11,7,-2);c.inputs[2].anchor=Vector3.new(11,4.025,-2)
        c.inputs[3].position=Vector3.new(-11,7,-2);c.inputs[3].anchor=Vector3.new(-11,4.025,-2)
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
        local c=fixture(1)
        while c.garden.actors[1].behavior~="investigate"do c:step(.5)end
        local snapshot=c.garden:snapshot();local a=snapshot.actors["1"]
        local now=(a.startTime+a.endTime)*.5
        local first,second=Activity.sample(a,now),Activity.sample(a,now)
        assert((first.position-second.position).Magnitude<1e-6 and math.abs(first.phase-.5)<1e-9)
        assert((first.position-Activity.vector(a.from)).Magnitude>.1)
        local payload=game:GetService("HttpService"):JSONEncode(snapshot)
        assert(#payload<4096,"small authoritative snapshot exceeded its bounded payload")
    end)
    return {passed=#cases,cases=cases}
end
