import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for communicating with the backend API
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
  Future<String?> createUser() async {
    if (!isInitialized) {
      debugPrint('API service not initialized');
      return null;
    }

    try {
      final response = await http.post(Uri.parse('$_baseUrl/users'));

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

  /// Upload biometrics data to the server (Legacy: assumes user_id in URL)
  Future<bool> uploadBiometrics(Map<String, dynamic> biometricsData) async {
    if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    try {
      // This version uses the new endpoint structure with user_id in body and data wrapper
      final requestData = {
        'user_id': _userId,
        'data': biometricsData, // Wrap the original data
      };
      
      final requestBody = jsonEncode(requestData);
      debugPrint('[Legacy API Shim] Sending to /biometrics with wrapped data');

      final response = await http.post(
        Uri.parse('$_baseUrl/biometrics'), // Use the new unified endpoint
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Biometrics uploaded: ${data['metrics_received']}');
        return true;
      } else {
        debugPrint('Error uploading biometrics: ${response.statusCode}');
        debugPrint('Response body: ${response.body}'); // Log error
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading biometrics: $e');
      return false;
    }
  }

  /// Upload health data directly to the server (Legacy Endpoint - Deprecate?)
  /// This endpoint seems less structured. Consider migrating to specific uploads.
  Future<bool> uploadHealthData(Map<String, dynamic> healthData) async {
     if (!isInitialized || _userId == null) {
      debugPrint('API service not initialized or User ID missing');
      return false;
    }

    // TODO: This endpoint is problematic. It sends a mixed bag of data.
    // Ideally, the caller should process this data and call the specific 
    // upload functions (uploadWorkouts, uploadBiometrics, uploadActivities etc.)
    // For now, we can try to forward it, but it might fail on the backend 
    // if there isn't a handler specifically for `/users/{user_id}/health-data`
    debugPrint('WARNING: Calling legacy /users/$_userId/health-data endpoint. Consider refactoring to use specific upload methods.');

    try {
      debugPrint('Uploading health data via legacy endpoint...');
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/health-data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(healthData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Health data (legacy) uploaded successfully: ${data['message']}');
        return true;
      } else {
        debugPrint('Error uploading health data (legacy): ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading health data (legacy): $e');
      return false;
    }
  }

  // --- Deprecated Memory Update Endpoints --- 
  // These directly manipulated memory files, which is now handled by the main upload endpoints.
  // Mark them as deprecated or remove if no longer used.
  
  @Deprecated('Use specific upload endpoints like uploadBiometrics, uploadWorkouts, etc.')
  Future<bool> updateHealthMetrics(Map<String, dynamic> metrics) async {
    debugPrint('DEPRECATED: updateHealthMetrics called. Use specific upload endpoints.');
    // Optionally, try to map `metrics` to a specific upload call if possible.
    // For now, return false or attempt a legacy call if one exists.
    return false; 
  }

  @Deprecated('Use uploadBiometrics instead.')
  Future<bool> updateBiometrics(Map<String, dynamic> biometrics) async {
    debugPrint('DEPRECATED: updateBiometrics called. Use uploadBiometrics instead.');
    // Forward to the new uploadBiometrics method
    return uploadBiometrics(biometrics);
  }

  @Deprecated('Use uploadWorkout or uploadWorkouts instead.')
  Future<bool> addWorkout(Map<String, dynamic> workout) async {
    debugPrint('DEPRECATED: addWorkout called. Use uploadWorkout instead.');
    // Create the structure expected by the new single workout endpoint
    final requestData = {
      'user_id': _userId,
      'workout': workout, 
    };
    
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
  @Deprecated('Use specific batch upload endpoints like uploadWorkouts, uploadActivities etc.')
  Future<bool> uploadHealthDataChunk(
    String dataType,
    List<dynamic> dataChunk,
  ) async {
    debugPrint('DEPRECATED: uploadHealthDataChunk called. Use specific batch upload endpoints.');
    // Determine the correct batch endpoint based on dataType and call it.
    // Example:
    // if (dataType == 'WORKOUT') {
    //   return uploadWorkouts(List<Map<String, dynamic>>.from(dataChunk));
    // } else if (dataType == 'ACTIVITY') { ... }
    // For now, return false.
    return false;
  }
}
