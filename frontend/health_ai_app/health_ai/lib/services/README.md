# Health Services Implementation

This directory contains the implementation of health data services for the Health AI app.

## Overview

The app uses two different implementations for accessing health data:

1. **Original Implementation**: Uses the Flutter `health` package and a custom native bridge for accessing HealthKit data.
2. **New Implementation**: Uses the `health_kit_reporter` package for direct access to HealthKit data.

The new implementation provides more accurate and comprehensive access to HealthKit data, particularly for workout details like kilometer splits and heart rate data.

## Service Architecture

### Unified Health Service

The `UnifiedHealthService` is the main entry point for accessing health data. It uses a feature flag to determine which implementation to use:

```dart
// Get the active health service based on feature flags
dynamic _getActiveService() {
  return _featureFlagService.isEnabled('use_health_kit_reporter')
      ? _newHealthServiceFacade
      : _originalHealthService;
}
```

### Feature Flag Service

The `FeatureFlagService` manages feature flags for the app, allowing for gradual rollout of new features:

```dart
// Check if a feature flag is enabled
bool isEnabled(String featureFlag) {
  if (!_isInitialized) {
    debugPrint('Feature flag service not initialized');
    return false;
  }

  return _featureFlags[featureFlag] ?? false;
}
```

### Health Service Facade

The `HealthServiceFacade` provides the same interface as the original `HealthService` but uses the new `HealthKitReporterService` internally:

```dart
// Fetch workout history
Future<WorkoutHistory> fetchWorkoutHistory({
  DateTime? startDate,
  DateTime? endDate,
}) async {
  // ...
  final workouts = await _healthKitReporterService.fetchWorkouts(
    startDate: startDate,
    endDate: endDate,
    includeDetailedMetrics: true,
  );
  // ...
}
```

### Health Kit Reporter Service

The `HealthKitReporterService` provides direct access to HealthKit data using the `health_kit_reporter` package:

```dart
// Fetch workouts from HealthKit
Future<List<Map<String, dynamic>>> fetchWorkouts({
  DateTime? startDate,
  DateTime? endDate,
  bool includeDetailedMetrics = true,
}) async {
  // ...
  final workouts = await HealthKitReporter.workoutQuery(predicate);
  // ...
}
```

## Migration Guide

To migrate to the new implementation:

1. Initialize the `UnifiedHealthService` instead of the `HealthService`:

```dart
final healthService = UnifiedHealthService();
await healthService.initialize();
```

2. Enable the new implementation:

```dart
await healthService.enableNewImplementation();
```

3. Use the `UnifiedHealthService` as you would use the `HealthService`:

```dart
final workoutHistory = await healthService.fetchWorkoutHistory();
```

4. If you encounter issues, you can disable the new implementation:

```dart
await healthService.disableNewImplementation();
```

## Testing

The implementation includes unit tests for the `HealthKitReporterService` in `test/services/health_kit_reporter_service_test.dart`.

To run the tests:

```bash
flutter test test/services/health_kit_reporter_service_test.dart
```

Note that some tests can only be run on an actual iOS device, as they require access to HealthKit.

## Known Issues

- The `health_kit_reporter` package requires iOS 11.0 or later.
- Some features like `HeartbeatSeries` are only available on iOS 13.0 or later.
- Clinical Records are only available on iOS 12.0 or later and require a paid Apple developer subscription.
- We're using version 2.1.0 of the Flutter package, which depends on version 3.1.0 of the native HealthKitReporter CocoaPod.
