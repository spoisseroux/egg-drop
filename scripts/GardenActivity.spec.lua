return function(client)
    local Activity=require(game.ReplicatedStorage.Shared.GardenActivity)
    local Follow=require(client.PetFollow)
    local actor={ownerId=1,petId="pip",generation=4,actionId=7,behavior="investigate",startTime=10,endTime=14,
        from={0,4.025,0},via={0,4.025,-2},to={-2,4.025,-2},yaw=0}
    local function visual()return{origin=Vector3.new(0,4.025,0),worldScale=.72,greet=function()end,applyGardenPose=function(self,sample)self.pose=sample end}end
    local a,b=visual(),visual();local sa,sb
    for i=1,120 do sa=Follow.activity(a,actor,10+i/60,1/60,sa,false)end
    for i=1,60 do sb=Follow.activity(b,actor,10+i/30,1/30,sb,false)end
    assert((a.origin-b.origin).Magnitude<1e-6 and a.pose.actionId==b.pose.actionId)
    local previous=a.origin
    Follow.activity(a,actor,12+1/120,1/120,sa,false)
    assert((a.origin-previous).Magnitude>0,"movement must interpolate between cosmetic ticks")
    local reduced=visual();Follow.activity(reduced,actor,12,1/60,nil,true)
    assert((reduced.origin-b.origin).Magnitude<1e-6 and reduced.gaitWeight==0)
    assert(math.abs(math.abs(Activity.sample(actor,10.2).yaw)-math.pi)<1e-6,"first leg must face the lawn point")
    assert(math.abs(Activity.sample(actor,13.8).yaw+math.pi*.5)<1e-6,"second leg must face the toy")
    assert(Activity.sample(actor,20).position==Activity.vector(actor.to))
    local focus=table.clone(actor);focus.action="focus";focus.behavior="rest"
    assert(Activity.sample(focus,12).expression=="curious","idle focus must keep its eyes open")
    assert(Activity.sample({from={0/0,0,0},to={0,0,0},startTime=0,endTime=1},.5)==nil)
    return{passed=4,cases={"two viewer rates sample identical server-time positions","movement advances every rendered frame","reduced gait preserves shared gameplay position","late and malformed snapshots are bounded"}}
end
