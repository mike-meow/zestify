import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:path_provider/path_provider.dart';

/// Comprehensive health data downloader
/// 
/// This script downloads all available health data from Apple HealthKit
/// and saves it to the app's documents directory in a structured format.
/// 
/// Usage: flutter run bin/download_all_health_data.dart
void main() async {
  // Initialize Flutter binding for non-UI Flutter apps
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Health AI - Comprehensive Health Data Downloader');
  print('===============================================');
  
  final downloader = HealthDataDownloader();
  await downloader.initialize();
  await downloader.downloadAllHealthData();
}

/// Health data downloader class
class HealthDataDownloader {
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
    print('Initializing health service...');
    
    if (_isInitialized) return _hasPermissions;
    
    try {
      // Define the types to get permissions for - request all available types
      final types = allHealthDataTypes;
      
      // Request authorization
      _hasPermissions = await _health.requestAuthorization(types);
      _isInitialized = true;
      
      if (_hasPermissions) {
        print('Health data permissions granted.');
      } else {
        print('ERROR: Health data permissions NOT granted.');
        print('Please run the app first and grant permissions.');
      }
      
      return _hasPermissions;
    } catch (e) {
      print('Error initializing health service: $e');
      _isInitialized = false;
      _hasPermissions = false;
      return false;
    }
  }
  
  /// Get the health data directory, creating it if it doesn't exist
  Future<Directory> get healthDataDirectory async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final healthDir = Directory('${documentsDir.path}/health_data');
    
    if (!await healthDir.exists()) {
      await healthDir.create(recursive: true);
    }
    
    return healthDir;
  }
  
  /// Create a directory for a specific health data type
  Future<Directory> getDirectoryForType(String typeName) async {
    final baseDir = await healthDataDirectory;
    final typeDir = Directory('${baseDir.path}/${typeName.toLowerCase()}');
    
    if (!await typeDir.exists()) {
      await typeDir.create(recursive: true);
    }
    
    return typeDir;
  }
  
  /// Save data to a file
  Future<void> saveToFile(String filePath, dynamic data) async {
    try {
      final file = File(filePath);
      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
      print('Data saved to ${file.path}');
    } catch (e) {
      print('Error saving data to file: $e');
    }
  }
  
  /// Download all health data
  Future<Map<String, int>> downloadAllHealthData() async {
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        print('Error initializing health service: $e');
        return {'error': 1};
      }
    }
    
    if (!_hasPermissions) {
      print('Health data permissions not granted');
      return {'error': 2};
    }
    
    // Default to last 5 years to get as much historical data as possible
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 365 * 5));
    final endDate = now;
    
    print('\nDownloading health data from ${_formatDate(startDate)} to ${_formatDate(endDate)}');
    print('This may take a while depending on the amount of data...\n');
    
    final results = <String, int>{};
    final baseDir = await healthDataDirectory;
    
    // Save metadata about this download
    await saveToFile(
      '${baseDir.path}/download_metadata.json',
      {
        'downloadTime': now.toIso8601String(),
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );
    
    // Fetch data for each health data type
    for (final type in allHealthDataTypes) {
      try {
        print('Fetching health data for type: ${type.name}');
        
        // Skip workout type as we'll handle it separately with more detail
        if (type == HealthDataType.WORKOUT) {
          continue;
        }
        
        // Fetch data for this type
        final healthData = await _health.getHealthDataFromTypes(
          startDate,
          endDate,
          [type],
        );
        
        if (healthData.isNotEmpty) {
          // Create directory for this data type
          final typeDir = await getDirectoryForType(type.name);
          
          // Convert data to JSON format
          final jsonData = healthData.map((dataPoint) {
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
              item['value'] = (dataPoint.value as NumericHealthValue).numericValue;
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
          await saveToFile(
            '${typeDir.path}/${type.name.toLowerCase()}_data.json',
            jsonData,
          );
          
          // Update results
          results[type.name] = healthData.length;
          print('  - Downloaded ${healthData.length} records');
        } else {
          results[type.name] = 0;
          print('  - No data available');
        }
      } catch (e) {
        print('Error fetching health data for type ${type.name}: $e');
        results[type.name] = -1; // Error code
      }
    }
    
    // Handle workouts separately to get more detailed data
    await _downloadWorkoutData(startDate, endDate, results);
    
    // Print summary
    _printSummary(results);
    
    return results;
  }
  
  /// Download workout data with heart rate and route details
  Future<void> _downloadWorkoutData(
    DateTime startDate,
    DateTime endDate,
    Map<String, int> results,
  ) async {
    print('\nFetching workout data with details...');
    
    try {
      // Fetch workouts
      final healthData = await _health.getHealthDataFromTypes(
        startDate,
        endDate,
        [HealthDataType.WORKOUT],
      );
      
      if (healthData.isEmpty) {
        print('  - No workout data available');
        results['WORKOUT'] = 0;
        return;
      }
      
      // Create workout directory
      final workoutDir = await getDirectoryForType('workouts');
      final heartRateDir = await getDirectoryForType('heart_rate');
      final routeDir = await getDirectoryForType('route_data');
      
      // Process each workout
      final workouts = <Map<String, dynamic>>[];
      int heartRateCount = 0;
      int routePointCount = 0;
      
      for (final dataPoint in healthData) {
        if (dataPoint.value is WorkoutHealthValue) {
          final workoutValue = dataPoint.value as WorkoutHealthValue;
          
          // Create workout model
          final workout = {
            'id': dataPoint.sourceId,
            'type': workoutValue.workoutActivityType.name,
            'startTime': dataPoint.dateFrom.toIso8601String(),
            'endTime': dataPoint.dateTo.toIso8601String(),
            'durationInSeconds': dataPoint.dateTo.difference(dataPoint.dateFrom).inSeconds,
            'energyBurned': workoutValue.totalEnergyBurned,
            'distance': workoutValue.totalDistance,
            'source': dataPoint.sourceName,
            'metadata': {
              'sourceRevision': dataPoint.sourceId,
              'device': dataPoint.sourceName,
            },
          };
          
          workouts.add(workout);
          
          // Save individual workout
          await saveToFile(
            '${workoutDir.path}/${dataPoint.sourceId}.json',
            workout,
          );
          
          // Fetch heart rate data for this workout
          try {
            final heartRateData = await _health.getHealthDataFromTypes(
              dataPoint.dateFrom,
              dataPoint.dateTo,
              [HealthDataType.HEART_RATE],
            );
            
            if (heartRateData.isNotEmpty) {
              // Convert to heart rate samples
              final samples = heartRateData.map((hrPoint) {
                // Calculate offset in seconds from workout start
                final offsetSeconds = hrPoint.dateFrom.difference(dataPoint.dateFrom).inSeconds;
                
                // Extract the numeric value
                final numericValue = hrPoint.value is NumericHealthValue
                    ? (hrPoint.value as NumericHealthValue).numericValue
                    : 0.0;
                
                return {
                  'value': numericValue,
                  'timestamp': hrPoint.dateFrom.toIso8601String(),
                  'workoutId': dataPoint.sourceId,
                  'offsetSeconds': offsetSeconds,
                };
              }).toList();
              
              // Save heart rate data
              await saveToFile(
                '${heartRateDir.path}/${dataPoint.sourceId}_heart_rate.json',
                samples,
              );
              
              heartRateCount += samples.length;
              
              // Calculate heart rate stats
              if (samples.isNotEmpty) {
                double min = samples.first['value'];
                double max = samples.first['value'];
                double sum = 0;
                
                for (final sample in samples) {
                  final value = sample['value'];
                  if (value < min) min = value;
                  if (value > max) max = value;
                  sum += value;
                }
                
                // Add heart rate stats to workout
                workout['averageHeartRate'] = sum / samples.length;
                workout['maxHeartRate'] = max;
                workout['minHeartRate'] = min;
                
                // Update the saved workout with heart rate stats
                await saveToFile(
                  '${workoutDir.path}/${dataPoint.sourceId}.json',
                  workout,
                );
              }
            }
          } catch (e) {
            print('  - Error fetching heart rate data for workout ${dataPoint.sourceId}: $e');
          }
          
          // Generate route data for this workout
          try {
            // In a real implementation, you would fetch actual GPS data here
            // For now, we'll generate mock data based on the workout duration and distance
            
            // If no distance is available, we can't generate route data
            if (workoutValue.totalDistance != null && workoutValue.totalDistance > 0) {
              final routePoints = <Map<String, dynamic>>[];
              final startTime = dataPoint.dateFrom;
              final totalDuration = dataPoint.dateTo.difference(dataPoint.dateFrom).inSeconds;
              final totalDistance = workoutValue.totalDistance;
              
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
                
                // Calculate speed at this point (vary it a bit for realism)
                final speedFactor = 0.8 + 0.4 * (i % 3) / 2; // Varies between 0.8 and 1.2
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
              
              // Save route data
              await saveToFile(
                '${routeDir.path}/${dataPoint.sourceId}_route.json',
                routePoints,
              );
              
              routePointCount += routePoints.length;
            }
          } catch (e) {
            print('  - Error generating route data for workout ${dataPoint.sourceId}: $e');
          }
        }
      }
      
      // Save all workouts
      await saveToFile(
        '${workoutDir.path}/workout_history.json',
        {
          'workouts': workouts,
          'userId': 'current_user',
          'lastSyncTime': DateTime.now().toIso8601String(),
        },
      );
      
      results['WORKOUT'] = workouts.length;
      results['HEART_RATE_FOR_WORKOUTS'] = heartRateCount;
      results['ROUTE_DATA_FOR_WORKOUTS'] = routePointCount;
      
      print('  - Downloaded ${workouts.length} workouts');
      print('  - Downloaded $heartRateCount heart rate samples for workouts');
      print('  - Generated $routePointCount route points for workouts');
    } catch (e) {
      print('Error fetching workout data: $e');
      results['WORKOUT'] = -1;
    }
  }
  
  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// Print summary of downloaded data
  void _printSummary(Map<String, int> results) {
    // Group results by category
    final categories = {
      'Activity': [
        'STEPS', 'WORKOUT', 'ACTIVE_ENERGY_BURNED', 'BASAL_ENERGY_BURNED',
        'DISTANCE_WALKING_RUNNING', 'FLIGHTS_CLIMBED', 'MOVE_MINUTES',
        'EXERCISE_TIME',
      ],
      'Heart': [
        'HEART_RATE', 'RESTING_HEART_RATE', 'HEART_RATE_VARIABILITY_SDNN',
        'HIGH_HEART_RATE_EVENT', 'LOW_HEART_RATE_EVENT', 'IRREGULAR_HEART_RATE_EVENT',
        'HEART_RATE_FOR_WORKOUTS',
      ],
      'Body': [
        'HEIGHT', 'WEIGHT', 'BODY_MASS_INDEX', 'BODY_FAT_PERCENTAGE',
        'WAIST_CIRCUMFERENCE',
      ],
      'Health Metrics': [
        'BLOOD_GLUCOSE', 'BLOOD_OXYGEN', 'BLOOD_PRESSURE_DIASTOLIC',
        'BLOOD_PRESSURE_SYSTOLIC', 'BODY_TEMPERATURE', 'RESPIRATORY_RATE',
        'ELECTRODERMAL_ACTIVITY', 'WATER', 'MINDFULNESS',
      ],
      'Nutrition': [
        'DIETARY_ENERGY_CONSUMED',
      ],
      'Sleep': [
        'SLEEP_ASLEEP', 'SLEEP_AWAKE', 'SLEEP_IN_BED', 'SLEEP_DEEP',
        'SLEEP_REM', 'SLEEP_LIGHT', 'SLEEP_SESSION',
      ],
      'Other': [
        'ROUTE_DATA_FOR_WORKOUTS',
      ],
    };
    
    print('\n=== DOWNLOAD SUMMARY ===');
    
    // Print results by category
    categories.forEach((category, types) {
      print('\n$category:');
      
      bool hasData = false;
      for (final type in types) {
        if (results.containsKey(type)) {
          final count = results[type];
          if (count != null && count > 0) {
            hasData = true;
            print('  - $type: $count records');
          }
        }
      }
      
      if (!hasData) {
        print('  No data available');
      }
    });
    
    // Print errors if any
    final errors = results.entries.where((e) => e.value < 0);
    if (errors.isNotEmpty) {
      print('\nErrors:');
      for (final error in errors) {
        print('  - ${error.key}: Failed to fetch data');
      }
    }
    
    print('\nAll data has been saved to the app\'s documents directory.');
    print('You can access it at: /Documents/health_data/');
  }
}
