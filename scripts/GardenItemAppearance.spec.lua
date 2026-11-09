-- Only applied selections cross the garden boundary; private earned/stock do not.
return function(client)
 local Http=game:GetService("HttpService");local Garden=require(client.GardenClient)
 local boards=Instance.new("Folder");local board=Instance.new("Folder");board.Name="1";board.Parent=boards
 board:SetAttribute("CompanionId","pip");board:SetAttribute("PetAppearanceRevision",19)
 local state=Instance.new("Folder");state.Name="GardenState"
 local garden=Garden.new(boards,{playerId=1,folder=state})
 board:SetAttribute("PetAppearance",Http:JSONEncode({pip={toyId="ball",featureStages={horns=5,claws=-1,wings=1.5},earned=5,featureStock=99},puddle={toyId="sparkler",featureStages={horns=4,claws=4,wings=4}}}))
 local a=garden:appearance(board,"pip");assert(a.toyId=="ball"and a.featureStages.horns==5 and a.featureStages.claws==0 and a.featureStages.wings==0 and a.appearanceGeneration==19)
 local b=garden:appearance(board,"puddle");assert(b.toyId=="none"and b.featureStages.horns==0 and not b.earned and not b.featureStock)
 board:SetAttribute("PetAppearance",Http:JSONEncode({pip={toyId="foreign-id",featureStages={horns=0,claws=3,wings=5}}}))
 a=garden:appearance(board,"pip");assert(a.toyId=="none"and a.featureStages.claws==3 and a.featureStages.wings==5)
 garden:destroy();state:Destroy();boards:Destroy();return{passed=3,cases={"stage validation","selected identity scope","unknown toy fallback"}}
end
