import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health_ai/services/health_service.dart';

/// Command-line tool to download all health data
void main() async {
  // Initialize Flutter binding for non-UI Flutter apps
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Health AI Data Downloader');
  print('------------------------');
  print('Downloading all health data...');
  
  final healthService = HealthService();
  
  // Initialize health service
  final hasPermissions = await healthService.initialize();
  if (!hasPermissions) {
    print('Error: Health data permissions not granted.');
    print('Please run the app first and grant permissions.');
    exit(1);
  }
  
  // Download all health data
  print('Fetching all health data (this may take a while)...');
  final results = await healthService.fetchAllHealthData();
  
  // Print results
  print('\nDownload complete!');
  print('Results:');
  
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
  
  print('\nData saved to device storage. You can view it in the app\'s File Explorer screen.');
}
