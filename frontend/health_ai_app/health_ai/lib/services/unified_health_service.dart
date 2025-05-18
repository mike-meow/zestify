import 'package:flutter/foundation.dart';
import 'package:health_ai/models/workout/workout.dart';
import 'package:health_ai/models/workout/heart_rate_sample.dart';
import 'package:health_ai/models/workout/workout_history.dart';
import 'package:health_ai/services/feature_flag_service.dart';
import 'package:health_ai/services/health_service.dart';
import 'package:health_ai/services/health_service_facade.dart';

/// Unified health service that uses either the original HealthService
/// or the new HealthServiceFacade based on feature flags
class UnifiedHealthService {
  static final UnifiedHealthService _instance =
      UnifiedHealthService._internal();

  /// Factory constructor to return the singleton instance
  factory UnifiedHealthService() => _instance;

  /// Private constructor for singleton pattern
  UnifiedHealthService._internal();

  /// Feature flag service
  final FeatureFlagService _featureFlagService = FeatureFlagService();

  /// Original health service
  final HealthService _originalHealthService = HealthService();

  /// New health service facade
  final HealthServiceFacade _newHealthServiceFacade = HealthServiceFacade();

  /// Whether the service is initialized
  bool _isInitialized = false;

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) {
      return _getActiveService().initialize();
    }

    try {
      // Initialize feature flag service
      await _featureFlagService.initialize();

      // Initialize both health services
      final originalResult = await _originalHealthService.initialize();
      final newResult = await _newHealthServiceFacade.initialize();

      _isInitialized = true;

      // Return the result from the active service
      return _featureFlagService.isEnabled('use_health_kit_reporter')
          ? newResult
          : originalResult;
    } catch (e) {
      debugPrint('Error initializing unified health service: $e');
      return false;
    }
  }

  /// Get the active health service based on feature flags
  dynamic _getActiveService() {
    return _featureFlagService.isEnabled('use_health_kit_reporter')
        ? _newHealthServiceFacade
        : _originalHealthService;
  }

  /// Fetch and upload health data directly to the server
  Future<bool> fetchAndUploadHealthData({
    DateTime? startDate,
    DateTime? endDate,
    bool includeWorkoutDetails = true,
  }) async {
    final activeService = _getActiveService();

    // Log which service is being used
    debugPrint(
      'Using ${activeService is HealthServiceFacade ? 'new' : 'original'} health service',
    );

    return activeService.fetchAndUploadHealthData(
      startDate: startDate,
      endDate: endDate,
      includeWorkoutDetails: includeWorkoutDetails,
    );
  }

  /// Fetch workout history
  Future<WorkoutHistory> fetchWorkoutHistory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final activeService = _getActiveService();

    // Log which service is being used
    debugPrint(
      'Using ${activeService is HealthServiceFacade ? 'new' : 'original'} health service',
    );

    return activeService.fetchWorkoutHistory(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Enable the new health service implementation
  Future<void> enableNewImplementation() async {
    await _featureFlagService.enableFeature('use_health_kit_reporter');
    debugPrint('New health service implementation enabled');
  }

  /// Disable the new health service implementation
  Future<void> disableNewImplementation() async {
    await _featureFlagService.disableFeature('use_health_kit_reporter');
    debugPrint('New health service implementation disabled');
  }

  /// Check if the new health service implementation is enabled
  bool isNewImplementationEnabled() {
    return _featureFlagService.isEnabled('use_health_kit_reporter');
  }

  /// Fetch all health data
  Future<Map<String, int>> fetchAllHealthData({
    DateTime? startDate,
    DateTime? endDate,
    bool includeWorkoutDetails = true,
  }) async {
    // For testing, we'll use the original health service for this method
    // since the new implementation doesn't support it yet
    return _originalHealthService.fetchAllHealthData(
      startDate: startDate,
      endDate: endDate,
      includeWorkoutDetails: includeWorkoutDetails,
    );
  }

  /// Fetch workout by ID
  Future<Workout?> fetchWorkoutById(String workoutId) async {
    final activeService = _getActiveService();

    // Log which service is being used
    debugPrint(
      'Using ${activeService is HealthServiceFacade ? 'new' : 'original'} health service',
    );

    return activeService.fetchWorkoutById(workoutId);
  }

  /// Get heart rate data for a workout
  Future<List<HeartRateSample>> getHeartRateDataForWorkout(
    Workout workout,
  ) async {
    final activeService = _getActiveService();

    // Log which service is being used
    debugPrint(
      'Using ${activeService is HealthServiceFacade ? 'new' : 'original'} health service',
    );

    return activeService.getHeartRateDataForWorkout(workout);
  }

  /// Get route data for a workout
  Future<List<Map<String, dynamic>>> getRouteDataForWorkout(
    Workout workout,
  ) async {
    final activeService = _getActiveService();

    // Log which service is being used
    debugPrint(
      'Using ${activeService is HealthServiceFacade ? 'new' : 'original'} health service',
    );

    return activeService.getRouteDataForWorkout(workout);
  }

  /// Calculate heart rate statistics
  Map<String, double> calculateHeartRateStats(List<HeartRateSample> samples) {
    final activeService = _getActiveService();

    // Log which service is being used
    debugPrint(
      'Using ${activeService is HealthServiceFacade ? 'new' : 'original'} health service',
    );

    return activeService.calculateHeartRateStats(samples);
  }
}
