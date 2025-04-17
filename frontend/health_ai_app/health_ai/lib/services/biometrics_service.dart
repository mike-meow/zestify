import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'file_storage_service.dart';
import 'health_service.dart';

/// Service for processing biometrics data
class BiometricsService {
  static final BiometricsService _instance = BiometricsService._internal();

  /// Factory constructor to return the singleton instance
  factory BiometricsService() => _instance;

  /// Private constructor for singleton pattern
  BiometricsService._internal();

  /// Health service instance
  final HealthService _healthService = HealthService();

  /// File storage service instance
  final FileStorageService _fileStorage = FileStorageService();

  /// Prepare biometrics data for upload
  Future<Map<String, dynamic>> prepareBiometricsData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Ensure we have permissions
    final hasPermissions = await _healthService.initialize();
    if (!hasPermissions) {
      debugPrint('Health data permissions not granted');
      return {};
    }

    // Default to last year if no date range provided
    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 365));
    final end = endDate ?? now;

    // Fetch all health data
    final healthData = await _healthService.fetchAllHealthData(
      startDate: start,
      endDate: end,
      includeWorkoutDetails: true,
    );

    // Load the raw health data files
    final rawHealthData = await _loadRawHealthData();
    
    // Process the data into biometrics format
    final biometricsData = _processHealthData(rawHealthData);

    // Save a copy locally
    await _fileStorage.saveRawHealthData(
      'biometrics_upload_${DateTime.now().millisecondsSinceEpoch}',
      biometricsData,
    );

    return biometricsData;
  }

  /// Load raw health data from files
  Future<Map<String, dynamic>> _loadRawHealthData() async {
    try {
      // Get list of health data files
      final fileList = await _fileStorage.listHealthDataFiles();
      
      // Find the most recent file
      if (fileList.isEmpty) {
        return {};
      }
      
      // Sort by timestamp (newest first)
      fileList.sort((a, b) => b.compareTo(a));
      
      // Load the most recent file
      final mostRecentFile = fileList.first;
      final rawData = await _fileStorage.loadRawHealthData(mostRecentFile);
      
      return rawData;
    } catch (e) {
      debugPrint('Error loading raw health data: $e');
      return {};
    }
  }

  /// Process health data into biometrics format
  Map<String, dynamic> _processHealthData(Map<String, dynamic> rawData) {
    final biometrics = <String, dynamic>{};
    
    try {
      // Extract heart rate data
      if (rawData.containsKey('data_points') && 
          rawData['data_points'] is Map &&
          rawData['data_points'].containsKey('HEART_RATE')) {
        
        final heartRateData = rawData['data_points']['HEART_RATE'];
        if (heartRateData is List && heartRateData.isNotEmpty) {
          // Calculate average heart rate
          double sum = 0;
          for (final data in heartRateData) {
            if (data is Map && data.containsKey('value')) {
              sum += double.tryParse(data['value'].toString()) ?? 0;
            }
          }
          final average = sum / heartRateData.length;
          
          biometrics['heart_rate'] = {
            'daily_average': {
              'current': average,
              'unit': 'bpm',
              'history': heartRateData.map((data) {
                return {
                  'value': double.tryParse(data['value'].toString()) ?? 0,
                  'timestamp': data['date_from'],
                  'source': data['source_name'] ?? 'Apple Health',
                };
              }).toList(),
            }
          };
        }
      }
      
      // Extract sleep data
      if (rawData.containsKey('data_points') && 
          rawData['data_points'] is Map &&
          rawData['data_points'].containsKey('SLEEP_ASLEEP')) {
        
        final sleepData = rawData['data_points']['SLEEP_ASLEEP'];
        if (sleepData is List && sleepData.isNotEmpty) {
          // Calculate average sleep duration
          double totalDuration = 0;
          for (final data in sleepData) {
            if (data is Map && data.containsKey('date_from') && data.containsKey('date_to')) {
              final from = DateTime.parse(data['date_from'].toString());
              final to = DateTime.parse(data['date_to'].toString());
              final duration = to.difference(from).inMinutes / 60; // Convert to hours
              totalDuration += duration;
            }
          }
          final average = totalDuration / sleepData.length;
          
          biometrics['sleep'] = {
            'total_duration': {
              'current': average,
              'unit': 'hours',
              'history': sleepData.map((data) {
                final from = DateTime.parse(data['date_from'].toString());
                final to = DateTime.parse(data['date_to'].toString());
                final duration = to.difference(from).inMinutes / 60; // Convert to hours
                
                return {
                  'value': duration,
                  'timestamp': data['date_from'],
                  'source': data['source_name'] ?? 'Apple Health',
                };
              }).toList(),
            }
          };
        }
      }
      
      // Extract weight data
      if (rawData.containsKey('data_points') && 
          rawData['data_points'] is Map &&
          rawData['data_points'].containsKey('WEIGHT')) {
        
        final weightData = rawData['data_points']['WEIGHT'];
        if (weightData is List && weightData.isNotEmpty) {
          // Sort by date (newest first)
          weightData.sort((a, b) {
            final dateA = DateTime.parse(a['date_from'].toString());
            final dateB = DateTime.parse(b['date_from'].toString());
            return dateB.compareTo(dateA);
          });
          
          // Get the most recent weight
          final latestWeight = weightData.first;
          final weightValue = double.tryParse(latestWeight['value'].toString()) ?? 0;
          
          if (!biometrics.containsKey('body_composition')) {
            biometrics['body_composition'] = {};
          }
          
          biometrics['body_composition']['weight'] = {
            'current': weightValue,
            'unit': 'kg',
            'history': weightData.map((data) {
              return {
                'value': double.tryParse(data['value'].toString()) ?? 0,
                'timestamp': data['date_from'],
                'source': data['source_name'] ?? 'Apple Health',
              };
            }).toList(),
          };
        }
      }
      
      // Extract activity data (steps)
      if (rawData.containsKey('data_points') && 
          rawData['data_points'] is Map &&
          rawData['data_points'].containsKey('STEPS')) {
        
        final stepsData = rawData['data_points']['STEPS'];
        if (stepsData is List && stepsData.isNotEmpty) {
          // Calculate average steps
          double sum = 0;
          for (final data in stepsData) {
            if (data is Map && data.containsKey('value')) {
              sum += double.tryParse(data['value'].toString()) ?? 0;
            }
          }
          final average = sum / stepsData.length;
          
          if (!biometrics.containsKey('activity')) {
            biometrics['activity'] = {};
          }
          
          biometrics['activity']['steps'] = {
            'current': average.round(),
            'unit': 'steps',
            'history': stepsData.map((data) {
              return {
                'value': double.tryParse(data['value'].toString())?.round() ?? 0,
                'timestamp': data['date_from'],
                'source': data['source_name'] ?? 'Apple Health',
              };
            }).toList(),
          };
        }
      }
      
      // Extract workouts data
      if (rawData.containsKey('workouts') && rawData['workouts'] is List) {
        final workouts = rawData['workouts'];
        if (workouts.isNotEmpty) {
          // Include workouts in the biometrics data
          biometrics['workouts'] = workouts;
        }
      }
      
    } catch (e) {
      debugPrint('Error processing health data: $e');
    }
    
    return biometrics;
  }
}
