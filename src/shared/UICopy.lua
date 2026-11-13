-- One table for the menu copy (UI personality T3, UI-PERSONALITY-SCOPE-2026-11-13
-- section 3). Voice: a friend at the garden gate, short, warm, present tense. Facts
-- (odds, prices, "looks only", "never an advantage") stay exact; buttons keep plain
-- verbs. Every line fits the width of the line it replaced on the 812 x 354 layout
-- (scripts/UICopy.spec.lua measures them).
--
-- UICopy.get("results.leave.wide") returns the string; `{name}` placeholders are
-- filled from `vars` (no concatenation at call sites, so translations slot in later).
local UICopy={}

local Table={
 hatch={
  footer={
   desktop="Give one a shake. The odds are on the label.",
   phone="The odds are on the label",
  },
  promise="No surprises. The odds never change.",
  -- Restricted players (paid random items): the fixed next item instead of the odds.
  next={label="Next item",line="Next: {item}",done="All collected"},
  egg={
   toy={line="A toy to carry and chase",description="Something is rattling around in here. Hatches one toy your pet can carry and play with.",per="1 toy per egg"},
   material={line="A fresh new coat",description="Smooth and heavy. Hatches one finish that changes how your pet's body catches the light.",per="1 finish per egg"},
   hue={line="Fruit that shifts colour",description="It smells like fruit. Hatches one colour fruit to feed your pet.",per="1 fruit per egg"},
   feature={line="Horns, claws or wings",description="Something pointy is growing in here. Hatches one feature item to grow on any pet.",per="1 item per egg"},
  },
 },
 style={
  promise={
   faceplates="Fixed prices. No random plates.",
   backgrounds="Backgrounds are earned, not bought.",
   balls="Just for looks. Never an advantage.",
  },
  balls={pitch="Same sizes, same rules. Only cuter."},
 },
 results={
  leave={
   wide="Back to the garden",
   mid="Leave to garden",
   narrow="Leave",
  },
  saved={done="Tucked into your wallet",pending="Saving…"},
  nudge={
   up="Brave? {heat} pays {low} to {high}",
   again="A win on {heat} pays {low} to {high}",
  },
 },
 shop={
  short={
   one="1 Star short. One more round?",
   many="{count} Stars short. One more round?",
   plain="{count} Stars short",
   plainOne="1 Star short",
  },
  reason={
   needStars="Not enough Stars",busy="Busy, try again",throttled="Try again in a moment",priceChanged="Price changed",
   unowned="Not owned yet",notOwned="Buy it first",retrying="Still saving…",
  },
  failed={bought="Not bought",applied="Not applied",saved="Not saved"},
 },
 items={note={empty="You have no items",full="Belt's full. Use one first."}},
 menu={subtitle={locked="Win a round and this opens up",empty="Round not started",paused="Round paused"}},
 -- Empty states (T12, wired by P3 with the pet peek).
 -- `solo` lines are the no-pet versions (fresh save).
 quests={allDone="All done. {pet} is impressed.",allDoneSolo="All done for today."},
 wardrobe={empty="Nothing to wear yet. {pet} doesn't mind.",emptySolo="Nothing to wear yet.",emptySlot="Nothing for this slot yet."},
 companions={wearing={none="Nothing yet"}},
 -- Play-forever F2: collection book, stamp card, restricted eggs.
 book={
  title="Collection book",eyebrow="Garden",
  entry={line="Pages to fill, Stars to find",claimOne="1 TO CLAIM",claimMany="{count} TO CLAIM"},
  records={name="Records",line="Your lifetime numbers",empty="Play a round and your records start here."},
  promise="Every page pays once. Nothing to buy.",
  claim="Claim ★{reward}",claimShort="★{reward}",claimed="Claimed",pending="Saving…",retrying="Still saving…",
  timeout="Still saving. Try again soon.",failed="Not claimed",
  owned="{owned}/{total}",
  found="Found",missing="Not yet",empty="Nothing on this page yet.",
  bookworm={line="Finish any three pages: Bookworm faceplate",short="3 full pages: Bookworm",done="Bookworm faceplate is yours",count="{count}/3"},
  toast={claimed="Page milestone",bookworm="Bookworm faceplate unlocked"},
  hint={pages="Pages",move="Move",claim="Claim",back="Back"},
  stats={rounds="Rounds played",winsEasy="Wins on Easy",winsMedium="Wins on Medium",winsHard="Wins on Hard",tidyWins="Tidy wins",
   merges="Merges",bestChain="Best chain",tierFive="Tier V balls",itemsUsed="Items used",pets="Pets hatched",
   starsEarned="Stars earned",starsSpent="Stars spent",stamps="Stamps collected"},
 },
 -- Pet Park K3: the park chip (shown only while the owner is inside the kerb).
 park={name="Pet Park",playDate="Play date {count}/{target}",done="+{reward} ★ today"},
 stamp={
  title="Stamp card",
  promise="No streaks. Miss a day, lose nothing.",
  next="Today's stamp: ★ {reward}",
  tomorrow="Next stamp tomorrow: ★ {reward}",
  full="Card full. A fresh one tomorrow.",
  button="Stamp today +{reward}",
  done="Stamped for today",
  landed="+{reward} Stars",
 },
}

local function freeze(node)
 for _,value in pairs(node)do if type(value)=="table"then freeze(value)end end
 return table.freeze(node)
end
UICopy.Table=freeze(Table)

local warned={}
local function lookup(key)
 local node=Table
 for part in string.gmatch(key,"[^%.]+")do
  if type(node)~="table"then return nil end
  node=node[part]
 end
 return if type(node)=="string"then node else nil
end
function UICopy.has(key)return lookup(key)~=nil end
-- The string at `key` with `{name}` filled from `vars`. A missing key returns the
-- key itself (and warns once) so a typo shows on screen instead of erroring.
function UICopy.get(key,vars)
 local text=lookup(key)
 if not text then
  if not warned[key]then warned[key]=true;warn("UICopy: missing key "..tostring(key))end
  return tostring(key)
 end
 if not vars then return text end
 local filled=string.gsub(text,"{(%w+)}",function(name)
  local value=vars[name]
  if value==nil then return nil end
  return tostring(value)
 end)
 return filled
end
-- The table under `key` (e.g. "hatch.egg"), for callers that hold a frozen copy table.
function UICopy.section(key)
 local node=Table
 for part in string.gmatch(key,"[^%.]+")do
  if type(node)~="table"then return nil end
  node=node[part]
 end
 return if type(node)=="table"then node else nil
end
-- Every leaf key, sorted (specs walk these).
function UICopy.keys()
 local out={}
 local function walk(node,prefix)
  for name,value in pairs(node)do
   local key=if prefix=="" then name else prefix.."."..name
   if type(value)=="table"then walk(value,key)else table.insert(out,key)end
  end
 end
 walk(Table,"")
 table.sort(out)
 return out
end
-- "N Stars short" lines for a shortfall, longest first (callers keep the first that
-- fits, e.g. Kit.fitText). Unknown or no shortfall: the plain server reason.
function UICopy.starsShort(count)
 if type(count)~="number"or count<=0 then return {UICopy.get("shop.reason.needStars")}end
 if count==1 then return {UICopy.get("shop.short.one"),UICopy.get("shop.short.plainOne")}end
 return {UICopy.get("shop.short.many",{count=count}),UICopy.get("shop.short.plain",{count=count})}
end

return UICopy
