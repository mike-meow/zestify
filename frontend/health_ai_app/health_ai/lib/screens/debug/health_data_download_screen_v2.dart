import 'package:flutter/material.dart';
import 'package:health_ai/services/api_service_v2.dart';
import 'package:health_ai/services/health_service_v2.dart';
import 'package:health_ai/screens/debug/server_settings_screen_v2.dart';

/// Screen for downloading and uploading health data
class HealthDataDownloadScreenV2 extends StatefulWidget {
  const HealthDataDownloadScreenV2({super.key});

  @override
  State<HealthDataDownloadScreenV2> createState() =>
      _HealthDataDownloadScreenV2State();
}

class _HealthDataDownloadScreenV2State
    extends State<HealthDataDownloadScreenV2> {
  final _healthService = HealthServiceV2();
  final _apiService = ApiServiceV2();

  bool _isLoading = false;
  bool _isUploading = false;
  String _statusMessage = '';
  String _uploadStatusMessage = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _includeWorkoutDetails = true;

  @override
  void initState() {
    super.initState();
    _checkApiService();
  }

  /// Check if API service is initialized
  Future<void> _checkApiService() async {
    await _apiService.initialize();
    setState(() {});
  }

  /// Download and upload health data
  Future<void> _downloadAndUploadHealthData() async {
    // Check if API service is initialized
    if (!_apiService.isInitialized) {
      _showServerSettingsDialog();
      return;
    }

    // Check if user ID is available
    if (_apiService.userId == null) {
      _showCreateUserDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Downloading health data...';
    });

    try {
      final success = await _healthService.fetchAndUploadHealthData(
        startDate: _startDate,
        endDate: _endDate,
        includeWorkoutDetails: _includeWorkoutDetails,
      );

      setState(() {
        _isLoading = false;
        _statusMessage =
            success
                ? 'Health data downloaded and uploaded successfully'
                : 'Failed to download or upload health data';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  /// Show server settings dialog
  void _showServerSettingsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ServerSettingsScreenV2()),
    );
  }

  /// Show create user dialog
  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('No User ID'),
            content: const Text(
              'You need to create a user before uploading health data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);

                  setState(() {
                    _isUploading = true;
                    _uploadStatusMessage = 'Creating user...';
                  });

                  try {
                    final userId = await _apiService.createUser();

                    setState(() {
                      _isUploading = false;
                      _uploadStatusMessage =
                          userId != null
                              ? 'User created: $userId'
                              : 'Failed to create user';
                    });
                  } catch (e) {
                    setState(() {
                      _isUploading = false;
                      _uploadStatusMessage = 'Error creating user: $e';
                    });
                  }
                },
                child: const Text('CREATE USER'),
              ),
            ],
          ),
    );
  }

  /// Show date picker
  Future<void> _selectDate(bool isStartDate) async {
    final initialDate =
        isStartDate
            ? _startDate ?? DateTime.now().subtract(const Duration(days: 7))
            : _endDate ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Data Upload (V2)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Server URL: ${_apiService.baseUrl ?? 'Not set'}'),
                    Text('User ID: ${_apiService.userId ?? 'Not set'}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _showServerSettingsDialog,
                          child: const Text('Server Settings'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed:
                              _apiService.userId == null
                                  ? _showCreateUserDialog
                                  : null,
                          child: const Text('Create User'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Date range
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Range',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => _selectDate(true),
                            child: Text(
                              'Start Date: ${_startDate?.toString().split(' ')[0] ?? 'Last 7 days'}',
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => _selectDate(false),
                            child: Text(
                              'End Date: ${_endDate?.toString().split(' ')[0] ?? 'Today'}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      title: const Text('Include Workout Details'),
                      value: _includeWorkoutDetails,
                      onChanged: (value) {
                        setState(() {
                          _includeWorkoutDetails = value ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Download and upload
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download and Upload',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed:
                          _isLoading ? null : _downloadAndUploadHealthData,
                      child: const Text('Download and Upload Health Data'),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading) const LinearProgressIndicator(),
                    if (_statusMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_statusMessage),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Upload status
            if (_uploadStatusMessage.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (_isUploading) const LinearProgressIndicator(),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(_uploadStatusMessage),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
