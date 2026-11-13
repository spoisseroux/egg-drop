-- Odds disclosure text. An equal share that has no exact percentage (1/3, 1/6...)
-- reads "1 in N" so the list never adds up to 99.9%; other odds read as a percentage.
local OddsText={}
function OddsText.format(probability)
 if type(probability)~="number"or probability~=probability or probability<=0 then return "0%"end
 if probability>=1 then return "100%"end
 local percent=probability*100
 -- Only shares that a one-decimal percentage can't state exactly (33.33...%) switch to "1 in N".
 local n=math.round(1/probability)
 if n>1 and math.abs(probability*n-1)<1e-9 and math.abs(percent*10-math.round(percent*10))>1e-6 then return "1 in "..n end
 if math.abs(percent-math.round(percent))<1e-6 then return string.format("%d%%",math.round(percent))end
 return string.format("%.1f%%",percent)
end
return table.freeze(OddsText)
