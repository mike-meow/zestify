import 'package:health/health.dart';
import 'package:flutter/foundation.dart';
import '../models/workout/workout.dart';
import '../models/workout/workout_history.dart';
import '../models/workout/heart_rate_sample.dart';
import 'file_storage_service.dart';

/// Service for interacting with Apple Health
class HealthService {
  static final HealthService _instance = HealthService._internal();

  /// Factory constructor to return the singleton instance
  factory HealthService() => _instance;

  /// Private constructor for singleton pattern
  HealthService._internal();

  /// Health plugin instance
  final HealthFactory _health = HealthFactory(
    useHealthConnectIfAvailable: true,
  );

  /// Whether the service has been initialized
  bool _isInitialized = false;

  /// Whether the user has granted permissions
  bool _hasPermissions = false;

  /// Initialize the health service and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) return _hasPermissions;

    try {
      // Define the types to get permissions for - request all available types
      final types = [
        // Activity and fitness
        HealthDataType.STEPS,
        HealthDataType.WORKOUT,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.FLIGHTS_CLIMBED,
        HealthDataType.EXERCISE_TIME,

        // Heart related
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,

        // Body measurements
        HealthDataType.HEIGHT,
        HealthDataType.WEIGHT,
        HealthDataType.BODY_MASS_INDEX,
        HealthDataType.BODY_FAT_PERCENTAGE,

        // Results
        HealthDataType.BLOOD_GLUCOSE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BODY_TEMPERATURE,
        HealthDataType.RESPIRATORY_RATE,

        // Sleep
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_LIGHT,
      ];

      // Request authorization
      _hasPermissions = await _health.requestAuthorization(types);
      _isInitialized = true;

      return _hasPermissions;
    } catch (e) {
      debugPrint('Error initializing health service: $e');
      _isInitialized = false;
      _hasPermissions = false;
      return false;
    }
  }

  /// Check if the service has permissions
  bool get hasPermissions => _hasPermissions;

  /// Fetch workout history from Apple Health
  Future<WorkoutHistory> fetchWorkoutHistory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Ensure we have permissions
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('Error initializing health service: $e');
        // Return empty workout history on initialization error
        return WorkoutHistory(
          workouts: [],
          userId: 'current_user',
          lastSyncTime: DateTime.now(),
        );
      }
    }

    if (!_hasPermissions) {
      debugPrint('Health data permissions not granted');
      // Return empty workout history when permissions not granted
      return WorkoutHistory(
        workouts: [],
        userId: 'current_user',
        lastSyncTime: DateTime.now(),
      );
    }

    // Default to last 30 days if no date range provided
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;

    try {
      // Fetch workouts using getHealthDataFromTypes with WORKOUT type
      final healthData = await _health.getHealthDataFromTypes(start, end, [
        HealthDataType.WORKOUT,
      ]);

      // Convert to our model
      final List<Workout> workoutModels = [];

      for (final dataPoint in healthData) {
        if (dataPoint.value is WorkoutHealthValue) {
          final workoutValue = dataPoint.value as WorkoutHealthValue;

          // Debug the workout type
          debugPrint('Raw workout type: ${workoutValue.workoutActivityType}');
          debugPrint(
            'Workout type name: ${workoutValue.workoutActivityType.name}',
          );

          // Convert the workout data to a map
          final workoutData = {
            'uuid': dataPoint.sourceId,
            'workoutActivityType': workoutValue.workoutActivityType.name,
            'workoutActivityTypeEnum':
                workoutValue.workoutActivityType.toString(),
            'startDate': dataPoint.dateFrom.toIso8601String(),
            'endDate': dataPoint.dateTo.toIso8601String(),
            'totalEnergyBurned': workoutValue.totalEnergyBurned,
            'totalDistance': workoutValue.totalDistance,
            'sourceRevision': dataPoint.sourceId,
            'device': dataPoint.sourceName,
            'durationInSeconds':
                dataPoint.dateTo.difference(dataPoint.dateFrom).inSeconds,
          };

          // Create a workout model
          final workout = Workout.fromAppleHealth(workoutData);
          workoutModels.add(workout);
        }
      }

      // Sort workouts by start time (newest first)
      workoutModels.sort((a, b) => b.startTime.compareTo(a.startTime));

      // Create workout history
      final workoutHistory = WorkoutHistory(
        workouts: workoutModels,
        userId: 'current_user', // Replace with actual user ID when available
        lastSyncTime: DateTime.now(),
      );

      // Save to files
      final fileStorage = FileStorageService();
      await fileStorage.saveWorkoutHistory(workoutHistory);

      // Save each workout individually
      for (final workout in workoutModels) {
        await fileStorage.saveWorkout(workout);

        // Save raw workout data for debugging/design
        final rawWorkoutData = workout.toJson();
        await fileStorage.saveRawHealthData(
          'raw_workout_${workout.id}',
          rawWorkoutData,
        );
      }

      // Save all raw workout data for debugging/design
      await fileStorage.saveRawHealthData(
        'all_workouts_raw',
        workoutModels.map((w) => w.toJson()).toList(),
      );

      return workoutHistory;
    } catch (e) {
      debugPrint('Error fetching workout history: $e');
      // Return empty workout history on error
      return WorkoutHistory(
        workouts: [],
        userId: 'current_user',
        lastSyncTime: DateTime.now(),
      );
    }
  }

  /// Fetch a specific workout by ID
  Future<Workout?> fetchWorkoutById(String workoutId) async {
    // Ensure we have permissions
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('Error initializing health service: $e');
        return null;
      }
    }

    if (!_hasPermissions) {
      debugPrint('Health data permissions not granted');
      return null;
    }

    try {
      // Fetch all workouts from the last year (we'll filter by ID)
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 365));

      final healthData = await _health.getHealthDataFromTypes(start, now, [
        HealthDataType.WORKOUT,
      ]);

      // Find the workout with the matching ID
      final dataPoint = healthData.firstWhere(
        (dp) => dp.sourceId == workoutId,
        orElse: () => throw Exception('Workout not found'),
      );

      if (dataPoint.value is WorkoutHealthValue) {
        final workoutValue = dataPoint.value as WorkoutHealthValue;

        // Debug the workout type
        debugPrint('Raw workout type: ${workoutValue.workoutActivityType}');
        debugPrint(
          'Workout type name: ${workoutValue.workoutActivityType.name}',
        );

        // Convert to our model
        final workoutData = {
          'uuid': dataPoint.sourceId,
          'workoutActivityType': workoutValue.workoutActivityType.name,
          'workoutActivityTypeEnum':
              workoutValue.workoutActivityType.toString(),
          'startDate': dataPoint.dateFrom.toIso8601String(),
          'endDate': dataPoint.dateTo.toIso8601String(),
          'totalEnergyBurned': workoutValue.totalEnergyBurned,
          'totalDistance': workoutValue.totalDistance,
          'sourceRevision': dataPoint.sourceId,
          'device': dataPoint.sourceName,
          'durationInSeconds':
              dataPoint.dateTo.difference(dataPoint.dateFrom).inSeconds,
        };

        return Workout.fromAppleHealth(workoutData);
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching workout by ID: $e');
      return null;
    }
  }

  /// Get heart rate data for a specific workout
  Future<List<HeartRateSample>> getHeartRateDataForWorkout(
    Workout workout,
  ) async {
    // Ensure we have permissions
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('Error initializing health service: $e');
        return [];
      }
    }

    if (!_hasPermissions) {
      debugPrint('Health data permissions not granted');
      return [];
    }

    try {
      // Fetch heart rate data during the workout
      final heartRateData = await _health.getHealthDataFromTypes(
        workout.startTime,
        workout.endTime,
        [HealthDataType.HEART_RATE],
      );

      // Convert to HeartRateSample objects
      final samples =
          heartRateData.map((dataPoint) {
            // Calculate offset in seconds from workout start
            final offsetSeconds =
                dataPoint.dateFrom.difference(workout.startTime).inSeconds;

            // Extract the numeric value
            final numericValue =
                dataPoint.value is NumericHealthValue
                    ? (dataPoint.value as NumericHealthValue).numericValue
                    : 0.0;

            return HeartRateSample(
              value: numericValue.toDouble(),
              timestamp: dataPoint.dateFrom,
              workoutId: workout.id,
              offsetSeconds: offsetSeconds,
            );
          }).toList();

      // Save heart rate data to file
      final fileStorage = FileStorageService();
      await fileStorage.saveHeartRateSamples(workout.id, samples);

      // Save raw heart rate data for debugging/design
      final rawHeartRateData =
          heartRateData
              .map(
                (dataPoint) => {
                  'value':
                      dataPoint.value is NumericHealthValue
                          ? (dataPoint.value as NumericHealthValue).numericValue
                          : 0.0,
                  'timestamp': dataPoint.dateFrom.toIso8601String(),
                  'offsetSeconds':
                      dataPoint.dateFrom
                          .difference(workout.startTime)
                          .inSeconds,
                },
              )
              .toList();
      await fileStorage.saveRawHealthData(
        'raw_heart_rate_${workout.id}',
        rawHeartRateData,
      );

      return samples;
    } catch (e) {
      debugPrint('Error fetching heart rate data: $e');
      return [];
    }
  }

  /// Calculate statistics from heart rate samples
  Map<String, dynamic> calculateHeartRateStats(List<HeartRateSample> samples) {
    if (samples.isEmpty) {
      return {'min': null, 'max': null, 'avg': null};
    }

    // Calculate min, max, and average
    double min = samples.first.value;
    double max = samples.first.value;
    double sum = 0;

    for (final sample in samples) {
      if (sample.value < min) min = sample.value;
      if (sample.value > max) max = sample.value;
      sum += sample.value;
    }

    return {'min': min, 'max': max, 'avg': sum / samples.length};
  }
}
