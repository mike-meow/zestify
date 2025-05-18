import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing feature flags
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();

  /// Factory constructor to return the singleton instance
  factory FeatureFlagService() => _instance;

  /// Private constructor for singleton pattern
  FeatureFlagService._internal();

  /// Shared preferences instance
  SharedPreferences? _prefs;

  /// Whether the service is initialized
  bool _isInitialized = false;

  /// Feature flags
  final Map<String, bool> _featureFlags = {
    'use_health_kit_reporter': false, // Default to false
  };

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // Load feature flags from shared preferences
      for (final key in _featureFlags.keys) {
        final value = _prefs?.getBool('feature_flag_$key');
        if (value != null) {
          _featureFlags[key] = value;
        }
      }

      _isInitialized = true;
      debugPrint('Feature flag service initialized');
    } catch (e) {
      debugPrint('Error initializing feature flag service: $e');
    }
  }

  /// Check if a feature flag is enabled
  bool isEnabled(String featureFlag) {
    if (!_isInitialized) {
      debugPrint('Feature flag service not initialized');
      return false;
    }

    return _featureFlags[featureFlag] ?? false;
  }

  /// Enable a feature flag
  Future<void> enableFeature(String featureFlag) async {
    if (!_isInitialized) {
      await initialize();
    }

    _featureFlags[featureFlag] = true;
    await _prefs?.setBool('feature_flag_$featureFlag', true);
    debugPrint('Feature flag $featureFlag enabled');
  }

  /// Disable a feature flag
  Future<void> disableFeature(String featureFlag) async {
    if (!_isInitialized) {
      await initialize();
    }

    _featureFlags[featureFlag] = false;
    await _prefs?.setBool('feature_flag_$featureFlag', false);
    debugPrint('Feature flag $featureFlag disabled');
  }
}
