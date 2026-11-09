-- Isolated coherent replica and intent transport; no real remote dispatch.
return function(client)
    local Garden=require(client.GardenClient)
    local Http=game:GetService("HttpService")
    local root=Instance.new("Folder");root.Name="_GardenClientSpec";root.Parent=workspace
    local folder=Instance.new("Folder");folder.Name="GardenState";folder.Parent=root
    local boards=Instance.new("Folder");boards.Parent=root
    local character=Instance.new("Model");character:SetAttribute("GardenCharacterId",1);character.Parent=root
    for id=101,102 do local board=Instance.new("Folder");board.Name=tostring(id);board:SetAttribute("CompanionId",if id==101 then "pip"else "puddle");board:SetAttribute("CompanionGeneration",0);board:SetAttribute("GardenCharacterId",1);board.Parent=boards end
    local packets={};local now=10
    local g=Garden.new(boards,{folder=folder,playerId=101,now=function()return now end,characterId=function()return 1 end,remote={FireServer=function(_,packet)table.insert(packets,packet)end}})
    local function actor(id,pet)
        return{ownerId=id,petId=pet,characterId=1,petGeneration=0,generation=1,behavior="follow",mode="Room",actionId=4,from={0,4.025,0},to={2,4.025,0},startTime=10,endTime=14}
    end
    local snapshot={version=1,revision=1,actors={["101"]=actor(101,"pip"),["102"]=actor(102,"puddle")},toy={position={-2,4.025,-9}}}
    local function publish()folder:SetAttribute("Snapshot",Http:JSONEncode(snapshot));game:GetService("RunService").Heartbeat:Wait()end
    local cases={};local function test(name,run)run();table.insert(cases,name)end
    local ok,problem=pcall(function()
        test("joining replica receives current action and rejects stale or malformed replacement",function()
            publish();assert(g:get(101,"pip",character).endTime==14)
            local retained=g.snapshot;snapshot.revision=0;publish();assert(g.snapshot==retained)
            folder:SetAttribute("Snapshot","broken");game:GetService("RunService").Heartbeat:Wait();assert(g.snapshot==retained)
            snapshot.revision=2
        end)
        test("a partial or superseded peer greeting is never presented as an agreed pair",function()
            local a,b=snapshot.actors["101"],snapshot.actors["102"]
            a.action,b.action="greet","greet";a.peerId,b.peerId=102,101;a.actionId,b.actionId=8,9;publish()
            assert(g:get(101,"pip",character)==nil)
            b.actionId=8;snapshot.revision+=1;publish();assert(g:get(101,"pip",character).actionId==8)
            boards["102"]:SetAttribute("CompanionId","pip");assert(g:get(101,"pip",character)==nil)
            boards["102"]:SetAttribute("CompanionId","puddle")
        end)
        test("character replacement fences a previously valid actor",function()
            character:SetAttribute("GardenCharacterId",nil);assert(g:get(101,"pip",character)==nil)
            character:SetAttribute("GardenCharacterId",2);assert(g:get(101,"pip",character)==nil)
            character:SetAttribute("GardenCharacterId",1)
        end)
        test("an old same-alias snapshot is ignored after confirmed equip generation advances",function()
            boards["101"]:SetAttribute("CompanionGeneration",2)
            assert(g:get(101,"pip",character)==nil)
            boards["101"]:SetAttribute("CompanionGeneration",0)
        end)
        test("one deliberate focus holds with bounded pulses and retirement ends that generation",function()
            g:focus(true,"pip",Vector3.new(2,4.025,0),0);g:focus(true,"pip",Vector3.new(2,4.025,0),0)
            assert(#packets==1 and packets[1].kind=="focus")
            for _=1,31 do g:step(1/60)end
            assert(#packets==2 and packets[2].kind=="focusPulse"and packets[2].seq==packets[1].seq)
            g:focus(false);local count=#packets;assert(packets[count].kind=="focusEnd")
            for _=1,120 do g:step(1/60)end;assert(#packets==count)
        end)
        test("quick end and reopen defers acquisition until the server focus cooldown passes",function()
            now=11;g:focus(true,"pip",Vector3.new(2,4.025,0),0)
            g:focus(false);local count=#packets
            now=11.1;g:focus(true,"pip",Vector3.new(2,4.025,0),0)
            assert(#packets==count and g.focusPet==nil)
            g:step(.5);assert(#packets==count,"unacquired focus must not send pulses")
            now=11.31;g:focus(true,"pip",Vector3.new(2,4.025,0),0)
            assert(#packets==count+1 and packets[#packets].kind=="focus"and g.focusPet=="pip")
            g:focus(false)
        end)
        test("an unacknowledged current focus retries once and retiring it cancels all retry work",function()
            now=12;g:focus(true,"pip",Vector3.new(2,4.025,0),0)
            local begin=packets[#packets];local index=#packets
            for _=1,120 do g:step(1/60)end
            local retries=0
            for i=index+1,#packets do if packets[i].kind=="focus"then retries+=1;assert(packets[i].seq==begin.seq)end end
            assert(retries==1)
            g:focus(false);local count=#packets
            for _=1,120 do g:step(1/60)end;assert(#packets==count)
        end)
        test("per-pet authoritative OFF is retained and unsupported peers default to visible",function()
            boards["101"]:SetAttribute("PetAppearance",Http:JSONEncode({pip={charmVisible=false},puddle={charmVisible=true}}))
            assert(not g:appearance(boards["101"],"pip").charmVisible and g:appearance(boards["101"],"puddle").charmVisible)
        end)
    end)
    g:destroy();root:Destroy();assert(ok,problem)
    return{passed=#cases,cases=cases}
end
