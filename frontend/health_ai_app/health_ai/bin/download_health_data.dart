import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health_ai/services/unified_health_service.dart';

/// Command-line tool to download all health data
void main() async {
  // Initialize Flutter binding for non-UI Flutter apps
  WidgetsFlutterBinding.ensureInitialized();

  print('Health AI Data Downloader');
  print('------------------------');
  print('Downloading all health data...');

  final healthService = UnifiedHealthService();

  // Initialize health service
  final hasPermissions = await healthService.initialize();
  if (!hasPermissions) {
    print('Error: Health data permissions not granted.');
    print('Please run the app first and grant permissions.');
    exit(1);
  }

  // Download all health data
  print('Fetching all health data (this may take a while)...');
  final success = await healthService.fetchAndUploadHealthData();

  // Print results
  print('\nDownload complete!');

  if (success) {
    print('Health data successfully fetched and uploaded to the server.');
  } else {
    print('Error: Failed to fetch or upload health data.');
  }

  print(
    '\nData saved to device storage. You can view it in the app\'s File Explorer screen.',
  );
}
