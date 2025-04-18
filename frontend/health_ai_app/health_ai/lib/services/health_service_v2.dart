import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_ai/services/api_service_v2.dart';
import 'package:health_ai/services/biometrics_fetcher.dart';

/// Source type for health data
enum SourceType { appleHealth, manual, device, other }

/// Service for interacting with Apple Health data
class HealthServiceV2 {
  static final HealthServiceV2 _instance = HealthServiceV2._internal();

  /// Factory constructor to return the singleton instance
  factory HealthServiceV2() => _instance;

  /// Private constructor for singleton pattern
  HealthServiceV2._internal();

  /// Health plugin instance
  final HealthFactory _health = HealthFactory();

  /// Biometrics fetcher for full health histories
  final BiometricsFetcher _biometricsFetcher = BiometricsFetcher();

  /// API service
  final ApiServiceV2 _apiService = ApiServiceV2();

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

  /// Map workout type from HealthKit to our API format
  String _mapWorkoutType(String healthKitWorkoutType) {
    // Map HealthKit workout types to our API workout types
    final Map<String, String> workoutTypeMap = {
      'RUNNING': 'Running',
      'WALKING': 'Walking',
      'CYCLING': 'Cycling',
      'SWIMMING': 'Swimming',
      'STRENGTH_TRAINING': 'Strength Training',
      'HIIT': 'HIIT',
      'YOGA': 'Yoga',
      'PILATES': 'Pilates',
      'DANCE': 'Dance',
      'HIKING': 'Hiking',
    };

    return workoutTypeMap[healthKitWorkoutType] ?? 'Other';
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
        if (foundWorkouts)
          break; // Skip if we already found workouts with larger chunks

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

        // Skip workouts with no duration
        if (dataPoint.dateTo.difference(dataPoint.dateFrom).inSeconds <= 0) {
          continue;
        }

        // Create a unique ID for the workout
        final workoutId =
            '${dataPoint.dateFrom.millisecondsSinceEpoch}_${workoutValue.workoutActivityType.name}';

        // Create workout data
        final workoutData = {
          'id': workoutId,
          'workout_type': _mapWorkoutType(
            workoutValue.workoutActivityType.name,
          ),
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
          if (foundDataForType)
            break; // Skip if we already found data with larger chunks

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
          if (foundDataForType)
            break; // Skip if we already found data with larger chunks

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
}
