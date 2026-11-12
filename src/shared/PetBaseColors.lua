-- Neutral undyed appearance. Saved hue anchors/doses and protected face palettes are separate.
local Colors={body=Color3.fromHex("#FFFFFF"),secondary=Color3.fromHex("#A8A5AE")}
function Colors.applyDefinition(definition)
 definition.faceBody=definition.faceBody or definition.palette.body
 definition.palette.body="#FFFFFF";definition.palette.secondary="#A8A5AE"
 -- Two-tone rigs get their paw tips from the body gradient, so hands stay body-coloured.
 for _,piece in ipairs(if definition.twoTone then {} else definition.pieces)do
  if piece.channel=="HandL"or piece.channel=="HandR"or piece.channel=="CuffL"or piece.channel=="CuffR"then piece.colorRole="secondary"end
 end
end
return table.freeze(Colors)
