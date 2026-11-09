# Bounded midnight CPU check

The final-art first three midnight rounds measured median rig-update p95 1.221800 ms against 1.106600 ms before, 10.410% higher. Overall elapsed frame p95 improved; all rounds had 180 controlled light/camera frames and stable world/UI/graphics. Client rig code and the seven fixture rig resources are unchanged; the world adds 64 parts.

Before further measurement, declare one follow-up batch of three midnight rounds on the same frozen source, same 180 warm / 180 captured frames, viewport, camera, graphics and seven-rig/toy fixture. Retain the initial three and report all six after rounds together. No cosmetic or runtime optimization is applied between these rounds. This investigates the >10% tail trigger without selecting a favorable replacement batch. It cannot prove physical-phone performance or assign a CPU fluctuation to a particular engine subsystem.
