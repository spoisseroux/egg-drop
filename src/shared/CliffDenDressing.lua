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
return table.freeze(Hide)
