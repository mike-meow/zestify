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

  /// Get all available health data types
  List<HealthDataType> get allHealthDataTypes => [
    // Activity and fitness
    HealthDataType.STEPS,
    HealthDataType.WORKOUT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.MOVE_MINUTES,
    HealthDataType.EXERCISE_TIME,

    // Heart related
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.HIGH_HEART_RATE_EVENT,
    HealthDataType.LOW_HEART_RATE_EVENT,
    HealthDataType.IRREGULAR_HEART_RATE_EVENT,

    // Body measurements
    HealthDataType.HEIGHT,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.WAIST_CIRCUMFERENCE,

    // Results
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.ELECTRODERMAL_ACTIVITY,
    HealthDataType.WATER,
    HealthDataType.MINDFULNESS,

    // Nutrition
    HealthDataType.DIETARY_ENERGY_CONSUMED,

    // Sleep
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_SESSION,
  ];

  /// Initialize the health service and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) return _hasPermissions;

    try {
      // Define the types to get permissions for - request all available types
      final types = allHealthDataTypes;

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

  /// Fetch all health data from Apple Health and save to files
  Future<Map<String, int>> fetchAllHealthData({
    DateTime? startDate,
    DateTime? endDate,
    bool includeWorkoutDetails = true,
  }) async {
    // Ensure we have permissions
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('Error initializing health service: $e');
        return {'error': 1};
      }
    }

    if (!_hasPermissions) {
      debugPrint('Health data permissions not granted');
      return {'error': 2};
    }

    // Default to last 3 years if no date range provided
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365 * 3));
    final end = endDate ?? now;

    final fileStorage = FileStorageService();
    final results = <String, int>{};

    // Fetch data for each health data type
    for (final type in allHealthDataTypes) {
      try {
        debugPrint('Fetching health data for type: ${type.name}');

        // Skip workout type as we'll handle it separately
        if (type == HealthDataType.WORKOUT && includeWorkoutDetails) {
          continue;
        }

        // Fetch data for this type
        final healthData = await _health.getHealthDataFromTypes(start, end, [
          type,
        ]);

        if (healthData.isNotEmpty) {
          // Create directory for this data type
          final dirName = type.name.toLowerCase();

          // Convert data to JSON format
          final jsonData =
              healthData.map((dataPoint) {
                // Base data that all types have
                final Map<String, dynamic> item = {
                  'uuid': dataPoint.sourceId,
                  'type': dataPoint.type.name,
                  'timestamp': dataPoint.dateFrom.toIso8601String(),
                  'endTimestamp': dataPoint.dateTo.toIso8601String(),
                  'sourceName': dataPoint.sourceName,
                  'sourceId': dataPoint.sourceId,
                };

                // Add value based on its type
                if (dataPoint.value is NumericHealthValue) {
                  item['value'] =
                      (dataPoint.value as NumericHealthValue).numericValue;
                } else if (dataPoint.value is WorkoutHealthValue) {
                  final workout = dataPoint.value as WorkoutHealthValue;
                  item['workoutType'] = workout.workoutActivityType.name;
                  item['totalEnergyBurned'] = workout.totalEnergyBurned;
                  item['totalDistance'] = workout.totalDistance;
                } else if (dataPoint.value is AudiogramHealthValue) {
                  // Handle audiogram data
                  item['value'] = 'audiogram_data';
                } else if (dataPoint.value is ElectrocardiogramHealthValue) {
                  // Handle ECG data
                  item['value'] = 'ecg_data';
                } else {
                  // For other types, just convert to string
                  item['value'] = dataPoint.value.toString();
                }

                return item;
              }).toList();

          // Save to file
          await fileStorage.saveRawHealthData('${dirName}_data', jsonData);

          // Update results
          results[type.name] = healthData.length;
        } else {
          results[type.name] = 0;
        }
      } catch (e) {
        debugPrint('Error fetching health data for type ${type.name}: $e');
        results[type.name] = -1; // Error code
      }
    }

    // Fetch workout history if requested
    if (includeWorkoutDetails) {
      try {
        final workoutHistory = await fetchWorkoutHistory(
          startDate: start,
          endDate: end,
        );
        results['WORKOUT'] = workoutHistory.workouts.length;

        // For each workout, fetch heart rate and route data
        for (final workout in workoutHistory.workouts) {
          try {
            final heartRateData = await getHeartRateDataForWorkout(workout);
            results['HEART_RATE_FOR_WORKOUTS'] =
                (results['HEART_RATE_FOR_WORKOUTS'] ?? 0) +
                heartRateData.length;
          } catch (e) {
            debugPrint(
              'Error fetching heart rate data for workout ${workout.id}: $e',
            );
          }

          try {
            final routeData = await getRouteDataForWorkout(workout);
            results['ROUTE_DATA_FOR_WORKOUTS'] =
                (results['ROUTE_DATA_FOR_WORKOUTS'] ?? 0) + routeData.length;
          } catch (e) {
            debugPrint(
              'Error fetching route data for workout ${workout.id}: $e',
            );
          }
        }
      } catch (e) {
        debugPrint('Error fetching workout history: $e');
        results['WORKOUT'] = -1; // Error code
      }
    }

    // Save metadata about this fetch
    await fileStorage.saveRawHealthData('health_data_fetch_metadata', {
      'fetchTime': DateTime.now().toIso8601String(),
      'startDate': start.toIso8601String(),
      'endDate': end.toIso8601String(),
      'results': results,
    });

    return results;
  }

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

    // Default to last 3 years if no date range provided
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365 * 3));
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

  /// Get route data for a specific workout
  /// Note: This is a mock implementation as HealthKit doesn't directly provide route data
  /// In a real app, you would use CoreLocation or a fitness API to get this data
  Future<List<Map<String, dynamic>>> getRouteDataForWorkout(
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
      // In a real implementation, you would fetch actual GPS data here
      // For now, we'll generate mock data based on the workout duration and distance

      // If no distance is available, we can't generate route data
      if (workout.distance == null || workout.distance == 0) {
        return [];
      }

      final routePoints = <Map<String, dynamic>>[];
      final startTime = workout.startTime;
      final totalDuration = workout.durationInSeconds;
      final totalDistance = workout.distance!;

      // Generate points every 30 seconds or at least 20 points for the route
      final interval = totalDuration > 600 ? 30 : (totalDuration / 20).round();
      final pointCount = (totalDuration / interval).ceil();

      // Mock starting coordinates (San Francisco)
      double latitude = 37.7749;
      double longitude = -122.4194;
      double altitude = 10.0;

      // Generate route points
      for (int i = 0; i < pointCount; i++) {
        final offsetSeconds = i * interval;
        final timestamp = startTime.add(Duration(seconds: offsetSeconds));

        // Calculate progress along the route
        final progress = i / (pointCount - 1);

        // Update coordinates (simple linear path for mock data)
        latitude += 0.001 * progress;
        longitude += 0.001 * progress;
        altitude += (workout.totalAscent ?? 0) * progress / pointCount;

        // Calculate speed at this point (vary it a bit for realism)
        final speedFactor =
            0.8 + 0.4 * (i % 3) / 2; // Varies between 0.8 and 1.2
        final avgSpeed = totalDistance / totalDuration; // meters per second
        final speed = avgSpeed * speedFactor;

        routePoints.add({
          'latitude': latitude,
          'longitude': longitude,
          'altitude': altitude,
          'speed': speed,
          'timestamp': timestamp.toIso8601String(),
          'offsetSeconds': offsetSeconds,
        });
      }

      // Save route data to file
      final fileStorage = FileStorageService();
      await fileStorage.saveRoutePoints(workout.id, routePoints);

      // Save raw route data for debugging/design
      await fileStorage.saveRawHealthData(
        'raw_route_${workout.id}',
        routePoints,
      );

      return routePoints;
    } catch (e) {
      debugPrint('Error generating route data: $e');
      return [];
    }
  }
}
