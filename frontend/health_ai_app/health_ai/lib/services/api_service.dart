import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for communicating with the backend API
/// This version uses the API endpoints with user_id in the request body
class ApiService {
  static final ApiService _instance = ApiService._internal();

  /// Factory constructor to return the singleton instance
  factory ApiService() => _instance;

  /// Private constructor for singleton pattern
  ApiService._internal();

  /// Base URL for the API
  String? _baseUrl;

  /// User ID for API calls
  String? _userId;

  /// Initialize the API service with the server URL
  Future<bool> initialize({String? serverUrl}) async {
    try {
      // If serverUrl is provided, use it
      if (serverUrl != null && serverUrl.isNotEmpty) {
        _baseUrl = serverUrl;

        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('api_server_url', serverUrl);

        debugPrint('API service initialized with URL: $_baseUrl');
        return true;
      }

      // Otherwise, try to load from preferences
      final prefs = await SharedPreferences.getInstance();
      _baseUrl = prefs.getString('api_server_url');
      _userId = prefs.getString('user_id');

      if (_baseUrl != null && _baseUrl!.isNotEmpty) {
        debugPrint(
          'API service initialized with URL from preferences: $_baseUrl',
        );
        return true;
      }

      debugPrint('API service not initialized: No server URL provided');
      return false;
    } catch (e) {
      debugPrint('Error initializing API service: $e');
      return false;
    }
  }

  /// Check if the API service is initialized
  bool get isInitialized => _baseUrl != null && _baseUrl!.isNotEmpty;

  /// Get the base URL
  String? get baseUrl => _baseUrl;

  /// Get the user ID
  String? get userId => _userId;

  /// Set the user ID
  Future<void> setUserId(String userId) async {
    _userId = userId;

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);

    debugPrint('User ID set: $_userId');
  }

  /// Check if the server is reachable
  Future<bool> checkServerHealth() async {
    if (!isInitialized) {
      debugPrint('API service not initialized');
      return false;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'));

      if (response.statusCode == 200) {
        debugPrint('Server health check successful');
        return true;
      } else {
        debugPrint('Server health check failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error checking server health: $e');
      return false;
    }
  }

  /// Create a new user
  Future<String?> createUser({String? name, String? email}) async {
    if (!isInitialized) {
      debugPrint('API service not initialized');
      return null;
    }

    try {
      // Generate a unique user ID
      final userId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create request body
      final requestBody = {'user_id': userId, 'name': name, 'email': email};

      final response = await http.post(
        Uri.parse('$_baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userId = data['user_id'];

        // Save the user ID
        await setUserId(userId);

        debugPrint('User created: $userId');
        return userId;
      } else {
        debugPrint('Error creating user: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating user: $e');
      return null;
    }
  }

  /// Upload biometrics data to the server
  Future<bool> uploadBiometrics(Map<String, dynamic> biometricsData) async {
    if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    try {
      // Wrap the data according to the API definition
      final requestData = {
        'user_id': _userId,
        'data': biometricsData, // Embed the original data under 'data' key
      };

      _logWeightHistoryDetails(
        biometricsData,
      ); // Log details from original data

      final requestBody = jsonEncode(requestData);
      debugPrint('Biometrics request body length: ${requestBody.length}');
      // debugPrint('Biometrics request body: $requestBody'); // Uncomment for debugging

      final response = await http.post(
        Uri.parse('$_baseUrl/biometrics'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Biometrics uploaded: ${data['metrics_received']}');
        return true;
      } else {
        debugPrint('Error uploading biometrics: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading biometrics: $e');
      return false;
    }
  }

  /// Log detailed information about weight history
  void _logWeightHistoryDetails(Map<String, dynamic> biometrics) {
    try {
      if (biometrics.containsKey('body_composition') &&
          biometrics['body_composition'] is Map &&
          biometrics['body_composition'].containsKey('weight')) {
        final weight = biometrics['body_composition']['weight'];
        debugPrint('======== WEIGHT DATA SUBMISSION DETAILS ========');
        debugPrint(
          'Current weight: ${weight['value']} ${weight['unit']} @ ${weight['timestamp']}',
        );

        if (weight.containsKey('history') && weight['history'] is List) {
          final history = weight['history'] as List;
          debugPrint('Total weight history records: ${history.length}');

          if (history.isEmpty) {
            debugPrint('WARNING: Weight history array is empty!');
            return;
          }

          // Check if history is actually a proper list of maps
          if (history.first is! Map) {
            debugPrint(
              'ERROR: Weight history items are not maps! Type: ${history.first.runtimeType}',
            );
            return;
          }

          // Sort history by date to see the range
          final List sortedHistory = List.from(history);
          sortedHistory.sort((a, b) {
            final aTime = a['timestamp'] ?? '';
            final bTime = b['timestamp'] ?? '';
            return aTime.compareTo(bTime);
          });

          // Log the date range
          final oldestEntry = sortedHistory.first;
          final newestEntry = sortedHistory.last;
          final dateRange =
              '${oldestEntry['timestamp']} to ${newestEntry['timestamp']}';
          debugPrint('Weight data spans: $dateRange');

          // Log a sample of entries from different time periods
          debugPrint('=== Sample of weight history entries ===');

          // Get the first entry
          debugPrint(
            'Oldest entry: ${oldestEntry['value']} ${oldestEntry['unit']} @ ${oldestEntry['timestamp']}',
          );

          // Get the most recent entry
          debugPrint(
            'Newest entry: ${newestEntry['value']} ${newestEntry['unit']} @ ${newestEntry['timestamp']}',
          );

          // Get some entries in the middle if there are enough
          if (history.length >= 4) {
            final middle1Index = history.length ~/ 3;
            final middle2Index = (history.length * 2) ~/ 3;

            final middle1 = sortedHistory[middle1Index];
            final middle2 = sortedHistory[middle2Index];

            debugPrint(
              'Middle entry 1: ${middle1['value']} ${middle1['unit']} @ ${middle1['timestamp']}',
            );
            debugPrint(
              'Middle entry 2: ${middle2['value']} ${middle2['unit']} @ ${middle2['timestamp']}',
            );
          }

          // Check for duplicate timestamps
          final Set<String> timestamps = {};
          int duplicates = 0;

          for (final entry in history) {
            final timestamp = entry['timestamp'];
            if (timestamps.contains(timestamp)) {
              duplicates++;
            } else {
              timestamps.add(timestamp);
            }
          }

          if (duplicates > 0) {
            debugPrint(
              'WARNING: Found $duplicates duplicate timestamps in weight history',
            );
          }

          // Check for valid structure on all entries
          int malformedEntries = 0;

          for (final entry in history) {
            if (!entry.containsKey('value') ||
                !entry.containsKey('timestamp') ||
                !entry.containsKey('unit')) {
              malformedEntries++;
            } else if (entry['value'] is! num) {
              malformedEntries++;
              debugPrint(
                'ERROR: Weight value is not a number: ${entry['value']} (${entry['value'].runtimeType})',
              );
            }
          }

          if (malformedEntries > 0) {
            debugPrint(
              'WARNING: Found $malformedEntries malformed entries in weight history',
            );
          }

          debugPrint('================================================');
        } else {
          debugPrint('ERROR: No weight history found in weight data structure');
          debugPrint('Weight data keys: ${weight.keys.join(', ')}');
        }
      } else {
        debugPrint('ERROR: No weight data found in body composition');
        if (biometrics.containsKey('body_composition')) {
          debugPrint(
            'Body composition keys: ${biometrics['body_composition'].keys.join(', ')}',
          );
        } else {
          debugPrint('No body_composition key in biometrics');
          debugPrint('Biometrics keys: ${biometrics.keys.join(', ')}');
        }
      }
    } catch (e) {
      debugPrint('Error logging weight history: $e');
    }
  }

  /// Upload consolidated health data to the server
  /// This method distributes the data to the appropriate endpoints
  Future<bool> uploadHealthData(Map<String, dynamic> healthData) async {
    if (!isInitialized) {
      debugPrint('API service not initialized');
      return false;
    }

    if (_userId == null) {
      debugPrint('No user ID available');
      return false;
    }

    try {
      debugPrint('Processing consolidated health data for upload...');
      bool success = true;

      // Process workouts if available
      if (healthData.containsKey('workouts') &&
          healthData['workouts'] is List &&
          healthData['workouts'].isNotEmpty) {
        final workouts = List<Map<String, dynamic>>.from(
          healthData['workouts'],
        );
        final workoutSuccess = await uploadWorkouts(workouts);
        if (!workoutSuccess) {
          debugPrint('Failed to upload workouts');
          success = false;
        }
      }

      // Process biometrics if available
      if (healthData.containsKey('metrics') &&
          healthData['metrics'] is Map &&
          healthData['metrics'].isNotEmpty) {
        // Convert metrics to biometrics format
        final biometrics = _convertMetricsToBiometrics(healthData['metrics']);
        if (biometrics.isNotEmpty) {
          final biometricsSuccess = await uploadBiometrics(biometrics);
          if (!biometricsSuccess) {
            debugPrint('Failed to upload biometrics');
            success = false;
          }
        }
      }

      // Process activity data if available
      if (healthData.containsKey('activity') &&
          healthData['activity'] is Map &&
          healthData['activity'].isNotEmpty) {
        final activities = _extractActivities(healthData['activity']);
        if (activities.isNotEmpty) {
          final activitySuccess = await uploadActivities(activities);
          if (!activitySuccess) {
            debugPrint('Failed to upload activities');
            success = false;
          }
        }
      }

      // Process sleep data if available
      if (healthData.containsKey('sleep') &&
          healthData['sleep'] is List &&
          healthData['sleep'].isNotEmpty) {
        final sleepSessions = List<Map<String, dynamic>>.from(
          healthData['sleep'],
        );
        final sleepSuccess = await uploadSleep(sleepSessions);
        if (!sleepSuccess) {
          debugPrint('Failed to upload sleep data');
          success = false;
        }
      }

      return success;
    } catch (e) {
      debugPrint('Error processing and uploading health data: $e');
      return false;
    }
  }

  // --- Deprecated Memory Update Endpoints ---
  // These directly manipulated memory files, which is now handled by the main upload endpoints.
  // Mark them as deprecated or remove if no longer used.

  @Deprecated(
    'Use specific upload endpoints like uploadBiometrics, uploadWorkouts, etc.',
  )
  Future<bool> updateHealthMetrics(Map<String, dynamic> metrics) async {
    debugPrint(
      'DEPRECATED: updateHealthMetrics called. Use specific upload endpoints.',
    );
    // Optionally, try to map `metrics` to a specific upload call if possible.
    // For now, return false or attempt a legacy call if one exists.
    return false;
  }

  @Deprecated('Use uploadBiometrics instead.')
  Future<bool> updateBiometrics(Map<String, dynamic> biometrics) async {
    debugPrint(
      'DEPRECATED: updateBiometrics called. Use uploadBiometrics instead.',
    );
    // Forward to the new uploadBiometrics method
    return uploadBiometrics(biometrics);
  }

  @Deprecated('Use uploadWorkout or uploadWorkouts instead.')
  Future<bool> addWorkout(Map<String, dynamic> workout) async {
    debugPrint('DEPRECATED: addWorkout called. Use uploadWorkout instead.');
    // Create the structure expected by the new single workout endpoint
    final requestData = {'user_id': _userId, 'workout': workout};

    if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    try {
      final url = '$_baseUrl/workouts'; // Use the new endpoint
      debugPrint('[Legacy API Shim] Adding workout via /workouts...');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData), // Send wrapped data
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Workout added (via shim): ${data['message']}');
        return true;
      } else {
        debugPrint('Error adding workout (via shim): ${response.statusCode}');
        debugPrint('Error response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error adding workout (via shim): $e');
      return false;
    }
  }

  // --- Deprecated Chunk Upload Endpoint ---
  @Deprecated(
    'Use specific batch upload endpoints like uploadWorkouts, uploadActivities etc.',
  )
  Future<bool> uploadHealthDataChunk(
    String dataType,
    List<dynamic> dataChunk,
  ) async {
    debugPrint(
      'DEPRECATED: uploadHealthDataChunk called. Use specific batch upload endpoints.',
    );
    // Determine the correct batch endpoint based on dataType and call it.
    // Example:
    // if (dataType == 'WORKOUT') {
    //   return uploadWorkouts(List<Map<String, dynamic>>.from(dataChunk));
    // } else if (dataType == 'ACTIVITY') { ... }
    // For now, return false.
    return false;
  }

  /// Upload a single workout to the server
  Future<bool> uploadWorkout(Map<String, dynamic> workoutData) async {
    if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    try {
      // Wrap the data according to the API definition
      final requestData = {
        'user_id': _userId,
        'workout': workoutData, // Use 'workout' key as per API definition
      };

      final requestBody = jsonEncode(requestData);
      // debugPrint('Workout request body: $requestBody'); // Uncomment for debugging

      final response = await http.post(
        Uri.parse('$_baseUrl/workouts'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Workout uploaded: ${data['workout_id']}');
        return true;
      } else {
        debugPrint('Error uploading workout: ${response.statusCode}');
        debugPrint('Response body: ${response.body}'); // Log error response
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading workout: $e');
      return false;
    }
  }

  /// Upload multiple workouts to the server
  Future<bool> uploadWorkouts(List<Map<String, dynamic>> workouts) async {
    if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    try {
      // Wrap the data according to the API definition
      final requestData = {
        'user_id': _userId,
        'workouts': workouts, // Use 'workouts' key as per API definition
      };

      final requestBody = jsonEncode(requestData);
      // debugPrint('Workouts batch request body: $requestBody'); // Uncomment for debugging

      final response = await http.post(
        Uri.parse('$_baseUrl/workouts/batch'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Workouts uploaded: ${data['workout_count']}');
        return true;
      } else {
        debugPrint('Error uploading workouts: ${response.statusCode}');
        debugPrint('Response body: ${response.body}'); // Log error response
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading workouts: $e');
      return false;
    }
  }

  /// Upload daily activity data to the server
  Future<bool> uploadActivities(List<Map<String, dynamic>> activities) async {
    if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    try {
      // Wrap the data according to the API definition
      final requestData = {
        'user_id': _userId,
        'activities': activities, // Use 'activities' key as per API definition
      };

      final requestBody = jsonEncode(requestData);
      // debugPrint('Activities request body: $requestBody'); // Uncomment for debugging

      final response = await http.post(
        Uri.parse('$_baseUrl/activities'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Activities uploaded: ${data['activity_count']}');
        return true;
      } else {
        debugPrint('Error uploading activities: ${response.statusCode}');
        debugPrint('Response body: ${response.body}'); // Log error response
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading activities: $e');
      return false;
    }
  }

  /// Upload sleep data to the server
  Future<bool> uploadSleep(List<Map<String, dynamic>> sleepSessions) async {
    if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    try {
      // Pre-process sessions
      final processedSessions =
          sleepSessions
              .map((session) {
                if (!session.containsKey('start_date') ||
                    !session.containsKey('end_date') ||
                    !session.containsKey('sleep_stages')) {
                  debugPrint('Sleep session missing required fields: $session');
                  return null;
                }
                final processedSession = Map<String, dynamic>.from(session);
                final startDate = DateTime.parse(session['start_date']);
                final endDate = DateTime.parse(session['end_date']);
                final durationSeconds = endDate.difference(startDate).inSeconds;
                processedSession['duration_seconds'] =
                    durationSeconds.toDouble();
                if (!processedSession.containsKey('duration_minutes')) {
                  processedSession['duration_minutes'] =
                      (durationSeconds / 60).toDouble();
                }
                if (processedSession['sleep_stages'] is List) {
                  final validStages = [
                    'AWAKE',
                    'LIGHT',
                    'DEEP',
                    'REM',
                    'IN_BED',
                    'UNSPECIFIED',
                  ];
                  processedSession['sleep_stages'] =
                      (processedSession['sleep_stages'] as List)
                          .map((stage) {
                            if (stage is Map &&
                                stage.containsKey('stage_type')) {
                              if (!validStages.contains(stage['stage_type'])) {
                                stage['stage_type'] = 'UNSPECIFIED';
                              }
                              if (!stage.containsKey('duration_minutes') &&
                                  stage.containsKey('start_date') &&
                                  stage.containsKey('end_date')) {
                                final stageStart = DateTime.parse(
                                  stage['start_date'],
                                );
                                final stageEnd = DateTime.parse(
                                  stage['end_date'],
                                );
                                stage['duration_minutes'] =
                                    stageEnd
                                        .difference(stageStart)
                                        .inMinutes
                                        .toDouble();
                              }
                              return stage;
                            }
                            return null;
                          })
                          .where((stage) => stage != null)
                          .toList();
                }
                [
                  'duration_seconds',
                  'duration_minutes',
                  'asleep_minutes',
                  'awake_minutes',
                  'in_bed_minutes',
                  'sleep_efficiency',
                ].forEach((field) {
                  if (processedSession.containsKey(field)) {
                    var value = processedSession[field];
                    if (value is! num) {
                      try {
                        processedSession[field] = double.parse(
                          value.toString(),
                        );
                      } catch (_) {
                        processedSession[field] = 0.0;
                      }
                    }
                  }
                });
                return processedSession;
              })
              .where((session) => session != null)
              .toList();

      if (processedSessions.isEmpty) {
        debugPrint('No valid sleep sessions to upload');
        return false;
      }

      // Wrap the data according to the API definition
      final requestData = {
        'user_id': _userId,
        'sleep_sessions': processedSessions, // Use 'sleep_sessions' key
      };

      final requestBody = jsonEncode(requestData);
      debugPrint('Sending sleep request body length: ${requestBody.length}');
      // debugPrint('Sleep request body: $requestBody'); // Uncomment for debugging

      final response = await http.post(
        Uri.parse('$_baseUrl/sleep'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Sleep sessions uploaded: ${data['sleep_count']}');
        return true;
      } else {
        debugPrint('Error uploading sleep sessions: ${response.statusCode}');
        debugPrint('Response body: ${response.body}'); // Log error response
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading sleep sessions: $e');
      return false;
    }
  }

  /// Upload nutrition data to the server
  Future<bool> uploadNutrition(
    List<Map<String, dynamic>> nutritionEntries,
  ) async {
    if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    try {
      // Wrap the data according to the API definition
      final requestData = {
        'user_id': _userId,
        'nutrition_entries': nutritionEntries, // Use 'nutrition_entries' key
      };

      final requestBody = jsonEncode(requestData);
      // debugPrint('Nutrition request body: $requestBody'); // Uncomment for debugging

      final response = await http.post(
        Uri.parse('$_baseUrl/nutrition'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Nutrition entries uploaded: ${data['entry_count']}');
        return true;
      } else {
        debugPrint('Error uploading nutrition entries: ${response.statusCode}');
        debugPrint('Response body: ${response.body}'); // Log error response
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading nutrition entries: $e');
      return false;
    }
  }

  /// Helper method to convert metrics to biometrics format
  Map<String, dynamic> _convertMetricsToBiometrics(
    Map<String, dynamic> metrics,
  ) {
    final biometrics = <String, dynamic>{};

    try {
      // Extract body composition data
      if (metrics.containsKey('weight') ||
          metrics.containsKey('height') ||
          metrics.containsKey('body_fat_percentage') ||
          metrics.containsKey('bmi')) {
        final bodyComposition = <String, dynamic>{};

        // Process weight
        if (metrics.containsKey('weight')) {
          bodyComposition['weight'] = {
            'current': metrics['weight']['value'],
            'unit': metrics['weight']['unit'],
            'timestamp': metrics['weight']['timestamp'],
            'source': metrics['weight']['source'] ?? 'Apple Health',
          };
        }

        // Process height
        if (metrics.containsKey('height')) {
          bodyComposition['height'] = {
            'current': metrics['height']['value'],
            'unit': metrics['height']['unit'],
            'timestamp': metrics['height']['timestamp'],
            'source': metrics['height']['source'] ?? 'Apple Health',
          };
        }

        // Process body fat percentage
        if (metrics.containsKey('body_fat_percentage')) {
          bodyComposition['body_fat_percentage'] = {
            'current': metrics['body_fat_percentage']['value'],
            'unit': metrics['body_fat_percentage']['unit'],
            'timestamp': metrics['body_fat_percentage']['timestamp'],
            'source':
                metrics['body_fat_percentage']['source'] ?? 'Apple Health',
          };
        }

        // Process BMI
        if (metrics.containsKey('bmi')) {
          bodyComposition['bmi'] = {
            'current': metrics['bmi']['value'],
            'unit': metrics['bmi']['unit'],
            'timestamp': metrics['bmi']['timestamp'],
            'source': metrics['bmi']['source'] ?? 'Apple Health',
          };
        }

        biometrics['body_composition'] = bodyComposition;
      }

      // Extract vital signs data
      if (metrics.containsKey('heart_rate') ||
          metrics.containsKey('blood_pressure_systolic') ||
          metrics.containsKey('blood_pressure_diastolic') ||
          metrics.containsKey('blood_oxygen') ||
          metrics.containsKey('respiratory_rate')) {
        final vitalSigns = <String, dynamic>{};

        // Process heart rate
        if (metrics.containsKey('heart_rate')) {
          vitalSigns['heart_rate'] = {
            'value': metrics['heart_rate']['value'],
            'unit': metrics['heart_rate']['unit'],
            'timestamp': metrics['heart_rate']['timestamp'],
            'source': metrics['heart_rate']['source'] ?? 'Apple Health',
          };
        }

        // Process blood pressure
        if (metrics.containsKey('blood_pressure_systolic') &&
            metrics.containsKey('blood_pressure_diastolic')) {
          vitalSigns['blood_pressure'] = {
            'systolic': {
              'value': metrics['blood_pressure_systolic']['value'],
              'unit': metrics['blood_pressure_systolic']['unit'],
            },
            'diastolic': {
              'value': metrics['blood_pressure_diastolic']['value'],
              'unit': metrics['blood_pressure_diastolic']['unit'],
            },
            'timestamp': metrics['blood_pressure_systolic']['timestamp'],
            'source':
                metrics['blood_pressure_systolic']['source'] ?? 'Apple Health',
          };
        }

        // Process blood oxygen
        if (metrics.containsKey('blood_oxygen')) {
          vitalSigns['blood_oxygen'] = {
            'value': metrics['blood_oxygen']['value'],
            'unit': metrics['blood_oxygen']['unit'],
            'timestamp': metrics['blood_oxygen']['timestamp'],
            'source': metrics['blood_oxygen']['source'] ?? 'Apple Health',
          };
        }

        // Process respiratory rate
        if (metrics.containsKey('respiratory_rate')) {
          vitalSigns['respiratory_rate'] = {
            'value': metrics['respiratory_rate']['value'],
            'unit': metrics['respiratory_rate']['unit'],
            'timestamp': metrics['respiratory_rate']['timestamp'],
            'source': metrics['respiratory_rate']['source'] ?? 'Apple Health',
          };
        }

        biometrics['vital_signs'] = vitalSigns;
      }
    } catch (e) {
      debugPrint('Error converting metrics to biometrics: $e');
    }

    return biometrics;
  }

  /// Helper method to extract activities from activity data
  List<Map<String, dynamic>> _extractActivities(
    Map<String, dynamic> activityData,
  ) {
    final activities = <Map<String, dynamic>>[];

    try {
      // Process steps
      if (activityData.containsKey('steps')) {
        final steps = activityData['steps'];
        if (steps is Map &&
            steps.containsKey('history') &&
            steps['history'] is List) {
          final history = steps['history'] as List;
          for (final entry in history) {
            if (entry is Map &&
                entry.containsKey('date') &&
                entry.containsKey('value')) {
              // Check if we already have an activity for this date
              final date = entry['date'] as String;
              final existingIndex = activities.indexWhere(
                (a) => a['date'] == date,
              );

              if (existingIndex >= 0) {
                // Add steps to existing activity
                activities[existingIndex]['steps'] = entry['value'];
              } else {
                // Create new activity
                activities.add({
                  'date': date,
                  'steps': entry['value'],
                  'source': entry['source'] ?? 'Apple Health',
                });
              }
            }
          }
        }
      }

      // Process distance
      if (activityData.containsKey('distance')) {
        final distance = activityData['distance'];
        if (distance is Map &&
            distance.containsKey('history') &&
            distance['history'] is List) {
          final history = distance['history'] as List;
          for (final entry in history) {
            if (entry is Map &&
                entry.containsKey('date') &&
                entry.containsKey('value')) {
              // Check if we already have an activity for this date
              final date = entry['date'] as String;
              final existingIndex = activities.indexWhere(
                (a) => a['date'] == date,
              );

              if (existingIndex >= 0) {
                // Add distance to existing activity
                activities[existingIndex]['distance'] = entry['value'];
                activities[existingIndex]['distance_unit'] =
                    entry['unit'] ?? 'km';
              } else {
                // Create new activity
                activities.add({
                  'date': date,
                  'distance': entry['value'],
                  'distance_unit': entry['unit'] ?? 'km',
                  'source': entry['source'] ?? 'Apple Health',
                });
              }
            }
          }
        }
      }

      // Process active energy
      if (activityData.containsKey('active_energy_burned')) {
        final energy = activityData['active_energy_burned'];
        if (energy is Map &&
            energy.containsKey('history') &&
            energy['history'] is List) {
          final history = energy['history'] as List;
          for (final entry in history) {
            if (entry is Map &&
                entry.containsKey('date') &&
                entry.containsKey('value')) {
              // Check if we already have an activity for this date
              final date = entry['date'] as String;
              final existingIndex = activities.indexWhere(
                (a) => a['date'] == date,
              );

              if (existingIndex >= 0) {
                // Add energy to existing activity
                activities[existingIndex]['active_energy_burned'] =
                    entry['value'];
                activities[existingIndex]['active_energy_burned_unit'] =
                    entry['unit'] ?? 'kcal';
              } else {
                // Create new activity
                activities.add({
                  'date': date,
                  'active_energy_burned': entry['value'],
                  'active_energy_burned_unit': entry['unit'] ?? 'kcal',
                  'source': entry['source'] ?? 'Apple Health',
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting activities: $e');
    }

    return activities;
  }
}
