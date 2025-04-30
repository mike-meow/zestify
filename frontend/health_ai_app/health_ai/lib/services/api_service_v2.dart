import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for communicating with the backend API (V2)
/// This version uses the new API endpoints with user_id in the request body
class ApiServiceV2 {
  static final ApiServiceV2 _instance = ApiServiceV2._internal();

  /// Factory constructor to return the singleton instance
  factory ApiServiceV2() => _instance;

  /// Private constructor for singleton pattern
  ApiServiceV2._internal();

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
      // Wrap the data according to the new API definition
      final requestData = {
        'user_id': _userId,
        'data': biometricsData, // Embed the original data under 'data' key
      };

      _logWeightHistoryDetails(biometricsData); // Log details from original data

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
        debugPrint('Current weight: ${weight['value']} ${weight['unit']} @ ${weight['timestamp']}');
        
        if (weight.containsKey('history') && weight['history'] is List) {
          final history = weight['history'] as List;
          debugPrint('Total weight history records: ${history.length}');
          
          if (history.isEmpty) {
            debugPrint('WARNING: Weight history array is empty!');
            return;
          }
          
          // Check if history is actually a proper list of maps
          if (history.first is! Map) {
            debugPrint('ERROR: Weight history items are not maps! Type: ${history.first.runtimeType}');
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
          final dateRange = '${oldestEntry['timestamp']} to ${newestEntry['timestamp']}';
          debugPrint('Weight data spans: $dateRange');
          
          // Log a sample of entries from different time periods
          debugPrint('=== Sample of weight history entries ===');
          
          // Get the first entry
          debugPrint('Oldest entry: ${oldestEntry['value']} ${oldestEntry['unit']} @ ${oldestEntry['timestamp']}');
          
          // Get the most recent entry
          debugPrint('Newest entry: ${newestEntry['value']} ${newestEntry['unit']} @ ${newestEntry['timestamp']}');
          
          // Get some entries in the middle if there are enough
          if (history.length >= 4) {
            final middle1Index = history.length ~/ 3;
            final middle2Index = (history.length * 2) ~/ 3;
            
            final middle1 = sortedHistory[middle1Index];
            final middle2 = sortedHistory[middle2Index];
            
            debugPrint('Middle entry 1: ${middle1['value']} ${middle1['unit']} @ ${middle1['timestamp']}');
            debugPrint('Middle entry 2: ${middle2['value']} ${middle2['unit']} @ ${middle2['timestamp']}');
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
            debugPrint('WARNING: Found $duplicates duplicate timestamps in weight history');
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
              debugPrint('ERROR: Weight value is not a number: ${entry['value']} (${entry['value'].runtimeType})');
            }
          }
          
          if (malformedEntries > 0) {
            debugPrint('WARNING: Found $malformedEntries malformed entries in weight history');
          }
          
          debugPrint('================================================');
        } else {
          debugPrint('ERROR: No weight history found in weight data structure');
          debugPrint('Weight data keys: ${weight.keys.join(', ')}');
        }
      } else {
        debugPrint('ERROR: No weight data found in body composition');
        if (biometrics.containsKey('body_composition')) {
          debugPrint('Body composition keys: ${biometrics['body_composition'].keys.join(', ')}');
        } else {
          debugPrint('No body_composition key in biometrics');
          debugPrint('Biometrics keys: ${biometrics.keys.join(', ')}');
        }
      }
    } catch (e) {
      debugPrint('Error logging weight history: $e');
    }
  }

  /// Upload a single workout to the server
  Future<bool> uploadWorkout(Map<String, dynamic> workoutData) async {
    if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    try {
      // Wrap the data according to the new API definition
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
      // Wrap the data according to the new API definition
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
      // Wrap the data according to the new API definition
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
      // Pre-process sessions (existing logic seems okay)
      final processedSessions = sleepSessions.map((session) {
         // ... (keep existing pre-processing logic for sleep data) ...
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
          processedSession['duration_seconds'] = durationSeconds.toDouble();
          if (!processedSession.containsKey('duration_minutes')) {
            processedSession['duration_minutes'] = (durationSeconds / 60).toDouble();
          }
          if (processedSession['sleep_stages'] is List) {
            final validStages = ['AWAKE', 'LIGHT', 'DEEP', 'REM', 'IN_BED', 'UNSPECIFIED'];
            processedSession['sleep_stages'] = (processedSession['sleep_stages'] as List)
                .map((stage) {
                  if (stage is Map && stage.containsKey('stage_type')) {
                    if (!validStages.contains(stage['stage_type'])) {
                      stage['stage_type'] = 'UNSPECIFIED';
                    }
                    if (!stage.containsKey('duration_minutes') && stage.containsKey('start_date') && stage.containsKey('end_date')) {
                      final stageStart = DateTime.parse(stage['start_date']);
                      final stageEnd = DateTime.parse(stage['end_date']);
                      stage['duration_minutes'] = stageEnd.difference(stageStart).inMinutes.toDouble();
                    }
                    return stage;
                  }
                  return null;
                })
                .where((stage) => stage != null)
                .toList();
          }
          ['duration_seconds', 'duration_minutes', 'asleep_minutes', 'awake_minutes', 'in_bed_minutes', 'sleep_efficiency'].forEach((field) {
            if (processedSession.containsKey(field)) {
              var value = processedSession[field];
              if (value is! num) {
                try { processedSession[field] = double.parse(value.toString()); } catch (_) { processedSession[field] = 0.0; }
              }
            }
          });
          return processedSession;
      }).where((session) => session != null).toList();

      if (processedSessions.isEmpty) {
        debugPrint('No valid sleep sessions to upload');
        return false;
      }

      // Wrap the data according to the new API definition
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
      // Wrap the data according to the new API definition
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
      debugPrint('Error uploading health data: $e');
      return false;
    }
  }

  /// Convert metrics to biometrics format
  Map<String, dynamic> _convertMetricsToBiometrics(
    Map<String, dynamic> metrics,
  ) {
    final biometrics = <String, dynamic>{};

    // Body composition data
    final bodyComposition = <String, dynamic>{};

    // Check for weight
    if (metrics.containsKey('WEIGHT')) {
      final weight = metrics['WEIGHT'];
      
      // Handle weight as both current value and history
      if (weight is Map && weight.containsKey('value')) {
        // Single weight value
        bodyComposition['weight'] = {
          'value': double.tryParse(weight['value'].toString()) ?? 0,
          'unit': weight['unit'] ?? 'kg',
          'timestamp': weight['date'] ?? DateTime.now().toIso8601String(),
          'source': weight['source'] ?? 'Apple Health',
        };
      } else if (weight is Map && weight.containsKey('history')) {
        // Weight with history
        List<dynamic> weightHistory = weight['history'] as List<dynamic>;
        
        if (weightHistory.isNotEmpty) {
          // Sort history by timestamp (newest first)
          weightHistory.sort((a, b) {
            final aTime = a['timestamp'] ?? '';
            final bTime = b['timestamp'] ?? '';
            return bTime.compareTo(aTime);
          });
          
          // Use the latest entry as the current value
          final latest = weightHistory.first;
          
          bodyComposition['weight'] = {
            'value': double.tryParse(latest['value'].toString()) ?? 0,
            'unit': latest['unit'] ?? 'kg',
            'timestamp': latest['timestamp'] ?? DateTime.now().toIso8601String(),
            'source': latest['source'] ?? 'Apple Health',
            'history': weightHistory.map((entry) {
              return {
                'value': double.tryParse(entry['value'].toString()) ?? 0,
                'timestamp': entry['timestamp'],
                'unit': entry['unit'] ?? 'kg',
                'source': entry['source'] ?? 'Apple Health',
              };
            }).toList(),
          };
        }
      } else if (weight is List && weight.isNotEmpty) {
        // Direct list of weight measurements
        List<dynamic> weightList = weight;
        
        // Sort by timestamp (newest first)
        weightList.sort((a, b) {
          final aTime = a['timestamp'] ?? a['date'] ?? '';
          final bTime = b['timestamp'] ?? b['date'] ?? '';
          return bTime.compareTo(aTime);
        });
        
        // Use the latest entry as the current value
        final latest = weightList.first;
        final timestamp = latest['timestamp'] ?? latest['date'] ?? DateTime.now().toIso8601String();
        
        bodyComposition['weight'] = {
          'value': double.tryParse(latest['value'].toString()) ?? 0,
          'unit': latest['unit'] ?? 'kg',
          'timestamp': timestamp,
          'source': latest['source'] ?? 'Apple Health',
          'history': weightList.map((entry) {
            return {
              'value': double.tryParse(entry['value'].toString()) ?? 0,
              'timestamp': entry['timestamp'] ?? entry['date'],
              'unit': entry['unit'] ?? 'kg',
              'source': entry['source'] ?? 'Apple Health',
            };
          }).toList(),
        };
      }
    }

    // Check for height
    if (metrics.containsKey('HEIGHT')) {
      final height = metrics['HEIGHT'];
      
      // Handle height in the same way as weight
      if (height is Map && height.containsKey('value')) {
        // Single height value
        bodyComposition['height'] = {
          'value': double.tryParse(height['value'].toString()) ?? 0,
          'unit': height['unit'] ?? 'cm',
          'timestamp': height['date'] ?? DateTime.now().toIso8601String(),
          'source': height['source'] ?? 'Apple Health',
        };
      } else if (height is Map && height.containsKey('history')) {
        // Height with history
        List<dynamic> heightHistory = height['history'] as List<dynamic>;
        
        if (heightHistory.isNotEmpty) {
          // Sort history by timestamp (newest first)
          heightHistory.sort((a, b) {
            final aTime = a['timestamp'] ?? '';
            final bTime = b['timestamp'] ?? '';
            return bTime.compareTo(aTime);
          });
          
          // Use the latest entry as the current value
          final latest = heightHistory.first;
          
          bodyComposition['height'] = {
            'value': double.tryParse(latest['value'].toString()) ?? 0,
            'unit': latest['unit'] ?? 'cm',
            'timestamp': latest['timestamp'] ?? DateTime.now().toIso8601String(),
            'source': latest['source'] ?? 'Apple Health',
            'history': heightHistory.map((entry) {
              return {
                'value': double.tryParse(entry['value'].toString()) ?? 0,
                'timestamp': entry['timestamp'],
                'unit': entry['unit'] ?? 'cm',
                'source': entry['source'] ?? 'Apple Health',
              };
            }).toList(),
          };
        }
      } else if (height is List && height.isNotEmpty) {
        // Direct list of height measurements
        List<dynamic> heightList = height;
        
        // Sort by timestamp (newest first)
        heightList.sort((a, b) {
          final aTime = a['timestamp'] ?? a['date'] ?? '';
          final bTime = b['timestamp'] ?? b['date'] ?? '';
          return bTime.compareTo(aTime);
        });
        
        // Use the latest entry as the current value
        final latest = heightList.first;
        final timestamp = latest['timestamp'] ?? latest['date'] ?? DateTime.now().toIso8601String();
        
        bodyComposition['height'] = {
          'value': double.tryParse(latest['value'].toString()) ?? 0,
          'unit': latest['unit'] ?? 'cm',
          'timestamp': timestamp,
          'source': latest['source'] ?? 'Apple Health',
          'history': heightList.map((entry) {
            return {
              'value': double.tryParse(entry['value'].toString()) ?? 0,
              'timestamp': entry['timestamp'] ?? entry['date'],
              'unit': entry['unit'] ?? 'cm',
              'source': entry['source'] ?? 'Apple Health',
            };
          }).toList(),
        };
      }
    }

    // Check for body fat percentage
    if (metrics.containsKey('BODY_FAT_PERCENTAGE')) {
      final bodyFat = metrics['BODY_FAT_PERCENTAGE'];
      bodyComposition['body_fat_percentage'] = {
        'value': double.tryParse(bodyFat['value'].toString()) ?? 0,
        'unit': bodyFat['unit'] ?? '%',
        'timestamp': bodyFat['date'] ?? DateTime.now().toIso8601String(),
        'source': bodyFat['source'] ?? 'Apple Health',
      };
    }

    // Add body composition to biometrics if not empty
    if (bodyComposition.isNotEmpty) {
      biometrics['body_composition'] = bodyComposition;
    }

    // Vital signs data
    final vitalSigns = <String, dynamic>{};

    // Check for heart rate
    if (metrics.containsKey('HEART_RATE')) {
      final heartRate = metrics['HEART_RATE'];
      vitalSigns['resting_heart_rate'] = {
        'value': double.tryParse(heartRate['value'].toString()) ?? 0,
        'unit': heartRate['unit'] ?? 'bpm',
        'timestamp': heartRate['date'] ?? DateTime.now().toIso8601String(),
        'source': heartRate['source'] ?? 'Apple Health',
      };
    }

    // Check for blood pressure
    if (metrics.containsKey('BLOOD_PRESSURE_SYSTOLIC')) {
      final systolic = metrics['BLOOD_PRESSURE_SYSTOLIC'];
      vitalSigns['blood_pressure_systolic'] = {
        'value': double.tryParse(systolic['value'].toString()) ?? 0,
        'unit': systolic['unit'] ?? 'mmHg',
        'timestamp': systolic['date'] ?? DateTime.now().toIso8601String(),
        'source': systolic['source'] ?? 'Apple Health',
      };
    }

    if (metrics.containsKey('BLOOD_PRESSURE_DIASTOLIC')) {
      final diastolic = metrics['BLOOD_PRESSURE_DIASTOLIC'];
      vitalSigns['blood_pressure_diastolic'] = {
        'value': double.tryParse(diastolic['value'].toString()) ?? 0,
        'unit': diastolic['unit'] ?? 'mmHg',
        'timestamp': diastolic['date'] ?? DateTime.now().toIso8601String(),
        'source': diastolic['source'] ?? 'Apple Health',
      };
    }

    // Check for respiratory rate
    if (metrics.containsKey('RESPIRATORY_RATE')) {
      final respiratoryRate = metrics['RESPIRATORY_RATE'];
      vitalSigns['respiratory_rate'] = {
        'value': double.tryParse(respiratoryRate['value'].toString()) ?? 0,
        'unit': respiratoryRate['unit'] ?? 'breaths/min',
        'timestamp':
            respiratoryRate['date'] ?? DateTime.now().toIso8601String(),
        'source': respiratoryRate['source'] ?? 'Apple Health',
      };
    }

    // Check for blood oxygen
    if (metrics.containsKey('BLOOD_OXYGEN')) {
      final bloodOxygen = metrics['BLOOD_OXYGEN'];
      vitalSigns['blood_oxygen'] = {
        'value': double.tryParse(bloodOxygen['value'].toString()) ?? 0,
        'unit': bloodOxygen['unit'] ?? '%',
        'timestamp': bloodOxygen['date'] ?? DateTime.now().toIso8601String(),
        'source': bloodOxygen['source'] ?? 'Apple Health',
      };
    }

    // Check for blood glucose
    if (metrics.containsKey('BLOOD_GLUCOSE')) {
      final bloodGlucose = metrics['BLOOD_GLUCOSE'];
      vitalSigns['blood_glucose'] = {
        'value': double.tryParse(bloodGlucose['value'].toString()) ?? 0,
        'unit': bloodGlucose['unit'] ?? 'mg/dL',
        'timestamp': bloodGlucose['date'] ?? DateTime.now().toIso8601String(),
        'source': bloodGlucose['source'] ?? 'Apple Health',
      };
    }

    // Check for body temperature
    if (metrics.containsKey('BODY_TEMPERATURE')) {
      final bodyTemperature = metrics['BODY_TEMPERATURE'];
      vitalSigns['body_temperature'] = {
        'value': double.tryParse(bodyTemperature['value'].toString()) ?? 0,
        'unit': bodyTemperature['unit'] ?? '°C',
        'timestamp':
            bodyTemperature['date'] ?? DateTime.now().toIso8601String(),
        'source': bodyTemperature['source'] ?? 'Apple Health',
      };
    }

    // Add vital signs to biometrics if not empty
    if (vitalSigns.isNotEmpty) {
      biometrics['vital_signs'] = vitalSigns;
    }

    return biometrics;
  }

  /// Extract activities from health data
  List<Map<String, dynamic>> _extractActivities(
    Map<String, dynamic> activityData,
  ) {
    final activities = <Map<String, dynamic>>[];

    // Group activity data by date
    final activityByDate = <String, Map<String, dynamic>>{};

    // Process steps
    if (activityData.containsKey('steps') &&
        activityData['steps'] is Map &&
        activityData['steps'].containsKey('history')) {
      final stepsHistory = activityData['steps']['history'];
      if (stepsHistory is List) {
        for (final step in stepsHistory) {
          if (step is Map &&
              step.containsKey('timestamp') &&
              step.containsKey('value')) {
            final date =
                step['timestamp'].toString().split('T')[0]; // Extract date part

            if (!activityByDate.containsKey(date)) {
              activityByDate[date] = {'date': date, 'source': 'APPLE_HEALTH'};
            }

            if (activityByDate[date] != null) {
              activityByDate[date]!['steps'] = step['value'];
            }
          }
        }
      }
    }

    // Process distance
    if (activityData.containsKey('distance') &&
        activityData['distance'] is Map &&
        activityData['distance'].containsKey('history')) {
      final distanceHistory = activityData['distance']['history'];
      if (distanceHistory is List) {
        for (final distance in distanceHistory) {
          if (distance is Map &&
              distance.containsKey('timestamp') &&
              distance.containsKey('value')) {
            final date =
                distance['timestamp'].toString().split(
                  'T',
                )[0]; // Extract date part

            if (!activityByDate.containsKey(date)) {
              activityByDate[date] = {'date': date, 'source': 'APPLE_HEALTH'};
            }

            if (activityByDate[date] != null) {
              activityByDate[date]!['distance'] = distance['value'];
              activityByDate[date]!['distance_unit'] = distance['unit'] ?? 'km';
            }
          }
        }
      }
    }

    // Process floors climbed
    if (activityData.containsKey('floors_climbed') &&
        activityData['floors_climbed'] is Map &&
        activityData['floors_climbed'].containsKey('history')) {
      final floorsHistory = activityData['floors_climbed']['history'];
      if (floorsHistory is List) {
        for (final floors in floorsHistory) {
          if (floors is Map &&
              floors.containsKey('timestamp') &&
              floors.containsKey('value')) {
            final date =
                floors['timestamp'].toString().split(
                  'T',
                )[0]; // Extract date part

            if (!activityByDate.containsKey(date)) {
              activityByDate[date] = {'date': date, 'source': 'APPLE_HEALTH'};
            }

            if (activityByDate[date] != null) {
              activityByDate[date]!['floors_climbed'] = floors['value'];
            }
          }
        }
      }
    }

    // Process active energy burned
    if (activityData.containsKey('active_energy_burned') &&
        activityData['active_energy_burned'] is Map &&
        activityData['active_energy_burned'].containsKey('history')) {
      final energyHistory = activityData['active_energy_burned']['history'];
      if (energyHistory is List) {
        for (final energy in energyHistory) {
          if (energy is Map &&
              energy.containsKey('timestamp') &&
              energy.containsKey('value')) {
            final date =
                energy['timestamp'].toString().split(
                  'T',
                )[0]; // Extract date part

            if (!activityByDate.containsKey(date)) {
              activityByDate[date] = {'date': date, 'source': 'APPLE_HEALTH'};
            }

            if (activityByDate[date] != null) {
              activityByDate[date]!['active_energy_burned'] = energy['value'];
              activityByDate[date]!['active_energy_burned_unit'] =
                  energy['unit'] ?? 'kcal';
            }
          }
        }
      }
    }

    // Convert map to list
    activityByDate.forEach((date, activity) {
      activities.add(activity);
    });

    return activities;
  }
}
