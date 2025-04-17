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

  /// Upload biometrics data to the server
  Future<bool> uploadBiometrics(Map<String, dynamic> biometricsData) async {
    if (!isInitialized) {
      debugPrint('API service not initialized');
      return false;
    }

    if (_userId == null) {
      debugPrint('No user ID available');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/biometrics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(biometricsData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Biometrics uploaded: ${data['metrics_received']}');
        return true;
      } else {
        debugPrint('Error uploading biometrics: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading biometrics: $e');
      return false;
    }
  }

  /// Upload health data directly to the server
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
      debugPrint('Uploading health data to server...');
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/health-data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(healthData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Health data uploaded successfully: ${data['message']}');
        return true;
      } else {
        debugPrint('Error uploading health data: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading health data: $e');
      return false;
    }
  }

  /// Update health metrics memory
  Future<bool> updateHealthMetrics(Map<String, dynamic> metrics) async {
    if (!isInitialized) {
      debugPrint('API service not initialized');
      return false;
    }

    if (_userId == null) {
      debugPrint('No user ID available');
      return false;
    }

    try {
      debugPrint('Updating health metrics memory...');
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/memory/health-metrics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(metrics),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Health metrics updated: ${data['message']}');
        return true;
      } else {
        debugPrint('Error updating health metrics: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error updating health metrics: $e');
      return false;
    }
  }

  /// Update biometrics memory
  Future<bool> updateBiometrics(Map<String, dynamic> biometrics) async {
    if (!isInitialized) {
      debugPrint('API service not initialized');
      return false;
    }

    if (_userId == null) {
      debugPrint('No user ID available');
      return false;
    }

    try {
      debugPrint('Updating biometrics memory...');
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/memory/biometrics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(biometrics),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Biometrics updated: ${data['message']}');
        return true;
      } else {
        debugPrint('Error updating biometrics: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error updating biometrics: $e');
      return false;
    }
  }

  /// Add a workout to memory
  Future<bool> addWorkout(Map<String, dynamic> workout) async {
    if (!isInitialized) {
      debugPrint('API service not initialized');
      return false;
    }

    if (_userId == null) {
      debugPrint('No user ID available');
      return false;
    }

    try {
      final url = '$_baseUrl/users/$_userId/memory/workout/add';
      debugPrint('Adding workout to memory...');
      debugPrint('URL: $url');
      debugPrint('User ID: $_userId');
      debugPrint('Workout data: ${jsonEncode(workout)}');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(workout),
      );

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Workout added: ${data['message']}');
        return true;
      } else {
        debugPrint('Error adding workout: ${response.statusCode}');
        debugPrint('Error response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error adding workout: $e');
      return false;
    }
  }

  /// Upload health data in chunks
  Future<bool> uploadHealthDataChunk(
    String dataType,
    List<dynamic> dataChunk,
  ) async {
    if (!isInitialized) {
      debugPrint('API service not initialized');
      return false;
    }

    if (_userId == null) {
      debugPrint('No user ID available');
      return false;
    }

    try {
      debugPrint('Uploading $dataType chunk with ${dataChunk.length} items...');
      final response = await http.post(
        Uri.parse('$_baseUrl/users/$_userId/health-data/chunk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data_type': dataType,
          'data': dataChunk,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint(
          'Health data chunk uploaded successfully: ${data['message']}',
        );
        return true;
      } else {
        debugPrint('Error uploading health data chunk: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading health data chunk: $e');
      return false;
    }
  }
}
