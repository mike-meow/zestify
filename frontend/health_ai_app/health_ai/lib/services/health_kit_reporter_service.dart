import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:health_kit_reporter/health_kit_reporter.dart';
import 'package:health_kit_reporter/model/payload/category.dart' as hk;
import 'package:health_kit_reporter/model/payload/correlation.dart' as hk;
import 'package:health_kit_reporter/model/payload/quantity.dart' as hk;
import 'package:health_kit_reporter/model/payload/workout.dart' as hk;
import 'package:health_kit_reporter/model/predicate.dart';
import 'package:health_kit_reporter/model/type/category_type.dart';
import 'package:health_kit_reporter/model/type/correlation_type.dart';
import 'package:health_kit_reporter/model/type/quantity_type.dart';
import 'package:health_kit_reporter/model/type/workout_type.dart';
import 'package:health_kit_reporter/model/update_frequency.dart';

/// Service for accessing Apple HealthKit data directly through health_kit_reporter package
/// This provides more accurate and comprehensive data than the Flutter health package
class HealthKitReporterService {
  static final HealthKitReporterService _instance =
      HealthKitReporterService._internal();

  /// Factory constructor to return the singleton instance
  factory HealthKitReporterService() => _instance;

  /// Private constructor for singleton pattern
  HealthKitReporterService._internal();

  /// Whether the service is initialized
  bool _isInitialized = false;

  /// Whether the service has permissions
  bool _hasPermissions = false;

  /// Getter for initialization status
  bool get isInitialized => _isInitialized;

  /// Getter for permissions status
  bool get hasPermissions => _hasPermissions;

  /// Initialize the service and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) return _hasPermissions;

    try {
      // Define the types we want to read
      final readTypes = [
        // Workout data
        WorkoutType.workoutType.identifier,
        // Activity data
        QuantityType.stepCount.identifier,
        QuantityType.distanceWalkingRunning.identifier,
        QuantityType.activeEnergyBurned.identifier,
        // Vital signs
        QuantityType.heartRate.identifier,
        QuantityType.restingHeartRate.identifier,
        QuantityType.heartRateVariabilitySDNN.identifier,
        QuantityType.oxygenSaturation.identifier,
        QuantityType.respiratoryRate.identifier,
        QuantityType.bodyTemperature.identifier,
        // Body measurements
        QuantityType.height.identifier,
        QuantityType.bodyMass.identifier,
        QuantityType.bodyFatPercentage.identifier,
        QuantityType.leanBodyMass.identifier,
        // Sleep data
        CategoryType.sleepAnalysis.identifier,
      ];

      // Define the types we want to write (if any)
      final writeTypes = <String>[];

      // Request authorization
      final isRequested = await HealthKitReporter.requestAuthorization(
        readTypes,
        writeTypes,
      );

      _isInitialized = true;
      _hasPermissions = isRequested;

      debugPrint(
        'HealthKitReporter initialized with permissions: $_hasPermissions',
      );
      return _hasPermissions;
    } catch (e) {
      debugPrint('Error initializing HealthKitReporter: $e');
      return false;
    }
  }

  /// Create a predicate for querying data within a date range
  Predicate _createPredicate(DateTime startDate, DateTime endDate) {
    return Predicate(startDate, endDate);
  }

  /// Fetch workouts from HealthKit
  Future<List<Map<String, dynamic>>> fetchWorkouts({
    DateTime? startDate,
    DateTime? endDate,
    bool includeDetailedMetrics = true,
  }) async {
    try {
      // Ensure we have permissions
      final hasPermissions = await initialize();
      if (!hasPermissions) {
        debugPrint('Health data permissions not granted');
        return [];
      }

      // Default to last year if no date range provided
      final now = DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 365));
      final end = endDate ?? now;

      // Create predicate for date range
      final predicate = _createPredicate(start, end);

      // Query workouts
      final workouts = await HealthKitReporter.workoutQuery(predicate);

      // Process workouts
      final processedWorkouts = <Map<String, dynamic>>[];

      for (final workout in workouts) {
        // Process basic workout data
        final workoutData = _processWorkout(workout);

        // Add detailed metrics if requested
        if (includeDetailedMetrics) {
          // Add kilometer splits if available
          final splits = await _fetchWorkoutKilometerSplits(workout);
          if (splits.isNotEmpty) {
            workoutData['kilometer_splits'] = splits;
          }

          // Add heart rate data if available
          final heartRateData = await _fetchWorkoutHeartRateData(workout);
          if (heartRateData.isNotEmpty) {
            workoutData['heart_rate_data'] = heartRateData;
          }
        }

        processedWorkouts.add(workoutData);
      }

      return processedWorkouts;
    } catch (e) {
      debugPrint('Error fetching workouts: $e');
      return [];
    }
  }

  /// Fetch kilometer splits for a workout
  Future<List<Map<String, dynamic>>> _fetchWorkoutKilometerSplits(
    hk.Workout workout,
  ) async {
    try {
      // Skip if not a running or walking workout
      if (!_isRunningOrWalkingWorkout(workout.workoutActivityType)) {
        return [];
      }

      // Create a predicate for this workout
      final workoutPredicate = Predicate.fromWorkout(workout);

      // Get route data for this workout
      final routeSamples = await HealthKitReporter.routeQuery(workoutPredicate);

      // Skip if no route data
      if (routeSamples.isEmpty) {
        return [];
      }

      // Process route data to extract kilometer splits
      final splits = <Map<String, dynamic>>[];

      // Get the first route (usually there's only one per workout)
      final route = routeSamples.first;

      // Get the locations for this route
      final locations = route.locations;

      // Skip if no locations
      if (locations.isEmpty) {
        return [];
      }

      // Calculate kilometer splits
      double currentDistance = 0.0;
      int splitIndex = 1;
      DateTime? splitStartTime;
      DateTime? lastLocationTime;

      for (int i = 0; i < locations.length - 1; i++) {
        final currentLocation = locations[i];
        final nextLocation = locations[i + 1];

        // Get timestamps
        final currentTime = DateTime.fromMillisecondsSinceEpoch(
          currentLocation.timestamp,
        );
        final nextTime = DateTime.fromMillisecondsSinceEpoch(
          nextLocation.timestamp,
        );

        // Set split start time if this is the first location
        if (splitStartTime == null) {
          splitStartTime = currentTime;
        }

        // Calculate distance between points
        final segmentDistance = calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          nextLocation.latitude,
          nextLocation.longitude,
        );

        // Add to current distance
        currentDistance += segmentDistance;

        // If we've reached a kilometer, record the split
        if (currentDistance >= 1.0) {
          // Calculate split duration
          final splitDuration = nextTime.difference(splitStartTime!);

          // Calculate pace (minutes per kilometer)
          final paceSeconds = splitDuration.inSeconds;
          final paceMinutes = paceSeconds / 60;

          // Add split data
          splits.add({
            'split_index': splitIndex,
            'distance': 1.0,
            'distance_unit': 'km',
            'duration_seconds': splitDuration.inSeconds,
            'pace_seconds_per_km': paceSeconds,
            'pace_minutes_per_km': paceMinutes,
          });

          // Reset for next split
          currentDistance =
              currentDistance - 1.0; // Keep remainder for next split
          splitIndex++;
          splitStartTime = nextTime;
        }

        lastLocationTime = nextTime;
      }

      // Add final partial split if there's significant distance
      if (currentDistance > 0.1 &&
          splitStartTime != null &&
          lastLocationTime != null) {
        final splitDuration = lastLocationTime.difference(splitStartTime);
        final paceSeconds = splitDuration.inSeconds / currentDistance;
        final paceMinutes = paceSeconds / 60;

        splits.add({
          'split_index': splitIndex,
          'distance': currentDistance,
          'distance_unit': 'km',
          'duration_seconds': splitDuration.inSeconds,
          'pace_seconds_per_km': paceSeconds,
          'pace_minutes_per_km': paceMinutes,
          'is_partial': true,
        });
      }

      return splits;
    } catch (e) {
      debugPrint('Error fetching kilometer splits: $e');
      return [];
    }
  }

  /// Fetch heart rate data for a workout
  Future<List<Map<String, dynamic>>> _fetchWorkoutHeartRateData(
    hk.Workout workout,
  ) async {
    try {
      // Create a predicate for this workout's time range
      final workoutPredicate = _createPredicate(
        DateTime.fromMillisecondsSinceEpoch(workout.startDate),
        DateTime.fromMillisecondsSinceEpoch(workout.endDate),
      );

      // Get preferred unit for heart rate
      final preferredUnits = await HealthKitReporter.preferredUnits([
        QuantityType.heartRate.identifier,
      ]);

      if (preferredUnits.isEmpty) return [];

      final unit = preferredUnits.first.unit;
      final type = QuantityTypeFactory.from(QuantityType.heartRate.identifier);

      // Query heart rate data
      final heartRateSamples = await HealthKitReporter.quantityQuery(
        type,
        unit,
        workoutPredicate,
      );

      // Skip if no heart rate data
      if (heartRateSamples.isEmpty) return [];

      // Process heart rate data
      final heartRateData = <Map<String, dynamic>>[];

      for (final sample in heartRateSamples) {
        final timestamp = DateTime.fromMillisecondsSinceEpoch(sample.startDate);
        final value = sample.harmonized.value;

        heartRateData.add({
          'timestamp': timestamp.toIso8601String(),
          'value': value,
          'unit': 'bpm',
        });
      }

      // Also get statistics
      final statistics = await HealthKitReporter.statisticsQuery(
        type,
        unit,
        workoutPredicate,
      );

      // Add summary data if available
      if (statistics.averageQuantity != null) {
        final summary = {
          'average': statistics.averageQuantity,
          'min': statistics.minimumQuantity,
          'max': statistics.maximumQuantity,
        };

        if (heartRateData.isNotEmpty) {
          heartRateData.first['summary'] = summary;
        } else {
          heartRateData.add({'summary': summary, 'unit': 'bpm'});
        }
      }

      return heartRateData;
    } catch (e) {
      debugPrint('Error fetching heart rate data: $e');
      return [];
    }
  }

  /// Check if workout is running or walking
  bool _isRunningOrWalkingWorkout(String workoutType) {
    return workoutType == 'HKWorkoutActivityTypeRunning' ||
        workoutType == 'HKWorkoutActivityTypeRunningSand' ||
        workoutType == 'HKWorkoutActivityTypeWalking' ||
        workoutType == 'HKWorkoutActivityTypeHiking';
  }

  /// Calculate distance between two points using Haversine formula
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const int earthRadius = 6371; // Radius of the earth in km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadius * c; // Distance in km

    return distance;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Process a workout into a standardized map format
  Map<String, dynamic> _processWorkout(hk.Workout workout) {
    // Map workout type to standardized format
    final workoutType = mapWorkoutType(workout.workoutActivityType);

    // Create base workout data
    final workoutData = {
      'id': workout.uuid,
      'workout_type': workoutType,
      'original_type': workout.workoutActivityType,
      'start_date':
          DateTime.fromMillisecondsSinceEpoch(
            workout.startDate,
          ).toIso8601String(),
      'end_date':
          DateTime.fromMillisecondsSinceEpoch(
            workout.endDate,
          ).toIso8601String(),
      'duration_seconds': (workout.endDate - workout.startDate) / 1000,
      'source': workout.sourceRevision.source.name,
    };

    // Add distance if available
    if (workout.totalDistance != null) {
      workoutData['distance'] = workout.totalDistance! / 1000; // Convert to km
      workoutData['distance_unit'] = 'km';
    }

    // Add energy burned if available
    if (workout.totalEnergyBurned != null) {
      workoutData['energy_burned'] = workout.totalEnergyBurned;
      workoutData['energy_burned_unit'] = 'kcal';
    }

    return workoutData;
  }

  /// Map Apple HealthKit workout type to standardized format
  String mapWorkoutType(String originalType) {
    // Map common workout types
    switch (originalType) {
      case 'HKWorkoutActivityTypeRunning':
      case 'HKWorkoutActivityTypeRunningSand':
        return 'running';
      case 'HKWorkoutActivityTypeWalking':
      case 'HKWorkoutActivityTypeHiking':
        return 'walking';
      case 'HKWorkoutActivityTypeCycling':
      case 'HKWorkoutActivityTypeCyclingIndoor':
        return 'cycling';
      case 'HKWorkoutActivityTypeSwimming':
        return 'swimming';
      case 'HKWorkoutActivityTypeYoga':
        return 'yoga';
      case 'HKWorkoutActivityTypeStrengthTraining':
      case 'HKWorkoutActivityTypeFunctionalStrengthTraining':
        return 'strength_training';
      default:
        return originalType
            .replaceAll('HKWorkoutActivityType', '')
            .toLowerCase();
    }
  }
}
