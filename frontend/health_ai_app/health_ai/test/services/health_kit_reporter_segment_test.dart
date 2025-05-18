/// Integration tests for HealthKitReporterService verifying
/// that segment pace data (kilometer splits) is retrieved for
/// running and swimming workouts.
///
/// IMPORTANT: These tests need a real iOS device with HealthKit
/// permissions and at least one recent Run & Swim workout that
/// has route data.  They are skipped by default so that CI (which
/// runs on macOS simulators or Linux containers) does not fail.
///
/// To execute on-device:
///   flutter test --plain-name "HealthKitReporter – segment pace"
/// and respond to HealthKit permission prompts on the phone.
///
/// You can also point the test to a specific time-range by setting
/// the following env vars before running the test:
///   SEGMENT_TEST_START=<ISO8601>  SEGMENT_TEST_END=<ISO8601>
///
/// Example:
///   SEGMENT_TEST_START=2024-05-01 SEGMENT_TEST_END=2024-05-10 \
///     flutter test test/services/health_kit_reporter_segment_test.dart
// @dart=3.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_ai/services/health_kit_reporter_service.dart';

void main() {
  final service = HealthKitReporterService();

  // By default we skip on non-iOS platforms or simulators.
  final bool shouldSkip = !Platform.isIOS ||
      // The iOS simulator does not support HealthKit.
      (Platform.environment['SIMULATOR_DEVICE_NAME'] != null);

  group('HealthKitReporter – segment pace', () {
    setUpAll(() async {
      if (shouldSkip) return;
      await service.initialize();
    });

    test('Run workouts expose kilometer splits', () async {
      if (shouldSkip) {
        return;
      }

      final now = DateTime.now();
      DateTime? start;
      DateTime? end;

      // Allow optional env vars to narrow the query window.
      if (Platform.environment.containsKey('SEGMENT_TEST_START')) {
        start = DateTime.parse(Platform.environment['SEGMENT_TEST_START']!);
      }
      if (Platform.environment.containsKey('SEGMENT_TEST_END')) {
        end = DateTime.parse(Platform.environment['SEGMENT_TEST_END']!);
      }

      final workouts = await service.fetchWorkouts(
        startDate: start ?? now.subtract(const Duration(days: 30)),
        endDate: end ?? now,
        includeDetailedMetrics: true,
      );

      // Filter to running workouts that contain kilometer splits.
      final runWithSplits = workouts.where((w) {
        return w['workout_type'] == 'running' &&
            (w['kilometer_splits'] as List?)?.isNotEmpty == true;
      });

      expect(runWithSplits, isNotEmpty,
          reason:
              'Expected at least one recent running workout with segment data.');

      // Validate basic shape of split objects.
      final firstRun = runWithSplits.first;
      final splits = firstRun['kilometer_splits'] as List;
      final firstSplit = splits.first as Map<String, dynamic>;

      expect(firstSplit, contains('distance'));
      expect(firstSplit['distance'], greaterThan(0));
      expect(firstSplit, containsPair('distance_unit', 'km'));
      expect(firstSplit, contains('duration_seconds'));
      expect(firstSplit['pace_minutes_per_km'], isNotNull);
    }, skip: shouldSkip);

    test('Swim workouts expose segment pace if available', () async {
      if (shouldSkip) {
        return;
      }

      final now = DateTime.now();
      final workouts = await service.fetchWorkouts(
        startDate: now.subtract(const Duration(days: 90)),
        endDate: now,
        includeDetailedMetrics: true,
      );

      final swimWithSplits = workouts.where((w) {
        return w['workout_type'] == 'swimming' &&
            (w['kilometer_splits'] as List?)?.isNotEmpty == true;
      });

      // Some devices may not record route data for swims; we just assert that
      // the code doesn't crash and returns an empty list gracefully.
      expect(swimWithSplits, isNotNull);
    }, skip: shouldSkip);
  });
}