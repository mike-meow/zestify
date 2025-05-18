import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health_ai/models/workout/workout_history.dart';
import 'package:health_ai/services/health_service.dart';
import 'package:health_ai/services/health_service_facade.dart';
import 'package:path_provider/path_provider.dart';

/// Service for collecting telemetry data to compare
/// the original and new health service implementations
class HealthTelemetryService {
  static final HealthTelemetryService _instance = HealthTelemetryService._internal();

  /// Factory constructor to return the singleton instance
  factory HealthTelemetryService() => _instance;

  /// Private constructor for singleton pattern
  HealthTelemetryService._internal();

  /// Original health service
  final HealthService _originalHealthService = HealthService();

  /// New health service facade
  final HealthServiceFacade _newHealthServiceFacade = HealthServiceFacade();

  /// Whether the service is initialized
  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize both health services
      await _originalHealthService.initialize();
      await _newHealthServiceFacade.initialize();
      
      _isInitialized = true;
      debugPrint('Health telemetry service initialized');
    } catch (e) {
      debugPrint('Error initializing health telemetry service: $e');
    }
  }

  /// Collect telemetry data by comparing the results from both implementations
  Future<Map<String, dynamic>> collectTelemetryData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 7)); // Use a shorter period for telemetry
    final end = endDate ?? now;

    debugPrint('Collecting telemetry data from ${start.toIso8601String()} to ${end.toIso8601String()}');

    try {
      // Collect data from both implementations
      final originalStartTime = DateTime.now();
      final originalWorkoutHistory = await _originalHealthService.fetchWorkoutHistory(
        startDate: start,
        endDate: end,
      );
      final originalEndTime = DateTime.now();
      final originalDuration = originalEndTime.difference(originalStartTime);

      final newStartTime = DateTime.now();
      final newWorkoutHistory = await _newHealthServiceFacade.fetchWorkoutHistory(
        startDate: start,
        endDate: end,
      );
      final newEndTime = DateTime.now();
      final newDuration = newEndTime.difference(newStartTime);

      // Compare the results
      final telemetryData = {
        'timestamp': DateTime.now().toIso8601String(),
        'date_range': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
        'original_implementation': {
          'duration_ms': originalDuration.inMilliseconds,
          'workout_count': originalWorkoutHistory.workouts.length,
          'has_kilometer_splits': _countWorkoutsWithKilometerSplits(originalWorkoutHistory),
          'has_heart_rate_data': _countWorkoutsWithHeartRateData(originalWorkoutHistory),
        },
        'new_implementation': {
          'duration_ms': newDuration.inMilliseconds,
          'workout_count': newWorkoutHistory.workouts.length,
          'has_kilometer_splits': _countWorkoutsWithKilometerSplits(newWorkoutHistory),
          'has_heart_rate_data': _countWorkoutsWithHeartRateData(newWorkoutHistory),
        },
      };

      // Save telemetry data to file
      await _saveTelemetryData(telemetryData);

      return telemetryData;
    } catch (e) {
      debugPrint('Error collecting telemetry data: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Count workouts with kilometer splits
  int _countWorkoutsWithKilometerSplits(WorkoutHistory workoutHistory) {
    return workoutHistory.workouts
        .where((workout) => 
            workout.containsKey('kilometer_splits') && 
            workout['kilometer_splits'] is List && 
            (workout['kilometer_splits'] as List).isNotEmpty)
        .length;
  }

  /// Count workouts with heart rate data
  int _countWorkoutsWithHeartRateData(WorkoutHistory workoutHistory) {
    return workoutHistory.workouts
        .where((workout) => 
            (workout.containsKey('heart_rate_data') && 
             workout['heart_rate_data'] is List && 
             (workout['heart_rate_data'] as List).isNotEmpty) ||
            workout.containsKey('heart_rate_summary'))
        .length;
  }

  /// Save telemetry data to file
  Future<void> _saveTelemetryData(Map<String, dynamic> telemetryData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/health_telemetry.json');
      
      // Read existing data if file exists
      List<dynamic> existingData = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          existingData = jsonDecode(content) as List<dynamic>;
        }
      }
      
      // Add new data
      existingData.add(telemetryData);
      
      // Write data back to file
      await file.writeAsString(jsonEncode(existingData));
      
      debugPrint('Telemetry data saved to ${file.path}');
    } catch (e) {
      debugPrint('Error saving telemetry data: $e');
    }
  }
}
