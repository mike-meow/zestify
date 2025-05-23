import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_ai/services/api_service.dart';
import 'package:health_ai/services/biometrics_fetcher.dart';
import 'package:health_ai/services/native_health_service.dart';
import 'package:health_ai/models/workout/workout.dart';
import 'package:health_ai/models/workout/workout_history.dart';
import 'package:health_ai/models/workout/heart_rate_sample.dart';

/// Source type for health data
enum SourceType { appleHealth, manual, device, other }

/// Service for interacting with Apple Health data
class HealthService {
  static final HealthService _instance = HealthService._internal();

  /// Factory constructor to return the singleton instance
  factory HealthService() => _instance;

  /// Private constructor for singleton pattern
  HealthService._internal();

  /// Health plugin instance
  final HealthFactory _health = HealthFactory();

  /// Biometrics fetcher for full health histories
  final BiometricsFetcher _biometricsFetcher = BiometricsFetcher();

  /// API service
  final ApiService _apiService = ApiService();

  /// Native health service for direct HealthKit access
  final NativeHealthService _nativeHealthService = NativeHealthService();

  /// Whether the service is initialized
  bool _isInitialized = false;

  /// Whether the service has permissions
  bool _hasPermissions = false;

  /// Initialize the health service and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) {
      return _hasPermissions;
    }

    try {
      // Define the types to get permissions for
      final types = [
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.BODY_MASS_INDEX,
        HealthDataType.BODY_FAT_PERCENTAGE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.FLIGHTS_CLIMBED,
        HealthDataType.MOVE_MINUTES,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.WORKOUT,
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.BLOOD_GLUCOSE,
        HealthDataType.RESPIRATORY_RATE,
        HealthDataType.WATER,
        HealthDataType.MINDFULNESS,
      ];

      // Request authorization
      _hasPermissions = await _health.requestAuthorization(types);
      _isInitialized = true;

      // Also initialize the native health service
      await _nativeHealthService.initialize();

      debugPrint(
        'Health service initialized with permissions: $_hasPermissions',
      );
      return _hasPermissions;
    } catch (e) {
      debugPrint('Error initializing health service: $e');
      return false;
    }
  }

  /// Fetch and upload health data directly to the server (focused on key metrics only)
  Future<bool> fetchAndUploadHealthData({
    DateTime? startDate,
    DateTime? endDate,
    bool includeWorkoutDetails = true,
  }) async {
    // Ensure we have permissions
    final hasPermissions = await initialize();
    if (!hasPermissions) {
      debugPrint('Health data permissions not granted');
      return false;
    }

    // Ensure API service is initialized
    if (!_apiService.isInitialized) {
      debugPrint('API service not initialized');
      return false;
    }

    // Ensure user ID is available
    if (_apiService.userId == null) {
      debugPrint('No user ID available');
      return false;
    }

    // Default to last year if no date range provided (to get more historical data)
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now;

    debugPrint(
      'Fetching health data from ${start.toIso8601String()} to ${end.toIso8601String()}',
    );

    try {
      // Fetch workouts
      final workouts = await _fetchAndProcessWorkouts(start, end);
      if (workouts.isNotEmpty) {
        // Upload workouts
        final workoutsSuccess = await _apiService.uploadWorkouts(workouts);
        if (!workoutsSuccess) {
          debugPrint('Failed to upload workouts');
        } else {
          debugPrint('Successfully uploaded ${workouts.length} workouts');
        }
      }

      // Fetch biometrics
      final biometrics = await _fetchBiometrics(start, end);
      if (biometrics.isNotEmpty) {
        // Upload biometrics
        final biometricsSuccess = await _apiService.uploadBiometrics(
          biometrics,
        );
        if (!biometricsSuccess) {
          debugPrint('Failed to upload biometrics');
        } else {
          debugPrint('Successfully uploaded biometrics');
        }
      }

      // Fetch activity data
      final activities = await _fetchActivities(start, end);
      if (activities.isNotEmpty) {
        // Upload activities
        final activitiesSuccess = await _apiService.uploadActivities(
          activities,
        );
        if (!activitiesSuccess) {
          debugPrint('Failed to upload activities');
        } else {
          debugPrint('Successfully uploaded ${activities.length} activities');
        }
      }

      // Fetch sleep data
      final sleepSessions = await _fetchSleepData(start, end);
      if (sleepSessions.isNotEmpty) {
        // Upload sleep data
        final sleepSuccess = await _apiService.uploadSleep(sleepSessions);
        if (!sleepSuccess) {
          debugPrint('Failed to upload sleep data');
        } else {
          debugPrint(
            'Successfully uploaded ${sleepSessions.length} sleep sessions',
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error fetching and uploading health data: $e');
      return false;
    }
  }

  /// Fetch and process workouts using chunked fetching for better reliability
  Future<List<Map<String, dynamic>>> _fetchAndProcessWorkouts(
    DateTime startDate,
    DateTime endDate,
  ) async {
    debugPrint(
      'Fetching workouts from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
    );

    try {
      // Get all workout data from health kit using chunked fetching
      final List<HealthDataPoint> workouts = [];

      // Try various chunk sizes - start with larger chunks
      final List<Duration> chunkSizes = [
        const Duration(days: 90), // 3 months
        const Duration(days: 30), // 1 month
        const Duration(days: 7), // 1 week
      ];

      bool foundWorkouts = false;

      for (final chunkSize in chunkSizes) {
        if (foundWorkouts) {
          break; // Skip if we already found workouts with larger chunks
        }

        debugPrint(
          'Trying workout fetch with chunk size: ${chunkSize.inDays} days',
        );

        // Break request into smaller chunks to ensure we get all data
        DateTime chunkStart = startDate;
        while (chunkStart.isBefore(endDate)) {
          // Calculate chunk end
          final chunkEnd = chunkStart.add(chunkSize);
          // Make sure we don't go past the end date
          final adjustedChunkEnd =
              chunkEnd.isAfter(endDate) ? endDate : chunkEnd;

          debugPrint(
            'Fetching workout chunk from ${chunkStart.toIso8601String()} to ${adjustedChunkEnd.toIso8601String()}',
          );

          try {
            final chunkData = await _health.getHealthDataFromTypes(
              chunkStart,
              adjustedChunkEnd,
              [HealthDataType.WORKOUT],
            );

            // Filter for workout data points
            final workoutChunk =
                chunkData
                    .where((dp) => dp.value is WorkoutHealthValue)
                    .toList();

            if (workoutChunk.isNotEmpty) {
              workouts.addAll(workoutChunk);
              foundWorkouts = true;
              debugPrint('Found ${workoutChunk.length} workouts in this chunk');
            }
          } catch (e) {
            debugPrint('Error fetching workout chunk: $e');
          }

          // Move to next chunk
          chunkStart = adjustedChunkEnd;
        }
      }

      if (workouts.isEmpty) {
        debugPrint('No workouts found after trying all chunk sizes');
        return [];
      }

      debugPrint('Found ${workouts.length} workouts in total');

      // Process workouts
      final processedWorkouts = <Map<String, dynamic>>[];

      for (final dataPoint in workouts) {
        // Skip if not a workout value
        if (dataPoint.value is! WorkoutHealthValue) {
          continue;
        }

        final workoutValue = dataPoint.value as WorkoutHealthValue;
        final rawWorkoutType = workoutValue.workoutActivityType.name;

        // Skip workouts with no duration
        if (dataPoint.dateTo.difference(dataPoint.dateFrom).inSeconds <= 0) {
          continue;
        }

        // Map RUNNING_SAND to RUNNING
        String normalizedWorkoutType = rawWorkoutType;
        if (rawWorkoutType.toUpperCase() == 'RUNNING_SAND') {
          normalizedWorkoutType = 'RUNNING';
          debugPrint('Mapped RUNNING_SAND to RUNNING');
        }

        // Create workout data map with normalized workout type
        final workoutData = {
          'id': dataPoint.dateFrom.millisecondsSinceEpoch.toString(),
          'workout_type': normalizedWorkoutType,
          'original_type': rawWorkoutType,
          'start_date': dataPoint.dateFrom.toIso8601String(),
          'end_date': dataPoint.dateTo.toIso8601String(),
          'duration_seconds':
              dataPoint.dateTo
                  .difference(dataPoint.dateFrom)
                  .inSeconds
                  .toDouble(),
          'active_energy_burned': workoutValue.totalEnergyBurned,
          'active_energy_burned_unit': 'kcal',
          'distance':
              workoutValue.totalDistance != null
                  ? workoutValue.totalDistance! / 1000
                  : null,
          'distance_unit': 'km',
          'source': 'Apple Health',
        };

        // Fetch heart rate data for this workout
        try {
          final heartRateData = await _fetchHeartRateForWorkout(
            dataPoint.dateFrom,
            dataPoint.dateTo,
          );

          if (heartRateData.isNotEmpty) {
            workoutData['heart_rate_summary'] = {
              'average': heartRateData['average'],
              'min': heartRateData['min'],
              'max': heartRateData['max'],
              'unit': 'bpm',
            };
          }
        } catch (e) {
          debugPrint('Error fetching heart rate for workout: $e');
        }

        // We're not calculating kilometer splits anymore
        // In the future, we'll use the native implementation to get this data
        // For now, we'll leave segment_data empty

        processedWorkouts.add(workoutData);
      }

      return processedWorkouts;
    } catch (e) {
      debugPrint('Error fetching workouts: $e');
      return [];
    }
  }

  /// Fetch heart rate data for a specific workout
  Future<Map<String, dynamic>> _fetchHeartRateForWorkout(
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final heartRateData = await _health.getHealthDataFromTypes(
        startTime,
        endTime,
        [HealthDataType.HEART_RATE],
      );

      if (heartRateData.isEmpty) {
        return {};
      }

      // Calculate min, max, and average heart rate
      double sum = 0;
      double min = double.infinity;
      double max = 0;

      for (final data in heartRateData) {
        if (data.value is NumericHealthValue) {
          final value =
              (data.value as NumericHealthValue).numericValue.toDouble();
          sum += value;
          min = value < min ? value : min;
          max = value > max ? value : max;
        }
      }

      final average = sum / heartRateData.length;

      return {
        'average': average,
        'min': min == double.infinity ? 0 : min,
        'max': max,
      };
    } catch (e) {
      debugPrint('Error fetching heart rate data: $e');
      return {};
    }
  }

  // We've removed the _fetchWorkoutSegmentData method since we're not using it anymore
  // In the future, we'll use the native implementation to get kilometer splits

  /// Fetch biometrics data
  Future<Map<String, dynamic>> _fetchBiometrics(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint('Fetching biometrics...');

      // Use BiometricsFetcher to get full body composition history
      final bodyCompositionData = await _biometricsFetcher
          .fetchAllBodyComposition(startDate, endDate);

      // Define vital signs types to fetch
      final vitalSignsTypes = [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.BLOOD_GLUCOSE,
        HealthDataType.RESPIRATORY_RATE,
        HealthDataType.BODY_TEMPERATURE,
      ];

      // Fetch vital signs data
      final vitalSignsData = <String, dynamic>{};

      for (final type in vitalSignsTypes) {
        try {
          final data = await _health.getHealthDataFromTypes(
            startDate,
            endDate,
            [type],
          );

          if (data.isEmpty) {
            continue;
          }

          // Sort by date (newest first)
          data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

          // Get the most recent value
          final latestData = data.first;

          // Map health data type to field name
          String fieldName;
          switch (type) {
            case HealthDataType.HEART_RATE:
              fieldName = 'heart_rate';
              break;
            case HealthDataType.RESTING_HEART_RATE:
              fieldName = 'resting_heart_rate';
              break;
            case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
              fieldName = 'blood_pressure_systolic';
              break;
            case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
              fieldName = 'blood_pressure_diastolic';
              break;
            case HealthDataType.BLOOD_OXYGEN:
              fieldName = 'blood_oxygen';
              break;
            case HealthDataType.BLOOD_GLUCOSE:
              fieldName = 'blood_glucose';
              break;
            case HealthDataType.RESPIRATORY_RATE:
              fieldName = 'respiratory_rate';
              break;
            case HealthDataType.BODY_TEMPERATURE:
              fieldName = 'body_temperature';
              break;
            default:
              continue;
          }

          // Add to vital signs data
          if (latestData.value is NumericHealthValue) {
            vitalSignsData[fieldName] = {
              'value':
                  (latestData.value as NumericHealthValue).numericValue
                      .toDouble(),
              'unit': latestData.unit.name,
              'timestamp': latestData.dateFrom.toIso8601String(),
              'source': 'Apple Health',
              'notes': null,
            };
          }
        } catch (e) {
          debugPrint('Error fetching ${type.name}: $e');
        }
      }

      // Create biometrics data
      final biometrics = <String, dynamic>{'user_id': _apiService.userId};

      // Add body composition data if found
      if (bodyCompositionData.isNotEmpty &&
          bodyCompositionData.containsKey('body_composition')) {
        biometrics['body_composition'] =
            bodyCompositionData['body_composition'];

        // Log how many weight records we have
        if (biometrics['body_composition'].containsKey('weight') &&
            biometrics['body_composition']['weight'].containsKey('history')) {
          final weightHistoryCount =
              biometrics['body_composition']['weight']['history'].length;
          debugPrint(
            'Including $weightHistoryCount weight records in biometrics data',
          );
        }
      }

      // Add vital signs data if not empty
      if (vitalSignsData.isNotEmpty) {
        biometrics['vital_signs'] = vitalSignsData;
      }

      return biometrics;
    } catch (e) {
      debugPrint('Error fetching biometrics: $e');
      return {};
    }
  }

  /// Fetch activity data using chunked fetching for better reliability
  Future<List<Map<String, dynamic>>> _fetchActivities(
    DateTime startDate,
    DateTime endDate,
  ) async {
    debugPrint(
      'Fetching activity data from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
    );

    try {
      // Define the types to fetch
      final activityTypes = [
        HealthDataType.STEPS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.FLIGHTS_CLIMBED,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.MOVE_MINUTES,
      ];

      // Create a map to store activity data by date
      final activityByDate = <String, Map<String, dynamic>>{};

      // Try various chunk sizes for fetching
      final List<Duration> chunkSizes = [
        const Duration(days: 90), // 3 months
        const Duration(days: 30), // 1 month
        const Duration(days: 7), // 1 week
      ];

      // Fetch data for each type
      for (final type in activityTypes) {
        debugPrint('Fetching activity data for ${type.name}');

        // Use chunked fetching for each activity type
        bool foundDataForType = false;

        for (final chunkSize in chunkSizes) {
          if (foundDataForType) {
            break; // Skip if we already found data with larger chunks
          }

          debugPrint(
            'Trying activity fetch with chunk size: ${chunkSize.inDays} days',
          );

          // Break request into smaller chunks
          DateTime chunkStart = startDate;

          while (chunkStart.isBefore(endDate)) {
            // Calculate chunk end
            final chunkEnd = chunkStart.add(chunkSize);
            // Make sure we don't go past the end date
            final adjustedChunkEnd =
                chunkEnd.isAfter(endDate) ? endDate : chunkEnd;

            try {
              final data = await _health.getHealthDataFromTypes(
                chunkStart,
                adjustedChunkEnd,
                [type],
              );

              if (data.isNotEmpty) {
                foundDataForType = true;
                debugPrint(
                  'Found ${data.length} ${type.name} records in chunk',
                );

                // Process each data point
                for (final point in data) {
                  // Extract date (YYYY-MM-DD)
                  final date = point.dateFrom.toIso8601String().split('T')[0];

                  // Create entry for this date if it doesn't exist
                  if (!activityByDate.containsKey(date)) {
                    activityByDate[date] = {
                      'date': date,
                      'source': 'Apple Health',
                    };
                  }

                  // Add data based on type
                  if (point.value is NumericHealthValue) {
                    final numericValue =
                        (point.value as NumericHealthValue).numericValue;

                    switch (type) {
                      case HealthDataType.STEPS:
                        // Sum steps for the day
                        final currentSteps =
                            activityByDate[date]!['steps'] ?? 0;
                        activityByDate[date]!['steps'] =
                            currentSteps + numericValue.toInt();
                        break;

                      case HealthDataType.DISTANCE_WALKING_RUNNING:
                        // Sum distance for the day (in km)
                        final currentDistance =
                            activityByDate[date]!['distance'] ?? 0.0;
                        activityByDate[date]!['distance'] =
                            currentDistance + numericValue.toDouble();
                        activityByDate[date]!['distance_unit'] = 'km';
                        break;

                      case HealthDataType.FLIGHTS_CLIMBED:
                        // Sum floors for the day
                        final currentFloors =
                            activityByDate[date]!['floors_climbed'] ?? 0;
                        activityByDate[date]!['floors_climbed'] =
                            currentFloors + numericValue.toInt();
                        break;

                      case HealthDataType.ACTIVE_ENERGY_BURNED:
                        // Sum active energy for the day
                        final currentEnergy =
                            activityByDate[date]!['active_energy_burned'] ??
                            0.0;
                        activityByDate[date]!['active_energy_burned'] =
                            currentEnergy + numericValue.toDouble();
                        activityByDate[date]!['active_energy_burned_unit'] =
                            'kcal';
                        break;

                      case HealthDataType.EXERCISE_TIME:
                        // Sum exercise minutes for the day (convert from seconds)
                        final currentExercise =
                            activityByDate[date]!['exercise_minutes'] ?? 0;
                        activityByDate[date]!['exercise_minutes'] =
                            currentExercise + (numericValue.toInt() ~/ 60);
                        break;

                      case HealthDataType.MOVE_MINUTES:
                        // Sum move minutes for the day (convert from seconds)
                        final currentMove =
                            activityByDate[date]!['move_minutes'] ?? 0;
                        activityByDate[date]!['move_minutes'] =
                            currentMove + (numericValue.toInt() ~/ 60);
                        break;

                      default:
                        break;
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Error fetching ${type.name} chunk: $e');
            }

            // Move to next chunk
            chunkStart = adjustedChunkEnd;
          }
        }
      }

      // Convert map to list
      final activities = activityByDate.values.toList();
      debugPrint('Processed activity data for ${activities.length} days');
      return activities;
    } catch (e) {
      debugPrint('Error fetching activity data: $e');
      return [];
    }
  }

  /// Fetch sleep data using chunked fetching for better reliability
  Future<List<Map<String, dynamic>>> _fetchSleepData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    debugPrint(
      'Fetching sleep data from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
    );

    try {
      // Define the types to fetch
      final sleepTypes = [
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
      ];

      // Fetch all sleep data
      final allSleepData = <HealthDataPoint>[];

      // Try various chunk sizes for fetching
      final List<Duration> chunkSizes = [
        const Duration(days: 90), // 3 months
        const Duration(days: 30), // 1 month
        const Duration(days: 7), // 1 week
      ];

      for (final type in sleepTypes) {
        debugPrint('Fetching sleep data for ${type.name}');

        // Use chunked fetching for each sleep type
        bool foundDataForType = false;

        for (final chunkSize in chunkSizes) {
          if (foundDataForType) {
            break; // Skip if we already found data with larger chunks
          }

          debugPrint(
            'Trying sleep fetch with chunk size: ${chunkSize.inDays} days',
          );

          // Break request into smaller chunks
          DateTime chunkStart = startDate;

          while (chunkStart.isBefore(endDate)) {
            // Calculate chunk end
            final chunkEnd = chunkStart.add(chunkSize);
            // Make sure we don't go past the end date
            final adjustedChunkEnd =
                chunkEnd.isAfter(endDate) ? endDate : chunkEnd;

            try {
              final data = await _health.getHealthDataFromTypes(
                chunkStart,
                adjustedChunkEnd,
                [type],
              );

              if (data.isNotEmpty) {
                allSleepData.addAll(data);
                foundDataForType = true;
                debugPrint(
                  'Found ${data.length} ${type.name} records in chunk',
                );
              }
            } catch (e) {
              debugPrint('Error fetching ${type.name} chunk: $e');
            }

            // Move to next chunk
            chunkStart = adjustedChunkEnd;
          }
        }
      }

      if (allSleepData.isEmpty) {
        debugPrint('No sleep data found after trying all chunk sizes');
        return [];
      }

      debugPrint('Found ${allSleepData.length} sleep records in total');

      // Sort by date
      allSleepData.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      // Process sleep data into sessions
      final sleepSessions = <Map<String, dynamic>>[];

      // Group by date
      final Map<String, List<HealthDataPoint>> sleepByDate = {};

      for (final point in allSleepData) {
        final date = point.dateFrom.toIso8601String().split('T')[0];
        if (!sleepByDate.containsKey(date)) {
          sleepByDate[date] = [];
        }
        sleepByDate[date]!.add(point);
      }

      // Process each date's sleep data
      for (final date in sleepByDate.keys) {
        final points = sleepByDate[date]!;

        // Calculate total sleep time and quality
        int totalSleepMinutes = 0;
        int inBedMinutes = 0;
        int awakeDuringMinutes = 0;

        for (final point in points) {
          final durationMinutes =
              point.dateTo.difference(point.dateFrom).inMinutes;

          if (point.type == HealthDataType.SLEEP_ASLEEP) {
            totalSleepMinutes += durationMinutes;
          } else if (point.type == HealthDataType.SLEEP_IN_BED) {
            inBedMinutes += durationMinutes;
          } else if (point.type == HealthDataType.SLEEP_AWAKE) {
            awakeDuringMinutes += durationMinutes;
          }
        }

        // Create sleep session entry
        final session = {
          'date': date,
          'source': 'Apple Health',
          'sleep_minutes': totalSleepMinutes,
          'in_bed_minutes': inBedMinutes,
          'awake_minutes': awakeDuringMinutes,
          'efficiency':
              inBedMinutes > 0
                  ? (totalSleepMinutes / inBedMinutes * 100).round()
                  : 0,
        };

        sleepSessions.add(session);
      }

      return sleepSessions;
    } catch (e) {
      debugPrint('Error fetching sleep data: $e');
      return [];
    }
  }

  /// Fetch workout history from Apple Health
  /// This method now tries to use the native implementation first for more accurate data
  Future<WorkoutHistory> fetchWorkoutHistory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Try to use the native implementation first
    try {
      // Use the native implementation which has more accurate kilometer splits
      return await fetchWorkoutHistoryWithNativeSplits(
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      debugPrint(
        'Native implementation failed, falling back to Flutter health package: $e',
      );
      // Fall back to the Flutter health package implementation
      return await _fetchWorkoutHistoryWithFlutterHealthPackage(
        startDate: startDate,
        endDate: endDate,
      );
    }
  }

  /// Fetch workout history using the Flutter health package (fallback method)
  Future<WorkoutHistory> _fetchWorkoutHistoryWithFlutterHealthPackage({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Ensure we have permissions
    final hasPermissions = await initialize();
    if (!hasPermissions) {
      debugPrint('Health data permissions not granted');
      return WorkoutHistory(
        workouts: [],
        userId: _apiService.userId ?? 'unknown',
        lastSyncTime: DateTime.now(),
      );
    }

    // Default to last year if no date range provided
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now;

    try {
      // Fetch workouts using the existing method
      final processedWorkouts = await _fetchAndProcessWorkouts(start, end);

      // Convert to Workout objects
      final workouts =
          processedWorkouts.map((workoutData) {
            return Workout(
              id: workoutData['id'] as String,
              workoutType: workoutData['workout_type'] as String,
              startTime: DateTime.parse(workoutData['start_date'] as String),
              endTime: DateTime.parse(workoutData['end_date'] as String),
              durationInSeconds:
                  (workoutData['duration_seconds'] as double).toInt(),
              energyBurned: workoutData['active_energy_burned'] as double? ?? 0,
              distance: workoutData['distance'] as double?,
              source: workoutData['source'] as String,
              segmentData: workoutData['segment_data'] as Map<String, dynamic>?,
              averageHeartRate:
                  workoutData['heart_rate_summary'] != null
                      ? (workoutData['heart_rate_summary']
                              as Map<String, dynamic>)['average']
                          as double?
                      : null,
              maxHeartRate:
                  workoutData['heart_rate_summary'] != null
                      ? (workoutData['heart_rate_summary']
                              as Map<String, dynamic>)['max']
                          as double?
                      : null,
            );
          }).toList();

      // Sort workouts by date (newest first)
      workouts.sort((a, b) => b.startTime.compareTo(a.startTime));

      return WorkoutHistory(
        workouts: workouts,
        userId: _apiService.userId ?? 'unknown',
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error fetching workout history: $e');
      return WorkoutHistory(
        workouts: [],
        userId: _apiService.userId ?? 'unknown',
        lastSyncTime: DateTime.now(),
      );
    }
  }

  /// Fetch a specific workout by ID
  Future<Workout?> fetchWorkoutById(String workoutId) async {
    try {
      debugPrint('Flutter: Fetching workout by ID: $workoutId');

      // Try to get the workout directly using the native API
      final splits = await getNativeKilometerSplits(workoutId);

      if (splits.isNotEmpty) {
        debugPrint('Flutter: Got ${splits.length} splits from native API');

        // If we got splits, we need to fetch the workout details
        // For now, we'll still need to fetch all workouts and find the matching one
        debugPrint('Flutter: Fetching workout history to find workout details');
        final history = await fetchWorkoutHistory();

        try {
          final workout = history.workouts.firstWhere(
            (workout) => workout.id == workoutId,
            orElse: () => throw Exception('Workout not found'),
          );

          debugPrint(
            'Flutter: Found workout: ${workout.workoutType}, adding splits',
          );

          // Add the splits to the workout
          if (workout.segmentData == null) {
            debugPrint(
              'Flutter: Creating new segment_data with kilometer_splits',
            );
            final updatedWorkout = workout.copyWith(
              segmentData: {'kilometer_splits': splits},
            );
            debugPrint(
              'Flutter: segment_data added: ${updatedWorkout.segmentData != null}',
            );
            return updatedWorkout;
          } else {
            debugPrint(
              'Flutter: Updating existing segment_data with kilometer_splits',
            );
            final updatedSegmentData = Map<String, dynamic>.from(
              workout.segmentData!,
            );
            updatedSegmentData['kilometer_splits'] = splits;
            final updatedWorkout = workout.copyWith(
              segmentData: updatedSegmentData,
            );
            debugPrint(
              'Flutter: segment_data updated: ${updatedWorkout.segmentData != null}',
            );
            return updatedWorkout;
          }
        } catch (e) {
          debugPrint('Flutter: Error finding workout in history: $e');
          rethrow;
        }
      } else {
        debugPrint(
          'Flutter: No splits from native API, falling back to regular method',
        );

        // Fall back to the regular method
        final history = await fetchWorkoutHistory();
        return history.workouts.firstWhere(
          (workout) => workout.id == workoutId,
          orElse: () => throw Exception('Workout not found'),
        );
      }
    } catch (e) {
      debugPrint('Flutter: Workout with ID $workoutId not found: $e');
      return null;
    }
  }

  /// Get heart rate data for a specific workout
  Future<List<HeartRateSample>> getHeartRateDataForWorkout(
    Workout workout,
  ) async {
    try {
      // Ensure we have permissions
      final hasPermissions = await initialize();
      if (!hasPermissions) {
        debugPrint('Health data permissions not granted');
        return [];
      }

      // Fetch heart rate data for the workout time range
      final heartRateData = await _health.getHealthDataFromTypes(
        workout.startTime,
        workout.endTime,
        [HealthDataType.HEART_RATE],
      );

      if (heartRateData.isEmpty) {
        return [];
      }

      // Convert to HeartRateSample objects
      final samples = <HeartRateSample>[];
      for (final data in heartRateData) {
        if (data.value is NumericHealthValue) {
          final value =
              (data.value as NumericHealthValue).numericValue.toDouble();
          // Calculate offset in seconds from workout start
          final offsetSeconds =
              data.dateFrom.difference(workout.startTime).inSeconds;
          samples.add(
            HeartRateSample(
              timestamp: data.dateFrom,
              value: value,
              workoutId: workout.id,
              offsetSeconds: offsetSeconds,
            ),
          );
        }
      }

      // Sort by timestamp
      samples.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return samples;
    } catch (e) {
      debugPrint('Error fetching heart rate data for workout: $e');
      return [];
    }
  }

  /// Get route data for a workout (if available)
  Future<List<Map<String, dynamic>>> getRouteDataForWorkout(
    Workout workout,
  ) async {
    // Note: This is a placeholder as route data is not directly available
    // through the health package. In a real implementation, you would need
    // to use a different API or package to access location data.
    return [];
  }

  /// Fetch all health data for debugging purposes
  /// Returns a map with counts of each data type
  Future<Map<String, int>> fetchAllHealthData({
    DateTime? startDate,
    DateTime? endDate,
    bool includeWorkoutDetails = true,
  }) async {
    // Ensure we have permissions
    final hasPermissions = await initialize();
    if (!hasPermissions) {
      debugPrint('Health data permissions not granted');
      return {'error': 1};
    }

    // Default to last year if no date range provided
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now;

    try {
      final results = <String, int>{};

      // Fetch workouts
      final workouts = await _fetchAndProcessWorkouts(start, end);
      results['workouts'] = workouts.length;

      // Fetch biometrics
      final biometrics = await _fetchBiometrics(start, end);
      if (biometrics.containsKey('body_composition')) {
        results['body_composition'] = 1;
      }
      if (biometrics.containsKey('vital_signs')) {
        results['vital_signs'] = 1;
      }

      // Fetch activity data
      final activities = await _fetchActivities(start, end);
      results['activities'] = activities.length;

      // Fetch sleep data
      final sleepSessions = await _fetchSleepData(start, end);
      results['sleep_sessions'] = sleepSessions.length;

      return results;
    } catch (e) {
      debugPrint('Error fetching all health data: $e');
      return {'error': 1};
    }
  }

  /// Fetch workout history with native kilometer splits
  /// This uses the native HealthKit API directly for more accurate data
  Future<WorkoutHistory> fetchWorkoutHistoryWithNativeSplits({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    debugPrint('Flutter: Fetching workout history with native splits');

    // Ensure we have permissions
    final hasPermissions = await initialize();
    if (!hasPermissions) {
      debugPrint('Flutter: Health data permissions not granted');
      return WorkoutHistory(
        workouts: [],
        userId: _apiService.userId ?? 'unknown',
        lastSyncTime: DateTime.now(),
      );
    }

    try {
      debugPrint('Flutter: Calling native getWorkoutsWithSplits');
      // Use the native channel to get workouts with splits
      final workoutsWithSplits = await _nativeHealthService
          .getWorkoutsWithSplits(startDate: startDate, endDate: endDate);

      debugPrint(
        'Flutter: Native returned ${workoutsWithSplits.length} workouts',
      );

      if (workoutsWithSplits.isEmpty) {
        debugPrint(
          'Flutter: No workouts found with native splits, falling back to regular method',
        );
        // Fall back to regular method if native method returns no data
        return _fetchWorkoutHistoryWithFlutterHealthPackage(
          startDate: startDate,
          endDate: endDate,
        );
      }

      // Convert to Workout objects
      final workouts =
          workoutsWithSplits.map((data) {
            return Workout(
              id: data['id'] as String,
              workoutType: data['workout_type'] as String,
              startTime: DateTime.parse(data['start_date'] as String),
              endTime: DateTime.parse(data['end_date'] as String),
              durationInSeconds: (data['duration_seconds'] as double).toInt(),
              energyBurned: data['active_energy_burned'] as double? ?? 0,
              distance: data['distance'] as double?,
              source: data['source'] as String,
              segmentData: data['segment_data'] as Map<String, dynamic>?,
              averageHeartRate:
                  data['heart_rate_summary'] != null
                      ? (data['heart_rate_summary']
                              as Map<String, dynamic>)['average']
                          as double?
                      : null,
              maxHeartRate:
                  data['heart_rate_summary'] != null
                      ? (data['heart_rate_summary']
                              as Map<String, dynamic>)['max']
                          as double?
                      : null,
            );
          }).toList();

      // Sort workouts by date (newest first)
      workouts.sort((a, b) => b.startTime.compareTo(a.startTime));

      debugPrint('Found ${workouts.length} workouts with native splits');

      return WorkoutHistory(
        workouts: workouts,
        userId: _apiService.userId ?? 'unknown',
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error fetching workout history with native splits: $e');
      // Fall back to regular method if native method fails
      return fetchWorkoutHistory(startDate: startDate, endDate: endDate);
    }
  }

  /// Get kilometer splits for a specific workout using native API
  /// This provides more accurate split data than the calculated method
  Future<List<Map<String, dynamic>>> getNativeKilometerSplits(
    String workoutId,
  ) async {
    try {
      debugPrint(
        'Flutter: Getting native kilometer splits for workout: $workoutId',
      );
      await initialize();
      final splits = await _nativeHealthService.getWorkoutKilometerSplits(
        workoutId,
      );
      debugPrint(
        'Flutter: Received ${splits.length} kilometer splits from native',
      );

      // Log the first split if available
      if (splits.isNotEmpty) {
        debugPrint('Flutter: First split: ${splits.first}');
      }

      return splits;
    } catch (e) {
      debugPrint('Flutter: Error fetching native kilometer splits: $e');
      return [];
    }
  }

  /// Calculate heart rate statistics from samples
  Map<String, double> calculateHeartRateStats(List<HeartRateSample> samples) {
    if (samples.isEmpty) {
      return {};
    }

    double sum = 0;
    double min = double.infinity;
    double max = 0;

    for (final sample in samples) {
      sum += sample.value;
      min = sample.value < min ? sample.value : min;
      max = sample.value > max ? sample.value : max;
    }

    final avg = sum / samples.length;

    return {'min': min == double.infinity ? 0 : min, 'avg': avg, 'max': max};
  }
}
