import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/workout/workout.dart';
import '../models/workout/workout_history.dart';
import '../models/workout/heart_rate_sample.dart';
import '../models/workout/route_point.dart';

/// Service for storing and retrieving data from the file system
class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();

  /// Factory constructor to return the singleton instance
  factory FileStorageService() => _instance;

  /// Private constructor for singleton pattern
  FileStorageService._internal();

  /// Get the app's document directory
  Future<Directory> get _documentsDirectory async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get the health data directory, creating it if it doesn't exist
  Future<Directory> get _healthDataDirectory async {
    final documentsDir = await _documentsDirectory;
    final healthDir = Directory('${documentsDir.path}/health_data');

    if (!await healthDir.exists()) {
      await healthDir.create(recursive: true);
    }

    return healthDir;
  }

  /// Get the workouts directory, creating it if it doesn't exist
  Future<Directory> get _workoutsDirectory async {
    final healthDir = await _healthDataDirectory;
    final workoutsDir = Directory('${healthDir.path}/workouts');

    if (!await workoutsDir.exists()) {
      await workoutsDir.create(recursive: true);
    }

    return workoutsDir;
  }

  /// Get the heart rate data directory, creating it if it doesn't exist
  Future<Directory> get _heartRateDirectory async {
    final healthDir = await _healthDataDirectory;
    final heartRateDir = Directory('${healthDir.path}/heart_rate');

    if (!await heartRateDir.exists()) {
      await heartRateDir.create(recursive: true);
    }

    return heartRateDir;
  }

  /// Get the route data directory, creating it if it doesn't exist
  Future<Directory> get _routeDataDirectory async {
    final healthDir = await _healthDataDirectory;
    final routeDataDir = Directory('${healthDir.path}/route_data');

    if (!await routeDataDir.exists()) {
      await routeDataDir.create(recursive: true);
    }

    return routeDataDir;
  }

  /// Save workout history to a file
  Future<void> saveWorkoutHistory(WorkoutHistory workoutHistory) async {
    try {
      final healthDir = await _healthDataDirectory;
      final file = File('${healthDir.path}/workout_history.json');

      // Convert to JSON and save
      final jsonData = workoutHistory.toJson();
      await file.writeAsString(jsonEncode(jsonData));

      debugPrint('Workout history saved to ${file.path}');
    } catch (e) {
      debugPrint('Error saving workout history: $e');
    }
  }

  /// Save a single workout to a file
  Future<void> saveWorkout(Workout workout) async {
    try {
      final workoutsDir = await _workoutsDirectory;
      final file = File('${workoutsDir.path}/${workout.id}.json');

      // Convert to JSON and save
      final jsonData = workout.toJson();
      await file.writeAsString(jsonEncode(jsonData));

      debugPrint('Workout saved to ${file.path}');
    } catch (e) {
      debugPrint('Error saving workout: $e');
    }
  }

  /// Save heart rate samples for a workout
  Future<void> saveHeartRateSamples(
    String workoutId,
    List<HeartRateSample> samples,
  ) async {
    try {
      final heartRateDir = await _heartRateDirectory;
      final file = File('${heartRateDir.path}/${workoutId}_heart_rate.json');

      // Convert to JSON and save
      final jsonData = samples.map((sample) => sample.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonData));

      debugPrint('Heart rate data saved to ${file.path}');
    } catch (e) {
      debugPrint('Error saving heart rate data: $e');
    }
  }

  /// Save route points for a workout
  Future<void> saveRoutePoints(
    String workoutId,
    List<dynamic> routePoints,
  ) async {
    try {
      final routeDataDir = await _routeDataDirectory;
      final file = File('${routeDataDir.path}/${workoutId}_route.json');

      // Convert to JSON and save
      await file.writeAsString(jsonEncode(routePoints));

      debugPrint('Route data saved to ${file.path}');
    } catch (e) {
      debugPrint('Error saving route data: $e');
    }
  }

  /// Save raw health data (any type)
  Future<void> saveRawHealthData(String filename, dynamic data) async {
    try {
      final healthDir = await _healthDataDirectory;
      final file = File('${healthDir.path}/$filename.json');

      // Convert to JSON and save
      await file.writeAsString(jsonEncode(data));

      debugPrint('Raw health data saved to ${file.path}');
    } catch (e) {
      debugPrint('Error saving raw health data: $e');
    }
  }

  /// Load workout history from file
  Future<WorkoutHistory?> loadWorkoutHistory() async {
    try {
      final healthDir = await _healthDataDirectory;
      final file = File('${healthDir.path}/workout_history.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonData = jsonDecode(jsonString);
        return WorkoutHistory.fromJson(jsonData);
      }

      return null;
    } catch (e) {
      debugPrint('Error loading workout history: $e');
      return null;
    }
  }

  /// Load a single workout from file
  Future<Workout?> loadWorkout(String workoutId) async {
    try {
      final workoutsDir = await _workoutsDirectory;
      final file = File('${workoutsDir.path}/$workoutId.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonData = jsonDecode(jsonString);
        return Workout.fromJson(jsonData);
      }

      return null;
    } catch (e) {
      debugPrint('Error loading workout: $e');
      return null;
    }
  }

  /// Load heart rate samples for a workout
  Future<List<HeartRateSample>> loadHeartRateSamples(String workoutId) async {
    try {
      final heartRateDir = await _heartRateDirectory;
      final file = File('${heartRateDir.path}/${workoutId}_heart_rate.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final jsonData = jsonDecode(jsonString) as List;
        return jsonData.map((item) => HeartRateSample.fromJson(item)).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error loading heart rate data: $e');
      return [];
    }
  }

  /// Load route points for a workout
  Future<List<dynamic>> loadRoutePoints(String workoutId) async {
    try {
      final routeDataDir = await _routeDataDirectory;
      final file = File('${routeDataDir.path}/${workoutId}_route.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return jsonDecode(jsonString);
      }

      return [];
    } catch (e) {
      debugPrint('Error loading route data: $e');
      return [];
    }
  }

  /// Load raw health data (any type)
  Future<dynamic> loadRawHealthData(String filename) async {
    try {
      final healthDir = await _healthDataDirectory;
      final file = File('${healthDir.path}/$filename.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return jsonDecode(jsonString);
      }

      return null;
    } catch (e) {
      debugPrint('Error loading raw health data: $e');
      return null;
    }
  }

  /// Get a list of all saved files in the health data directory
  Future<Map<String, List<String>>> getFileList() async {
    final result = <String, List<String>>{};

    try {
      // Get main health data directory files
      final healthDir = await _healthDataDirectory;
      final healthFiles =
          await healthDir
              .list()
              .where((entity) => entity is File)
              .map((entity) => entity.path.split('/').last)
              .toList();
      result['health_data'] = healthFiles;

      // Get workout files
      final workoutsDir = await _workoutsDirectory;
      final workoutFiles =
          await workoutsDir
              .list()
              .where((entity) => entity is File)
              .map((entity) => entity.path.split('/').last)
              .toList();
      result['workouts'] = workoutFiles;

      // Get heart rate files
      final heartRateDir = await _heartRateDirectory;
      final heartRateFiles =
          await heartRateDir
              .list()
              .where((entity) => entity is File)
              .map((entity) => entity.path.split('/').last)
              .toList();
      result['heart_rate'] = heartRateFiles;

      // Get route data files
      final routeDataDir = await _routeDataDirectory;
      final routeDataFiles =
          await routeDataDir
              .list()
              .where((entity) => entity is File)
              .map((entity) => entity.path.split('/').last)
              .toList();
      result['route_data'] = routeDataFiles;
    } catch (e) {
      debugPrint('Error getting file list: $e');
    }

    return result;
  }

  /// Get the path to the health data directory (for external access)
  Future<String> getHealthDataDirectoryPath() async {
    final healthDir = await _healthDataDirectory;
    return healthDir.path;
  }

  /// List all health data files in the health data directory
  Future<List<String>> listHealthDataFiles() async {
    try {
      final healthDir = await _healthDataDirectory;
      final files =
          await healthDir
              .list()
              .where(
                (entity) => entity is File && entity.path.endsWith('.json'),
              )
              .map(
                (entity) => entity.path.split('/').last.replaceAll('.json', ''),
              )
              .toList();

      // Sort files by name (which often contains timestamps)
      files.sort();

      return files;
    } catch (e) {
      debugPrint('Error listing health data files: $e');
      return [];
    }
  }
}
