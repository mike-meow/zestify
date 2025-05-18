import 'package:flutter/foundation.dart';
import 'package:health_ai/services/api_service.dart';
import 'package:health_ai/services/health_kit_reporter_service.dart';
import 'package:health_ai/models/workout/workout.dart';
import 'package:health_ai/models/workout/workout_history.dart';

/// Facade for the HealthKitReporterService that provides the same interface as HealthService
class HealthServiceFacade {
  static final HealthServiceFacade _instance = HealthServiceFacade._internal();

  /// Factory constructor to return the singleton instance
  factory HealthServiceFacade() => _instance;

  /// Private constructor for singleton pattern
  HealthServiceFacade._internal();

  /// Health kit reporter service
  final HealthKitReporterService _healthKitReporterService =
      HealthKitReporterService();

  /// API service for uploading data
  final ApiService _apiService = ApiService();

  /// Whether the service is initialized
  bool _isInitialized = false;

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) {
      return _healthKitReporterService.hasPermissions;
    }

    try {
      // Initialize the health kit reporter service
      final hasPermissions = await _healthKitReporterService.initialize();

      _isInitialized = true;

      return hasPermissions;
    } catch (e) {
      debugPrint('Error initializing health service facade: $e');
      return false;
    }
  }

  /// Fetch and upload health data directly to the server
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

    try {
      // Fetch workout history
      final workoutHistory = await fetchWorkoutHistory(
        startDate: startDate,
        endDate: endDate,
      );

      // Upload workout history
      final workoutUploadResult = await _apiService.uploadWorkoutHistory(
        workoutHistory,
      );

      if (!workoutUploadResult) {
        debugPrint('Failed to upload workout history');
        return false;
      }

      // For now, we're only uploading workout data
      // In the future, we can add more data types

      return true;
    } catch (e) {
      debugPrint('Error fetching and uploading health data: $e');
      return false;
    }
  }

  /// Fetch workout history
  Future<WorkoutHistory> fetchWorkoutHistory({
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

    try {
      // Fetch workouts with detailed metrics
      final workoutMaps = await _healthKitReporterService.fetchWorkouts(
        startDate: startDate,
        endDate: endDate,
        includeDetailedMetrics: true,
      );
      
      // Convert Map<String, dynamic> to Workout objects
      final workouts = workoutMaps.map((workoutMap) => Workout.fromJson(workoutMap)).toList();
      
      // Return workout history
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

  /// Fetch workout by ID
  Future<Workout?> fetchWorkoutById(String workoutId) async {
    // Ensure we have permissions
    final hasPermissions = await initialize();
    if (!hasPermissions) {
      debugPrint('Health data permissions not granted');
      return null;
    }

    try {
      // Fetch all workouts
      final workouts = await _healthKitReporterService.fetchWorkouts(
        includeDetailedMetrics: true,
      );

      // Find the workout with the matching ID
      final workoutMap = workouts.firstWhere(
        (workout) => workout['id'] == workoutId,
        orElse: () => <String, dynamic>{},
      );

      if (workoutMap.isEmpty) {
        return null;
      }

      // Convert to Workout object
      return Workout.fromJson(workoutMap);
    } catch (e) {
      debugPrint('Error fetching workout by ID: $e');
      return null;
    }
  }

  /// Get heart rate data for a workout
  Future<List<Map<String, dynamic>>> getHeartRateDataForWorkout(
    Workout workout,
  ) async {
    // Ensure we have permissions
    final hasPermissions = await initialize();
    if (!hasPermissions) {
      debugPrint('Health data permissions not granted');
      return [];
    }

    try {
      // Fetch the workout with heart rate data
      final workoutWithHeartRate = await fetchWorkoutById(workout.id);

      if (workoutWithHeartRate == null) {
        return [];
      }

      // Extract heart rate data
      final heartRateData = workoutWithHeartRate.heartRateData ?? [];

      return heartRateData;
    } catch (e) {
      debugPrint('Error fetching heart rate data for workout: $e');
      return [];
    }
  }

  /// Get route data for a workout
  Future<List<Map<String, dynamic>>> getRouteDataForWorkout(
    Workout workout,
  ) async {
    // Ensure we have permissions
    final hasPermissions = await initialize();
    if (!hasPermissions) {
      debugPrint('Health data permissions not granted');
      return [];
    }

    try {
      // For now, we don't have a way to get route data directly
      // We could implement this in the future
      return [];
    } catch (e) {
      debugPrint('Error fetching route data for workout: $e');
      return [];
    }
  }

  /// Calculate heart rate statistics
  Map<String, double> calculateHeartRateStats(List<dynamic> samples) {
    try {
      if (samples.isEmpty) {
        return {
          'min': 0,
          'max': 0,
          'avg': 0,
        };
      }

      // Check if we have a summary already
      if (samples.first is Map<String, dynamic> &&
          samples.first.containsKey('summary')) {
        final summary = samples.first['summary'];
        return {
          'min': summary['min']?.toDouble() ?? 0,
          'max': summary['max']?.toDouble() ?? 0,
          'avg': summary['average']?.toDouble() ?? 0,
        };
      }

      // Calculate manually
      double min = double.infinity;
      double max = 0;
      double sum = 0;

      for (final sample in samples) {
        if (sample is Map<String, dynamic> && sample.containsKey('value')) {
          final value = sample['value'].toDouble();
          min = min > value ? value : min;
          max = max < value ? value : max;
          sum += value;
        }
      }

      return {
        'min': min == double.infinity ? 0 : min,
        'max': max,
        'avg': samples.isEmpty ? 0 : sum / samples.length,
      };
    } catch (e) {
      debugPrint('Error calculating heart rate stats: $e');
      return {
        'min': 0,
        'max': 0,
        'avg': 0,
      };
    }
  }
}
