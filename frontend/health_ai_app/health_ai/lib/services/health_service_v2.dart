import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_ai/services/api_service_v2.dart';

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

  // No file storage service needed for V2

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

    // Default to last week if no date range provided (for faster iteration)
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 7));
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

  /// Fetch and process workouts
  Future<List<Map<String, dynamic>>> _fetchAndProcessWorkouts(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint('Fetching workouts...');
      final healthData = await _health.getHealthDataFromTypes(
        startDate,
        endDate,
        [HealthDataType.WORKOUT],
      );

      // Filter for workout data points
      final workouts =
          healthData.where((dp) => dp.value is WorkoutHealthValue).toList();

      if (workouts.isEmpty) {
        debugPrint('No workouts found');
        return [];
      }

      debugPrint('Found ${workouts.length} workouts');

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

      // Define the types to fetch
      final bodyCompositionTypes = [
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.BODY_MASS_INDEX,
        HealthDataType.BODY_FAT_PERCENTAGE,
      ];

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

      // Fetch body composition data
      final bodyCompositionData = <String, dynamic>{};

      for (final type in bodyCompositionTypes) {
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
            case HealthDataType.WEIGHT:
              fieldName = 'weight';
              break;
            case HealthDataType.HEIGHT:
              fieldName = 'height';
              break;
            case HealthDataType.BODY_MASS_INDEX:
              fieldName = 'bmi';
              break;
            case HealthDataType.BODY_FAT_PERCENTAGE:
              fieldName = 'body_fat_percentage';
              break;
            default:
              continue;
          }

          // Add to body composition data
          if (latestData.value is NumericHealthValue) {
            bodyCompositionData[fieldName] = {
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

      // Add body composition data if not empty
      if (bodyCompositionData.isNotEmpty) {
        biometrics['body_composition'] = bodyCompositionData;
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

  /// Fetch activity data
  Future<List<Map<String, dynamic>>> _fetchActivities(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint('Fetching activity data...');

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

      // Fetch data for each type
      for (final type in activityTypes) {
        try {
          final data = await _health.getHealthDataFromTypes(
            startDate,
            endDate,
            [type],
          );

          if (data.isEmpty) {
            continue;
          }

          // Process each data point
          for (final point in data) {
            // Extract date (YYYY-MM-DD)
            final date = point.dateFrom.toIso8601String().split('T')[0];

            // Create entry for this date if it doesn't exist
            if (!activityByDate.containsKey(date)) {
              activityByDate[date] = {'date': date, 'source': 'Apple Health'};
            }

            // Add data based on type
            switch (type) {
              case HealthDataType.STEPS:
                // Sum steps for the day
                final currentSteps = activityByDate[date]!['steps'] ?? 0;
                if (point.value is NumericHealthValue) {
                  activityByDate[date]!['steps'] =
                      currentSteps +
                      (point.value as NumericHealthValue).numericValue.toInt();
                }
                break;
              case HealthDataType.DISTANCE_WALKING_RUNNING:
                // Sum distance for the day
                final currentDistance =
                    activityByDate[date]!['distance'] ?? 0.0;
                if (point.value is NumericHealthValue) {
                  activityByDate[date]!['distance'] =
                      currentDistance +
                      (point.value as NumericHealthValue).numericValue
                          .toDouble();
                  activityByDate[date]!['distance_unit'] = 'km';
                }
                break;
              case HealthDataType.FLIGHTS_CLIMBED:
                // Sum floors for the day
                final currentFloors =
                    activityByDate[date]!['floors_climbed'] ?? 0;
                if (point.value is NumericHealthValue) {
                  activityByDate[date]!['floors_climbed'] =
                      currentFloors +
                      (point.value as NumericHealthValue).numericValue.toInt();
                }
                break;
              case HealthDataType.ACTIVE_ENERGY_BURNED:
                // Sum active energy for the day
                final currentEnergy =
                    activityByDate[date]!['active_energy_burned'] ?? 0.0;
                if (point.value is NumericHealthValue) {
                  activityByDate[date]!['active_energy_burned'] =
                      currentEnergy +
                      (point.value as NumericHealthValue).numericValue
                          .toDouble();
                  activityByDate[date]!['active_energy_burned_unit'] = 'kcal';
                }
                break;
              case HealthDataType.EXERCISE_TIME:
                // Sum exercise minutes for the day
                final currentExercise =
                    activityByDate[date]!['exercise_minutes'] ?? 0;
                if (point.value is NumericHealthValue) {
                  activityByDate[date]!['exercise_minutes'] =
                      currentExercise +
                      ((point.value as NumericHealthValue).numericValue
                              .toInt() ~/
                          60);
                }
                break;
              case HealthDataType.MOVE_MINUTES:
                // Sum move minutes for the day
                final currentMove = activityByDate[date]!['move_minutes'] ?? 0;
                if (point.value is NumericHealthValue) {
                  activityByDate[date]!['move_minutes'] =
                      currentMove +
                      ((point.value as NumericHealthValue).numericValue
                              .toInt() ~/
                          60);
                }
                break;
              default:
                break;
            }
          }
        } catch (e) {
          debugPrint('Error fetching ${type.name}: $e');
        }
      }

      // Convert map to list
      final activities = activityByDate.values.toList();

      return activities;
    } catch (e) {
      debugPrint('Error fetching activity data: $e');
      return [];
    }
  }

  /// Fetch sleep data
  Future<List<Map<String, dynamic>>> _fetchSleepData(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint('Fetching sleep data...');

      // Define the types to fetch
      final sleepTypes = [
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
      ];

      // Fetch all sleep data
      final allSleepData = <HealthDataPoint>[];

      for (final type in sleepTypes) {
        try {
          final data = await _health.getHealthDataFromTypes(
            startDate,
            endDate,
            [type],
          );

          if (data.isNotEmpty) {
            allSleepData.addAll(data);
          }
        } catch (e) {
          debugPrint('Error fetching ${type.name}: $e');
        }
      }

      if (allSleepData.isEmpty) {
        return [];
      }

      // Sort by date
      allSleepData.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

      // Group sleep data into sessions
      final sleepSessions = <Map<String, dynamic>>[];
      Map<String, dynamic>? currentSession;

      for (final data in allSleepData) {
        // Skip invalid data
        if (data.dateFrom.isAfter(data.dateTo)) {
          continue;
        }

        // Check if this is a new session
        if (currentSession == null ||
            data.dateFrom
                    .difference(DateTime.parse(currentSession['end_date']))
                    .inMinutes >
                60) {
          // Save previous session if it exists
          if (currentSession != null) {
            sleepSessions.add(currentSession);
          }

          // Create a new session
          currentSession = {
            'id': data.dateFrom.millisecondsSinceEpoch.toString(),
            'start_date': data.dateFrom.toIso8601String(),
            'end_date': data.dateTo.toIso8601String(),
            'source': 'Apple Health',
            'sleep_stages': [],
          };
        } else {
          // Update end date if this data point extends the session
          if (data.dateTo.isAfter(DateTime.parse(currentSession['end_date']))) {
            currentSession['end_date'] = data.dateTo.toIso8601String();
          }
        }

        // Add sleep stage
        String stageType;
        switch (data.type) {
          case HealthDataType.SLEEP_ASLEEP:
            stageType = 'ASLEEP';
            break;
          case HealthDataType.SLEEP_AWAKE:
            stageType = 'AWAKE';
            break;
          case HealthDataType.SLEEP_IN_BED:
            stageType = 'IN_BED';
            break;
          default:
            stageType = 'UNKNOWN';
        }

        (currentSession['sleep_stages'] as List).add({
          'stage_type': stageType,
          'start_date': data.dateFrom.toIso8601String(),
          'end_date': data.dateTo.toIso8601String(),
          'duration_minutes': data.dateTo.difference(data.dateFrom).inMinutes,
        });
      }

      // Add the last session
      if (currentSession != null) {
        sleepSessions.add(currentSession);
      }

      // Calculate total sleep duration for each session
      for (final session in sleepSessions) {
        final startDate = DateTime.parse(session['start_date']);
        final endDate = DateTime.parse(session['end_date']);
        session['duration_minutes'] = endDate.difference(startDate).inMinutes;

        // Calculate sleep quality metrics
        double asleepMinutes = 0;
        double awakeMinutes = 0;
        double inBedMinutes = 0;

        for (final stage in session['sleep_stages']) {
          switch (stage['stage_type']) {
            case 'ASLEEP':
              asleepMinutes += stage['duration_minutes'];
              break;
            case 'AWAKE':
              awakeMinutes += stage['duration_minutes'];
              break;
            case 'IN_BED':
              inBedMinutes += stage['duration_minutes'];
              break;
          }
        }

        session['asleep_minutes'] = asleepMinutes;
        session['awake_minutes'] = awakeMinutes;
        session['in_bed_minutes'] = inBedMinutes;

        // Calculate sleep efficiency (time asleep / time in bed)
        final totalInBed = asleepMinutes + awakeMinutes + inBedMinutes;
        if (totalInBed > 0) {
          session['sleep_efficiency'] = (asleepMinutes / totalInBed) * 100;
        }
      }

      return sleepSessions;
    } catch (e) {
      debugPrint('Error fetching sleep data: $e');
      return [];
    }
  }
}
