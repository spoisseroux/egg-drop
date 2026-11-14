# Report sharding — unpublished code result

2026-11-14 · Sol implementation, independent systems Sol code review **GO**. No external report reads/writes, migration, erasure, Studio control, commit or publish performed by this lane.

`BugReportStore` now routes fresh UTC days into 16 deterministic UserId shards. Existing nonempty legacy days continue in their legacy key; failed or malformed legacy reads queue without writing anywhere. A weak-key record routing cache retains the first successful route decision through ambiguous writes and midnight retries, without adding a persisted personal-data field. Immutable id deduplication precedes all stored caps. Recent owner reads cover all 17 possible keys/day, globally sort and deduplicate before limiting. Strict canonical parsing protects retention and owner erasure for both key formats.

Validation: `python scripts/testhelpers/run_bug_reports.py` runs actual module/form/copy source in local Luau (only UICopy's Studio `script` global is stubbed): **14/14 passing**. Cases include shared-server same-user caps/duplicates, independent full shards, legacy daily limits and next-day transition, read failure, malformed legacy data, ambiguous success at a full shard, midnight, merged reads, strict expiry/erasure and owner gates. Coordinator independently reran 14/14. Studio spec execution remains coordinator-owned.

**Rollout requirement:** replace stale pre-sharding servers when eventually deploying. Old servers still append/create legacy keys and can split a user's new-day reports between formats if allowed to coexist with shard writers. The legacy-preserving rule is not a migration and cannot solve mixed-version writers. No deployment happened in this task.

Operational tradeoff: an owner request for 30 days reads up to 510 keys sequentially. This can be slow or consume budget; no load/latency claim is made. The user-facing submission path reads one legacy key and updates one chosen key.
