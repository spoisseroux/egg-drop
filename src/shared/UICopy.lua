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
 care={notice={busy="Machine busy · keep carrying",dry="Find a clear dry patch",closer="Move closer to your pet or machine",changed="Your pet changed · try again",ended="Machine session ended",saving="Wait for your pet save",retry="Couldn't complete · try again"}},
 qa={coach={welcome="Merge balls. Hatch a friend.",sayHi="Say hi to {pet}"},shortfall="{count} more Stars needed",shortfallOne="{count} more Star needed",loading="Getting the preview ready…",retryPreview="Retry preview"},
 hatch={
  material={random="16 Stars · one unowned material. No duplicates.",fixed="16 Stars · one guaranteed material. No duplicates.",oddsPromise="No duplicates. Odds update with your collection.",nextPromise="No duplicates. Your next material is shown above."},
  display={charm="A charm for your pet",finish="A material for your pet",wait="A little surprise",line="The display wakes up",loading="Preparing your surprise…",material="Material for your pet",friend="New friend",firstFriend="Your first friend",owned="Already owned",refund="Already owned · {count} Stars back"},
  -- Full-screen item reveal (QA v685 H2): the rarity banner over the item's name.
  reveal={tier={Common="COMMON",Uncommon="UNCOMMON",Rare="RARE"},
   kind={toy="TOY",hue="COLOUR JAR",material="MATERIAL",feature="FEATURE",item="ITEM",finish="MATERIAL JAR",charm="CHARM",stat="STAT SNACK",name="NAME PIECE"},
   banner="{tier} {kind}",fresh="NEW {kind}",close="Close",
   -- QA R1 (2026-11-15): one fun line for every hatch result, shown under the name on the
   -- item reveal. 60 characters at most, in the garden's warm and quirky voice (the pets'
   -- lines are in PetCatalog). `other` covers an item that has no line of its own yet.
   describe={
    toy={ball="Round, bouncy, and never where you left it.",bone="Too good to bury. Carried everywhere instead.",
     sparkler="Fizzes like a tiny birthday. Every day is one now.",wobble_top="Spins, wobbles, never quite falls. A small miracle.",
     squeaky_carrot="Squeaks when squeezed. Does not taste like carrot.",pocket_deck="A tiny deck for tiny paws. High scores pending."},
    material={gloss="Shiny enough to check your hair in. Pets check often.",matte="Soft as chalk and twice as huggable.",
     jelly="See-through and wobbly. Do not eat, however tempting.",metal="Clinks politely. Surprisingly good at cuddles.",
     pearl_edge="A pearly shimmer, borrowed from a very kind oyster.",speckle_satin="Freckled like a robin's egg, smooth as a ribbon."},
    hue={rose="Pink as a cheek after a compliment.",tide="A jar of sea, caught on a calm day.",
     citrus="Sunshine, squeezed. Mind the pips.",iris="Dusk in a jar. Smells faintly of plums.",
     reset="Rinses a pet back to its very first colour."},
    feature={horns="Two small buds. Big plans.",claws="Tiny and fierce. Mostly used for back scratches.",
     wings="Folded neat as a letter. They flutter when excited."},
    -- Customization Egg (2026-11-16): material jars (finishJar keys) and the rare egg charms.
    finishJar={gloss="One shine closer to a mirror.",matte="A soft, chalky hush for any coat.",jelly="Wobbly, see-through, and very proud of it."},
    charm={dot="A tiny snowflake that never melts.",ring="A little ring that floats in its own orbit.",pebble="A lucky pebble, smoothed by a very old river."},
    other={toy="Something new to carry, chase and lose under things.",material="A fresh new coat. Your pet feels very fancy.",
     hue="A new colour, waiting for the right pet.",feature="Something new to grow. Give it a little time.",
     item="A little something for your garden."}}},
  footer={
   desktop="Give one a shake. The odds are on the label.",
   phone="The odds are on the label",
  },
  promise="No surprises. The odds never change.",
  -- Paid random items (LISTING.md section 7): shown under odds rounded to four significant digits.
  odds={rounded="Rounded, so the odds may not add up to exactly 100%."},
  -- Customization Egg (plan 2026-11-16 §5.2, §6). Its odds move as charms are collected.
  look={charmRow="Charm · {each} each: {shapes}",charmShort="Charm · {each} each",charmName="Charms",charmOwned="Yours to keep. It floats in your pet's Secondary colour.",missing="Charms are {each} each. Still to find: {shapes}.",
   pityShort="Charm within {count} eggs",allCharmsShort="All charms found",pity="A charm within {count} eggs",pityOne="Next egg: a charm",
   pityRule="If 14 eggs pass without a charm, the next one is a charm.",allCharms="All egg charms found",
   restrictedCharm="Charm in {count} eggs",notReady="Customization Eggs are not ready yet.",
   promise={random="The odds are on the label. They shift only as you collect charms.",fixed="No surprises. Your next item is shown above."},
   openSaved={charm="Open saved charm",finish="Open saved material"},
   wear="Wear it",wearOn="Wear on {pet}",worn="Wearing it",wearRetry="Try wearing it again",later="Later",useNow="Use now",
   jar={gloss="Gloss jar",matte="Matte jar",jelly="Jelly jar"},
   reason={PoolChanged="Your odds just changed. Check them and tap again.",PolicyChanged="Your odds just changed. Check them and tap again.",
    MaxSheen="This shine is as far as it goes.",MaxJelly="This pet is as jelly as it gets.",FinishChanged="This pet's material changed. Check it and tap again.",
    Locked="Find this charm first.",NotReady="Customization Eggs are not ready yet."}},
  -- v2 hatch result card (V2-HATCH-REDESIGN-2026-11-19 2.5, R1.1): the odds tray, Hatch
  -- another, the pity tray, the skip chip and the Rare stamp.
  result={inThisEgg="IN THIS EGG",youGot="YELLOW = YOU GOT",again="Hatch another",againPrice="Hatch another  ★ {count}",
   hatching="Hatching…",more="+{count} more",tapToSkip="Tap to skip",stamp={rare="RARE!"},
   need="{count} more Stars needed",soldOut="Back tomorrow",pouchFull="Pouch is full. Feed a snack first.",allToys="Every toy found",
   allFound="All collected",stockToys="{count} toys left to find",stockNest="{count} left in today's nest"},
  -- Restricted players (paid random items): the fixed next item instead of the odds.
  next={label="Next item",line="Next: {item}",done="All collected"},
  egg={
   toy={line="A toy to carry and chase",description="Something is rattling around in here. Hatches one toy your pet can carry and play with.",per="1 toy per egg"},
   material={line="A fresh new coat",description="Smooth and heavy. Hatches one material that changes how your pet's body catches the light.",per="1 material per egg"},
   hue={line="A jar of colour",description="Hatches one pigment jar to change your pet's colour.",per="1 jar per egg"},
   look={name="Customization Egg",line="Colours, materials and the odd charm",description="Hatches one jar of colour or material. Now and then, a rare charm.",per="1 item per egg"},
   feature={line="Horns, claws or wings",description="Something pointy is growing in here. Hatches one feature item to grow on any pet.",per="1 item per egg"},
   stat={name="Stat Egg",line="A snack that speeds up training",description="Hatches one Stat Snack. Feed it to your pet: the next XP it earns in that stat counts extra.",per="1 snack per egg"},
  },
  -- v2 Stat Eggs (V2-SCOPE 5, V2-PET-AND-SNACKS 2): the odds card, the button and the reveal.
  stat={
   each="Each stat",eachLabel="One of {count} stats, {each} each: {names}",
   size={nibble="Nibble · 2x 50 XP",snack="Snack · 2x 120 XP",feast="Feast · 3x 120 XP"},
   pity="A Feast within {count} eggs",pityOne="Next egg: a Feast",pityRule="If 7 eggs pass without a Feast, the 8th is a Feast.",
   next="Next: {stat} {size}",cycle="Sizes follow a ten-egg cycle: 6 Nibble, 3 Snack, 1 Feast.",
   promise={random="The odds are on the label. A Feast within 8 eggs.",fixed="No surprises. Your next snack is shown above."},
   hatch="★ Hatch {count}",free="Open free egg ({count})",soldOut="Back tomorrow",pouchFull="Pouch full · feed a snack",
   allMaxed="Every stat is at 99",notReady="Stat Eggs are not ready yet.",noPet="Hatch a pet first",
   today="{count} of {total} left in today's nest",freeLine="{count} free eggs to open",
   reveal={kind="STAT SNACK",name="{stat} {size}",boost="{mult}x for your next {count} XP",feed="Feed now",keep="Keep",kept="In your pouch"},
   reason={PoolChanged="Your odds just changed. Check them and tap again.",PouchFull="Your pouch is full. Feed a snack first.",SoldOut="Today's nest is empty. Back tomorrow.",
    NeedStars="You need more Stars.",NoFreeEgg="No free egg to open.",AllMaxed="Every stat is at 99.",PetNotOut="Bring your pet out first.",ClockRollback="One moment, then try again.",
    ExpiredDay="A new day just started. Tap again.",Busy="Finishing your last save…",Throttled="One moment…",Retrying="Still saving… your egg will show here.",Timeout="Still saving… your egg will show here.",Disabled="Stat Eggs are not ready yet."},
  },
 },
 style={
  promise={
   faceplates="Fixed prices. No random plates.",
   backgrounds="Backgrounds are earned, not bought.",
   balls="Just for looks. Never an advantage.",
  },
  balls={pitch="Same sizes, same rules. Only cuter."},
  -- Levels matter S3: the Effects tab (deck juice).
  effects={title="Effects",pop="Merge pop",trail="Drop trail",start="Start",classic="Classic",promise="Just for looks. Never an advantage.",locked="Needs {name} {level}"},
 },
 -- Beta 34 QA (Spencer): the Pocket Deck round HUD in words. `goal`: each field goal as a plain instruction, longest
 -- line first (GoalWords; {ball} is "a green ●" on the deck, "a green ball" in plain text). `chain`: what the chain
 -- does (each merge within 1.25 s of the last adds 10 points to it, BoardConfig.mergeScore). `quests`: the deck's
 -- button that opens the quest log.
 deck={
  goal={make="Make {ball} {where}",makeUp="Make {ball} or bigger {where}",match="Match two {small} {where}",
   merges="Make {count} merges {where}",chain="Make {count} quick merges in a row",
   short={make="{ball} {where}",match="Two {small} {where}",merges="{count} merges {where}",chain="{count} quick merges"},
   tiny={make="{ball} {where}",merges="{count} merges",chain="{count} in a row"},
   where={left="on the left",right="on the right",center="in the middle",any="anywhere"},
   whereTiny={left="left",right="right",center="middle",any="anywhere"},
   next="Next, {goal}",done="Done!"},
  chain={line="Quick merges in a row score more",short="Quick merges score more",tiny="Be quick: more points",
   toast="Chain ×{count}! Quick merges in a row score more"},
  quests={open="Open",button="Quests"},
  -- Deck juice P2 (AERO-JUICE-BRIEF 2, AeroJuice): the one praise word over the well on a chain of 5 and up (5, 6, 7,
  -- 8 and up). Original words; never a clock, a near miss or an upsell.
  praise={bubbly="Bubbly!",fizzy="Fizzy!",sparkly="Sparkly!",sky="Sky high!"},
  -- DECK-FEEL-BRIEF 6 (Alive deckfeel): the hint row while the Difficulty card is the control (▲▼ on keys and pads).
  level={hint="Level"},
  -- DECK-FEEL-BRIEF 8: the so-close line names what was reached, never what was lost; the new best's stamp.
  feel={toGo={one="1 goal to go",many="{count} goals to go"},best="New best!"},
 },
 results={
  inPlace={noStars="No Stars this round",total="Total  ★ {count}",metrics="Score {score} · Best {best} · Chain ×{chain}",replay="Replay",hatch="Hatch eggs"},
  leave={
   wide="Back to the garden",
   mid="Leave to garden",
   narrow="Leave",
  },
  saved={done="Tucked into your wallet",pending="Saving…"},
  -- Growth cuts (2026-11-25): the Welcome bonus payout row and the next-egg nudge under the Star.
  starter={row="Welcome bonus"},
  next={ready="{egg}: you have enough!",short="{egg}: {count} more Stars",shortOne="{egg}: 1 more Star"},
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
   needsLevel="Your pet needs a higher level first",
  },
  -- Levels matter S2: the chip on a locked item, and the way to train for it.
  needs={stat="Needs {name} {level}",total="Needs total level {count}"},train="Train {name}",
  failed={bought="Not bought",applied="Not applied",saved="Not saved"},
  -- QA Q2.4: an optimistic change the server refused, now put back.
  rolledBack="Didn't save, so it's back how it was",
 },
 items={note={empty="You have no items",full="Belt's full. Use one first."}},
 menu={subtitle={locked="Win a round and this opens up",empty="Round not started",paused="Round paused"}},
 -- QA Q5 machine hub: the Pocket menu outside rounds, one tile per machine.
 hub={quests={title="Quests"},
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
  -- QA 2026-11-14 U2: progress chips on the hub tiles and the "this week" shelf sticker.
  chip={quests="{done}/{total} today",stamp="Stamp {count}/{total}",book="{percent}% found",toys="{owned}/{total} toys",
   styles="{owned}/{total} styles",outfits="{owned}/{total} outfits"},
  week="This week",
 },
 pause={settings="Settings"},
 -- Empty states (T12, wired by P3 with the pet peek).
 -- `solo` lines are the no-pet versions (fresh save).
 quests={allDone="All done. {pet} is impressed.",allDoneSolo="All done for today."},
 wardrobe={empty="Nothing to wear yet. {pet} doesn't mind.",emptySolo="Nothing to wear yet.",emptySlot="Nothing for this slot yet."},
 companions={wearing={none="Nothing yet"},toys={name="Toys",line="Something to carry and chase"}},
 -- QA Q2.7: petting pays +1 Star, five times a day.
 -- G2 (FirstHelloBonus): the first paid pet on a new save, gold over the pet; {count} is the receipt's total.
 pet={star="+1 ★",hello="First hello! +{count} ★",capped="{pet}'s had plenty of pets today",cappedSolo="Plenty of pets today",
  -- The petting screen (ONBOARDING-V3-BRIEF section 4, switch pet2): the bottom hint, the favourite spot's line, Back's label.
  cuddle={rub="Rub {pet}!",loves="{pet} loves this!",back="Back",friend="your pet"},
  -- Beta (42) D13: the pet screen's name pill for a pet with no name yet.
  unnamed="Pet"},
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
  toast={claimed="Page milestone",bookworm="Bookworm faceplate unlocked",plate="{name} faceplate unlocked"},
  hint={pages="Pages",move="Move",claim="Claim",back="Back"},
  -- Levels matter S1: "where to find" on empty spots (Smarts 5).
  where={balls="In Deck style, under Balls.",faceplates="In Deck style, under Faceplates.",wardrobe="In Companions, under Wardrobe.",
   toy="Hatches from the Toy Egg.",finishJar="Hatches from the Customization Egg.",charmEgg="Hatches from the Customization Egg.",charmEarned="Earned by playing. Check its page.",
   pets="Say hello in Companions.",discoveries="Play a round and it will turn up."},
  stats={rounds="Rounds played",winsEasy="Wins on Easy",winsMedium="Wins on Medium",winsHard="Wins on Hard",tidyWins="Tidy wins",
   merges="Merges",bestChain="Best chain",tierFive="Tier V balls",itemsUsed="Items used",pets="Pets hatched",
   starsEarned="Stars earned",starsSpent="Stars spent",stamps="Stamps collected"},
 },
 -- Pet Park K3: the park chip (shown only while the owner is inside the kerb).
 -- Garden Dash (V3 slice S7). Short: most of it is read while running.
 dash={title="Garden Dash",prompt="Race",fun="Just for Fun",stats="Stats On",trial="Time Trial",jump="Jump",dash="Dash",stones="Take the stones",
  go="GO!",perfect="Perfect!",clear="Nice!",trip="Oops!",clover="Lucky clover!",zoom="Zoomies!",puff="Phew!",leave="Leave race",again="Race again",done="Done",
  hint={jump="Tap Jump now!",dash="Hold Dash!"},
  newCup="You won a cup!",gather="{name} · {count} of 8 · {left}",queue="You're in line. Tap to leave.",
  -- Beta 14 F2 (WORLD-AND-NEST-LOOK 5): leaving the line, by its rail line, the gate's prompt or the rope ring.
  line={title="Leave the line?",line="You'll lose your spot for the next race.",yes="Leave",no="Stay in line",left="You left the line.",prompt="Leave line"},
  gate={line="Your pet runs. Jump the hoops. Hold Dash to zoom!",modes="Just for Fun: all pets equal. Stats On: your pet's levels count."},
  ask={title="Leave the race?",line="Your pet runs on, but you won't get a ribbon.",yes="Leave",no="Keep racing"},
  ordinal={p1="1st",p2="2nd",p3="3rd",p4="4th",p5="5th",p6="6th",p7="7th",p8="8th"},
  medal={bronze="Bronze cup time!",silver="Silver cup time!",gold="Gold cup time!"},
  result={place="You finished {place}!",trial="{time} s!",noTime="Almost home!",time="Time {time} s",home="Almost home!",tryAgain="Try again for a cup!",best="Best {best} s",
   stars="+{reward} Stars ({done} of {total} today)"},
  reason={Far="Come closer to the gate",NoPet="Bring your pet with you",NoCharacter="Try again in a moment",Carried="Put your pet down first",Busy="Your pet is busy",
   Petting="Your pet is busy",Hatching="Finish hatching first",Saving="Saving. Try again soon",Queued="You're in line for the next race!",WrongBand="That race is for other levels. You're next!",
   Full="The line is full",Off="The race has stopped",Error="The race has stopped",Empty="The race has stopped",Deck="You left the race",Left="You left the race",
   PetChanged="You changed pets",AlreadySeated="You're already in",Throttled="One moment",StalePet="Try again in a moment",other="Can't race right now",
   -- The Play Den (PLAY-DEN-BUILD-PLAN): the meadow's hop found no race gathering; the den closed while you waited there.
   Missed="That race has started",Closed="The Play Den closed"},
  -- The Play Den: the meadow pad's prompt while the den is open (it only hops into a race that is gathering).
  join="Join race"},
 -- The Play Den (PLAY-DEN-BUILD-PLAN, step A): the sign over the cave mouth and the prompts' object names.
 den={name="The Play Den",board="Notice board",table="Pocket Deck"},
 -- Things to do (V3-THINGS-TO-DO-PLAN-2026-11-22): the Pocket menu tile, its page and the trail's marker.
 things={title="Things to do",new="New",play="Play",show="Show me",tile={line="Every game in the garden",short="Things"},
  deck={name="Pocket Deck",line="Play a round"},
  den={name="The Play Den",line="Games inside the cave"},
  dash={gather="Race: {count} of 8",live="A race is on",idle="Start a race",prizes="Stars races today: {done} of {total}"},
  finds={name="Garden finds",waiting="{count} finds waiting",one="1 find waiting",later="Come back later",done="All found today"}},
 -- Garden finds (V3-FINDS-BUILD-PLAN-2026-11-22): the trail's marker and the Smarts a find paid.
 finds={name="Garden find",gain="+{count} Smarts"},
 -- Onboarding v3 (ONBOARDING-V3-PLAN-2026-11-23 section 6): the need bubbles (Things to do top row), the station label
 -- tips, the Sleepy Nest, the See you tomorrow strip, the welcome-week card and the veterans' ticket. Whole sentences.
 onb3={
  -- Beta (12) QA O1 (Fable, GARDEN-LIFE-NEST-LOOK.md section 5): the egg naps, you come back, you hatch a gift. Never
  -- "ready", "growing" or "sleepy" for the same thing. {hours} is Nest.Hours, never typed.
  need={hi="Say hi to {pet}.",toy="{pet} wants a toy.",deck="{pet} wants to watch you play.",nest="Tuck in {pet}'s egg.",
   park="{pet} wants to meet friends.",egg="{pet}'s egg is ready to hatch!"},
  tip={hatch="{pet} found the egg machine!",style="Dress up your Pocket Deck here.",companions="Care for {pet} here.",
   park="Pets play together in here.",nest="{pet}'s egg is napping. Hatch it later for a gift."},
  nest={title="Napping egg",sign="{pet}'s egg",signPlain="Your egg",how="{pet}'s egg naps for {hours} hours. Come back to hatch a gift.",
   howPlain="This egg naps for {hours} hours. Come back to hatch a gift.",
   inside="Inside: {item} and {stars} Stars.",insideStars="Inside: {stars} Stars.",
   -- The gift chain (Onboard "gifts", GIFT-ART-BRIEF 4): the gift's name waits for the hatch; the Peek's pill.
   insideKind="Inside: {kind} and {stars} Stars.",kind={hat="a hat",neck="a neck piece",toy="a toy",charm="a charm"},sweet="Sweet dreams!",
   hours="Hatches in {hours} h",tomorrow="Hatches tomorrow",minutes="Hatches in {minutes} min",ready="Hatch me!",tuck="Tuck in",hatch="Hatch",
   tuckedFirst="Tucked in! Come back in {hours} hours to hatch a gift.",
   tucked="Sleep tight. It naps while you're away.",next="A new egg is napping. Come back in {hours} hours.",count="Egg {count} of 7",
   chipHours="Egg {hours} h",chipMinutes="Egg {minutes} min",chipReady="Hatch egg!",got="{item} from the napping egg!",
   pinReady="Hatch!", -- beta 14 Q1: the Show me pin over a ready egg
   -- The egg corner (EGG-CORNER-LOOK 3): Peek (the nest prompt while it naps), the "?" disc's label, and the "?" card.
   peek="Peek",helpAsk="What is this?",
   help={title="Napping egg",what="Your pet's egg is asleep in the nest.",time="It naps for {hours} hours, even when you're not playing.",
    gift="When it wakes up, come back and hatch it for a gift.",free="It's always free. You never need Stars for it.",
    next="Hatch it, and a new egg starts its nap.",wait="Naps can't be hurried. Go play, it will be here.",button="Got it"}},
  -- QA-R2-LOOK 5 (Spencer R2.6): "Coming up", a live status of what is on its way. Whole, short and tiny forms; the
  -- bare numbers ("+25", "2") are never sent for translation. {hours} and {minutes} are the egg's or the day's clock.
  strip={title="Coming up",wait="Miss a day, lose nothing.",
   eggHM="Egg in {hours} h {minutes} m",eggH="Egg in {hours} h",eggM="Egg in {minutes} min",eggSoon="Egg in under 1 min",eggReady="Egg ready!",
   stampReady="Stamp {count} ready: +{stars}",stampNext="Next stamp: +{stars}",stampIn="Stamp {count} in {hours} h",
   stampInHM="Stamp {count} in {hours} h {minutes} m",stampInM="Stamp {count} in {minutes} min",
   questsLeft="{left} quests to go",questsOne="1 quest to go",questsDone="Quests done!",questsIn="New quests in {hours} h",
   questsInHM="New quests in {hours} h {minutes} m",questsInM="New quests in {minutes} min",questsReady="{count} ready to claim",
   short={hm="{hours} h {minutes} m",h="{hours} h",m="{minutes} min",soon="<1 min",ready="Ready!",left="{left} left",done="Done!"},
   tiny={hm="{hours}h {minutes}m",h="{hours}h",m="{minutes}m",soon="<1m",ready="Ready!",done="Done"},
   go={nest="Go to the nest",stamp="Open the stamp card",quests="Open quests"}},
  week={title="Welcome week done!",line="{pet} loves the garden. A new egg naps in the nest after every hatch."},
  new={title="New in the garden",line="{pet} has a nest now."},
  charm={name="Nest Charm"},
  notify="{pet}'s egg is ready to hatch!",notifyPlain="Your egg is ready to hatch!",
 },
 park={waitIdle="Pets are playing",count="Pets playing {count}/{capacity}",full="Park full · {count}/{capacity}",otherHasRoom="The other park has room",games="Games {count}/{target}",playing="Playing · {count}/{target}",saving="Saving · {count}/{target}",name="Pet Park",playDate="Play date {count}/{target}",done="+{reward} ★ today",
  -- Beta (17) U1 (CAPSULE-AND-HUD-LOOK 2): the rail's play date ticket, with the Things page's name. 3 is the day's
  -- target, not a limit. The phone line (a top bar under 600 px) is park.playDate.
  date={games="Play date {count}/{target} · +{reward} ★",playing="Play date {count}/{target} · playing",
   saving="Play date {count}/{target} · saving",done="Play date done · +{reward} ★"},
  throw="Throw",ballOut="Ball is out",fetching="They’re on it.",fetchWait="Give them a moment.",fetchUnavailable="The ball needs a clear lane."},
 -- Remaining Welcome board and optional first-spend route. Catalogs own prices/odds.
 onboarding={
  welcome={friend="Hatch a friend",match="Merge",more="One more!",skip="Skip tutorial",saving="Saving…",static="↓",gamepad="D-pad · A",keyboard="← → · SPACE",egg="Mystery egg"},
  crack={tap="Tap the egg!",click="Click the egg!",pad="Press A!"}, -- the First Hatch (Onboard "crack"), by last input
  spend={hatch="Hatch eggs",give="Give to {pet}",store="Store",ready="A toy for {pet}",line="Choose a Toy Egg when you're ready."},
 },
 -- Onboarding v2 (artifacts/qa-2026-11-26-beta35/ONBOARDING-V2.md): one instruction a step, 16 characters or fewer,
 -- never a key name (a phone shows a hand, a computer the words, a gamepad the button picture).
 onb2={
  deck={drop="Drop a ball!",match="Match two!",two="2 more!",one="1 more!",hatching="It's hatching!",click="Click to drop",
   -- Onboarding v3 section 5 (Onboard "deck2"): the punch word over the well on combos 1 and 2 (combo 3 says
   -- `hatching`), and the big sun-gold numeral over "2 more!" / "1 more!".
   nice="Nice!",close="So close!",numTwo="2",numOne="1",
   -- The onboarding fun pass (deck2): the egg's own words after combos 1 and 2, in place of `two` / `one`.
   moved="It moved!",cracking="It's cracking!"},
  stork={delivery="A delivery!",skip="Skip"},
  crack={tap="Tap the egg!",click="Click the egg!",pad="Crack it!"},
  card={meet="Meet {pet}"},
  guide={pet="Pet {pet}!",nest="Tuck the egg in!",deck="Play for Stars!",allSet="You're all set!",deckIcon="Deck",ballIcon="Ball",eggsIcon="Eggs"},
  replay="Watch the first hatch again",
 },
 -- Onboarding v3 brief section 1 (Onboard "lead", qa-2026-11-27-beta37/ONBOARDING-V3-BRIEF.md): two lines, a headline
 -- of 16 characters or fewer and a sub-line of 28 or fewer; the post-tuck toast. The onboarding fun pass: the headlines
 -- are the pet's own voice (it asks, we do not order); thisWay is the nudge's word over "This way!". Beta (40): the
 -- tuck's sub-line and the toast count down to the hatch ({hours} / {minutes}: PetLead.hatchWords), never "tomorrow".
 onbLead={pet="Pet me!",follow="This way!",followSub="A new egg is waiting",tuck="Tuck it in!",tuckSub="It hatches in {hours} h",
  tuckSubMin="It hatches in {minutes} min",
  deck="Let's win Stars!",deckSub="Stars turn the crank!",thisWay="Come on!",toast="Sweet dreams! It hatches in {hours} h.",
  toastMin="Sweet dreams! It hatches in {minutes} min."},
 -- The gift chain (ONBOARDING-FUN-PASS section 2, Onboard "gifts"): the pet asks (its own voice), a headline of 16
 -- characters or fewer and a sub-line of 28 or fewer; the gift card, the Things row and the parked lines.
 onbGift={
  -- Beta 42 note 2: the sub-line says where to go ("it says free egg above the bear, but not go to the egg machine").
  paint="A gift for you!",paintSub="Free egg at the machine!",toy="A toy for me?",toySub="Toy Egg at the machine!",
  snack="A snack for me?",snackSub="Snack Egg at the machine!",pull="You can hatch one!",pullSub="Turn the crank",
  park="Let's go play!",parkSub="The Pet Park is open",dash="Race time!",dashSub="Try the Garden Dash",
  nest="It's hatching!",nestSub="Come and see",waiting="Gift waiting!",waitingSub="At the egg machine",
  -- Onboarding part 2 (ONBOARDING-P2-BRIEF 1): at the machine the bubble says tap it (the shop opens on the free egg);
  -- "Turn it!" is gone with the chip. freeEgg is the machine's prompt too while a gift waits.
  atMachine="Tap the machine!",atMachineSub="Your free egg is inside",nudge="For you!",throw="Throw it!",
  fetch="{pet} learned Fetch!",fetchSub="Throw the ball any time",
  freeEgg="Free egg!",wipe="{pet} is {colour}!",
  card={title="A gift for you!",from="A gift from {pet}!",paint="Paint {pet}!",play="Play!",later="Later",keep="Keep it",
   pot="{name} paint pot",potOdds="Each colour: 1 in 4",toyOdds="Each toy you don't have: 1 in {count}",deeper="Deeper {name}!",
   free="Free",snack="A snack for the racer!"},
  row={name="Gift waiting",line="A free egg at the egg machine",lineSnack="A free Snack Egg at the machine"},
  -- The Hatch eggs screen in gift mode (ONBOARDING-P2-BRIEF 1, step 4): the tile's sticker, the pane's price, its button
  -- and its promise line.
  shop={free="FREE",price="Free",hatch="Hatch free!",from="A gift from {pet}!"},
  busy="Try again in a moment.",room="Make room in the pouch first.",bring="Bring {pet} out first.",
 },
 -- Onboarding part 2 (ONBOARDING-P2-BRIEF 2, Onboard "teach"): the pointer's labels on the real buttons, a few words
 -- each. Keyboard and gamepad add their key or glyph after the words (TeachPointer).
 teach={dress="Dress up!",paint="Tap Paint!",deck="Play!",menu="Open the Menu!",things="All the games!",throw="Throw it!",go="Go!",
  -- Teach more (qa-2026-11-27-beta42/TEACH-MORE-BRIEF): the first field round's tour (DeckTour, with "{n}/{of}"), its tips,
  -- the round-two quests pointer, the colour reset, the snack, stats and wardrobe lessons and Settings > Skip the tips.
  tour1="Tick these to win!",tour2="Your balls. Use them well!",level="Tap to change level!",levelSub="Harder pays more ★",
  tipNext="This one's next!",tipChain="Chain! Quick merges score more",tipGoal="One down! Tick them all to win",
  quests="Quests pay extra ★",more="One more thing!",reset="Change your mind? It's free!",snack="Snack time!",feed="Feed {pet}!",
  stats="See {pet} grow!",outfits="Outfits!",skipAll="Skip the tips",count="{n}/{of}",
  skipTitle="No more tips?",skipLine="You can still find everything in the Menu.",skipYes="Skip the tips",skipDone="Tips are off"},
 -- Section 3 (Onboard "allset2"): the celebration card.
 -- gift: the one-time welcome gift's pill under the stamps, its Stars landing one by one up to 5 (shown only once the
 -- server paid it); giftSub replaces `sub` with it. hatch: the button when the Stars cover the cheapest egg (the fun pass).
 onbAllSet={title="You're all set!",pet="Pet",nest="Nest",stars="Stars",sub="{pet} loves it here.",next="What's next?",gift="+{count} ★ Welcome gift!",
  giftSub="A welcome gift from {pet}.",hatch="Hatch one!"},
 -- v1 track A onboarding: coach cards (CoachCards.lua), each shown once ever (coachMask).
 -- A title of three words or fewer and one short line; the game assumes merge-game players.
 coach={effortPay="Good effort",
  skip="Skip",gotIt="Got it",next="Next",
  welcome={title="Hatch your first friend",line="Merge to crack the egg. Stars come with it."},
  firstStars={toast="First round cleared"},
  -- Growth cuts (2026-11-25): with GardenTourCut, the one garden line that replaces the four tour cards.
  sayHi={touch="Tap {pet} to say hi",key="Press E near {pet} to say hi",pad="Press X near {pet} to say hi"},
  -- G2 (RoundTwoNudge): the round-two pill after the first toy; {count} is StarterBonus's first bonus, never typed in.
  roundTwo={bonus="Round two: ★ {count} Welcome bonus",toy="Round two: hatch a toy for {pet}",plain="Play round two on your Pocket Deck"},
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
 -- Growth cuts (2026-11-25): the TOMORROW strip on the results screen and its garden rail line.
 tomorrow={label="TOMORROW",stamp="Stamp {count}  ★ {reward}",stampPet="Stamp 7  {pet} + ★ {reward}",stampToday="Today's stamp  ★ {reward}",
  quests="{count} new quests",claim="{count} to claim",claimOne="1 to claim",statEggs="{count} Stat Eggs",
  rail="Tomorrow: Stamp {count} ★ {reward} · {quests} new quests",railToday="Today's stamp is waiting  ★ {reward}"},
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
    a={title="Earn Stars",line="Rounds and quests earn Stars. Open Quests for your once-daily stamp."},
    b={title="Pick an egg",line="Each egg hatches one kind of thing. The odds are on the label."},
    c={title="Hatch it",line="Press Hatch and watch it crack. What comes out is yours to keep."}},
   style={title="Deck style",
    a={title="Faceplates",line="Dress up your Pocket Deck. Fixed prices, no random plates."},
    b={title="Backgrounds",line="Earned by playing, never bought. Pick the one behind your deck."},
    c={title="Balls",line="New looks for the balls. Same sizes, same rules. Only cuter."}},
   companions={title="Companions",
    a={title="Bond hearts",line="Hearts show bond. Petting, rounds and Play dates grow it. Level up to unlock tricks."},
    b={title="Wardrobe",line="Hats and bits to wear, bought with Stars. Looks only."},
    c={title="Customize",line="Use colour jars, add a charm or hand over a toy."},
    d={title="Hatch eggs",line="Toys and colour jars hatch from eggs. Spend Stars at Hatch eggs."}},
   quests={title="Quests",
    a={title="Daily quests",line="Three a day. Play rounds to fill the bars, then claim the Stars."},
    b={title="Stamp card",line="One stamp a day, just for stopping by. Each stamp pays Stars."},
    c={title="A full card",line="Stamp seven pays ★ 12, then a fresh card starts. Miss a day, lose nothing."}},
   -- QA v735 H5: the first-session tour (CoachCards opens it once, in the garden; Show
   -- tips again replays it). Not a machine, so it has no ? and is not in HowItWorks.Order.
   garden={title="Your garden",
    a={title="Machines",line="Walk up to a glowing machine to use it, or tap Menu to open any of them from anywhere."},
    -- QA v775: how to say hi (it was an always-on hint in the garden). One line per input.
    e={title="Say hi to your pet",line="Walk up to your pet and press E to say hi, then hold E to pet it.",
     linePad="Walk up to your pet and press X to say hi, then hold X to pet it.",lineTouch="Tap your pet to say hi, then rub to pet it."},
    b={title="Quests and dailies",line="Open the Menu and pick Quests. Three daily quests and a once-a-day stamp pay Stars."},
    c={title="Customize",line="Open Companions to recolour and dress your pet. New pieces hatch from eggs."},
    f={title="Things to do",line="Find every game in Things to do."}},
   book={title="Collection book",
    a={title="Collect",line="Every ball, plate, outfit and toy you own gets a spot in the book."},
    b={title="Milestones",line="Fill a page to 25, 50, 75 and 100% to claim Stars. Each pays once."},
    c={title="Records",line="Your best rounds and big totals, kept for good."}},
   park={title="Pet Park",
    a={title="Play dates",line="Bring your pet in to play. Three play dates a day pay Stars."},
    b={title="Busy park",line="When every spot is taken, pets mingle and wait their turn."}},
   -- Listed only while the race is on; card d only while its prizes are.
   dash={title="Garden Dash",
    a={title="Run",line="Your pet runs. You help."},
    b={title="Jump",line="Tap Jump at each hoop."},
    c={title="Dash",line="Hold Dash to zoom. Let go to rest."},
    d={title="Stars",line="Two Stars a race, five races a day."}},
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
   -- machine: the egg corner's prompt names the machine; its action is `name` (beta 16 B2: "Turn" said nothing).
   Eggs={name="Hatch eggs",line="Spend Stars on new eggs",machine="Egg machine"},
   -- Beta 14 D1 (Fable R2): the onboarding v3 places only. The egg corner retired the nest's line (EggsNest).
   EggsV3={name="Hatch eggs",line="Toys, looks and snacks for your pet"},
   Customize={name="Deck style",line="Faceplates, backgrounds and balls"},
   Journal={name="Companions",line="Dress up and care for your pets"},
   Park={name="Pet Park",line="Pets play here. Play dates pay Stars"},
   Dash={name="Garden Dash",line="Race your pet. It's free!"},
  },
 },
 -- QA v2 track R4 (Wardrobe, Customize, Deck style content). `equipped` / `inUse`: the
 -- worn / used card keeps its button, disabled (R3.5). Wardrobe None cards (R4.2),
 -- the free Original colour card (R4.4) and the "More from eggs" lines (R4.5).
 r4={
  equipped="Equipped",inUse="In use",
  wardrobe={none="None",takeOff="Take off",noneNote="Nothing in this slot",slot="Slot",buyOrWear="Buy or wear"},
  hue={original="Original colour",white="White",free="Free",currentChip="CURRENT",current="Current colour",reset="Reset colour",
   confirmReset="Confirm reset",confirmLine="Press again to reset. It's free.",
   originalMain="{pet}'s first Main colour. Free, any time.",originalSecondary="{pet}'s first Secondary colour. Free, any time."},
  customize={newBadge="NEW",moreMaterials="More materials hatch from Customization Eggs.",moreToys="More toys hatch from Toy Eggs.",
   moreFinishes="More material jars hatch from Customization Eggs.",moreHues="More colour jars hatch from Customization Eggs.",
   -- UI-SPEC-v816 3: Toys are their own Companions screen; Customize keeps Hue, Charm and Material.
   toys={title="Toys",row="Pick a toy and watch your pet play",playing="Playing with {pet}",give="Give to {pet}",owned="{count} OWNED"},
   subtitle="Hue, charm and material",
   -- The Material tab (was Finish; UI-SPEC-v816 2): a read-only Shine / Jelly meter, jar cards
   -- with Use / Max / ×0 pills, the egg link and one Back to original. Keys keep "finish".
   finish={title="Material",look="Look: {look}",original="Original",sheenAxis="Shine",jellyAxis="Jelly",shine="Shine",
    stop="{item} {count}/{total}",jellyCount="{count}/{total}",helper="Use Gloss jars to add shine, Matte jars to soften.",
    pill={use="Use",max="Max",none="×0"},eggLink="Find jars in the Customization Egg ›",noJars="No {item} jars",reset="Back to original",
    already="Already original",clearLine="Back to original from {look}. Free.",empty="Find material jars in the Customization Egg.",
    kept="Kept: {finish}",useJar="Use a {item} jar",maxSheen="This shine is as far as it goes.",maxJelly="This pet is as jelly as it gets.",
    mix="{jelly} {sheen}",jar={gloss="Gloss",matte="Matte",jelly="Jelly"},
    sheen={m3="Chalky",m2="Matte",m1="Soft",zero="Original",p1="Satin",p2="Glossy",p3="Glassy"},
    jelly={s1="Misty",s2="Jelly",s3="Clear Jelly"}}},
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
  -- Beta 37: "This week" now names the weekly full-price pick (ThisWeek); the 20%-off shelf is the Deal.
  chip="Deal −20%",chipShort="−20%",
  line="Deal: {item}",short="20% off",
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
   -- Customization Egg (plan 2026-11-16 §5.4): Snowflake, Ring and Pebble are rare egg drops.
   dot={rule="Rare in the Customization Egg"},
   ring={rule="Rare in the Customization Egg"},
   pebble={rule="Rare in the Customization Egg"},
   egg={rule="Rare in the Customization Egg"},
   findInEggs="Find in eggs",
   none="No charm yet. Charms are rare in the Customization Egg, or earned.",
  },
 },
 bond={
  -- Lane U (F-cli): bond pips, the level-up toast and the trick names (levels 1-10).
  title="Bond",level="Bond level {count}",short="Lv {count}",max="Lv {count} · more soon",
  levelUp="Bond level {count} · New trick: {name}",levelUpPlain="Bond level {count}",
  trick={l1="Hello",l2="Sit",l3="Wiggle dance",l4="Big stretch",l5="Happy hop",
   -- Follow-up 2026-11-14: levels 6-10 [PLACEHOLDER names].
   l6="Peekaboo",l7="Cosy stretch",l8="Sneezy wiggle",l9="Show-off",l10="Best friends"},
  -- The last level: nothing more is promised.
  top="Lv {count} · Best friends",
 },
 -- v2 S3: the pet stats panel (StatsPanel), the level-up line (StatToasts) and the
 -- results strip. Stat names and tier words are the StatCatalog ids in UICopy form.
 -- v2 pet names (V2-CUTE-ICONS-AND-NAMES-2026-11-20 2.6). The pieces themselves are proper names
 -- in NameCatalog, shown the same to every viewer (never in this table, never translated).
 names={
  title="Name your {pet}",eyebrow="Companions",open="Name",save="Save name",saving="Saving…",saved="Name saved",
  row="Pick name pieces for your pet",rowUnnamed="Not named yet",
  swap="Swap",clear="Clear",
  slots={empty="Pick a piece",optional="Optional",hint="One piece or two. No typing, ever."},
  tab={all="All",starter="Starter",egg="Names Egg",stat="Stats",book="Book"},
  shows={title="Shows",where="When you pet it\nOn its card and stats",own="Each pet has its own name."},
  footer={free="Renaming is free, any time.",account="A piece you unlock is yours for every pet."},
  lock={stat="{stat} {level}",total="TOTAL {count}",anyLevel="ANY STAT {level}",book="BOOK {count}",egg="NAMES EGG"},
  hint={stat="Reach {stat} {level} on any pet to unlock it.",total="Reach a total level of {count} on one pet to unlock it.",
   anyLevel="Reach level {level} in any stat to unlock it.",book="Claim {count} collection book rewards to unlock it.",
   egg="This one hatches from the Names Egg."},
  egg={key="Names Egg · {price} Stars",allShort="All pieces collected",title="Names Egg",line="One new name piece every time. Never a duplicate.",
   per="1 name piece per egg",each="Each piece left: 1 in {count}, {each}",next="Next: {piece}",nextValue="Next",
   order="Pieces come in a fixed order, shown before you buy.",fixedLine="No surprises. Your next piece is shown above.",
   randomLine="Every piece still to find is equally likely.",buy="Hatch for {price} Stars",hatching="Hatching…",retry="Still saving · tap to check",
   all="All name pieces collected",notReady="The Names Egg is not ready yet.",close="Close",left="{count} pieces left to find",
   again="Hatch another · {price}"},
  reveal={sticker="NEW NAME PIECE",line="Yours for every pet",use="Use it",done="Done",yours="Renaming is free, any time."},
  unlocked="New name piece: {piece}",
  reason={PoolChanged="The egg just changed. Check it and tap again.",AllOwned="All name pieces collected",NeedStars="Not enough Stars yet",
   NotOwned="Unlock that piece first",SamePiece="Pick two different pieces",Busy="One moment, then try again",Throttled="One moment, then try again",
   Retrying="Still saving. Try again in a moment.",Timeout="No answer yet. Try again.",default="Couldn't save. Try again."},
 },
 stats={
  title="{pet}'s stats",eyebrow="Companions",open="Stats",chip="Total {count}",row="Levels, Bonus XP and snacks",
  total="Total level",of="/ {total}",nextKeeper="{name} at {count}",topKeeper="Every stat at the top",
  toNext="{count} XP to {target}",max="Top level",bonus="BONUS",
  bonusLeft="2x bonus: {count} XP left today",bonusUsed="Today's 2x bonus is used. Back tomorrow.",
  footer="Levels never go down. Miss a day, lose nothing.",none="Hatch a pet to start its stats.",
  hint={browse="Browse",back="Back"},
  name={heart="Heart",power="Power",energy="Energy",jump="Jump",speed="Speed",smarts="Smarts"},
  tier={seedling="Seedling",sprout="Sprout",bloom="Bloom",fullBloom="Full Bloom",starbloom="Starbloom"},
  keeper="{name} Keeper",gardenStar="Garden Star",
  -- What trains each stat (V2-SCOPE 2.2).
  train={heart="Petting, pet focus, care stations and rounds with your pet beside you.",
   power="Merges and chains on the Pocket Deck. Every merge counts, win or lose.",
   energy="Finishing and winning rounds, goals met and tidy wins. Harder pays more.",
   jump="Pet Park games you start, the daily Play date and playing with friends' pets.",
   speed="Throw and fetch, and toy play in the garden.",
   smarts="Daily and weekly quests, the daily stamp and Collection book finds."},
  levelUp="{name} {count}",levelUpMore="{name} {count} +{target}",
  -- v2 Stat Snacks: the boost on a tile, the pouch and feeding (V2-FEEDING-RUNES 2 and 3).
  boost="{mult}x · {count} XP left",boostMore="{mult}x · {count} XP left · +{more}",
  snacks={open="Snacks",close="Close",title="Snack pouch",count="{count}/{total}",empty="No snacks yet. Hatch a Stat Egg.",feed="Feed",back="Stats",
   name="{stat} {size}",tile="{stat} {size}, {count}",card="{mult}x for your next {count} XP",cardBoost="{stat} has {mult}x · {left} XP left",
   drop="Let go to feed {pet}",tapHint="Tap a snack, then Feed.",eggs="Go to Hatch eggs",
   line="{name} boost: {mult}x for your next {count} XP",favourite="{pet}'s favourite!",
   size={nibble="Nibble",snack="Snack",feast="Feast"},
   reason={InRound="{pet} can't eat during a round",PetBusy="{pet} is busy playing",PetNotOut="Bring {pet} out first",QueueFull="{stat} is already full of boosts",
    StatMaxed="{stat} is at the top",NoSnack="That snack is gone",RevealPending="Open your egg first",Throttled="One bite at a time",Busy="One moment…",
    Timeout="Still saving… check your pouch in a moment.",UnknownSnack="This snack is from a newer update",Retrying="Still saving… check your pouch in a moment.",other="Couldn't feed right now"}},
  results={label="Stats",gain="{name} +{count}",up="{name} +{count} (Lv {target}!)"},
  -- Levels matter S1: the next reward line, the guide, and each reward's words (StatRewards).
  next={free="Next at {level}: {name} · free",gate="Next at {level}: {name} · shop",short="At {level}: {name}",top="Top level"},
  guide={title="{name} guide",open="All {name} rewards",earned="Got it",at="Level {level}",shop="Go to shop",jobs="Also good for",none="More rewards soon"},
  levelUpReward="{name} {count} · {reward}",
  reward={item="{name}",name="Name piece: {name}",trick="New trick: {name}",
   swingCheer="A wave on the swing",swingHigh="Swings higher",slideSpin="A spin on the slide",seesawHop="A hop on the see-saw",
   longThrow="Longer throw in the park",catchHop="A happy catch hop",bookHints="Where-to-find hints in the Book",
   confetti="Confetti merge pop",fizz="Fizz merge pop",bubble="Bubble drop trail",comet="Comet drop trail",
   ready="Ready, steady start",lightning="Lightning lid start"},
 },
 -- Levels matter S4: stat medals and the free Stat Egg each one brings.
 medal={sprout="Sprout medal",bloom="Bloom medal",fullBloom="Full Bloom medal",starbloom="Starbloom medal",
  earned="{name} medal! A free Stat Egg is yours.",eggOne="1 medal egg is waiting.",eggs="{count} medal eggs are waiting."},
 -- QA v685 R10: the daily stamp chip on the Hatch eggs header (a counter; opens Quests).
 stampChip={done="✓ {count}/{total}",open="{count}/{total}",label="Daily stamp"},
 -- QA v685 R6: another player's pet, as a read-only profile card, and the reward-free
 -- hello. The name slot shows the species until Names ships (v2).
 inspect={
  prompt="Inspect",owner="{name}'s pet",bond="Bond level {count}",
  slot={charm="Charm",finish="Material",toy="Toy"},empty="Empty",hidden="Hidden",
  hello="Say hello",sent="Hello!",closer="Come closer",busy="Playing right now",off="Greetings off",wait="In a moment",
  gone="Pet moved on",close="Close",spin="Drag to turn",
  setting={on="Pet greetings: On",off="Pet greetings: Off"},
  -- ASMR-AND-SCALE-LOOK 2 "The setting": the one Vibration switch (beta only; hidden where the device cannot buzz).
  vibration={on="Vibration: On",off="Vibration: Off"},
  -- Toy Shell R1.1: Settings > Menu colours (menus follow the equipped deck, or Classic Shell).
  menuColours={deck="Menu colours: Match my deck",classic="Menu colours: Classic Shell"},
  -- v2 S4: the Stats tab (default) beside the Outfit grid, and Compare.
  tab={stats="Stats",outfit="Outfit"},compare="Compare",you="You {count}",marks="Marks",
  statsPrivate="Levels only. XP, Stars and history stay private.",statsNone="No stats to show yet.",
 },
 -- QA v735 H5: notice cards (NoticeCards.lua). A tap on a top-bar pill (a quest ticker or
 -- an onboarding line) opens one: what it means, what to do next, and one button that goes
 -- there. `pill` is the wording of the pills themselves.
 notice={
  label={what="What it means",next="What to do next"},
  go={quests="Open Quests",hatch="Open Hatch eggs",companions="Open Companions",menu="Open the Menu",show="Show me"},
  -- G2 (ToyPillCopy): firstToy replaces firstSpend while the switch is on; the old keys stay for off.
  pill={tip="Tip: {title}",firstSpend="Hatch your first egg",firstToy="Hatch a toy for {pet}"},
  welcome={title="Your first round",what="Drop balls into the deck. Two of the same kind merge into a bigger one.",
   next="Keep merging to crack the mystery egg. Your first friend hatches from it, with Stars."},
  firstStars={title="Your first Stars",what="Stars are the one wallet. Rounds, quests and the daily stamp all pay them.",
   next="Spend Stars on eggs at Hatch eggs. The Menu lists every machine."},
  locked={title="Not yet",what="The garden and its machines open once you have a pet.",
   next="Win this round to hatch your first friend."},
  machines={title="Machines",what="Each glowing machine in the garden does one job: Hatch eggs, Deck style, Companions and the Pocket Deck.",
   next="Walk up to a machine to use it, or open the Menu to jump to any of them."},
  hub={title="Pocket menu",what="The Menu lists every machine, with Quests, the Collection book and Settings.",
   next="Open it any time: tap Menu, press M, or press Y on a gamepad."},
  quest={title="Quests and dailies",what="Three daily quests, three weekly ones and a once-a-day stamp. They all pay Stars.",
   next="Open the Menu and pick Quests. Stamp the card each day and claim every finished quest."},
  customize={title="Customize your pet",what="Colour jars, charms, toys and outfits change how {pet} looks. Looks only.",
   next="Open Companions and pick Customize or Wardrobe. New pieces hatch from eggs."},
  fillLine={title="Fill line",what="Keep the pile under the line. Stay over it too long and the round ends.",
   next="Merge to make room, and drop each ball next to its match."},
  item={title="An item!",what="Power-up merges earn items. They wait for you on the item button.",
   next="Tap Items to use one when the pile gets tight."},
  questDone={title="Quest done!",what="You finished a quest. Its Stars are waiting to be claimed.",
   next="Open Quests and press Claim. Stars buy eggs at Hatch eggs."},
  questReady={title="Quest done!",what="{quest} is finished. It pays ★ {reward} when you claim it.",
   next="Open Quests and press Claim. Stars buy eggs at Hatch eggs."},
  questClaimed={title="Quest claimed",what="★ {reward} went into your wallet.",
   next="Spend Stars at Hatch eggs, or save up. New daily quests arrive every day."},
  firstSpend={title="Your first egg",what="You have enough Stars for an egg. A Toy Egg hatches a toy for {pet} to carry and play with.",
   next="Open Hatch eggs and choose the Toy Egg. The odds are on every label."},
  -- G2 (ToyPillCopy): the same card in the new words (its `next` is firstSpend.next, NoticeCards.ById.firstToy).
  firstToy={title="A toy for {pet}",what="You have enough Stars for a Toy Egg. It hatches a toy for {pet} to carry and play with."},
  -- Growth cuts (2026-11-25): the garden's Tomorrow line opens this (`next` is the stamp card's promise).
  tomorrow={title="See you tomorrow",what="A new stamp, three new quests and three Stat Eggs arrive every day.",
   next="No streaks. Miss a day, lose nothing."},
  bond={title="Bond grew",what="Hearts show how close you and {pet} are. Each new level unlocks a trick.",
   next="Keep petting, playing rounds and going on Play dates. The hearts are in Companions."},
  -- Things to do: the lines that lead to a game (ThingsTips).
  parkInvite={title="Pet Park",what="{pet} wants to play.",next="Tap Show me and follow the trail to the park."},
  dashIntro={title="Garden Dash",what="Race your pet. It's free!",next="Tap Show me and follow the trail to the race."},
  dashNew={title="New in the garden",what="Garden Dash is open.",next="Race your pet. It's free! Tap Show me to find it."},
  findsIntro={title="Something sparkles",what="Walk {pet} over to sniff it.",next="Tap Show me and follow the trail to it."},
 },
 -- Round 3 (Spencer 2026-11-20): the confirm dialog (ConfirmDialog) for big spends and actions
 -- that can't be undone; it replaces "press again" confirms.
 confirm={cancel="Cancel",yes="Confirm",
  adoptTitle="Adopt the {pet}?",adoptLine="The {pet} comes home with you for ★ {price}.",adoptYes="Adopt ★ {price}",
  buyTitle="Buy {item}?",buyLine="It's yours to keep for ★ {price}.",buyYes="Buy ★ {price}",
  restartTitle="Restart this round?",restartLine="The board starts over from the beginning.",restartYes="Restart",
  quitTitle="Quit to the garden?",quitLine="This round ends now.",quitYes="Quit",
  resetTitle="Reset the colours?",resetLine="Your pet goes back to its first colours. It's free.",resetYes="Reset"},
 -- Stars store access (Spencer 2026-11-21: "clicking the stars icon opens a store to buy stars?"):
 -- the header wallet opens the store; a short buy button opens this card.
 -- Get Stars page, Toy Shell restyle (Fable's brief, artifacts/stars-store-2026-11-21/).
 store={title="Get Stars",eyebrow="Garden",boosts="Boosts",packs="Stars packs",whatYouGet="What you get",
  buy="Buy · R$ {price}",owned="✓ Owned",ownedChip="✓ OWNED",forever="FOREVER",loading="Loading…",soon="Coming soon",opening="Opening…",
  best="BEST VALUE",free="You can always earn Stars free by playing.",thanks="Thank you! This boost is always on.",
  starsRow="Stars",walletAfter="Your wallet after",keepsWorking="Keeps working",foreverValue="Forever",
  sub={doubleStars="Double Stars, forever",supporter="+1 Star every round",starter="{stars} Stars · one per player",pack="{stars} Stars"},
  gets={doubleStars="Every round and quest",doubleStarsValue="2× Stars",supporter="Every finished round",supporterValue="+1 Star"},
  blurb={handful="A little top-up for one more egg.",pouch="Enough Stars for a few eggs.",jar="Lots of Stars for lots of eggs.",chest="The big one."},
  hints={buy="Buy"},banner={stars="+{count} Stars",pass="It's yours!"}},
 starsShort={title="You need ★ {count} more",titleOne="You need ★ 1 more",line="{item} is ★ {price}. Get Stars, or earn them on the Pocket Deck.",
  lineNoItem="Get Stars, or earn them on the Pocket Deck.",buy="Get Stars",earn="Play a round",wallet="Get Stars"},
 -- v2 Bunny (2026-11-19, Sol): adopting the second pet on the Companions Pets page. Free at the
 -- stamp count, or a fixed Star price (never random, never Robux).
 v2={
  adopt={status="ADOPT ★ {price}",line="Free at {need} stamps ({stamps}/{need}), or adopt now",
   button="Adopt for ★ {price}",confirm="Press again to adopt for ★ {price}",short="Needs ★ {price}",saving="Adopting…",
   done="{pet} came home with you!",retry="Still saving… try again in a moment.",failed="Couldn't adopt right now. No Stars were spent.",
   freeStatus="FREE",freeLine="{need} stamps: yours for free",free="Take home free"},
 },
}

-- Dash and Deck UI look (beta 12 QA, DASH-DECK-UI-LOOK section 10): new keys only, in their own block.
do
 local dash=Table.dash
 dash.sub={fun="All pets equal",stats="Your levels count",trial="Solo. Beat the clock"}
 dash.equal="All pets equal in this race"
 dash.band="{band} · Dash level {level}"
 dash.bestShort="Best {best} s"
 dash.label={time="Time",best="Best"}
 dash.result.newBest="New best"
 dash.result.starsShort="+{reward} Stars"
 dash.result.today="{done} of {total} today"
 dash.result.tomorrow="Stars again tomorrow"
 dash.result.saving="Saving…"
 dash.racing="Racing"
 dash.pad={dash="DASH",jump="JUMP",puff="PHEW!"} -- the HUD pads' words, in capitals as shown (so they localize as is)
 Table.results.inPlace.hatchShort="Hatch"
end
-- "This week" (ThisWeek, GARDEN-PLAY-BRIEF-2 section 8): the wardrobe's weekly pick. Full price, a stated cycle, no
-- countdown and no "last chance" (kids audience): the line says when it comes back, never when it goes.
Table.thisWeek={tab="This week",chip="This week",
 status="This week's pick. Back every {weeks} weeks.",statusShort="Back every {weeks} weeks"}
-- The fruit trees (GARDEN-B38-BRIEF 3b): the prompt at a fruit tree's trunk, and the Guide's one-time pointer to it.
Table.fruit={tree="Fruit tree",shake="Shake",guide="Shake the tree!"}

-- Paint, Shine, Dress (PAINT-SHINE-DRESS-PLAN, Fable's CUSTOMIZE-AUDIT): the Dress up door, its four tabs, paint pots and
-- the renames. Shown only while the Alive `paint` switch is on (PaintCopy maps today's keys onto these); the keys these
-- replace stay, because the switch-off path and live read them. No word from the audit's list (Hue, jar, dose, Main,
-- Secondary, Rose, Tide, Citrus, Iris, Chalky, Satin, Glassy, Misty, Customization) appears here (PaintCopy.spec).
Table.paint={door="Dress up",title="Dress up",eyebrow="Companions",
 tab={colour="Colour",shine="Shine",outfit="Outfit",charm="Charm"},
 target={main="Body",secondary="Tummy & ears"},
 pot={rose="Pink",tide="Blue",citrus="Yellow",iris="Purple"},
 potName="{colour} pot",
 mix={rose_tide="Violet",citrus_rose="Orange",iris_rose="Magenta",citrus_tide="Green",iris_tide="Indigo",citrus_iris="Coral"},
 status="{count}/5 · ×{stock}",statusMix="{count}/5",statusLocked="{count}/5 · Locked",
 paint="Paint",painting="Painting…",saving="Saving…",retry="Try again",
 -- Spencer, beta (38): pots come only from the Paint Egg (gacha). A swatch with no pot is locked: previewed, never sold.
 hatch="Hatch a Paint Egg",lockedChip="Locked",
 lockedLine="Win it from a Paint Egg.",lockedMix="Needs a {pot}. Win it from a Paint Egg.",
 line="{target} {count} of 5 → {next} of 5",
 lineMix="{colour} mixes {a} and {b}. Next: one {pot}.",
 full="Full",fullLine="{target} is as {colour} as it gets.",
 white="Back to white",whiteLine="Free, any time. {pet} goes back to white here. Pots used stay used.",
 whiteConfirm="Tap again: back to white",whiteConfirmLine="The paint here comes off. Pots used stay used.",
 whiteCurrent="White now",free="Free",current="Current",
 none="No pots yet. Win them from the Paint Egg.",
 reason={NotReady="Paint pots are not ready yet.",NeedStars="You need more Stars.",Throttled="One moment…",Busy="Finishing your last save…",
  RevealPending="Open your new item first.",PriceChanged="The price changed. Check it and tap again.",StackLimit="You have all the pots you can hold.",
  MeetPipFirst="Hatch a pet first.",OperationConflict="That was not saved. Try again.",Retrying="Still saving… your pot will show here.",
  RevisionChanged="Your pots changed. Check them and tap again.",InvalidPot="That was not saved. Try again.",
  NotSold="Pots come from the Paint Egg."},
 shop={looks="Looks",snacks="Snacks"},
 egg={look="Paint Egg",lookLine="Paint, shine and the odd charm",lookDescription="Hatches one paint pot or one shine. Now and then, a rare charm.",
  lookPer="1 item per egg",stat="Snack Egg",statDescription="Hatches one training snack. Feed it to your pet: the next XP it earns in that stat counts extra.",
  notReady="Paint Eggs are not ready yet.",statNotReady="Snack Eggs are not ready yet.",snacksEmpty="No snacks yet. Hatch a Snack Egg.",
  statEggs="{count} Snack Eggs",medal="{name} medal! A free Snack Egg is yours.",where="Hatches from the Paint Egg.",charm="Rare in the Paint Egg",
  charmNone="No charm yet. Charms are rare in the Paint Egg, or earned.",kindPot="PAINT POT",kindShine="SHINE",shineFor="Shine for your pet"},
 shine={title="Shine",clear="See-through",soft="Soft",normal="Normal",shiny="Shiny",clear1="A bit see-through",clear2="See-through",clear3="Clear",
  helper="Shiny and Soft move one step. See-through has three.",eggLink="Find more in the Paint Egg ›",empty="Find shine in the Paint Egg.",
  none="None yet",use="Use {item}",reset="Back to normal",already="Already normal",clearLine="Back to normal from {look}. Free.",
  max="As far as it goes.",more="More shine hatches from Paint Eggs.",openSaved="Open saved shine"},
 hub={line="Colour, shine, outfits and charms",tile="Pets, dress up and toys"},
 coach="Dress up {pet} and swap pets.",
 charmTip="Charms take {pet}'s tummy-and-ears colour.\nChange it on the Colour tab.",
 legacy="Your carried egg: choose its free pot once.",
 describe={tide="A pot of sea, caught on a calm day.",iris="Dusk in a pot. Smells faintly of plums."},
 charmOwned="Yours to keep. It floats in your pet's tummy-and-ears colour.",
 promise={hue="One pot, one step of colour. Back to white is free.",finish="One step of shine. Normal is free."},
 more={hues="Win more pots from the Paint Egg."},
 help={line="Paint, shine, outfits and charms, all behind Dress up.",title="Dress up"},
 notice={title="Dress up your pet",next="Tap Dress up on your pet. New pieces hatch from eggs.",what="Paint, charms, toys and outfits change how {pet} looks. Looks only."}}

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
-- Paint, Shine, Dress: the client installs one override (PaintCopy.install) that swaps a key for its `paint.*` key while
-- the switch is on. nil (the server, a spec, the switch off) is today's text, exactly.
local override=nil
function UICopy.setOverride(fn)override=if type(fn)=="function"then fn else nil end
function UICopy.get(key,vars)
 if override then local ok,alt=pcall(override,key);if ok and type(alt)=="string"and lookup(alt)~=nil then key=alt end end
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
