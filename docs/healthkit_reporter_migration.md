# Migration to HealthKitReporter

## 1. Why migrate?

| Metric | `health` package | HealthKitReporter |
| ------ | ---------------- | ----------------- |
| Segment pace (km splits) for Run/Swim | ❌ Not exposed, only coarse distance | ✅ Accurate splits via `WorkoutRoute` & events |
| Lap-based pool-swim pace | ❌ | ✅ `HKWorkoutEventTypeSegment` supported |
| Heart-rate zones (min/max/avg) | Approx. (sampling intervals differ) | Exact statistics from `statisticsQuery` |
| GPS/Route polyline | ❌ | ✅ Full `WorkoutRoute` locations list |
| Background delivery | Limited | Robust – supports observer & anchored-object queries |
| Preferred units | Manual mapping | Auto via `preferredUnits` |
| Write access | Partial | Mirrors HealthKitReporter capabilities |

**Result** → Users see the same pace numbers in the app that they see inside the iOS Fitness app.

## 2. Test coverage added

* `test/services/health_kit_reporter_segment_test.dart`
  * Verifies kilometer-split extraction for **running** workouts.
  * Verifies (optionally) split retrieval for **swimming** workouts.
  * Runs only on a real iOS device – skipped on CI/simulator.
* Existing unit-tests continue to validate geo-distance maths & workout-type mapping.

> ℹ️ Run the new suite on-device:
> ```bash
> flutter test --plain-name "HealthKitReporter – segment pace"
> ```

## 3. Migration plan to remove the legacy `health` package

| Phase | Goal | Code changes | Owner | Target date |
| ----- | ---- | ------------ | ----- | ----------- |
| **Phase 0** (done) | Dual-stack behind feature flag, default **on** | – `use_health_kit_reporter` flag defaulted to `true` | Core | Now |
| **Phase 1** | Expand test matrix – nightly on-device run, manual QA session | 1. Add GitHub Action to run `xcodebuild test` on a connected iPhone<br>2. QA team validates 5x real workouts per user (Run, Walk, Swim, Cycle, Strength) | QA | +2 weeks |
| **Phase 2** | Deprecate legacy path | 1. Remove toggle from UI<br>2. Hard-code UnifiedHealthService to `HealthServiceFacade` | Core | +3 weeks |
| **Phase 3** | Remove dependency | 1. `flutter pub remove health`<br>2. Delete `HealthService`, `NativeHealthService`, Biometrics chunks that depended on `health`<br>3. Clean up iOS swift code calling old MethodChannel | Core | +4 weeks |
| **Phase 4** | Clean ◦ Polish | 1. Regenerate `pubspec.lock`<br>2. `pod deintegrate && pod install`<br>3. Confirm App Store submission passes App Review | Core | +5 weeks |

### Rollback strategy

Set `use_health_kit_reporter` to `false` in `SharedPreferences` (or via the hidden debug switch) to return to the legacy stack for any hot-fix.

## 4. Monitoring

* Track `workout_upload_success` & `workout_segment_count` metrics – expect segment count > 0 for 95-percentile of outdoor runs.
* Alert if average Δpace between Apple Health and backend > 3 s/km (requires server-side comparison).

---
**Questions?** Ping #mobile-health in Slack.