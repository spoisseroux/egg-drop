-- Stickers are retired: faceplates replaced them (SCOPE-2026-11-12 Decisions).
-- Only the blank id remains so the appearance protocol and old saves that
-- still carry a `sticker` field keep loading; every old id resolves to "none".
local Stickers={Default="none",Order={"none"},ById={none={name="Blank"}}}
function Stickers.canEquip(id)return id=="none"end
function Stickers.resolve(id)return "none"end
return Stickers
