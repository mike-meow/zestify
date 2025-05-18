import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service for accessing native HealthKit data directly through method channels
/// This provides more accurate data than the Flutter health package for certain metrics
class NativeHealthService {
  static final NativeHealthService _instance = NativeHealthService._internal();

  /// Factory constructor to return the singleton instance
  factory NativeHealthService() => _instance;

  /// Private constructor for singleton pattern
  NativeHealthService._internal();

  /// Method channel for communicating with native code
  static const MethodChannel _channel = MethodChannel(
    'com.healthai.health/native',
  );

  /// Whether the service is initialized
  bool _isInitialized = false;

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing native health service: $e');
      return false;
    }
  }

  /// Fetch kilometer splits for a specific workout
  /// Returns a list of kilometer split segments with pace data
  Future<List<Map<String, dynamic>>> getWorkoutKilometerSplits(
    String workoutId,
  ) async {
    try {
      debugPrint(
        'Flutter: Calling native getWorkoutKilometerSplits with ID: $workoutId',
      );
      final result = await _channel.invokeMethod('getWorkoutKilometerSplits', {
        'workoutId': workoutId,
      });

      if (result == null) {
        debugPrint('Flutter: Native returned null result for kilometer splits');
        return [];
      }

      final splits = List<Map<String, dynamic>>.from(result);
      debugPrint('Flutter: Native returned ${splits.length} kilometer splits');
      return splits;
    } catch (e) {
      debugPrint('Flutter: Error fetching native kilometer splits: $e');
      return [];
    }
  }

  /// Get all workouts with their kilometer splits
  /// This fetches workouts directly from HealthKit with accurate segment data
  Future<List<Map<String, dynamic>>> getWorkoutsWithSplits({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final result = await _channel.invokeMethod('getWorkoutsWithSplits', {
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      });

      if (result == null) return [];

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error fetching workouts with splits: $e');
      return [];
    }
  }
}
