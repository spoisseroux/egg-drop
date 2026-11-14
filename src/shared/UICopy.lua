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
  -- QA Q5: the come-back strip's left cell (Stars earned from rounds today, no cap).
  today={label="TODAY",line="★ {count} earned",short="Today: ★ {count}"},
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
  -- QA Q2.4: an optimistic change the server refused, now put back.
  rolledBack="Didn't save, so it's back how it was",
 },
 items={note={empty="You have no items",full="Belt's full. Use one first."}},
 menu={subtitle={locked="Win a round and this opens up",empty="Round not started",paused="Round paused"}},
 -- QA Q5 machine hub: the Pocket menu outside rounds, one tile per machine.
 hub={
  title="Pocket menu",eyebrow="Garden",
  promise="Every machine, one tap away.",
  tile={
   hatch={name="Hatch eggs",line="Eggs, odds and today's stamp"},
   style={name="Deck style",line="Faceplates, backgrounds and balls",short="Style"},
   companions={name="Companions",line="Pets, wardrobe and customize"},
   quests={name="Quests",line="Daily and weekly quests"},
   book={short="Book"},
   settings={name="Settings",line="Sound, music and motion"},
  },
  status={stamp="STAMP READY",locked="LOCKED"},
 },
 pause={settings="Settings"},
 -- Empty states (T12, wired by P3 with the pet peek).
 -- `solo` lines are the no-pet versions (fresh save).
 quests={allDone="All done. {pet} is impressed.",allDoneSolo="All done for today."},
 wardrobe={empty="Nothing to wear yet. {pet} doesn't mind.",emptySolo="Nothing to wear yet.",emptySlot="Nothing for this slot yet."},
 companions={wearing={none="Nothing yet"}},
 -- QA Q2.7: petting pays +1 Star, five times a day.
 pet={star="+1 ★",capped="{pet}'s had plenty of pets today",cappedSolo="Plenty of pets today"},
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
 -- v1 track A onboarding: coach cards (CoachCards.lua), each shown once ever (coachMask).
 -- A title of three words or fewer and one short line; the game assumes merge-game players.
 coach={
  skip="Skip",gotIt="Got it",next="Next",
  welcome={title="Hatch your first friend",line="Merge to crack the egg. Stars come with it."},
  firstStars={toast="First round cleared"},
  machines={title="Machines",line="Walk up to a glowing machine to use it."},
  hub={title="Pocket menu",key="Press M for every machine, any time.",pad="Press Y for every machine, any time.",touch="Tap Menu for every machine, any time."},
  quest={title="Quests",line="Today's quests pay Stars. Find them in the menu."},
  fillLine={title="Fill line",line="Keep the pile under the line. Stay over it too long and the round ends.",short="Keep the pile under the line"},
  hatch={title="Hatch eggs",line="Spend Stars on eggs. The odds are on every label."},
  style={title="Deck style",line="Faceplates, backgrounds and balls. Looks only."},
  companions={title="Companions",line="Dress up {pet}, swap pets and customize."},
  quests={title="Quests",line="Three a day, three a week. Each one pays Stars."},
  book={title="Collection book",line="Fill the pages as you collect. Every page pays once."},
  park={title="Pet Park",line="{pet} plays here. Three play dates a day pay +4 ★."},
  item={title="An item!",line="Power-up merges earn items. Use one from the item button.",short="Item earned! Use it from Items"},
  questDone={title="Quest done!",line="Claim its Stars in Quests, in the menu."},
  missPay="Goal met",
 },
 -- v1 track B: Settings > "Report a bug / Suggest something" (BugReportSheet).
 -- No contact details, no links out; the note is filtered and only the team reads it.
 report={
  entry="Report a bug / Suggest something",entryShort="Report or suggest",
  title="Tell us",titleShort="Tell us",eyebrow="Settings",
  kind={bug="Bug",suggestion="Suggestion"},
  about="What's it about?",
  category={deck="Pocket Deck",garden="Garden",park="Pet Park",menus="Menus",pets="Pets",stars="Stars",other="Other"},
  note={placeholder="Tell us more (optional)",count="{count}/200",privacy="Don't include names or personal details."},
  send="Send",sending="Sending…",wait="Send again soon",
  pick="Pick what it's about",
  thanks={bug="Thanks! We'll take a look.",suggestion="Ooh, noted. Thank you!",queued="Thanks! It'll go out shortly."},
  reply={limited="That's plenty for now. Try again later.",full="Our mailbox is full today. Try tomorrow.",busy="Still sending the last one…",
   invalid="That didn't send. Try again.",timeout="No answer yet. Try again in a bit."},
 },
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
 -- QA v2 track R1 (reveal + first session). Welcome pill on the board (longest
 -- first; the pill keeps the first that fits the board), the Hatch eggs footer's
 -- confirm word (the rest of the footer is R2's input.action / input.legend), and the
 -- first Bear's exit button.
 r1={
  welcomePill={wide="Merge to hatch your first friend",mid="Hatch your first friend",narrow="Hatch a friend"},
  hatchHints={hatch="Hatch"},
  reveal={exit="Back"},
 },
 -- QA v2 track R6 (phone Pocket Deck): the caption under the phone B (the item
 -- button) reads Items in a round and Back in a menu.
 phoneDeck={b={items="Items",back="Back"}},
 -- QA v2 track R2 (input): the one control legend for menu footers. Footer chips come
 -- from HintGlyphs (client) per device: gamepad + / A / B / LB, keyboard WASD / ENTER /
 -- BKSP / Q/E, touch none (tap). `legend.<device>` is the line that explains them once
 -- (R1 Hatch eggs footer, R4 Wardrobe / Customize footers); `action.*` names each one.
 input={
  legend={
   gamepad="D-pad moves, A picks, B goes back, LB and RB switch tabs.",
   keyboard="Arrows or WASD move, Enter picks, Backspace goes back, Q and E switch tabs.",
   touch="Tap a card to pick it. The back arrow closes the screen.",
  },
  action={browse="Browse",confirm="Pick",back="Back",tab="Switch tab"},
 },
 -- QA v2 track R3 (menu shell). `help`: each machine's "How it works" cards
 -- (HowItWorks, the ? in every machine header), two or three cards of a title and one
 -- line. `quests`: the redesigned quest rows (what to do, status, the celebration)
 -- and the stamp card's new home on the daily tab.
 r3={
  help={
   button="How it works",eyebrow="How it works",
   done="Got it",close="Close",replay="Tap ? any time to see this again.",
   hatch={title="Hatch eggs",
    a={title="Earn Stars",line="Win rounds, finish quests and stamp your card. Stars pay for eggs."},
    b={title="Pick an egg",line="Each egg hatches one kind of thing. The odds are on the label."},
    c={title="Hatch it",line="Press Hatch and watch it crack. What comes out is yours to keep."}},
   style={title="Deck style",
    a={title="Faceplates",line="Dress up your Pocket Deck. Fixed prices, no random plates."},
    b={title="Backgrounds",line="Earned by playing, never bought. Pick the one behind your deck."},
    c={title="Balls",line="New looks for the balls. Same sizes, same rules. Only cuter."}},
   companions={title="Companions",
    a={title="Your pets",line="Everyone you hatch lives here. Visit them and swap who tags along."},
    b={title="Wardrobe",line="Hats and bits to wear, bought with Stars. Looks only."},
    c={title="Customize",line="Feed colour fruit, add a charm, try a finish or hand over a toy."}},
   quests={title="Quests",
    a={title="Daily quests",line="Three a day. Play rounds to fill the bars, then claim the Stars."},
    b={title="Stamp card",line="One stamp a day, just for stopping by. Each stamp pays Stars."},
    c={title="A full card",line="Stamp seven pays ★ 12, then a fresh card starts. Miss a day, lose nothing."}},
   book={title="Collection book",
    a={title="Collect",line="Every ball, plate, outfit and toy you own gets a spot in the book."},
    b={title="Milestones",line="Fill a page to 25, 50, 75 and 100% to claim Stars. Each pays once."},
    c={title="Records",line="Your best rounds and big totals, kept for good."}},
   park={title="Pet Park",
    a={title="Play dates",line="Bring your pet in to play. Three play dates a day pay Stars."},
    b={title="Busy park",line="When every spot is taken, pets mingle and wait their turn."}},
  },
  quests={
   eyebrow="Quests",
   status={notStarted="Not started",toGo="{count} to go",ready="Done! Claim it",claimed="Claimed"},
   claimed="Nice one! +{reward} Stars",
   stamp={title="Today's stamp",line="One stamp a day, just for stopping by.",lineDone="Come back tomorrow for the next one."},
   weekly={title="Weekly bonus",line="Clear all three this week for a bonus."},
   menu="Menu",
  },
  -- The machine hub's tile lines now that the stamp card lives in Quests.
  hub={hatchLine="Eggs and their odds",questsLine="Quests and the daily stamp"},
  tips="Show tips again",
 },
 -- QA v2 track R5 (world + garden): station marker labels. The first time a player walks
 -- up to a station the label reads name + line; after that the name only.
 r5={
  station={
   Eggs={name="Hatch eggs",line="Spend Stars on new eggs"},
   Customize={name="Deck style",line="Faceplates, backgrounds and balls"},
   Journal={name="Companions",line="Dress up and care for your pets"},
   Park={name="Pet Park",line="Pets play here. Play dates pay Stars"},
  },
 },
 -- QA v2 track R4 (Wardrobe, Customize, Deck style content). `equipped` / `inUse`: the
 -- worn / used card keeps its button, disabled (R3.5). Wardrobe None cards (R4.2),
 -- the free Original colour card (R4.4) and the "More from eggs" lines (R4.5).
 r4={
  equipped="Equipped",inUse="In use",
  wardrobe={none="None",takeOff="Take off",noneNote="Nothing in this slot",slot="Slot",buyOrWear="Buy or wear"},
  hue={original="Original colour",free="Free",currentChip="CURRENT",current="Current colour",reset="Reset colour",
   confirmReset="Confirm reset",confirmLine="Press again to reset. It's free.",
   originalMain="{pet}'s first Main colour. Free, any time.",originalSecondary="{pet}'s first Secondary colour. Free, any time."},
  customize={moreMaterials="More finishes hatch from Material Eggs.",moreToys="More toys hatch from Toy Eggs."},
 },
 -- Overnight 2026-11-14 (artifacts/overnight-2026-11-14/BUILD-PLAN.md): one block per slice; each lane
 -- writes only inside its own block. e2 = second pet (E), variants = recolours + new tabs (B),
 -- shelf = weekly shelf (C), pool3 = toys / charms / Discoveries (D), bond = bond levels (F).
 e2={
  -- Lane U (E-cli): the earned pet's arrival card (CoachCards, coach bit petArrived) and the
  -- stamp card's tease (StampCardView). All hidden while EarnedPets.enabled("blip") is false.
  arrived={title="A friend arrived!",line="{pet} came to stay in your garden.",sayHi="Say hi"},
  tease={many="Someone's on the way… {count} more stamps",one="Someone's on the way… 1 more stamp",short="Someone's on the way…"},
  hub={none="No companion yet. Play your first rounds to meet your Bear."},
 },
 variants={
  -- Lane U (B-cli): the Wardrobe's new slot tabs and the recolour line on a variant's pane.
  tab={eyewear="Eyewear",cheek="Cheek",wrist="Wrist",ankle="Ankle"},
  note="A new colour of {item}",
  slot={eyewear="Sits on the nose",cheek="A pair, one for each cheek",wrist="A pair, one for each wrist",ankle="A pair, one for each ankle"},
 },
 shelf={
  -- Lane U (C-cli): the weekly shelf chip (shops) and the machine hub line. No countdown.
  chip="This week −20%",chipShort="−20%",
  line="This week: {item}",short="20% off this week",
  status="On this week's shelf",
  deluxe="Deluxe",
 },
 pool3={
  -- Lane U (D-cli): earned charm shapes on the Customize Charm tab.
  charm={
   locked="Locked",earned="Earned",
   heart={rule="Finish the Wardrobe page in the book"},
   star={rule="Claim 4 weekly bonuses"},
   leaf={rule="Collect 14 daily stamps"},
   fallback={rule="Keep playing to earn this charm"},
  },
 },
 bond={
  -- Lane U (F-cli): bond pips, the level-up toast and the trick names (levels 1-5).
  title="Bond",level="Bond level {count}",short="Lv {count}",max="Lv {count} · more soon",
  levelUp="Bond level {count} · New trick: {name}",levelUpPlain="Bond level {count}",
  trick={l1="Hello",l2="Sit",l3="Wiggle dance",l4="Big stretch",l5="Happy hop"},
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

-- Pseudo-localization (v1 track C, text-fit check). UICopy.pseudo returns a string about
-- 35% longer (German / French / Portuguese run 20-35% over English) with accented
-- letters, inside [brackets] so a clipped end shows. `{name}` placeholders and rich
-- text <tags> are kept as they are. FeatureFlags.PseudoLocale turns it on for
-- UICopy.get in Studio only (a live server ignores the flag); scripts/LocalizationFit
-- applies UICopy.pseudo to every translatable label on screen instead.
UICopy.PseudoExpansion=.35
local accents={a="à",b="ƀ",c="ç",d="ð",e="é",f="ƒ",g="ĝ",h="ĥ",i="î",j="ĵ",k="ķ",l="ļ",m="ɱ",n="ñ",o="ö",p="þ",q="ǫ",r="ŕ",s="š",
 t="ţ",u="ü",v="ṽ",w="ŵ",x="ẋ",y="ý",z="ž",A="Å",B="Ɓ",C="Ç",D="Ð",E="É",F="Ƒ",G="Ĝ",H="Ĥ",I="Î",J="Ĵ",K="Ķ",L="Ļ",M="Ṁ",N="Ñ",
 O="Ö",P="Þ",Q="Ǫ",R="Ŕ",S="Š",T="Ţ",U="Ü",V="Ṽ",W="Ŵ",X="Ẋ",Y="Ý",Z="Ž"}
local filler={"ŵ","ö","ŕ","ð","š","é"}
function UICopy.pseudo(text)
 if type(text)~="string"or text==""then return text end
 local out,count,i,n={"["},0,1,#text
 while i<=n do
  local c=string.sub(text,i,i)
  local close=if c=="{"then string.find(text,"}",i,true)elseif c=="<"then string.find(text,">",i,true)else nil
  if close then
   table.insert(out,string.sub(text,i,close));i=close+1
  else
   local b=string.byte(text,i)
   local len=if b<0x80 then 1 elseif b<0xE0 then 2 elseif b<0xF0 then 3 else 4
   local ch=string.sub(text,i,i+len-1)
   table.insert(out,accents[ch]or ch);count+=1;i+=len
  end
 end
 -- The padding is its own short words, so wrapping labels can still break it.
 local extra=math.ceil(count*UICopy.PseudoExpansion)-2
 for k=1,extra do table.insert(out,if k%7==1 and k<extra then " "else filler[(k%#filler)+1])end
 table.insert(out,"]")
 return table.concat(out)
end
local pseudoOn=false
local function studio()
 local ok,result=pcall(function()return game:GetService("RunService"):IsStudio()end)
 return ok and result==true
end
do
 local ok,Flags=pcall(require,script.Parent.FeatureFlags)
 pseudoOn=ok and type(Flags)=="table"and Flags.PseudoLocale==true and studio()
end
-- Studio only: specs can turn the pseudo locale on and off for UICopy.get.
function UICopy.setPseudo(on)pseudoOn=on==true and studio()end
function UICopy.pseudoEnabled()return pseudoOn end

-- The string at `key` with `{name}` filled from `vars`. A missing key returns the
-- key itself (and warns once) so a typo shows on screen instead of erroring.
function UICopy.get(key,vars)
 local text=lookup(key)
 if not text then
  if not warned[key]then warned[key]=true;warn("UICopy: missing key "..tostring(key))end
  return tostring(key)
 end
 if pseudoOn then text=UICopy.pseudo(text)end
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
