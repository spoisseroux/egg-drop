# Server policy fixture newline audit

Coordinator reported a nil `S` in MaterialProgress. The injected explicit-random-policy wrapper had an end-of-line comment followed by `;local ...`, swallowing subsequent requires even though Luau compiled.

Audited all five canonical fixtures carrying `explicit allowed random fixture`: CharmRules, HueClear, HueProgress, MaterialProgress and ToyFeatureProgress. Four required **newline-only** repairs: HueClear / HueProgress / MaterialProgress / ToyFeatureProgress. CharmRules was already newline-safe. The wrapper's cloned H API and `handle.restricted=false` semantics remain unchanged; no assertion or runtime policy guard was weakened.

Synchronized all five `src/server/ZZSpecs` mirrors to their canonical scripts and compiled all changed sources/mirrors. The swallowed S/Hue/Legacy/Toy/Feature requires are now lexical declarations. No server runtime, save schema or user record was edited. Coordinator must rerun the full server suite from these current sources; this audit does not substitute compile for those tests.
