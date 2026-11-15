# Release gates audit

14 November 2026. Read-only review of PRE-PUBLISH-QA, current TODO launch sections, PLAY-BUILD and active source. No Studio, source, staging or publish actions. The packet covers the new feature QA well; these are concrete additions/clarifications, not new feature scope.

## Verdict after the packet expanded to30 items

Items27–30 now cover the device/performance/avatar/controller, human balance, multiplayer/load and listing gaps below. Three short coordinator-owned additions remain concrete:

1. **Launch namespace:** explicitly verify EggDropLaunchV1 is the intended empty/fresh launch namespace (or choose an agreed fresh one). The current flag-off sentence alone does not do this; ProgressStore.lua selects that fixed name and never erases its existing records.
2. **Published audio sweep:** explicitly include all reachable SFX/coos/ambience and Purr, not only the four hatch auditions/new music. Current Purr is80835586668229; TODO's17-SFX label is historical. Native load proof for new assets is not the full standalone-client sweep.
3. **Writer rollout:** explicitly replace/drain old gameplay servers for the coherent report/material/save deployment. This is the implementation review's old-server replacement requirement, not a new feature request.

Seven-offer live purchase/rejoin testing and matching fixed Dashboard/source prices can be named as clarification of the existing purchases gate; they need no new numbered human QA item. Current Supporter/Starter marketing is truthfully Stars-only. No missing cosmetic grant should be inferred from the historical TODO promise.

The remaining sections document the source facts and original suggested additions; items27–30 now address most of them.

## Before the next authorized private QA publish

- Finish the current music audition/choice, integrate only accepted replacements, rerun affected checks and preserve exact checkpoint evidence. Already covered by the packet; v3 is working music, not accepted final music.
- Add **published-writer rollout** explicitly: replace/drain old gameplay servers when deploying the coherent material/report/save writers. Do not mix old pool clients/writers with the new rollout. Preserve durable historical receipt/reservation recovery.
- Regenerate/review localization and sync the cloud table for that publish. Existing onboarding, reports, translations code and park implementation are complete; old “not built” TODO fragments are stale. Published report persistence and analytics ingestion remain service checks after publishing, not missing implementations.

## Add to private published QA, before public launch

1. **Physical iPhone AND Android, sustained performance:** first session through hatch, menus, active round, crowded garden, pickup/care and park. Record device/OS, touch/safe areas, readable text, sustained frame rate/heat and audio. Repeat at lowest graphics. Studio phone emulation and the earlier desktop seven-rig benchmark do not establish this.
2. **Avatar/input coverage:** R6 and R15, or explicitly confirm the launch avatar restriction; real gamepad first-session/menu/results/carry flow, not only directional fixtures. Keep unsupported platforms disabled until tested. The current packet touches gamepad but does not cover a complete controller journey.
3. **6–8-player load test:** both parks, simultaneous pair/fetch/carry/care contention, owner departure/rejoin and late join. Observe frame/network/server load and stuck reservations. Two accounts prove ownership boundaries; they do not replace this load test. Confirm the configured 12-player maximum separately.
4. **Human balance pass:** ordinary earning versus current egg/wardrobe/pack prices and Easy/Medium/Hard progression. Play all six active field templates, especially Ripple relay, Bank bounce and Mirror marks. Solver wins and reward arithmetic do not prove understandable/fun goals or a satisfactory earning pace.
5. **Live monetization/save acceptance:** authorized tests for both passes and all five products; correct prompt prices, grants, once-only Starter, cancellation/retry/rejoin and receipts. Confirm pass ownership and round/quest effects after reconnect. Existing packet mentions receipts generically; name all seven offers explicitly. No real spending without separate authorization.
6. **Full published audio inventory:** currently reachable board/menu/care/hatch cues, garden/Deck transitions, coos/ambience and Purr, including mute/focus/duck/seams. “17 SFX” is an old inventory label: current BoardAudio also maps placeholder and five native-hatch cues. Purr remains asset80835586668229. New music/SFX Studio loads do not prove every reachable asset loads for standalone clients.

## Public-launch decisions / setup

- **Listing and maturity:** choose/update icon, thumbnails, description and questionnaire in Creator Hub. The existing listing kit is a draft; old hatch/odds imagery and Toy34/33/33 or Material50/50 references must not become the current listing. Check intended audience/device/access/chat settings and actual publishing eligibility in Creator Hub; do not assume the historical “all ages” note completes current setup.
- **Launch save namespace:** TestFreshSaves is currently true. Set it false for public launch and verify the intended fresh namespace. ProgressStore then selects EggDropLaunchV1; switching the flag does not erase records already there. Confirm emptiness or choose an agreed fresh namespace, without an unauthorized destructive wipe.
- **Commercial promises:** current StoreCatalog advertises Stars only: 2× Stars299R$, Supporter99R$ (+1 per finished round), Starter49R$/40Stars, plus four repeatable Star packs. Current UI derives those blurbs; no shell/charm is promised there or granted by StoreService. The old TODO cosmetics promise is a backlog/product decision, not a current in-game sale defect. Reconcile the external dashboard/listing promise with the intended Stars-only launch; do not automatically add cosmetics. Managed Pricing was recorded off; confirm dashboard prices match fixed source prices and keep that mode unless deliberately changing its integration.
- **Paid random disclosure:** active Toy pool2 costs8Stars; Material pool4 costs16Stars with initial45/10/45 and updated remaining odds. Feature Egg is hidden; retired Companion eggs are not a launch hatch requirement. Policy unknown/restricted paths are fixed and disclosed; packs fail closed. Confirm this in published account-policy flows. Roblox requires numerical outcomes/odds for Robux-funded indirect random purchases: [official guidance](https://create.roblox.com/docs/production/monetization/paid-random-items). Use the [current publishing guidance](https://create.roblox.com/docs/production/publishing/publish-games-and-places) and actual Hub questionnaire rather than the dated draft answers.

Current flags: Park=true, DayNight=false (locked dusk), Features=false, SecondPet=false, WeeklyShelf=true, PseudoLocale=false. Preserve those intentional scope decisions unless changed explicitly. Blip is rejected/parked; Names Egg and visitor Hello remain optional scope decisions, not missing fixes. No new roster, cave, Stat Egg or retired-pet work belongs in this release gate.
