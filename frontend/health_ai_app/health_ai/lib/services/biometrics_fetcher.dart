import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:http/http.dart' as http;

/// Utility class to fetch biometrics data from Apple Health with full history
class BiometricsFetcher {
  // Health plugin instance
  final HealthFactory _health = HealthFactory();

  /// Directly upload weight data to the server for debugging
  Future<bool> directUploadWeightHistory(
    String userId,
    String baseUrl,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint('*** DIRECT WEIGHT UPLOAD MODE ***');
      debugPrint('Fetching and directly uploading weight history');

      // First fetch the weight data
      final weightData = await fetchWeightHistory(startDate, endDate);
      if (weightData.isEmpty || !weightData.containsKey('weight')) {
        debugPrint('No weight data found to upload');
        return false;
      }

      // Get the weight data
      final weight = weightData['weight'];
      final history = weight['history'] as List;

      if (history.isEmpty) {
        debugPrint('Weight history is empty');
        return false;
      }

      // Get the most recent entry for the current value
      final mostRecent = history[0];
      final oldestEntry = history[history.length - 1];
      final middleIndex1 = history.length ~/ 3;
      final middleIndex2 = (history.length * 2) ~/ 3;

      // Print detailed debug information
      debugPrint('======== WEIGHT DATA SUBMISSION DETAILS ========');
      debugPrint(
        'Current weight: ${weight['value']} ${weight['unit']} @ ${weight['timestamp']}',
      );
      debugPrint('Total weight history records: ${history.length}');
      debugPrint(
        'Weight data spans: ${oldestEntry['timestamp']} to ${mostRecent['timestamp']}',
      );
      debugPrint('=== Sample of weight history entries ===');
      debugPrint(
        'Oldest entry: ${oldestEntry['value']} ${oldestEntry['unit']} @ ${oldestEntry['timestamp']}',
      );
      debugPrint(
        'Newest entry: ${mostRecent['value']} ${mostRecent['unit']} @ ${mostRecent['timestamp']}',
      );
      if (history.length > 2) {
        debugPrint(
          'Middle entry 1: ${history[middleIndex1]['value']} ${history[middleIndex1]['unit']} @ ${history[middleIndex1]['timestamp']}',
        );
        debugPrint(
          'Middle entry 2: ${history[middleIndex2]['value']} ${history[middleIndex2]['unit']} @ ${history[middleIndex2]['timestamp']}',
        );
      }
      debugPrint('================================================');

      // Create the biometrics data structure in the format expected by the server
      final biometricsData = {
        'user_id': userId,
        'body_composition': {
          'weight': {
            'value': mostRecent['value'],
            'unit': mostRecent['unit'],
            'timestamp': mostRecent['timestamp'],
            'source': mostRecent['source'],
            'notes': null,
            'history': history,
          },
        },
      };

      // Print the request body length for debugging
      final requestBody = jsonEncode(biometricsData);
      debugPrint('Biometrics request body length: ${requestBody.length}');

      debugPrint(
        'Directly uploading ${history.length} weight records to the server',
      );
      debugPrint('Request body: ${jsonEncode(biometricsData)}');

      // Upload the data
      final response = await http.post(
        Uri.parse('$baseUrl/biometrics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(biometricsData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Biometrics uploaded directly: ${data['metrics_received']}');
        return true;
      } else {
        debugPrint(
          'Error uploading biometrics directly: ${response.statusCode}',
        );
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error in direct upload: $e');
      return false;
    }
  }

  /// Fetch complete weight history from Apple Health
  Future<Map<String, dynamic>> fetchWeightHistory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint(
        'Fetching weight history from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
      );

      // Get all weight data from health kit
      final List<HealthDataPoint> weightDataPoints = [];

      // Always use small chunks to ensure we get ALL data points
      // Don't stop after finding data with larger chunks
      final List<Duration> chunkSizes = [
        const Duration(days: 90), // 3 months
        const Duration(days: 30), // 1 month
        const Duration(days: 7), // 1 week
      ];

      // Use all chunk sizes to ensure complete coverage
      for (final chunkSize in chunkSizes) {
        debugPrint('Fetching with chunk size: ${chunkSize.inDays} days');

        // Break request into smaller chunks to ensure we get all data
        DateTime chunkStart = startDate;
        while (chunkStart.isBefore(endDate)) {
          // Calculate chunk end
          final chunkEnd = chunkStart.add(chunkSize);
          // Make sure we don't go past the end date
          final adjustedChunkEnd =
              chunkEnd.isAfter(endDate) ? endDate : chunkEnd;

          debugPrint(
            'Fetching weight chunk from ${chunkStart.toIso8601String()} to ${adjustedChunkEnd.toIso8601String()}',
          );

          try {
            final chunkData = await _health.getHealthDataFromTypes(
              chunkStart,
              adjustedChunkEnd,
              [HealthDataType.WEIGHT],
            );

            if (chunkData.isNotEmpty) {
              weightDataPoints.addAll(chunkData);
              debugPrint(
                'Found ${chunkData.length} weight records in this chunk',
              );
            }
          } catch (e) {
            debugPrint('Error fetching weight chunk: $e');
          }

          // Move to next chunk
          chunkStart = adjustedChunkEnd;
        }
      }

      // Try direct access methods as backup
      if (weightDataPoints.isEmpty) {
        debugPrint('Trying direct access as backup');

        try {
          final directData = await _health.getHealthDataFromTypes(
            startDate,
            endDate,
            [HealthDataType.WEIGHT],
          );

          if (directData.isNotEmpty) {
            weightDataPoints.addAll(directData);
            debugPrint(
              'Found ${directData.length} weight records with direct access',
            );
          }
        } catch (e) {
          debugPrint('Error with direct access: $e');
        }
      }

      // If still empty, try with sample query
      if (weightDataPoints.isEmpty) {
        try {
          debugPrint('Trying with default weight sample query');

          final now = DateTime.now();
          final threeYearsAgo = now.subtract(const Duration(days: 365 * 3));

          final sampleData = await _health.getHealthDataFromTypes(
            threeYearsAgo,
            now,
            [HealthDataType.WEIGHT],
          );

          if (sampleData.isNotEmpty) {
            weightDataPoints.addAll(sampleData);
            debugPrint(
              'Found ${sampleData.length} weight records with sample query',
            );
          }
        } catch (e) {
          debugPrint('Error with sample query: $e');
        }
      }

      // Remove any duplicates
      final Map<String, HealthDataPoint> uniquePoints = {};
      for (final dp in weightDataPoints) {
        if (dp.value is NumericHealthValue) {
          final key =
              '${dp.dateFrom.toIso8601String()}_${(dp.value as NumericHealthValue).numericValue}';
          uniquePoints[key] = dp;
        }
      }
      weightDataPoints.clear();
      weightDataPoints.addAll(uniquePoints.values);

      if (weightDataPoints.isEmpty) {
        debugPrint('No weight data found after all queries');
        return {};
      }

      debugPrint(
        'Found ${weightDataPoints.length} total unique weight measurements',
      );

      // Sort by date (newest first for convenient access, but we'll include all data)
      weightDataPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

      // Process all weight data points
      final List<Map<String, dynamic>> weightHistory = [];

      // Debug: print out all weight records with timestamps for debugging
      debugPrint('===== WEIGHT RECORDS FOUND =====');
      for (int i = 0; i < weightDataPoints.length; i++) {
        final point = weightDataPoints[i];
        if (point.value is NumericHealthValue) {
          final value =
              (point.value as NumericHealthValue).numericValue.toDouble();
          final timestamp = point.dateFrom.toIso8601String();

          // Only log some of the records to avoid flooding the console
          if (i < 10 || i > weightDataPoints.length - 10 || i % 10 == 0) {
            debugPrint(
              'Weight record #$i: $value ${point.unit.name} @ $timestamp',
            );
          }

          weightHistory.add({
            'value': value,
            'unit': point.unit.name,
            'timestamp': timestamp,
            'source': 'Apple Health',
            'notes': null,
          });
        }
      }
      debugPrint('===== END WEIGHT RECORDS =====');

      // If we still have no weight history, something is wrong with the data conversion
      if (weightHistory.isEmpty) {
        debugPrint(
          'ERROR: Found health data points but failed to convert them to weight history',
        );
        return {};
      }

      debugPrint(
        'Successfully processed ${weightHistory.length} weight records into history',
      );

      // Get the most recent weight as current value
      final latestData = weightDataPoints.first;
      double currentValue = 0;
      if (latestData.value is NumericHealthValue) {
        currentValue =
            (latestData.value as NumericHealthValue).numericValue.toDouble();
      }

      return {
        'weight': {
          'value': currentValue,
          'unit': latestData.unit.name,
          'timestamp': latestData.dateFrom.toIso8601String(),
          'source': 'Apple Health',
          'notes': null,
          'history': weightHistory,
        },
      };
    } catch (e) {
      debugPrint('Error fetching weight history: $e');
      return {};
    }
  }

  /// Fetch complete height history
  Future<Map<String, dynamic>> fetchHeightHistory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint(
        'Fetching height history from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
      );

      final heightData = await _health.getHealthDataFromTypes(
        startDate,
        endDate,
        [HealthDataType.HEIGHT],
      );

      if (heightData.isEmpty) {
        debugPrint('No height data found');
        return {};
      }

      debugPrint('Found ${heightData.length} height measurements');

      // Sort by date (newest first for convenient access, but we'll include all data)
      heightData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

      // Process all height data points
      final List<Map<String, dynamic>> heightHistory = [];

      for (final point in heightData) {
        if (point.value is NumericHealthValue) {
          heightHistory.add({
            'value':
                (point.value as NumericHealthValue).numericValue.toDouble(),
            'unit': point.unit.name,
            'timestamp': point.dateFrom.toIso8601String(),
            'source': 'Apple Health',
            'notes': null,
          });
        }
      }

      // Get the most recent height as current value
      final latestData = heightData.first;
      double currentValue = 0;
      if (latestData.value is NumericHealthValue) {
        currentValue =
            (latestData.value as NumericHealthValue).numericValue.toDouble();
      }

      return {
        'height': {
          'value': currentValue,
          'unit': latestData.unit.name,
          'timestamp': latestData.dateFrom.toIso8601String(),
          'source': 'Apple Health',
          'notes': null,
          'history': heightHistory,
        },
      };
    } catch (e) {
      debugPrint('Error fetching height history: $e');
      return {};
    }
  }

  /// Fetch complete body fat percentage history
  Future<Map<String, dynamic>> fetchBodyFatHistory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      debugPrint(
        'Fetching body fat history from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
      );

      final bodyFatData = await _health.getHealthDataFromTypes(
        startDate,
        endDate,
        [HealthDataType.BODY_FAT_PERCENTAGE],
      );

      if (bodyFatData.isEmpty) {
        debugPrint('No body fat data found');
        return {};
      }

      debugPrint('Found ${bodyFatData.length} body fat measurements');

      // Sort by date (newest first for convenient access, but we'll include all data)
      bodyFatData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

      // Process all body fat data points
      final List<Map<String, dynamic>> bodyFatHistory = [];

      for (final point in bodyFatData) {
        if (point.value is NumericHealthValue) {
          bodyFatHistory.add({
            'value':
                (point.value as NumericHealthValue).numericValue.toDouble(),
            'unit': point.unit.name,
            'timestamp': point.dateFrom.toIso8601String(),
            'source': 'Apple Health',
            'notes': null,
          });
        }
      }

      // Get the most recent body fat as current value
      final latestData = bodyFatData.first;
      double currentValue = 0;
      if (latestData.value is NumericHealthValue) {
        currentValue =
            (latestData.value as NumericHealthValue).numericValue.toDouble();
      }

      return {
        'body_fat_percentage': {
          'value': currentValue,
          'unit': latestData.unit.name,
          'timestamp': latestData.dateFrom.toIso8601String(),
          'source': 'Apple Health',
          'notes': null,
          'history': bodyFatHistory,
        },
      };
    } catch (e) {
      debugPrint('Error fetching body fat history: $e');
      return {};
    }
  }

  /// Fetch all body composition metrics with full history
  Future<Map<String, dynamic>> fetchAllBodyComposition(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final Map<String, dynamic> bodyComposition = {};

    // Fetch weight history
    final weightData = await fetchWeightHistory(startDate, endDate);
    if (weightData.isNotEmpty && weightData.containsKey('weight')) {
      bodyComposition['weight'] = weightData['weight'];
    }

    // Fetch height history
    final heightData = await fetchHeightHistory(startDate, endDate);
    if (heightData.isNotEmpty && heightData.containsKey('height')) {
      bodyComposition['height'] = heightData['height'];
    }

    // Fetch body fat history
    final bodyFatData = await fetchBodyFatHistory(startDate, endDate);
    if (bodyFatData.isNotEmpty &&
        bodyFatData.containsKey('body_fat_percentage')) {
      bodyComposition['body_fat_percentage'] =
          bodyFatData['body_fat_percentage'];
    }

    // Log what we found
    debugPrint(
      'Found body composition data: ${bodyComposition.keys.join(', ')}',
    );

    return {'body_composition': bodyComposition};
  }
}
