# Immediate preference save checkpoint

The v358 Charm host staged Applied without requesting a flush. Normal autosave waited12s while UI offered Retry after2s. Sol added one coalesced per-profile deferred drain, preserving the existing exact stamp/writer/generation proof and in-flight owner. Three bounded .5/1/2s retries handle actual failures; periodic safety sweep remains. Saved replay performs no write. Independent Sol UI-owner source review: GO; Astra architecture: GO.

Fresh native Server VM passes **41 isolated cases**: PreferenceFlush6, CareCompanionSave8, PetAppearance19, SessionRecovery8. Fake stores/schedulers only; no live persistence. Includes commit-then-error, concurrent newer intent, exact replay, last-writer and lease fencing. Edit first failed because its cached older PetAppearance module lacked shape(); a fresh Server VM exposes the current API and passes. No production workaround for that authoring cache.

This checkpoint alone is not a publication or physical-phone/live-save latency claim. Final ordinary controls and integrated UI/material regressions follow in the larger pass.
