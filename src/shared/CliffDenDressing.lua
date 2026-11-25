-- The dressing the beta's sculpt leaves floating or blocking (CLIFF-DEN-BUILD, Studio R2): the WorldDressing flowers and
-- bushes over the terrace top, in the cliff path's cut or its corridor (CliffDenData.dressingHide, from
-- cliff_den_checks.py). Skipped where they are placed, only while the sculpt is in (workspace `CliffDen`, set at server
-- start). Pure but for the lazy data read; live never has the attribute, so it never reads CliffDenData.
local Hide={}
Hide.Attribute="CliffDen"
Hide.Within=.05
local points=nil
-- The hide list ({x, z} pairs), or an empty one when the data is missing. data (specs) replaces CliffDenData.
function Hide.points(data)
	if data==nil and points then return points end
	local d=data
	if d==nil then
		local ok,module=pcall(function()return require(script.Parent:FindFirstChild("CliffDenData"))end)
		d=if ok then module else nil
	end
	local out={}
	if type(d)=="table"and type(d.dressingHide)=="table"then
		for _,p in ipairs(d.dressingHide)do
			if type(p)=="table"and type(p[1])=="number"and type(p[2])=="number"then table.insert(out,{p[1],p[2]})end
		end
	end
	if data==nil then points=out end
	return out
end
-- Pure: is a dressing row at (x, z) one to skip? on: the sculpt is in (nil reads the workspace attribute).
function Hide.skip(x,z,on,data)
	if on==nil then on=workspace:GetAttribute(Hide.Attribute)==true end
	if on~=true or type(x)~="number"or type(z)~="number"then return false end
	for _,p in ipairs(Hide.points(data))do
		if math.abs(p[1]-x)<=Hide.Within and math.abs(p[2]-z)<=Hide.Within then return true end
	end
	return false
end
-- Fable cliff-den review fix 9 (FABLE-REVIEW-CLIFF-DEN.md): the tan cut faces at the den's mouth hidden with the
-- existing dressing only, while the den's sculpt is in (LoungeWorldV7Art.dressing, Art.carved). The proper fix is the
-- next sculpt export (cut faces take the rock material).
--   Bushes  WorldDressing.Bushes rows {x, base y, z, kind index (BushKinds), yaw, scale}: two each side of the mouth at
--           the jamb rocks' feet (Fable: about x -18 and x 4, z -97), behind the notice board on the right. Base y from
--           the sculpt (assets/world/world-v7-beta.fbx): the apron's top (4.95) on the left, the lawn (4.1 to 4.5) on
--           the right. They count toward WorldDressing.MaxBushes in place of the six the sculpt skips.
--   Boulder a ParkHollowMount.stone row (the Hollow's rim boulders): one on the big tan slope left of the mouth, at its
--           foot (ground 5.2 to 5.6), clear of the cliff path's first tread. Visual only, as the Hollow's.
Hide.MouthBushes=table.freeze({
	table.freeze({-17.4,4.95,-97.3,2,.4,1.7}),  -- FrondSpray, against the left jamb rock
	table.freeze({-18.1,5.0,-95.3,1,2.1,1.5}),  -- FrondFan, in front of it on the slope's foot
	table.freeze({4.8,4.45,-97.8,2,3.6,1.6}),   -- FrondSpray, behind the board against the right jamb rock
	table.freeze({6.2,4.15,-96.6,1,5.2,1.3}),   -- FrondFan
})
Hide.MouthBoulder=table.freeze({name="DenMouthBoulder",x=-24.6,y=5.3,z=-92.4,size=Vector3.new(5,4.6,4),yaw=.6,seed=20261126,
	colour="#6B7465"})
return table.freeze(Hide)
